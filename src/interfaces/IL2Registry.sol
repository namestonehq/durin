// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ***********************************************
// ▗▖  ▗▖ ▗▄▖ ▗▖  ▗▖▗▄▄▄▖ ▗▄▄▖▗▄▄▄▖▗▄▖ ▗▖  ▗▖▗▄▄▄▖
// ▐▛▚▖▐▌▐▌ ▐▌▐▛▚▞▜▌▐▌   ▐▌     █ ▐▌ ▐▌▐▛▚▖▐▌▐▌
// ▐▌ ▝▜▌▐▛▀▜▌▐▌  ▐▌▐▛▀▀▘ ▝▀▚▖  █ ▐▌ ▐▌▐▌ ▝▜▌▐▛▀▀▘
// ▐▌  ▐▌▐▌ ▐▌▐▌  ▐▌▐▙▄▄▖▗▄▄▞▘  █ ▝▚▄▞▘▐▌  ▐▌▐▙▄▄▖
// ***********************************************

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {IL2Resolver} from "./IL2Resolver.sol";

/// @author NameStone
interface IL2Registry is IERC721, IL2Resolver {
    // State variables
    function totalSupply() external view returns (uint256);
    function parentNode() external view returns (bytes32);
    function names(bytes32 node) external view returns (bytes memory name);

    // Public functions
    function register(string calldata label, address owner) external;

    // Admin functions
    function addRegistrar(address registrar) external;
    function removeRegistrar(address registrar) external;
    function setBaseURI(string calldata baseURI) external;
}
