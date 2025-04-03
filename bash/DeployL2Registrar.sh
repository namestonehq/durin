#!/bin/bash
source .env

# Check if required variables are set
if [ -z "$ETHERSCAN_API_KEY" ] || [ -z "$L2_REGISTRY_ADDRESS" ] || [ -z "$L2_RPC_URL" ]; then
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
forge create \
    --rpc-url "${L2_RPC_URL}" \
    --verify \
    --etherscan-api-key "$ETHERSCAN_API_KEY" \
    --interactive \
    --broadcast \
    $CONTRACT_FILE:$CONTRACT_NAME \
    --constructor-args "$L2_REGISTRY_ADDRESS"

