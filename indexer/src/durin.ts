import { ponder } from 'ponder:registry'
import { l2Domain } from 'ponder:schema'

ponder.on('durin:NewSubname', async ({ event, context }) => {
  await context.db.insert(l2Domain).values({
    id: event.id,
    context: undefined,
    name: undefined,
    namehash: undefined,
    labelName: event.args.label,
    labelhash: event.args.labelhash,
    resolvedAddress: undefined,
    subdomainCount: 0,
    expiryDate: undefined,
  })
})

ponder.on('durin:AddrChanged', async ({ event, context }) => {
  await context.db.update(l2Domain, { id: '0x123' }).set({})
})
