// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ***********************************************
// ▗▖  ▗▖ ▗▄▖ ▗▖  ▗▖▗▄▄▄▖ ▗▄▄▖▗▄▄▄▖▗▄▖ ▗▖  ▗▖▗▄▄▄▖
// ▐▛▚▖▐▌▐▌ ▐▌▐▛▚▞▜▌▐▌   ▐▌     █ ▐▌ ▐▌▐▛▚▖▐▌▐▌
// ▐▌ ▝▜▌▐▛▀▜▌▐▌  ▐▌▐▛▀▀▘ ▝▀▚▖  █ ▐▌ ▐▌▐▌ ▝▜▌▐▛▀▀▘
// ▐▌  ▐▌▐▌ ▐▌▐▌  ▐▌▐▙▄▄▖▗▄▄▞▘  █ ▝▚▄▞▘▐▌  ▐▌▐▙▄▄▖
// ***********************************************

import {ABIResolver} from "@ensdomains/ens-contracts/resolvers/profiles/ABIResolver.sol";
import {AddrResolver} from "@ensdomains/ens-contracts/resolvers/profiles/AddrResolver.sol";
import {ContentHashResolver} from "@ensdomains/ens-contracts/resolvers/profiles/ContentHashResolver.sol";
import {ExtendedResolver} from "@ensdomains/ens-contracts/resolvers/profiles/ExtendedResolver.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Multicallable} from "@ensdomains/ens-contracts/resolvers/Multicallable.sol";
import {TextResolver} from "@ensdomains/ens-contracts/resolvers/profiles/TextResolver.sol";

import {IUniversalSignatureValidator} from "./interfaces/IUniversalSignatureValidator.sol";
import {L2Registry} from "./L2Registry.sol";

/// @title Durin Resolver
/// @author NameStone
/// @notice Resolver to store standard ENS records
/// @dev This contract is inherited by L2Registry, making registry methods available via `address(this)`
contract L2Resolver is
    Multicallable,
    ABIResolver,
    AddrResolver,
    ContentHashResolver,
    TextResolver,
    ExtendedResolver
{
    using MessageHashUtils for bytes32;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev ERC-6492: Signature Validation for Predeploy Contracts
    IUniversalSignatureValidator private immutable universalSignatureValidator =
        IUniversalSignatureValidator(
            0x164af34fAF9879394370C7f09064127C043A35E9
        );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized(bytes32 node);
    error SignatureExpired();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier unexpiredSignature(uint256 expiration) {
        if (block.timestamp > expiration) {
            revert SignatureExpired();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setAddrWithSignature(
        bytes32 node,
        uint256 coinType,
        bytes memory a,
        uint256 expiration,
        address signer,
        bytes calldata signature
    ) public unexpiredSignature(expiration) {
        bytes32 sigHash = keccak256(
            abi.encodePacked(address(this), node, coinType, a, expiration)
        ).toEthSignedMessageHash();

        if (
            !isAuthorisedForAddress(signer, node) ||
            !universalSignatureValidator.isValidSig(signer, sigHash, signature)
        ) {
            revert Unauthorized(node);
        }

        setAddr(node, coinType, a);
    }

    function setTextWithSignature(
        bytes32 node,
        string memory key,
        string memory value,
        uint256 expiration,
        address signer,
        bytes calldata signature
    ) public unexpiredSignature(expiration) {
        bytes32 sigHash = keccak256(
            abi.encodePacked(address(this), node, key, value, expiration)
        ).toEthSignedMessageHash();

        if (
            !isAuthorisedForAddress(signer, node) ||
            !universalSignatureValidator.isValidSig(signer, sigHash, signature)
        ) {
            revert Unauthorized(node);
        }

        // Manually update storage since `setText()` on the inherited contract cannot be called internally
        versionable_texts[recordVersions[node]][node][key] = value;
        emit TextChanged(node, key, key, value);
    }

    function setContenthashWithSignature(
        bytes32 node,
        bytes memory hash,
        uint256 expiration,
        address signer,
        bytes calldata signature
    ) public unexpiredSignature(expiration) {
        bytes32 sigHash = keccak256(
            abi.encodePacked(address(this), node, hash, expiration)
        ).toEthSignedMessageHash();

        if (
            !isAuthorisedForAddress(signer, node) ||
            !universalSignatureValidator.isValidSig(signer, sigHash, signature)
        ) {
            revert Unauthorized(node);
        }

        // Manually update storage since `setContenthash()` on the inherited contract cannot be called internally
        versionable_hashes[recordVersions[node]][node] = hash;
        emit ContenthashChanged(node, hash);
    }

    function setABIWithSignature(
        bytes32 node,
        uint256 contentType,
        bytes memory data,
        uint256 expiration,
        address signer,
        bytes calldata signature
    ) public unexpiredSignature(expiration) {
        bytes32 sigHash = keccak256(
            abi.encodePacked(address(this), node, contentType, data, expiration)
        ).toEthSignedMessageHash();

        if (
            !isAuthorisedForAddress(signer, node) ||
            !universalSignatureValidator.isValidSig(signer, sigHash, signature)
        ) {
            revert Unauthorized(node);
        }

        // Content types must be powers of 2
        require(((contentType - 1) & contentType) == 0);

        // Manually update storage since `setABI()` on the inherited contract cannot be called internally
        versionable_abis[recordVersions[node]][node][contentType] = data;
        emit ABIChanged(node, contentType);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _registry() internal view returns (L2Registry) {
        return L2Registry(address(this));
    }

    function isAuthorisedForAddress(
        address addr,
        bytes32 node
    ) internal view returns (bool) {
        L2Registry registry = _registry();

        if (registry.registrars(addr)) {
            return true;
        }

        uint256 tokenId = uint256(node);
        address owner = registry.ownerOf(tokenId);

        if ((owner != addr) && (registry.getApproved(tokenId) != addr)) {
            revert Unauthorized(node);
        }

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                           REQUIRED OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @dev Reverts instead of returning false so the modifier that uses this function has better error messages
    function isAuthorised(bytes32 node) internal view override returns (bool) {
        return isAuthorisedForAddress(msg.sender, node);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(
            Multicallable,
            ABIResolver,
            AddrResolver,
            ContentHashResolver,
            TextResolver
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
