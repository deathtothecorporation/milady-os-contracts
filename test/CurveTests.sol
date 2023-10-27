/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./MiladyOSTestBase.sol";
import "./Miladys.sol";
import "../src/MiladyAvatar.sol";
import "TokenGatedAccount/TGARegistry.sol";

contract CurveTests is MiladyOSTestBase 
{
    // Purpose: 
    // 1. To test that the bonding curve is correctly implemented
    // 2. To ensure that the bonding curve acts as expected
    // 3. To gain understanding of potential exploits to the curve

    // Notes :
    // * This should cover both the LiquidAccessory minting and burning calculations
    // * The disbursement of profits to VapourWare
    // * The disbursement of rewards to Miladys with equiped accessories

    // Questions for Logan :
    // * Why is 0.005 ether arbitrary?

    // The aggregate value of the selling curve [_currentSupply - _amount, _currentSupply]
    function getBurnRewardForReturnedAccessories(
            uint _currentSupplyOfAccessory,
            uint _amount,
            uint _curveParameter)
        private
        pure
        returns (uint _totalReward)
    {
        require(_curveParameter != 0, "No bonding curve");
        require(_amount <= _currentSupplyOfAccessory, "Insufficient accessory supply");

        for (uint i=0; i<_amount; i++) {
            _totalReward += getBurnRewardForItemNumber((_currentSupplyOfAccessory - 1) - i, _curveParameter);
        }
    }

    // The aggregate value of the buying curve   [_currentSupply, _currentSupply + _amount]
    function getMintCostForNewAccessories(
            uint _currentSupplyOfAccessory,
            uint _amount, 
            uint _curveParameter)
        public
        pure
        returns (uint _mintCost)
    {
        require(_curveParameter != 0, "Item has no bonding curve");

        for (uint i=0; i<_amount; i++) {
            _mintCost += getMintCostForItemNumber(_currentSupplyOfAccessory + i, _curveParameter);
        }
    }

    // The selling curve
    function getBurnRewardForItemNumber(uint _itemNumber, uint _curveParameter)
        private
        pure
        returns (uint)
    {
        return 0.005 ether + _curveParameter * _itemNumber * _itemNumber;
    }

    // The buying curve
    function getMintCostForItemNumber(uint _itemNumber, uint _curveParameter)
        public
        pure
        returns (uint _mintCost)
    {
        uint percDisbursementVW = 100;      //  10%
        uint percDisbursementMilady = 100;  //  10%
        uint percDisbursementCurve = 1000;  // 100%
        uint percTotal = 
            percDisbursementVW 
            + percDisbursementMilady 
            + percDisbursementCurve;        // 120%

        uint burnReward = getBurnRewardForItemNumber(_itemNumber, _curveParameter);
        _mintCost = burnReward * percTotal / percDisbursementCurve;
    }

    function test_MintCalculations(
            uint _curveParameter,
            uint _existingItems,
            uint _newItems,
            uint _seed)
        public
    {
        // create an _existingItems number of items
        // get the mint price of _newItems number of items
        // check that the cost of minting _newItems is the same as the cost of minting _existingItems + _newItems

        vm.assume(_curveParameter > 0);
        vm.assume(_curveParameter < 10**18);
        vm.assume(_existingItems < 10);
        vm.assume(_newItems >= 0);
        vm.assume(_newItems < 100);

        // init existing items
        uint accessoryId = random(_seed);
        createAccessory(accessoryId, _curveParameter);
        for (uint i=0; i<_existingItems; i++) {
            buyAccessory(0, accessoryId);
        }

        // calculate the cost of minting _newItems
        uint calculatedMintCost = getMintCostForNewAccessories(_existingItems, _newItems, _curveParameter);
        uint actualMintCost = liquidAccessoriesContract.getMintCostForNewAccessories(accessoryId, _newItems);
        require(calculatedMintCost == actualMintCost, "Mint cost mismatch");
    }

    function test_BurnCalculations(
            uint _curveParameter,
            uint _existingItems,
            uint _returnedItems,
            uint _seed)
        public
    {
        // create an _existingItems number of items
        // get the burn price of _returnedItems number of items
        // check that the reward for burning _returnedItems is the same as the reward for burning _existingItems - _returnedItems

        vm.assume(_curveParameter > 0);
        vm.assume(_curveParameter < 10**18);
        vm.assume(_existingItems < 10);
        vm.assume(_returnedItems < 10);
        
        _returnedItems = clamp(_returnedItems, 0, _existingItems);

        // init existing items
        uint accessoryId = random(_seed);
        createAccessory(accessoryId, _curveParameter);
        for (uint i=0; i<_existingItems; i++) {
            buyAccessory(0, accessoryId);
        }

        // calculate the reward for burning _returnedItems
        uint calculatedBurnReward = getBurnRewardForReturnedAccessories(_existingItems, _returnedItems, _curveParameter);
        uint actualBurnReward = liquidAccessoriesContract.getBurnRewardForReturnedAccessories(accessoryId, _returnedItems);
        require(calculatedBurnReward == actualBurnReward, "Burn reward mismatch");
    }

    function getEquipStatus(uint _miladyId, uint _accessoryId) 
        private
        view
        returns (uint _equippedAccessoryId)
    {
        (uint128 _type,) = avatarContract.accessoryIdToTypeAndVariantIds(_accessoryId);
        _equippedAccessoryId = avatarContract.equipSlots(0, _type);
    }

    function logRewardConfiguration(uint _miladyId, uint _accessoryId)
        private
        view
    {
        (uint rewardsPerWearerAccrued, uint totalWearers) = rewardsContract.rewardInfoForAccessory(_accessoryId);
        (bool isRegistered, uint amountCliamed) = rewardsContract.getMiladyRewardInfoForAccessory(_miladyId, _accessoryId);

        console.log("rewards miladyId", _miladyId);
        console.log("rewards accessoryId", _accessoryId);
        console.log("rewardsPerWearerAccrued", rewardsPerWearerAccrued);
        console.log("totalWearers", totalWearers);
        console.log("isRegistered", isRegistered);
        console.log("amountCliamed", amountCliamed);
    }

    function getFreeAmount(uint _existingItems, uint _newItems, uint _curveParameter) 
        public
        pure
        returns (uint _freeAmount)
    {
        _freeAmount = 
            getMintCostForNewAccessories(_existingItems, _newItems, _curveParameter) 
            - getBurnRewardForReturnedAccessories(_existingItems, _newItems, _curveParameter);
    }

    function test_MintDisbursements
            (
            uint _curveParameter,
            uint _existingItems,
            uint _newItems,
            uint _seed)
            // ()
        public
    {
        vm.assume(_curveParameter > 0);
        vm.assume(_curveParameter < 10**18);
        vm.assume(_existingItems < 5);
        vm.assume(_newItems < 5);
        vm.assume(_newItems > 0);

        // (
        //     uint _curveParameter,
        //     uint _existingItems,
        //     uint _newItems,
        //     uint _seed) = (1, 0, 1, 0);
        
        // init existing items
        uint accessoryId = random(_seed);
        createAccessory(accessoryId, _curveParameter);
        for (uint i=0; i<_existingItems; i++) {
            buyAndEquipAccessory(0, accessoryId);
        }

        // calculate the reward for minting, as well as the disbursed amounts
        // compare them to the actual disbursements
        uint calculatedMintCost = getMintCostForNewAccessories(_existingItems, _newItems, _curveParameter);
        uint freeAmount = 
            calculatedMintCost - ((calculatedMintCost * 1000) / 1200);

        console.log("Calcualted mint cost", calculatedMintCost);
        console.log("Free amount", freeAmount);

        uint calculatedRewards; 
        uint calculatedDisbursementVW;
        
        if (_existingItems == 0) {
            calculatedDisbursementVW = freeAmount;
            calculatedRewards = 0;
        } else {
            calculatedRewards = freeAmount / 2;
            calculatedDisbursementVW = freeAmount - calculatedRewards;
        }
        
        address payable overpayRecipient = payable(randomAddress(_seed));
        uint overpayRecipientBalanceBefore = overpayRecipient.balance;
        uint revenueRecipientBalanceBefore = PROJECT_REVENUE_RECIPIENT.balance;
        uint rewardsBalanceBefore = address(rewardsContract).balance;

        uint[] memory accessoryIds = new uint[](1);
        accessoryIds[0] = accessoryId;
        uint[] memory amounts = new uint[](1);
        amounts[0] = _newItems;

        vm.deal(address(this), calculatedMintCost + 1);
        vm.prank(address(this));
        console.log("equipStatus", getEquipStatus(0, accessoryId));
        logRewardConfiguration(0, accessoryId);
        console.log("-------------------");
        liquidAccessoriesContract.mintAccessories
            { value : calculatedMintCost * 2 } 
            (accessoryIds, 
            amounts, 
            avatarContract.ownerOf(1), 
            overpayRecipient);

        uint overpayRecipientBalanceAfter = overpayRecipient.balance;
        uint revenueRecipientBalanceAfter = PROJECT_REVENUE_RECIPIENT.balance;
        uint rewardsBalanceAfter = address(rewardsContract).balance;

        logRewardConfiguration(0, accessoryId);
        console.log("-------------------");

        console.log("calculatedMintCost", calculatedMintCost);
        console.log("freeAmount", freeAmount);
        console.log("calculatedDisbursementVW", calculatedDisbursementVW);
        console.log("revenueRecipientBalanceBefore", revenueRecipientBalanceBefore);
        console.log("revenueRecipientBalanceAfter", revenueRecipientBalanceAfter);
        console.log("rewardsBalanceBefore", rewardsBalanceBefore);
        console.log("rewardsBalanceAfter", address(rewardsContract).balance);
        console.log("overpayRecipientBalanceBefore", overpayRecipientBalanceBefore);
        console.log("overpayRecipientBalanceAfter", overpayRecipientBalanceAfter);

        require(overpayRecipientBalanceAfter == overpayRecipientBalanceBefore + 1, "Overpay recipient balance mismatch");
        require(absDiff(revenueRecipientBalanceAfter, (revenueRecipientBalanceBefore + calculatedDisbursementVW)) <= 10, "Revenue recipient balance mismatch");
        require(absDiff(rewardsBalanceAfter, (rewardsBalanceBefore + calculatedRewards)) <= 10, "Rewards balance mismatch");
    }
    
    function absDiff(uint _a, uint _b)
        private
        pure
        returns (uint _diff)
    {
        if (_a > _b) {
            _diff = _a - _b;
        } else {
            _diff = _b - _a;
        }
    }
}