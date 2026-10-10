// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Subset of the ENSv2 UniversalHelper used to look up name ownership.
/// @dev See https://github.com/ensdomains/contracts-v2/blob/main/contracts/src/universalResolver/UniversalHelper.sol
interface IUniversalHelper {
    /// @notice Find the exact owner for `name`.
    /// @param name The DNS-encoded name.
    /// @return The owner address or null if unowned or not found.
    function findExactOwner(
        bytes calldata name
    ) external view returns (address);
}
