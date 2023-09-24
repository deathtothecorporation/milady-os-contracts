// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./MiladyOSTestBase.sol";
import "./Miladys.sol";
import "../src/MiladyAvatar.sol";
import "../src/TGA/TBARegistry.sol";

contract GhostNFT is MiladyOSTestBase {

    function test_ownershipTracks() public {
        assert(avatarContract.ownerOf(0) == testUtils.getTgaAddress(miladysContract, 0));

        miladysContract.transferFrom(address(this), address(0x2), 0);

        assert(avatarContract.ownerOf(0) == testUtils.getTgaAddress(miladysContract, 0));
    }

    function test_balanceOfForTGAIs1(uint miladyId) public {
        vm.assume(miladyId <= 9999);

        require(avatarContract.balanceOf(testUtils.getTgaAddress(miladysContract, 0)) == 1);
    }

    function test_balanceOfRandomAcccountIs0(address randomAccount) public {
        // make sure this random address is not 0x0 or a TBA
        vm.assume(randomAccount != address(uint160(0)));
        (address tbaTokenContractAddr, ) = testUtils.tgaReverseLookup(randomAccount);
        vm.assume(tbaTokenContractAddr == address(0x0));

        require(avatarContract.balanceOf(randomAccount) == 0);
    }

    function test_idValidity(uint id) public {
        if (id <= 9999) {
            avatarContract.ownerOf(id);
        }
        else {
            vm.expectRevert("Invalid Milady/Avatar id");
            avatarContract.ownerOf(id);
        }
    }

    /*
    more tests:
    * test all transfer-related functions fail
    * test negative cases (owner for an Id with no milady?)
    */
}