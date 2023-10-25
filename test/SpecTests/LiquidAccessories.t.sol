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
            tgaRegistry,
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

    function test_LA_MADR_3 
        // () public { 
        (uint _accessoryId, uint _amount, address _recipient) public {
        // Conditions:
        // 1. the _amount being minted is > 0
        // 2. there are no eligible eligible reward recipeints
        // 3. there is a bonding curve parameter set for the accessory

        // (uint _accessoryId, 
        // uint _amount, 
        // address _recipient) =
        //     (7237005577332262213973186563042994240829374041602535252466099000494570602495, 
        //     2, 
        //     0xf4CF79A8485A8C6A434545F2CF9e24ed5c4Ef002);

        vm.assume(_amount > 0);
        vm.assume(_amount < 100);

        vm.prank(address(liquidAccessoriesContract.owner()));
        liquidAccessoriesContract.defineBondingCurveParameter(_accessoryId, 0.001 ether);

        (uint accessorySupplyBefore,) = liquidAccessoriesContract.bondingCurves(_accessoryId);
        uint revenueRecipientBalanceBefore = address(liquidAccessoriesContract._revenueRecipient()).balance;

        uint mintCost = liquidAccessoriesContract.getMintCostForNewAccessories(_accessoryId, _amount);
        (uint currentAccessorySupply, uint curveParameter) = liquidAccessoriesContract.bondingCurves(_accessoryId);
        uint burnReward = liquidAccessoriesContract.getBurnRewardForReturnedAccessories(
            _amount, 
            currentAccessorySupply + _amount, 
            curveParameter);

        uint rewards = mintCost - burnReward;

        vm.deal(address(this), 10**21);
        liquidAccessoriesContract.mintAccessoryAndDisburseRevenue{ value : mintCost }(
            _accessoryId,
            _amount,
            _recipient);
        
        uint revenueRecipientBalanceAfter = address(liquidAccessoriesContract._revenueRecipient()).balance;

        console.log("revenueRecipientBalanceBefore: %d", revenueRecipientBalanceBefore);
        console.log("rewards: %d", rewards);
        console.log("mintCost: %d", mintCost);
        console.log("burnReward: %d", burnReward);
        console.log("revenueRecipientBalanceAfter: %d", revenueRecipientBalanceAfter);
        console.log("calculated balance: %d", revenueRecipientBalanceBefore + rewards);

        require(revenueRecipientBalanceAfter == revenueRecipientBalanceBefore + rewards, "Incorrect rewards amount");
    }

    // TODO : @Schalk, this is slow at high fuzz rates!
    function test_LA_MADR_4
        // () public { 
        (uint _accessoryId, uint _amount, address _recipient) public {
        // Conditions:
        // 1. the _amount being minted is > 0
        // 2. there are SOME eligible eligible reward recipeints
        // 3. there is a bonding curve parameter set for the accessory

        // (uint _accessoryId, 
        // uint _amount, 
        // address _recipient) =
        //     (0, 
        //     2, 
        //     0x0000000000000000000000000000000000000001);

        vm.assume(_amount > 0);
        vm.assume(_amount < 10);
        vm.assume(_recipient != address(0));
        vm.assume(_accessoryId != 0);

        createBuyAndEquipAccessory(0, _accessoryId, 0.001 ether);
        for (uint i = 1; i < NUM_MILADYS_MINTED; i++)
        {
            buyAndEquipAccessory(i, _accessoryId);
        }

        (uint accessorySupplyBefore,) = liquidAccessoriesContract.bondingCurves(_accessoryId);
        uint revenueRecipientBalanceBefore = address(liquidAccessoriesContract._revenueRecipient()).balance;
        uint rewardsContractBalanceBefore = address(rewardsContract).balance;

        uint mintCost = liquidAccessoriesContract.getMintCostForNewAccessories(_accessoryId, _amount);
        (uint currentAccessorySupply, uint curveParameter) = liquidAccessoriesContract.bondingCurves(_accessoryId);
        uint burnReward = liquidAccessoriesContract.getBurnRewardForReturnedAccessories(
            _amount, 
            currentAccessorySupply + _amount, 
            curveParameter);

        uint rewards = mintCost - burnReward;

        vm.deal(address(this), 10**21);
        liquidAccessoriesContract.mintAccessoryAndDisburseRevenue{ value : mintCost }(
            _accessoryId,
            _amount,
            _recipient);
        
        uint revenueRecipientBalanceAfter = address(liquidAccessoriesContract._revenueRecipient()).balance;
        uint rewardsContractBalanceAfter = address(rewardsContract).balance;

        console.log("revenueRecipientBalanceBefore: %d", revenueRecipientBalanceBefore);
        console.log("rewards: %d", rewards);
        console.log("mintCost: %d", mintCost);
        console.log("burnReward: %d", burnReward);
        console.log("revenueRecipientBalanceAfter: %d", revenueRecipientBalanceAfter);
        console.log("calculated balance: %d", revenueRecipientBalanceBefore + rewards);

        require(revenueRecipientBalanceAfter == revenueRecipientBalanceBefore + (rewards/2), "Incorrect rewards amount");
        require(rewardsContractBalanceAfter == rewardsContractBalanceBefore + (rewards - rewards/2), "Incorrect rewards amount");
    }

    function test_LA_BAS_2 
        // () public
        (uint _accessoryId, uint _amount, address _recipient) public
    {
        // Conditions:
        // 1. there are some legitimate reward recipients
        // 2. the requested _minRewardOut > actual rewards paid

       // (uint _accessoryId, uint _amount, address _recipient) = (random(1234), 1, address(0x1234));

        vm.assume(_accessoryId != 0);
        vm.assume(_amount > 0);
        vm.assume(_amount < 10);
        vm.assume(_recipient != address(0));

        createBuyAndEquipAccessory(0, _accessoryId, 0.001 ether);
        for (uint i = 1; i < NUM_MILADYS_MINTED; i++)
        {
            buyAndEquipAccessory(i, _accessoryId);
        }

        uint mintCost = liquidAccessoriesContract.getMintCostForNewAccessories(_accessoryId, _amount);
        (uint currentAccessorySupply, uint curveParameter) = liquidAccessoriesContract.bondingCurves(_accessoryId);
        uint burnReward = liquidAccessoriesContract.getBurnRewardForReturnedAccessories(
            _amount, 
            currentAccessorySupply + _amount, 
            curveParameter);

        vm.deal(address(this), 10**21);
        liquidAccessoriesContract.mintAccessoryAndDisburseRevenue{ value : mintCost }(
            _accessoryId,
            _amount,
            _recipient);

        uint[] memory accessoryIds = new uint[](1);
        accessoryIds[0] = _accessoryId;
        uint[] memory amounts = new uint[](1);
        amounts[0] = _amount;

        vm.prank(_recipient);
        vm.expectRevert("Specified reward not met");
        liquidAccessoriesContract.burnAccessories(accessoryIds, amounts, burnReward + 1, payable(address(0x1234)));
    }

    function test_LA_BA_1
        // () 
        (uint _miladyId, uint _accessoryId, uint _amount) 
        public
    {
        // Conditions : 
        // 1. the caller holds fewer of the accessoryId than they are trying to burn

        vm.assume(_miladyId < NUM_MILADYS_MINTED);
        vm.assume(_accessoryId != 0);
        vm.assume(_amount > 0);
        vm.assume(_amount < 10);

        for (uint i=0; i < _amount - 1; i++) {
            createAndBuyAccessory(_miladyId, _accessoryId, 0.001 ether);
        }

        vm.prank(address(miladysContract.ownerOf(_miladyId)));
        vm.expectRevert("Incorrect accessory balance");
        liquidAccessoriesContract.burnAccessory(_accessoryId, _amount + 1);
    }

    function test_LA_BTT_2
        // ()
        (uint _miladyId, uint _accessoryTypes, uint _seed, uint _amount) 
        public 
    {
        // Conditions: 
        // 1. The calling contract is the avatarContract

        vm.assume(_miladyId < NUM_MILADYS_MINTED);
        vm.assume(_amount > 0);
        vm.assume(_amount < 10);
        vm.assume(_accessoryTypes > 0);
        vm.assume(_accessoryTypes < 10);
        vm.assume(_seed < 2**255);

        uint[] memory ids = new uint[](_accessoryTypes);
        uint[] memory amounts = new uint[](_accessoryTypes);

        for(uint i = 0; i < _accessoryTypes; i++)
        {
            ids[i] = random(_seed + i);
            amounts[i] = _amount;
            for(uint j = 0; j < _amount; j++)
            {
                createAndBuyAccessory(_miladyId, ids[i], 0.001 ether);
            }
        }

        address from = avatarContract.getAvatarTGA(_miladyId);
        vm.prank(address(avatarContract));
        liquidAccessoriesContract.beforeTokenTransfer(address(0), from, address(1), ids, amounts, "");

        for(uint i = 0; i < _accessoryTypes; i++)
        {
            (uint128 accessoryType,) = avatarContract.accessoryIdToTypeAndVariantIds(ids[i]);
            require(avatarContract.equipSlots(_miladyId, accessoryType) == 0, "Accessory not unequiped");
        }
    }
}
