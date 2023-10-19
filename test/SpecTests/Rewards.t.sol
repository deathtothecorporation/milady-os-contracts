// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "../MiladyOSTestBase.sol";
import "../Harnesses.t.sol";

contract RewardsTests is MiladyOSTestBase {
    event RewardsAccrued(uint indexed _accessoryId, uint _value);
    event MiladyDeregisteredForRewards(uint indexed _miladyId, uint indexed _accessoryId);
    event RewardsClaimed(uint indexed _miladyId, uint indexed _accessoryId, address indexed _recipient);

    function test_R_AR_1(uint _accessoryId) public {
        // conditions:
        // * no ether is included in the transaction

        // expect the function to revert with the specified message
        vm.expectRevert("No ether included");

        // act
        // try to add rewards for the accessory without sending ether
        rewardsContract.addRewardsForAccessory{value : 0 ether}(_accessoryId);
    }

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

    function test_R_RMFRFA_1(address _sender, uint _accessoryId, uint _miladyId) public {
        // conditions:
        // * msg.sender is not avatarContractAddress

        // impersonate the _sender account for this test
        vm.prank(_sender);

        // expect the function to revert with the specified message
        vm.expectRevert("Not avatarContractAddress");

        // act
        // try to register the milady for rewards for the accessory
        rewardsContract.registerMiladyForRewardsForAccessory(_miladyId, _accessoryId);
    }

    function test_R_DMFRFAAC_1(address _sender, uint _accessoryId, uint _miladyId, address payable _recipient) public {
        // conditions:
        // * msg.sender is not avatarContractAddress

        // impersonate the _sender account for this test
        vm.prank(_sender);

        // expect the function to revert with the specified message
        vm.expectRevert("Not avatarContractAddress");

        // act
        // try to deregister the milady for rewards for the accessory and claim
        rewardsContract.deregisterMiladyForRewardsForAccessoryAndClaim(_miladyId, _accessoryId, _recipient);
    }

    function test_R_DMFRFAAC_4(uint _miladyId, uint _seed) public {
        //public { 
        // conditions: 
        // * msg.sender is avatarContractAddress
        // * the milady is registered for rewards for the accessory
        // * _recipient is payable

        // setup:
        // * register the milady for rewards for the accessory (mint and equip it)
        // * add rewards for the accessory

        // (uint _accessoryId, uint _miladyId, address payable _recipient) =
        //     (random(abi.encodePacked(uint(0))),
        //     1,
        //     payable(randomAddress(abi.encodePacked(uint(2)))));

        // arrange
        vm.assume(_miladyId <= NUM_MILADYS_MINTED);
        uint accessoryId = random(abi.encodePacked(_seed));
        address payable recipient = payable(randomAddress(abi.encodePacked(_seed)));
        vm.prank(avatarContract.ownerOf(_miladyId));
        vm.deal(address(this), 1e18 * 1000);
        createBuyAndEquipAccessory(_miladyId,  accessoryId, 0.001 ether);
        rewardsContract.addRewardsForAccessory{value : 0.1 ether}(accessoryId);

        uint[] memory accessoryIds = new uint[](1);
        accessoryIds[0] = accessoryId;

        // act 
        // deregister the milady for rewards for the accessory and claim
        (uint rewardsPerWearerAccruedBefore, uint totalWearersBefore) = rewardsContract.rewardInfoForAccessory(accessoryId);
        require(totalWearersBefore > 0, "totalWearersBefore <= 0");
        console.log("totalWearersBefore: %d", totalWearersBefore);
        require(rewardsPerWearerAccruedBefore > 0, "rewardsPerWearerAccruedBefore <= 0");
        uint recipientBalanceBefore = recipient.balance;
        require(recipientBalanceBefore == 0, "recipientBalanceBefore != 0");

        vm.prank(address(avatarContract));
        vm.expectEmit(address(rewardsContract));
        emit RewardsClaimed(_miladyId, accessoryId, recipient);
        vm.expectEmit(address(rewardsContract));
        emit MiladyDeregisteredForRewards(_miladyId, accessoryId);
        rewardsContract.deregisterMiladyForRewardsForAccessoryAndClaim(_miladyId, accessoryId, recipient);

        // assert
        (uint rewardsPerWearerAccruedAfter,uint totalWearersAfter) = rewardsContract.rewardInfoForAccessory(accessoryId);
        (bool isRegisteredAfter, uint amountClaimedAfter) = rewardsContract.getMiladyRewardInfoForAccessory(_miladyId, accessoryId);
        uint recipientBalanceAfter = recipient.balance;
 
        console.log("totalWearersAfter: %d", totalWearersAfter);
        require(totalWearersAfter == totalWearersBefore - 1, "totalWearersAfter != totalWearersBefore - 1");
        require(rewardsPerWearerAccruedAfter == rewardsPerWearerAccruedBefore, "rewardsPerWearerAccruedAfter != rewardsPerWearerAccruedBefore");
        require(isRegisteredAfter == false, "isRegisteredAfter != false");
        require(amountClaimedAfter == rewardsPerWearerAccruedBefore, "amountClaimedAfter != rewardsPerWearerAccruedBefore");
        require(recipientBalanceAfter == recipientBalanceBefore + rewardsPerWearerAccruedBefore, "recipientBalanceAfter != recipientBalanceBefore + rewardsPerWearerAccruedBefore");
    }
}