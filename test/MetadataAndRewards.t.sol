// // SPDX-License-Identifier: UNLICENSED

// /* solhint-disable private-vars-leading-underscore */

// pragma solidity ^0.8.13;

// import "forge-std/Test.sol";
// import "forge-std/console.sol";
// import "./TestConstants.sol";
// import "../src/MetadataAndRewards.sol";
// import "../src/Miladys.sol";

// contract MetadataAndRewardsTest is Test {
//     MiladyAccessoriesAndRewards accessoriesAndRewardsContract;
//     Miladys miladyContract;
//     // MockOffchainMetadataSource mockMetdataSource;

//     function setUp() external {
//         miladyContract = new Miladys();
//         miladyContract.flipSaleState();

//         // mint miladys to msg.sender for testing
//         miladyContract.mintMiladys{value:60000000000000000*NUM_MILADYS_MINTED}(NUM_MILADYS_MINTED);

//         // console.log(miladyAuthorityAddress);
//         accessoriesAndRewardsContract = new MiladyAccessoriesAndRewards(miladyContract, miladyAuthorityAddress);

//         // mockMetdataSource = new MockOffchainMetadataSource();
//     }

//     function test_basicRewards() external {
//         // onboard a milady
//         uint16[NUM_ACCESSORY_TYPES] memory metadata0 = [uint16(0), 1, 2, 3];
//         vm.prank(miladyAuthorityAddress);
//         accessoriesAndRewardsContract.onboardMilady(0, metadata0);

//         // deposit rewards for some items the Milady has
//         accessoriesAndRewardsContract.receiveRewardsForAccessory{value:100}(0);
//         accessoriesAndRewardsContract.receiveRewardsForAccessory{value:101}(1);

//         // deposit a reward for an item the Milady does not have
//         accessoriesAndRewardsContract.receiveRewardsForAccessory{value:103}(99);

//         require(accessoriesAndRewardsContract.getAmountClaimableForMilady(0) == 201);
//         uint balancePreClaim = address(this).balance;
//         accessoriesAndRewardsContract.claimRewardsForMilady(0);
//         uint balancePostClaim = address(this).balance;
//         require(balancePostClaim - balancePreClaim == 201);
//         require(accessoriesAndRewardsContract.getAmountClaimableForMilady(0) == 0);

//         // now onboard another Milady and make sure rewards work as expected
//         // new milady only shares accessory id 0 with previous milady
//         uint16[NUM_ACCESSORY_TYPES] memory metadata1 = [uint16(0), 4, 5, 6];
//         vm.prank(miladyAuthorityAddress);
//         accessoriesAndRewardsContract.onboardMilady(1, metadata1);

//         // deposit a reward for:
//         // * shared accessory
//         accessoriesAndRewardsContract.receiveRewardsForAccessory{value:100}(0);
//         // * accessory only held by milady 0
//         accessoriesAndRewardsContract.receiveRewardsForAccessory{value:101}(1);
//         // * accessory only held by milady 1
//         accessoriesAndRewardsContract.receiveRewardsForAccessory{value:103}(4);

//         uint expectedRewardsForMilady0 = 50 + 101; // half of first reward, all of second
//         uint expectedRewardsForMilady1 = 50 + 103; // half of first reward, all of third

//         // test read functions
//         require(accessoriesAndRewardsContract.getAmountClaimableForMilady(0) == expectedRewardsForMilady0);
//         require(accessoriesAndRewardsContract.getAmountClaimableForMilady(1) == expectedRewardsForMilady1);

//         // test actual claims
//         balancePreClaim = address(this).balance;
//         accessoriesAndRewardsContract.claimRewardsForMilady(0);
//         balancePostClaim = address(this).balance;
//         require(balancePostClaim - balancePreClaim == expectedRewardsForMilady0);

//         balancePreClaim = address(this).balance;
//         accessoriesAndRewardsContract.claimRewardsForMilady(1);
//         balancePostClaim = address(this).balance;
//         require(balancePostClaim - balancePreClaim == expectedRewardsForMilady1);

//         // just for kicks let's do one more onboarding and claim
//         uint16[NUM_ACCESSORY_TYPES] memory metadata2 = [uint16(0), 4, 5, 6];
//         vm.prank(miladyAuthorityAddress);
//         accessoriesAndRewardsContract.onboardMilady(2, metadata2);
        
//         // deposit more rewards for accessory id 0
//         accessoriesAndRewardsContract.receiveRewardsForAccessory{value:99}(0);

//         require(accessoriesAndRewardsContract.getAmountClaimableForMilady(2) == 33);
//         balancePreClaim = address(this).balance;
//         accessoriesAndRewardsContract.claimRewardsForMilady(2);
//         balancePostClaim = address(this).balance;
//         require(balancePostClaim - balancePreClaim == 33);
//     }

//     // define functions to allow receiving ether and NFTs

//     receive() external payable {}

//     function onERC721Received(
//         address,
//         address,
//         uint256,
//         bytes calldata
//     ) external pure returns (bytes4) {
//         return IERC721Receiver.onERC721Received.selector;
//     }
// }

// // contract MockOffchainMetadataSource {
// //     function get(uint miladyID)
// //         pure
// //         public
// //         returns (uint16[NUM_ACCESSORY_TYPES] memory accessories)
// //     {
// //         if (miladyID == 0) {
// //             return [uint16(0), 1, 2, 3];
// //         }
// //         else {
// //             revert("no mock metadata for that milady ID yet!");
// //         }
// //     }
// // }