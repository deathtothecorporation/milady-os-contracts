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

    function equipAccessory(uint _miladyId, uint _accessoryId)
        public
    {
        require(msg.sender == ownerOf(_miladyId), "Not Milday owner");
        _equipAccessory(_miladyId, _accessoryId);
    }

    function _equipAccessory(uint _miladyId, uint _accessoryId)
        internal
    {
        address payable avatarTBA = payable(getAvatarTBA(_miladyId));
        (uint128 accType, uint128 accVariant) = AccessoryUtils.idToTypeAndVariantHashes(_accessoryId);

        if (accVariant != 0)
        {
            require(
                liquidAccessoriesContract.balanceOf(avatarTBA, _accessoryId) > 0
             || soulboundAccessoriesContract.balanceOf(avatarTBA, _accessoryId) > 0,
                "Unowned accessory"
            );
            // equipSlots[_miladyId][accType] = 0; // implied
            emit AccessoryUnequipped(_miladyId, equipSlots[_miladyId][accType]);
            equipSlots[_miladyId][accType] = accVariant;
            emit AccessoryEquipped(_miladyId, equipSlots[_miladyId][accType]);
            rewardsContract.registerMiladyForRewardsForAccessory(_miladyId, _accessoryId);
        }
        else
        {
            equipSlots[_miladyId][accType] = 0;
            emit AccessoryUnequipped(_miladyId, equipSlots[_miladyId][accType]);
            rewardsContract.deregisterMiladyForRewardsForAccessoryAndClaim(_miladyId, _accessoryId, avatarTBA);
        }
    }

    // replaces updateEquipSlotsByAccessoryIds
    function equipAccessories(uint _miladyId, uint[] calldata _accessoryIds)
        external
    {
        require(msg.sender == ownerOf(_miladyId), "Not Milday owner");
        _equipAccessories(_miladyId, _accessoryIds);
    }

    function _equipAccessories(uint _miladyId, uint[] calldata _accessoryIds)
        internal
    {
        for (uint i=0; i<_accessoryIds.length; i++) 
        {
            _equipAccessory(_miladyId, _accessoryIds[i]);
        }
    }

    function equipAccessoriesAsSoulboundAccessories(uint _miladyId, uint[] calldata _accessoryIds)
        external
    {
        require(msg.sender == address(soulboundAccessoriesContract), "Not SoulboundAccessories contract");
        _equipAccessories(_miladyId, _accessoryIds);
    }

    event AccessoryEquipped(uint miladyId, uint accessoryId);

    event AccessoryUnequipped(uint miladyId, uint accessoryId);

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