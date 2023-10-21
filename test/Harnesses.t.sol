pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./TestSetup.sol";
import "./TestUtils.sol";
import "./TestConstants.sol";

contract SoulboundAccessoriesHarness is SoulboundAccessories
{
    constructor(
        IERC6551Registry _tbaRegistry,
        IERC6551Account _tbaAccountImpl,
        address _miladyAuthority,
        string memory uri_
    )
        SoulboundAccessories( 
        _tbaRegistry,
         _tbaAccountImpl,
         _miladyAuthority,
        uri_) {}

    function mintBatch(
            address to,
            uint256[] memory ids,
            uint256[] memory amounts,
            bytes memory data) 
        public 
    {
        _mintBatch(to, ids, amounts, data);
    }
}

contract MiladyAvatarHarness is MiladyAvatar {
    constructor(
            IERC721 _miladysContract,
            TBARegistry _tbaRegistry,
            TokenGatedAccount _tbaAccountImpl,
            string memory _baseURI
    ) MiladyAvatar(
        _miladysContract,
        _tbaRegistry,
        _tbaAccountImpl,
        _baseURI) {}

    function updateEquipSlotByTypeAndVariant(uint _miladyId, uint128 _accType, uint128 _accVariantOrNull) public {
        _updateEquipSlotByTypeAndVariant(_miladyId, _accType, _accVariantOrNull);
    }
}

contract RewardsHarness is Rewards {
    constructor (
        address _avatarContractAddress,
        IERC721 _miladysContract
    ) Rewards(
        _avatarContractAddress,
        _miladysContract
    ) {}

    function getMiladyRewardInfoForAccessory(uint _miladyId, uint _accessoryId)
        external
        view
        returns (bool isRegistered, uint amountClaimed)
    {
        MiladyRewardInfo storage miladyRewardInfo = rewardInfoForAccessory[_accessoryId].miladyRewardInfo[_miladyId];

        isRegistered = miladyRewardInfo.isRegistered;
        amountClaimed = miladyRewardInfo.amountClaimed;
    }
}

contract LiquidAccessoriesHarness is LiquidAccessories {
    constructor(
            TBARegistry _tbaRegistry, 
            Rewards _rewardsContract, 
            address payable _revenueRecipient, 
            string memory uri_)
        LiquidAccessories(
            _tbaRegistry, 
            _rewardsContract, 
            _revenueRecipient, 
            uri_) {}

    function mintAccessoryAndDisburseRevenue(
            uint _accessoryId, 
            uint _amount, 
            address _recipient)
        external
        payable
    {
        _mintAccessoryAndDisburseRevenue(_accessoryId, _amount, _recipient);
    }

    function _revenueRecipient()
        external
        view
        returns (address payable)
    {
        return revenueRecipient;
    }

    function getBurnRewardForReturnedAccessories(uint _amount, uint _currentSupplyOfAccessory, uint _curveParameter)
        external
        pure
        returns (uint)
    {
        require(_curveParameter != 0, "No bonding curve");
        require(_amount <= _currentSupplyOfAccessory, "Insufficient accessory supply");

        uint totalReward;
        for (uint i=0; i<_amount; i++) {
            totalReward += getBurnRewardForItemNumber((_currentSupplyOfAccessory - 1) - i, _curveParameter);
        }
        return totalReward;
    }

    function burnAccessory(uint _accessoryId, uint _amount)
        external
    {
        _burnAccessory(_accessoryId, _amount);
    }
}

contract HarnessDeployer {
    MiladyAvatarHarness public avatarContract;
    RewardsHarness public rewardsContract;
    LiquidAccessoriesHarness public liquidAccessoriesContract;
    SoulboundAccessoriesHarness public soulboundAccessoriesContract;  // Changed the contract type here

    event Deployed(
        address avatarContractAddress,
        address liquidAccessoriesContractAddress,
        address soulboundAccessoriesContractAddress,  // Changed the event parameter name here
        address rewardsContractAddress
    );

    constructor(
        TBARegistry tbaRegistry,
        TokenGatedAccount tbaAccountImpl,
        IERC721 miladysContract,
        address miladyAuthorityAddress,
        address payable revenueRecipient,
        string memory avatarBaseURI,
        string memory liquidAccessoriesURI,
        string memory soulboundAccessoriesHarnessURI  // Changed the parameter name here
    )
    {
        avatarContract = new MiladyAvatarHarness(
            miladysContract,
            tbaRegistry,
            tbaAccountImpl,
            avatarBaseURI
        );

        rewardsContract = new RewardsHarness(address(avatarContract), miladysContract);

        liquidAccessoriesContract = new LiquidAccessoriesHarness(
            tbaRegistry,
            rewardsContract,
            revenueRecipient,
            liquidAccessoriesURI
        );

        soulboundAccessoriesContract = new SoulboundAccessoriesHarness(  // Changed the contract type here
            tbaRegistry,
            tbaAccountImpl,
            miladyAuthorityAddress,
            soulboundAccessoriesHarnessURI  // Changed the parameter name here
        );

        avatarContract.setOtherContracts(liquidAccessoriesContract, soulboundAccessoriesContract, rewardsContract);  // Changed the contract type here
        liquidAccessoriesContract.setAvatarContract(avatarContract);
        soulboundAccessoriesContract.setAvatarContract(avatarContract);  // Changed the contract type here

        emit Deployed(
            address(avatarContract),
            address(liquidAccessoriesContract),
            address(soulboundAccessoriesContract),  // Changed the event argument here
            address(rewardsContract)
        );
    }
}
