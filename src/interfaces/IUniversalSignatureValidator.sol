// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUniversalSignatureValidator {
    function isValidSig(
        address _signer,
        bytes32 _hash,
        bytes calldata _signature
    ) external returns (bool);
}
