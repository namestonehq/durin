// ***********************************************
// ▗▖  ▗▖ ▗▄▖ ▗▖  ▗▖▗▄▄▄▖ ▗▄▄▖▗▄▄▄▖▗▄▖ ▗▖  ▗▖▗▄▄▄▖
// ▐▛▚▖▐▌▐▌ ▐▌▐▛▚▞▜▌▐▌   ▐▌     █ ▐▌ ▐▌▐▛▚▖▐▌▐▌
// ▐▌ ▝▜▌▐▛▀▜▌▐▌  ▐▌▐▛▀▀▘ ▝▀▚▖  █ ▐▌ ▐▌▐▌ ▝▜▌▐▛▀▀▘
// ▐▌  ▐▌▐▌ ▐▌▐▌  ▐▌▐▙▄▄▖▗▄▄▞▘  █ ▝▚▄▞▘▐▌  ▐▌▐▙▄▄▖
// ***********************************************

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @author darianb.eth + Unruggable(clowes.eth)
/// @custom:project Durin
/// @custom:company NameStone
/// @notice Combined registry and resolver contract for Layer 2 name resolution
/// @dev Implements ERC721 for name ownership and AccessControl for permissions

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {BytesUtils} from "@ensdomains/ens-contracts/utils/BytesUtils.sol";

import {ENSDNSUtils} from "./utils/ENSDNSUtils.sol";

