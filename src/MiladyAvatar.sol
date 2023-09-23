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
    TBARegistry tbaRegistry;
    IERC6551Account tbaAccountImpl;
    uint chainId;

    string baseURI;

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

    function setOtherContracts(LiquidAccessories _liquidAccessoriesContract, SoulboundAccessories _soulboundAccessoriesContract, Rewards _rewardsContract)
        external
    {
        require(msg.sender == deployer, "Only callable by the initial deployer");
        require(address(liquidAccessoriesContract) == address(0), "Contracts already set");
        
        liquidAccessoriesContract = _liquidAccessoriesContract;
        soulboundAccessoriesContract = _soulboundAccessoriesContract;
        rewardsContract = _rewardsContract;
    }

    function name() external pure returns (string memory) {
        return "Milady Avatar";
    }

    function symbol() external pure returns (string memory) {
        return "MILA";
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(tokenId <= 9999, "Invalid Milady/Avatar id");

        return string(abi.encodePacked(baseURI, Strings.toString(tokenId)));
    }

    function balanceOf(address who) external view returns (uint256 balance) {
        (address tbaContractAddress,) = tbaRegistry.registeredAccounts(who);
        if (tbaContractAddress == address(miladysContract)) {
            return 1;
        }
        else return 0;
    }
    function ownerOf(uint256 tokenId) public view returns (address owner) {
        require(tokenId <= 9999, "Invalid Milady/Avatar id");

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
        revert("Milady Avatars cannot be moved from their soulbound Milady.");
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC721).interfaceId;
    }

    // each avatar has equip slots for each accessory type
    mapping (uint => mapping (uint128 => uint)) public equipSlots;

    // A special function to allow the soulbound accessories to "auto equip" themselves upon mint
    // See `SoulboundAccessories.mintSoulboundAccessories`.
    function equipSoulboundAccessory(uint miladyId, uint accessoryId)
        public
    {
        require(msg.sender == address(soulboundAccessoriesContract), "not called by SoulboundAccessories");

        _equipAccessoryIfOwned(miladyId, accessoryId);
    }

    // batch version of the previous function
    function equipSoulboundAccessories(uint miladyId, uint[] calldata accessoryIds)
        external
    {
        require(msg.sender == address(soulboundAccessoriesContract), "not called by SoulboundAccessories");

        for (uint i=0; i<accessoryIds.length; i++) {
            _equipAccessoryIfOwned(miladyId, accessoryIds[i]);
        }
    }

    // Allows the owner of the avatar to equip an accessory.
    // The accessory must be held in the avatar's TBA.
    // If some other accessory is equipped with the same accType, it will be unequipped.
    function equipAccessory(uint miladyId, uint accessoryId)
        public
    {
        // note: this effectively checks that the msg.sender is the avatar.
        // thus we are assuming that the interface is constructing a TBA call.
        require(msg.sender == ownerOf(miladyId), "You don't own that Milady Avatar");

        _equipAccessoryIfOwned(miladyId, accessoryId);
    }

    // batch version of the previous function
    function equipAccessories(uint miladyId, uint[] memory accessoryIds)
        external
    {
        require(msg.sender == ownerOf(miladyId), "You don't own that Milady Avatar");

        for (uint i=0; i<accessoryIds.length; i++) {
            _equipAccessoryIfOwned(miladyId, accessoryIds[i]);
        }
    }

    function _equipAccessoryIfOwned(uint miladyId, uint accessoryId)
        internal
    {
        address avatarTBA = getAvatarTBA(miladyId);

        require(
            liquidAccessoriesContract.balanceOf(address(avatarTBA), accessoryId) > 0
         || soulboundAccessoriesContract.balanceOf(address(avatarTBA), accessoryId) > 0,
            "That avatar does not own that accessory."
        );

        (uint128 accType,) = AccessoryUtils.idToTypeAndVariantHashes(accessoryId);

        _unequipAccessoryByTypeIfEquipped(miladyId, accType);
        rewardsContract.registerMiladyForRewardsForAccessory(miladyId, accessoryId);

        equipSlots[miladyId][accType] = accessoryId;
    }

    function unequipAccessoryByIdIfEquipped(uint miladyId, uint accessoryId)
        external
    {
        require(msg.sender == address(liquidAccessoriesContract) || msg.sender == ownerOf(miladyId));

        (uint128 accType,) = AccessoryUtils.idToTypeAndVariantHashes(accessoryId);

        unequipAccessoryByTypeIfEquipped(miladyId, accType);
    }

    function unequipAccessoryByTypeIfEquipped(uint miladyId, uint128 accType)
        public
    {
        require(msg.sender == ownerOf(miladyId), "You don't own that Milady Avatar");

        _unequipAccessoryByTypeIfEquipped(miladyId, accType);
    }

    // batch version of previous function
    function unequipAccessoriesByTypeIfEquipped(uint miladyId, uint128[] memory accTypes)
        public
    {
        require(msg.sender == ownerOf(miladyId), "You don't own that Milady Avatar");

        for (uint i=0; i<accTypes.length; i++) {
            _unequipAccessoryByTypeIfEquipped(miladyId, accTypes[i]);
        }
    }

    function _unequipAccessoryByTypeIfEquipped(uint miladyId, uint128 accType)
        internal
    {
        if (equipSlots[miladyId][accType] != 0) {
            rewardsContract.deregisterMiladyForRewardsForAccessoryAndClaim(miladyId, equipSlots[miladyId][accType], getPayableAvatarTBA(miladyId));
            equipSlots[miladyId][accType] = 0;
        }
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
}