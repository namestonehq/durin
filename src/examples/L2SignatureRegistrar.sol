// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import {IL2Registry} from "../interfaces/IL2Registry.sol";
import {IL2Resolver} from "../interfaces/IL2Resolver.sol";

/// @dev This is an example registrar contract that is meant to be modified.
///      It lets anyone submit record updates that were signed by an address authorised for a name, so the signer
///      doesn't need to send a transaction.
contract L2SignatureRegistrar is EIP712, Nonces {
    /// @notice EIP-712 typehash for a batch of record updates
    bytes32 public constant SET_RECORDS_TYPEHASH =
        keccak256(
            "SetRecords(bytes32 node,bytes[] data,uint256 nonce,uint256 deadline)"
        );

    bytes4 private constant SET_ADDR =
        bytes4(keccak256("setAddr(bytes32,address)"));
    bytes4 private constant SET_ADDR_WITH_COIN_TYPE =
        bytes4(keccak256("setAddr(bytes32,uint256,bytes)"));

    /// @notice Reference to the target registry contract
    IL2Registry public immutable registry;

    /// @notice Thrown when the signature's deadline has passed
    error SignatureExpired();

    /// @notice Thrown when the signature is not valid for the signer
    error InvalidSignature();

    /// @notice Thrown when the signer is not authorised to update the records of the node
    error Unauthorized(address signer, bytes32 node);

    /// @notice Thrown when a call is not one of the registry's record setters
    error UnsupportedCall(bytes4 selector);

    /// @notice Thrown when a call is for a different node than the one that was signed
    error NodeMismatch(bytes32 callNode);

    /// @notice Initializes the registrar with a registry contract
    /// @param _registry Address of the L2Registry contract
    constructor(address _registry) EIP712("Durin Signature Registrar", "1") {
        registry = IL2Registry(_registry);
    }

    /// @notice Updates the records of a node with a signature from an address authorised for it
    /// @param node The node to update
    /// @param data Calls to the registry's record setters for `node`, e.g. `abi.encodeCall(IL2Resolver.setText, (node, key, value))`
    /// @param deadline Timestamp after which the signature is no longer valid
    /// @param signer The owner of the node, an operator approved by the owner or the address approved for the token
    /// @param signature EIP-712 signature of `SetRecords(node, data, nonces(signer), deadline)` from an EOA or ERC-1271 contract
    function setRecords(
        bytes32 node,
        bytes[] calldata data,
        uint256 deadline,
        address signer,
        bytes calldata signature
    ) external {
        if (block.timestamp > deadline) {
            revert SignatureExpired();
        }

        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    SET_RECORDS_TYPEHASH,
                    node,
                    _hashData(data),
                    _useNonce(signer),
                    deadline
                )
            )
        );

        if (!SignatureChecker.isValidSignatureNow(signer, digest, signature)) {
            revert InvalidSignature();
        }

        if (!_isAuthorised(signer, node)) {
            revert Unauthorized(signer, node);
        }

        // Call the registry directly instead of via `multicallWithNodeCheck()` so revert reasons are bubbled up
        for (uint256 i = 0; i < data.length; i++) {
            bytes4 selector = bytes4(data[i][:4]);
            if (!_isRecordSetter(selector)) {
                revert UnsupportedCall(selector);
            }

            // Every record setter takes the node as its first argument
            bytes32 callNode = bytes32(data[i][4:36]);
            if (callNode != node) {
                revert NodeMismatch(callNode);
            }

            Address.functionCall(address(registry), data[i]);
        }
    }

    /// @notice Invalidates the caller's outstanding signatures by incrementing their nonce
    function invalidateNonce() external {
        _useNonce(msg.sender);
    }

    /// @dev Mirrors the registry's authorisation for record updates, excluding registrars
    function _isAuthorised(
        address signer,
        bytes32 node
    ) private view returns (bool) {
        uint256 tokenId = uint256(node);
        address owner = registry.ownerOf(tokenId);

        return
            signer == owner ||
            registry.isApprovedForAll(owner, signer) ||
            registry.getApproved(tokenId) == signer;
    }

    function _isRecordSetter(bytes4 selector) private pure returns (bool) {
        return
            selector == SET_ADDR ||
            selector == SET_ADDR_WITH_COIN_TYPE ||
            selector == IL2Resolver.setText.selector ||
            selector == IL2Resolver.setContenthash.selector ||
            selector == IL2Resolver.setABI.selector;
    }

    /// @dev EIP-712 encoding of `bytes[]`: the hash of the concatenated hashes of each element
    function _hashData(bytes[] calldata data) private pure returns (bytes32) {
        bytes32[] memory hashes = new bytes32[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            hashes[i] = keccak256(data[i]);
        }
        return keccak256(abi.encodePacked(hashes));
    }
}
