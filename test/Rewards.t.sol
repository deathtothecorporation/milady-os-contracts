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

    function setUp() external {
        (
            ,//TBARegistry tbaRegistry,
            ,//TokenBasedAccount tbaAccountImpl,
            miladyContract,
            ,//MiladyAvatar miladyAvatarContract,
            ,//LiquidAccessories liquidAccessoriesContract,
            soulboundAccessoriesContract,
            rewardsContract
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
        
        soulboundAccessoriesContract.mintAndEquipSoulboundAccessories(0, milady0Accessories);

        // deposit rewards for some items the Milady has
        rewardsContract.accrueRewardsForAccessory{value:100}(milady0Accessories[0]);
        rewardsContract.accrueRewardsForAccessory{value:101}(milady0Accessories[1]);

        // deposit a reward for an item the Milady does not have
        rewardsContract.accrueRewardsForAccessory{value:99}(
            AccessoryUtils.plaintextAccessoryTextToId("hat", "awful hat that no one has")
        );

        require(rewardsContract.getAmountClaimableForMiladyAndAccessories(0, milady0Accessories) == 201);





        // uint balancePreClaim = address(this).balance;
        // accessoriesAndRewardsContract.claimRewardsForMilady(0);
        // uint balancePostClaim = address(this).balance;
        // require(balancePostClaim - balancePreClaim == 201);
        // require(accessoriesAndRewardsContract.getAmountClaimableForMilady(0) == 0);

        // // now onboard another Milady and make sure rewards work as expected
        // // new milady only shares accessory id 0 with previous milady
        // uint16[NUM_ACCESSORY_TYPES] memory metadata1 = [uint16(0), 4, 5, 6];
        // vm.prank(miladyAuthorityAddress);
        // accessoriesAndRewardsContract.onboardMilady(1, metadata1);

        // // deposit a reward for:
        // // * shared accessory
        // accessoriesAndRewardsContract.receiveRewardsForAccessory{value:100}(0);
        // // * accessory only held by milady 0
        // accessoriesAndRewardsContract.receiveRewardsForAccessory{value:101}(1);
        // // * accessory only held by milady 1
        // accessoriesAndRewardsContract.receiveRewardsForAccessory{value:103}(4);

        // uint expectedRewardsForMilady0 = 50 + 101; // half of first reward, all of second
        // uint expectedRewardsForMilady1 = 50 + 103; // half of first reward, all of third

        // // test read functions
        // require(accessoriesAndRewardsContract.getAmountClaimableForMilady(0) == expectedRewardsForMilady0);
        // require(accessoriesAndRewardsContract.getAmountClaimableForMilady(1) == expectedRewardsForMilady1);

        // // test actual claims
        // balancePreClaim = address(this).balance;
        // accessoriesAndRewardsContract.claimRewardsForMilady(0);
        // balancePostClaim = address(this).balance;
        // require(balancePostClaim - balancePreClaim == expectedRewardsForMilady0);

        // balancePreClaim = address(this).balance;
        // accessoriesAndRewardsContract.claimRewardsForMilady(1);
        // balancePostClaim = address(this).balance;
        // require(balancePostClaim - balancePreClaim == expectedRewardsForMilady1);

        // // just for kicks let's do one more onboarding and claim
        // uint16[NUM_ACCESSORY_TYPES] memory metadata2 = [uint16(0), 4, 5, 6];
        // vm.prank(miladyAuthorityAddress);
        // accessoriesAndRewardsContract.onboardMilady(2, metadata2);
        
        // // deposit more rewards for accessory id 0
        // accessoriesAndRewardsContract.receiveRewardsForAccessory{value:99}(0);

        // require(accessoriesAndRewardsContract.getAmountClaimableForMilady(2) == 33);
        // balancePreClaim = address(this).balance;
        // accessoriesAndRewardsContract.claimRewardsForMilady(2);
        // balancePostClaim = address(this).balance;
        // require(balancePostClaim - balancePreClaim == 33);
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