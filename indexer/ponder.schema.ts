import { onchainTable } from 'ponder'

export const registryDeployedEvent = onchainTable(
  'registryDeployedEvent',
  (t) => ({
    id: t.text().primaryKey(),
    name: t.text().notNull(),
    admin: t.hex().notNull(),
    registry: t.hex().notNull(),
  })
)
