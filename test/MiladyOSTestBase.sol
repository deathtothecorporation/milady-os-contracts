// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./TestSetup.sol";
import "./TestUtils.sol";
import "./TestConstants.sol";

contract MiladyOSTestBase is Test {
    TBARegistry tbaRegistry;
    // TokenGatedAccount tbaAccountImpl;
    Miladys miladysContract;
    MiladyAvatar avatarContract;
    LiquidAccessories liquidAccessoriesContract;
    SoulboundAccessories soulboundAccessoriesContract;
    Rewards rewardsContract;
    TestUtils testUtils;
    
    function setUp() public {
        (
            tbaRegistry,
            ,// tbaAccountImpl,
            miladysContract,
            avatarContract,
            liquidAccessoriesContract,
            soulboundAccessoriesContract,
            rewardsContract,
            testUtils
        )
         =
        TestSetup.deploy(NUM_MILADYS_MINTED, MILADY_AUTHORITY_ADDRESS);

        vm.createFork(vm.envString("RPC_MAINNET"), 18200000);
        miladysContract = Miladys(0x5Af0D9827E0c53E4799BB226655A1de152A425a5);
        console.log(vm.envString("RPC_MAINNET"));
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