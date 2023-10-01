pragma solidity ^0.8.13;

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
        uint _chainId,
        address _miladyAuthority,
        string memory uri_
    )
        SoulboundAccessories( 
        _tbaRegistry,
         _tbaAccountImpl,
         _chainId,
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

contract HarnessDeployer {
    MiladyAvatar public avatarContract;
    Rewards public rewardsContract;
    LiquidAccessories public liquidAccessoriesContract;
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
        uint chainId,
        IERC721 miladysContract,
        address miladyAuthorityAddress,
        address payable revenueRecipient,
        string memory avatarBaseURI,
        string memory liquidAccessoriesURI,
        string memory soulboundAccessoriesHarnessURI  // Changed the parameter name here
    )
    {
        avatarContract = new MiladyAvatar(
            miladysContract,
            tbaRegistry,
            tbaAccountImpl,
            chainId,
            avatarBaseURI
        );

        rewardsContract = new Rewards(address(avatarContract), miladysContract);

        liquidAccessoriesContract = new LiquidAccessories(
            tbaRegistry,
            rewardsContract,
            revenueRecipient,
            liquidAccessoriesURI
        );

        soulboundAccessoriesContract = new SoulboundAccessoriesHarness(  // Changed the contract type here
            tbaRegistry,
            tbaAccountImpl,
            chainId,
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
