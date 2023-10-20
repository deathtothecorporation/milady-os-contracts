// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "../MiladyOSTestBase.sol";

contract LiquidAccessoriesTests is MiladyOSTestBase {
    function test_LA_SAC_3() public
    {
        // Conditions: 
        // 1. caller is the deployer
        // 2. avatar contract is not set

        vm.prank(address(0x1234));
        LiquidAccessories liquidAccessoriesContract = new LiquidAccessories(
            tbaRegistry,
            rewardsContract,
            PROJECT_REVENUE_RECIPIENT,
            "https://n.a/"
        );

        vm.prank(address(0x1234));
        liquidAccessoriesContract.setAvatarContract(avatarContract);

        require(address(liquidAccessoriesContract.avatarContract()) == address(avatarContract), "Avatar contract not set");
    }

    function test_LA_MA_4 //() public 
        (uint _accessoryTypesToMint, uint _seed, address _recipient, address payable _overpayAddress) public
    { 
        // Conditions:
        // 1. the two input arrays are the same length
        // 2. msg.value == total minting cost exactly
        // 3. all mintAndDisburdeRevnue calls succeed
        // 4. all accessories have a bonding curve parameter set

        vm.assume(_accessoryTypesToMint > 0);
        vm.assume(_accessoryTypesToMint < 10);
        vm.assume(_seed < 2**255);

        // (uint _accessoryTypesToMint, uint _seed, address _recipient, address payable _overpayAddress) =
        //     (1000, 115792089237316195423570985008687907853269984665640564039457584007913129639934, address(0x1234), payable(address(0x1235)));

        uint[] memory accessoryIds = new uint[](_accessoryTypesToMint);
        uint[] memory amounts = new uint[](_accessoryTypesToMint);
        uint totalMintCost = 0;
        for (uint i = 0; i < _accessoryTypesToMint; i++) {
            accessoryIds[i] = random(_seed + i);
            amounts[i] = random(_seed + i + 1) % 10 + 1;
            uint curveParam = (random(_seed + i + 2) % 10 + 1) * 0.001 ether;

            vm.prank(address(liquidAccessoriesContract.owner()));
            liquidAccessoriesContract.defineBondingCurveParameter(accessoryIds[i], curveParam);
            console.log("curveParam: %d", curveParam);
            uint mintCost = liquidAccessoriesContract.getMintCostForNewAccessories(accessoryIds[i], amounts[i]);
            console.log("mintCost: %d", mintCost);
            totalMintCost += mintCost;
            console.log("totalMintCost: %d", totalMintCost);
        }

        liquidAccessoriesContract.mintAccessories{ value : totalMintCost }(
            accessoryIds,
            amounts,
            _recipient,
            _overpayAddress
        );

        for (uint i = 0; i < _accessoryTypesToMint; i++) {
            require(liquidAccessoriesContract.balanceOf(_recipient, accessoryIds[i]) == amounts[i], "Incorrect balance");
        }
    }

    function test_LA_MA_8(uint _accessoryTypesToMint, uint _seed, address _recipient, address payable _overpayAddress) public
    { 
        // Conditions:
        // 1. the two input arrays are the same length
        // 2. msg.value > total minting cost exactly
        // 3. all mintAndDisburdeRevenue calls succeeds
        // 4. all accessories have a bonding curve parameter set

        vm.assume(_accessoryTypesToMint > 0);
        vm.assume(_accessoryTypesToMint < 10);
        vm.assume(_seed < 2**255);
        
        uint[] memory accessoryIds = new uint[](_accessoryTypesToMint);
        uint[] memory amounts = new uint[](_accessoryTypesToMint);
        uint totalMintCost = 0;
        for (uint i = 0; i < _accessoryTypesToMint; i++) {
            accessoryIds[i] = random(_seed + i);
            amounts[i] = random(_seed + i + 1) % 10 + 1;
            uint curveParam = (random(_seed + i + 2) % 10 + 1) * 0.001 ether;

            vm.prank(address(liquidAccessoriesContract.owner()));
            liquidAccessoriesContract.defineBondingCurveParameter(accessoryIds[i], curveParam);
            totalMintCost += liquidAccessoriesContract.getMintCostForNewAccessories(accessoryIds[i], amounts[i]);
        }

        uint overpayAmount = totalMintCost + random(abi.encodePacked(_seed + 100)) % 10**18;
        uint overpayAddressBalanceBefore = _overpayAddress.balance;

        vm.deal(address(this), totalMintCost + overpayAmount);
        liquidAccessoriesContract.mintAccessories{ value : totalMintCost + overpayAmount }(
            accessoryIds,
            amounts,
            _recipient,
            _overpayAddress
        );

        uint overpayAddressBalanceAfter = _overpayAddress.balance;
        require(overpayAddressBalanceAfter - overpayAddressBalanceBefore == overpayAmount, "Incorrect overpay amount");

        for (uint i = 0; i < _accessoryTypesToMint; i++) {
            require(liquidAccessoriesContract.balanceOf(_recipient, accessoryIds[i]) == amounts[i], "Incorrect balance");
        }
    }
}