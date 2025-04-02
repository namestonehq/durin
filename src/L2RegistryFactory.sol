// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ***********************************************
// ▗▖  ▗▖ ▗▄▖ ▗▖  ▗▖▗▄▄▄▖ ▗▄▄▖▗▄▄▄▖▗▄▖ ▗▖  ▗▖▗▄▄▄▖
// ▐▛▚▖▐▌▐▌ ▐▌▐▛▚▞▜▌▐▌   ▐▌     █ ▐▌ ▐▌▐▛▚▖▐▌▐▌
// ▐▌ ▝▜▌▐▛▀▜▌▐▌  ▐▌▐▛▀▀▘ ▝▀▚▖  █ ▐▌ ▐▌▐▌ ▝▜▌▐▛▀▀▘
// ▐▌  ▐▌▐▌ ▐▌▐▌  ▐▌▐▙▄▄▖▗▄▄▞▘  █ ▝▚▄▞▘▐▌  ▐▌▐▙▄▄▖
// ***********************************************

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {IL2Registry} from "./interfaces/IL2Registry.sol";

/// @title Durin Registry Factory
/// @author NameStone
/// @notice Facilitates the deployment of new ENS subname registries
contract L2RegistryFactory {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The implementation contract to clone
    address public immutable registryImplementation;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new registry is deployed
    /// @param name The parent ENS name for the registry
    /// @param admin The address granted admin roles for the new registry
    /// @param registry The address of the newly deployed registry
    event RegistryDeployed(string name, address admin, address registry);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _registryImplementation) {
        registryImplementation = _registryImplementation;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys a new L2Registry contract with default parameters
    /// @param name The parent ENS name for the registry, e.g. "example.eth"
    /// @return address The address of the newly deployed registry clone
    function deployRegistry(string calldata name) external returns (address) {
        return deployRegistry(name, "", "", msg.sender);
    }

    /// @notice Deploys a new L2Registry contract with specified parameters
    /// @param name The parent ENS name for the registry, e.g. "example.eth"
    /// @param symbol The symbol for the registry's ERC721 token
    /// @param baseURI The URI for the NFT's metadata
    /// @param admin The address to grant admin roles to
    /// @return address The address of the newly deployed registry clone
    function deployRegistry(
        string calldata name,
        string memory symbol,
        string memory baseURI,
        address admin
    ) public returns (address) {
        address registry = Clones.clone(registryImplementation);
        IL2Registry(registry).initialize(name, symbol, baseURI, admin);

        emit RegistryDeployed(name, admin, registry);
        return registry;
    }
}
