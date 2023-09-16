// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

library AccessoryUtils {
    // an ID's upper 128 bits are the truncated hash of the category text;
    // the lower 128 bits are the truncated hash of the variant test

    struct PlaintextAccessoryInfo {
        string accType;
        string accVariant;
    }

    function batchPlaintextAccessoryInfoToAccessoryIds(PlaintextAccessoryInfo[] memory accInfos)
        public
        pure
        returns (uint[] memory accIds)
    {
        accIds = new uint[](accInfos.length);
        for (uint i=0; i<accInfos.length; i++)
        {
            accIds[i] = plaintextAccessoryInfoToId(accInfos[i]);
        }
    }

    function plaintextAccessoryInfoToId(PlaintextAccessoryInfo memory accInfo)
        public
        pure
        returns (uint accessoryId)
    {
        uint128 accType = uint128(uint256(keccak256(abi.encodePacked(accInfo.accType))));
        uint128 accVariant = uint128(uint256(keccak256(abi.encodePacked(accInfo.accVariant))));
        accessoryId = typeAndVariantHashesToId(accType, accVariant);
    }

    function plaintextAccessoryTextToId(string memory accTypeString, string memory accVariantString)
        public
        pure
        returns (uint accessoryId)
    {
        return plaintextAccessoryInfoToId(PlaintextAccessoryInfo(accTypeString, accVariantString));
    }

    function idToTypeAndVariantHashes(uint id)
        public
        pure
        returns (uint128 accType, uint128 accVariant)
    {
        return (uint128(id >> 128), uint128(id));
    }

    function typeAndVariantHashesToId(uint128 accType, uint128 accVariant)
        public
        pure
        returns (uint)
    {
        return (uint(accType) << 128) | uint(accVariant);
    }
}