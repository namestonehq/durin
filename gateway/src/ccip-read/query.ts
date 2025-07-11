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

import { type Env, envVar } from '../env'
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

  // const ALCHEMY_API_KEY = envVar('ALCHEMY_API_KEY', env)
  const ALCHEMY_API_KEY = 'WCxKqTtbcItjAXW7R_TDrj3wp57JD6GO'

  const l2Client = createPublicClient({
    chain,
    transport: http(
      chain.id === worldchainSepolia.id
        ? 'https://worldchain-sepolia.g.alchemy.com/public'
        : ALCHEMY_API_KEY
          ? alchemy(chain.id, ALCHEMY_API_KEY)
          : undefined
    ),
  })

  const log = {
    targetChainId,
    targetRegistryAddress,
    name,
    functionName,
    args,
  }

  try {
    // We can just pass through the call to our L2 resolver because it shares the same interface
    const data = await l2Client.readContract({
      address: targetRegistryAddress,
      abi: [resolverAbi[1]],
      functionName: 'resolve',
      args: [dnsEncodedName, encodedResolveCall],
    })

    console.log({ ...log, success: true })

    return data
  } catch (error) {
    console.error('There is an error when calling the l2TargetRegistry')
    console.log({ ...log, success: false })
    return '0x' as const
  }
}
