// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC1155/ERC1155.sol";
import "./TGA/TBARegistry.sol";
import "./AccessoryUtils.sol";
import "./MiladyAvatar.sol";
import "./Rewards.sol";

contract LiquidAccessories is ERC1155 {
    TBARegistry public tbaRegistry;
    MiladyAvatar public avatarContract;

    Rewards rewardsContract;
    address payable revenueRecipient;

    // only used for initial deploy
    address deployer;

    constructor(TBARegistry _tbaRegistry, Rewards _rewardsContract, address payable _revenueRecipient, string memory uri_)
        ERC1155(uri_)
    {
        deployer = msg.sender;

        tbaRegistry = _tbaRegistry;
        rewardsContract = _rewardsContract;
        revenueRecipient = _revenueRecipient;

        require(address(tbaRegistry) != address(0), "tbaRegistry cannot be the 0x0 address");
    }

    function setAvatarContract(MiladyAvatar _avatarContract)
        external
    {
        require(msg.sender == deployer, "Only callable by the initial deployer");
        require(address(avatarContract) == address(0), "avatar contract already set");

        avatarContract = _avatarContract;
    }
    
    mapping(uint => uint) public liquidAccessorySupply;

    function mintAccessories(uint[] calldata accessoryIds, uint[] calldata amounts, address payable overpayReturnAddress)
        external
        payable
    {
        require(accessoryIds.length == amounts.length, "array arguments must have the same length");
        
        uint totalMintCost;
        for (uint i=0; i<accessoryIds.length; i++) {
            totalMintCost += getMintCostForNewAccessories(accessoryIds[i], amounts[i]);
        }
        require(msg.value >= totalMintCost, "Not enough ether included to buy that accessory.");

        for (uint i=0; i<accessoryIds.length; i++) {
            _mintAccessoryAndDisburseRevenue(accessoryIds[i], amounts[i]);
        }

        if (msg.value > totalMintCost) {
            // return extra in case of overpayment
            // schalk: is this the appropriate tfer func to use?
            overpayReturnAddress.transfer(msg.value - totalMintCost);
        }
    }

    function _mintAccessoryAndDisburseRevenue(uint accessoryId, uint amount)
        internal
    {
        uint mintCost = _mintAccessory(accessoryId, amount);

        // let's now take revenue.
        uint burnReward = getBurnRewardForReturnedAccessories(accessoryId, amount);
        uint freeRevenue = mintCost - burnReward;

        // If no one is currently equipping the accessory, the rewards contract will revert.
        // We test for this and just send everything to revenueRecipient if that's the case.
        (, uint numEligibleRewardRecipients) = rewardsContract.rewardInfoForAccessory(accessoryId);
        if (numEligibleRewardRecipients == 0) {
            // syntax / which transfer func?
            revenueRecipient.transfer(freeRevenue);
        }
        else {
            uint halfFreeRevenue = freeRevenue / 2;

            rewardsContract.accrueRewardsForAccessory{value:halfFreeRevenue}(accessoryId);

            // using `totalRevenue-halfFreeRevenue` instead of simply `halfFreeRevenue` to handle rounding errors from div by 2
            // schalk: is this the appropriate tfer func to use?
            revenueRecipient.transfer(freeRevenue - halfFreeRevenue);
        }
    }

    function _mintAccessory(uint accessoryId, uint amount)
        internal
        returns (uint cost)
    {
        cost = getMintCostForNewAccessories(accessoryId, amount);

        liquidAccessorySupply[accessoryId] += amount;

        _mint(msg.sender, accessoryId, amount, "");
    }

    function burnAccessory(uint accessoryId, uint amount, address payable fundsRecipient)
        public
    {
        require(balanceOf(msg.sender, accessoryId) >= amount, "You don't own that many of that accessory.");

        uint burnReward = getBurnRewardForReturnedAccessories(accessoryId, amount);
        
        liquidAccessorySupply[accessoryId] -= amount;

        _burn(msg.sender, accessoryId, amount);

        fundsRecipient.transfer(burnReward);
    }

    // batch call of the previous function
    function burnAccessories(uint[] calldata accessoryIds, uint[] calldata amounts, address payable fundsRecipient)
        external
        payable
    {
        require(accessoryIds.length == amounts.length, "array arguments must have the same length");

        for (uint i=0; i<accessoryIds.length; i++) {
            burnAccessory(accessoryIds[i], amounts[i], fundsRecipient);
        }
    }

    function getMintCostForNewAccessories(uint accessoryId, uint amount)
        public
        view
        returns (uint)
    {
        uint currentSupplyOfAccessory = liquidAccessorySupply[accessoryId];

        uint totalCost;
        for (uint i=0; i<amount; i++) {
            totalCost += getMintCostForItemNumber(currentSupplyOfAccessory + i);
        }
        return totalCost;
    }

    function getBurnRewardForReturnedAccessories(uint accessoryId, uint amount)
        public
        view
        returns (uint)
    {
        uint currentSupplyOfAccessory = liquidAccessorySupply[accessoryId];
        require(amount <= currentSupplyOfAccessory, "Not enough supply of that accessory");

        uint totalReward;
        for (uint i=0; i<amount; i++) {
            totalReward += getBurnRewardForItemNumber((currentSupplyOfAccessory - 1) - i);
        }
        return totalReward;
    }

    function getMintCostForItemNumber(uint itemNumber)
        public
        pure
        returns (uint)
    {
        return
            ((getBurnRewardForItemNumber(itemNumber) * 1100))
            / 1000
        ;
    }

    function getBurnRewardForItemNumber(uint itemNumber)
        public
        pure
        returns (uint)
    {
        return 0.001 ether * (itemNumber + 1);
    }

    // We need to make sure the equip status is updated if we send away an accessory that is currently equipped.
    function _beforeTokenTransfer(address, address from, address, uint256[] memory ids, uint256[] memory amounts, bytes memory)
        internal
        override
    {
        for (uint i=0; i<ids.length; i++) {

            // check if we're sending from a miladyAvatar TBA
            (address tbaTokenContract, uint tbaTokenId) = tbaRegistry.registeredAccounts(from);
            // tbaTokenContract == 0x0 if not a TBA
            if (tbaTokenContract == address(avatarContract)) {
                
                // next 3 lines for clarity. possible todo: remove for gas savings
                uint accessoryId = ids[i];
                uint requestedAmountToTransfer = amounts[i];
                uint miladyId = tbaTokenId;

                // check if this transfer would result in a 0 balance
                if (requestedAmountToTransfer == balanceOf(from, accessoryId)) { // if requestedAmountToTransfer is > balance, OZ's 1155 logic will catch and revert
                    //unequip if it's equipped
                    avatarContract.preTransferUnequipById(miladyId, accessoryId);
                }
            }
        }
    }
}