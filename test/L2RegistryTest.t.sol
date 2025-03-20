// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {L2Registry} from "../src/L2Registry.sol";
import {L2RegistryFactory} from "../src/L2RegistryFactory.sol";
import {IL2Resolver} from "../src/interfaces/IL2Resolver.sol";

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

    function testFuzz_Register(string calldata label) public {
        vm.assume(bytes(label).length > 1 && bytes(label).length < 255);

        vm.startPrank(admin);
        registry.addRegistrar(admin);
        registry.register(label, admin);
        vm.stopPrank();

        bytes32 labelhash = keccak256(abi.encodePacked(label));
        bytes32 node = registry.makeNode(registry.parentNode(), labelhash);
        assertEq(registry.ownerOf(uint256(node)), admin);
    }

    function testFuzz_RegisterTwiceReverts(string calldata label) public {
        vm.assume(bytes(label).length > 1 && bytes(label).length < 255);

        vm.startPrank(admin);
        registry.addRegistrar(admin);
        registry.register(label, admin);

        // Attempt to register the same label again
        vm.expectRevert(
            abi.encodeWithSelector(
                L2Registry.NotAvailable.selector,
                label,
                registry.parentNode()
            )
        );
        registry.register(label, admin);
        vm.stopPrank();
    }

    function testFuzz_RegisterWithUnauthedAddressReverts(
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

    function testFuzz_SetSubnodeOwner(
        string calldata label,
        string calldata sublabel
    ) public {
        vm.assume(bytes(label).length > 1 && bytes(label).length < 255);
        vm.assume(bytes(sublabel).length > 1 && bytes(sublabel).length < 255);

        // Register a name
        vm.startPrank(admin);
        registry.addRegistrar(admin);
        registry.register(label, admin);

        // Create a subnode
        bytes32 nameNode = registry.makeNode(
            registry.parentNode(),
            keccak256(abi.encodePacked(label))
        );
        bytes32 subnode = registry.setSubnodeOwner(nameNode, sublabel, user1);
        vm.stopPrank();

        assertEq(registry.ownerOf(uint256(subnode)), user1);

        // Then the subnode owner should be able to move the subnode to a new owner
        vm.startPrank(user1);
        registry.transferFrom(user1, user2, uint256(subnode));
        vm.stopPrank();

        assertEq(registry.ownerOf(uint256(subnode)), user2);
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
            abi.encodeWithSelector(IL2Resolver.Unauthorized.selector, node)
        );
        vm.prank(user2);
        registry.setAddr(node, user2);
    }

    function testFuzz_SetRecordsWithMulticall(string calldata label) public {
        vm.assume(bytes(label).length > 1 && bytes(label).length < 255);
        bytes32 labelhash = keccak256(abi.encodePacked(label));
        bytes32 node = registry.makeNode(registry.parentNode(), labelhash);

        bytes[] memory data = new bytes[](3);

        // setAddr(bytes32, address) = 0xd5fa2b00
        data[0] = abi.encodeWithSelector(bytes4(0xd5fa2b00), node, user1);
        data[1] = abi.encodeWithSelector(
            IL2Resolver.setText.selector,
            node,
            "key",
            "value"
        );
        data[2] = abi.encodeWithSelector(
            IL2Resolver.setContenthash.selector,
            node,
            hex"1234"
        );

        vm.startPrank(admin);
        registry.addRegistrar(admin);
        registry.register(label, user1);
        registry.multicallWithNodeCheck(node, data);
        vm.stopPrank();

        assertEq(registry.addr(node), user1);
        assertEq(registry.text(node, "key"), "value");
        assertEq(registry.contenthash(node), hex"1234");
    }

    function test_ImplementationAddressNotNull() public view {
        address implAddr = factory.implementation();
        assertTrue(implAddr != address(0));
    }
}
