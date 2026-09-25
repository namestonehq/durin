// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {L2Registry} from "src/L2Registry.sol";
import {L2RegistryFactory} from "src/L2RegistryFactory.sol";
import {IL2Resolver} from "src/interfaces/IL2Resolver.sol";
import {L2SignatureRegistrar} from "src/examples/L2SignatureRegistrar.sol";

import {MockERC1271Wallet} from "./mocks/MockERC1271Wallet.sol";
import {MockRegistrar} from "./mocks/MockRegistrar.sol";

contract L2SignatureRegistrarTest is Test {
    L2Registry public registry;
    MockRegistrar public registrar;
    L2SignatureRegistrar public signatureRegistrar;

    address public admin = address(1);
    address public user1;
    uint256 public privateKey1;
    address public user2;
    uint256 public privateKey2;
    address public relayer = address(2);

    bytes32 public node;
    uint256 public deadline;

    function setUp() public {
        (user1, privateKey1) = makeAddrAndKey("user1");
        (user2, privateKey2) = makeAddrAndKey("user2");

        vm.startPrank(admin);
        L2RegistryFactory factory = new L2RegistryFactory(
            address(new L2Registry())
        );
        registry = L2Registry(factory.deployRegistry("testname.eth"));
        registrar = new MockRegistrar(address(registry));
        signatureRegistrar = new L2SignatureRegistrar(address(registry));
        registry.addRegistrar(address(registrar));
        registry.addRegistrar(address(signatureRegistrar));
        vm.stopPrank();

        node = registrar.register("name", user1);
        deadline = block.timestamp + 1 days;
    }

    function test_SetRecordsByRelayer() public {
        bytes[] memory data = new bytes[](2);
        data[0] = _setText(node, "key", "value");
        data[1] = abi.encodeWithSignature(
            "setAddr(bytes32,uint256,bytes)",
            node,
            60,
            abi.encodePacked(user1)
        );
        bytes memory signature = _sign(privateKey1, node, data, 0, deadline);

        // `relayer` has no permissions for `node` but can submit the signed update
        vm.prank(relayer);
        signatureRegistrar.setRecords(node, data, deadline, user1, signature);

        assertEq(registry.text(node, "key"), "value");
        assertEq(registry.addr(node), user1);
        assertEq(signatureRegistrar.nonces(user1), 1);
    }

    function test_SetRecordsSupportsAllRecordSetters() public {
        bytes[] memory data = new bytes[](4);
        data[0] = abi.encodeWithSignature(
            "setAddr(bytes32,address)",
            node,
            user2
        );
        data[1] = _setText(node, "key", "value");
        data[2] = abi.encodeCall(
            IL2Resolver.setContenthash,
            (node, hex"1234")
        );
        data[3] = abi.encodeCall(IL2Resolver.setABI, (node, 1, hex"5678"));
        bytes memory signature = _sign(privateKey1, node, data, 0, deadline);

        vm.prank(relayer);
        signatureRegistrar.setRecords(node, data, deadline, user1, signature);

        assertEq(registry.addr(node), user2);
        assertEq(registry.text(node, "key"), "value");
        assertEq(registry.contenthash(node), hex"1234");
        (uint256 contentType, bytes memory abiData) = registry.ABI(node, 1);
        assertEq(contentType, 1);
        assertEq(abiData, hex"5678");
    }

    function test_SignatureReplayReverts() public {
        bytes[] memory data = _single(_setText(node, "key", "old"));
        bytes memory signature = _sign(privateKey1, node, data, 0, deadline);
        signatureRegistrar.setRecords(node, data, deadline, user1, signature);

        vm.prank(user1);
        registry.setText(node, "key", "new");

        // The same signature cannot be used to revert the record to the old value
        vm.expectRevert(L2SignatureRegistrar.InvalidSignature.selector);
        signatureRegistrar.setRecords(node, data, deadline, user1, signature);
        assertEq(registry.text(node, "key"), "new");
    }

    function test_SignatureForDifferentDataReverts() public {
        bytes memory signature = _sign(
            privateKey1,
            node,
            _single(_setText(node, "url", "https://real.io")),
            0,
            deadline
        );

        vm.expectRevert(L2SignatureRegistrar.InvalidSignature.selector);
        signatureRegistrar.setRecords(
            node,
            _single(_setText(node, "urlhttps://real.i", "o")),
            deadline,
            user1,
            signature
        );
    }

    function test_UnauthorizedSignerReverts() public {
        bytes[] memory data = _single(_setText(node, "key", "value"));
        bytes memory signature = _sign(privateKey2, node, data, 0, deadline);

        vm.expectRevert(
            abi.encodeWithSelector(
                L2SignatureRegistrar.Unauthorized.selector,
                user2,
                node
            )
        );
        signatureRegistrar.setRecords(node, data, deadline, user2, signature);
    }

    function test_SignatureFromWrongSignerReverts() public {
        bytes[] memory data = _single(_setText(node, "key", "value"));
        bytes memory signature = _sign(privateKey2, node, data, 0, deadline);

        vm.expectRevert(L2SignatureRegistrar.InvalidSignature.selector);
        signatureRegistrar.setRecords(node, data, deadline, user1, signature);
    }

    function test_CallForOtherNodeReverts() public {
        bytes32 otherNode = registrar.register("other", user2);

        // `user1` signs an update for their own node that contains a call for `otherNode`
        bytes[] memory data = _single(_setText(otherNode, "key", "value"));
        bytes memory signature = _sign(privateKey1, node, data, 0, deadline);

        vm.expectRevert(
            bytes("multicall: All records must have a matching namehash")
        );
        signatureRegistrar.setRecords(node, data, deadline, user1, signature);
    }

    function test_UnsupportedCallReverts() public {
        bytes[] memory data = _single(
            abi.encodeWithSignature("clearRecords(bytes32)", node)
        );
        bytes memory signature = _sign(privateKey1, node, data, 0, deadline);

        vm.expectRevert(
            abi.encodeWithSelector(
                L2SignatureRegistrar.UnsupportedCall.selector,
                bytes4(keccak256("clearRecords(bytes32)"))
            )
        );
        signatureRegistrar.setRecords(node, data, deadline, user1, signature);
    }

    function test_ExpiredSignatureReverts() public {
        bytes[] memory data = _single(_setText(node, "key", "value"));
        bytes memory signature = _sign(privateKey1, node, data, 0, deadline);

        vm.warp(deadline + 1);
        vm.expectRevert(L2SignatureRegistrar.SignatureExpired.selector);
        signatureRegistrar.setRecords(node, data, deadline, user1, signature);
    }

    function test_SignatureFromOtherChainReverts() public {
        bytes[] memory data = _single(_setText(node, "key", "value"));
        bytes memory signature = _sign(privateKey1, node, data, 0, deadline);

        vm.chainId(block.chainid + 1);
        vm.expectRevert(L2SignatureRegistrar.InvalidSignature.selector);
        signatureRegistrar.setRecords(node, data, deadline, user1, signature);
    }

    function test_InvalidateNonceCancelsSignature() public {
        bytes[] memory data = _single(_setText(node, "key", "value"));
        bytes memory signature = _sign(privateKey1, node, data, 0, deadline);

        vm.prank(user1);
        signatureRegistrar.invalidateNonce();

        vm.expectRevert(L2SignatureRegistrar.InvalidSignature.selector);
        signatureRegistrar.setRecords(node, data, deadline, user1, signature);
    }

    function test_SetRecordsByOperator() public {
        vm.prank(user1);
        registry.setApprovalForAll(user2, true);

        bytes[] memory data = _single(_setText(node, "key", "value"));
        bytes memory signature = _sign(privateKey2, node, data, 0, deadline);
        signatureRegistrar.setRecords(node, data, deadline, user2, signature);

        assertEq(registry.text(node, "key"), "value");
    }

    function test_SetRecordsByApprovedAddress() public {
        vm.prank(user1);
        registry.approve(user2, uint256(node));

        bytes[] memory data = _single(_setText(node, "key", "value"));
        bytes memory signature = _sign(privateKey2, node, data, 0, deadline);
        signatureRegistrar.setRecords(node, data, deadline, user2, signature);

        assertEq(registry.text(node, "key"), "value");
    }

    function test_SetRecordsBySmartContractWallet() public {
        MockERC1271Wallet wallet = new MockERC1271Wallet(user2);
        bytes32 walletNode = registrar.register("wallet", address(wallet));

        bytes[] memory data = _single(_setText(walletNode, "key", "value"));
        bytes memory signature = _sign(
            privateKey2,
            walletNode,
            data,
            0,
            deadline
        );
        signatureRegistrar.setRecords(
            walletNode,
            data,
            deadline,
            address(wallet),
            signature
        );

        assertEq(registry.text(walletNode, "key"), "value");
    }

    function test_InvalidEVMAddressReverts() public {
        bytes[] memory data = _single(
            abi.encodeWithSignature(
                "setAddr(bytes32,uint256,bytes)",
                node,
                60,
                hex"1234"
            )
        );
        bytes memory signature = _sign(privateKey1, node, data, 0, deadline);

        // The registry's own validation runs, but `Multicallable` doesn't bubble up the revert reason
        vm.expectRevert(bytes(""));
        signatureRegistrar.setRecords(node, data, deadline, user1, signature);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _setText(
        bytes32 _node,
        string memory key,
        string memory value
    ) private pure returns (bytes memory) {
        return abi.encodeCall(IL2Resolver.setText, (_node, key, value));
    }

    function _single(bytes memory call) private pure returns (bytes[] memory) {
        bytes[] memory data = new bytes[](1);
        data[0] = call;
        return data;
    }

    /// @dev Builds the EIP-712 digest independently of the contract
    function _sign(
        uint256 privateKey,
        bytes32 _node,
        bytes[] memory data,
        uint256 nonce,
        uint256 _deadline
    ) private view returns (bytes memory) {
        bytes32[] memory hashes = new bytes32[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            hashes[i] = keccak256(data[i]);
        }

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "SetRecords(bytes32 node,bytes[] data,uint256 nonce,uint256 deadline)"
                ),
                _node,
                keccak256(abi.encodePacked(hashes)),
                nonce,
                _deadline
            )
        );
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("Durin Signature Registrar"),
                keccak256("1"),
                block.chainid,
                address(signatureRegistrar)
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            MessageHashUtils.toTypedDataHash(domainSeparator, structHash)
        );
        return abi.encodePacked(r, s, v);
    }
}
