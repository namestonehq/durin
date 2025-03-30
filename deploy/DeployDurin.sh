#!/bin/bash
source .env

echo "Building the project..."
forge build --force

echo "Deploying contracts..."

# --verify isn't working with --multi, so we need to verify each contract individually via 
# `./VerifyL2Factory.sh` and `./VerifyL2RegistryImplementation.sh`
forge script scripts/DeployDurin.s.sol:DeployDurin \
    --slow \
    --multi \
    --broadcast \
    --interactives 1 \
    -vvvv