/// @title Registry/Resolver All-in-one (for Layer 2)
/// @notice Manages name registration, ownership, and resolution on Layer 2
/// @dev Uses labelhash instead of node for resolution functions
contract L2Registry is Initializable, ERC721, AccessControl {
    /// @notice Implements interface detection for ERC721 and AccessControl
    /// @param x The interface identifier to check
    /// @return bool True if the interface is supported
    function supportsInterface(
        bytes4 x
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(x);
    }

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

    /// @notice Thrown when caller lacks required permissions
    error Unauthorized();
    /// @notice Thrown when initialization is attempted twice
    error AlreadyInitialized();

    /// @notice Emitted when a new name is registered
    event Registered(string label, address owner);
    /// @notice Emitted when a text record is changed
    event TextChanged(bytes32 indexed labelhash, string key, string value);
    /// @notice Emitted when an address record is changed
    event AddrChanged(bytes32 indexed labelhash, uint256 coinType, bytes value);
    /// @notice Emitted when a content hash is changed
    event ContenthashChanged(bytes32 indexed labelhash, bytes value);

    /// @notice Structure for text record updates
    /// @dev Used to prevent stack too deep errors in multicall functions
    struct Text {
        string key;
        string value;
    }

    /// @notice Structure for address record updates
    /// @dev Used to prevent stack too deep errors in multicall functions
    struct Addr {
        uint256 coinType;
        bytes value;
    }

    /*
     * Access Control Roles
     */
    /// @notice Role identifier for administrative operations
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    /// @notice Role identifier for registrar operations
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    /*
     * Constants
     */
    /// @notice Ethereum coin type as per SLIP-0044
    uint256 constant COIN_TYPE_ETH = 60;

    /*
     * Properties
     */
    /// @notice Total number of registered names
    uint256 public totalSupply;
    /// @notice Base URI for token metadata
    string public baseUri;
    ///  @notice Store name and symbol as public variables
    string private _name;
    string private _symbol;
    /// @notice Mapping of text records for each name
    mapping(bytes32 labelhash => mapping(string key => string)) _texts;
    /// @notice Mapping of address records for each name
    mapping(bytes32 labelhash => mapping(uint256 coinType => bytes)) _addrs;
    /// @notice Mapping of content hashes for each name
    mapping(bytes32 labelhash => bytes) _chashes;
    /// @notice Mapping of labels (names) for each labelhash
    mapping(bytes32 labelhash => string) _labels;

    // Initialize with placeholder values that will be updated in initialize()
    constructor() ERC721("", "") {
        _disableInitializers();
    }

    /// @notice Initializes the registry with name, symbol, and base URI
    /// @param tokenName The name for the ERC721 token
    /// @param tokenSymbol The symbol for the ERC721 token
    /// @param _baseUri The base URI for token metadata
    function initialize(
        string calldata tokenName,
        string calldata tokenSymbol,
        string calldata _baseUri,
        address admin
    ) external initializer {
        // Store the name and symbol in our public variables
        _name = tokenName;
        _symbol = tokenSymbol;
        baseUri = _baseUri;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    // Override name() and symbol() from ERC721
    // function name() public view override returns (string memory) {
    //     return _name;
    // }

    // function symbol() public view override returns (string memory) {
    //     return _symbol;
    // }

    /// @notice Returns the base URI for token metadata
    /// @return string The base URI
    // function _baseURI() internal view override returns (string memory) {
    //     return baseUri;
    // }

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
        _labels[labelhash] = label;
        totalSupply++;
        emit Registered(label, owner);
    }

    /*
     * Resolution Functions
     */
    /// @notice Gets the Ethereum address for a name
    /// @param labelhash The hash of the name to resolve
    /// @return address The Ethereum address
    function addr(bytes32 labelhash) public view returns (address) {
        return address(uint160(bytes20(addr(labelhash, COIN_TYPE_ETH))));
    }

    /// @notice Gets the address for a specific coin type
    /// @param labelhash The hash of the name to resolve
    /// @param cointype The coin type to fetch the address for
    /// @return bytes The address for the specified coin
    function addr(
        bytes32 labelhash,
        uint256 cointype
    ) public view returns (bytes memory) {
        return _addrs[labelhash][cointype];
    }

    /// @notice Gets a text record
    /// @param labelhash The hash of the name
    /// @param key The key of the text record
    /// @return string The value of the text record
    function text(
        bytes32 labelhash,
        string calldata key
    ) external view returns (string memory) {
        return _texts[labelhash][key];
    }

    /// @notice Gets the content hash
    /// @param labelhash The hash of the name
    /// @return bytes The content hash
    function contenthash(
        bytes32 labelhash
    ) external view returns (bytes memory) {
        return _chashes[labelhash];
    }

    /// @notice Gets the label (name) for a labelhash
    /// @param labelhash The hash to lookup
    /// @return string The original label
    function labelFor(bytes32 labelhash) external view returns (string memory) {
        return _labels[labelhash];
    }

    /*
     * Record Management Functions
     */
    /// @notice Sets the base URI for token metadata
    /// @param _baseUri The new base URI
    /// @dev Only callable by admin role
    // function setBaseURI(string memory _baseUri) external onlyRole(ADMIN_ROLE) {
    //     baseUri = _baseUri;
    // }

    /// @notice Internal function to set address records
    /// @param labelhash The name's hash
    /// @param coinType The coin type to set address for
    /// @param value The address value
    function _setAddr(
        bytes32 labelhash,
        uint256 coinType,
        bytes memory value
    ) internal {
        _addrs[labelhash][coinType] = value;
        emit AddrChanged(labelhash, coinType, value);
    }

    /// @notice Internal function to set text records
    /// @param labelhash The name's hash
    /// @param key The record key
    /// @param value The record value
    function _setText(
        bytes32 labelhash,
        string memory key,
        string memory value
    ) internal {
        _texts[labelhash][key] = value;
        emit TextChanged(labelhash, key, value);
    }

    /// @notice Internal function to set content hash
    /// @param labelhash The name's hash
    /// @param value The content hash value
    function _setContenthash(bytes32 labelhash, bytes memory value) internal {
        _chashes[labelhash] = value;
        emit ContenthashChanged(labelhash, value);
    }

    /// @notice Public function to set address records with access control
    /// @param labelhash The name's hash
    /// @param coinType The coin type to set address for
    /// @param value The address value
    function setAddr(
        bytes32 labelhash,
        uint256 coinType,
        bytes memory value
    ) public onlyTokenOperatorOrRegistrar(labelhash) {
        _setAddr(labelhash, coinType, value);
    }

    /// @notice Public function to set text records with access control
    /// @param labelhash The name's hash
    /// @param key The record key
    /// @param value The record value
    function setText(
        bytes32 labelhash,
        string memory key,
        string memory value
    ) public onlyTokenOperatorOrRegistrar(labelhash) {
        _setText(labelhash, key, value);
    }

    /// @notice Public function to set content hash with access control
    /// @param labelhash The name's hash
    /// @param value The content hash value
    function setContenthash(
        bytes32 labelhash,
        bytes memory value
    ) public onlyTokenOperatorOrRegistrar(labelhash) {
        _setContenthash(labelhash, value);
    }

    /// @notice Batch sets multiple records in one transaction
    /// @param labelhash The name's hash
    /// @param texts Array of text records to set
    /// @param addrs Array of address records to set
    /// @param chash Content hash to set (optional)
    function setRecords(
        bytes32 labelhash,
        Text[] calldata texts,
        Addr[] calldata addrs,
        bytes calldata chash
    ) external onlyTokenOperatorOrRegistrar(labelhash) {
        uint256 i;

        for (i = 0; i < texts.length; i++) {
            _setText(labelhash, texts[i].key, texts[i].value);
        }

        for (i = 0; i < addrs.length; i++) {
            _setAddr(labelhash, addrs[i].coinType, addrs[i].value);
        }

        if (chash.length > 0) {
            _setContenthash(labelhash, chash);
        }
    }

    function _deriveNode(string calldata name) internal pure returns (bytes32) {
        bytes memory dnsEncodedName = ENSDNSUtils.dnsEncode(name);
        bytes32 node = BytesUtils.namehash(dnsEncodedName, 0);
        return node;
    }
}
