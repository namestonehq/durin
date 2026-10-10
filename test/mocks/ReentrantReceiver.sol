// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import { IL2Registry } from "../../src/interfaces/IL2Registry.sol";

/// @dev Creates a subnode under the token it receives from within `onERC721Received()`
contract ReentrantReceiver is IERC721Receiver {
    IL2Registry public immutable registry;
    bool private _entered;

    constructor(
        address _registry
    ) {
        registry = IL2Registry(_registry);
    }

    function onERC721Received(
        address,
        address,
        uint256 tokenId,
        bytes calldata
    ) external returns (bytes4) {
        if (!_entered) {
            _entered = true;
            registry.createSubnode(bytes32(tokenId), "child", address(this), new bytes[](0));
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}
