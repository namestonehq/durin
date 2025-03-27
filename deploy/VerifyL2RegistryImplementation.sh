#!/bin/bash

# Load environment variables
source .env

# Verify on desired network (update network name as needed)
# Examples: arbitrum, optimism, base, etc.
NETWORK="base-sepolia"
BLOCK_EXPLORER_API_KEY="${BASESCAN_API_KEY}"

# Run verification
echo "Verifying contract..."
forge verify-contract \
    --chain "${NETWORK}" \
    --etherscan-api-key "${BLOCK_EXPLORER_API_KEY}" \
    --watch \
    "${L2_REGISTRY_IMPLEMENTATION_ADDRESS}" \
    src/L2Registry.sol:L2Registry

# Check verification status
echo "Verification submitted. Check status on the block explorer."

