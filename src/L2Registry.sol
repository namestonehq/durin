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
import {BytesUtils} from "@ensdomains/ens-contracts/utils/BytesUtils.sol";

import {ENSDNSUtils} from "./utils/ENSDNSUtils.sol";

/// @title ENS Subname Registry
/// @author NameStone
/// @notice Manages ENS subname registration and management on L2
/// @dev Combined Registry, BaseRegistrar and Resolver from the official .eth contracts
contract L2Registry is Initializable, ERC721, AccessControl {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Role identifier for administrative operations
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    /// @notice Role identifier for registrar operations
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");
    /// @notice Total number of registered names
    uint256 public totalSupply;

    string private _name;
    string private _symbol;
    string private _baseUri;

    /// @notice Mapping of node (namehash) to name (DNS-encoded)
    /// @dev Same mapping as in NameWrapper
    mapping(bytes32 node => bytes name) public names;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new name is registered
    event Registered(string name, address owner);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when caller lacks required permissions
    error Unauthorized();

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

    /// @notice Initializes the registry with name, symbol, and base URI
    /// @param tokenName The name for the ERC721 token
    /// @param tokenSymbol The symbol for the ERC721 token
    function initialize(
        string calldata tokenName,
        string calldata tokenSymbol,
        string calldata baseURI,
        address admin
    ) external initializer {
        _name = tokenName;
        _symbol = tokenSymbol;
        _baseUri = baseURI;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Registers a new name
    /// @param label The name to register
    /// @param owner The address that will own the name
    /// @dev Only callable by addresses with registrar role
    function register(
        string calldata label,
        address owner
    ) external onlyRole(REGISTRAR_ROLE) {
        bytes32 labelhash = keccak256(abi.encodePacked(label));
        uint256 tokenId = uint256(labelhash);
        // This will fail if the node is already registered
        _safeMint(owner, tokenId);
        // _labels[labelhash] = label;
        totalSupply++;
        emit Registered(label, owner);
    }

    /// @notice The token collection name.
    function name() public view override returns (string memory) {
        return _name;
    }

    /// @notice The token collection symbol.
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /// @notice The base URI for token metadata.
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseUri;
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
        _baseUri = baseURI;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // function _deriveNode(string calldata name) private pure returns (bytes32) {
    //     bytes memory dnsEncodedName = ENSDNSUtils.dnsEncode(name);
    //     bytes32 node = BytesUtils.namehash(dnsEncodedName, 0);
    //     return node;
    // }

    /*//////////////////////////////////////////////////////////////
                           REQUIRED OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
