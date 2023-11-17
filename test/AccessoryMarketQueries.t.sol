pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "./MiladyOSTestBase.sol";
import "../src/AccessoryMarketQueries.sol";

contract AccessoryMarketQueriesTest is MiladyOSTestBase {
    function test_query(uint accessoryId) public {
        AccessoryMarketQueries amqContract = new AccessoryMarketQueries(liquidAccessoriesContract, address(this));

        // activate accessories in LiquidAccessories and amqContract
        vm.prank(liquidAccessoriesContract.owner());
        liquidAccessoriesContract.defineBondingCurveParameter(accessoryId, 14);
        uint[] memory idsToSet = new uint[](1);
        idsToSet[0] = accessoryId;
        amqContract.activateAccessories(idsToSet);

        (uint[] memory returnedIds, uint[] memory mintPrices, uint[] memory burnRewards) = amqContract.getActivatedAccessoryPrices();

        require(returnedIds.length == 1 && mintPrices.length == 1 && burnRewards.length == 1, "wrong number of accessories returned");
        require(returnedIds[0] == accessoryId, "wrong accessory ID returned");

        uint expectedBurnReward = 0;
        uint expectedMintCost = (uint(0.005 ether) + 14 * 0 * 0) * 1200 / 1000;

        require(burnRewards[0] == expectedBurnReward, "wrong burn reward returned");
        require(mintPrices[0] == expectedMintCost, "wrong mint price returned");

        // mint an accessory and try it again
        uint[] memory amountsToMint = new uint[](1);
        amountsToMint[0] = 1;
        liquidAccessoriesContract.mintAccessories{value:expectedMintCost}(idsToSet, amountsToMint, address(this), payable(address(this)));

        (returnedIds, mintPrices, burnRewards) = amqContract.getActivatedAccessoryPrices();

        expectedBurnReward = (uint(0.005 ether) + 14 * 0 * 0);
        expectedMintCost = (uint(0.005 ether) + 14 * 1 * 1) * 1200 / 1000;

        require(burnRewards[0] == expectedBurnReward, "wrong burn reward returned");
        require(mintPrices[0] == expectedMintCost, "wrong mint price returned");
    }
}