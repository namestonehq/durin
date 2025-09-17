// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ***********************************************
// ▗▖  ▗▖ ▗▄▖ ▗▖  ▗▖▗▄▄▄▖ ▗▄▄▖▗▄▄▄▖▗▄▖ ▗▖  ▗▖▗▄▄▄▖
// ▐▛▚▖▐▌▐▌ ▐▌▐▛▚▞▜▌▐▌   ▐▌     █ ▐▌ ▐▌▐▛▚▖▐▌▐▌
// ▐▌ ▝▜▌▐▛▀▜▌▐▌  ▐▌▐▛▀▀▘ ▝▀▚▖  █ ▐▌ ▐▌▐▌ ▝▜▌▐▛▀▀▘
// ▐▌  ▐▌▐▌ ▐▌▐▌  ▐▌▐▙▄▄▖▗▄▄▞▘  █ ▝▚▄▞▘▐▌  ▐▌▐▙▄▄▖
// ***********************************************

import {ENS} from "@ensdomains/ens-contracts/registry/ENS.sol";
import {GatewayFetcher, GatewayRequest} from "@unruggable/gateways/GatewayFetcher.sol";
import {GatewayFetchTarget, IGatewayVerifier} from "@unruggable/gateways/GatewayFetchTarget.sol";
import {IABIResolver} from "@ensdomains/ens-contracts/resolvers/profiles/IABIResolver.sol";
import {IAddressResolver} from "@ensdomains/ens-contracts/resolvers/profiles/IAddressResolver.sol";
import {IAddrResolver} from "@ensdomains/ens-contracts/resolvers/profiles/IAddrResolver.sol";
import {IContentHashResolver} from "@ensdomains/ens-contracts/resolvers/profiles/IContentHashResolver.sol";
import {IExtendedResolver} from "@ensdomains/ens-contracts/resolvers/profiles/IExtendedResolver.sol";
import {ITextResolver} from "@ensdomains/ens-contracts/resolvers/profiles/ITextResolver.sol";
import {NameCoder} from "@ensdomains/ens-contracts/utils/NameCoder.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {strings} from "@arachnid/string-utils/strings.sol";

import {IOperationRouter} from "./interfaces/IOperationRouter.sol";

interface INameWrapper {
    function ownerOf(uint256 id) external view returns (address owner);
}

