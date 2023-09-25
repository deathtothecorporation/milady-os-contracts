// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/AccessoryUtils.sol";
import "./MiladyOSTestBase.sol";

contract LiquidAccessoriesTests is MiladyOSTestBase {
    function test_minting() public {
        uint[] memory accessoryIds = new uint[](3);
        accessoryIds[0] = AccessoryUtils.plaintextAccessoryTextToId("hat", "blue hat");
        accessoryIds[1] = AccessoryUtils.plaintextAccessoryTextToId("earring", "strawberry");
        accessoryIds[2] = AccessoryUtils.plaintextAccessoryTextToId("necklace", "green");
        
        vm.expectRevert("Not miladyAuthority");
        soulboundAccessoriesContract.mintAndEquipSoulboundAccessories(0, accessoryIds);

        TokenGatedAccount avatar0TGA = testUtils.getTGA(avatarContract, 0);

        vm.startPrank(MILADY_AUTHORITY_ADDRESS);
        soulboundAccessoriesContract.mintAndEquipSoulboundAccessories(0, accessoryIds);

        require(soulboundAccessoriesContract.balanceOf(address(avatar0TGA), accessoryIds[0]) == 1);

        (uint128 hatAccessoryType,) = AccessoryUtils.idToTypeAndVariantHashes(accessoryIds[0]);
        uint equippedAccessoryId = avatarContract.equipSlots(0, hatAccessoryType);
        require(equippedAccessoryId == accessoryIds[0]);

        vm.expectRevert("Avatar already activated");
        soulboundAccessoriesContract.mintAndEquipSoulboundAccessories(0, accessoryIds);

        vm.stopPrank();

        vm.startPrank(address(avatar0TGA));
        vm.expectRevert("Cannot transfer soulbound tokens");
        soulboundAccessoriesContract.safeTransferFrom(address(avatar0TGA), address(0x1), accessoryIds[0], 1, "");
        vm.stopPrank();
    }
}