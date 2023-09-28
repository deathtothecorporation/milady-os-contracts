// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "openzeppelin/token/ERC1155/IERC1155Receiver.sol";
import "../src/Rewards.sol";
import "../src/Deployer.sol";
import "./MiladyOSTestBase.sol";
import "./Miladys.sol";

contract RewardsTest is MiladyOSTestBase {
    function test_basicRewards() external {
        // prepare milady with its soulbound accessories
        MiladyAvatar.PlaintextAccessoryInfo[] memory milady0AccessoriesPlaintext = new MiladyAvatar.PlaintextAccessoryInfo[](3);
        milady0AccessoriesPlaintext[0] = MiladyAvatar.PlaintextAccessoryInfo("hat", "red hat");
        milady0AccessoriesPlaintext[1] = MiladyAvatar.PlaintextAccessoryInfo("earring", "strawberry");
        milady0AccessoriesPlaintext[2] = MiladyAvatar.PlaintextAccessoryInfo("shirt", "gucci");
        
        uint[] memory milady0Accessories = avatarContract.batchPlaintextAccessoryInfoToAccessoryIds(milady0AccessoriesPlaintext);
        vm.prank(MILADY_AUTHORITY_ADDRESS);
        
        soulboundAccessoriesContract.mintAndEquipSoulboundAccessories(0, milady0Accessories);

        // deposit rewards for some items the Milady has
        rewardsContract.accrueRewardsForAccessory{value:100}(milady0Accessories[0]);
        rewardsContract.accrueRewardsForAccessory{value:101}(milady0Accessories[1]);

        // depositing a reward for an item the Milady does not have should revert,
        // as no one will receive the rewards
        uint idForAccessoryNooneHas = avatarContract.plaintextAccessoryTextToAccessoryId("hat", "awful hat that no one has");
        vm.expectRevert("That accessory has no eligible recipients");
        rewardsContract.accrueRewardsForAccessory{value:99}(idForAccessoryNooneHas);

        require(rewardsContract.getAmountClaimableForMiladyAndAccessories(0, milady0Accessories) == 201);

        uint balancePreClaim = address(this).balance;
        rewardsContract.claimRewardsForMilady(0, milady0Accessories, payable(address(this)));
        uint balancePostClaim = address(this).balance;
        require(balancePostClaim - balancePreClaim == 201);
        require(rewardsContract.getAmountClaimableForMiladyAndAccessories(0, milady0Accessories) == 0);

        // now onboard another Milady and make sure rewards work as expected
        // new milady only shares accessory id 0 with previous milady
        MiladyAvatar.PlaintextAccessoryInfo[] memory milady1AccessoriesPlaintext = new MiladyAvatar.PlaintextAccessoryInfo[](3);
        milady1AccessoriesPlaintext[0] = MiladyAvatar.PlaintextAccessoryInfo("hat", "red hat");
        milady1AccessoriesPlaintext[1] = MiladyAvatar.PlaintextAccessoryInfo("earring", "peach");
        milady1AccessoriesPlaintext[2] = MiladyAvatar.PlaintextAccessoryInfo("shirt", "wife beater");
        
        uint[] memory milady1Accessories = avatarContract.batchPlaintextAccessoryInfoToAccessoryIds(milady1AccessoriesPlaintext);
        vm.prank(MILADY_AUTHORITY_ADDRESS);
        
        soulboundAccessoriesContract.mintAndEquipSoulboundAccessories(1, milady1Accessories);

        // deposit a reward for:
        // * shared accessory
        rewardsContract.accrueRewardsForAccessory{value:100}(milady0Accessories[0]);
        // * accessory only held by milady 0
        rewardsContract.accrueRewardsForAccessory{value:101}(milady0Accessories[1]);
        // * accessory only held by milady 1
        rewardsContract.accrueRewardsForAccessory{value:103}(milady1Accessories[1]);

        uint expectedRewardsForMilady0 = 50 + 101; // half of first reward, all of second
        uint expectedRewardsForMilady1 = 50 + 103; // half of first reward, all of third

        // test read functions
        require(rewardsContract.getAmountClaimableForMiladyAndAccessories(0, milady0Accessories) == expectedRewardsForMilady0);
        require(rewardsContract.getAmountClaimableForMiladyAndAccessories(1, milady1Accessories) == expectedRewardsForMilady1);

        // test actual claims
        balancePreClaim = address(this).balance;
        rewardsContract.claimRewardsForMilady(0, milady0Accessories, payable(address(this)));
        balancePostClaim = address(this).balance;
        require(balancePostClaim - balancePreClaim == expectedRewardsForMilady0);

        balancePreClaim = address(this).balance;
        rewardsContract.claimRewardsForMilady(1, milady1Accessories, payable(address(this)));
        balancePostClaim = address(this).balance;
        require(balancePostClaim - balancePreClaim == expectedRewardsForMilady1);
    }
}