// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ***********************************************
// ▗▖  ▗▖ ▗▄▖ ▗▖  ▗▖▗▄▄▄▖ ▗▄▄▖▗▄▄▄▖▗▄▖ ▗▖  ▗▖▗▄▄▄▖
// ▐▛▚▖▐▌▐▌ ▐▌▐▛▚▞▜▌▐▌   ▐▌     █ ▐▌ ▐▌▐▛▚▖▐▌▐▌
// ▐▌ ▝▜▌▐▛▀▜▌▐▌  ▐▌▐▛▀▀▘ ▝▀▚▖  █ ▐▌ ▐▌▐▌ ▝▜▌▐▛▀▀▘
// ▐▌  ▐▌▐▌ ▐▌▐▌  ▐▌▐▙▄▄▖▗▄▄▞▘  █ ▝▚▄▞▘▐▌  ▐▌▐▙▄▄▖
// ***********************************************

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {L2Registry} from "./L2Registry.sol";

/// @title Durin
/// @author NameStone
/// @notice Facilitates the deployment of new ENS subname registries
contract L2RegistryFactory {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The implementation contract to clone
    address public immutable implementation;

    /// @notice The name of the contract
    string public constant name = "Durin";

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

    constructor() {
        implementation = address(new L2Registry());
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys a new L2Registry contract with default parameters
    /// @param _name The parent ENS name for the registry
    /// @return address The address of the newly deployed registry clone
    function deployRegistry(string calldata _name) external returns (address) {
        return deployRegistry(_name, "", "", msg.sender);
    }

    /// @notice Deploys a new L2Registry contract with specified parameters
    /// @param _name The parent ENS name for the registry
    /// @param _symbol The symbol for the registry's ERC721 token
    /// @param _baseURI The URI for the NFT's metadata
    /// @param _admin The address to grant admin roles to
    /// @return address The address of the newly deployed registry clone
    function deployRegistry(
        string calldata _name,
        string memory _symbol,
        string memory _baseURI,
        address _admin
    ) public returns (address) {
        address registry = Clones.clone(implementation);
        L2Registry(registry).initialize(_name, _symbol, _baseURI, _admin);

        emit RegistryDeployed(_name, _admin, registry);
        return registry;
    }
}
