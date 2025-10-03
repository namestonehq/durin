import { db } from 'ponder:api'
import schema, { resolver } from 'ponder:schema'
import { Hono } from 'hono'
import { and, client, eq, graphql } from 'ponder'
import { createPublicClient, http, namehash, parseAbi } from 'viem'
import { mainnet, sepolia } from 'viem/chains'
import { replaceBigInts } from '@ponder/utils'

const app = new Hono()

app.use('/sql/*', client({ db, schema }))

app.use('/', graphql({ db, schema }))
app.use('/graphql', graphql({ db, schema }))

const viemClient = createPublicClient({
  chain: sepolia,
  transport: http(process.env.RPC_URL),
})

app.get('/name/:name', async (c) => {
  const name = c.req.param('name')
  const twoLd = name.split('.').slice(0, 2).join('.')
  const twoLdNode = namehash(twoLd)
  const node = namehash(name)

  // Check which resolver the name uses via RPC
  const resolverAddress = await viemClient.getEnsResolver({ name: twoLd })

  try {
    // Check target chain and registry address via `l2Registry()` or via the latest `MetadataChanged` event
    const [, l2Registry] = await viemClient.readContract({
      address: resolverAddress,
      abi: parseAbi([
        'function l2Registry(bytes32 node) view returns (uint64, address)',
      ]),
      functionName: 'l2Registry',
      args: [twoLdNode],
    })

    // Find the available records for the name via the indexer
    const records = await db
      .select()
      .from(resolver)
      .where(and(eq(resolver.node, node), eq(resolver.address, l2Registry)))

    return c.json(replaceBigInts(records, (v) => v.toString()))
  } catch (error) {
    console.error(error)
    return c.json({ error: 'Name does not appear to use Durin' }, 400)
  }
})

export default app
