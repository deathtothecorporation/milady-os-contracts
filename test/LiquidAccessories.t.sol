// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/AccessoryUtils.sol";
import "./TestSetup.sol";
import "./TestUtils.sol";
import "./TestConstants.sol";

contract LiquidAccessoriesTests is Test {
    TestUtils testUtils;
    LiquidAccessories liquidAccessoriesContract;
    
    function setUp() public {
        (
            ,//TBARegistry tbaRegistry,
            ,//TokenGatedAccount tbaAccountImpl,
            ,//Miladys _miladysContract,
            ,//MiladyAvatar miladyAvatarContract,
            LiquidAccessories _liquidAccessoriesContract,
            ,//soulboundAccessoriesContract,
            ,//rewardsContract
            TestUtils _testUtils
        )
         =
        TestSetup.deploy(NUM_MILADYS_MINTED, MILADY_AUTHORITY_ADDRESS);

        testUtils = _testUtils;
        liquidAccessoriesContract = _liquidAccessoriesContract;
    }

    function test_revenueFlow() public {
        require(liquidAccessoriesContract.getBurnRewardForItemNumber(0) == 0.001 ether);
        require(liquidAccessoriesContract.getMintCostForItemNumber(0) == 0.0011 ether);
        vm.expectRevert();
        liquidAccessoriesContract.getBurnRewardForReturnedAccessories(0, 1);
        require(liquidAccessoriesContract.getMintCostForNewAccessories(0, 1) == 0.0011 ether);

        uint[] memory accessoriesToMint = new uint[](1);
        accessoriesToMint[0] = AccessoryUtils.plaintextAccessoryTextToId("hat", "blue hat");
        uint[] memory amounts = new uint[](1);
        amounts[0] = 1;

        // Mint the first accessory
        // this should cost 0.0011 eth
        address payable overpayAddress = payable(address(uint160(10)));
        liquidAccessoriesContract.mintAccessories{value:0.0011 ether}(accessoriesToMint, amounts, overpayAddress);
        require(overpayAddress.balance == 0);
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