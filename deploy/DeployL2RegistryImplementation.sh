#!/bin/bash
source .env

echo "Building the project..."
forge build --force

echo "Deploying contracts..."

# --verify isn't working with --multi, so we need to verify each contract individually via `./VerifyL2Registry.sh`
forge script scripts/DeployL2RegistryImplementation.s.sol:DeployL2RegistryImplementation \
    --slow \
    --multi \
    --broadcast \
    --interactives 1 \
    -vvvv

