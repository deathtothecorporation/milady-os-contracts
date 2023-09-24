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
    function test_revenueFlow() public {
        require(liquidAccessoriesContract.getBurnRewardForItemNumber(0) == 0.001 ether);
        require(liquidAccessoriesContract.getMintCostForItemNumber(0) == 0.0011 ether);
        vm.expectRevert();
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
        liquidAccessoriesContract.mintAccessories{value:0.0011 ether}(listOfBlueHatAccessoryId, amounts, overpayAddress);
        require(overpayAddress.balance == 0);

        // because no one has equipped this yet, all of the revenue should have gone to PROJECT_REVENUE_RECIPIENT
        uint expectedRevenue = 0.0001 ether;
        require(PROJECT_REVENUE_RECIPIENT.balance == expectedRevenue);

        TokenGatedAccount milady0TGA = testUtils.getTGA(miladysContract, 0);
        TokenGatedAccount avatar0TGA = testUtils.getTGA(miladyAvatarContract, 0);

        // let's now equip it on an Avatar and try again
        liquidAccessoriesContract.safeTransferFrom(address(this), address(avatar0TGA), blueHatAccessoryId, 1, "");
        milady0TGA.executeCall(address(miladyAvatarContract), 0, abi.encodeCall(miladyAvatarContract.updateEquipSlotsByAccessoryIds, (0, listOfBlueHatAccessoryId) ));

        // clear out PROJECT_REVENUE_RECIPIENT to make logic below simpler
        vm.prank(PROJECT_REVENUE_RECIPIENT);
        payable(address(0x0)).transfer(PROJECT_REVENUE_RECIPIENT.balance);

        // mint an additional blue hat.
        // this should cost 0.0022 eth, so let's include 0.0023 eth and verify the overpay address got back 0.0001 eth
        liquidAccessoriesContract.mintAccessories{value:0.0023 ether}(listOfBlueHatAccessoryId, amounts, overpayAddress);
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
    }
}