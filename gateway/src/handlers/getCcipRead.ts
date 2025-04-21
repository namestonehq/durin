import type { HonoRequest } from 'hono'
import { type Hex, serializeSignature } from 'viem'
import { sign } from 'viem/accounts'
import {
  decodeFunctionData,
  encodeAbiParameters,
  encodePacked,
  isAddress,
  isHex,
  keccak256,
} from 'viem/utils'
import { z } from 'zod'

import { handleQuery } from '../ccip-read/query'
import { resolverAbi } from '../ccip-read/utils'
import { type Env, envVar } from '../env'

const schema = z.object({
  sender: z.string().refine((data) => isAddress(data)),
  data: z.string().refine((data) => isHex(data)),
})

// Implements ERC-3668
export const getCcipRead = async (
  req: HonoRequest,
  env: Env
): Promise<Response> => {
  const safeParse = schema.safeParse(req.param())

  if (!safeParse.success) {
    return Response.json(
      { message: 'Invalid request', error: safeParse.error },
      { status: 400 }
    )
  }

  const { sender, data } = safeParse.data

  const decodedStuffedResolveCall = decodeFunctionData({
    abi: [resolverAbi[0]],
    data: data,
  })

  const result = await handleQuery({
    dnsEncodedName: decodedStuffedResolveCall.args[0],
    encodedResolveCall: decodedStuffedResolveCall.args[1] as Hex,
    targetChainId: decodedStuffedResolveCall.args[2],
    targetRegistryAddress: decodedStuffedResolveCall.args[3],
    env,
  })

  const ttl = 1000
  const validUntil = Math.floor(Date.now() / 1000 + ttl)

  // Specific to `makeSignatureHash()` in the contract https://etherscan.io/address/0xDB34Da70Cfd694190742E94B7f17769Bc3d84D27#code#F2#L14
  const messageHash = keccak256(
    encodePacked(
      ['bytes', 'address', 'uint64', 'bytes32', 'bytes32'],
      [
        '0x1900', // This is hardcoded in the contract (EIP-191).
        sender, // target: The address the signature is for.
        BigInt(validUntil), // expires: The timestamp at which the response becomes invalid.
        keccak256(data), // request: The original request that was sent.
        keccak256(result), // result: The `result` field of the response (not including the signature part).
      ]
    )
  )

  const sig = await sign({
    hash: messageHash,
    privateKey: envVar('SIGNER_PRIVATE_KEY', env),
  })

  // An ABI encoded tuple of `(bytes result, uint64 expires, bytes sig)`, where
  // `result` is the data to return to the caller and `sig` is the (r,s,v) encoded message signature.
  // Specific to `verify()` in SignatureVerifier.sol
  const encodedResponse = encodeAbiParameters(
    [
      { name: 'result', type: 'bytes' },
      { name: 'expires', type: 'uint64' },
      { name: 'sig', type: 'bytes' },
    ],
    [result, BigInt(validUntil), serializeSignature(sig)]
  )

  return Response.json({ data: encodedResponse }, { status: 200 })
}
