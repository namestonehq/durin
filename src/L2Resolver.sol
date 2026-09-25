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
import {COIN_TYPE_DEFAULT, COIN_TYPE_ETH, ENSIP19} from "@ensdomains/ens-contracts/utils/ENSIP19.sol";
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
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Signature nonce for each node, consumed by the `*WithSignature` methods to prevent replays
    mapping(bytes32 node => uint256 nonce) public nonces;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized(bytes32 node);
    error SignatureExpired();
    error InvalidContentType(uint256 contentType);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier unexpiredSignature(uint256 expiration) {
        _unexpiredSignature(expiration);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // The `*WithSignature` methods allow anyone to submit a record update that was signed by an address authorised
    // for `node`. The signer must sign (ERC-191 `personal_sign`) the keccak256 hash of:
    //
    //   abi.encode(bytes4 selector, uint256 chainId, address registry, bytes32 node, bytes recordArgs,
    //              uint256 expiration, uint256 nonce)
    //
    // where `selector` is the selector of the `*WithSignature` method being called, `recordArgs` is the ABI encoding
    // of the record-specific arguments (e.g. `abi.encode(key, value)` for `setTextWithSignature`) and `nonce` is
    // `nonces(node)`. Each successful call increments `nonces(node)`, so a signature can only be used once.

    function setAddrWithSignature(
        bytes32 node,
        uint256 coinType,
        bytes memory a,
        uint256 expiration,
        address signer,
        bytes calldata signature
    ) public unexpiredSignature(expiration) {
        _verifySignature(
            this.setAddrWithSignature.selector,
            node,
            abi.encode(coinType, a),
            expiration,
            signer,
            signature
        );

        // Manually update storage since `setAddr()` on the inherited contract checks `msg.sender` instead of `signer`
        if (
            a.length != 0 && a.length != 20 && ENSIP19.isEVMCoinType(coinType)
        ) {
            revert InvalidEVMAddress(a);
        }
        emit AddressChanged(node, coinType, a);
        if (coinType == COIN_TYPE_ETH) {
            emit AddrChanged(node, address(bytes20(a)));
        }
        versionable_addresses[recordVersions[node]][node][coinType] = a;
    }

    function setTextWithSignature(
        bytes32 node,
        string memory key,
        string memory value,
        uint256 expiration,
        address signer,
        bytes calldata signature
    ) public unexpiredSignature(expiration) {
        _verifySignature(
            this.setTextWithSignature.selector,
            node,
            abi.encode(key, value),
            expiration,
            signer,
            signature
        );

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
        _verifySignature(
            this.setContenthashWithSignature.selector,
            node,
            abi.encode(hash),
            expiration,
            signer,
            signature
        );

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
        // Content types must be powers of 2
        if (contentType == 0 || ((contentType - 1) & contentType) != 0) {
            revert InvalidContentType(contentType);
        }

        _verifySignature(
            this.setABIWithSignature.selector,
            node,
            abi.encode(contentType, data),
            expiration,
            signer,
            signature
        );

        // Manually update storage since `setABI()` on the inherited contract cannot be called internally
        versionable_abis[recordVersions[node]][node][contentType] = data;
        emit ABIChanged(node, contentType);
    }

    /// Override the inherited function to support default EVM address
    /// @inheritdoc AddrResolver
    function addr(
        bytes32 node,
        uint256 coinType
    ) public view override returns (bytes memory addressBytes) {
        addressBytes = super.addr(node, coinType);

        // Lookup default EVM address if no address is found
        if (
            addressBytes.length == 0 && ENSIP19.chainFromCoinType(coinType) > 0
        ) {
            addressBytes = super.addr(node, COIN_TYPE_DEFAULT);
        }
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Registrars are authorised for every node in the registry. Otherwise, the owner of the node, an operator
    ///      approved via `setApprovalForAll()` or the address approved for the token via `approve()` is authorised.
    function _isAuthorisedForAddress(
        address _addr,
        bytes32 _node
    ) internal view returns (bool) {
        L2Registry registry = _registry();

        if (registry.registrars(_addr)) {
            return true;
        }

        uint256 tokenId = uint256(_node);
        address owner = registry.ownerOf(tokenId);

        if (
            owner != _addr &&
            !registry.isApprovedForAll(owner, _addr) &&
            registry.getApproved(tokenId) != _addr
        ) {
            revert Unauthorized(_node);
        }

        return true;
    }

    function _registry() internal view returns (L2Registry) {
        return L2Registry(address(this));
    }

    function _unexpiredSignature(uint256 expiration) internal view {
        if (block.timestamp > expiration) {
            revert SignatureExpired();
        }
    }

    /// @dev Consumes the nonce for `node` and reverts unless `signature` is valid for the record update.
    ///      See the comment above the `*WithSignature` methods for the message format.
    function _verifySignature(
        bytes4 selector,
        bytes32 node,
        bytes memory recordArgs,
        uint256 expiration,
        address signer,
        bytes calldata signature
    ) private {
        bytes32 message = keccak256(
            abi.encode(
                selector,
                block.chainid,
                address(this),
                node,
                recordArgs,
                expiration,
                nonces[node]++
            )
        );

        if (
            !_isAuthorisedForAddress(signer, node) ||
            !universalSignatureValidator.isValidSig(
                signer,
                message.toEthSignedMessageHash(),
                signature
            )
        ) {
            revert Unauthorized(node);
        }
    }

    /*//////////////////////////////////////////////////////////////
                           REQUIRED OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @dev Reverts instead of returning false so the modifier that uses this function has better error messages
    function isAuthorised(bytes32 node) internal view override returns (bool) {
        return _isAuthorisedForAddress(msg.sender, node);
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
