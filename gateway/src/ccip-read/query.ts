import { alchemy } from 'evm-providers'
import { type Hex, createPublicClient, http } from 'viem'
import {
  arbitrum,
  arbitrumSepolia,
  base,
  baseSepolia,
  celo,
  celoAlfajores,
  linea,
  lineaSepolia,
  optimism,
  optimismSepolia,
  polygon,
  polygonAmoy,
  scroll,
  scrollSepolia,
  worldchain,
  worldchainSepolia,
} from 'viem/chains'
import { decodeFunctionData } from 'viem/utils'

import { dnsDecodeName, resolverAbi } from './utils'

const supportedChains = [
  base,
  baseSepolia,
  optimism,
  optimismSepolia,
  arbitrum,
  arbitrumSepolia,
  linea,
  lineaSepolia,
  scroll,
  scrollSepolia,
  celo,
  celoAlfajores,
  worldchain,
  worldchainSepolia,
  polygon,
  polygonAmoy,
]

const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY

// Create clients outside of the function lets us take advantage of Viem's native caching
const clients = supportedChains.map((chain) =>
  createPublicClient({
    chain,
    cacheTime: 10_000,
    batch: { multicall: true },
    transport: http(
      ALCHEMY_API_KEY ? alchemy(chain.id, ALCHEMY_API_KEY) : undefined
    ),
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

  const l2Client = clients.find(
    (client) => BigInt(client.chain.id) === targetChainId
  )

  if (!l2Client) {
    console.error(`Unsupported chain ${targetChainId} for ${name}`)
    return '0x' as const
  }

  console.log({
    targetChainId,
    targetRegistryAddress,
    name,
    functionName,
    args,
  })

  // We can just pass through the call to our L2 resolver because it shares the same interface
  return l2Client.readContract({
    address: targetRegistryAddress,
    abi: [resolverAbi[1]],
    functionName: 'resolve',
    args: [dnsEncodedName, encodedResolveCall],
  })
}
