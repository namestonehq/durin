import {
  type AbiItem,
  type Hex,
  createPublicClient,
  http,
  labelhash,
  parseAbi,
} from 'viem'
import { base, baseSepolia } from 'viem/chains'
import { decodeFunctionData, encodeFunctionResult } from 'viem/utils'

import { dnsDecodeName, resolverAbi } from './utils'

const supportedChains = [
  { ...base, rpcUrl: 'https://base.drpc.org' },
  { ...baseSepolia, rpcUrl: 'https://base-sepolia.drpc.org' },
]

type HandleQueryArgs = {
  dnsEncodedName: Hex
  encodedResolveCall: Hex
  targetChainId: bigint
  targetRegistryAddress: Hex
}

export async function handleQuery({
  dnsEncodedName,
  encodedResolveCall,
  targetChainId,
  targetRegistryAddress,
}: HandleQueryArgs) {
  const name = dnsDecodeName(dnsEncodedName)
  const [label] = name.split('.')

  // Decode the internal resolve call like addr(), text() or contenthash()
  const { functionName, args } = decodeFunctionData({
    abi: resolverAbi,
    data: encodedResolveCall,
  })

  const l2Chain = supportedChains.find(
    (chain) => chain.id === Number(targetChainId)
  )

  console.log({ functionName, args, l2Chain: l2Chain?.name })

  if (!l2Chain) {
    throw new Error(`Unsupported chain ${targetChainId}`)
  }

  const l2Client = createPublicClient({
    chain: l2Chain,
    transport: http(l2Chain.rpcUrl),
  })

  // We need to find the correct ABI item for each function, otherwise `addr(node)` and `addr(node, coinType)` causes issues
  const abiItem: AbiItem | undefined = resolverAbi.find(
    (abi) => abi.name === functionName && abi.inputs.length === args.length
  )

  // We can just pass through the call to our L2 resolver because it shares the same interface
  const res = (await l2Client.readContract({
    address: targetRegistryAddress,
    abi: [abiItem],
    functionName,
    args,
  })) as string

  console.log({ res, abiItem })

  return {
    ttl: 1000,
    result: encodeFunctionResult({
      abi: [abiItem],
      functionName: functionName,
      result: res,
    }),
  }
}
