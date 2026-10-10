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

    bytes16 private constant _HEX_DIGITS = "0123456789abcdef";

    string private _tokenName;
    string private _tokenSymbol;
    string private _tokenBaseUri;

    /// @notice Mapping of node (namehash) to name (DNS-encoded)
    mapping(bytes32 node => bytes name) public names;

    /// @notice Mapping of approved registrar controllers
    /// @dev Registrars are fully trusted: they can create subnodes under any node and update the records of any node
    mapping(address registrar => bool approved) public registrars;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a name is created at any level
    event SubnodeCreated(bytes32 indexed node, bytes name, address owner);

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
    error InvalidLabel(string label);
    error NotAvailable(string label, bytes32 parentNode);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Only the owner of the node, an operator approved by the owner, the address approved for the token or a
    ///      registrar can call the function. This matches who can update the node's records.
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
        totalSupply++;
        _safeMint(admin, uint256(node));
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a subnode from a parent node and label
    /// @dev Only callable by the owner of the parent node, an operator approved by the owner, the address approved for
    ///      the parent token or a registrar
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

        // Update state and emit events before `_safeMint()` which calls `onERC721Received()` on `_owner`
        names[subnode] = dnsEncodedName;
        totalSupply++;
        emit NewOwner(node, labelhash, _owner);
        emit SubnodeCreated(subnode, dnsEncodedName, _owner);

        // Records are set after minting so the new owner is authorised for them
        _safeMint(_owner, uint256(subnode));
        _multicall(subnode, data);
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
        return keccak256(abi.encodePacked(parentNode, labelhash));
    }

    /// @notice The admin of the registry
    /// @dev This is the owner of the `baseNode` token, so transferring that token transfers admin rights
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
        // A "." in a label would make the decoded name ambiguous, e.g. "a.b" under "name.eth" displays as "a.b.name.eth"
        for (uint256 i = 0; i < bytes(label).length; i++) {
            if (bytes(label)[i] == ".") {
                revert InvalidLabel(label);
            }
        }
        return abi.encodePacked(uint8(bytes(label).length), label, _name);
    }

    function _onlyOwner() internal view {
        if (owner() != msg.sender) {
            revert Unauthorized(baseNode);
        }
    }

    function _onlyOwnerOrRegistrar(bytes32 node) internal view {
        address nodeOwner = owner(node);
        if (
            nodeOwner != msg.sender &&
            !registrars[msg.sender] &&
            !isApprovedForAll(nodeOwner, msg.sender) &&
            _getApproved(uint256(node)) != msg.sender
        ) {
            revert Unauthorized(node);
        }
    }

    function _setBaseURI(string calldata baseURI) private {
        _tokenBaseUri = baseURI;
        emit BaseURIUpdated(baseURI);
    }

    /// @dev Escapes a string so it can be safely embedded in a JSON string value
    function _escapeJSON(
        string memory input
    ) private pure returns (string memory) {
        bytes memory buffer = bytes(input);
        // Worst case: every byte becomes a 6-byte `\u00XX` escape sequence
        bytes memory output = new bytes(buffer.length * 6);
        uint256 outputLength = 0;

        for (uint256 i = 0; i < buffer.length; i++) {
            bytes1 char = buffer[i];
            if (char == '"' || char == "\\") {
                output[outputLength++] = "\\";
                output[outputLength++] = char;
            } else if (uint8(char) < 0x20) {
                output[outputLength++] = "\\";
                output[outputLength++] = "u";
                output[outputLength++] = "0";
                output[outputLength++] = "0";
                output[outputLength++] = _HEX_DIGITS[uint8(char) >> 4];
                output[outputLength++] = _HEX_DIGITS[uint8(char) & 0x0f];
            } else {
                output[outputLength++] = char;
            }
        }

        assembly ("memory-safe") {
            mstore(output, outputLength)
        }
        return string(output);
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
                _escapeJSON(NameCoder.decode(names[bytes32(tokenId)])),
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
