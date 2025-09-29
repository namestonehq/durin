import { createConfig, factory } from 'ponder'
import { alchemy, type AlchemyChain } from 'evm-providers'

import { durinAbi } from './abis/durinAbi'
import { durinFactoryAbi } from './abis/durinFactoryAbi'
import { parseAbiItem } from 'viem/utils'

const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY

if (!ALCHEMY_API_KEY) {
  throw new Error('ALCHEMY_API_KEY is not set')
}

const rpc = (chainId: AlchemyChain) => alchemy(chainId, ALCHEMY_API_KEY)

export default createConfig({
  ordering: 'multichain',
  // TODO: import supported chains from `gateway/src/ccip-read/query.ts`
  chains: {
    mainnet: {
      id: 1,
      rpc: rpc(1),
    },
    sepolia: {
      id: 11155111,
      rpc: rpc(11155111),
    },
    base: {
      id: 8453,
      rpc: rpc(8453),
    },
    baseSepolia: {
      id: 84532,
      rpc: rpc(84532),
    },
    celo: {
      id: 42220,
      rpc: rpc(42220),
    },
    celoSepolia: {
      id: 11142220,
      rpc: rpc(11142220),
    },
  },
  contracts: {
    durinFactory: {
      address: '0xDddddDdDDD8Aa1f237b4fa0669cb46892346d22d',
      abi: durinFactoryAbi,
      chain: {
        base: { startBlock: 28455942 },
        baseSepolia: { startBlock: 23966116 },
        celo: { startBlock: 31800825 },
        celoSepolia: { startBlock: 5025928 },
      },
    },
    durin: {
      abi: durinAbi,
      address: factory({
        address: '0xDddddDdDDD8Aa1f237b4fa0669cb46892346d22d',
        // This is the old event
        event: parseAbiItem(
          'event L2RegistrySet(bytes32 node, uint64 targetChainId, address targetRegistryAddress)'
        ),
        parameter: 'targetRegistryAddress',
      }),
      chain: {
        base: { startBlock: 28455942 },
        baseSepolia: { startBlock: 23966116 },
        celo: { startBlock: 31800825 },
        celoSepolia: { startBlock: 5025928 },
      },
    },
  },
})
