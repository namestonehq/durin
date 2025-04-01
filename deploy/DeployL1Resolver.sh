#!/bin/bash
source .env

forge build --force

NETWORK="sepolia"
RPC_URL="https://ethereum-sepolia-rpc.publicnode.com"

forge script scripts/DeployL1Resolver.s.sol:DeployL1Resolver \
    --chain "${NETWORK}" \
    --rpc-url "${RPC_URL}" \
    --broadcast \
    --interactives 1 \
    -vvvv

