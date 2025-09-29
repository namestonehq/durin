// Implements the interfaces established in ENSIP-16
// https://github.com/ensdomains/ensips/blob/modify-ensip-16/ensips/16.md
import { onchainTable, relations } from 'ponder'

export const domain = onchainTable('domain', (t) => ({
  id: t.text().primaryKey(),
  // metadata (from relation)
}))

export const metadata = onchainTable('metadata', (t) => ({
  id: t.text().primaryKey(),
  name: t.text().notNull(),
  graphqlUrl: t.text().notNull(),
  chainId: t.bigint().notNull(),
  l2RegistryAddress: t.hex().notNull(),
}))

// Add `metadata` relation to the `domain` table
// https://ponder.sh/docs/query/graphql#relationship-fields
export const domainRelations = relations(domain, ({ one }) => ({
  metadata: one(metadata, { fields: [domain.id], references: [metadata.name] }),
}))

export const l2Domain = onchainTable('l2Domain', (t) => ({
  id: t.text().primaryKey(), // concatenation of context and namehash delimited by `-`
  context: t.hex(),
  name: t.text(),
  namehash: t.hex(),
  labelName: t.text(),
  labelhash: t.hex(),
  resolvedAddress: t.hex(), // addr(60)
  // parent (from relation)
  // subdomains (from relation)
  subdomainCount: t.integer(),
  // resolver (from relation)
  expiryDate: t.bigint(),
}))

// Add `parent` relation to the `l2Domain` table
export const l2DomainRelations = relations(l2Domain, ({ one, many }) => ({
  parent: one(l2Domain, {
    fields: [l2Domain.namehash],
    references: [l2Domain.namehash],
  }),
  subdomains: many(l2Domain),
}))

export const l2DomainSubdomains = relations(l2Domain, ({ one }) => ({
  subdomains: one(l2Domain, {
    fields: [l2Domain.namehash],
    references: [l2Domain.namehash],
  }),
}))

export const resolver = onchainTable('resolver', (t) => ({
  id: t.text().primaryKey(),
  node: t.hex(),
  context: t.hex(),
  address: t.hex(),
  // domain (from relation)
  addr: t.hex(),
  contentHash: t.hex(),
  texts: t.text().array(),
  coinTypes: t.bigint().array(),
}))

// Add `domain` relation to the `resolver` table
export const resolverRelations = relations(resolver, ({ one }) => ({
  domain: one(domain, { fields: [resolver.node], references: [domain.id] }),
}))

export const registryDeployedEvent = onchainTable(
  'registryDeployedEvent',
  (t) => ({
    id: t.text().primaryKey(),
    name: t.text().notNull(),
    admin: t.hex().notNull(),
    registry: t.hex().notNull(),
  })
)
