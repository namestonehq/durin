#!/bin/bash

# Load environment variables
source .env

# Check if required variables are set
if [ -z "$CONTRACT_SYMBOL" ] || [ -z "$ETHERSCAN_API_KEY" ] || [ -z "$RPC_URL" ] || [ -z "$BASE_URI" ] || [ -z "$FACTORY_ADDRESS" ]; then
    echo "Error: Missing required environment variables. Please check your .env file."
    exit 1
fi

echo "Deployment Configuration:"
echo "- Factory Address: $FACTORY_ADDRESS"
echo "- Contract Name: L2Registry"
echo "- Contract Symbol: $CONTRACT_SYMBOL"
echo "- Base URI: $BASE_URI"
echo "- RPC URL is set: ✓"
echo "- Etherscan API Key is set: ✓"

# Build the project
echo "Building the project..."
forge build

# Call the factory's deployRegistry function
echo "Deploying L2 Registry using factory..."
cast send --rpc-url $RPC_URL \
    --legacy \
    --interactive 1 \
    $FACTORY_ADDRESS \
    "deployRegistry(string,string,string)(address)" \
    "$CONTRACT_NAME" \
    "$CONTRACT_SYMBOL" \
    "$BASE_URI"