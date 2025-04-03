// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

import {L2Registry} from "src/L2Registry.sol";
import {L2RegistryFactory} from "src/L2RegistryFactory.sol";
import {IL2Resolver} from "src/interfaces/IL2Resolver.sol";
import {ENSDNSUtils} from "src/lib/ENSDNSUtils.sol";

import {MockRegistrar} from "./mocks/MockRegistrar.sol";

contract L2RegistryTest is Test {
    using MessageHashUtils for bytes32;

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

        // Deploy UniversalSignatureValidator locally via the CREATE2 factory that Foundry uses internally
        address universalSignatureValidator = 0x164af34fAF9879394370C7f09064127C043A35E9;
        address create2Factory = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        (bool success, ) = create2Factory.call(
            abi.encodePacked(
                bytes32(0),
                hex"6080604052348015600f57600080fd5b50610d488061001f6000396000f3fe608060405234801561001057600080fd5b50600436106100415760003560e01c806316d43401146100465780638f0684301461006d57806398ef1ed814610080575b600080fd5b61005961005436600461085e565b610093565b604051901515815260200160405180910390f35b61005961007b3660046108d2565b6105f8565b61005961008e3660046108d2565b61068e565b600073ffffffffffffffffffffffffffffffffffffffff86163b6060826020861080159061010157507f649264926492649264926492649264926492649264926492649264926492649287876100ea60208261092e565b6100f6928a929061096e565b6100ff91610998565b145b90508015610200576000606088828961011b60208261092e565b926101289392919061096e565b8101906101359190610acf565b9550909250905060008590036101f9576000808373ffffffffffffffffffffffffffffffffffffffff168360405161016d9190610b6e565b6000604051808303816000865af19150503d80600081146101aa576040519150601f19603f3d011682016040523d82523d6000602084013e6101af565b606091505b5091509150816101f657806040517f9d0d6e2d0000000000000000000000000000000000000000000000000000000081526004016101ed9190610bd4565b60405180910390fd5b50505b505061023a565b86868080601f0160208091040260200160405190810160405280939291908181526020018383808284376000920191909152509294505050505b80806102465750600083115b156103d3576040517f1626ba7e00000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff8a1690631626ba7e9061029f908b908690600401610bee565b602060405180830381865afa9250505080156102f6575060408051601f3d9081017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe01682019092526102f391810190610c07565b60015b61035e573d808015610324576040519150601f19603f3d011682016040523d82523d6000602084013e610329565b606091505b50806040517f6f2a95990000000000000000000000000000000000000000000000000000000081526004016101ed9190610bd4565b7fffffffff0000000000000000000000000000000000000000000000000000000081167f1626ba7e0000000000000000000000000000000000000000000000000000000014841580156103ae5750825b80156103b8575086155b156103c757806000526001601ffd5b94506105ef9350505050565b60418614610463576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152603a60248201527f5369676e617475726556616c696461746f72237265636f7665725369676e657260448201527f3a20696e76616c6964207369676e6174757265206c656e67746800000000000060648201526084016101ed565b6000610472602082898b61096e565b61047b91610998565b9050600061048d604060208a8c61096e565b61049691610998565b90506000898960408181106104ad576104ad610c49565b919091013560f81c915050601b81148015906104cd57508060ff16601c14155b1561055a576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602d60248201527f5369676e617475726556616c696461746f723a20696e76616c6964207369676e60448201527f617475726520762076616c75650000000000000000000000000000000000000060648201526084016101ed565b6040805160008152602081018083528d905260ff831691810191909152606081018490526080810183905273ffffffffffffffffffffffffffffffffffffffff8d169060019060a0016020604051602081039080840390855afa1580156105c5573d6000803e3d6000fd5b5050506020604051035173ffffffffffffffffffffffffffffffffffffffff161496505050505050505b95945050505050565b6040517f16d4340100000000000000000000000000000000000000000000000000000000815260009030906316d4340190610640908890889088908890600190600401610c78565b6020604051808303816000875af115801561065f573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906106839190610cf5565b90505b949350505050565b6040517f16d4340100000000000000000000000000000000000000000000000000000000815260009030906316d43401906106d59088908890889088908890600401610c78565b6020604051808303816000875af192505050801561072e575060408051601f3d9081017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe016820190925261072b91810190610cf5565b60015b6107db573d80801561075c576040519150601f19603f3d011682016040523d82523d6000602084013e610761565b606091505b50805160018190036107d4578160008151811061078057610780610c49565b6020910101517fff00000000000000000000000000000000000000000000000000000000000000167f0100000000000000000000000000000000000000000000000000000000000000149250610686915050565b8060208301fd5b9050610686565b73ffffffffffffffffffffffffffffffffffffffff8116811461080457600080fd5b50565b60008083601f84011261081957600080fd5b50813567ffffffffffffffff81111561083157600080fd5b60208301915083602082850101111561084957600080fd5b9250929050565b801515811461080457600080fd5b60008060008060006080868803121561087657600080fd5b8535610881816107e2565b945060208601359350604086013567ffffffffffffffff8111156108a457600080fd5b6108b088828901610807565b90945092505060608601356108c481610850565b809150509295509295909350565b600080600080606085870312156108e857600080fd5b84356108f3816107e2565b935060208501359250604085013567ffffffffffffffff81111561091657600080fd5b61092287828801610807565b95989497509550505050565b81810381811115610968577f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b92915050565b6000808585111561097e57600080fd5b8386111561098b57600080fd5b5050820193919092039150565b80356020831015610968577fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff602084900360031b1b1692915050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052604160045260246000fd5b600082601f830112610a1457600080fd5b813567ffffffffffffffff811115610a2e57610a2e6109d4565b6040517fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0603f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f8501160116810181811067ffffffffffffffff82111715610a9a57610a9a6109d4565b604052818152838201602001851015610ab257600080fd5b816020850160208301376000918101602001919091529392505050565b600080600060608486031215610ae457600080fd5b8335610aef816107e2565b9250602084013567ffffffffffffffff811115610b0b57600080fd5b610b1786828701610a03565b925050604084013567ffffffffffffffff811115610b3457600080fd5b610b4086828701610a03565b9150509250925092565b60005b83811015610b65578181015183820152602001610b4d565b50506000910152565b60008251610b80818460208701610b4a565b9190910192915050565b60008151808452610ba2816020860160208601610b4a565b601f017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0169290920160200192915050565b602081526000610be76020830184610b8a565b9392505050565b8281526040602082015260006106866040830184610b8a565b600060208284031215610c1957600080fd5b81517fffffffff0000000000000000000000000000000000000000000000000000000081168114610be757600080fd5b7f4e487b7100000000000000000000000000000000000000000000000000000000600052603260045260246000fd5b73ffffffffffffffffffffffffffffffffffffffff8616815284602082015260806040820152826080820152828460a0830137600060a08483010152600060a07fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f860116830101905082151560608301529695505050505050565b600060208284031215610d0757600080fd5b8151610be78161085056fea2646970667358221220fa1669652244780c8dcf7823a819ca1aa2abb64af0cf4d7adedb2339d4e907d964736f6c634300081a0033"
            )
        );
        require(success, "Failed to deploy UniversalSignatureValidator");
        assertGt(universalSignatureValidator.code.length, 0);

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
        vm.assume(bytes(label).length > 1 && bytes(label).length < 255);
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

    function testFuzz_SetTextRecordWithSignature(string calldata label) public {
        vm.assume(bytes(label).length > 1 && bytes(label).length < 255);

        bytes32 node = registry.makeNode(registry.baseNode(), label);

        vm.prank(admin);
        registry.addRegistrar(address(registrar));

        vm.startPrank(user1);
        registrar.register(label, user1);

        uint256 expiration = block.timestamp + 1 days;

        // Sign message that will be used for another user to set a text record
        bytes32 message = keccak256(
            abi.encodePacked(
                address(registry),
                node,
                "key",
                "value",
                expiration
            )
        ).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey1, message);

        bytes memory signature = abi.encodePacked(r, s, v);
        vm.stopPrank();

        assertEq(ecrecover(message, v, r, s), user1);

        vm.prank(user2);
        registry.setTextWithSignature(
            node,
            "key",
            "value",
            expiration,
            user1,
            signature
        );

        assertEq(registry.text(node, "key"), "value");
    }

    function testFuzz_SetTextRecordWithSignatureByUnauthorizedAddressReverts(
        string calldata label
    ) public {
        vm.assume(bytes(label).length > 1 && bytes(label).length < 255);

        bytes32 node = registry.makeNode(registry.baseNode(), label);

        vm.prank(admin);
        registry.addRegistrar(address(registrar));

        vm.startPrank(user1);
        registrar.register(label, user1);

        uint256 expiration = block.timestamp + 1 days;

        // Sign message that will be used for another user to set a text record
        bytes32 message = keccak256(
            abi.encodePacked(
                address(registry),
                node,
                "key",
                "value",
                expiration
            )
        ).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey2, message);

        bytes memory signature = abi.encodePacked(r, s, v);
        vm.stopPrank();

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(IL2Resolver.Unauthorized.selector, node)
        );
        registry.setTextWithSignature(
            node,
            "key",
            "value",
            expiration,
            user2,
            signature
        );
    }

    function testFuzz_SetRecordUnauthedReverts(string calldata label) public {
        vm.assume(bytes(label).length > 1 && bytes(label).length < 255);
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
        vm.assume(bytes(label).length > 1 && bytes(label).length < 255);
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

    function test_RegistryHelperFunctions() public {
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
}
