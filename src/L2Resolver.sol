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
import {COIN_TYPE_DEFAULT, ENSIP19} from "@ensdomains/ens-contracts/utils/ENSIP19.sol";
import {ContentHashResolver} from "@ensdomains/ens-contracts/resolvers/profiles/ContentHashResolver.sol";
import {ExtendedResolver} from "@ensdomains/ens-contracts/resolvers/profiles/ExtendedResolver.sol";
import {IMulticallable} from "@ensdomains/ens-contracts/resolvers/IMulticallable.sol";
import {TextResolver} from "@ensdomains/ens-contracts/resolvers/profiles/TextResolver.sol";

import {L2Registry} from "./L2Registry.sol";

/// @title Durin Resolver
/// @author NameStone
/// @notice Resolver to store standard ENS records
/// @dev This contract is inherited by L2Registry, making registry methods available via `address(this)`
contract L2Resolver is
    IMulticallable,
    ABIResolver,
    AddrResolver,
    ContentHashResolver,
    TextResolver,
    ExtendedResolver
{
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized(bytes32 node);
    error NodeMismatch(bytes32 callNode);

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Multicall is implemented here instead of inheriting `Multicallable` from ens-contracts, which reverts with no
    // data when a call fails and hides the reason

    /// @inheritdoc IMulticallable
    function multicall(
        bytes[] calldata data
    ) external returns (bytes[] memory results) {
        return _multicall(bytes32(0), data);
    }

    /// @inheritdoc IMulticallable
    function multicallWithNodeCheck(
        bytes32 nodehash,
        bytes[] calldata data
    ) external returns (bytes[] memory results) {
        return _multicall(nodehash, data);
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

    /// @dev Calls each item in `data` on this contract, keeping `msg.sender`. If `nodehash` is not zero, every call
    ///      must have it as its first argument.
    function _multicall(
        bytes32 nodehash,
        bytes[] calldata data
    ) internal returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            if (nodehash != bytes32(0)) {
                bytes32 callNode = bytes32(data[i][4:36]);
                if (callNode != nodehash) {
                    revert NodeMismatch(callNode);
                }
            }

            (bool success, bytes memory result) = address(this).delegatecall(
                data[i]
            );
            if (!success) {
                // Bubble up the revert reason
                assembly ("memory-safe") {
                    revert(add(result, 32), mload(result))
                }
            }
            results[i] = result;
        }
    }

    function _registry() internal view returns (L2Registry) {
        return L2Registry(address(this));
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
        override(ABIResolver, AddrResolver, ContentHashResolver, TextResolver)
        returns (bool)
    {
        return
            interfaceId == type(IMulticallable).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
