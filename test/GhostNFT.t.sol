// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./TestConstants.sol";
import "./TestSetup.sol";
import "./TestUtils.sol";
import "./Miladys.sol";
import "../src/MiladyAvatar.sol";
import "../src/TGA/TBARegistry.sol";

contract GhostNFT is Test {
    TBARegistry public tbaRegistry;
    TokenGatedAccount public tbaAcctImpl;

    Miladys miladyContract;
    MiladyAvatar miladyAvatarContract;

    TestUtils testUtils;

    function setUp() external {
        (
            ,//TBARegistry tbaRegistry,
            ,//TokenGatedAccount tbaAccountImpl,
            miladyContract,
            miladyAvatarContract,
            ,//LiquidAccessories liquidAccessoriesContract,
            ,//soulboundAccessoriesContract,
            ,//rewardsContract,
            testUtils
        )
         =
        TestSetup.deploy(NUM_MILADYS_MINTED, MILADY_AUTHORITY_ADDRESS);
    }

    function test_ownershipTracks() public {
        assert(miladyAvatarContract.ownerOf(0) == testUtils.getTGA(miladyContract, 0));

        miladyContract.transferFrom(address(this), address(0x2), 0);

        assert(miladyAvatarContract.ownerOf(0) == testUtils.getTGA(miladyContract, 0));
    }

    function test_balanceOfForTGAIs1(uint miladyId) public {
        vm.assume(miladyId <= 9999);

        require(miladyAvatarContract.balanceOf(testUtils.getTGA(miladyContract, 0)) == 1);
    }

    function test_balanceOfRandomAcccountIs0(address randomAccount) public {
        // make sure this random address is not 0x0 or a TBA
        vm.assume(randomAccount != address(uint160(0)));
        (address tbaTokenContractAddr, ) = testUtils.tgaReverseLookup(randomAccount);
        vm.assume(tbaTokenContractAddr == address(0x0));

        require(miladyAvatarContract.balanceOf(randomAccount) == 0);
    }

    function test_idValidity(uint id) public {
        if (id <= 9999) {
            miladyAvatarContract.ownerOf(id);
        }
        else {
            vm.expectRevert("Invalid Milady/Avatar id");
            miladyAvatarContract.ownerOf(id);
        }
    }

    /*
    more tests:
    * test all transfer-related functions fail
    * test negative cases (owner for an Id with no milady?)
    */

    receive() external payable {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}