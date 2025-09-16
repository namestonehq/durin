// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @dev Implements ERC-7884
interface IOperationRouter {
    /// @dev Error to raise when mutations are being deferred onchain, that being the layer 1 or a layer 2
    /// @param chainId Chain ID to perform the deferred mutation to.
    /// @param contractAddress Contract Address at which the deferred mutation should transact with.
    error OperationHandledOnchain(uint256 chainId, address contractAddress);

    /// @notice Determines the appropriate handler for an encoded function call
    /// @param encodedFunction The ABI encoded function call
    function getOperationHandler(bytes calldata encodedFunction) external view;
}
