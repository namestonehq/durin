// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ***********************************************
// ▗▖  ▗▖ ▗▄▖ ▗▖  ▗▖▗▄▄▄▖ ▗▄▄▖▗▄▄▄▖▗▄▖ ▗▖  ▗▖▗▄▄▄▖
// ▐▛▚▖▐▌▐▌ ▐▌▐▛▚▞▜▌▐▌   ▐▌     █ ▐▌ ▐▌▐▛▚▖▐▌▐▌
// ▐▌ ▝▜▌▐▛▀▜▌▐▌  ▐▌▐▛▀▀▘ ▝▀▚▖  █ ▐▌ ▐▌▐▌ ▝▜▌▐▛▀▀▘
// ▐▌  ▐▌▐▌ ▐▌▐▌  ▐▌▐▙▄▄▖▗▄▄▞▘  █ ▝▚▄▞▘▐▌  ▐▌▐▙▄▄▖
// ***********************************************

import "@ensdomains/ens-contracts/resolvers/Multicallable.sol";
import "@ensdomains/ens-contracts/resolvers/profiles/ABIResolver.sol";
import "@ensdomains/ens-contracts/resolvers/profiles/AddrResolver.sol";
import "@ensdomains/ens-contracts/resolvers/profiles/ContentHashResolver.sol";
import "@ensdomains/ens-contracts/resolvers/profiles/TextResolver.sol";
import "@ensdomains/ens-contracts/resolvers/profiles/ExtendedResolver.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

import "./interfaces/IL2Registry.sol";

/// @author NameStone
/// @notice Basic resolver to store standard ENS records
/// @dev This contract is inherited by L2Registry, making the registry available via `address(this)`
contract L2Resolver is
    Multicallable,
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

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyRegistryAdmin() {
        IL2Registry registry = _registry();
        if (!registry.hasRole(registry.REGISTRAR_ROLE(), msg.sender)) {
            revert IAccessControl.AccessControlUnauthorizedAccount(
                msg.sender,
                registry.ADMIN_ROLE()
            );
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _registry() internal view returns (IL2Registry) {
        return IL2Registry(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                           REQUIRED OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @dev Reverts instead of returning false so the modifier that uses this function has better error messages.
    function isAuthorised(bytes32 node) internal view override returns (bool) {
        IL2Registry registry = _registry();

        if (registry.hasRole(registry.REGISTRAR_ROLE(), msg.sender)) {
            return true;
        }

        uint256 tokenId = uint256(node);
        address owner = registry.ownerOf(tokenId);

        if (
            (owner != msg.sender) &&
            (registry.getApproved(tokenId) != msg.sender)
        ) {
            revert Unauthorized(node);
        }

        return true;
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
