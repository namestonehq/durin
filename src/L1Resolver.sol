// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BytesUtils} from "@ensdomains/ens-contracts/utils/BytesUtils.sol";
import {ENS} from "@ensdomains/ens-contracts/registry/ENS.sol";
import {IExtendedResolver} from "@ensdomains/ens-contracts/resolvers/profiles/IExtendedResolver.sol";
import {strings} from "@arachnid/string-utils/strings.sol";
import {NameEncoder} from "@ensdomains/ens-contracts/utils/NameEncoder.sol";

import {SignatureVerifier} from "./lib/SignatureVerifier.sol";
import {ENSDNSUtils} from "./lib/ENSDNSUtils.sol";

interface IResolverService {
    function stuffedResolveCall(
        bytes calldata name,
        bytes calldata data,
        uint64 targetChainId,
        address targetRegistryAddress
    )
        external
        view
        returns (bytes memory result, uint64 expires, bytes memory sig);
}

interface INameWrapper {
    function ownerOf(uint256 id) external view returns (address owner);
}

/// @notice Implements an ENS resolver that directs all queries to a CCIP read gateway.
/// @dev Callers must implement EIP 3668 and ENSIP 10.
contract L1Resolver is IExtendedResolver {
    string public url;
    ENS public ens;
    INameWrapper nameWrapper;

    struct L2Registry {
        uint64 chainId;
        address registryAddress;
    }

    mapping(address => bool) public signers;
    mapping(bytes32 node => L2Registry l2Registry) public l2Registry;

    event SignerAdded(address signer);
    event SignerRemoved(address signer);

    error Unauthorized();
    error InvalidSignature();
    error UnsupportedName();
    error OffchainLookup(
        address sender,
        string[] urls,
        bytes callData,
        bytes4 callbackFunction,
        bytes extraData
    );

    constructor(
        address _ens,
        address _nameWrapper,
        string memory _url,
        address _signer
    ) {
        ens = ENS(_ens);
        nameWrapper = INameWrapper(_nameWrapper);
        url = _url;
        signers[_signer] = true;
        emit SignerAdded(_signer);
    }

    function makeSignatureHash(
        address target,
        uint64 expires,
        bytes memory request,
        bytes memory result
    ) external pure returns (bytes32) {
        return
            SignatureVerifier.makeSignatureHash(
                target,
                expires,
                request,
                result
            );
    }

    /// @notice Resolves a name, as specified by ENSIP 10.
    /// @param name The DNS-encoded name to resolve.
    /// @param data The ABI encoded data for the underlying resolution function (Eg, addr(bytes32), text(bytes32,string), etc).
    /// @return The return data, ABI encoded identically to the underlying function.
    function resolve(
        bytes calldata name,
        bytes calldata data
    ) external view override returns (bytes memory) {
        string memory decodedName = ENSDNSUtils.dnsDecode(name); // 'sub.name.eth'
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
        (bytes memory parentNameEncoded, bytes32 parentNode) = NameEncoder
            .dnsEncodeName(parentName);

        L2Registry memory targetL2Registry = l2Registry[parentNode];

        return
            stuffedResolveCall(
                name,
                data,
                targetL2Registry.chainId,
                targetL2Registry.registryAddress
            );
    }

    /// @dev Add target registry info to the CCIP Read error.
    function stuffedResolveCall(
        bytes calldata name,
        bytes calldata data,
        uint64 targetChainId,
        address targetRegistryAddress
    ) internal view returns (bytes memory) {
        bytes memory callData = abi.encodeWithSelector(
            IResolverService.stuffedResolveCall.selector,
            name,
            data,
            targetChainId,
            targetRegistryAddress
        );

        string[] memory urls = new string[](1);
        urls[0] = url;

        revert OffchainLookup(
            address(this), // sender
            urls, // urls
            callData, // callData
            L1Resolver.resolveWithProof.selector, // callbackFunction
            callData // extraData
        );
    }

    /// @notice Callback used by CCIP read compatible clients to parse and verify the response.
    function resolveWithProof(
        bytes calldata response,
        bytes calldata extraData
    ) external view returns (bytes memory) {
        (address signer, bytes memory result) = SignatureVerifier.verify(
            extraData,
            response
        );

        if (!signers[signer]) {
            revert InvalidSignature();
        }

        return result;
    }

    function supportsInterface(bytes4 interfaceID) public pure returns (bool) {
        return
            interfaceID == type(IExtendedResolver).interfaceId ||
            interfaceID == 0x01ffc9a7; // ERC-165 interface
    }

    /// @notice Sets the URL for the resolver service. Only callable by the signers.
    function setURL(string calldata _url) external onlySigners {
        url = _url;
    }

    /// @notice Sets the signers for the resolver service. Only callable by the signers.
    function addSigner(address _signer) external onlySigners {
        signers[_signer] = true;
        emit SignerAdded(_signer);
    }

    function removeSigner(address _signer) external onlySigners {
        signers[_signer] = false;
        emit SignerRemoved(_signer);
    }

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
    }

    modifier onlySigners() {
        if (!signers[msg.sender]) {
            revert Unauthorized();
        }
        _;
    }
}
