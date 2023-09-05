// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC1155/ERC1155.sol";
import "openzeppelin/utils/math/SafeMath.sol";

// todo: change uint16 to uint

contract AccessoryMinter is ERC1155 {
    constructor(string memory uri)
        ERC1155(uri)
    {}
    
    mapping(uint16 => uint) public accessorySupply;

    function mintAccessory(uint16 accessory, address payable overpayReturnAddress)
        public
        payable
    {
        uint price = getBuyPriceOfNewAccessory(accessory);
        require (msg.value >= price, "Not enough ether included to buy that accessory.");
        if (msg.value > price) {
            // return extra in case of overpayment
            overpayReturnAddress.transfer(msg.value - price);
        }

        accessorySupply[accessory] ++;

        _mint(msg.sender, uint256(accessory), 1, ""); // todo: better handling of data?
    }

    function returnAccessory(uint16 accessory, address payable fundsRecipient)
        public
    {
        require(balanceOf(msg.sender, accessory) > 0, "You don't own that accessory.");

        uint sellPrice = getSellPriceOfAccessory(accessory);

        fundsRecipient.transfer(sellPrice);
        
        accessorySupply[accessory] --;

        _burn(msg.sender, accessory, 1);
    }

    function getBuyPriceOfNewAccessory(uint16 accessory)
        public
        view
        returns (uint)
    {
        uint currentSupplyOfAccessory = accessorySupply[accessory];
        return getBuyPriceGivenSupply(currentSupplyOfAccessory + 1);
    }

    function getSellPriceOfAccessory(uint16 accessory)
        public
        view
        returns (uint)
    {
        uint currentSupplyOfAccessory = accessorySupply[accessory];
        return getSellPriceGivenSupply(currentSupplyOfAccessory);
    }

    function getBuyPriceGivenSupply(uint supply)
        public
        pure
        returns (uint)
    {
        return SafeMath.div(
            SafeMath.mul(
                getSellPriceGivenSupply(supply + 1),
                1100),
            1000
        );
    }

    function getSellPriceGivenSupply(uint supply)
        public
        pure
        returns (uint)
    {
        return 0.001 ether * supply;
    }
}