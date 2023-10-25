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
        view
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
        // mint _newItems number of items
        // check that the cost of minting _newItems is the same as the cost of minting _existingItems + _newItems

        vm.assume(_curveParameter > 0);
        vm.assume(_curveParameter < 10**18);
        vm.assume(_existingItems < 10);
        vm.assume(_newItems > 0);
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
        // burn _returnedItems number of items
        // check that the reward for burning _returnedItems is the same as the reward for burning _existingItems - _returnedItems

        vm.assume(_curveParameter > 0);
        vm.assume(_curveParameter < 10**18);
        vm.assume(_existingItems < 10);
        vm.assume(_returnedItems > 0);
        vm.assume(_returnedItems < 100);

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
}