#!/bin/bash
source .env

if [ -z "$L1_RESOLVER_URL" ] || [ -z "$L1_RESOLVER_SIGNER" ] || [ -z "$L1_RESOLVER_OWNER" ] || [ -z "$L1_RESOLVER_ADDRESS" ]; then
    echo "Error: All environment variables that start with L1_RESOLVER_ must be set"
    exit 1
fi

# Verify on desired network ("mainnet" or "sepolia")
NETWORK="sepolia"

# Encode constructor arguments (string, address)
CONSTRUCTOR_ARGS=$(cast abi-encode \
    "constructor(string, address, address)" \
    "${L1_RESOLVER_URL}" \
    "${L1_RESOLVER_SIGNER}" \
    "${L1_RESOLVER_OWNER}" \
)

forge verify-contract \
    --chain "${NETWORK}" \
    --etherscan-api-key "${ETHERSCAN_API_KEY}" \
    --watch \
    --constructor-args "${CONSTRUCTOR_ARGS}" \
    "${L1_RESOLVER_ADDRESS}" \
    src/L1Resolver.sol:L1Resolver

