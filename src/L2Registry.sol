// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ***********************************************
// ▗▖  ▗▖ ▗▄▖ ▗▖  ▗▖▗▄▄▄▖ ▗▄▄▖▗▄▄▄▖▗▄▖ ▗▖  ▗▖▗▄▄▄▖
// ▐▛▚▖▐▌▐▌ ▐▌▐▛▚▞▜▌▐▌   ▐▌     █ ▐▌ ▐▌▐▛▚▖▐▌▐▌
// ▐▌ ▝▜▌▐▛▀▜▌▐▌  ▐▌▐▛▀▀▘ ▝▀▚▖  █ ▐▌ ▐▌▐▌ ▝▜▌▐▛▀▀▘
// ▐▌  ▐▌▐▌ ▐▌▐▌  ▐▌▐▙▄▄▖▗▄▄▞▘  █ ▝▚▄▞▘▐▌  ▐▌▐▙▄▄▖
// ***********************************************

import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {NameCoder} from "@ensdomains/ens-contracts/utils/NameCoder.sol";
import {strings} from "@arachnid/string-utils/strings.sol";

import {L2Resolver} from "./L2Resolver.sol";

/// @title Durin Registry
/// @author NameStone
/// @notice Manages ENS subname registration and management on L2
/// @dev Combined Registry, BaseRegistrar and PublicResolver from the official .eth contracts
contract L2Registry is ERC721, Initializable, L2Resolver {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The base node for the registry
    /// @dev namehash of `name()`
    bytes32 public baseNode;

    /// @notice Total number of subnames
    /// @dev Includes names at any depth
    uint256 public totalSupply;

    string private _tokenName;
    string private _tokenSymbol;
    string private _tokenBaseUri;

    /// @notice Mapping of node (namehash) to name (DNS-encoded)
    mapping(bytes32 node => bytes name) public names;

    /// @notice Mapping of approved registrar controllers
    mapping(address registrar => bool approved) public registrars;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a name is created at any level
    event SubnodeCreated(bytes32 indexed node, bytes name, address owner);

    /// @notice Emitted when a new label is created (ENSIP-16)
    event NewSubname(bytes32 indexed labelhash, string label);

    event RegistrarAdded(address registrar);
    event RegistrarRemoved(address registrar);
    event BaseURIUpdated(string baseURI);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error LabelTooShort();
    error LabelTooLong(string label);
    error NotAvailable(string label, bytes32 parentNode);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Only the owner of the node or a registrar can call the function
    modifier onlyOwnerOrRegistrar(bytes32 node) {
        _onlyOwnerOrRegistrar(node);
        _;
    }

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() ERC721("", "") {
        _disableInitializers();
    }

    /// @notice Initializes the registry
    /// @param tokenName The parent ENS name, and name of the NFT collection
    /// @param tokenSymbol The symbol of the NFT collection
    /// @param baseURI The base URI of the NFT collection
    /// @param admin The address that will be granted admin role
    function initialize(
        string calldata tokenName,
        string calldata tokenSymbol,
        string calldata baseURI,
        address admin
    ) external initializer {
        bytes memory dnsEncodedName = NameCoder.encode(tokenName);
        bytes32 node = NameCoder.namehash(dnsEncodedName, 0);

        // ERC721
        _tokenName = tokenName;
        _tokenSymbol = tokenSymbol;
        _setBaseURI(baseURI);

        // Registry
        baseNode = node;
        names[baseNode] = dnsEncodedName;

        // Extract the label
        strings.slice memory s = strings.toSlice(tokenName);
        strings.slice memory delim = strings.toSlice(".");
        string memory label = strings.toString(strings.split(s, delim));
        bytes32 labelhash = keccak256(bytes(label));

        // Mint the base node to the admin
        emit SubnodeCreated(node, dnsEncodedName, admin);
        emit NewSubname(labelhash, label);
        _safeMint(admin, uint256(node));
        totalSupply++;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a subnode from a parent node and label
    /// @dev Only callable by the owner of the parent node
    /// @param node The parent node, e.g. `namehash("name.eth")` for "name.eth"
    /// @param label The label of the subnode, e.g. "x" for "x.name.eth"
    /// @param _owner The address that will own the subnode
    /// @param data The encoded calldata for resolver setters
    /// @return The resulting subnode, e.g. `namehash("x.name.eth")` for "x.name.eth"
    function createSubnode(
        bytes32 node,
        string calldata label,
        address _owner,
        bytes[] calldata data
    ) external onlyOwnerOrRegistrar(node) returns (bytes32) {
        bytes32 subnode = makeNode(node, label);
        bytes32 labelhash = keccak256(bytes(label));
        bytes memory dnsEncodedName = _addLabel(label, names[node]);

        if (owner(subnode) != address(0)) {
            revert NotAvailable(label, node);
        }

        _safeMint(_owner, uint256(subnode));
        _multicall(subnode, data);
        names[subnode] = dnsEncodedName;
        totalSupply++;

        emit SubnodeCreated(subnode, dnsEncodedName, _owner);
        emit NewSubname(labelhash, label);
        return subnode;
    }

    /// @notice Helper to derive a node from a name
    /// @dev In practice, this should be performed offchain
    function namehash(string calldata _name) external pure returns (bytes32) {
        bytes memory dnsEncodedName = NameCoder.encode(_name);
        bytes32 node = NameCoder.namehash(dnsEncodedName, 0);
        return node;
    }

    /// @notice Helper to decode a DNS-encoded name
    /// @dev In practice, this should be performed offchain
    function decodeName(
        bytes calldata _name
    ) external pure returns (string memory) {
        return NameCoder.decode(_name);
    }

    /// @notice Helper to derive a node from a parent node and label
    /// @param parentNode The namehash of the parent, e.g. `namehash("name.eth")` for "name.eth"
    /// @param label The label of the subnode, e.g. "x" for "x.name.eth"
    /// @return The resulting subnode, e.g. `namehash("x.name.eth")` for "x.name.eth"
    function makeNode(
        bytes32 parentNode,
        string calldata label
    ) public pure returns (bytes32) {
        bytes32 labelhash = keccak256(bytes(label));
        return NameCoder.namehash(parentNode, labelhash);
    }

    /// @notice The admin of the registry
    function owner() public view returns (address) {
        return owner(baseNode);
    }

    /// @notice Returns the address that owns the specified node
    /// @dev We need this because `ERC721.ownerOf()` reverts if the token doesn't exist
    function owner(bytes32 node) public view returns (address) {
        return _ownerOf(uint256(node));
    }

    /// @notice The name of the NFT collection and base ENS name
    function name() public view override returns (string memory) {
        return _tokenName;
    }

    /// @notice The symbol of the NFT collection
    function symbol() public view override returns (string memory) {
        return _tokenSymbol;
    }

    /// @notice The base URI for NFT metadata
    function _baseURI() internal view override returns (string memory) {
        return _tokenBaseUri;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Adds a new registrar address
    /// @param registrar The address to grant registrar role to
    /// @dev Only callable by admin role
    function addRegistrar(address registrar) external onlyOwner {
        registrars[registrar] = true;
        emit RegistrarAdded(registrar);
    }

    /// @notice Removes a registrar address
    /// @param registrar The address to revoke registrar role from
    /// @dev Only callable by admin role
    function removeRegistrar(address registrar) external onlyOwner {
        registrars[registrar] = false;
        emit RegistrarRemoved(registrar);
    }

    /// @notice Sets the base URI for token metadata
    /// @param baseURI The new base URI
    /// @dev Only callable by admin role
    function setBaseURI(string calldata baseURI) external onlyOwner {
        _setBaseURI(baseURI);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Adds a label to its parent DNS-encoded name
    /// @param label The label to add
    /// @param parentName The parent DNS-encoded name
    /// @return ret The resulting DNS-encoded name
    function _addLabel(
        string memory label,
        bytes memory parentName
    ) private pure returns (bytes memory ret) {
        if (bytes(label).length < 1) {
            revert LabelTooShort();
        }
        if (bytes(label).length > 255) {
            revert LabelTooLong(label);
        }
        return abi.encodePacked(uint8(bytes(label).length), label, parentName);
    }

    function _onlyOwner() internal view {
        if (owner() != msg.sender) {
            revert Unauthorized(baseNode);
        }
    }

    function _onlyOwnerOrRegistrar(bytes32 node) internal view {
        if (owner(node) != msg.sender && !registrars[msg.sender]) {
            revert Unauthorized(node);
        }
    }

    function _setBaseURI(string calldata baseURI) private {
        _tokenBaseUri = baseURI;
        emit BaseURIUpdated(baseURI);
    }

    /*//////////////////////////////////////////////////////////////
                               OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns onchain JSON if no baseURI is set
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        if (bytes(_tokenBaseUri).length == 0) {
            _requireOwned(tokenId);

            string memory json = string.concat(
                '{"name": "',
                NameCoder.decode(names[bytes32(tokenId)]),
                '"}'
            );

            return
                string.concat(
                    "data:application/json;base64,",
                    Base64.encode(bytes(json))
                );
        }

        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, L2Resolver) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
