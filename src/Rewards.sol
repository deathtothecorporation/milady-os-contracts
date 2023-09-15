// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "openzeppelin/access/AccessControl.sol";
import "openzeppelin/token/ERC721/IERC721.sol";

contract Rewards is AccessControl {
    bytes32 constant ROLE_REWARD_REGISTRATION = keccak256("REWARD_REGISTRATION");

    IERC721 miladysContract;

    constructor(address miladyAvatarContractAddress, IERC721 _miladysContract) {
        _grantRole(ROLE_REWARD_REGISTRATION, miladyAvatarContractAddress);
        miladysContract = _miladysContract;
    }

    mapping (uint => RewardInfoForAccessory) public rewardInfoForAccessory;
    struct RewardInfoForAccessory {
        uint totalRewardsAccrued;
        uint totalHolders;
        mapping (uint => MiladyRewardInfo) miladyRewardInfo;
    }
    struct MiladyRewardInfo {
        bool isRegistered;
        uint amountClaimedBeforeDivision;
    }

    function accrueRewards(uint accessoryId)
        payable
        external
    {
        require(msg.value > 0, "call must include some ether");

        rewardInfoForAccessory[accessoryId].totalRewardsAccrued += msg.value;
    }

    function registerMiladyForRewardsForAccessory(uint miladyId, uint accessoryId)
        external
        onlyRole(ROLE_REWARD_REGISTRATION)
    {
        MiladyRewardInfo storage miladyRewardInfo = rewardInfoForAccessory[accessoryId].miladyRewardInfo[miladyId];

        require(! miladyRewardInfo.isRegistered, "Milady is already registered.");

        // When a new Milady is registered, we pretend they've been here the whole time and have already claimed all they could.
        // This essentially starts out this Milady with 0 claimable rewards, which will go up as revenue increases.
        miladyRewardInfo.amountClaimedBeforeDivision = rewardInfoForAccessory[accessoryId].totalRewardsAccrued;
        rewardInfoForAccessory[accessoryId].totalHolders ++;

        miladyRewardInfo.isRegistered = true;
    }

    function deregisterMiladyForRewardsForAccessoryAndClaim(uint miladyId, uint accessoryId)
        external
        onlyRole(ROLE_REWARD_REGISTRATION)
    {
        MiladyRewardInfo storage miladyRewardInfo = rewardInfoForAccessory[accessoryId].miladyRewardInfo[miladyId];

        require(miladyRewardInfo.isRegistered, "Milady is not registered.");

        _claimRewardsForMiladyForAccessory(miladyId, accessoryId);

        rewardInfoForAccessory[accessoryId].totalHolders --;

        miladyRewardInfo.isRegistered = false;
    }

    function claimRewardsForMilady(uint miladyId, uint[] calldata accessoriesToClaimFor)
        external
    {
        require(msg.sender == miladysContract.ownerOf(miladyId), "Only callable by the owner of the Milady");

        for (uint i=0; i<accessoriesToClaimFor.length; i++) {
            _claimRewardsForMiladyForAccessory(miladyId, accessoriesToClaimFor[i]);
        }
    }

    function _claimRewardsForMiladyForAccessory(uint miladyId, uint accessoryId)
        internal
    {
        RewardInfoForAccessory storage rewardInfo = rewardInfoForAccessory[accessoryId];

        uint rewardOwedBeforeDivision = rewardInfo.totalRewardsAccrued - rewardInfo.miladyRewardInfo[miladyId].amountClaimedBeforeDivision;

        uint amountToSend = getAmountClaimableForMiladyAndAccessory(miladyId, accessoryId);

        //todo: maybe send to the Milady's TBA instead?
        address recipient = miladysContract.ownerOf(miladyId);

        //todo: RE-ENTRANCY ISSUE
        //todo: should we really be working around this issue?
        (bool success, ) = recipient.call{value: amountToSend}("");
        require(success, "Reward transfer failed");

        rewardInfo.miladyRewardInfo[miladyId].amountClaimedBeforeDivision += rewardOwedBeforeDivision;
    }

    function getAmountClaimableForMiladyAndAccessory(uint miladyId, uint accessoryId)
        public
        view
        returns (uint amountClaimable)
    {
        RewardInfoForAccessory storage rewardInfo = rewardInfoForAccessory[accessoryId];
        
        //todo: possible DRY cleanup with this and the beginning of claimRewardsForMiladyAndAccessory
        uint rewardOwedBeforeDivision = rewardInfo.totalRewardsAccrued - rewardInfo.miladyRewardInfo[miladyId].amountClaimedBeforeDivision;

        amountClaimable = rewardOwedBeforeDivision / rewardInfo.totalHolders;
    }
}