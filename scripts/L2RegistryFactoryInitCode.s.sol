// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "src/L2RegistryFactory.sol";

/// @dev Helper script to log the init code hash of L2RegistryFactory.sol for CREATE2 salt mining.
//       Run with `forge script ./scripts/L2RegistryFactoryInitCode.s.sol`
contract RegistryBytecode is Script {
    address public registryImplementation =
        vm.envAddress("L2_REGISTRY_IMPLEMENTATION_ADDRESS");

    function setUp() public {}

    function run() public {
        bytes memory creationCode = type(L2RegistryFactory).creationCode;
        bytes memory constructorArgs = abi.encode(registryImplementation);
        bytes memory initCode = abi.encodePacked(creationCode, constructorArgs);
        console.logBytes32(keccak256(initCode));
    }
}
