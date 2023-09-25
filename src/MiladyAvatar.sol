// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC721/IERC721.sol";
import "./TGA/TokenGatedAccount.sol";
import "./TGA/TBARegistry.sol";
import "./Rewards.sol";
import "./AccessoryUtils.sol";
import "./LiquidAccessories.sol";
import "./SoulboundAccessories.sol";

contract MiladyAvatar is IERC721 {
    IERC721 public miladysContract;
    LiquidAccessories public liquidAccessoriesContract;
    SoulboundAccessories public soulboundAccessoriesContract;
    Rewards public rewardsContract;
    
    // state needed for TBA determination
    TBARegistry public tbaRegistry;
    IERC6551Account public tbaAccountImpl;
    uint public chainId;

    string public baseURI;

    // only used for initial deploy
    address deployer;

    constructor(
            IERC721 _miladysContract,
            TBARegistry _tbaRegistry,
            TokenGatedAccount _tbaAccountImpl,
            uint _chainId,
            string memory _baseURI
    ) {
        deployer = msg.sender;
        miladysContract = _miladysContract;
        tbaRegistry = _tbaRegistry;
        tbaAccountImpl = _tbaAccountImpl;
        chainId = _chainId;
        baseURI = _baseURI;
    }

    function setOtherContracts(
            LiquidAccessories _liquidAccessoriesContract, 
            SoulboundAccessories _soulboundAccessoriesContract, 
            Rewards _rewardsContract)
        external
    {
        require(msg.sender == deployer, "Caller not initial deployer");
        require(address(liquidAccessoriesContract) == address(0), "Contracts already set");
        
        liquidAccessoriesContract = _liquidAccessoriesContract;
        soulboundAccessoriesContract = _soulboundAccessoriesContract;
        rewardsContract = _rewardsContract;
    }

    // each avatar has equip slots for each accessory type
    mapping (uint => mapping (uint128 => uint)) public equipSlots;

    // A special function to allow the soulbound accessories to "auto equip" themselves upon mint
    // See `SoulboundAccessories.mintSoulboundAccessories`.
    function equipSoulboundAccessories(uint _miladyId, uint[] calldata _accessoryIds)
        external
    {
        require(msg.sender == address(soulboundAccessoriesContract), "Not SoulboundAccessories");

        for (uint i=0; i<_accessoryIds.length; i++) {
            _equipAccessoryIfOwned(_miladyId, _accessoryIds[i]);
        }
    }
    
    // main entry point for a user to change their Avatar's appearance / equip status
    // If an accessoryId's unpacked accVariant == 0, we interpret this as an unequip action
    function updateEquipSlotsByAccessoryIds(uint miladyId, uint[] memory accessoryIds)
        public
    {
        require(msg.sender == ownerOf(miladyId), "You don't own that Milady Avatar");

        for (uint i=0; i<accessoryIds.length; i++) {
            (uint128 accType, uint128 accVariant) = AccessoryUtils.idToTypeAndVariantHashes(accessoryIds[i]);

            _updateEquipSlotByTypeAndVariant(miladyId, accType, accVariant);
        }
    }

    function _updateEquipSlotByTypeAndVariant(
            uint miladyId, 
            uint128 accType, 
            uint128 accVariantOrNull)
        internal
    {
        if (accVariantOrNull == 0) {
            _unequipAccessoryByTypeIfEquipped(miladyId, accType);
        }
        else {
            uint accessoryId = AccessoryUtils.typeAndVariantHashesToId(accType, accVariantOrNull);
            _equipAccessoryIfOwned(miladyId, accessoryId);
        }
    }

    function equipAccessory(uint _miladyId, uint _accessoryId)
        public
    {
        require(msg.sender == ownerOf(_miladyId), "Not Milday owner");
        require(
            liquidAccessoriesContract.balanceOf(address(avatarTBA), _accessoryId) > 0
         || soulboundAccessoriesContract.balanceOf(address(avatarTBA), _accessoryId) > 0,
            "Unowned accessory"
        );

        (uint128 accType, uint128 accVariant) = AccessoryUtils.idToTypeAndVariantHashes(_accessoryId);

        if (accVariant != 0)
        {
            // equipSlots[miladyId][accType] = 0; // implied
            emit AccessoryUnequipped(miladyId, equipSlots[miladyId][accType]);
            equipSlots[miladyId][accType] = accVariant;
            emit AccessoryEquipped(miladyId, equipSlots[miladyId][accType]);
            rewardsContract.registerMiladyForRewardsForAccessoryAndClaim(_miladyId, _accessoryId);
        }
        else
        {
            equipSlots[miladyId][accType] = 0;
            emit AccessoryUnequipped(miladyId, equipSlots[miladyId][accType]);
            rewardsContract.deregisterMiladyForRewardsForAccessoryAndClaim(_miladyId, _accessoryId);
        }
    }

    function equipAccessories(uint _miladyId, uint[] memory _accessoryIds)
        public
    {
        // Logan <| This is not gas efficient but greatly reduces the complexity of the code
        // Logan <| The gas wins here are limited anyways due to registering and deregistering for rewards
        for (uint i=0; i<_accessoryIds.length; i++) {
            equipAccessory(_miladyId, _accessoryIds[i]);
        }
    }

    event AccessoryEquipped(uint miladyId, uint accessoryId);

    // core function for equip logic.
    // Unequips items if equip would overwrite for that accessory type
    function _equipAccessoryIfOwned(uint _miladyId, uint _accessoryId)
        internal
    {
        address avatarTBA = getAvatarTBA(_miladyId);

        require(
            liquidAccessoriesContract.balanceOf(address(avatarTBA), _accessoryId) > 0
         || soulboundAccessoriesContract.balanceOf(address(avatarTBA), _accessoryId) > 0,
            "Unowned accessory"
        );

        (uint128 accType,) = AccessoryUtils.idToTypeAndVariantHashes(_accessoryId);

        _unequipAccessoryByTypeIfEquipped(miladyId, accType);
        rewardsContract.registerMiladyForRewardsForAccessory(_miladyId, _accessoryId);

        equipSlots[miladyId][accType] = _accessoryId;

        emit AccessoryEquipped(_miladyId, _accessoryId);
    }

    event AccessoryUnequipped(uint miladyId, uint accessoryId);

    // core function for unequip logic
    function _unequipAccessoryByTypeIfEquipped(uint miladyId, uint128 accType)
        internal
    {
        if (equipSlots[miladyId][accType] != 0) {
            rewardsContract.deregisterMiladyForRewardsForAccessoryAndClaim(miladyId, equipSlots[miladyId][accType], getPayableAvatarTBA(miladyId));

            emit AccessoryUnequipped(miladyId, equipSlots[miladyId][accType]);

            equipSlots[miladyId][accType] = 0;
        }
    }

    function preTransferUnequipById(uint miladyId, uint accessoryId)
        external
    {
        require(msg.sender == address(liquidAccessoriesContract), "msg.sender not liquidAccessories contract");

        (uint128 accType, ) = AccessoryUtils.idToTypeAndVariantHashes(accessoryId);

        _unequipAccessoryByTypeIfEquipped(miladyId, accType);
    }

    // Get the TokenGatedAccount for a particular Milady Avatar.
    function getAvatarTBA(uint miladyId)
        public
        view
        returns (address)
    {
        return tbaRegistry.account(address(tbaAccountImpl), block.chainid, address(this), miladyId, 0);
    }

    function getPayableAvatarTBA(uint miladyId)
        public
        view
        returns (address payable)
    {
        return payable(getAvatarTBA(miladyId));
    }

    // todo: needs uri function?

    // perfunctory
        function name() external pure returns (string memory) {
        return "Milady Avatar";
    }

    function symbol() external pure returns (string memory) {
        return "MILA";
    }

    function tokenURI(uint256 tokenId) 
        external 
        view 
        returns (string memory) 
    {
        require(tokenId <= 9999, "Invalid Milady/Avatar id");

        return string(abi.encodePacked(baseURI, Strings.toString(tokenId)));
    }

    function balanceOf(address who) 
        external 
        view 
        returns 
        (uint256 balance) 
    {
        (address tbaContractAddress,) = tbaRegistry.registeredAccounts(who);
        if (tbaContractAddress == address(miladysContract)) {
            return 1;
        }
        else return 0;
    }

    function ownerOf(uint256 tokenId) 
        public 
        view 
        returns (address owner) 
    {
        require(tokenId <= 9998, "Invalid Milady/Avatar id");

        return tbaRegistry.account(address(tbaAccountImpl), chainId, address(miladysContract), tokenId, 0);
    }

    function safeTransferFrom(address, address, uint256, bytes calldata) external {
        revertWithSoulboundMessage();
    }
    
    function safeTransferFrom(address, address, uint256) external {
        revertWithSoulboundMessage();
    }

    function transferFrom(address, address, uint256) external {
        revertWithSoulboundMessage();
    }

    function approve(address, uint256) external {
        revertWithSoulboundMessage();
    }

    function setApprovalForAll(address, bool) external {
        revertWithSoulboundMessage();
    }

    function getApproved(uint256) external view returns (address operator) {
        revertWithSoulboundMessage();
    }

    function isApprovedForAll(address, address) external view returns (bool) {
        return false;
    }

    function revertWithSoulboundMessage() pure internal {
        revert("Cannot transfer soulbound tokens");
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC721).interfaceId;
    }
}