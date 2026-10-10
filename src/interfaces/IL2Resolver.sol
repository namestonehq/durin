//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ***********************************************
// ▗▖  ▗▖ ▗▄▖ ▗▖  ▗▖▗▄▄▄▖ ▗▄▄▖▗▄▄▄▖▗▄▖ ▗▖  ▗▖▗▄▄▄▖
// ▐▛▚▖▐▌▐▌ ▐▌▐▛▚▞▜▌▐▌   ▐▌     █ ▐▌ ▐▌▐▛▚▖▐▌▐▌
// ▐▌ ▝▜▌▐▛▀▜▌▐▌  ▐▌▐▛▀▀▘ ▝▀▚▖  █ ▐▌ ▐▌▐▌ ▝▜▌▐▛▀▀▘
// ▐▌  ▐▌▐▌ ▐▌▐▌  ▐▌▐▙▄▄▖▗▄▄▞▘  █ ▝▚▄▞▘▐▌  ▐▌▐▙▄▄▖
// ***********************************************

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IMulticallable } from "@ensdomains/ens-contracts/resolvers/IMulticallable.sol";
import { IABIResolver } from "@ensdomains/ens-contracts/resolvers/profiles/IABIResolver.sol";
import { IAddressResolver } from "@ensdomains/ens-contracts/resolvers/profiles/IAddressResolver.sol";
import { IAddrResolver } from "@ensdomains/ens-contracts/resolvers/profiles/IAddrResolver.sol";
import { IContentHashResolver } from "@ensdomains/ens-contracts/resolvers/profiles/IContentHashResolver.sol";
import { ITextResolver } from "@ensdomains/ens-contracts/resolvers/profiles/ITextResolver.sol";
import { IExtendedResolver } from "@ensdomains/ens-contracts/resolvers/profiles/IExtendedResolver.sol";

/// @author NameStone
interface IL2Resolver is
    IERC165,
    IMulticallable,
    IABIResolver,
    IAddressResolver,
    IAddrResolver,
    IContentHashResolver,
    ITextResolver,
    IExtendedResolver
{
    error Unauthorized(bytes32 node);

    function setABI(
        bytes32 node,
        uint256 contentType,
        bytes calldata data
    ) external;

    function setAddr(
        bytes32 node,
        address addr
    ) external;

    function setAddr(
        bytes32 node,
        uint256 coinType,
        bytes calldata a
    ) external;

    function setContenthash(
        bytes32 node,
        bytes calldata hash
    ) external;

    function setText(
        bytes32 node,
        string calldata key,
        string calldata value
    ) external;
}
