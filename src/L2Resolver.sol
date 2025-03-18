// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ***********************************************
// ▗▖  ▗▖ ▗▄▖ ▗▖  ▗▖▗▄▄▄▖ ▗▄▄▖▗▄▄▄▖▗▄▖ ▗▖  ▗▖▗▄▄▄▖
// ▐▛▚▖▐▌▐▌ ▐▌▐▛▚▞▜▌▐▌   ▐▌     █ ▐▌ ▐▌▐▛▚▖▐▌▐▌
// ▐▌ ▝▜▌▐▛▀▜▌▐▌  ▐▌▐▛▀▀▘ ▝▀▚▖  █ ▐▌ ▐▌▐▌ ▝▜▌▐▛▀▀▘
// ▐▌  ▐▌▐▌ ▐▌▐▌  ▐▌▐▙▄▄▖▗▄▄▞▘  █ ▝▚▄▞▘▐▌  ▐▌▐▙▄▄▖
// ***********************************************

import "@ensdomains/ens-contracts/resolvers/profiles/ABIResolver.sol";
import "@ensdomains/ens-contracts/resolvers/profiles/AddrResolver.sol";
import "@ensdomains/ens-contracts/resolvers/profiles/ContentHashResolver.sol";
import "@ensdomains/ens-contracts/resolvers/profiles/TextResolver.sol";
import "@ensdomains/ens-contracts/resolvers/Multicallable.sol";

import "./L2Registry.sol";

/// @author NameStone
/// @notice Basic resolver to store standard ENS records
/// @dev This contract is inherited by L2Registry, making the registry available via `address(this)`
contract L2Resolver is
    Multicallable,
    ABIResolver,
    AddrResolver,
    ContentHashResolver,
    TextResolver
{
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    mapping(address => bool) public trustedControllers;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyRegistryAdmin() {
        L2Registry registry = _registry();
        if (!registry.hasRole(registry.ADMIN_ROLE(), msg.sender)) {
            revert Unauthorized();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setTrustedController(
        address controller,
        bool isTrusted
    ) external onlyRegistryAdmin {
        trustedControllers[controller] = isTrusted;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _registry() internal view returns (L2Registry) {
        return L2Registry(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                           REQUIRED OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function isAuthorised(bytes32 node) internal view override returns (bool) {
        if (trustedControllers[msg.sender]) {
            return true;
        }

        L2Registry registry = _registry();
        uint256 tokenId = uint256(node);
        address owner = registry.ownerOf(tokenId);

        return
            (owner == msg.sender) ||
            (registry.getApproved(tokenId) == msg.sender);
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
