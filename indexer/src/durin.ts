import { ponder } from 'ponder:registry'
import { l2Domain, registryDeployedEvent, resolver } from 'ponder:schema'
import { namehash } from 'viem'
import { makeNode } from './lib/utils'

ponder.on('durin:NewSubname', async ({ event, context }) => {
  const registry = event.log.address
  const parent = await context.db.find(registryDeployedEvent, { registry })

  if (!parent) {
    throw new Error('Parent registry not found')
  }

  // await context.db.insert(l2Domain).values({
  //   id: event.id,
  //   context: undefined,
  //   name: undefined,
  //   namehash: undefined,
  //   labelName: event.args.label,
  //   labelhash: event.args.labelhash,
  //   resolvedAddress: undefined,
  //   subdomainCount: 0,
  //   expiryDate: undefined,
  // })

  const node = makeNode({
    parentNode: namehash(parent.name),
    labelHash: event.args.labelhash,
  })

  await context.db.insert(resolver).values({
    node,
    address: registry,
  })
})

ponder.on('durin:AddrChanged', async ({ event, context }) => {
  const registry = event.log.address
  const { node, a } = event.args

  await context.db.update(resolver, { address: registry, node }).set({
    addr: a,
  })
})

ponder.on('durin:AddressChanged', async ({ event, context }) => {
  const registry = event.log.address
  const { node, coinType } = event.args

  await context.db.update(resolver, { address: registry, node }).set((row) => ({
    coinTypes: [...(row.coinTypes ?? []), coinType],
  }))
})

ponder.on('durin:TextChanged', async ({ event, context }) => {
  const registry = event.log.address
  const { node, key } = event.args

  await context.db.update(resolver, { address: registry, node }).set((row) => ({
    texts: [...(row.texts ?? []), key],
  }))
})

ponder.on('durin:ContenthashChanged', async ({ event, context }) => {
  const registry = event.log.address
  const { node, hash } = event.args

  await context.db.update(resolver, { address: registry, node }).set({
    contentHash: hash,
  })
})
