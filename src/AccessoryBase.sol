// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC1155/ERC1155.sol";

contract AccessoryBase is ERC1155 {
    constructor(string memory uri_)
        ERC1155(uri_)
    {}

    // an ID's upper 128 bits are the truncated hash of the category text;
    // the lower 128 bits are the truncated hash of the variant test

    function idToTypeAndVariant(uint id)
        public
        pure
        returns (uint128 accType, uint128 accVariant)
    {
        return (uint128(id >> 128), uint128(id));
    }

    function typeAndVariantToId(uint128 accType, uint128 accVariant)
        public
        pure
        returns (uint)
    {
        return (uint(accType) << 128) | uint(accVariant);
    }
}