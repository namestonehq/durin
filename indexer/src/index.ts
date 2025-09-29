import { ponder } from 'ponder:registry'
import { registryDeployedEvent } from 'ponder:schema'

ponder.on('durinFactory:RegistryDeployed', async ({ event, context }) => {
  await context.db.insert(registryDeployedEvent).values({
    id: event.id,
    ...event.args,
  })
})
