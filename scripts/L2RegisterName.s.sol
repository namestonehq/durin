// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @author darianb.eth
/// @custom:project Durin
/// @custom:company NameStone

// Sets an address record in the L2Registry contract
// Load environment variables and run the script
// source .env && forge script scripts/L2RegisterName.s.sol:L2RegisterName --rpc-url $RPC_URL --broadcast

import {Script} from "forge-std/Script.sol";
import {L2Registrar} from "src/examples/L2Registrar.sol";

contract L2RegisterName is Script {
    function setUp() public {}

    function run() public {
        // Load environment variables
        address registrarAddress = vm.envAddress("REGISTRAR_ADDRESS");
        string memory nameToRegister = vm.envString("NAME_TO_REGISTER");
        address owner = vm.envAddress("OWNER_ADDRESS");

        // Start broadcasting transactions
        vm.startBroadcast();

        // Get the contract instance
        L2Registrar registrar = L2Registrar(registrarAddress);

        // Register the name
        registrar.register(nameToRegister, owner);

        vm.stopBroadcast();
    }
}
