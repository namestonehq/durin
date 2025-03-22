// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @dev Interface for ERC-6492: Signature Validation for Predeploy Contracts
interface IUniversalSignatureValidator {
    function isValidSig(
        address _signer,
        bytes32 _hash,
        bytes calldata _signature
    ) external returns (bool);
}
