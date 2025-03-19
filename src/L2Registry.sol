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
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {NameEncoder} from "@ensdomains/ens-contracts/utils/NameEncoder.sol";

import {L2Resolver} from "./L2Resolver.sol";

/// @title Durin Registry
/// @author NameStone
/// @notice Manages ENS subname registration and management on L2
/// @dev Combined Registry, BaseRegistrar and Resolver from the official .eth contracts
contract L2Registry is L2Resolver, Initializable, ERC721, AccessControl {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Role identifier for administrative operations
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    /// @notice Role identifier for registrar operations
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");
    /// @notice Total number of registered names
    uint256 public totalSupply;
    /// @notice The parent ENS node
    bytes32 public parentNode;

    string private _tokenName;
    string private _tokenSymbol;
    string private _tokenBaseURI;

    /// @notice Mapping of node (namehash) to name (DNS-encoded)
    /// @dev Same mapping as NameWrapper
    mapping(bytes32 node => bytes name) public names;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new name is registered
    event Registered(string name, address owner);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error LabelTooShort();
    error LabelTooLong(string label);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if caller is token operator or has registrar role
    /// @param labelhash The hash of the label to check permissions for
    modifier onlyTokenOperatorOrRegistrar(bytes32 labelhash) {
        address owner = _ownerOf(uint256(labelhash));
        if (
            owner != msg.sender &&
            !isApprovedForAll(owner, msg.sender) &&
            !hasRole(REGISTRAR_ROLE, msg.sender)
        ) {
            revert Unauthorized();
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
        (bytes memory dnsEncodedName, bytes32 _parentNode) = NameEncoder
            .dnsEncodeName(tokenName);

        // ERC721
        _tokenName = tokenName;
        _tokenSymbol = tokenSymbol;
        _tokenBaseURI = baseURI;

        // Registry
        parentNode = _parentNode;
        names[parentNode] = dnsEncodedName;

        // Access control
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Registers a new name
    /// @dev Only callable by addresses with `REGISTRAR_ROLE`
    /// @param label The label to register
    /// @param owner The address that will own the name
    function register(
        string calldata label,
        address owner
    ) external onlyRole(REGISTRAR_ROLE) {
        bytes32 node = _makeNode(parentNode, _labelhash(label));

        // This will revert if the node is already registered
        _safeMint(owner, uint256(node));

        totalSupply++;
        names[node] = _addLabel(label, names[parentNode]);
        emit Registered(label, owner);
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
    function addRegistrar(address registrar) external onlyRole(ADMIN_ROLE) {
        _grantRole(REGISTRAR_ROLE, registrar);
    }

    /// @notice Removes a registrar address
    /// @param registrar The address to revoke registrar role from
    /// @dev Only callable by admin role
    function removeRegistrar(address registrar) external onlyRole(ADMIN_ROLE) {
        _revokeRole(REGISTRAR_ROLE, registrar);
    }

    /// @notice Sets the base URI for token metadata
    /// @param baseURI The new base URI
    /// @dev Only callable by admin role
    function setBaseURI(string memory baseURI) external onlyRole(ADMIN_ROLE) {
        _tokenBaseURI = baseURI;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _labelhash(string calldata label) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(label));
    }

    function _makeNode(
        bytes32 node,
        bytes32 labelhash
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(node, labelhash));
    }

    function _addLabel(
        string memory label,
        bytes memory _name
    ) internal pure returns (bytes memory ret) {
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
    ) public view override(ERC721, AccessControl, L2Resolver) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
