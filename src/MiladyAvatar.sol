/* solhint-disable private-vars-leading-underscore */

pragma solidity 0.8.18;

import "openzeppelin/token/ERC721/IERC721.sol";
import "TokenGatedAccount/TokenGatedAccount.sol";
import "TokenGatedAccount/TGARegistry.sol";
import "./Rewards.sol";
import "./LiquidAccessories.sol";
import "./SoulboundAccessories.sol";

/// @title MiladyAvatar Contract
/// @notice A contract to manage Milady Avatars, including accessory equip/unequip actions.
contract MiladyAvatar is IERC721 {
    IERC721 public immutable miladysContract;
    LiquidAccessories public liquidAccessoriesContract;
    SoulboundAccessories public soulboundAccessoriesContract;
    Rewards public rewardsContract;
    
    // state needed for TGA address calculation
    TGARegistry public immutable tgaRegistry;
    IERC6551Account public immutable tgaAccountImpl;

    string public baseURI;

    address immutable initialDeployer;

    /** 
     * @dev Sets initial state for the contract.
     * @param _miladysContract Address of the Milady's ERC721 contract.
     * @param _tgaRegistry Address of the TokenGatedAccount registry contract.
     * @param _tgaAccountImpl Address of the TokenGatedAccount implementation contract.
     * @param _baseURI The base URI for the ERC721 token metadata.
     */
    constructor(
            IERC721 _miladysContract,
            TGARegistry _tgaRegistry,
            TokenGatedAccount _tgaAccountImpl,
            string memory _baseURI
    ) {
        initialDeployer = msg.sender;
        miladysContract = _miladysContract;
        tgaRegistry = _tgaRegistry;
        tgaAccountImpl = _tgaAccountImpl;
        baseURI = _baseURI;
    }

    /** 
     * @notice Sets other required contracts for the MiladyAvatar to function properly.
     * @dev This function is callable only once and only by the initial deployer.
     * @param _liquidAccessoriesContract The LiquidAccessories contract address.
     * @param _soulboundAccessoriesContract The SoulboundAccessories contract address.
     * @param _rewardsContract The Rewards contract address.
     */
    function setOtherContracts(
            LiquidAccessories _liquidAccessoriesContract, 
            SoulboundAccessories _soulboundAccessoriesContract, 
            Rewards _rewardsContract)
        external
    {
        require(msg.sender == initialDeployer, "Caller not initial deployer");
        require(address(liquidAccessoriesContract) == address(0), "Contracts already set");
        
        liquidAccessoriesContract = _liquidAccessoriesContract;
        soulboundAccessoriesContract = _soulboundAccessoriesContract;
        rewardsContract = _rewardsContract;
    }

    // indexed by miladyId -> accessoryType
    mapping (uint => mapping (uint128 => uint)) public equipSlots;
    

    /** 
     * @notice Updates the equipped accessories for a Milady Avatar.
     * @dev A variant ID of 0 is interpreted as an unequip action.
     * @param _miladyId The ID of the Milady Avatar.
     * @param _accessoryIds Array of accessory IDs to equip or unequip.
     */
    // main entry point for a user to change their Avatar's appearance / equip status
    // if an accessoryId's unpacked accVariant == 0, we interpret this as an unequip action
    function updateEquipSlotsByAccessoryIds(uint _miladyId, uint[] memory _accessoryIds)
        public
    {
        require(msg.sender == ownerOf(_miladyId), "Not Milady TGA");

        for (uint i=0; i<_accessoryIds.length;) {
            (uint128 accType, uint128 accVariant) = accessoryIdToTypeAndVariantIds(_accessoryIds[i]);

            _updateEquipSlotByTypeAndVariant(_miladyId, accType, accVariant);

            unchecked { i++; }
        }
    }

    function _updateEquipSlotByTypeAndVariant(uint _miladyId, uint128 _accType, uint128 _accVariantOrNull)
        internal
    {
        if (_accVariantOrNull == 0) {
            _unequipAccessoryByTypeIfEquipped(_miladyId, _accType);
        }
        else {
            uint accessoryId = typeAndVariantIdsToAccessoryId(_accType, _accVariantOrNull);
            _equipAccessoryIfOwned(_miladyId, accessoryId);
        }
    }

    event AccessoryEquipped(uint indexed _miladyId, uint indexed _accessoryId);

    // core function for equip logic.
    // unequips items if equip would overwrite for that accessory type
    // assumes the accessory's accVariant != 0
    function _equipAccessoryIfOwned(uint _miladyId, uint _accessoryId)
        internal
    {
        require(totalAccessoryBalanceOfAvatar(_miladyId, _accessoryId) > 0, "Not accessory owner");

        (uint128 accType, uint accVariant) = accessoryIdToTypeAndVariantIds(_accessoryId);
        require(accVariant != 0);

        _unequipAccessoryByTypeIfEquipped(_miladyId, accType);

        equipSlots[_miladyId][accType] = _accessoryId;
        
        rewardsContract.registerMiladyForRewardsForAccessory(_miladyId, _accessoryId);

        emit AccessoryEquipped(_miladyId, _accessoryId);
    }

    event AccessoryUnequipped(uint indexed _miladyId, uint indexed _accessoryId);

    // core function for unequip logic
    function _unequipAccessoryByTypeIfEquipped(uint _miladyId, uint128 _accType)
        internal
    {
        // if "something" is equiped in this slot
        if (equipSlots[_miladyId][_accType] != 0) { 
            rewardsContract.deregisterMiladyForRewardsForAccessoryAndClaim(_miladyId, equipSlots[_miladyId][_accType], getPayableAvatarTGA(_miladyId));

            emit AccessoryUnequipped(_miladyId, equipSlots[_miladyId][_accType]);

            equipSlots[_miladyId][_accType] = 0;
        }
    }

    /** 
     * @notice This function lets soulbound accessories automatically equip themselves upon minting.
     * @dev Function is intended to be called from the `SoulboundAccessories` contract.
     * @param _miladyId The ID of the Milady Avatar.
     * @param _accessoryIds Array of accessory IDs to equip.
     */
    // allows soulbound accessories to "auto equip" themselves upon mint
    // see `SoulboundAccessories.mintAndEquipSoulboundAccessories`
    function equipSoulboundAccessories(uint _miladyId, uint[] calldata _accessoryIds)
        external
    {
        require(msg.sender == address(soulboundAccessoriesContract), "Not soulboundAccessories");

        for (uint i=0; i<_accessoryIds.length;) {
            _equipAccessoryIfOwned(_miladyId, _accessoryIds[i]);

            unchecked { i++; }
        }
    }

    /** 
     * @notice This function lets soulbound accessories unequip themselves upon unmint.
     * @dev Function is intended to be called from the `SoulboundAccessories` contract.
     * @param _miladyId The ID of the Milady Avatar.
     * @param _accessoryIds Array of accessory IDs to unequip.
     */
    // allows soulbound accessories to unequip the item upon unmint
    // see `SoulboundAccessories.unmintAndUnequipSoulboundAccessories`
    function unequipSoulboundAccessories(uint _miladyId, uint[] calldata _accessoryIds)
        external
    {
        require(msg.sender == address(soulboundAccessoriesContract), "Not soulboundAccessories");

        for (uint i=0; i<_accessoryIds.length;) {
            _equipAccessoryIfOwned(_miladyId, _accessoryIds[i]);

            unchecked { i++; }
        }
    }

    /** 
     * @notice This function lets liquid accessories automatically unequip themselves before transferring.
     * @dev Intended to be called from the `LiquidAccessories` contract's `_beforeTokenTransfer` function.
     * @param _miladyId The ID of the Milady Avatar.
     * @param _accessoryId The accessory ID to unequip.
     */
    // allows liquid accessoires to "auto unequip" themselves upon transfer away
    // see `LiquidAccessories._beforeTokenTransfer`
    function preTransferUnequipById(uint _miladyId, uint _accessoryId)
        external
    {
        require(msg.sender == address(liquidAccessoriesContract), "Not liquidAccessoriesContract");

        (uint128 accType, ) = accessoryIdToTypeAndVariantIds(_accessoryId);

        _unequipAccessoryByTypeIfEquipped(_miladyId, accType);
    }


    function totalAccessoryBalanceOfAvatar(uint miladyId, uint accessoryId)
        public
        view
        returns(uint)
    {
        return
            liquidAccessoriesContract.balanceOf(getAvatarTGA(miladyId), accessoryId)
          + soulboundAccessoriesContract.balanceOf(getAvatarTGA(miladyId), accessoryId);
    }

    // get the TokenGatedAccount for a particular Milady Avatar.
    function getAvatarTGA(uint _miladyId)
        public
        view
        returns (address)
    {
        return tgaRegistry.account(address(tgaAccountImpl), block.chainid, address(this), _miladyId, 0);
    }

    function getPayableAvatarTGA(uint _miladyId)
        public
        view
        returns (address payable)
    {
        return payable(getAvatarTGA(_miladyId));
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
        (address tgaContractAddress,) = tgaRegistry.registeredAccounts(_who);
        if (tgaContractAddress == address(miladysContract)) {
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

        return tgaRegistry.account(address(tgaAccountImpl), block.chainid, address(miladysContract), _tokenId, 0);
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

    /// @dev This function is used internally to revert any calls attempting to transfer soulbound tokens.
    function revertWithSoulboundMessage() pure internal {
        revert("Cannot transfer soulbound tokens");
    }

    /** 
     * @notice Checks if the contract supports a given interface.
     * @param interfaceId The interface ID to check.
     * @return True if the interface is supported, false otherwise.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC721).interfaceId;
    }

    // accessory utils

    // the remaining functions describe the scheme whereby hashes (treated as IDs) of an accessory type and accessory variant
    // are encoded into the same uint256 that is used for a global ID for a particular accessory

    // an ID's upper 128 bits are the truncated hash of the category text;
    // the lower 128 bits are the truncated hash of the variant test

    /** 
     * @notice Calculates a unique identifier for accessories using their type and variant.
     * @dev This identifier is based on the truncated hashes of the accessory's type and variant.
     * @param accTypeString Text representation of the accessory type.
     * @param accVariantString Text representation of the accessory variant.
     * @return accessoryId The unique identifier for the accessory.
     */
    struct PlaintextAccessoryInfo {
        string accType;
        string accVariant;
    }

    function batchPlaintextAccessoryInfoToAccessoryIds(PlaintextAccessoryInfo[] memory accInfos)
        public
        pure
        returns (uint[] memory accIds)
    {
        accIds = new uint[](accInfos.length);
        for (uint i=0; i<accInfos.length;)
        {
            accIds[i] = plaintextAccessoryInfoToAccessoryId(accInfos[i]);

            unchecked { i++; }
        }
    }

    function plaintextAccessoryInfoToAccessoryId(PlaintextAccessoryInfo memory accInfo)
        public
        pure
        returns (uint accessoryId)
    {
        uint128 accType = uint128(uint256(keccak256(abi.encodePacked(accInfo.accType))));
        uint128 accVariant = uint128(uint256(keccak256(abi.encodePacked(accInfo.accVariant))));
        accessoryId = typeAndVariantIdsToAccessoryId(accType, accVariant);
    }

    function plaintextAccessoryTextToAccessoryId(string memory accTypeString, string memory accVariantString)
        public
        pure
        returns (uint accessoryId)
    {
        return plaintextAccessoryInfoToAccessoryId(PlaintextAccessoryInfo(accTypeString, accVariantString));
    }

    function accessoryIdToTypeAndVariantIds(uint id)
        public
        pure
        returns (uint128 accType, uint128 accVariant)
    {
        return (uint128(id >> 128), uint128(id));
    }

    function typeAndVariantIdsToAccessoryId(uint128 accType, uint128 accVariant)
        public
        pure
        returns (uint)
    {
        return (uint(accType) << 128) | uint(accVariant);
    }
}