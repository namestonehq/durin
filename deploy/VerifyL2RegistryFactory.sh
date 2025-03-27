#!/bin/bash

# Load environment variables
source .env

# Verify on desired network (update network name as needed)
# Examples: arbitrum, optimism, base, etc.
NETWORK="base-sepolia"
BLOCK_EXPLORER_API_KEY="${BASESCAN_API_KEY}"

# Encode constructor arguments (bytes32 salt)
CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address)" "${L2_REGISTRY_IMPLEMENTATION_ADDRESS}")

echo "Constructor args: ${CONSTRUCTOR_ARGS}"
echo "Verifying contract..."

forge verify-contract \
    --chain "${NETWORK}" \
    --etherscan-api-key "${BLOCK_EXPLORER_API_KEY}" \
    --watch \
    --constructor-args "${CONSTRUCTOR_ARGS}" \
    "${L2_REGISTRY_FACTORY_ADDRESS}" \
    src/L2RegistryFactory.sol:L2RegistryFactory

echo "Verification submitted. Check status on the block explorer."

