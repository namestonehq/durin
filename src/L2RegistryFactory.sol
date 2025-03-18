// ***********************************************
// ▗▖  ▗▖ ▗▄▖ ▗▖  ▗▖▗▄▄▄▖ ▗▄▄▖▗▄▄▄▖▗▄▖ ▗▖  ▗▖▗▄▄▄▖
// ▐▛▚▖▐▌▐▌ ▐▌▐▛▚▞▜▌▐▌   ▐▌     █ ▐▌ ▐▌▐▛▚▖▐▌▐▌
// ▐▌ ▝▜▌▐▛▀▜▌▐▌  ▐▌▐▛▀▀▘ ▝▀▚▖  █ ▐▌ ▐▌▐▌ ▝▜▌▐▛▀▀▘
// ▐▌  ▐▌▐▌ ▐▌▐▌  ▐▌▐▙▄▄▖▗▄▄▞▘  █ ▝▚▄▞▘▐▌  ▐▌▐▙▄▄▖
// ***********************************************
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @author darianb.eth
/// @custom:project Durin
/// @custom:company NameStone
/// @notice Factory contract for deploying new L2Registry instances
/// @dev Uses OpenZeppelin Clones for gas-efficient deployment of registry contracts

import {L2Registry} from "./L2Registry.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

/// @title L2Registry Factory
/// @notice Facilitates the deployment of new L2Registry instances with proper role configuration
/// @dev Uses minimal proxy pattern through OpenZeppelin's Clones library
contract L2RegistryFactory {
    /// @notice The implementation contract to clone
    address public immutable implementation;

    /// @notice Emitted when a new registry is deployed
    /// @param name The parent ENS name for the registry
    /// @param admin The address granted admin roles for the new registry
    /// @param registry The address of the newly deployed registry
    event RegistryDeployed(string name, address admin, address registry);

    constructor() {
        implementation = address(new L2Registry());
    }

    /// @notice Deploys a new L2Registry contract with default parameters
    /// @param name The parent ENS name for the registry
    /// @return address The address of the newly deployed registry clone
    function deployRegistry(string calldata name) external returns (address) {
        return deployRegistry(name, name, "", msg.sender);
    }

    /// @notice Deploys a new L2Registry contract with specified parameters
    /// @param name The parent ENS name for the registry
    /// @param symbol The symbol for the registry's ERC721 token
    /// @param baseUri The URI for the NFT's metadata
    /// @param admin The address to grant admin roles to
    /// @return address The address of the newly deployed registry clone
    /// @dev Uses minimal proxy pattern to create cheap clones of the implementation
    function deployRegistry(
        string calldata name,
        string calldata symbol,
        string memory baseUri,
        address admin
    ) public returns (address) {
        address registry = Clones.clone(implementation);
        L2Registry(registry).initialize(name, symbol, baseUri, admin);
        emit RegistryDeployed(name, admin, registry);
        return registry;
    }
}
