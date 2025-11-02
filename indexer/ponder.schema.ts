// Implements the interfaces established in ENSIP-16
// https://github.com/ensdomains/ensips/blob/modify-ensip-16/ensips/16.md
import { onchainTable, primaryKey, relations } from 'ponder'

export const l1Domain = onchainTable('l1Domain', (t) => ({
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

export const l2DomainSubdomains = relations(l2Domain, ({ one }) => ({
  subdomains: one(l2Domain, {
    fields: [l2Domain.namehash],
    references: [l2Domain.namehash],
  }),
}))

export const resolver = onchainTable(
  'resolver',
  (t) => ({
    // id: t.text().primaryKey(), // concatenation of address and node delimited by `-`
    node: t.hex().notNull(),
    address: t.hex().notNull(),
    // domain (from relation)
    addr: t.hex(),
    contentHash: t.hex(),
    texts: t.text().array(),
    coinTypes: t.bigint().array(),
  }),
  (table) => ({
    pk: primaryKey({ columns: [table.address, table.node] }),
  })
)

/////////////////////////
// RELATIONS
// https://ponder.sh/docs/query/graphql#relationship-fields
////////////////////////

// Add `metadata` relation to the `domain` table
export const l1DomainRelations = relations(l1Domain, ({ one }) => ({
  metadata: one(metadata, {
    fields: [l1Domain.id],
    references: [metadata.name],
  }),
}))

// Add `parent` relation to the `l2Domain` table
export const l2DomainRelations = relations(l2Domain, ({ one, many }) => ({
  parent: one(l2Domain, {
    fields: [l2Domain.namehash],
    references: [l2Domain.namehash],
  }),
  subdomains: many(l2Domain),
}))

// Add `domain` relation to the `resolver` table
export const resolverRelations = relations(resolver, ({ one }) => ({
  domain: one(l1Domain, { fields: [resolver.node], references: [l1Domain.id] }),
}))

/////////////////////////
// EVENTS
////////////////////////

export const registryDeployedEvent = onchainTable(
  'registryDeployedEvent',
  (t) => ({
    // id: t.text().primaryKey(),
    name: t.text().notNull(),
    admin: t.hex().notNull(),
    registry: t.hex().primaryKey(),
  })
)

export const metadataChangedEvent = onchainTable(
  'metadataChangedEvent',
  (t) => ({
    id: t.text().primaryKey(),
    name: t.text().notNull(),
    graphqlUrl: t.text().notNull(),
    chainId: t.bigint().notNull(),
    l2RegistryAddress: t.hex().notNull(),
  })
)
