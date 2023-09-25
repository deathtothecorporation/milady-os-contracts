// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/AccessoryUtils.sol";
import "../src/Rewards.sol";
import "../src/MiladyAvatar.sol";
import "./MiladyOSTestBase.sol";

contract LiquidAccessoriesTests is MiladyOSTestBase {
    function test_autoUnequip() public {
        uint redHatAccessoryId = AccessoryUtils.plaintextAccessoryTextToId("hat", "red hat");
        uint greenHatAccessoryId = AccessoryUtils.plaintextAccessoryTextToId("hat", "green hat");
        uint blueHatAccessoryId = AccessoryUtils.plaintextAccessoryTextToId("hat", "blue hat");

        uint[] memory accessoriesToMint = new uint[](3);
        accessoriesToMint[0] = redHatAccessoryId;
        accessoriesToMint[1] = greenHatAccessoryId;
        accessoriesToMint[2] = blueHatAccessoryId;
        uint[] memory amounts = new uint[](3);
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;

        // should cost 0.0011 ETH per first item for each set, so 0.0033 ETH
        address payable overpayAddress = payable(address(uint160(10)));
        liquidAccessoriesContract.mintAccessories{value:0.0033 ether}(accessoriesToMint, amounts, address(this), overpayAddress);
        require(overpayAddress.balance == 0);

        require(liquidAccessoriesContract.balanceOf(address(this), redHatAccessoryId) == 1);
        require(liquidAccessoriesContract.balanceOf(address(this), greenHatAccessoryId) == 1);
        require(liquidAccessoriesContract.balanceOf(address(this), blueHatAccessoryId) == 1);

        // transfer the accessories to the avatarTGA
        TokenGatedAccount avatar0TGA = testUtils.getTGA(avatarContract, 0);
        liquidAccessoriesContract.safeTransferFrom(address(this), address(avatar0TGA), redHatAccessoryId, 1, "");
        liquidAccessoriesContract.safeTransferFrom(address(this), address(avatar0TGA), greenHatAccessoryId, 1, "");
        liquidAccessoriesContract.safeTransferFrom(address(this), address(avatar0TGA), blueHatAccessoryId, 1, "");

        // now equip one, then another, and make sure the auto unequip works
        vm.startPrank(address(testUtils.getTGA(miladysContract, 0)));
        (uint128 hatType, ) = AccessoryUtils.idToTypeAndVariantHashes(redHatAccessoryId);

        uint[] memory listOfJustRedHatId = new uint[](1);
        listOfJustRedHatId[0] = redHatAccessoryId;
        avatarContract.equipAccessories(0, listOfJustRedHatId);
        require(avatarContract.equipSlots(0, hatType) == redHatAccessoryId);
        (, uint totalHoldersForRedHatRewards) = rewardsContract.rewardInfoForAccessory(redHatAccessoryId);
        require(totalHoldersForRedHatRewards == 1);

        uint[] memory listOfJustBlueHatId = new uint[](1);
        listOfJustBlueHatId[0] = blueHatAccessoryId;
        avatarContract.equipAccessories(0, listOfJustBlueHatId);
        require(avatarContract.equipSlots(0, hatType) == blueHatAccessoryId);
        (, totalHoldersForRedHatRewards) = rewardsContract.rewardInfoForAccessory(redHatAccessoryId);
        require(totalHoldersForRedHatRewards == 0);
    }
    function test_autoUnequipBatch() public {
        uint redHatAccessoryId = AccessoryUtils.plaintextAccessoryTextToId("hat", "red hat");
        uint greenHatAccessoryId = AccessoryUtils.plaintextAccessoryTextToId("hat", "green hat");
        uint blueHatAccessoryId = AccessoryUtils.plaintextAccessoryTextToId("hat", "blue hat");

        uint[] memory accessoriesToMint = new uint[](3);
        accessoriesToMint[0] = redHatAccessoryId;
        accessoriesToMint[1] = greenHatAccessoryId;
        accessoriesToMint[2] = blueHatAccessoryId;
        uint[] memory amounts = new uint[](3);
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;

        // should cost 0.0011 ETH per first item for each set, so 0.0033 ETH
        address payable overpayAddress = payable(address(uint160(10)));
        liquidAccessoriesContract.mintAccessories{value:0.0033 ether}(accessoriesToMint, amounts, address(this), overpayAddress);
        require(overpayAddress.balance == 0);

        require(liquidAccessoriesContract.balanceOf(address(this), redHatAccessoryId) == 1);
        require(liquidAccessoriesContract.balanceOf(address(this), greenHatAccessoryId) == 1);
        require(liquidAccessoriesContract.balanceOf(address(this), blueHatAccessoryId) == 1);

        // transfer the accessories to the avatarTGA
        TokenGatedAccount avatar0TGA = testUtils.getTGA(avatarContract, 0);
        liquidAccessoriesContract.safeTransferFrom(address(this), address(avatar0TGA), redHatAccessoryId, 1, "");
        liquidAccessoriesContract.safeTransferFrom(address(this), address(avatar0TGA), greenHatAccessoryId, 1, "");
        liquidAccessoriesContract.safeTransferFrom(address(this), address(avatar0TGA), blueHatAccessoryId, 1, "");

        // equip all 3 in a batch, and make sure only the last one sticks
        vm.startPrank(address(testUtils.getTGA(miladysContract, 0)));
        (uint128 hatType, ) = AccessoryUtils.idToTypeAndVariantHashes(redHatAccessoryId);

        avatarContract.equipAccessories(0, accessoriesToMint);
        require(avatarContract.equipSlots(0, hatType) == blueHatAccessoryId);
        (, uint totalHoldersForRedHatRewards) = rewardsContract.rewardInfoForAccessory(redHatAccessoryId);
        require(totalHoldersForRedHatRewards == 0);
        (, uint totalHoldersForBlueHatRewards) = rewardsContract.rewardInfoForAccessory(blueHatAccessoryId);
        require(totalHoldersForBlueHatRewards == 1);
    }
    function test_revenueFlow() public {
        require(liquidAccessoriesContract.getBurnRewardForItemNumber(0) == 0.001 ether);
        require(liquidAccessoriesContract.getMintCostForItemNumber(0) == 0.0011 ether);
        vm.expectRevert("Not enough supply of that accessory");
        liquidAccessoriesContract.getBurnRewardForReturnedAccessories(0, 1);
        require(liquidAccessoriesContract.getMintCostForNewAccessories(0, 1) == 0.0011 ether);

        uint blueHatAccessoryId = AccessoryUtils.plaintextAccessoryTextToId("hat", "blue hat");

        uint[] memory listOfBlueHatAccessoryId = new uint[](1);
        listOfBlueHatAccessoryId[0] = blueHatAccessoryId;
        uint[] memory amounts = new uint[](1);
        amounts[0] = 1;

        // Mint the first accessory
        // this should cost 0.0011 eth
        address payable overpayAddress = payable(address(uint160(10)));
        liquidAccessoriesContract.mintAccessories{value:0.0011 ether}(listOfBlueHatAccessoryId, amounts, address(this), overpayAddress);
        require(overpayAddress.balance == 0);

        // because no one has equipped this yet, all of the revenue should have gone to PROJECT_REVENUE_RECIPIENT
        uint expectedRevenue = 0.0001 ether;
        require(PROJECT_REVENUE_RECIPIENT.balance == expectedRevenue);

        TokenGatedAccount milady0TGA = testUtils.getTGA(miladysContract, 0);
        TokenGatedAccount avatar0TGA = testUtils.getTGA(avatarContract, 0);

        // let's now equip it on an Avatar and try again
        liquidAccessoriesContract.safeTransferFrom(address(this), address(avatar0TGA), blueHatAccessoryId, 1, "");
        milady0TGA.executeCall(address(avatarContract), 0, abi.encodeCall(avatarContract.equipAccessories, (0, listOfBlueHatAccessoryId) ));

        // clear out PROJECT_REVENUE_RECIPIENT to make logic below simpler
        vm.prank(PROJECT_REVENUE_RECIPIENT);
        payable(address(0x0)).transfer(PROJECT_REVENUE_RECIPIENT.balance);

        // mint an additional blue hat.
        // this should cost 0.0022 eth, so let's include 0.0023 eth and verify the overpay address got back 0.0001 eth
        liquidAccessoriesContract.mintAccessories{value:0.0023 ether}(listOfBlueHatAccessoryId, amounts, address(this), overpayAddress);
        require(overpayAddress.balance == 0.0001 ether);

        expectedRevenue = 0.0002 ether;
        require(PROJECT_REVENUE_RECIPIENT.balance == expectedRevenue / 2);
        require(address(rewardsContract).balance == expectedRevenue - (expectedRevenue / 2));

        // send the item away and make sure unequip and deregister happens
        require(liquidAccessoriesContract.balanceOf(address(avatar0TGA), blueHatAccessoryId) == 1);
        (,uint totalHolders) = rewardsContract.rewardInfoForAccessory(blueHatAccessoryId);
        require(totalHolders == 1);

        bytes memory transferCall = abi.encodeCall(liquidAccessoriesContract.safeTransferFrom, (address(avatar0TGA), address(0x1), blueHatAccessoryId, 1, ""));
        bytes memory avatarExecuteCall = abi.encodeCall(avatar0TGA.executeCall, (address(liquidAccessoriesContract), 0, transferCall));
        milady0TGA.executeCall(address(avatar0TGA), 0, avatarExecuteCall);

        require(liquidAccessoriesContract.balanceOf(address(avatar0TGA), blueHatAccessoryId) == 0);
        (, totalHolders) = rewardsContract.rewardInfoForAccessory(blueHatAccessoryId);
        require(totalHolders == 0);

        // we can also verify the rewards were distributed upon the auto-unequip
        // The mint during equip should have had a freeRevenue of (0.0022 - 0.002) 0.0002.
        // Half of this (0.0001) should have been sent to the rewards contract, then distributed to the Milady
        // Thus the avatar's TBA should have a balance of 0.0001 ETH
        require(payable(address(avatar0TGA)).balance == 0.0001 ether);

        // test solvency by burning the two accessories we minted
        // we should have one in the 0x1 address and one in address(this)
        liquidAccessoriesContract.burnAccessory(blueHatAccessoryId, 1, payable(address(0x3)));
        vm.prank(address(0x1));
        liquidAccessoriesContract.burnAccessory(blueHatAccessoryId, 1, payable(address(0x3)));

        // the funds recipient (0x2) should have gotten the burnReward, 0.001 + 0.002 ETH
        require(payable(address(0x3)).balance == 0.003 ether);

        // there should be 0 remaining ether in the liquidAccessories contract
        require(payable(address(liquidAccessoriesContract)).balance == 0);
    }
}