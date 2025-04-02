// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "src/L1Resolver.sol";

/// @dev Run with `./bash/DeployL1Resolver.sh`
contract DeployL1Resolver is Script {
    // "sepolia" or "mainnet"
    string public network = "sepolia";

    function setUp() public {}

    function run() public {
        vm.createSelectFork(network);
        vm.startBroadcast();

        new L1Resolver{salt: 0}(
            vm.envString("L1_RESOLVER_URL"),
            vm.envAddress("L1_RESOLVER_SIGNER"),
            vm.envAddress("L1_RESOLVER_OWNER")
        );

        vm.stopBroadcast();
    }
}
