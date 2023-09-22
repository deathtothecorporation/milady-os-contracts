// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC721/IERC721.sol";
import "./TBA/TBARegistry.sol";

contract Rewards {
    IERC721 public miladysContract;
    address public avatarContractAddress;

    constructor(address _avatarContractAddress, IERC721 _miladysContract) {
        avatarContractAddress = _avatarContractAddress;
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

    function accrueRewardsForAccessory(uint accessoryId)
        payable
        external
    {
        require(msg.value > 0, "call must include some ether");
        require(rewardInfoForAccessory[accessoryId].totalHolders > 0, "That accessory has no eligible recipients");

        rewardInfoForAccessory[accessoryId].totalRewardsAccrued += msg.value;
    }

    function registerMiladyForRewardsForAccessory(uint miladyId, uint accessoryId)
        external
        
    {
        require(msg.sender == avatarContractAddress, "msg.sender is not authorized to call this function.");
        
        MiladyRewardInfo storage miladyRewardInfo = rewardInfoForAccessory[accessoryId].miladyRewardInfo[miladyId];

        require(! miladyRewardInfo.isRegistered, "Milady is already registered.");

        // When a new Milady is registered, we pretend they've been here the whole time and have already claimed all they could.
        // This essentially starts out this Milady with 0 claimable rewards, which will go up as revenue increases.
        miladyRewardInfo.amountClaimedBeforeDivision = rewardInfoForAccessory[accessoryId].totalRewardsAccrued;
        rewardInfoForAccessory[accessoryId].totalHolders ++;

        miladyRewardInfo.isRegistered = true;
    }

    function deregisterMiladyForRewardsForAccessoryAndClaim(uint miladyId, uint accessoryId, address payable recipient)
        external
    {
        require(msg.sender == avatarContractAddress, "msg.sender is not authorized to call this function.");

        MiladyRewardInfo storage miladyRewardInfo = rewardInfoForAccessory[accessoryId].miladyRewardInfo[miladyId];

        require(miladyRewardInfo.isRegistered, "Milady is not registered.");

        _claimRewardsForMiladyForAccessory(miladyId, accessoryId, recipient);

        rewardInfoForAccessory[accessoryId].totalHolders --;

        miladyRewardInfo.isRegistered = false;
    }

    function claimRewardsForMilady(uint miladyId, uint[] calldata accessoriesToClaimFor, address payable recipient)
        external
    {
        require(msg.sender == miladysContract.ownerOf(miladyId), "Only callable by the owner of the Milady");

        for (uint i=0; i<accessoriesToClaimFor.length; i++) {
            _claimRewardsForMiladyForAccessory(miladyId, accessoriesToClaimFor[i], recipient);
        }
    }

    function _claimRewardsForMiladyForAccessory(uint miladyId, uint accessoryId, address payable recipient)
        internal
    {
        RewardInfoForAccessory storage rewardInfo = rewardInfoForAccessory[accessoryId];

        uint rewardOwedBeforeDivision = rewardInfo.totalRewardsAccrued - rewardInfo.miladyRewardInfo[miladyId].amountClaimedBeforeDivision;

        uint amountToSend = getAmountClaimableForMiladyAndAccessory(miladyId, accessoryId);

        rewardInfo.miladyRewardInfo[miladyId].amountClaimedBeforeDivision += rewardOwedBeforeDivision;

        // Schalk: Should we be doing something more elaborate/careful here?
        recipient.transfer(amountToSend);
    }

    function getAmountClaimableForMiladyAndAccessory(uint miladyId, uint accessoryId)
        public
        view
        returns (uint amountClaimable)
    {
        if (! rewardInfoForAccessory[accessoryId].miladyRewardInfo[miladyId].isRegistered) {
            return 0;
        }
        
        RewardInfoForAccessory storage rewardInfo = rewardInfoForAccessory[accessoryId];
        
        //todo: possible DRY cleanup with this and the beginning of claimRewardsForMiladyAndAccessory
        uint rewardOwedBeforeDivision = rewardInfo.totalRewardsAccrued - rewardInfo.miladyRewardInfo[miladyId].amountClaimedBeforeDivision;

        amountClaimable = rewardOwedBeforeDivision / rewardInfo.totalHolders;
    }

    function getAmountClaimableForMiladyAndAccessories(uint miladyId, uint[] memory accessoryIds)
        public
        view
        returns (uint amountClaimable)
    {
        for (uint i=0; i<accessoryIds.length; i++) {
            amountClaimable += getAmountClaimableForMiladyAndAccessory(miladyId, accessoryIds[i]);
        }
    }
}