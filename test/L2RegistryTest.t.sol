// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, Vm} from "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {NameCoder} from "@ensdomains/ens-contracts/utils/NameCoder.sol";

import {L2Registry} from "src/L2Registry.sol";
import {L2RegistryFactory} from "src/L2RegistryFactory.sol";
import {IL2Resolver} from "src/interfaces/IL2Resolver.sol";

import {L2Registrar} from "src/examples/L2Registrar.sol";

import {MockRegistrar} from "./mocks/MockRegistrar.sol";
import {ReentrantReceiver} from "./mocks/ReentrantReceiver.sol";

contract L2RegistryTest is Test {
    L2RegistryFactory public factory;
    L2Registry public registry;
    MockRegistrar public registrar;

    address public admin = address(1);
    address public user1;
    uint256 public privateKey1;
    address public user2;
    uint256 public privateKey2;

    event BaseURIUpdated(string baseURI);

    function setUp() public {
        vm.startPrank(admin);

        (user1, privateKey1) = makeAddrAndKey("user1");
        (user2, privateKey2) = makeAddrAndKey("user2");

        // Deploy factory
        factory = new L2RegistryFactory(address(new L2Registry()));

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
        vm.assume(_isValidLabel(label));

        bytes32 expectedNode = registry.makeNode(registry.baseNode(), label);

        // The node should not be minted yet
        assertEq(registry.owner(expectedNode), address(0));

        // totalSupply should start at 1 because the root node is minted during deployment
        assertEq(registry.totalSupply(), 1);

        vm.prank(admin);
        registry.addRegistrar(address(registrar));

        vm.prank(user1);
        bytes32 node = registrar.register(label, user1);

        assertEq(node, expectedNode);
        assertEq(registry.ownerOf(uint256(node)), user1);
        assertEq(registry.owner(node), user1);
        assertEq(registry.totalSupply(), 2);

        // Verify that the contract is storing the full DNS-encoded name correctly
        string memory fullName = string.concat(label, ".", registry.name());
        assertEq(NameCoder.decode(registry.names(node)), fullName);
    }

    function testFuzz_RegisterTwiceReverts(string calldata label) public {
        vm.assume(_isValidLabel(label));

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
        vm.assume(_isValidLabel(label));

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
        vm.assume(_isValidLabel(label));
        vm.assume(_isValidLabel(sublabel));

        // Add registrar
        vm.prank(admin);
        registry.addRegistrar(address(registrar));

        // Register a name (3LD)
        vm.startPrank(user1);
        bytes32 nodeFor3ld = registrar.register(label, user1);
        assertEq(registry.ownerOf(uint256(nodeFor3ld)), user1);

        bytes32 expectedNodeFor4ld = registry.makeNode(nodeFor3ld, sublabel);

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
        assertEq(registry.text(expectedNodeFor4ld, "key"), "value");
        assertEq(registry.addr(expectedNodeFor4ld), user1);
        assertEq(registry.totalSupply(), 3);

        // Then the subnode owner should be able to move the subnode to a new owner
        registry.safeTransferFrom(user1, user2, uint256(actualNodeFor4ld));
        vm.stopPrank();
        assertEq(registry.owner(actualNodeFor4ld), user2);
    }

    function testFuzz_CreateSubnodeWithDataForUnownedNodeReverts(
        string calldata label,
        string calldata sublabel
    ) public {
        vm.assume(_isValidLabel(label));
        vm.assume(_isValidLabel(sublabel));

        // Add registrar
        vm.prank(admin);
        registry.addRegistrar(address(registrar));

        // Register a name (3LD)
        vm.startPrank(user1);
        bytes32 nodeFor3ld = registrar.register(label, user1);

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
        vm.assume(_isValidLabel(label));
        vm.assume(_isValidLabel(sublabel));

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
        vm.assume(_isValidLabel(label));
        bytes32 node = registry.makeNode(registry.baseNode(), label);

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
        vm.assume(_isValidLabel(label));
        bytes32 node = registry.makeNode(registry.baseNode(), label);

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
        vm.assume(_isValidLabel(label));
        bytes32 node = registry.makeNode(registry.baseNode(), label);

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
        vm.assume(_isValidLabel(label));
        bytes32 node = registry.makeNode(registry.baseNode(), label);

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

    function test_MulticallDoesntBlowEverythingUp() public {
        bytes[] memory data = new bytes[](1);

        vm.startPrank(user1);
        data[0] = abi.encodeWithSelector(
            bytes4(0xd5fa2b00),
            registry.baseNode(),
            user1
        );
        vm.expectRevert();
        registry.multicall(data);
        vm.stopPrank();
    }

    function test_ImplementationAddressNotNull() public view {
        address implAddr = factory.registryImplementation();
        assertTrue(implAddr != address(0));
    }

    function test_RegistryHelperFunctions() public view {
        bytes32 node = registry.namehash("testname.eth");
        assertEq(
            node,
            0x9709c900112b2537a4268551c6a89092af6ce2e45a001af4e8dc5d800c4eae25
        );

        bytes memory dnsEncodedName = registry.names(registry.baseNode());
        assertEq(dnsEncodedName, hex"08746573746e616d650365746800");

        string memory decodedName = registry.decodeName(dnsEncodedName);
        assertEq(decodedName, "testname.eth");
    }

    function test_TokenMetadata() public {
        // namehash("testname.eth")
        bytes32 testNameNode = 0x9709c900112b2537a4268551c6a89092af6ce2e45a001af4e8dc5d800c4eae25;
        string memory tokenIdString = Strings.toString(uint256(testNameNode));

        string memory metadata = string.concat(
            "data:application/json;base64,",
            Base64.encode(bytes('{"name": "testname.eth"}'))
        );

        // Should be an onchain SVG because we deployed the registry with no baseURI
        assertEq(registry.tokenURI(uint256(testNameNode)), metadata);

        string memory baseURI = "https://example.com/";

        vm.expectEmit();
        emit BaseURIUpdated(baseURI);
        vm.prank(admin);
        registry.setBaseURI(baseURI);

        assertEq(
            registry.tokenURI(uint256(testNameNode)),
            string(abi.encodePacked(baseURI, tokenIdString))
        );
    }

    function test_SetRecordsByOperator() public {
        bytes32 node = _registerTo("name", user1);

        vm.prank(user1);
        registry.setApprovalForAll(user2, true);

        vm.prank(user2);
        registry.setAddr(node, user2);
        assertEq(registry.addr(node), user2);
    }

    function test_SetRecordsByApprovedAddress() public {
        bytes32 node = _registerTo("name", user1);

        vm.prank(user1);
        registry.approve(user2, uint256(node));

        vm.prank(user2);
        registry.setAddr(node, user2);
        assertEq(registry.addr(node), user2);
    }

    function test_CreateSubnodeReentrancyKeepsNamesConsistent() public {
        ReentrantReceiver receiver = new ReentrantReceiver(address(registry));
        bytes32 parentNode = _registerTo("parent", address(receiver));
        bytes32 childNode = registry.makeNode(parentNode, "child");

        assertEq(registry.owner(childNode), address(receiver));
        assertEq(
            registry.decodeName(registry.names(childNode)),
            "child.parent.testname.eth"
        );
        assertEq(registry.totalSupply(), 3);
    }

    function test_CreateSubnodeEmitsParentEventsFirst() public {
        // The receiver creates "child" under "parent" from within `onERC721Received()`
        ReentrantReceiver receiver = new ReentrantReceiver(address(registry));
        bytes32 parentNode = registry.makeNode(registry.baseNode(), "parent");
        bytes32 childNode = registry.makeNode(parentNode, "child");

        vm.recordLogs();
        _registerTo("parent", address(receiver));
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bytes32[] memory created = new bytes32[](2);
        uint256 count = 0;
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].topics[0] ==
                keccak256("SubnodeCreated(bytes32,bytes,address)")
            ) {
                created[count++] = logs[i].topics[1];
            }
        }
        assertEq(count, 2);
        assertEq(created[0], parentNode);
        assertEq(created[1], childNode);
    }

    function test_CreateSubnodeByOperator() public {
        bytes32 node = _registerTo("name", user1);

        vm.prank(user1);
        registry.setApprovalForAll(user2, true);

        vm.prank(user2);
        bytes32 subnode = registry.createSubnode(
            node,
            "sub",
            user2,
            new bytes[](0)
        );
        assertEq(registry.owner(subnode), user2);
    }

    function test_CreateSubnodeByApprovedAddress() public {
        bytes32 node = _registerTo("name", user1);

        vm.prank(user1);
        registry.approve(user2, uint256(node));

        vm.prank(user2);
        bytes32 subnode = registry.createSubnode(
            node,
            "sub",
            user2,
            new bytes[](0)
        );
        assertEq(registry.owner(subnode), user2);
    }

    function test_CreateSubnodeUnderNonexistentNodeReverts() public {
        bytes32 node = registry.makeNode(registry.baseNode(), "missing");

        vm.expectRevert(
            abi.encodeWithSelector(IL2Resolver.Unauthorized.selector, node)
        );
        vm.prank(user1);
        registry.createSubnode(node, "sub", user1, new bytes[](0));
    }

    function test_ExampleRegistrarEnforcesMinimumLength() public {
        L2Registrar exampleRegistrar = new L2Registrar(address(registry));
        vm.prank(admin);
        registry.addRegistrar(address(exampleRegistrar));

        assertFalse(exampleRegistrar.available("ab"));
        vm.expectRevert(
            abi.encodeWithSelector(L2Registrar.LabelTooShort.selector, "ab")
        );
        exampleRegistrar.register("ab", user1);

        assertTrue(exampleRegistrar.available("abc"));
        exampleRegistrar.register("abc", user1);
        bytes32 node = registry.makeNode(registry.baseNode(), "abc");
        assertEq(registry.owner(node), user1);
        assertEq(registry.addr(node), user1);
        assertEq(
            exampleRegistrar.coinType(),
            0x80000000 | block.chainid
        );
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev `NameCoder.decode()` reverts on labels containing "."
    function _isValidLabel(string memory label) private pure returns (bool) {
        bytes memory b = bytes(label);
        if (b.length <= 1 || b.length >= 255) return false;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == ".") return false;
        }
        return true;
    }

    function _registerTo(
        string memory label,
        address owner
    ) private returns (bytes32) {
        vm.prank(admin);
        registry.addRegistrar(address(registrar));
        return registrar.register(label, owner);
    }
}
