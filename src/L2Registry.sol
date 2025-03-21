// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ***********************************************
// ▗▖  ▗▖ ▗▄▖ ▗▖  ▗▖▗▄▄▄▖ ▗▄▄▖▗▄▄▄▖▗▄▖ ▗▖  ▗▖▗▄▄▄▖
// ▐▛▚▖▐▌▐▌ ▐▌▐▛▚▞▜▌▐▌   ▐▌     █ ▐▌ ▐▌▐▛▚▖▐▌▐▌
// ▐▌ ▝▜▌▐▛▀▜▌▐▌  ▐▌▐▛▀▀▘ ▝▀▚▖  █ ▐▌ ▐▌▐▌ ▝▜▌▐▛▀▀▘
// ▐▌  ▐▌▐▌ ▐▌▐▌  ▐▌▐▙▄▄▖▗▄▄▞▘  █ ▝▚▄▞▘▐▌  ▐▌▐▙▄▄▖
// ***********************************************

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {NameEncoder} from "@ensdomains/ens-contracts/utils/NameEncoder.sol";

import {L2Resolver} from "./L2Resolver.sol";

/// @title Durin Registry
/// @author NameStone
/// @notice Manages ENS subname registration and management on L2
/// @dev Combined Registry, BaseRegistrar and Resolver from the official .eth contracts
contract L2Registry is L2Resolver, Initializable, ERC721 {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public baseNode;

    string private _tokenName;
    string private _tokenSymbol;
    string private _tokenBaseURI;

    /// @notice Mapping of node (namehash) to name (DNS-encoded)
    /// @dev Same mapping as NameWrapper
    mapping(bytes32 node => bytes name) public names;

    /// @notice Mapping of approved registrar controllers
    mapping(address registrar => bool approved) public registrars;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a name is registered at any level
    /// @dev Not identical to ENS contracts, but added for convenience
    event NameRegistered(bytes32 indexed node, bytes name, address owner);

    /// @notice Emitted when a subnode is registered at any level
    /// @dev Same event signature as the ENS Registry
    event NewOwner(
        bytes32 indexed parentNode,
        bytes32 indexed labelhash,
        address owner
    );

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
        if (owner(node) != msg.sender && !registrars[msg.sender]) {
            revert Unauthorized(node);
        }
        _;
    }

    modifier onlyOwner() {
        if (owner() != msg.sender) {
            revert Unauthorized(baseNode);
        }
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
        (bytes memory dnsEncodedName, bytes32 node) = NameEncoder.dnsEncodeName(
            tokenName
        );

        // ERC721
        _tokenName = tokenName;
        _tokenSymbol = tokenSymbol;
        _setBaseURI(baseURI);

        // Registry
        baseNode = node;
        names[baseNode] = dnsEncodedName;
        _safeMint(admin, uint256(node));
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a node under an existing node (nested subname)
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
        bytes32 labelhash = keccak256(abi.encodePacked(label));
        bytes32 subnode = makeNode(node, labelhash);
        bytes memory dnsEncodedName = _addLabel(label, names[node]);

        if (owner(subnode) != address(0)) {
            revert NotAvailable(label, node);
        }

        _safeMint(_owner, uint256(subnode));
        _multicall(subnode, data);
        names[subnode] = dnsEncodedName;

        emit NewOwner(node, labelhash, _owner);
        emit NameRegistered(subnode, dnsEncodedName, _owner);
        return subnode;
    }

    /// @notice The admin of the registry
    function owner() public view returns (address) {
        return owner(baseNode);
    }

    /// @notice Returns the address that owns the specified node.
    /// @dev We need this because `ERC721.ownerOf` reverts if the token doesn't exist
    function owner(bytes32 node) public view returns (address) {
        return _ownerOf(uint256(node));
    }

    /// @notice Helper to derive a node from a parent node and labelhash
    /// @param node The parent node, e.g. `namehash("name.eth")` for "name.eth"
    /// @param labelhash The labelhash of the subnode, e.g. `keccak256("x")` for "x.name.eth"
    /// @return The resulting subnode, e.g. `namehash("x.name.eth")` for "x.name.eth"
    function makeNode(
        bytes32 node,
        bytes32 labelhash
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(node, labelhash));
    }

    /// @notice The NFT collection name.
    function name() public view override returns (string memory) {
        return _tokenName;
    }

    /// @notice The NFT collection symbol.
    function symbol() public view override returns (string memory) {
        return _tokenSymbol;
    }

    /// @notice The base URI for NFT metadata.
    function _baseURI() internal view virtual override returns (string memory) {
        return _tokenBaseURI;
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
    function setBaseURI(string memory baseURI) external onlyOwner {
        _setBaseURI(baseURI);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setBaseURI(string memory baseURI) private {
        _tokenBaseURI = baseURI;
        emit BaseURIUpdated(baseURI);
    }

    function _addLabel(
        string memory label,
        bytes memory _name
    ) private pure returns (bytes memory ret) {
        if (bytes(label).length < 1) {
            revert LabelTooShort();
        }
        if (bytes(label).length > 255) {
            revert LabelTooLong(label);
        }
        return abi.encodePacked(uint8(bytes(label).length), label, _name);
    }

    /*//////////////////////////////////////////////////////////////
                           REQUIRED OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, L2Resolver) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
