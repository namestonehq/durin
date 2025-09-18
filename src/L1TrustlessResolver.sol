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

    // Storage mapping from L2Registry.sol
    uint256 constant SLOT_VERSIONS = 6;
    uint256 constant SLOT_ABI = 7;
    uint256 constant SLOT_ADDRS = 8;
    uint256 constant SLOT_CONTENTHASH = 9;
    uint256 constant SLOT_TEXTS = 10;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    INameWrapper public immutable nameWrapper;

    mapping(bytes32 node => L2Registry l2Registry) public l2Registry;

    /// @dev Mapping of chainId to verifier
    mapping(uint64 => IGatewayVerifier) public verifier;

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
    /// @param data The ABI encoded data for the underlying resolution function (Eg, addr(bytes32), text(bytes32,string), etc).
    /// @return The return data, ABI encoded identically to the underlying function.
    function resolve(
        bytes calldata name,
        bytes calldata data
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
        IGatewayVerifier v = verifier[targetL2Registry.chainId];

        if (
            targetL2Registry.registryAddress == address(0) ||
            address(v) == address(0)
        ) {
            revert UnreachableName(name);
        }

        bytes4 selector = bytes4(data);
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
        req.push(node); // leave on stack as offset 0
        req.setSlot(SLOT_VERSIONS); // recordVersions
        req.pushStack(0).follow(); // recordVersions[node]
        req.read(); // version, leave on stack at offset 1

        if (selector == IABIResolver.ABI.selector) {
            (, uint256 contentTypes) = abi.decode(data[4:], (bytes32, uint256));
            req.setSlot(SLOT_ABI); // abi
            req.follow().follow().push(contentTypes).follow(); // abi[version][node][contentTypes]
            req.readBytes().setOutput(0);
        } else if (selector == IAddressResolver.addr.selector) {
            (, uint256 coinType) = abi.decode(data[4:], (bytes32, uint256));
            req.setSlot(SLOT_ADDRS); // addr
            req.follow().follow().push(coinType).follow(); // addr[version][node][coinType]
            req.readBytes().setOutput(0);
        } else if (selector == IAddrResolver.addr.selector) {
            req.setSlot(SLOT_ADDRS); // addr
            req.follow().follow().push(60).follow(); // addr[version][node][60]
            req.readBytes().setOutput(0);
        } else if (selector == IContentHashResolver.contenthash.selector) {
            req.setSlot(SLOT_CONTENTHASH); // contenthash
            req.follow().follow(); // contenthash[version][node]
            req.readBytes().setOutput(0);
        } else if (selector == ITextResolver.text.selector) {
            (, string memory key) = abi.decode(data[4:], (bytes32, string));
            req.setSlot(SLOT_TEXTS); // text
            req.follow().follow().push(key).follow(); // text[version][node][key]
            req.readBytes().setOutput(0);
        } else {
            revert UnsupportedResolverProfile(selector);
        }

        /// Execute the Unruggable Gateways CCIP request
        fetch(v, req, this.resolveCallback.selector, data, v.gatewayURLs());
    }

    /// @notice The callback for the `OffchainLookup` triggered by our implementation of `IExtendedResolver` (ENSIP-10).
    function resolveCallback(
        bytes[] memory values,
        uint8,
        bytes memory data
    ) external pure returns (bytes memory) {
        bytes memory value = values[0];

        if (bytes4(data) == IAddrResolver.addr.selector) {
            return abi.encode(address(bytes20(value)));
        }

        return abi.encode(value);
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
        IGatewayVerifier verifierAddress
    ) external onlyOwner {
        verifier[chainId] = verifierAddress;
    }
}
