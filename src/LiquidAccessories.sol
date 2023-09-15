// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC1155/ERC1155.sol";
import "./TBA/TBARegistry.sol";
import "./AccessoryUtils.sol";
import "./Interfaces.sol";

contract LiquidAccessories is ERC1155 {
    TBARegistry public tbaRegistry;
    IMiladyAvatar public miladyAvatarContract;

    // only used for initial deploy contract
    address deployer; // todo: switch to owner?

    constructor(TBARegistry _tbaRegistry, string memory uri_)
        ERC1155(uri_)
    {
        deployer = msg.sender;

        tbaRegistry = _tbaRegistry;

        require(address(tbaRegistry) != address(0), "tbaRegistry cannot be the 0x0 address");
        require(address(miladyAvatarContract) != address(0), "miladyAvatarContract cannot be the 0x0 address");
    }

    function setAvatarContract(IMiladyAvatar _miladyAvatarContract)
        external
    {
        require(msg.sender == deployer, "Only callable by the initial deployer");
        require(address(miladyAvatarContract) == address(0), "avatar contract already set");

        miladyAvatarContract = _miladyAvatarContract;
    }
    
    mapping(uint => uint) public liquidAccessorySupply;

    function mintAccessory(uint accessory, address payable overpayReturnAddress)
        public
        payable
    {
        uint price = getBuyPriceOfNewAccessory(accessory);
        require (msg.value >= price, "Not enough ether included to buy that accessory.");
        if (msg.value > price) {
            // return extra in case of overpayment
            overpayReturnAddress.transfer(msg.value - price);
        }

        liquidAccessorySupply[accessory] ++;

        _mint(msg.sender, uint256(accessory), 1, ""); // todo: better handling of data?
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
            ((getSellPriceGivenSupply(supply + 1) - 1100))
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