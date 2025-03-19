// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/L2Registry.sol";
import "../src/examples/L2Registrar.sol";
import "../src/L2RegistryFactory.sol";

// contract L2RegistryTest is Test {
//     L2RegistryFactory public factory;
//     L2Registry public registry;
//     L2Registrar public registrar;
//     address public admin = address(1);
//     address public user1 = address(2);
//     address public user2 = address(3);

//     event Registered(string indexed label, address owner);
//     event TextChanged(bytes32 indexed labelhash, string key, string value);
//     event AddrChanged(bytes32 indexed labelhash, uint256 coinType, bytes value);

//     function setUp() public {
//         vm.startPrank(admin);

//         // Deploy factory with test salt
//         bytes32 salt = keccak256(abi.encodePacked("test"));
//         factory = new L2RegistryFactory(salt);

//         // Deploy registry through factory
//         registry = L2Registry(
//             factory.deployRegistry("TestNames", "TEST", "https://test.uri/")
//         );

//         // Deploy registrar
//         registrar = new L2Registrar(IL2Registry(address(registry)));

//         // Grant registrar role to registrar contract
//         registry.addRegistrar(address(registrar));

//         vm.stopPrank();
//     }

//     function test_RegisterName() public {
//         string memory label = "test";
//         bytes32 expectedLabelhash = keccak256(abi.encodePacked(label));

//         vm.deal(user1, 1 ether);
//         vm.prank(user1);
//         registrar.register(label, user1);

//         assertEq(registry.ownerOf(uint256(expectedLabelhash)), user1);
//     }

//     function test_SetRecords() public {
//         string memory label = "test";
//         bytes32 labelhash = keccak256(abi.encodePacked(label));

//         // Register as user1
//         vm.deal(user1, 1 ether);
//         vm.prank(user1);
//         registrar.register(label, user1);

//         // Prepare record data
//         L2Registry.Text[] memory texts = new L2Registry.Text[](1);
//         texts[0] = L2Registry.Text({key: "email", value: "test@example.com"});

//         L2Registry.Addr[] memory addrs = new L2Registry.Addr[](1);
//         addrs[0] = L2Registry.Addr({
//             coinType: 60,
//             value: abi.encodePacked(user2)
//         });

//         bytes memory contenthash = hex"1234";

//         // Test unauthorized user cannot set records
//         vm.prank(user2);
//         vm.expectRevert();
//         registry.setRecords(labelhash, texts, addrs, contenthash);

//         // Test owner can set records
//         vm.prank(user1);
//         vm.expectEmit(true, false, false, true);
//         emit TextChanged(labelhash, "email", "test@example.com");
//         registry.setRecords(labelhash, texts, addrs, contenthash);

//         // Test registrar can set records
//         vm.prank(address(registrar));
//         registry.setRecords(labelhash, texts, addrs, contenthash);

//         // Verify records
//         assertEq(registry.text(labelhash, "email"), "test@example.com");
//         assertEq(registry.addr(labelhash), user2);
//     }

//     function test_RecordAccessControl() public {
//         string memory label = "test";
//         bytes32 labelhash = keccak256(abi.encodePacked(label));

//         // Register name
//         vm.deal(user1, 1 ether);
//         vm.prank(user1);
//         registrar.register(label, user1);

//         // Test unauthorized access
//         vm.startPrank(user2);
//         vm.expectRevert();
//         registry.setText(labelhash, "email", "test@example.com");
//         vm.expectRevert();
//         registry.setAddr(labelhash, 60, abi.encodePacked(user2));
//         vm.expectRevert();
//         registry.setContenthash(labelhash, hex"1234");
//         vm.stopPrank();

//         // Test owner access
//         vm.startPrank(user1);
//         registry.setText(labelhash, "email", "test@example.com");
//         registry.setAddr(labelhash, 60, abi.encodePacked(user2));
//         registry.setContenthash(labelhash, hex"1234");
//         vm.stopPrank();

//         // Test registrar access
//         vm.startPrank(address(registrar));
//         registry.setText(labelhash, "email", "new@example.com");
//         registry.setAddr(labelhash, 60, abi.encodePacked(user1));
//         registry.setContenthash(labelhash, hex"5678");
//         vm.stopPrank();
//     }

//     function test_AccessControl() public {
//         // Test admin functions
//         vm.prank(user1);
//         vm.expectRevert();
//         registry.addRegistrar(user2);

//         vm.prank(admin);
//         registry.addRegistrar(user2);

//         // Test registrar functions
//         vm.prank(user1);
//         vm.expectRevert();
//         registry.register("test", user1);
//     }

//     function testFuzz_RegisterName(string calldata label) public {
//         vm.assume(bytes(label).length > 0);
//         vm.assume(bytes(label).length < 100); // reasonable length limit

//         vm.deal(user1, 1 ether);
//         vm.prank(user1);
//         registrar.register(label, user1);

//         bytes32 labelhash = keccak256(abi.encodePacked(label));
//         assertEq(registry.ownerOf(uint256(labelhash)), user1);
//     }

//     // New tests for clone-specific functionality
//     function test_CannotInitializeTwice() public {
//         vm.prank(admin);
//         vm.expectRevert(); // Should revert with AlreadyInitialized
//         registry.initialize("NewName", "NEW", "https://new.uri/");
//     }

//     function test_ImplementationIsolation() public {
//         // Deploy two registries
//         vm.startPrank(admin);
//         L2Registry registry2 = L2Registry(
//             factory.deployRegistry("TestNames2", "TEST2", "https://test2.uri/")
//         );

//         // Register name in first registry
//         vm.deal(user1, 2 ether);
//         L2Registrar registrar2 = new L2Registrar(
//             IL2Registry(address(registry2))
//         );
//         registry2.addRegistrar(address(registrar2));
//         vm.stopPrank();

//         // Register same name in both registries
//         string memory label = "test";

//         vm.prank(user1);
//         registrar.register(label, user1);

//         vm.prank(user1);
//         registrar2.register(label, user2);

//         bytes32 labelhash = keccak256(abi.encodePacked(label));

//         // Verify registries are isolated
//         assertEq(registry.ownerOf(uint256(labelhash)), user1);
//         assertEq(registry2.ownerOf(uint256(labelhash)), user2);
//     }

//     function test_ImplementationAddress() public view {
//         address implAddr = factory.implementationContract();
//         assertTrue(implAddr != address(0));

//         // Verify implementation contract is at expected address
//         address expectedAddr = factory.getImplementationAddress();
//         assertEq(implAddr, expectedAddr);
//     }

//     function test_CloneStorage() public {
//         string memory label = "test";
//         bytes32 labelhash = keccak256(abi.encodePacked(label));

//         // Register in first registry
//         vm.deal(user1, 1 ether);
//         vm.prank(user1);
//         registrar.register(label, user1);

//         // Deploy second registry
//         vm.prank(admin);
//         L2Registry registry2 = L2Registry(
//             factory.deployRegistry("TestNames2", "TEST2", "https://test2.uri/")
//         );

//         // Verify storage is separate
//         assertTrue(registry.ownerOf(uint256(labelhash)) == user1);
//         vm.expectRevert(); // Should revert as name doesn't exist in registry2
//         registry2.ownerOf(uint256(labelhash));
//     }
// }
