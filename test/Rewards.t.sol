// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "openzeppelin/token/ERC1155/IERC1155Receiver.sol";
import "../src/Rewards.sol";
import "../src/Deployer.sol";
import "../src/AccessoryUtils.sol";
import "./TestConstants.sol";
import "./Miladys.sol";
import "./TestSetup.t.sol";

contract RewardsTest is Test {
    Rewards rewardsContract;
    Miladys miladyContract;
    SoulboundAccessories soulboundAccessoriesContract;
    Onboarding onboardingContract;

    function setUp() external {
        (
            ,//TBARegistry tbaRegistry,
            ,//TokenBasedAccount tbaAccountImpl,
            miladyContract,
            ,//MiladyAvatar miladyAvatarContract,
            ,//LiquidAccessories liquidAccessoriesContract,
            soulboundAccessoriesContract,
            rewardsContract,
            onboardingContract
        )
         =
        TestSetup.deploy(NUM_MILADYS_MINTED, MILADY_AUTHORITY_ADDRESS);
    }

    function test_basicRewards() external {
        // prepare milady with its soulbound accessories
        AccessoryUtils.PlaintextAccessoryInfo[] memory milady0AccessoriesPlaintext = new AccessoryUtils.PlaintextAccessoryInfo[](3);
        milady0AccessoriesPlaintext[0] = AccessoryUtils.PlaintextAccessoryInfo("hat", "red hat");
        milady0AccessoriesPlaintext[1] = AccessoryUtils.PlaintextAccessoryInfo("earring", "strawberry");
        milady0AccessoriesPlaintext[2] = AccessoryUtils.PlaintextAccessoryInfo("shirt", "gucci");
        
        uint[] memory milady0Accessories = AccessoryUtils.batchPlaintextAccessoryInfoToAccessoryIds(milady0AccessoriesPlaintext);
        vm.prank(MILADY_AUTHORITY_ADDRESS);
        
        onboardingContract.onboardMilady(0, milady0Accessories);

        // deposit rewards for some items the Milady has
        rewardsContract.accrueRewardsForAccessory{value:100}(milady0Accessories[0]);
        rewardsContract.accrueRewardsForAccessory{value:101}(milady0Accessories[1]);

        // deposit a reward for an item the Milady does not have
        rewardsContract.accrueRewardsForAccessory{value:99}(
            AccessoryUtils.plaintextAccessoryTextToId("hat", "awful hat that no one has")
        );

        require(rewardsContract.getAmountClaimableForMiladyAndAccessories(0, milady0Accessories) == 201);

        uint balancePreClaim = address(this).balance;
        rewardsContract.claimRewardsForMilady(0, milady0Accessories, payable(address(this)));
        uint balancePostClaim = address(this).balance;
        require(balancePostClaim - balancePreClaim == 201);
        require(rewardsContract.getAmountClaimableForMiladyAndAccessories(0, milady0Accessories) == 0);

        // now onboard another Milady and make sure rewards work as expected
        // new milady only shares accessory id 0 with previous milady
        AccessoryUtils.PlaintextAccessoryInfo[] memory milady1AccessoriesPlaintext = new AccessoryUtils.PlaintextAccessoryInfo[](3);
        milady1AccessoriesPlaintext[0] = AccessoryUtils.PlaintextAccessoryInfo("hat", "red hat");
        milady1AccessoriesPlaintext[1] = AccessoryUtils.PlaintextAccessoryInfo("earring", "peach");
        milady1AccessoriesPlaintext[2] = AccessoryUtils.PlaintextAccessoryInfo("shirt", "wife beater");
        
        uint[] memory milady1Accessories = AccessoryUtils.batchPlaintextAccessoryInfoToAccessoryIds(milady1AccessoriesPlaintext);
        vm.prank(MILADY_AUTHORITY_ADDRESS);
        
        onboardingContract.onboardMilady(1, milady1Accessories);

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

    // define functions to allow receiving ether and NFTs

    receive() external payable {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }
}