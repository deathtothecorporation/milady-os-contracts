// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC721/IERC721.sol";
import "./TGA/TBARegistry.sol";

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

    event RewardsAccrued(uint indexed _accessoryId, uint _amount);

    function addRewardsForAccessory(uint _accessoryId)
        payable
        external
    {
        require(msg.value > 0, "No ether included");
        require(rewardInfoForAccessory[_accessoryId].totalHolders > 0, "No eligible recipients");

        rewardInfoForAccessory[_accessoryId].totalRewardsAccrued += msg.value;

        emit RewardsAccrued(_accessoryId, msg.value);
    }

    event MiladyRegisteredForRewards(uint indexed _miladyId, uint indexed _accessoryId);

    function registerMiladyForRewardsForAccessory(uint _miladyId, uint _accessoryId)
        external
    {
        require(msg.sender == avatarContractAddress, "Not avatarContractAddress");
        
        MiladyRewardInfo storage miladyRewardInfo = rewardInfoForAccessory[_accessoryId].miladyRewardInfo[_miladyId];

        require(! miladyRewardInfo.isRegistered, "Milady already registered");

        // When a new Milady is registered, we pretend they've been here the whole time and have already claimed all they could.
        // This essentially starts out this Milady with 0 claimable rewards, which will go up as revenue increases.
        miladyRewardInfo.amountClaimedBeforeDivision = rewardInfoForAccessory[_accessoryId].totalRewardsAccrued;
        rewardInfoForAccessory[_accessoryId].totalHolders ++;

        miladyRewardInfo.isRegistered = true;

        emit MiladyRegisteredForRewards(_miladyId, _accessoryId);
    }

    event MiladyDeregisteredForRewards(uint indexed _miladyId, uint indexed _accessoryId);

    function deregisterMiladyForRewardsForAccessoryAndClaim(uint _miladyId, uint _accessoryId, address payable _recipient)
        external
    {
        require(msg.sender == avatarContractAddress, "Not avatarContractAddress");

        MiladyRewardInfo storage miladyRewardInfo = rewardInfoForAccessory[_accessoryId].miladyRewardInfo[_miladyId];

        require(miladyRewardInfo.isRegistered, "Milady not registered");

        rewardInfoForAccessory[_accessoryId].totalHolders --;

        miladyRewardInfo.isRegistered = false;

        _claimRewardsForMiladyForAccessory(_miladyId, _accessoryId, _recipient);

        emit MiladyDeregisteredForRewards(_miladyId, _accessoryId);
    }

    function claimRewardsForMilady(uint _miladyId, uint[] calldata _accessoriesToClaimFor, address payable _recipient)
        external
    {
        require(msg.sender == miladysContract.ownerOf(_miladyId), "Not Milady owner");

        for (uint i=0; i<_accessoriesToClaimFor.length; i++) {
            _claimRewardsForMiladyForAccessory(_miladyId, _accessoriesToClaimFor[i], _recipient);
        }
    }

    event RewardsClaimed(uint indexed _miladyId, uint indexed _accessoryId, address indexed _recipient);

    function _claimRewardsForMiladyForAccessory(uint _miladyId, uint _accessoryId, address payable _recipient)
        internal
    {
        RewardInfoForAccessory storage rewardInfo = rewardInfoForAccessory[_accessoryId];

        uint rewardOwedBeforeDivision = rewardInfo.totalRewardsAccrued - rewardInfo.miladyRewardInfo[_miladyId].amountClaimedBeforeDivision;

        uint amountToSend = getAmountClaimableForMiladyAndAccessory(_miladyId, _accessoryId);

        rewardInfo.miladyRewardInfo[_miladyId].amountClaimedBeforeDivision += rewardOwedBeforeDivision;

        // Schalk: Should we be doing something more elaborate/careful here?
        // Logan <| Yes, but the problem was where _claimRewardsForMiladyForAccessory was being called in MiladyDeregisteredForRewards. Fixed now.
        _recipient.transfer(amountToSend);

        emit RewardsClaimed(_miladyId, _accessoryId, _recipient);
    }

    function getAmountClaimableForMiladyAndAccessory(uint _miladyId, uint _accessoryId)
        public
        view
        returns (uint amountClaimable)
    {
        if (! rewardInfoForAccessory[_accessoryId].miladyRewardInfo[_miladyId].isRegistered) {
            return 0;
        }
        
        RewardInfoForAccessory storage rewardInfo = rewardInfoForAccessory[_accessoryId];
        
        //todo: possible DRY cleanup with this and the beginning of claimRewardsForMiladyAndAccessory
        uint rewardOwedBeforeDivision = rewardInfo.totalRewardsAccrued - rewardInfo.miladyRewardInfo[_miladyId].amountClaimedBeforeDivision;

        amountClaimable = rewardOwedBeforeDivision / rewardInfo.totalHolders;
    }

    function getAmountClaimableForMiladyAndAccessories(uint _miladyId, uint[] memory _accessoryIds)
        public
        view
        returns (uint amountClaimable)
    {
        for (uint i=0; i<_accessoryIds.length; i++) {
            amountClaimable += getAmountClaimableForMiladyAndAccessory(_miladyId, _accessoryIds[i]);
        }
    }
}