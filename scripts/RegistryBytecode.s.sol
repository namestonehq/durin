// ./scripts/RegistryBytecode.s.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "src/L2RegistryFactory.sol";

/// @dev Used to get the initcode hash of the L2RegistryFactory contract for CREATE2 salt mining
contract RegistryBytecode is Script {
    function setUp() public {}

    function run() public {
        bytes memory creationCode = type(L2RegistryFactory).creationCode;
        console.logBytes32(keccak256(creationCode));
    }
}
