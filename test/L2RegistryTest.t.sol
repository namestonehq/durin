// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";

import {L2Registry} from "../src/L2Registry.sol";
import {L2RegistryFactory} from "../src/L2RegistryFactory.sol";
import {IL2Resolver} from "../src/interfaces/IL2Resolver.sol";
import {ENSDNSUtils} from "./utils/ENSDNSUtils.sol";
import {MockRegistrar} from "./mocks/MockRegistrar.sol";

contract L2RegistryTest is Test {
    L2RegistryFactory public factory;
    L2Registry public registry;
    MockRegistrar public registrar;

    address public admin = address(1);
    address public user1 = address(2);
    address public user2 = address(3);

    function setUp() public {
        vm.startPrank(admin);

        // Deploy factory
        factory = new L2RegistryFactory();

        // Deploy registry through factory with default parameters
        registry = L2Registry(factory.deployRegistry("testname.eth"));
        registrar = new MockRegistrar(address(registry));

        vm.stopPrank();
    }

    function test_InitialState() public view {
        uint256 tokenId = uint256(registry.baseNode());
        assertEq(registry.ownerOf(tokenId), admin);
        assertEq(admin, registry.owner());
    }

    function test_AddRegistrar() public {
        vm.prank(admin);
        registry.addRegistrar(address(registrar));
    }

    function test_AddRegistrarUnauthedReverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IL2Resolver.Unauthorized.selector,
                uint256(registry.baseNode())
            )
        );
        vm.prank(user1);
        registry.addRegistrar(address(registrar));
    }

    function testFuzz_Register(string calldata label) public {
        vm.assume(bytes(label).length > 1 && bytes(label).length < 255);

        bytes32 expectedNode = registry.makeNode(
            registry.baseNode(),
            keccak256(abi.encodePacked(label))
        );

        // The node should not be minted yet
        assertEq(registry.owner(expectedNode), address(0));

        vm.prank(admin);
        registry.addRegistrar(address(registrar));

        vm.prank(user1);
        bytes32 node = registrar.register(label, user1);

        assertEq(node, expectedNode);
        assertEq(registry.ownerOf(uint256(node)), user1);

        // Verify that the contract is storing the full DNS-encoded name correctly
        string memory fullName = string.concat(label, ".", registry.name());
        assertEq(ENSDNSUtils.dnsDecode(registry.names(node)), fullName);
    }

    function testFuzz_RegisterTwiceReverts(string calldata label) public {
        vm.assume(bytes(label).length > 1 && bytes(label).length < 255);

        vm.prank(admin);
        registry.addRegistrar(address(registrar));

        vm.startPrank(user1);
        registrar.register(label, admin);

        // Attempt to register the same label again
        vm.expectRevert(
            abi.encodeWithSelector(
                L2Registry.NotAvailable.selector,
                label,
                registry.baseNode()
            )
        );
        registrar.register(label, admin);
        vm.stopPrank();
    }

    function testFuzz_RegisterWithUnapprovedRegistrarReverts(
        string calldata label
    ) public {
        vm.assume(bytes(label).length > 1 && bytes(label).length < 255);

        vm.expectRevert(
            abi.encodeWithSelector(
                IL2Resolver.Unauthorized.selector,
                uint256(registry.baseNode())
            )
        );
        vm.prank(user1);
        registrar.register(label, user1);
    }

    function testFuzz_CreateSubnodeWithData(
        string calldata label,
        string calldata sublabel
    ) public {
        vm.assume(bytes(label).length > 1 && bytes(label).length < 255);
        vm.assume(bytes(sublabel).length > 1 && bytes(sublabel).length < 255);

        // Add registrar
        vm.prank(admin);
        registry.addRegistrar(address(registrar));

        // Register a name (3LD)
        vm.startPrank(user1);
        bytes32 nodeFor3ld = registrar.register(label, user1);
        assertEq(registry.ownerOf(uint256(nodeFor3ld)), user1);

        bytes32 expectedNodeFor4ld = registry.makeNode(
            nodeFor3ld,
            keccak256(abi.encodePacked(sublabel))
        );

        // Create calldata for resolver for the soon-to-be-created 4LD
        bytes[] memory data = new bytes[](2);
        // setAddr(bytes32, address) = 0xd5fa2b00
        data[0] = abi.encodeWithSelector(
            bytes4(0xd5fa2b00),
            expectedNodeFor4ld,
            user1
        );
        data[1] = abi.encodeWithSelector(
            IL2Resolver.setText.selector,
            expectedNodeFor4ld,
            "key",
            "value"
        );

        bytes32 actualNodeFor4ld = registry.createSubnode(
            nodeFor3ld,
            sublabel,
            user1,
            data
        );
        assertEq(expectedNodeFor4ld, actualNodeFor4ld);
        assertEq(registry.owner(actualNodeFor4ld), user1);

        // Then the subnode owner should be able to move the subnode to a new owner
        registry.transferFrom(user1, user2, uint256(actualNodeFor4ld));
        vm.stopPrank();
        assertEq(registry.owner(actualNodeFor4ld), user2);
    }

    function testFuzz_CreateSubnodeWithDataForUnownedNodeReverts(
        string calldata label,
        string calldata sublabel
    ) public {
        vm.assume(bytes(label).length > 1 && bytes(label).length < 255);
        vm.assume(bytes(sublabel).length > 1 && bytes(sublabel).length < 255);

        // Add registrar
        vm.prank(admin);
        registry.addRegistrar(address(registrar));

        // Register a name (3LD)
        vm.startPrank(user1);
        bytes32 nodeFor3ld = registrar.register(label, user1);

        bytes32 expectedNodeFor4ld = registry.makeNode(
            nodeFor3ld,
            keccak256(abi.encodePacked(sublabel))
        );

        // Create calldata for resolver for the soon-to-be-created 4LD
        bytes[] memory data = new bytes[](2);
        // setAddr(bytes32, address) = 0xd5fa2b00
        data[0] = abi.encodeWithSelector(bytes4(0xd5fa2b00), nodeFor3ld, user1);
        data[1] = abi.encodeWithSelector(
            IL2Resolver.setText.selector,
            nodeFor3ld,
            "key",
            "value"
        );

        // This throws from Multicallable which has `require` instead of custom error
        vm.expectRevert(
            bytes("multicall: All records must have a matching namehash")
        );
        registry.createSubnode(nodeFor3ld, sublabel, user1, data);
        vm.stopPrank();
    }

    function testFuzz_CreateSubnodeFromUnapprovedNodeReverts(
        string calldata label,
        string calldata sublabel
    ) public {
        vm.assume(bytes(label).length > 1 && bytes(label).length < 255);
        vm.assume(bytes(sublabel).length > 1 && bytes(sublabel).length < 255);

        // Add registrar
        vm.prank(admin);
        registry.addRegistrar(address(registrar));

        // Register a name
        vm.prank(user1);
        bytes32 nameNode = registrar.register(label, user1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IL2Resolver.Unauthorized.selector,
                uint256(nameNode)
            )
        );
        vm.prank(user2);
        registry.createSubnode(nameNode, sublabel, user1, new bytes[](0));
    }

    function testFuzz_SetSingleRecordsByOwner(string calldata label) public {
        vm.assume(bytes(label).length > 1 && bytes(label).length < 255);
        bytes32 labelhash = keccak256(abi.encodePacked(label));
        bytes32 node = registry.makeNode(registry.baseNode(), labelhash);

        vm.prank(admin);
        registry.addRegistrar(address(registrar));

        vm.startPrank(user1);
        registrar.register(label, user1);

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
        bytes32 node = registry.makeNode(registry.baseNode(), labelhash);

        vm.prank(admin);
        registry.addRegistrar(address(registrar));

        vm.startPrank(user1);
        registrar.register(label, user1);
        registry.approve(user1, uint256(node));
        vm.stopPrank();

        vm.prank(user1);
        registry.setAddr(node, user1);
        assertEq(registry.addr(node), user1);
    }

    function testFuzz_SetRecordUnauthedReverts(string calldata label) public {
        vm.assume(bytes(label).length > 1 && bytes(label).length < 255);
        bytes32 labelhash = keccak256(abi.encodePacked(label));
        bytes32 node = registry.makeNode(registry.baseNode(), labelhash);

        // Register a name to `user1`
        vm.prank(admin);
        registry.addRegistrar(address(registrar));

        vm.startPrank(user1);
        registrar.register(label, user1);
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
        bytes32 node = registry.makeNode(registry.baseNode(), labelhash);

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

        vm.prank(admin);
        registry.addRegistrar(address(registrar));

        vm.startPrank(user1);
        registrar.register(label, user1);
        registry.multicallWithNodeCheck(node, data);
        vm.stopPrank();

        assertEq(registry.addr(node), user1);
        assertEq(registry.text(node, "key"), "value");
        assertEq(registry.contenthash(node), hex"1234");
    }

    function test_ImplementationAddressNotNull() public view {
        address implAddr = factory.registryImplementation();
        assertTrue(implAddr != address(0));
    }
}
