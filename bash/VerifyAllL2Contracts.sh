#!/usr/local/bin/bash
source .env

if [ -z "$L2_REGISTRY_IMPLEMENTATION_ADDRESS" ] || [ -z "$L2_REGISTRY_FACTORY_ADDRESS" ]; then
    echo "Error: L2_REGISTRY_IMPLEMENTATION_ADDRESS and L2_REGISTRY_FACTORY_ADDRESS must be set"
    exit 1
fi

# Define networks and their corresponding API keys
declare -A NETWORK_API_KEYS=(

    ["base-sepolia"]="${BASE_API_KEY}"
    ["base"]="${BASE_API_KEY}"
    ["optimism-sepolia"]="${OPTIMISM_API_KEY}"
    ["optimism"]="${OPTIMISM_API_KEY}"
    ["polygon-amoy"]="${POLYGON_API_KEY}"
    ["polygon"]="${POLYGON_API_KEY}"
    ["world-sepolia"]="${WORLDCHAIN_API_KEY}"
    ["world"]="${WORLDCHAIN_API_KEY}"
    ["celo-sepolia"]="${CELO_API_KEY}"
    ["celo"]="${CELO_API_KEY}"
    ["linea-sepolia"]="${LINEA_API_KEY}"
    ["linea"]="${LINEA_API_KEY}"
    ["scroll-sepolia"]="${SCROLL_API_KEY}"
    ["scroll"]="${SCROLL_API_KEY}"
    ["arbitrum-sepolia"]="${ARBITRUM_API_KEY}"
    ["arbitrum"]="${ARBITRUM_API_KEY}"
    
    # Add more networks and their API keys as needed
)
# DEBUG: Print all keys and assigned values after declaration
echo "DEBUG: Associative array contents:"
for K in "${!NETWORK_API_KEYS[@]}"; do
    echo "  ${K}: ${NETWORK_API_KEYS[$K]}"
done
echo "----------------------------------------"

# DEBUG: Check specific values from env
echo "DEBUG: BASE_API_KEY value from env: ${BASE_API_KEY}"
echo "DEBUG: ARBITRUM_API_KEY value from env: ${ARBITRUM_API_KEY}"
echo "----------------------------------------"

# Loop through each network and verify contracts
for NETWORK in "${!NETWORK_API_KEYS[@]}"; do
    echo "Verifying contracts on ${NETWORK}..."
    echo "NETWORK_API_KEYS[$NETWORK]: ${NETWORK_API_KEYS[$NETWORK]}"
    BLOCK_EXPLORER_API_KEY="${NETWORK_API_KEYS[$NETWORK]}"
    echo "BLOCK_EXPLORER_API_KEY: ${BLOCK_EXPLORER_API_KEY}"

    # Verify L2Registry
    echo "Verifying L2Registry..."
    forge verify-contract \
        --chain "${NETWORK}" \
        --etherscan-api-key "${BLOCK_EXPLORER_API_KEY}" \
        --watch \
        "${L2_REGISTRY_IMPLEMENTATION_ADDRESS}" \
        src/L2Registry.sol:L2Registry

    FACTORY_CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address)" "${L2_REGISTRY_IMPLEMENTATION_ADDRESS}")

    # Verify L2RegistryFactory
    echo "Verifying L2RegistryFactory..."
    forge verify-contract \
        --chain "${NETWORK}" \
        --etherscan-api-key "${BLOCK_EXPLORER_API_KEY}" \
        --watch \
        --constructor-args "${FACTORY_CONSTRUCTOR_ARGS}" \
        "${L2_REGISTRY_FACTORY_ADDRESS}" \
        src/L2RegistryFactory.sol:L2RegistryFactory

    echo "Completed verification on ${NETWORK}"
    echo "----------------------------------------"
done 