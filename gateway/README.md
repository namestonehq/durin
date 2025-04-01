# CCIP Read Gateway

[CCIP Read](https://eips.ethereum.org/EIPS/eip-3668) provides a mechanism to allow a smart contract to fetch external data. This example is built specifically for the contracts in this monorepo.

## Run Locally

1. Navigate to this directory: `cd gateway`
2. Install dependencies: `bun install`
3. Set your environment variables: `cp .env.example .env` (this is the private key for one of the addresses listed as a signer on your resolver contract)
4. Start the dev server: `bun dev`
