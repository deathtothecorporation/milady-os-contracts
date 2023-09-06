// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC721/IERC721.sol";
import "openzeppelin/utils/math/SafeMath.sol";
import "./TBA/TokenBasedAccount.sol";
import "./TBA/IERC6551Registry.sol";
import "./TBA/IERC6551Account.sol";
import "./Interfaces.sol";
import "./AccessoryUtils.sol";
import "./LiquidAccessories.sol";

contract MiladyAvatar is IERC721, IMiladyAvatar {
    IERC721 public miladysContract;
    LiquidAccessories public liquidAccessoriesContract;
    
    // state needed for TBA determination
    IERC6551Registry tbaRegistry;
    IERC6551Account tbaAccountImpl;
    uint chainId;

    constructor(IERC721 _miladysContract, LiquidAccessories _liquidAccessoriesContract, IERC6551Registry _tbaRegistry, IERC6551Account _tbaAccountImpl, uint _chainId) {
        miladysContract = _miladysContract;
        liquidAccessoriesContract = _liquidAccessoriesContract;
        
        tbaRegistry = _tbaRegistry;
        tbaAccountImpl = _tbaAccountImpl;
        chainId = _chainId;
    }

    function balanceOf(address) external view returns (uint256 balance) {
        return 0;
    }
    function ownerOf(uint256 tokenId) public view returns (address owner) {
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
        revert("Milady Dolls cannot be moved from their soulbound Milady.");
    }
    function isApprovedForAll(address, address) external view returns (bool) {
        return false;
    }
    function revertWithSoulboundMessage() pure internal {
        revert("Milady Dolls cannot be moved from their soulbound Milady.");
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC721).interfaceId;
    }

    // each avatar has equip slots for each accessory type
    mapping (uint => mapping (uint128 => bool)) public equipSlots;

    // Allows the owner of the avatar to equip an accessory.
    // The accessory must be held in the avatar's TBA.
    // If some other accessory is equipped with the same accType, it will be ovewritten (unequipped).
    function equipAccessory(uint miladyId, uint accessoryId)
        public
    {
        // note: this effectively checks that the msg.sender is the avatar.
        // thus we are assuming that the interface is constructing a TBA call.
        require(msg.sender == ownerOf(miladyId), "You don't own that Milady Avatar");
        
        address avatarTBA = getAvatarTBA(miladyId);

        require(liquidAccessoriesContract.ownerOf(accessoryId) == address(avatarTBA), "That doll does not own that accessory.");

        (uint128 accType,) = AccessoryUtils.idToTypeAndVariant(accessoryId);

        equipSlots[accType] = accessoryId;
    }

    function unequipAccessoryByType(uint miladyId, uint128 accType)
        public
    {
        require(msg.sender == ownerOf(miladyId), "You don't own that Milady Avatar");

        //todo: doc that 0 indicates no item, because hashes
        equipSlots[accType] = 0;
    }

    function unequipAccessoryById(uint miladyId, uint accessoryId)
        external
        override
    {
        require(msg.sender == liquidAccessoriesContract || msg.sender == ownerOf(miladyId));

        (uint128 accType,) = AccessoryUtils.idToTypeAndVariant(accessoryId);

        unequipAccessoryByType(miladyId, accType);
    }

    // Get the TokenBasedAccount for a particular Milady Avatar.
    function getAvatarTBA(uint miladyId)
        public
        view
        returns (address)
    {
        return tbaRegistry.account(address(tbaAccountImpl), block.chainid, address(this), miladyId, 0);
    }

    // todo: needs uri function?
}