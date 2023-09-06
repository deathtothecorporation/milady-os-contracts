// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

abstract contract IMiladyAvatar {
    function unequipAccessoryIfEquipped(uint miladyId, uint accessoryId) external virtual;
}