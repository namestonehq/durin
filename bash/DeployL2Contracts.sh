#!/bin/bash
source .env

if [ -z "$CREATE2_DEPLOYER_ADDRESS" ] || [ -z "$L2_REGISTRY_IMPLEMENTATION_ADDRESS" ] || [ -z "$L2_REGISTRY_FACTORY_SALT" ]; then
    echo "Error: CREATE2_DEPLOYER_ADDRESS, L2_REGISTRY_IMPLEMENTATION_ADDRESS, and L2_REGISTRY_FACTORY_SALT must be set"
    exit 1
fi

echo "Building the project..."
forge build --force

echo "Deploying contracts..."

forge script scripts/DeployL2Contracts.s.sol:DeployL2Contracts \
    --slow \
    --multi \
    --broadcast \
    --interactives 1 \
    -vvvv

