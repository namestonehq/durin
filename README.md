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

Once cloned modify [L2Registrar.sol](https://github.com/resolverworks/durin/blob/main/src/examples/L2Registrar.sol) as need it.

Durin uses [foundry](https://github.com/foundry-rs/foundry), to install follow the [instructions](https://book.getfoundry.sh/getting-started/installation).

### 4. Prepare .env

```shell
cp example.env .env
```

```env
# Required: RPC URL for the chain where the registry is deployed
RPC_URL=

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

Required: Private key of the deployer exclude "0x" (Same as used on durin.dev)

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
- [L2Registrar](./src/examples/L2Registrar.sol): An example registrar contract that can mint subnames. This is meant to be customized.

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

## Deploying Durin

1. In [DeployL2RegistryImplementation.s.sol](./scripts/DeployL2RegistryImplementation.s.sol), make sure the chains you want to deploy to are uncommented.
2. Run `./deploy/DeployL2RegistryImplementation.sh` to deploy the registry implementation to the specified chains.
3. Create a `.env` file via `cp example.env .env` and set `L2_REGISTRY_IMPLEMENTATION_ADDRESS` to the address of the deployed registry implementation.
4. (Optional) See [CREATE2 Tips](#create2-tips) for mining a vanity address.
5. In [DeployL2RegistryFactory.s.sol](./scripts/DeployL2RegistryFactory.s.sol), make sure the chains you want to deploy to are uncommented.
6. Run `./deploy/DeployL2RegistryFactory.sh` to deploy the registry factory to the specified chains.
7. Run `./deploy/VerifyL2RegistryImplementation.sh` and `./deploy/VerifyL2RegistryFactory.sh` a bunch of times to verify all the contracts you just deployed. Unfortunately forge's verification is flaky for multi-chain deployments.

### CREATE2 Tips

For generating a CREATE2 salt to deploy the registry factory, run the command below. Use [./scripts/L2RegistryFactoryInitCode.s.sol](./scripts/L2RegistryFactoryInitCode.s.sol) to calculate the init code hash, and [pcaversaccio/create2deployer](https://github.com/pcaversaccio/create2deployer) to deploy the contract.

```bash
export FACTORY="0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2"
export INIT_CODE_HASH="<HASH_OF_YOUR_CONTRACT_INIT_CODE_GOES_HERE>"
cast create2 --starts-with dddddd --deployer $FACTORY --init-code-hash $INIT_CODE_HASH
```

Once you have a salt that you're happy with, update `L2_REGISTRY_FACTORY_SALT` in `.env` so it's used in the deployment script.
