import { type Hex, createPublicClient, http } from 'viem'
import { base, baseSepolia } from 'viem/chains'
import { decodeFunctionData } from 'viem/utils'

import { dnsDecodeName, resolverAbi } from './utils'

const supportedChains = [
  { ...base, rpcUrl: 'https://base.drpc.org' },
  { ...baseSepolia, rpcUrl: 'https://base-sepolia.drpc.org' },
]

// Create clients outside of the function lets us take advantage of Viem's native caching
const clients = supportedChains.map((chain) =>
  createPublicClient({
    chain,
    transport: http(chain.rpcUrl),
    cacheTime: 10_000,
  })
)

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

  // Decode the internal resolve call like addr(), text() or contenthash()
  const { functionName, args } = decodeFunctionData({
    abi: resolverAbi,
    data: encodedResolveCall,
  })

  console.log({
    targetChainId,
    targetRegistryAddress,
    name,
    functionName,
    args,
  })

  const l2Chain = supportedChains.find(
    (chain) => chain.id === Number(targetChainId)
  )

  const l2Client = clients.find((client) => client.chain.id === l2Chain?.id)

  if (!l2Chain || !l2Client) {
    console.error(`Unsupported chain ${targetChainId}`)
    return '0x' as const
  }

  // We can just pass through the call to our L2 resolver because it shares the same interface
  return l2Client.readContract({
    address: targetRegistryAddress,
    abi: [resolverAbi[1]],
    functionName: 'resolve',
    args: [dnsEncodedName, encodedResolveCall],
  })
}
