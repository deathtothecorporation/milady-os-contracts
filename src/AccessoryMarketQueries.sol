pragma solidity ^0.8.18;

import "openzeppelin/access/Ownable.sol";
import "./LiquidAccessories.sol";

/**
 * @title A convenience contract to get certain summarizing information about the market provided by LiquidAccessories
 * @author Logan Brutsche
 */
contract AccessoryMarketQueries is Ownable {
    LiquidAccessories public liquidAccessoriesContract;

    constructor(LiquidAccessories _liquidAccessoriesContract, address owner)
    {
        liquidAccessoriesContract = _liquidAccessoriesContract;

        transferOwnership(owner);
    }

    uint[] activatedAccessories;

    /**
     * @notice Marks a list of accessories as activated
     * @param ids The list of accessory IDs to activate
     */
    function activateAccessories(uint256[] calldata ids)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < ids.length; i++) {
            activatedAccessories.push(ids[i]);
        }
    }

    /**
     * @notice Removes a list of accessories from the activated list
     * @dev This function rearranges the array, so the order of the array will change
     * @param idPositions The list of positions in the activated list to deactivate
     */
    function deactivateAccessories_rearrangeArray(uint256[] calldata idPositions)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < idPositions.length; i++) {
            activatedAccessories[idPositions[i]] = activatedAccessories[activatedAccessories.length - 1];
            activatedAccessories.pop();
        }
    }

    /**
     * @notice Returns the ID and current mint and burn price of each activated accessory
     * @dev "activated" means accessories whose bonding curves have been defined.
     * @return 3 lists of the same size, respectively containing the accessory ID, mint price, and burn price of each activated accessory
     */
    function getActivatedAccessoryPrices()
        external
        view
        returns (uint256[] memory, uint256[] memory, uint256[] memory)
    {
        uint256[] memory mintPrices = new uint256[](activatedAccessories.length);
        uint256[] memory burnPrices = new uint256[](activatedAccessories.length);

        for (uint256 i = 0; i < activatedAccessories.length; i++) {
            mintPrices[i] = liquidAccessoriesContract.getMintCostForNewAccessories(activatedAccessories[i], 1);
            (uint supply,) = liquidAccessoriesContract.bondingCurves(activatedAccessories[i]);
            if (supply > 0) {
                burnPrices[i] = liquidAccessoriesContract.getBurnRewardForReturnedAccessories(activatedAccessories[i], 1);
            }
            // else we leave it as 0
        }

        return (activatedAccessories, mintPrices, burnPrices);
    }
}