# <img src="https://github.com/user-attachments/assets/4f01ef6e-3c1e-4201-83db-fac4b383a3b0" alt="durin" width="33%">

Durin is an opinionated approach to ENS L2 subnames. Durin consists of:

1. Registry factory on [supported chains](#active-registry-factory-deployments)
2. Registrar template
3. Gateway server

# Instructions To Deploy L2 ENS Subnames

This repo is meant to be used in conjuction with [Durin.dev](https://durin.dev/), which provides a frontend for deploying the registry & enabling name resolution.

### 1. Deploy Instance of Registry

Go to [Durin.dev](https://durin.dev/). Choose Sepolia or Mainnet ENS name resolution. Pick a supported L2 -- either mainnet or sepolia. Deploy.

Once complete note the deployed registry address on the L2.

## 2. Enable Name Resolution

To enable name resolution, change the resolver on the ENS name.

```
sepolia: 0x00f9314C69c3e7C37b3C7aD36EF9FB40d94eDDe1
mainnet: 0x2A6C785b002Ad859a3BAED69211167C7e998aAeC
```

After switching the resolver, add the following text record:

```
key: registry
value: {chain_id}:{registry_contract}
```

Both switching the resolver and adding the text record can be done via durin.dev or the ENS manager app.

### 3. Customize Registrar Template

Durin provides a registrar template designed for customization. Common customizations include adding pricing, implementing allow lists, and enabling token gating.

To get started
clone this repo:

```shell
git clone git@github.com:resolverworks/durin.git
cd durin
```

Once cloned modify [L2Registrar.sol](https://github.com/resolverworks/durin/blob/main/src/L2Registrar.sol) as need it.

Durin uses [foundry](https://github.com/foundry-rs/foundry), to install follow the [instructions](https://book.getfoundry.sh/getting-started/installation).

### 4. Prepare .env

```shell
cp example.env .env
```

```env
# Required: RPC URL for the chain where the registry is deployed
RPC_URL=

# Required: Private key of the deployer exclude "0x" (Same as used on durin.dev)
PRIVATE_KEY=

# Required: Etherscan API key for contract verification
ETHERSCAN_API_KEY=

# Required for L2Registrar contract deployment
REGISTRY_ADDRESS=

# Required to configure the deployed registry from durin.dev website. Add this after deploying the Registrar.
REGISTRAR_ADDRESS=Blank until step 5
```

### 5. Deploy L2Registrar Contract

```shell
bash deploy/deployL2Registrar.sh
```

**Update Registrar address in .env**

### 6. Connect Registrar to L2Registry

Only the Registrar can call `register()` on the Registry. The owner of the registry can add a registrar thus enabling minting. The [configureRegistry.sh](https://github.com/resolverworks/durin/blob/main/deploy/configureRegistry.sh) script adds the Registrar to the Registry by calling the `addRegistrar()`

```shell
bash deploy/configureRegistry.sh
```

## Contracts

This repo includes the L2 contracts required to enable subname issuance.

- [L2RegistryFactory](./src/L2RegistryFactory.sol): L2 contract for creating new registries.
- [L2Registry](./src/L2Registry.sol): L2 contract that stores subnames as ERC721 NFTs.
  It's responsible for storing subname data like address and text records.
- [L2Registrar](./src/L2Registrar.sol): An example registrar contract that can mint subnames. This is meant to be customized.

## Active Registry Factory Deployments

| L2               | Registry Factory                                                                                                                         |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Base             | [`0xA59eF1DCc0c4bcbDC718b95c0680b6B97Bb451eb`](https://basescan.org/address/0xA59eF1DCc0c4bcbDC718b95c0680b6B97Bb451eb)                  |
| Base Sepolia     | [`0xA59eF1DCc0c4bcbDC718b95c0680b6B97Bb451eb`](https://sepolia.basescan.org/address/0xA59eF1DCc0c4bcbDC718b95c0680b6B97Bb451eb)          |
| Optimism         | [`0xA59eF1DCc0c4bcbDC718b95c0680b6B97Bb451eb`](https://optimistic.etherscan.io/address/0xA59eF1DCc0c4bcbDC718b95c0680b6B97Bb451eb)       |
| Optimism Sepolia | [`0xA59eF1DCc0c4bcbDC718b95c0680b6B97Bb451eb`](https://sepolia-optimism.etherscan.io/address/0xA59eF1DCc0c4bcbDC718b95c0680b6B97Bb451eb) |
| Scroll           | [`0xA59eF1DCc0c4bcbDC718b95c0680b6B97Bb451eb`](https://scrollscan.com/address/0xA59eF1DCc0c4bcbDC718b95c0680b6B97Bb451eb)                |
| Scroll Sepolia   | [`0xA59eF1DCc0c4bcbDC718b95c0680b6B97Bb451eb`](https://sepolia-blockscout.scroll.io/address/0xA59eF1DCc0c4bcbDC718b95c0680b6B97Bb451eb)  |
| Arbitrum         | [`0xA59eF1DCc0c4bcbDC718b95c0680b6B97Bb451eb`](https://arbiscan.io/address/0xA59eF1DCc0c4bcbDC718b95c0680b6B97Bb451eb)                   |
| Arbitrum Sepolia | [`0xA59eF1DCc0c4bcbDC718b95c0680b6B97Bb451eb`](https://sepolia.arbiscan.io/address/0xA59eF1DCc0c4bcbDC718b95c0680b6B97Bb451eb)           |
| Linea            | [`0xA59eF1DCc0c4bcbDC718b95c0680b6B97Bb451eb`](https://lineascan.build/address/0xA59eF1DCc0c4bcbDC718b95c0680b6B97Bb451eb)               |
| Linea Sepolia    | [`0xA59eF1DCc0c4bcbDC718b95c0680b6B97Bb451eb`](https://sepolia.lineascan.build/address/0xA59eF1DCc0c4bcbDC718b95c0680b6B97Bb451eb)       |

## Architecture

![architecture](https://github.com/user-attachments/assets/06065784-0516-498e-a512-d7b63892599a)

> [!NOTE]  
> A dependency for supporting new chains is a deployment of UniversalSigValidator to `0x164af34fAF9879394370C7f09064127C043A35E9`. The deployment is permissionless and can be found [here](https://github.com/ensdomains/ens-contracts/blob/8c414e4c41dce49c49efd0bf82c10a145cdc8f0a/deploy/utils/00_deploy_universal_sig_validator.ts).
