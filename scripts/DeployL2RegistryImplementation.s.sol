// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "src/L2Registry.sol";

/// @dev Run with `./deploy/DeployL2RegistryImplementation.sh`
contract DeployL2RegistryImplementation is Script {
    function setUp() public {}

    function run() public {
        string[] memory networks = new string[](5);
        networks[0] = "base-sepolia";
        networks[1] = "arbitrum-sepolia";
        networks[2] = "optimism-sepolia";
        networks[3] = "scroll-sepolia";
        networks[4] = "linea-sepolia";
        // networks[6] = "base";
        // networks[7] = "arbitrum";
        // networks[8] = "optimism";
        // networks[9] = "scroll";
        // networks[10] = "linea";

        for (uint256 i = 0; i < networks.length; i++) {
            if (keccak256(bytes(networks[i])) == keccak256(bytes(""))) {
                break;
            }

            console.log("Deploying to", networks[i]);
            vm.createSelectFork(networks[i]);
            vm.startBroadcast();
            // Set an empty salt to use CREATE2 for a deterministic address
            L2Registry registryImplementation = new L2Registry{salt: 0}();
            console.log(
                "Registry implementation deployed to",
                address(registryImplementation)
            );
            vm.stopBroadcast();
        }
    }
}
