#!/bin/bash
source .env

echo "Building the project..."
forge build --force

echo "Deploying contracts..."

# --verify isn't working with --multi, so we need to verify each contract individually via `./VerifyL2Factory.sh`
forge script scripts/DeployL2RegistryFactory.s.sol:DeployL2RegistryFactory \
    --slow \
    --multi \
    --broadcast \
    --interactives 1 \
    -vvvv