/// @author NameStone
/// @notice ENS resolver that directs all queries to Unruggable Gateways for trustless resolution of data from L2s.
/// @dev Callers must implement EIP-3668 and ENSIP-10.
contract L1TrustlessResolver is GatewayFetchTarget, IExtendedResolver, Ownable {
    using GatewayFetcher for GatewayRequest;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct L2Registry {
        uint64 chainId;
        address registryAddress;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    ENS public constant ens = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

    /* 
        ╭-----------------------+------------------------------------------------------------------+------+--------+-------+-------------------------------------------------------------------------------+--------------------------------------------------------------------+-------------------------------╮
    | Name                  | Type                                                             | Slot | Offset | Bytes | Value                                                                         | Hex Value                                                          | Contract                      |
    +=======================================================================================================================================================================================================================================================================================================+
    | _name                 | string                                                           | 0    | 0      | 32    | 0                                                                             | 0x0000000000000000000000000000000000000000000000000000000000000000 | src/L2Registry.sol:L2Registry |
    |-----------------------+------------------------------------------------------------------+------+--------+-------+-------------------------------------------------------------------------------+--------------------------------------------------------------------+-------------------------------|
    | _symbol               | string                                                           | 1    | 0      | 32    | 0                                                                             | 0x0000000000000000000000000000000000000000000000000000000000000000 | src/L2Registry.sol:L2Registry |
    |-----------------------+------------------------------------------------------------------+------+--------+-------+-------------------------------------------------------------------------------+--------------------------------------------------------------------+-------------------------------|
    | _owners               | mapping(uint256 => address)                                      | 2    | 0      | 32    | 0                                                                             | 0x0000000000000000000000000000000000000000000000000000000000000000 | src/L2Registry.sol:L2Registry |
    |-----------------------+------------------------------------------------------------------+------+--------+-------+-------------------------------------------------------------------------------+--------------------------------------------------------------------+-------------------------------|
    | _balances             | mapping(address => uint256)                                      | 3    | 0      | 32    | 0                                                                             | 0x0000000000000000000000000000000000000000000000000000000000000000 | src/L2Registry.sol:L2Registry |
    |-----------------------+------------------------------------------------------------------+------+--------+-------+-------------------------------------------------------------------------------+--------------------------------------------------------------------+-------------------------------|
    | _tokenApprovals       | mapping(uint256 => address)                                      | 4    | 0      | 32    | 0                                                                             | 0x0000000000000000000000000000000000000000000000000000000000000000 | src/L2Registry.sol:L2Registry |
    |-----------------------+------------------------------------------------------------------+------+--------+-------+-------------------------------------------------------------------------------+--------------------------------------------------------------------+-------------------------------|
    | _operatorApprovals    | mapping(address => mapping(address => bool))                     | 5    | 0      | 32    | 0                                                                             | 0x0000000000000000000000000000000000000000000000000000000000000000 | src/L2Registry.sol:L2Registry |
    |-----------------------+------------------------------------------------------------------+------+--------+-------+-------------------------------------------------------------------------------+--------------------------------------------------------------------+-------------------------------|
    | recordVersions        | mapping(bytes32 => uint64)                                       | 6    | 0      | 32    | 0                                                                             | 0x0000000000000000000000000000000000000000000000000000000000000000 | src/L2Registry.sol:L2Registry |
    |-----------------------+------------------------------------------------------------------+------+--------+-------+-------------------------------------------------------------------------------+--------------------------------------------------------------------+-------------------------------|
    | versionable_abis      | mapping(uint64 => mapping(bytes32 => mapping(uint256 => bytes))) | 7    | 0      | 32    | 0                                                                             | 0x0000000000000000000000000000000000000000000000000000000000000000 | src/L2Registry.sol:L2Registry |
    |-----------------------+------------------------------------------------------------------+------+--------+-------+-------------------------------------------------------------------------------+--------------------------------------------------------------------+-------------------------------|
    | versionable_addresses | mapping(uint64 => mapping(bytes32 => mapping(uint256 => bytes))) | 8    | 0      | 32    | 0                                                                             | 0x0000000000000000000000000000000000000000000000000000000000000000 | src/L2Registry.sol:L2Registry |
    |-----------------------+------------------------------------------------------------------+------+--------+-------+-------------------------------------------------------------------------------+--------------------------------------------------------------------+-------------------------------|
    | versionable_hashes    | mapping(uint64 => mapping(bytes32 => bytes))                     | 9    | 0      | 32    | 0                                                                             | 0x0000000000000000000000000000000000000000000000000000000000000000 | src/L2Registry.sol:L2Registry |
    |-----------------------+------------------------------------------------------------------+------+--------+-------+-------------------------------------------------------------------------------+--------------------------------------------------------------------+-------------------------------|
    | versionable_texts     | mapping(uint64 => mapping(bytes32 => mapping(string => string))) | 10   | 0      | 32    | 0                                                                             | 0x0000000000000000000000000000000000000000000000000000000000000000 | src/L2Registry.sol:L2Registry |
    |-----------------------+------------------------------------------------------------------+------+--------+-------+-------------------------------------------------------------------------------+--------------------------------------------------------------------+-------------------------------|
    | baseNode              | bytes32                                                          | 11   | 0      | 32    | 18834108569120395063375654216744883725787019265380042890676523973120098237518 | 0x29a3ba497913ee88a341d39e5acfcf52ade41dd862a24846f28c8063d59efc4e | src/L2Registry.sol:L2Registry |
    |-----------------------+------------------------------------------------------------------+------+--------+-------+-------------------------------------------------------------------------------+--------------------------------------------------------------------+-------------------------------|
    | totalSupply           | uint256                                                          | 12   | 0      | 32    | 1                                                                             | 0x0000000000000000000000000000000000000000000000000000000000000001 | src/L2Registry.sol:L2Registry |
    |-----------------------+------------------------------------------------------------------+------+--------+-------+-------------------------------------------------------------------------------+--------------------------------------------------------------------+-------------------------------|
    | _tokenName            | string                                                           | 13   | 0      | 32    | 50861228703896826213710281084772313186350134743742855464613537810735746252826 | 0x70726f6f666f666d652e6574680000000000000000000000000000000000001a | src/L2Registry.sol:L2Registry |
    |-----------------------+------------------------------------------------------------------+------+--------+-------+-------------------------------------------------------------------------------+--------------------------------------------------------------------+-------------------------------|
    | _tokenSymbol          | string                                                           | 14   | 0      | 32    | 50861228703896826213710281084772313186350134743742855464613537810735746252826 | 0x70726f6f666f666d652e6574680000000000000000000000000000000000001a | src/L2Registry.sol:L2Registry |
    |-----------------------+------------------------------------------------------------------+------+--------+-------+-------------------------------------------------------------------------------+--------------------------------------------------------------------+-------------------------------|
    | _tokenBaseURI         | string                                                           | 15   | 0      | 32    | 0                                                                             | 0x0000000000000000000000000000000000000000000000000000000000000000 | src/L2Registry.sol:L2Registry |
    |-----------------------+------------------------------------------------------------------+------+--------+-------+-------------------------------------------------------------------------------+--------------------------------------------------------------------+-------------------------------|
    | names                 | mapping(bytes32 => bytes)                                        | 16   | 0      | 32    | 0                                                                             | 0x0000000000000000000000000000000000000000000000000000000000000000 | src/L2Registry.sol:L2Registry |
    |-----------------------+------------------------------------------------------------------+------+--------+-------+-------------------------------------------------------------------------------+--------------------------------------------------------------------+-------------------------------|
    | registrars            | mapping(address => bool)                                         | 17   | 0      | 32    | 0                                                                             | 0x0000000000000000000000000000000000000000000000000000000000000000 | src/L2Registry.sol:L2Registry |
    ╰-----------------------+------------------------------------------------------------------+------+--------+-------+-------------------------------------------------------------------------------+--------------------------------------------------------------------+-------------------------------╯
     */

    // Storage mapping from L2Registry.sol
    // `cast storage -r "https://base-sepolia-rpc.publicnode.com" 0x4Cd8e4135C41cd6982F2b2745D226d794b8A28ca`
    uint256 constant SLOT_VERSIONS = 6;
    uint256 constant SLOT_ABI = 7;
    uint256 constant SLOT_ADDRS = 8;
    uint256 constant SLOT_CHASH = 9;
    uint256 constant SLOT_TEXTS = 10;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    INameWrapper public immutable nameWrapper;

    mapping(bytes32 node => L2Registry l2Registry) public l2Registry;

    /// @dev Mapping of chainId to verifier
    mapping(uint64 => IGatewayVerifier) _verifiers;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event L2RegistrySet(
        bytes32 node,
        uint64 targetChainId,
        address targetRegistryAddress
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error InvalidSignature();
    error OffchainLookup(
        address sender,
        string[] urls,
        bytes callData,
        bytes4 callbackFunction,
        bytes extraData
    );

    /// @param name DNS-encoded ENS name that does not exist.
    error UnreachableName(bytes name);

    /// @param selector Function selector of the resolver profile that cannot be answered.
    error UnsupportedResolverProfile(bytes4 selector);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) Ownable(_owner) {
        // Get the NameWrapper address from namewrapper.eth
        // This allows us to have the same deploy bytecode on mainnet and sepolia
        bytes32 wrapperNode = 0xdee478ba2734e34d81c6adc77a32d75b29007895efa2fe60921f1c315e1ec7d9; // namewrapper.eth
        address wrapperResolver = ens.resolver(wrapperNode);
        address wrapperAddr = IAddrResolver(wrapperResolver).addr(wrapperNode);
        nameWrapper = INameWrapper(wrapperAddr);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Specify the L2 registry for a given name. Should only be used with 2LDs, e.g. "nick.eth".
    function setL2Registry(
        bytes32 node,
        uint64 targetChainId,
        address targetRegistryAddress
    ) external {
        address owner = ens.owner(node);

        if (owner == address(nameWrapper)) {
            owner = nameWrapper.ownerOf(uint256(node));
        }

        if (owner != msg.sender) {
            revert Unauthorized();
        }

        l2Registry[node] = L2Registry(targetChainId, targetRegistryAddress);
        emit L2RegistrySet(node, targetChainId, targetRegistryAddress);
    }

    /// @notice Resolves a name, as specified by ENSIP 10.
    /// @param name The DNS-encoded name to resolve.
    /// @param request The ABI encoded data for the underlying resolution function (Eg, addr(bytes32), text(bytes32,string), etc).
    /// @return The return data, ABI encoded identically to the underlying function.
    function resolve(
        bytes calldata name,
        bytes calldata request
    ) external view override returns (bytes memory) {
        string memory decodedName = NameCoder.decode(name); // 'sub.name.eth'
        strings.slice memory s = strings.toSlice(decodedName);
        strings.slice memory delim = strings.toSlice(".");
        string[] memory parts = new string[](strings.count(s, delim) + 1);

        // Populate the parts array into ['sub', 'name', 'eth']
        for (uint i = 0; i < parts.length; i++) {
            parts[i] = strings.toString(strings.split(s, delim));
        }

        // get the 2LD + TLD (final 2 parts), regardless of how many labels the name has
        string memory parentName = string.concat(
            parts[parts.length - 2],
            ".",
            parts[parts.length - 1]
        );

        // Encode the parent name
        bytes memory parentNameBytes = NameCoder.encode(parentName);
        bytes32 parentNode = NameCoder.namehash(parentNameBytes, 0);
        L2Registry memory targetL2Registry = l2Registry[parentNode];
        IGatewayVerifier verifier = _verifiers[targetL2Registry.chainId];

        if (
            targetL2Registry.registryAddress == address(0) ||
            address(verifier) == address(0)
        ) {
            revert UnreachableName(name);
        }

        bytes4 selector = bytes4(request);
        bytes32 node = NameCoder.namehash(name, 0);

        // ENSIP-20 / ERC-7884
        if (selector == IOperationRouter.getOperationHandler.selector) {
            revert IOperationRouter.OperationHandledOnchain(
                targetL2Registry.chainId,
                targetL2Registry.registryAddress
            );
        }

        // Build a Unruggable Gateways request based on the function selector of the passed calldata
        GatewayRequest memory req = GatewayFetcher.newRequest(1);
        req.setTarget(targetL2Registry.registryAddress);

        if (selector == IABIResolver.ABI.selector) {
            //
        } else if (selector == IAddressResolver.addr.selector) {
            //
        } else if (selector == IAddrResolver.addr.selector) {
            // First read the version of the node from the `recordVersions` slot
            req.setSlot(SLOT_VERSIONS).push(node).follow().readBytes();
            // Then read the address from the `versionable_addresses` slot
        } else if (selector == IContentHashResolver.contenthash.selector) {
            //
        } else if (selector == ITextResolver.text.selector) {
            //
        } else {
            revert UnsupportedResolverProfile(selector);
        }

        /// Execute the Unruggable Gateways CCIP request
        /// Pass through the called function selector in our carry bytes such that the callback can appropriately decode the response
        fetch(verifier, req, this.resolveCallback.selector);
    }

    /// @notice The callback for the `OffchainLookup` triggered by our implementation of `IExtendedResolver` (ENSIP-10).
    function resolveCallback(
        bytes[] memory values,
        uint8,
        bytes memory carry
    ) external pure returns (bytes memory) {
        bytes4 selector = abi.decode(carry, (bytes4));

        /// If we have an address as bytes, re-encode it correctly for decoding at the library level
        if (selector == IAddrResolver.addr.selector) {
            return abi.encode(uint160(bytes20(values[0])));
        }

        return abi.encode(values[0]);
    }

    function supportsInterface(bytes4 interfaceID) public pure returns (bool) {
        return
            interfaceID == type(IExtendedResolver).interfaceId ||
            interfaceID == 0x01ffc9a7; // ERC-165 interface
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Define the appropriate default Unruggable Gateway Verifier with a chainId
    function setVerifier(
        uint64 chainId,
        IGatewayVerifier verifier
    ) external onlyOwner {
        _verifiers[chainId] = verifier;
    }
}
