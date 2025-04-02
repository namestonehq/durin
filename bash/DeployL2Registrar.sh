#!/bin/bash

# Load environment variables
source .env

# Check if required variables are set
if [ -z "$ETHERSCAN_API_KEY" ] || [ -z "$RPC_URL" ] || [ -z "$REGISTRY_ADDRESS" ]; then
    echo "Error: Missing required environment variables. Please check your .env file."
    exit 1
fi

# Set contract details
CONTRACT_NAME="L2Registrar"
CONTRACT_FILE="src/examples/L2Registrar.sol"

# Build the project
echo "Building the project..."
forge build

# Deploy the contract
echo "Deploying $CONTRACT_NAME from $CONTRACT_FILE..."
DEPLOYED_OUTPUT=$(ETHERSCAN_API_KEY=$ETHERSCAN_API_KEY forge create \
    --rpc-url $RPC_URL \
    --verify \
    --legacy \
    --interactive \
    --broadcast \
    $CONTRACT_FILE:$CONTRACT_NAME \
    --constructor-args $REGISTRY_ADDRESS \
   
    --json)

echo "$DEPLOYED_OUTPUT"