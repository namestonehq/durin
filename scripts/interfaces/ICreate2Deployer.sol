// SPDX-License-Identifier: MIT
// https://github.com/pcaversaccio/create2deployer
pragma solidity ^0.8.9;

/**
 * @title CREATE2 Deployer Smart Contract
 * @author Pascal Marco Caversaccio, pascal.caversaccio@hotmail.ch
 * @dev Helper smart contract to make easier and safer usage of the
 * `CREATE2` EVM opcode. `CREATE2` can be used to compute in advance
 * the address where a smart contract will be deployed, which allows
 * for interesting new mechanisms known as 'counterfactual interactions'.
 */
interface ICreate2Deployer {
    /**
     * @dev Deploys a contract using `CREATE2`. The address where the
     * contract will be deployed can be known in advance via {computeAddress}.
     *
     * The bytecode for a contract can be obtained from Solidity with
     * `type(contractName).creationCode`.
     *
     * Requirements:
     * - `bytecode` must not be empty.
     * - `salt` must have not been used for `bytecode` already.
     * - the factory must have a balance of at least `value`.
     * - if `value` is non-zero, `bytecode` must have a `payable` constructor.
     */
    function deploy(uint256 value, bytes32 salt, bytes memory code) external;

    /**
     * @dev Returns the address where a contract will be stored if deployed via {deploy}.
     * Any change in the `bytecodeHash` or `salt` will result in a new destination address.
     */
    function computeAddress(
        bytes32 salt,
        bytes32 codeHash
    ) external view returns (address);
}
