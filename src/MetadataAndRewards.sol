// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "openzeppelin/utils/math/SafeMath.sol";
import "openzeppelin/token/ERC721/ERC721.sol";
import "openzeppelin/token/ERC721/IERC721.sol";
import "openzeppelin/access/AccessControl.sol";
import "./Constants.sol";

// todo: this contract is designed with no conception of "accessory types"; i.e.
// purple hats, red hats, and blue necklaces are all in the same "bucket".
// This could be changed trivially, which may be better,
// since we are uploading the accessories at this stage - there is an argument for completeness.

contract MiladyAccessoriesAndRewards is AccessControl {
    bytes32 constant ROLE_MILADY_AUTHORITY = keccak256("MILADY_AUTHORITY");

    IERC721 miladyContract;

    constructor(IERC721 _miladyContract, address miladyAuthority) {
        miladyContract = _miladyContract;
        _grantRole(ROLE_MILADY_AUTHORITY, miladyAuthority);
    }

    // using uint16 to specify a particular item (i.e. "purple hat").
    // This is packed/unpacked to two uint8s, one for type and one for variant ("purple", "hat")

    mapping (uint16 => RewardInfoForAccessory) public rewardInfoForAccessory;
    struct RewardInfoForAccessory {
        uint totalRewardsAccrued;
        uint totalHolders;
        mapping (uint => MiladyRewardInfo) miladyRewardInfo;
    }
    struct MiladyRewardInfo {
        bool isRegistered;
        uint amountClaimedBeforeDivision;
    }

    mapping (uint => uint16[NUM_ACCESSORY_TYPES]) public miladyAccessoryInfo;

    function onboardMilady(uint miladyID, uint16[NUM_ACCESSORY_TYPES] calldata accessories)
        onlyRole(ROLE_MILADY_AUTHORITY)
        external
    {
        uint16[NUM_ACCESSORY_TYPES] storage accessoryInfo = miladyAccessoryInfo[miladyID];

        for (uint i=0; i<NUM_ACCESSORY_TYPES; i++)
        {
            // set milady -> accessories association
            accessoryInfo[i] = accessories[i];

            // add accessory -> milady association
            MiladyRewardInfo storage miladyRewardInfo = rewardInfoForAccessory[accessories[i]].miladyRewardInfo[miladyID];

            require(! miladyRewardInfo.isRegistered, "milady has already been initialized");

            miladyRewardInfo.isRegistered = true;

            // When a new Milady is registered, we pretend they've been here the whole time and have already claimed all they could.
            // This essentially starts out this Milady with 0 claimable rewards, which will go up as revenue increases.
            miladyRewardInfo.amountClaimedBeforeDivision = rewardInfoForAccessory[accessories[i]].totalRewardsAccrued;
            rewardInfoForAccessory[accessories[i]].totalHolders ++;
        }
    }

    function numAccessoryHolders(uint16 accessory)
        external
        view
        returns (uint numHolders)
    {
        return rewardInfoForAccessory[accessory].totalHolders;
    }

    function receiveRewardsForAccessory(uint16 accessory)
        external
        payable
    {
        // todo: what if there aren't any miladys registered yet to receive the reward?
        rewardInfoForAccessory[accessory].totalRewardsAccrued += msg.value;
    }

    function claimRewardsForMilady(uint miladyID)
        external
    {
        require(miladyContract.ownerOf(miladyID) == msg.sender, "You don't own that Milady");

        uint16[NUM_ACCESSORY_TYPES] storage accessoryInfo = miladyAccessoryInfo[miladyID];

        for (uint i=0; i<NUM_ACCESSORY_TYPES; i++) {
            claimRewardsForMiladyAndAccessory(miladyID, accessoryInfo[i]);
        }
    }

    function claimRewardsForMiladyAndAccessory(uint miladyID, uint16 accessory)
        internal
    {
        RewardInfoForAccessory storage rewardInfo = rewardInfoForAccessory[accessory];
        
        uint rewardOwedBeforeDivision = SafeMath.sub(rewardInfo.totalRewardsAccrued, rewardInfo.miladyRewardInfo[miladyID].amountClaimedBeforeDivision);

        uint amountToSend = getAmountClaimableForMiladyAndAccessory(miladyID, accessory);

        //todo: maybe send to the Milady's TBA instead?
        address recipient = miladyContract.ownerOf(miladyID);

        //todo: should we be working around this?
        (bool success, ) = recipient.call{value: amountToSend}("");
        require(success, "Reward transfer failed");

        rewardInfo.miladyRewardInfo[miladyID].amountClaimedBeforeDivision += rewardOwedBeforeDivision;
    }

    function getAmountClaimableForMilady(uint miladyID)
        public
        view
        returns(uint totalClaimable)
    {
        uint16[NUM_ACCESSORY_TYPES] storage accessoryInfo = miladyAccessoryInfo[miladyID];

        for (uint i=0; i<NUM_ACCESSORY_TYPES; i++)
        {
            totalClaimable += getAmountClaimableForMiladyAndAccessory(miladyID, accessoryInfo[i]);
        }
    }

    function getAmountClaimableForMiladyAndAccessory(uint miladyID, uint16 accessory)
        public
        view
        returns (uint amountClaimable)
    {
        RewardInfoForAccessory storage rewardInfo = rewardInfoForAccessory[accessory];
        
        //todo: possible DRY cleanup with this and the beginning of claimRewardsForMiladyAndAccessory
        uint rewardOwedBeforeDivision = SafeMath.sub(rewardInfo.totalRewardsAccrued, rewardInfo.miladyRewardInfo[miladyID].amountClaimedBeforeDivision);

        amountClaimable = SafeMath.div(rewardOwedBeforeDivision, rewardInfo.totalHolders);
    }
}