/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity 0.8.18;

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
        rewardsContract.addRewardsForAccessory{value:100}(milady0Accessories[0]);
        rewardsContract.addRewardsForAccessory{value:101}(milady0Accessories[1]);

        // depositing a reward for an item the Milady does not have should revert,
        // as no one will receive the rewards
        uint idForAccessoryNooneHas = avatarContract.plaintextAccessoryTextToAccessoryId("hat", "awful hat that no one has");
        vm.expectRevert("No eligible recipients");
        rewardsContract.addRewardsForAccessory{value:99}(idForAccessoryNooneHas);

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
        rewardsContract.addRewardsForAccessory{value:100}(milady0Accessories[0]);
        // * accessory only held by milady 0
        rewardsContract.addRewardsForAccessory{value:101}(milady0Accessories[1]);
        // * accessory only held by milady 1
        rewardsContract.addRewardsForAccessory{value:103}(milady1Accessories[1]);

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

    function test_rewardsWithExiting() external {
        // prepare milady with its soulbound accessories
        MiladyAvatar.PlaintextAccessoryInfo[] memory milady0AccessoriesPlaintext = new MiladyAvatar.PlaintextAccessoryInfo[](3);
        milady0AccessoriesPlaintext[0] = MiladyAvatar.PlaintextAccessoryInfo("hat", "red hat");
        uint[] memory milady0Accessories = avatarContract.batchPlaintextAccessoryInfoToAccessoryIds(milady0AccessoriesPlaintext);
        vm.startPrank(MILADY_AUTHORITY_ADDRESS);
        soulboundAccessoriesContract.mintAndEquipSoulboundAccessories(0, milady0Accessories);
        soulboundAccessoriesContract.mintAndEquipSoulboundAccessories(1, milady0Accessories);
        vm.stopPrank();

        // deposit rewards for hat accessory
        rewardsContract.addRewardsForAccessory{value:20}(milady0Accessories[0]);
        require(rewardsContract.getAmountClaimableForMiladyAndAccessories(0, milady0Accessories) == 10);

        vm.startPrank(address(avatarContract));
        rewardsContract.deregisterMiladyForRewardsForAccessoryAndClaim(1, milady0Accessories[0], payable(address(this)));
        rewardsContract.deregisterMiladyForRewardsForAccessoryAndClaim(0, milady0Accessories[0], payable(address(this)));
        vm.stopPrank();
    }
    function test_auditRewardIssuePoc() external {
        // minimally modified code from audit POC of VAP-1
        
        // prepare milady with its soulbound accessories
        MiladyAvatar.PlaintextAccessoryInfo[] memory milady0AccessoriesPlaintext = new MiladyAvatar.PlaintextAccessoryInfo[](3);
        milady0AccessoriesPlaintext[0] = MiladyAvatar.PlaintextAccessoryInfo("hat", "red hat");
        uint[] memory milady0Accessories = avatarContract.batchPlaintextAccessoryInfoToAccessoryIds(milady0AccessoriesPlaintext);
        vm.prank(MILADY_AUTHORITY_ADDRESS);
        // User A mints accessory
        soulboundAccessoriesContract.mintAndEquipSoulboundAccessories(0, milady0Accessories);

        // deposit rewards for hat accessory
        rewardsContract.addRewardsForAccessory{value:20}(milady0Accessories[0]);
        require(rewardsContract.getAmountClaimableForMiladyAndAccessories(0, milady0Accessories) == 20);//Uses B and C mint accessories

        uint[] memory milady1Accessories = avatarContract.batchPlaintextAccessoryInfoToAccessoryIds(milady0AccessoriesPlaintext);
        vm.prank(MILADY_AUTHORITY_ADDRESS);
        soulboundAccessoriesContract.mintAndEquipSoulboundAccessories(1, milady1Accessories);
        uint[] memory milady2Accessories = avatarContract.batchPlaintextAccessoryInfoToAccessoryIds(milady0AccessoriesPlaintext);
        vm.prank(MILADY_AUTHORITY_ADDRESS);
        soulboundAccessoriesContract.mintAndEquipSoulboundAccessories(2, milady2Accessories);

        // deposit rewards for hat accessory
        rewardsContract.addRewardsForAccessory{value:30}(milady0Accessories[0]);
        require(rewardsContract.getAmountClaimableForMiladyAndAccessories(1, milady0Accessories) == 10);

        // User B and C unequip their accessories
        uint balancePreClaim = address(this).balance;
        vm.prank(address(avatarContract));
        rewardsContract.deregisterMiladyForRewardsForAccessoryAndClaim(1, milady0Accessories[0], payable(address(this)));
        vm.prank(address(avatarContract));
        rewardsContract.deregisterMiladyForRewardsForAccessoryAndClaim(2, milady0Accessories[0], payable(address(this)));
        uint balancePostClaim = address(this).balance;
        require(balancePostClaim - balancePreClaim == 20);
        // deposit rewards for hat accessory
        rewardsContract.addRewardsForAccessory{value:10}(milady0Accessories[0]);
        // User A tries to unequip their item and fails
        vm.prank(address(avatarContract));
        rewardsContract.deregisterMiladyForRewardsForAccessoryAndClaim(0, milady0Accessories[0], payable(address(this)));

        require(payable(address(rewardsContract)).balance == 0);
    }
}