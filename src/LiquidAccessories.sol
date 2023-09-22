// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC1155/ERC1155.sol";
import "./TBA/TBARegistry.sol";
import "./AccessoryUtils.sol";
import "./MiladyAvatar.sol";
import "./Rewards.sol";

contract LiquidAccessories is ERC1155 {
    TBARegistry public tbaRegistry;
    MiladyAvatar public miladyAvatarContract;

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

    function setAvatarContract(MiladyAvatar _miladyAvatarContract)
        external
    {
        require(msg.sender == deployer, "Only callable by the initial deployer");
        require(address(miladyAvatarContract) == address(0), "avatar contract already set");

        miladyAvatarContract = _miladyAvatarContract;
    }
    
    mapping(uint => uint) public liquidAccessorySupply;

    function mintAccessoryAndDisburseRevenue(uint accessoryId, address payable overpayReturnAddress)
        public
        payable
    {
        uint buyPrice = getBuyPriceOfNewAccessory(accessoryId);
        require (msg.value >= buyPrice, "Not enough ether included to buy that accessory.");

        liquidAccessorySupply[accessoryId] ++;

        _mint(msg.sender, uint256(accessoryId), 1, "");

        // let's now take revenue.
        // now that we've minted, we can get the current sell price, to know how much we can skim off the top
        uint sellPrice = getSellPriceOfAccessory(accessoryId);
        uint totalRevenue = buyPrice - sellPrice;

        // If no one is currently equipping the accessory, the rewards contract will revert.
        // We test for this and just send everything to revenueRecipient if that's the case.
        (, uint numEligibleRewardRecipients) = rewardsContract.rewardInfoForAccessory(accessoryId);
        if (numEligibleRewardRecipients == 0) {
            // syntax / which transfer func?
            revenueRecipient.transfer(totalRevenue);
        }
        else {
            uint halfRevenue = totalRevenue / 2;

            rewardsContract.accrueRewardsForAccessory{value:halfRevenue}(accessoryId);

            // using `totalRevenue-halfRevenue` instead of simply `halfRevenue` to handle rounding errors from div by 2
            // schalk: is this the appropriate tfer func to use?
            revenueRecipient.transfer(totalRevenue - halfRevenue);
        }

        if (msg.value > buyPrice) {
            // return extra in case of overpayment
            // schalk: is this the appropriate tfer func to use?
            overpayReturnAddress.transfer(msg.value - buyPrice);
        }
    }

    // batch call of the previous function
    function mintAccessoriesAndDisburseRevenue(uint[] calldata accessoryIds, uint[] calldata numBuysOfAccessory, address payable overpayReturnAddress)
        external
        payable
    {
        require(accessoryIds.length == numBuysOfAccessory.length, "array arguments must have the same length");

        for (uint i=0; i<accessoryIds.length; i++) {
            for (uint j=0; j<numBuysOfAccessory[i]; j++) {
                // schalk: is there a concern of re-entry here? I don't think so, since this call always changes state then disburses funds...?
                mintAccessoryAndDisburseRevenue(accessoryIds[i], overpayReturnAddress);
            }
        }
    }

    function returnAccessory(uint accessory, address payable fundsRecipient)
        public
    {
        require(balanceOf(msg.sender, accessory) > 0, "You don't own that accessory.");

        uint sellPrice = getSellPriceOfAccessory(accessory);

        fundsRecipient.transfer(sellPrice);
        
        liquidAccessorySupply[accessory] --;

        _burn(msg.sender, accessory, 1);
    }

    function getBuyPriceOfNewAccessory(uint accessory)
        public
        view
        returns (uint)
    {
        uint currentSupplyOfAccessory = liquidAccessorySupply[accessory];
        return getBuyPriceGivenSupply(currentSupplyOfAccessory + 1);
    }

    function getSellPriceOfAccessory(uint accessory)
        public
        view
        returns (uint)
    {
        uint currentSupplyOfAccessory = liquidAccessorySupply[accessory];
        return getSellPriceGivenSupply(currentSupplyOfAccessory);
    }

    function getBuyPriceGivenSupply(uint supply)
        public
        pure
        returns (uint)
    {
        return
            ((getSellPriceGivenSupply(supply + 1) * 1100))
            / 1000
        ;
    }

    function getSellPriceGivenSupply(uint supply)
        public
        pure
        returns (uint)
    {
        return 0.001 ether * supply;
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
            if (tbaTokenContract == address(miladyAvatarContract)) {
                
                // next 3 lines for clarity. possible todo: remove for gas savings
                uint accessoryId = ids[i];
                uint requestedAmountToTransfer = amounts[i];
                uint miladyId = tbaTokenId;

                // check if this transfer would result in a 0 balance
                if (requestedAmountToTransfer == balanceOf(from, accessoryId)) { // if requestedAmountToTransfer is > balance, OZ's 1155 logic will catch and revert
                    //unequip if it's equipped
                    miladyAvatarContract.unequipAccessoryByIdIfEquipped(miladyId, accessoryId);
                }
            }
        }
    }
}