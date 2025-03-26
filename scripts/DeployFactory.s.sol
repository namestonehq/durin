// ./deploy/DeployL2RegistryFactory.sh

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "src/L2RegistryFactory.sol";

contract DeployFactory is Script {
    // Use a fixed salt for consistent addresses across chains
    string saltString = vm.envString("SALT");
    bytes32 salt = keccak256(abi.encodePacked(saltString));

    // Get private key and add 0x prefix if missing
    string rawKey = vm.envString("PRIVATE_KEY");
    bytes privateKeyBytes = vm.parseBytes(rawKey);
    uint256 deployerPrivateKey = uint256(bytes32(privateKeyBytes));

    function setUp() public {}

    function run() public {
        string[] memory networks = new string[](5);
        networks[0] = "base-sepolia";
        // networks[1] = "arbitrum-sepolia";
        // networks[2] = "optimism-sepolia";
        // networks[3] = "scroll-sepolia";
        // networks[4] = "linea-sepolia";
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
            vm.startBroadcast(deployerPrivateKey);
            L2RegistryFactory factory = new L2RegistryFactory{salt: salt}();
            console.log("Factory deployed to", address(factory));
            vm.stopBroadcast();
        }
    }
}
