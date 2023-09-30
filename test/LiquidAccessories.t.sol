// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Rewards.sol";
import "../src/MiladyAvatar.sol";
import "./MiladyOSTestBase.sol";

contract LiquidAccessoriesTests is MiladyOSTestBase {
    function test_autoUnequip() public {
        uint redHatAccessoryId = avatarContract.plaintextAccessoryTextToAccessoryId("hat", "red hat");
        uint greenHatAccessoryId = avatarContract.plaintextAccessoryTextToAccessoryId("hat", "green hat");
        uint blueHatAccessoryId = avatarContract.plaintextAccessoryTextToAccessoryId("hat", "blue hat");

        vm.startPrank(liquidAccessoriesContract.owner());
        liquidAccessoriesContract.defineBondingCurveParameter(redHatAccessoryId, 0.001 ether);
        liquidAccessoriesContract.defineBondingCurveParameter(greenHatAccessoryId, 0.001 ether);
        liquidAccessoriesContract.defineBondingCurveParameter(blueHatAccessoryId, 0.001 ether);
        vm.stopPrank();

        uint[] memory accessoriesToMint = new uint[](3);
        accessoriesToMint[0] = redHatAccessoryId;
        accessoriesToMint[1] = greenHatAccessoryId;
        accessoriesToMint[2] = blueHatAccessoryId;
        uint[] memory amounts = new uint[](3);
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;

        // should cost (0.005 + 0)*1.2 = 0.006 ETH per first item for each set, so 0.018 ETH
        address payable overpayAddress = payable(address(uint160(10)));
        liquidAccessoriesContract.mintAccessories{value:0.018 ether}(accessoriesToMint, amounts, address(this), overpayAddress);
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
        (uint128 hatType, ) = avatarContract.accessoryIdToTypeAndVariantIds(redHatAccessoryId);

        uint[] memory listOfJustRedHatId = new uint[](1);
        listOfJustRedHatId[0] = redHatAccessoryId;
        avatarContract.updateEquipSlotsByAccessoryIds(0, listOfJustRedHatId);
        require(avatarContract.equipSlots(0, hatType) == redHatAccessoryId);
        (, uint totalHoldersForRedHatRewards) = rewardsContract.rewardInfoForAccessory(redHatAccessoryId);
        require(totalHoldersForRedHatRewards == 1);

        uint[] memory listOfJustBlueHatId = new uint[](1);
        listOfJustBlueHatId[0] = blueHatAccessoryId;
        avatarContract.updateEquipSlotsByAccessoryIds(0, listOfJustBlueHatId);
        require(avatarContract.equipSlots(0, hatType) == blueHatAccessoryId);
        (, totalHoldersForRedHatRewards) = rewardsContract.rewardInfoForAccessory(redHatAccessoryId);
        require(totalHoldersForRedHatRewards == 0);
    }
    function test_autoUnequipBatch() public {
        uint redHatAccessoryId = avatarContract.plaintextAccessoryTextToAccessoryId("hat", "red hat");
        uint greenHatAccessoryId = avatarContract.plaintextAccessoryTextToAccessoryId("hat", "green hat");
        uint blueHatAccessoryId = avatarContract.plaintextAccessoryTextToAccessoryId("hat", "blue hat");

        vm.startPrank(liquidAccessoriesContract.owner());
        liquidAccessoriesContract.defineBondingCurveParameter(redHatAccessoryId, 0.001 ether);
        liquidAccessoriesContract.defineBondingCurveParameter(greenHatAccessoryId, 0.001 ether);
        liquidAccessoriesContract.defineBondingCurveParameter(blueHatAccessoryId, 0.001 ether);
        vm.stopPrank();

        uint[] memory accessoriesToMint = new uint[](3);
        accessoriesToMint[0] = redHatAccessoryId;
        accessoriesToMint[1] = greenHatAccessoryId;
        accessoriesToMint[2] = blueHatAccessoryId;
        uint[] memory amounts = new uint[](3);
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;

        // should cost (0.005 + 0)*1.2 = 0.006 ETH per first item for each set, so 0.0165 ETH
        address payable overpayAddress = payable(address(uint160(10)));
        liquidAccessoriesContract.mintAccessories{value:0.018 ether}(accessoriesToMint, amounts, address(this), overpayAddress);
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
        (uint128 hatType, ) = avatarContract.accessoryIdToTypeAndVariantIds(redHatAccessoryId);

        avatarContract.updateEquipSlotsByAccessoryIds(0, accessoriesToMint);
        require(avatarContract.equipSlots(0, hatType) == blueHatAccessoryId);
        (, uint totalHoldersForRedHatRewards) = rewardsContract.rewardInfoForAccessory(redHatAccessoryId);
        require(totalHoldersForRedHatRewards == 0);
        (, uint totalHoldersForBlueHatRewards) = rewardsContract.rewardInfoForAccessory(blueHatAccessoryId);
        require(totalHoldersForBlueHatRewards == 1);
    }
    function test_revenueFlow() public {
        require(liquidAccessoriesContract.getBurnRewardForItemNumber(0, 0.001 ether) == 0.005 ether);
        require(liquidAccessoriesContract.getMintCostForItemNumber(0, 0.001 ether) == 0.006 ether);
        require(liquidAccessoriesContract.getBurnRewardForItemNumber(1, 0.001 ether) == 0.006 ether);
        require(liquidAccessoriesContract.getMintCostForItemNumber(1, 0.001 ether) == 0.0072 ether);

        uint redHatAccessoryId = avatarContract.plaintextAccessoryTextToAccessoryId("hat", "red hat");
        uint blueHatAccessoryId = avatarContract.plaintextAccessoryTextToAccessoryId("hat", "blue hat");

        vm.startPrank(liquidAccessoriesContract.owner());
        liquidAccessoriesContract.defineBondingCurveParameter(redHatAccessoryId, 0.001 ether);
        liquidAccessoriesContract.defineBondingCurveParameter(blueHatAccessoryId, 0.001 ether);
        vm.stopPrank();

        vm.expectRevert("Insufficient accessory supply");
        liquidAccessoriesContract.getBurnRewardForReturnedAccessories(redHatAccessoryId, 1);
        require(liquidAccessoriesContract.getMintCostForNewAccessories(redHatAccessoryId, 1) == 0.006 ether);

        uint[] memory listOfBlueHatAccessoryId = new uint[](1);
        listOfBlueHatAccessoryId[0] = blueHatAccessoryId;
        uint[] memory amounts = new uint[](1);
        amounts[0] = 1;

        // Mint the first accessory
        address payable overpayAddress = payable(address(uint160(10)));
        liquidAccessoriesContract.mintAccessories{value:0.006 ether}(listOfBlueHatAccessoryId, amounts, address(this), overpayAddress);
        require(overpayAddress.balance == 0);

        // because no one has equipped this yet, all of the revenue should have gone to PROJECT_REVENUE_RECIPIENT
        uint expectedRevenue = 0.001 ether;
        require(PROJECT_REVENUE_RECIPIENT.balance == expectedRevenue);

        TokenGatedAccount milady0TGA = testUtils.getTGA(miladysContract, 0);
        TokenGatedAccount avatar0TGA = testUtils.getTGA(avatarContract, 0);

        // let's now equip it on an Avatar and try again
        liquidAccessoriesContract.safeTransferFrom(address(this), address(avatar0TGA), blueHatAccessoryId, 1, "");
        milady0TGA.execute(address(avatarContract), 0, abi.encodeCall(avatarContract.updateEquipSlotsByAccessoryIds, (0, listOfBlueHatAccessoryId) ), 0);

        // clear out PROJECT_REVENUE_RECIPIENT to make logic below simpler
        vm.prank(PROJECT_REVENUE_RECIPIENT);
        payable(address(0x0)).transfer(PROJECT_REVENUE_RECIPIENT.balance);

        // mint an additional blue hat.
        // this should cost 0.0072 eth, so let's include 0.0073 eth and verify the overpay address got back 0.0001 eth
        liquidAccessoriesContract.mintAccessories{value:0.0073 ether}(listOfBlueHatAccessoryId, amounts, address(this), overpayAddress);
        require(overpayAddress.balance == 0.0001 ether);

        expectedRevenue = 0.0012 ether;
        require(PROJECT_REVENUE_RECIPIENT.balance == expectedRevenue / 2);
        require(address(rewardsContract).balance == expectedRevenue - (expectedRevenue / 2));

        // send the item away and make sure unequip and deregister happens
        require(liquidAccessoriesContract.balanceOf(address(avatar0TGA), blueHatAccessoryId) == 1);
        (,uint totalHolders) = rewardsContract.rewardInfoForAccessory(blueHatAccessoryId);
        require(totalHolders == 1);

        bytes memory transferCall = abi.encodeCall(liquidAccessoriesContract.safeTransferFrom, (address(avatar0TGA), address(0x1), blueHatAccessoryId, 1, ""));
        bytes memory avatarExecuteCall = abi.encodeCall(avatar0TGA.execute, (address(liquidAccessoriesContract), 0, transferCall, 0));
        milady0TGA.execute(address(avatar0TGA), 0, avatarExecuteCall, 0);

        require(liquidAccessoriesContract.balanceOf(address(avatar0TGA), blueHatAccessoryId) == 0);
        (, totalHolders) = rewardsContract.rewardInfoForAccessory(blueHatAccessoryId);
        require(totalHolders == 0);
        require(payable(address(rewardsContract)).balance == 0);

        // we can also verify the rewards were distributed upon the auto-unequip
        // The mint during equip should have had a freeRevenue of (0.0072 - 0.006) = 0.0012.
        // Half of this (0.0006) should have been sent to the rewards contract, then distributed to the Milady
        // Thus the avatar's TBA should have a balance of 0.0006 ETH
        require(payable(address(avatar0TGA)).balance == 0.0006 ether);

        // test solvency by burning the two accessories we minted
        // we should have one in the 0x1 address and one in address(this)
        uint[] memory singletonListOf1 = new uint[](1);
        singletonListOf1[0] = 1;
        liquidAccessoriesContract.burnAccessories(listOfBlueHatAccessoryId, singletonListOf1, 0, payable(address(0x3)));
        vm.prank(address(0x1));
        liquidAccessoriesContract.burnAccessories(listOfBlueHatAccessoryId, singletonListOf1, 0, payable(address(0x3)));

        // the funds recipient (0x3) should have gotten the burnReward, 0.005 + 0.006 ETH
        require(payable(address(0x3)).balance == 0.011 ether);

        // there should be 0 remaining ether in the liquidAccessories contract
        require(payable(address(liquidAccessoriesContract)).balance == 0);
    }
}