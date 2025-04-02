// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "src/L2Registry.sol";
import "./interfaces/ICreate2Deployer.sol";

/// @dev Helper script to log the deterministic deployment address of L2Registry.sol so we can deploy the implementation
///      and factory in a single script.
//       Run with `forge script ./scripts/L2RegistryAddress.s.sol`
contract L2RegistryAddress is Script {
    ICreate2Deployer create2Deployer =
        ICreate2Deployer(vm.envAddress("CREATE2_DEPLOYER_ADDRESS"));

    bytes initCode = type(L2Registry).creationCode;

    function setUp() public {
        // Can use any chain here as long as the CREATE2 deployer exists
        vm.createSelectFork("mainnet");
    }

    function run() public {
        // Set an empty salt to use CREATE2 for a deterministic address
        bytes32 salt = bytes32(0);
        address registryImplementation = create2Deployer.computeAddress(
            salt,
            keccak256(initCode)
        );

        console.log(
            "Registry implementation will be deployed to",
            registryImplementation
        );
    }
}
