/* solhint-disable private-vars-leading-underscore */

pragma solidity 0.8.18;

import "openzeppelin/token/ERC1155/ERC1155.sol";
import "openzeppelin/access/Ownable.sol";
import "openzeppelin/security/ReentrancyGuard.sol";
import "TokenGatedAccount/TGARegistry.sol";
import "./MiladyAvatar.sol";
import "./Rewards.sol";

contract LiquidAccessories is ERC1155, Ownable, ReentrancyGuard {
    TGARegistry public tgaRegistry;
    MiladyAvatar public avatarContract;

    Rewards immutable rewardsContract;
    address payable revenueRecipient;

    address immutable initialDeployer; 

    constructor(
            TGARegistry _tgaRegistry, 
            Rewards _rewardsContract, 
            address payable _revenueRecipient, 
            string memory uri_)
        ERC1155(uri_)
        ReentrancyGuard()
    {
        initialDeployer = msg.sender;

        tgaRegistry = _tgaRegistry;
        rewardsContract = _rewardsContract;
        revenueRecipient = _revenueRecipient;
    }

    function setAvatarContract(MiladyAvatar _avatarContract)
        external
    {
        require(msg.sender == initialDeployer, "Not deployer");
        require(address(avatarContract) == address(0), "avatarContract already set");

        avatarContract = _avatarContract;
    }
    
    // indexed by accessoryId
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

    function changeRevenueRecipient(address payable _revenueRecipient)
        external
        onlyOwner()
    {
        revenueRecipient = _revenueRecipient;
    }

    function mintAccessories(
            uint[] calldata _accessoryIds, 
            uint[] calldata _amounts, 
            address _recipient, 
            address payable _overpayReturnAddress)
        external
        payable
        nonReentrant
    {
        // note that msg.value functions as an implicit "minimumIn" (analagous to burnAccessories's "minRewardOut"),
        // implicitly protecting this purchase from sandwich attacks
        require(_accessoryIds.length == _amounts.length, "Array lengths differ");
        
        uint totalMintCost;
        for (uint i=0; i<_accessoryIds.length;) {
            totalMintCost += getMintCostForNewAccessories(_accessoryIds[i], _amounts[i]);
            unchecked { i++; }
        }
        require(msg.value >= totalMintCost, "Insufficient Ether included");

        for (uint i=0; i<_accessoryIds.length;) {
            _mintAccessoryAndDisburseRevenue(_accessoryIds[i], _amounts[i], _recipient);
            unchecked { i++; }
        }

        if (msg.value > totalMintCost) {
            // return extra in case of overpayment
            (bool success,) = _overpayReturnAddress.call{ value: msg.value - totalMintCost }("");
            require(success, "Transfer failed");
        }
    }

    function _mintAccessoryAndDisburseRevenue(uint _accessoryId, uint _amount, address _recipient)
        internal
        // only called from mintAccessories, therefore non-reentrant
    {
        require(_amount > 0, "amount cannot be 0");

        uint mintCost = getMintCostForNewAccessories(_accessoryId, _amount);
        _mintAccessory(_accessoryId, _amount, _recipient);

        uint burnReward = getBurnRewardForReturnedAccessories(_accessoryId, _amount);
        uint feeRevenue = mintCost - burnReward;

        // If no one is currently equipping the accessory, the rewards contract will revert.
        // We test for this and just send everything to revenueRecipient if that's the case.
        (, uint numEligibleRewardRecipients) = rewardsContract.rewardInfoForAccessory(_accessoryId);
        if (numEligibleRewardRecipients == 0) {
            (bool success, ) = revenueRecipient.call{ value: freeRevenue }("");
            require(success, "Transfer failed");
        }
        else {
            uint halfFeeRevenue = feeRevenue / 2;

            rewardsContract.addRewardsForAccessory{value:halfFeeRevenue}(_accessoryId);

            // using `totalRevenue-halfFreeRevenue` instead of simply `halfFreeRevenue` to handle rounding errors from div by 2
            (bool success,) = revenueRecipient.call{ value : feeRevenue - halfFeeRevenue }("");
            require(success, "Transfer failed");
        }
    }

    function _mintAccessory(uint _accessoryId, uint _amount, address _recipient)
        internal
    {
        bondingCurves[_accessoryId].accessorySupply += _amount;
        _mint(_recipient, _accessoryId, _amount, "");
    }

    function burnAccessories(
            uint[] calldata _accessoryIds, 
            uint[] calldata _amounts, 
            uint _minRewardOut, 
            address payable _fundsRecipient)
        external
        nonReentrant
    {
        require(_accessoryIds.length == _amounts.length, "Array lengths differ");

        uint totalBurnReward;
        for (uint i=0; i<_accessoryIds.length;) {
            totalBurnReward += getBurnRewardForReturnedAccessories(_accessoryIds[i], _amounts[i]);
            _burnAccessory(_accessoryIds[i], _amounts[i]);

            unchecked { i++; }
        }

        require(totalBurnReward >= _minRewardOut, "Specified reward not met");
        (bool success,) = _fundsRecipient.call{ value : totalBurnReward }("");
        require(success, "Transfer failed");
    }

    function _burnAccessory(uint _accessoryId, uint _amount)
        internal
    {
        require(balanceOf(msg.sender, _accessoryId) >= _amount, "Incorrect accessory balance");

        bondingCurves[_accessoryId].accessorySupply -= _amount;
        _burn(msg.sender, _accessoryId, _amount);
    }

    function getMintCostForNewAccessories(uint _accessoryId, uint _amount)
        public
        view
        returns (uint _totalCost)
    {
        uint currentSupplyOfAccessory = bondingCurves[_accessoryId].accessorySupply;
        uint curveParameter = bondingCurves[_accessoryId].curveParameter;
        require(curveParameter != 0, "Item has no bonding curve");

        for (uint i=0; i<_amount; i++) {
            _totalCost += getMintCostForItemNumber(currentSupplyOfAccessory + i, curveParameter);
        }
    }

    function getBurnRewardForReturnedAccessories(uint _accessoryId, uint _amount)
        public
        view
        returns (uint _totalReward)
    {
        uint curveParameter = bondingCurves[_accessoryId].curveParameter;
        require(curveParameter != 0, "No bonding curve");
        uint currentSupplyOfAccessory = bondingCurves[_accessoryId].accessorySupply;
        require(_amount <= currentSupplyOfAccessory, "Insufficient accessory supply");

        for (uint i=0; i<_amount; i++) {
            _totalReward += getBurnRewardForItemNumber((currentSupplyOfAccessory - 1) - i, curveParameter);
        }
    }

    function getMintCostForItemNumber(uint _itemNumber, uint _curveParameter)
        public
        pure
        returns (uint)
    {
        return
            ((getBurnRewardForItemNumber(_itemNumber, _curveParameter) * 1200))
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
        // check if we're sending from a miladyAvatar TGA
        (address tgaTokenContract, uint tgaTokenId) = tgaRegistry.registeredAccounts(_from);
        
        // tgaTokenContract == 0x0 if not a TGA
        if (tgaTokenContract == address(avatarContract)) {
            for (uint i=0; i<_ids.length;) {
                
                // next 3 lines for clarity. possible todo: remove for gas savings
                uint accessoryId = _ids[i];
                uint requestedAmountToTransfer = _amounts[i];
                uint miladyId = tgaTokenId;

                // check if this transfer would result in a 0 balance of that accessory
                if (requestedAmountToTransfer == avatarContract.totalAccessoryBalanceOfAvatar(miladyId, accessoryId)) {
                    //unequip if it's equipped
                    avatarContract.preTransferUnequipById(miladyId, accessoryId);
                }

                unchecked { i++; }
            }
        }
    }
}