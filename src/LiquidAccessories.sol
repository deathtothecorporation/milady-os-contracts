/* solhint-disable private-vars-leading-underscore */

pragma solidity 0.8.18;

import "openzeppelin/token/ERC1155/ERC1155.sol";
import "openzeppelin/access/Ownable.sol";
import "openzeppelin/security/ReentrancyGuard.sol";
import "TokenGatedAccount/TGARegistry.sol";
import "./MiladyAvatar.sol";
import "./Rewards.sol";

/**
 * @title LiquidAccessories
 * @dev A contract for minting and burning accessories based on bonding curves.
 * Users can mint or burn accessories and the cost/reward is determined by the curve.
 */
contract LiquidAccessories is ERC1155, Ownable, ReentrancyGuard {
    TGARegistry public tgaRegistry;
    MiladyAvatar public avatarContract;

    Rewards immutable rewardsContract;
    address payable revenueRecipient;

    address immutable initialDeployer; 

    /**
     * @dev Initializes the contract setting the TGARegistry, Rewards, revenueRecipient, and the URI.
     * @param _tgaRegistry Address of the TGARegistry contract.
     * @param _rewardsContract Address of the Rewards contract.
     * @param _revenueRecipient Address where revenues are sent.
     * @param uri_ URI to be passed to the ERC1155 contract.
     */
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

    /**
     * @dev Allows the initial deployer to set the MiladyAvatar contract.
     * @param _avatarContract Address of the MiladyAvatar contract.
     */
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

    /**
     * @dev Defines the curve parameter for a given accessory.
     * @param _accessoryId The ID of the accessory.
     * @param _parameter The curve parameter for the accessory.
     */
    function defineBondingCurveParameter(uint _accessoryId, uint _parameter)
        external
        onlyOwner()
    {
        require(_parameter != 0, "Parameter cannot be 0");
        require(bondingCurves[_accessoryId].curveParameter == 0, "Parameter already set");

        bondingCurves[_accessoryId].curveParameter = _parameter;
    }

    /**
     * @dev Allows the owner to change the address where revenues are sent.
     * @param _revenueRecipient New address for receiving revenues.
     */
    function changeRevenueRecipient(address payable _revenueRecipient)
        external
        onlyOwner()
    {
        revenueRecipient = _revenueRecipient;
    }

    /**
     * @notice Mints the specified accessories and sends them to the recipient.
     * @param _accessoryIds Array of accessory IDs to mint.
     * @param _amounts Corresponding array of amounts for each accessory.
     * @param _recipient The address that will receive the minted accessories.
     * @param _overpayReturnAddress The address to return any excess ether to.
     */
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
    
    /**
     * @notice Mints a specific accessory and distributes the revenue accordingly.
     * @param _accessoryId ID of the accessory to mint.
     * @param _amount Amount of the accessory to mint.
     * @param _recipient The address that will receive the minted accessories.
     */
    function _mintAccessoryAndDisburseRevenue(uint _accessoryId, uint _amount, address _recipient)
        internal
        // only called from mintAccessories, therefore non-reentrant
    {
        require(_amount > 0, "amount cannot be 0");

        uint mintCost = getMintCostForNewAccessories(_accessoryId, _amount);
        _mintAccessory(_accessoryId, _amount, _recipient);

        uint burnReward = getBurnRewardForReturnedAccessories(_accessoryId, _amount);
        uint freeRevenue = mintCost - burnReward;

        // If no one is currently equipping the accessory, the rewards contract will revert.
        // We test for this and just send everything to revenueRecipient if that's the case.
        (, uint numEligibleRewardRecipients) = rewardsContract.rewardInfoForAccessory(_accessoryId);
        if (numEligibleRewardRecipients == 0) {
            (bool success, ) = revenueRecipient.call{ value: freeRevenue }("");
            require(success, "Transfer failed");
        }
        else {
            uint halfFreeRevenue = freeRevenue / 2;

            rewardsContract.addRewardsForAccessory{value:halfFreeRevenue}(_accessoryId);

            // using `totalRevenue-halfFreeRevenue` instead of simply `halfFreeRevenue` to handle rounding errors from div by 2
            (bool success,) = revenueRecipient.call{ value : freeRevenue - halfFreeRevenue }("");
            require(success, "Transfer failed");
        }
    }

    /**
     * @notice Internal function to mint a specific accessory.
     * @param _accessoryId ID of the accessory to mint.
     * @param _amount Amount of the accessory to mint.
     * @param _recipient The address that will receive the minted accessories.
     */
    function _mintAccessory(uint _accessoryId, uint _amount, address _recipient)
        internal
    {
        bondingCurves[_accessoryId].accessorySupply += _amount;
        _mint(_recipient, _accessoryId, _amount, "");
    }
    
    /**
     * @notice Burns the specified accessories and sends the burn reward to the specified recipient.
     * @param _accessoryIds Array of accessory IDs to burn.
     * @param _amounts Corresponding array of amounts for each accessory.
     * @param _minRewardOut Minimum expected burn reward; reverts if not met.
     * @param _fundsRecipient Address that will receive the burn reward.
     */
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

    /**
     * @notice Internal function to burn a specific accessory.
     * @param _accessoryId ID of the accessory to burn.
     * @param _amount Amount of the accessory to burn.
     */
    function _burnAccessory(uint _accessoryId, uint _amount)
        internal
    {
        require(balanceOf(msg.sender, _accessoryId) >= _amount, "Incorrect accessory balance");

        bondingCurves[_accessoryId].accessorySupply -= _amount;
        _burn(msg.sender, _accessoryId, _amount);
    }

    /**
     * @notice Calculate the ether cost to mint a specified amount of a given accessory.
     * @param _accessoryId ID of the accessory.
     * @param _amount Amount of the accessory to calculate for.
     * @return totalCost The total cost in ether.
     */
    function getMintCostForNewAccessories(uint _accessoryId, uint _amount)
        public
        view
        returns (uint)
    {
        uint currentSupplyOfAccessory = bondingCurves[_accessoryId].accessorySupply;
        uint curveParameter = bondingCurves[_accessoryId].curveParameter;
        require(curveParameter != 0, "Item has no bonding curve");

        uint totalCost;
        for (uint i=0; i<_amount;) {
            totalCost += getMintCostForItemNumber(currentSupplyOfAccessory + i, curveParameter);

            unchecked { i++; }
        }
        return totalCost;
    }

    /**
     * @notice Calculate the ether reward for burning a specified amount of a given accessory.
     * @param _accessoryId ID of the accessory.
     * @param _amount Amount of the accessory to calculate for.
     * @return totalReward The total reward in ether.
     */
    function getBurnRewardForReturnedAccessories(uint _accessoryId, uint _amount)
        public
        view
        returns (uint)
    {
        uint curveParameter = bondingCurves[_accessoryId].curveParameter;
        require(curveParameter != 0, "No bonding curve");
        uint currentSupplyOfAccessory = bondingCurves[_accessoryId].accessorySupply;
        require(_amount <= currentSupplyOfAccessory, "Insufficient accessory supply");

        uint totalReward;
        for (uint i=0; i<_amount;) {
            totalReward += getBurnRewardForItemNumber((currentSupplyOfAccessory - 1) - i, curveParameter);
            
            unchecked { i++; }
        }
        return totalReward;
    }

    /**
     * @notice Calculates the ether cost to mint a single accessory given its number in the supply.
     * @param _itemNumber The position of the accessory in the supply.
     * @param _curveParameter Parameter of the bonding curve.
     * @return The ether cost.
     */
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

    /**
     * @notice Calculates the ether reward for burning a single accessory given its number in the supply.
     * @param _itemNumber The position of the accessory in the supply.
     * @param _curveParameter Parameter of the bonding curve.
     * @return The ether reward.
     */
    function getBurnRewardForItemNumber(uint _itemNumber, uint _curveParameter)
        public
        pure
        returns (uint)
    {
        return 0.005 ether + _curveParameter * _itemNumber * _itemNumber;
    }

    /**
     * @notice Updates the equip status before a token transfer.
     * @param _from Sender address.
     * @param _ids Array of token IDs being transferred.
     * @param _amounts Corresponding array of amounts for each token ID.
     */
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