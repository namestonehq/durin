// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import "../src/L2Registry.sol";
import "../src/L2RegistryFactory.sol";

contract L2RegistryTest is Test {
    L2RegistryFactory public factory;
    L2Registry public registry;
    address public admin = address(1);
    address public user1 = address(2);
    address public user2 = address(3);

    function setUp() public {
        vm.startPrank(admin);

        // Deploy factory
        factory = new L2RegistryFactory();

        // Deploy registry through factory with default parameters
        registry = L2Registry(factory.deployRegistry("testname.eth"));

        vm.stopPrank();
    }

    function testFuzz_AddRegistrar(address registrar) public {
        vm.prank(admin);
        registry.addRegistrar(registrar);
    }

    function testFuzz_AddRegistrarUnauthedReverts(address registrar) public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user1,
                registry.ADMIN_ROLE()
            )
        );
        vm.prank(user1);
        registry.addRegistrar(registrar);
    }

    function testFuzz_RegisterViaRegistryWithAuthedAddress(
        string calldata label
    ) public {
        vm.assume(bytes(label).length > 1 && bytes(label).length < 255);

        vm.startPrank(admin);
        registry.addRegistrar(admin);
        registry.register(label, admin);
        vm.stopPrank();

        bytes32 labelhash = keccak256(abi.encodePacked(label));
        bytes32 node = registry.makeNode(registry.parentNode(), labelhash);
        assertEq(registry.ownerOf(uint256(node)), admin);
        assertEq(registry.totalSupply(), 1);
    }

    function testFuzz_RegisterViaRegistryWithUnauthedAddressReverts(
        string calldata label
    ) public {
        vm.assume(bytes(label).length > 1 && bytes(label).length < 255);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user1,
                registry.REGISTRAR_ROLE()
            )
        );
        vm.prank(user1);
        registry.register(label, user1);
    }

    function testFuzz_SetSingleRecordsByOwner(string calldata label) public {
        vm.assume(bytes(label).length > 1 && bytes(label).length < 255);
        bytes32 labelhash = keccak256(abi.encodePacked(label));
        bytes32 node = registry.makeNode(registry.parentNode(), labelhash);

        vm.startPrank(admin);
        registry.addRegistrar(admin);
        registry.register(label, admin);

        registry.setAddr(node, user1);
        registry.setContenthash(node, hex"1234");
        registry.setText(node, "key", "value");
        vm.stopPrank();

        assertEq(registry.addr(node), user1);
        assertEq(registry.text(node, "key"), "value");
        assertEq(registry.contenthash(node), hex"1234");
    }

    function testFuzz_SetSingleRecordsByApprovedAddress(
        string calldata label
    ) public {
        vm.assume(bytes(label).length > 1 && bytes(label).length < 255);
        bytes32 labelhash = keccak256(abi.encodePacked(label));
        bytes32 node = registry.makeNode(registry.parentNode(), labelhash);

        vm.startPrank(admin);
        registry.addRegistrar(admin);
        registry.register(label, admin);
        registry.approve(user1, uint256(node));
        vm.stopPrank();

        vm.prank(user1);
        registry.setAddr(node, user1);
        assertEq(registry.addr(node), user1);
    }

    function testFuzz_SetRecordsUnauthedReverts(string calldata label) public {
        vm.assume(bytes(label).length > 1 && bytes(label).length < 255);
        bytes32 labelhash = keccak256(abi.encodePacked(label));
        bytes32 node = registry.makeNode(registry.parentNode(), labelhash);

        // Register a name to `user1`
        vm.startPrank(admin);
        registry.addRegistrar(admin);
        registry.register(label, user1);
        vm.stopPrank();

        // Revert when `user2` tries to update a record for the name owned by `user1`
        vm.expectRevert(
            abi.encodeWithSelector(L2Resolver.Unauthorized.selector, node)
        );
        vm.prank(user2);
        registry.setAddr(node, user2);
    }

    function testFuzz_SetRecordsWithMulticall(string calldata label) public {}

    function test_ImplementationAddressNotNull() public view {
        address implAddr = factory.implementation();
        assertTrue(implAddr != address(0));
    }
}
