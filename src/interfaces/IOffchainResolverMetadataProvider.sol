// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Metadata discovery for offchain names, as specified by ENSIP-16.
interface IOffchainResolverMetadataProvider {
    /// @notice Returns metadata for discovering the location of offchain name data.
    /// @param name DNS-encoded name to query.
    /// @return rpcUrls JSON-RPC endpoints for querying offchain data (may be empty).
    /// @return chainId The chain ID where the data is stored (0 for non-EVM sources).
    /// @return baseRegistry The base registry on the target chain that emits events (may be zero).
    function metadata(
        bytes calldata name
    )
        external
        view
        returns (
            string[] memory rpcUrls,
            uint256 chainId,
            address baseRegistry
        );

    /// @notice Emitted when the metadata for a name is changed.
    event MetadataChanged(
        bytes name,
        string[] rpcUrls,
        uint256 chainId,
        address baseRegistry
    );
}
