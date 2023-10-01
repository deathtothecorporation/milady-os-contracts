// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../MiladyOSTestBase.sol";
import "../Harnesses.t.sol";

contract RewardsTests is MiladyOSTestBase {
    event RewardsAccrued(uint indexed _accessoryId, uint _value);

    function test_R_AR_2(uint _accessoryId) public
    {
        // conditions:
        // * there is a reward to add
        // * there is no one to receive the reward

        vm.deal(address(this), 1e18 * 1000);
        vm.expectRevert("No eligible recipients");
        rewardsContract.addRewardsForAccessory{value : 0.1 ether}(_accessoryId);
    }

    function test_R_AR_3(uint _miladyId, uint _seed, uint _amount) public
    {
        // conditions:
        // * there is a reward to add
        // * there is someone to receive the reward

        // setup:
        // * buy a liquid accessory for the milady
        // * equip the accessory
        // * add rewards for the accessory

        // arrange
        vm.assume(_miladyId <= NUM_MILADYS_MINTED);
        vm.assume(_amount > 0);
        uint accessoryId = random(abi.encodePacked(_seed));
        createAndBuyAccessory(_miladyId, accessoryId, 0.001 ether);

        uint[] memory accessoryIds = new uint[](1);
        accessoryIds[0] = accessoryId; 
        vm.prank(avatarContract.ownerOf(_miladyId));
        avatarContract.updateEquipSlotsByAccessoryIds(_miladyId, accessoryIds);

        (uint totalRewardsAccruedBefore,) = rewardsContract.rewardInfoForAccessory(accessoryId);

        vm.deal(address(this), 1e18 * 1000);
        uint value = _amount % (1e18 * 1000);
        vm.expectEmit(address(rewardsContract));
        emit RewardsAccrued(accessoryId, value);

        // act
        rewardsContract.addRewardsForAccessory{value : value}(accessoryId);

        // assert
        (uint totalRewardsAccruedAfter,) = rewardsContract.rewardInfoForAccessory(accessoryId);
        require(
            totalRewardsAccruedAfter == totalRewardsAccruedBefore + value, 
            "totalRewardsAccruedAfter != totalRewardsAccruedBefore + value");
    }
}