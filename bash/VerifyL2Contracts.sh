#!/bin/bash
source .env

if [ -z "$L2_REGISTRY_IMPLEMENTATION_ADDRESS" ] || [ -z "$L2_REGISTRY_FACTORY_ADDRESS" ]; then
    echo "Error: L2_REGISTRY_IMPLEMENTATION_ADDRESS and L2_REGISTRY_FACTORY_ADDRESS must be set"
    exit 1
fi

# Verify on desired network (update network to desired network from foundry.toml)
NETWORK="base-sepolia"
BLOCK_EXPLORER_API_KEY="${BASESCAN_API_KEY}"

# Verify L2Registry
forge verify-contract \
    --chain "${NETWORK}" \
    --etherscan-api-key "${BLOCK_EXPLORER_API_KEY}" \
    --watch \
    "${L2_REGISTRY_IMPLEMENTATION_ADDRESS}" \
    src/L2Registry.sol:L2Registry

FACTORY_CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address)" "${L2_REGISTRY_IMPLEMENTATION_ADDRESS}")

# Verify L2RegistryFactory
forge verify-contract \
    --chain "${NETWORK}" \
    --etherscan-api-key "${BLOCK_EXPLORER_API_KEY}" \
    --watch \
    --constructor-args "${FACTORY_CONSTRUCTOR_ARGS}" \
    "${L2_REGISTRY_FACTORY_ADDRESS}" \
    src/L2RegistryFactory.sol:L2RegistryFactory

