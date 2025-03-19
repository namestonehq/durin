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

import {IL2Registry} from "./interfaces/IL2Registry.sol";

/// @title Registrar (for Layer 2)
/// @dev This is a simple registrar contract that is mean to be modified.
contract L2Registrar {
    /// @notice Emitted when a new name is registered
    /// @param label The registered label (e.g. "name" in "name.eth")
    /// @param owner The owner of the newly registered name
    event NameRegistered(string indexed label, address indexed owner);

    /// @notice Reference to the target registry contract
    IL2Registry public immutable registry;

    /// @notice The chainId for the current chain
    uint256 public chainId;

    /// @notice The coinType for the current chain (ENSIP-11)
    uint256 public immutable coinType;

    /// @notice Initializes the registrar with a registry contract
    /// @param _registry Address of the L2Registry contract
    constructor(IL2Registry _registry) {
        assembly {
            sstore(chainId.slot, chainid())
        }

        coinType = (0x80000000 | chainId) >> 0;
        registry = _registry;
    }

    /// @notice Checks if a given label is available for registration
    /// @param label The label to check availability for
    /// @return available True if the label can be registered, false if already taken
    /// @dev Uses try-catch to handle the ERC721NonexistentToken error
    function available(string memory label) external view returns (bool) {
        bytes32 labelhash = keccak256(bytes(label));
        uint256 tokenId = uint256(labelhash);

        try registry.ownerOf(tokenId) {
            return false;
        } catch {
            return true;
        }
    }

    /// @notice Registers a new name
    /// @param label The label to register (e.g. "name" for "name.eth")
    /// @param owner The address that will own the name
    function register(string memory label, address owner) external {
        bytes32 labelhash = keccak256(bytes(label)); // Hash the label
        bytes memory addr = abi.encodePacked(owner); // Convert address to bytes

        // Set the forward address for the current chain. This is needed for reverse resolution.
        // E.g. if this contract is deployed to Base, set an address for chainId 8453 which is
        // coinType 2147492101 according to ENSIP-11.
        registry.setAddr(labelhash, coinType, addr);

        // Set the forward address for mainnet ETH (coinType 60) for easier debugging.
        registry.setAddr(labelhash, 60, addr);

        // Register the name in the L2 registry
        registry.register(label, owner);
        emit NameRegistered(label, owner);
    }
}
