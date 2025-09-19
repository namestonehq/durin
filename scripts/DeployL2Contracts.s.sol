// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "src/L2Registry.sol";
import "src/L2RegistryFactory.sol";
import "./interfaces/ICreate2Deployer.sol";

/// @dev Run with `./bash/DeployL2Contracts.sh`
contract DeployL2Contracts is Script {
    ICreate2Deployer create2Deployer =
        ICreate2Deployer(vm.envAddress("CREATE2_DEPLOYER_ADDRESS"));

    address public registryImplementation =
        vm.envAddress("L2_REGISTRY_IMPLEMENTATION_ADDRESS");

    // Use a fixed salt for consistent addresses across chains
    bytes32 salt = vm.envBytes32("L2_REGISTRY_FACTORY_SALT");

    bytes implementationInitCode = type(L2Registry).creationCode;

    bytes factoryCreationCode = type(L2RegistryFactory).creationCode;
    bytes factoryConstructorArgs = abi.encode(registryImplementation);
    bytes factoryInitCode =
        abi.encodePacked(factoryCreationCode, factoryConstructorArgs);

    function setUp() public {}

    function run() public {
        string[] memory networks = new string[](100);
        networks[0] = "base-sepolia";
        networks[1] = "arbitrum-sepolia";
        networks[2] = "optimism-sepolia";
        networks[3] = "scroll-sepolia";
        networks[4] = "linea-sepolia";
        networks[5] = "celo-sepolia";
        networks[6] = "polygon-amoy";
        networks[7] = "worldchain-sepolia";
        // networks[8] = "base";
        // networks[9] = "arbitrum";
        // networks[10] = "optimism";
        // networks[11] = "scroll";
        // networks[12] = "linea";
        // networks[13] = "celo";
        // networks[14] = "polygon";
        // networks[15] = "worldchain";

        for (uint256 i = 0; i < networks.length; i++) {
            if (keccak256(bytes(networks[i])) == keccak256(bytes(""))) {
                break;
            }

            console.log("Deploying to", networks[i]);
            vm.createSelectFork(networks[i]);
            vm.startBroadcast();

            create2Deployer.deploy(0, 0, implementationInitCode);

            address factory = create2Deployer.computeAddress(
                salt,
                keccak256(factoryInitCode)
            );
            create2Deployer.deploy(0, salt, factoryInitCode);

            console.log("Factory deployed to", address(factory));
            vm.stopBroadcast();
        }
    }
}
