#!/bin/bash
source .env

# Check required env vars
if [ -z "$ETHERSCAN_API_KEY" ]; then
    echo "Error: ETHERSCAN_API_KEY is not set"
    exit 1
fi

echo "Deployment Configuration:"
echo "- Etherscan API Key is set: ✓"

echo "Building the project..."
forge build --force

echo "Deploying contracts..."

forge script scripts/DeployFactory.s.sol:DeployFactory \
    --slow \
    --multi \
    --broadcast \
    --verify \
    --interactives 1 \
    -vvvv
