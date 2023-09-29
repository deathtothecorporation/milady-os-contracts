// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC1155/ERC1155.sol";
import "openzeppelin/access/Ownable.sol";
import "./TGA/TBARegistry.sol";
import "./MiladyAvatar.sol";
import "./Rewards.sol";

contract LiquidAccessories is ERC1155, Ownable {
    TBARegistry public tbaRegistry;
    MiladyAvatar public avatarContract;

    Rewards rewardsContract;
    address payable revenueRecipient;

    address deployer; // only used for initial deploy

    constructor(
            TBARegistry _tbaRegistry, 
            Rewards _rewardsContract, 
            address payable _revenueRecipient, 
            string memory uri_)
        ERC1155(uri_)
    {
        deployer = msg.sender;

        tbaRegistry = _tbaRegistry;
        rewardsContract = _rewardsContract;
        revenueRecipient = _revenueRecipient;
    }

    function setAvatarContract(MiladyAvatar _avatarContract)
        external
    {
        require(msg.sender == deployer, "Not deployer");
        require(address(avatarContract) == address(0), "avatarContract already set");

        avatarContract = _avatarContract;
    }
    
    mapping(uint => BondingCurveInfo) public bondingCurves;
    struct BondingCurveInfo {
        uint accessorySupply;
        uint curveParameter;
    }

    function defineBondingCurveParameter(uint _accessoryId, uint _parameter)
        external
        onlyOwner()
    {
        require(_parameter != 0, "Parameter cannot be 0");
        require(bondingCurves[_accessoryId].curveParameter == 0, "Parameter already set");

        bondingCurves[_accessoryId].curveParameter = _parameter;
    }

    function mintAccessories(
            uint[] calldata _accessoryIds, 
            uint[] calldata _amounts, 
            address _recipient, 
            address payable _overpayReturnAddress)
        external
        payable
    {
        // note that msg.value functions as an implicit "minimumIn" (analagous to burnAccessories's "minRewardOut"),
        // implicitly protecting this purchase from sandwich attacks
        require(_accessoryIds.length == _amounts.length, "Array lengths differ");
        
        uint totalMintCost;
        for (uint i=0; i<_accessoryIds.length; i++) {
            totalMintCost += getMintCostForNewAccessories(_accessoryIds[i], _amounts[i]);
        }
        require(msg.value >= totalMintCost, "Insufficient Ether included");

        for (uint i=0; i<_accessoryIds.length; i++) {
            _mintAccessoryAndDisburseRevenue(_accessoryIds[i], _amounts[i], _recipient);
        }

        if (msg.value > totalMintCost) {
            // return extra in case of overpayment
            _overpayReturnAddress.transfer(msg.value - totalMintCost);
        }
    }

    function _mintAccessoryAndDisburseRevenue(uint _accessoryId, uint _amount, address _recipient)
        internal
    {
        uint mintCost = _mintAccessory(_accessoryId, _amount, _recipient);

        // let's now take revenue.
        uint burnReward = getBurnRewardForReturnedAccessories(_accessoryId, _amount);
        uint freeRevenue = mintCost - burnReward;

        // If no one is currently equipping the accessory, the rewards contract will revert.
        // We test for this and just send everything to revenueRecipient if that's the case.
        (, uint numEligibleRewardRecipients) = rewardsContract.rewardInfoForAccessory(_accessoryId);
        if (numEligibleRewardRecipients == 0) {
            // syntax / which transfer func?
            revenueRecipient.transfer(freeRevenue);
        }
        else {
            uint halfFreeRevenue = freeRevenue / 2;

            rewardsContract.addRewardsForAccessory{value:halfFreeRevenue}(_accessoryId);

            // using `totalRevenue-halfFreeRevenue` instead of simply `halfFreeRevenue` to handle rounding errors from div by 2
            revenueRecipient.transfer(freeRevenue - halfFreeRevenue);
        }
    }

    function _mintAccessory(uint _accessoryId, uint _amount, address _recipient)
        internal
        returns (uint cost)
    {
        // Logan <| Does this need to be in here? It isn't used here
        cost = getMintCostForNewAccessories(_accessoryId, _amount);

        bondingCurves[_accessoryId].accessorySupply += _amount;

        _mint(_recipient, _accessoryId, _amount, "");
    }

    function burnAccessories(uint[] calldata _accessoryIds, uint[] calldata _amounts, uint _minRewardOut, address payable _fundsRecipient)
        external
    {
        require(_accessoryIds.length == _amounts.length, "array arguments must have the same length");

        uint totalBurnReward;
        for (uint i=0; i<_accessoryIds.length; i++) {
            totalBurnReward += _burnAccessory(_accessoryIds[i], _amounts[i], _fundsRecipient);
        }

        require(totalBurnReward >= _minRewardOut, "Minimum specified reward not met");
    }

    function _burnAccessory(uint _accessoryId, uint _amount, address payable _fundsRecipient)
        internal
        returns (uint burnReward)
    {
        require(balanceOf(msg.sender, _accessoryId) >= _amount, "You don't own that many of that accessory.");

        burnReward = getBurnRewardForReturnedAccessories(_accessoryId, _amount);
        
        bondingCurves[_accessoryId].accessorySupply -= _amount;

        _burn(msg.sender, _accessoryId, _amount);

        _fundsRecipient.transfer(burnReward);
    }

    function getMintCostForNewAccessories(uint _accessoryId, uint _amount)
        public
        view
        returns (uint)
    {
        uint currentSupplyOfAccessory = bondingCurves[_accessoryId].accessorySupply;
        uint curveParameter = bondingCurves[_accessoryId].curveParameter;
        require(curveParameter != 0, "Item has no bonding curve");

        uint totalCost;
        for (uint i=0; i<_amount; i++) {
            totalCost += getMintCostForItemNumber(currentSupplyOfAccessory + i, curveParameter);
        }
        return totalCost;
    }

    function getBurnRewardForReturnedAccessories(uint _accessoryId, uint _amount)
        public
        view
        returns (uint)
    {
        uint currentSupplyOfAccessory = bondingCurves[_accessoryId].accessorySupply;
        require(_amount <= currentSupplyOfAccessory, "Insufficient accessory supply");
        uint curveParameter = bondingCurves[_accessoryId].curveParameter;
        require(curveParameter != 0, "No bonding curve");

        uint totalReward;
        for (uint i=0; i<_amount; i++) {
            totalReward += getBurnRewardForItemNumber((currentSupplyOfAccessory - 1) - i, curveParameter);
        }
        return totalReward;
    }

    function getMintCostForItemNumber(uint _itemNumber, uint _curveParameter)
        public
        pure
        returns (uint)
    {
        return
            ((getBurnRewardForItemNumber(_itemNumber, _curveParameter) * 1100))
            / 1000
        ;
    }

    function getBurnRewardForItemNumber(uint _itemNumber, uint _curveParameter)
        public
        pure
        returns (uint)
    {
        return 0.005 ether + _curveParameter * _itemNumber * _itemNumber;
    }

    // We need to make sure the equip status is updated if we send away an accessory that is currently equipped.
    function _beforeTokenTransfer(
            address, 
            address _from, 
            address, 
            uint256[] memory _ids, 
            uint256[] memory _amounts, 
            bytes memory)
        internal
        override
    {
        // check if we're sending from a miladyAvatar TBA
        (address tbaTokenContract, uint tbaTokenId) = tbaRegistry.registeredAccounts(_from);
        
        // tbaTokenContract == 0x0 if not a TBA
        if (tbaTokenContract == address(avatarContract)) {
            for (uint i=0; i<_ids.length; i++) {
                
                // next 3 lines for clarity. possible todo: remove for gas savings
                uint accessoryId = _ids[i];
                uint requestedAmountToTransfer = _amounts[i];
                uint miladyId = tbaTokenId;

                // check if this transfer would result in a 0 balance of that accessory
                if (requestedAmountToTransfer == avatarContract.totalAccessoryBalanceOfAvatar(miladyId, accessoryId)) {
                    //unequip if it's equipped
                    avatarContract.preTransferUnequipById(miladyId, accessoryId);
                }
            }
        }
    }
}