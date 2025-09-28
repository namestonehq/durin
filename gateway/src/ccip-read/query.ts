import { alchemy } from 'evm-providers'
import { type Hex, createPublicClient, http } from 'viem'
import {
  arbitrum,
  arbitrumSepolia,
  base,
  baseSepolia,
  celo,
  celoSepolia,
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

import { type Env, envVar } from '../env'
import { dnsDecodeName, resolverAbi } from './utils'

const supportedChains = [
  arbitrum,
  arbitrumSepolia,
  base,
  baseSepolia,
  celo,
  celoSepolia,
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
]

type HandleQueryArgs = {
  dnsEncodedName: Hex
  encodedResolveCall: Hex
  targetChainId: bigint
  targetRegistryAddress: Hex
  env: Env
}

export async function handleQuery({
  dnsEncodedName,
  encodedResolveCall,
  targetChainId,
  targetRegistryAddress,
  env,
}: HandleQueryArgs) {
  const name = dnsDecodeName(dnsEncodedName)

  // Decode the internal resolve call like addr(), text() or contenthash()
  const { functionName, args } = decodeFunctionData({
    abi: resolverAbi,
    data: encodedResolveCall,
  })

  const chain = supportedChains.find(
    (chain) => BigInt(chain.id) === targetChainId
  )

  if (!chain) {
    console.error(`Unsupported chain ${targetChainId} for ${name}`)
    return '0x' as const
  }

  const ALCHEMY_API_KEY = envVar('ALCHEMY_API_KEY', env)

  const l2Client = createPublicClient({
    chain,
    transport: http(
      // There's an Alchemy issue with Worldchain Sepolia when using API keys, so we'll use the public endpoint for now
      chain.id === worldchainSepolia.id
        ? 'https://worldchain-sepolia.g.alchemy.com/public'
        : ALCHEMY_API_KEY
          ? alchemy(chain.id, ALCHEMY_API_KEY)
          : undefined
    ),
  })

  console.log({
    targetChainId,
    targetRegistryAddress,
    name,
    functionName,
    args,
  })

  return l2Client.readContract({
    address: targetRegistryAddress,
    abi: [resolverAbi[1]],
    functionName: 'resolve',
    args: [dnsEncodedName, encodedResolveCall],
  })
}
