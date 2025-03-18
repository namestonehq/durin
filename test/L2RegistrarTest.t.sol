// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/L2Registry.sol";
import "../src/L2Registrar.sol";
import "../src/L2RegistryFactory.sol";

// contract L2RegistrarTest is Test {
//     L2RegistryFactory public factory;
//     L2Registry public registry;
//     L2Registrar public registrar;
//     address public admin = address(1);
//     address public user1 = address(2);

//     event NameRegistered(string indexed label, address indexed owner);

//     function setUp() public {
//         // Deploy factory with a test salt
//         vm.startPrank(admin);
//         bytes32 salt = keccak256(abi.encodePacked("test"));
//         factory = new L2RegistryFactory(salt);

//         // Deploy a registry through the factory
//         registry = L2Registry(
//             factory.deployRegistry("TestNames", "TEST", "https://test.uri/")
//         );

//         // Deploy and set up registrar
//         registrar = new L2Registrar(IL2Registry(address(registry)));
//         registry.addRegistrar(address(registrar));
//         vm.stopPrank();
//     }

//     function test_Available() public {
//         string memory label = "test";

//         // Should be available before registration
//         assertTrue(registrar.available(label));

//         // Register the name
//         vm.deal(user1, 1 ether);
//         vm.prank(user1);
//         registrar.register(label, user1);

//         // Should not be available after registration
//         assertFalse(registrar.available(label));
//     }

//     function testFuzz_Register(string calldata label) public {
//         vm.assume(bytes(label).length > 0);
//         vm.assume(bytes(label).length < 100);

//         vm.prank(user1);
//         registrar.register(label, user1);

//         // Verify registration
//         bytes32 labelhash = keccak256(abi.encodePacked(label));
//         assertEq(registry.ownerOf(uint256(labelhash)), user1);
//     }

//     // New tests specific to factory and clones functionality
//     function test_ImplementationAddress() public view {
//         address impl = factory.implementationContract();
//         assertTrue(impl != address(0), "Implementation not deployed");
//     }

//     function test_DeployMultipleRegistries() public {
//         vm.startPrank(admin);

//         // Deploy second registry
//         L2Registry registry2 = L2Registry(
//             factory.deployRegistry("TestNames2", "TEST2", "https://test2.uri/")
//         );

//         // Verify both registries work independently
//         L2Registrar registrar2 = new L2Registrar(
//             IL2Registry(address(registry2))
//         );
//         registry2.addRegistrar(address(registrar2));

//         // Register name in first registry
//         vm.deal(user1, 2 ether);
//         vm.stopPrank();

//         vm.prank(user1);
//         registrar.register("test1", user1);

//         // Register different name in second registry
//         vm.prank(user1);
//         registrar2.register("test2", user1);

//         // Verify registrations
//         bytes32 labelhash1 = keccak256(abi.encodePacked("test1"));
//         bytes32 labelhash2 = keccak256(abi.encodePacked("test2"));

//         assertEq(registry.ownerOf(uint256(labelhash1)), user1);
//         assertEq(registry2.ownerOf(uint256(labelhash2)), user1);
//     }

//     function test_RegistryInitialization() public {
//         vm.prank(admin);
//         L2Registry newRegistry = L2Registry(
//             factory.deployRegistry("TestNames3", "TEST3", "https://test3.uri/")
//         );

//         // Verify initialization worked
//         assertTrue(
//             newRegistry.hasRole(newRegistry.DEFAULT_ADMIN_ROLE(), admin)
//         );
//         assertTrue(newRegistry.hasRole(newRegistry.ADMIN_ROLE(), admin));

//         // Verify factory doesn't retain any roles
//         assertFalse(
//             newRegistry.hasRole(
//                 newRegistry.DEFAULT_ADMIN_ROLE(),
//                 address(factory)
//             )
//         );
//         assertFalse(
//             newRegistry.hasRole(newRegistry.ADMIN_ROLE(), address(factory))
//         );
//     }
// }
