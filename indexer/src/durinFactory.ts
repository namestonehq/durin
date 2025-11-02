import { ponder } from 'ponder:registry'
import { l1Domain, registryDeployedEvent, resolver } from 'ponder:schema'
import { namehash } from 'viem'

ponder.on('durinFactory:RegistryDeployed', async ({ event, context }) => {
  await context.db.insert(registryDeployedEvent).values({
    id: event.id,
    ...event.args,
  })

  await context.db.insert(resolver).values({
    node: namehash(event.args.name),
    address: event.args.registry,
  })
})
