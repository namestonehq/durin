// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IL2Registry} from "../../src/interfaces/IL2Registry.sol";

contract MockRegistrar {
    IL2Registry public immutable registry;

    constructor(address _registry) {
        registry = IL2Registry(_registry);
    }

    function register(
        string calldata label,
        address owner
    ) external returns (bytes32 node) {
        return
            registry.createSubnode(
                registry.baseNode(),
                label,
                owner,
                new bytes[](0)
            );
    }

    function registerWithData(
        string calldata label,
        address owner,
        bytes[] memory data
    ) external returns (bytes32 node) {
        return registry.createSubnode(registry.baseNode(), label, owner, data);
    }
}
