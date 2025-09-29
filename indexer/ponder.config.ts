import { alchemy, drpc, publicNode } from 'evm-providers'
import { createConfig, factory } from 'ponder'
import { loadBalance, rateLimit } from '@ponder/utils'

import { durinAbi } from './abis/durinAbi'
import { durinFactoryAbi } from './abis/durinFactoryAbi'
import { parseAbiItem } from 'viem/utils'
import { http } from 'viem'

const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY
const DRPC_API_KEY = process.env.DRPC_API_KEY

const rpc = (chainId: number) => {
  const id = chainId as any

  return loadBalance([
    rateLimit(http(alchemy(id, ALCHEMY_API_KEY!)), { requestsPerSecond: 10 }),
    rateLimit(http(drpc(id, DRPC_API_KEY)), { requestsPerSecond: 10 }),
    rateLimit(http(publicNode(id)), { requestsPerSecond: 10 }),
  ])
}

export default createConfig({
  ordering: 'multichain',
  // TODO: import supported chains from `gateway/src/ccip-read/query.ts`
  chains: {
    baseSepolia: {
      id: 84532,
      rpc: rpc(84532),
    },
    // arbitrumSepolia: {
    //   id: 421614,
    //   rpc: rpc(421614),
    // },
  },
  contracts: {
    durinFactory: {
      address: '0xFBd40321Bcf542Bd9199f1D68aB22e8083eA2f2B',
      abi: durinFactoryAbi,
      chain: {
        baseSepolia: { startBlock: 31703121 },
        // arbitrumSepolia: { startBlock: 199454358 },
      },
    },
    durin: {
      abi: durinAbi,
      address: factory({
        address: '0xFBd40321Bcf542Bd9199f1D68aB22e8083eA2f2B',
        event: parseAbiItem(
          'event RegistryDeployed(string name, address admin, address registry)'
        ),
        parameter: 'registry',
      }),
      chain: {
        baseSepolia: { startBlock: 31703121 },
        // arbitrumSepolia: { startBlock: 199454358 },
      },
    },
  },
})
