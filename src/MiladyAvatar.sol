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
    
    // main entry point for a user to change their Avatar's appearance / equip status
    // If an accessoryId's unpacked accVariant == 0, we interpret this as an unequip action
    function updateEquipSlotsByAccessoryIds(uint _miladyId, uint[] memory _accessoryIds)
        public
    {
        require(msg.sender == ownerOf(_miladyId), "Not Milday TBA");

        for (uint i=0; i<_accessoryIds.length; i++) {
            (uint128 accType, uint128 accVariant) = AccessoryUtils.idToTypeAndVariantHashes(_accessoryIds[i]);

            _updateEquipSlotByTypeAndVariant(_miladyId, accType, accVariant);
        }
    }

    function _updateEquipSlotByTypeAndVariant(uint _miladyId, uint128 _accType, uint128 _accVariantOrNull)
        internal
    {
        if (_accVariantOrNull == 0) {
            _unequipAccessoryByTypeIfEquipped(_miladyId, _accType);
        }
        else {
            uint accessoryId = AccessoryUtils.typeAndVariantHashesToId(_accType, _accVariantOrNull);
            _equipAccessoryIfOwned(_miladyId, accessoryId);
        }
    }

    event AccessoryEquipped(uint indexed _miladyId, uint indexed _accessoryId);

    // core function for equip logic.
    // Unequips items if equip would overwrite for that accessory type
    function _equipAccessoryIfOwned(uint _miladyId, uint _accessoryId)
        internal
    {
        address avatarTBA = getAvatarTBA(_miladyId);

        require(
            liquidAccessoriesContract.balanceOf(address(avatarTBA), _accessoryId) > 0
         || soulboundAccessoriesContract.balanceOf(address(avatarTBA), _accessoryId) > 0,
            "Not accessory owner"
        );

        (uint128 accType, uint accVariant) = AccessoryUtils.idToTypeAndVariantHashes(_accessoryId);
        assert(accVariant != 0); // take out for gas savings?

        _unequipAccessoryByTypeIfEquipped(_miladyId, accType);
        rewardsContract.registerMiladyForRewardsForAccessory(_miladyId, _accessoryId);

        equipSlots[_miladyId][accType] = _accessoryId;

        emit AccessoryEquipped(_miladyId, _accessoryId);
    }

    event AccessoryUnequipped(uint indexed _miladyId, uint indexed _accessoryId);

    // core function for unequip logic
    function _unequipAccessoryByTypeIfEquipped(uint _miladyId, uint128 _accType)
        internal
    {
        if (equipSlots[_miladyId][_accType] != 0) { // if "something" is equiped
            rewardsContract.deregisterMiladyForRewardsForAccessoryAndClaim(_miladyId, equipSlots[_miladyId][_accType], getPayableAvatarTBA(_miladyId));

            emit AccessoryUnequipped(_miladyId, equipSlots[_miladyId][_accType]);

            equipSlots[_miladyId][_accType] = 0;
        }
    }

    // Allows soulbound accessories to "auto equip" themselves upon mint
    // See `SoulboundAccessories.mintSoulboundAccessories`.
    function equipSoulboundAccessories(uint _miladyId, uint[] calldata _accessoryIds)
        external
    {
        require(msg.sender == address(soulboundAccessoriesContract), "Not soulboundAccessories");

        for (uint i=0; i<_accessoryIds.length; i++) {
            _equipAccessoryIfOwned(_miladyId, _accessoryIds[i]);
        }
    }

    // Allows liquid accessoires to "auto unequip" themselves upon transfer away
    // See `LiquidAccessories._beforeTokenTransfer`.
    function preTransferUnequipById(uint _miladyId, uint _accessoryId)
        external
    {
        require(msg.sender == address(liquidAccessoriesContract), "Not liquidAccessoriesContract");

        (uint128 accType, ) = AccessoryUtils.idToTypeAndVariantHashes(_accessoryId);

        _unequipAccessoryByTypeIfEquipped(_miladyId, accType);
    }

    // Get the TokenGatedAccount for a particular Milady Avatar.
    function getAvatarTBA(uint _miladyId)
        public
        view
        returns (address)
    {
        return tbaRegistry.account(address(tbaAccountImpl), block.chainid, address(this), _miladyId, 0);
    }

    function getPayableAvatarTBA(uint _miladyId)
        public
        view
        returns (address payable)
    {
        return payable(getAvatarTBA(_miladyId));
    }

    function name() external pure returns (string memory) {
        return "Milady Avatar";
    }

    function symbol() external pure returns (string memory) {
        return "MILA";
    }

    function tokenURI(uint256 _tokenId) 
        external 
        view 
        returns (string memory) 
    {
        require(_tokenId <= 9998, "Invalid Milady/Avatar id");

        return string(abi.encodePacked(baseURI, Strings.toString(_tokenId)));
    }

    function balanceOf(address _who) 
        external 
        view 
        returns 
        (uint256 balance) 
    {
        (address tbaContractAddress,) = tbaRegistry.registeredAccounts(_who);
        if (tbaContractAddress == address(miladysContract)) {
            return 1;
        }
        else return 0;
    }

    function ownerOf(uint256 _tokenId) 
        public 
        view 
        returns (address owner) 
    {
        require(_tokenId <= 9999, "Invalid Milady/Avatar id");

        return tbaRegistry.account(address(tbaAccountImpl), chainId, address(miladysContract), _tokenId, 0);
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

    function getApproved(uint256) external view returns (address) {
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