// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Interface for ERC-6492: Signature Validation for Predeploy Contracts
/// @dev Can validate signatures signed with ERC-6492, ERC-1271, traditional ecrecover and EIP-712
interface IUniversalSignatureValidator {
    function isValidSig(
        address _signer,
        bytes32 _hash,
        bytes calldata _signature
    ) external returns (bool);
}
