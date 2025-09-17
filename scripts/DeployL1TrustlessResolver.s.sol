// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "src/L1TrustlessResolver.sol";

/// @dev Run with `./bash/DeployL1TrustlessResolver.sh`
contract DeployL1TrustlessResolver is Script {
    // "sepolia" or "mainnet"
    string public network = "sepolia";

    function setUp() public {}

    function run() public {
        vm.createSelectFork(network);
        vm.startBroadcast();

        new L1TrustlessResolver{salt: 0}(
            0x179A862703a4adfb29896552DF9e307980D19285 // owner
        );

        vm.stopBroadcast();
    }
}
