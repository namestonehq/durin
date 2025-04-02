#!/bin/bash
source .env

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

