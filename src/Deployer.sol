// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC721/IERC721.sol";
import "./TBA/TBARegistry.sol";
import "./TBA/TokenBasedAccount.sol";
import "./MiladyAvatar.sol";
import "./LiquidAccessories.sol";
import "./SoulboundAccessories.sol";
import "./Rewards.sol";
import "./Onboarding.sol";

library Deployer {
    function deploy(
        TBARegistry tbaRegistry,
        TokenBasedAccount tbaAccountImpl,
        uint chainId,
        IERC721 miladysContract,
        address miladyAuthorityAddress,
        address payable revenueRecipient,
        string memory liquidAccessoriesURI,
        string memory soulboundAccessoriesURI
    )
        public
        returns (
            MiladyAvatar avatarContract,
            LiquidAccessories liquidAccessoriesContract,
            SoulboundAccessories soulboundAccessoriesContract,
            Rewards rewardsContract,
            Onboarding onboardingContract
        )
    {
        avatarContract = new MiladyAvatar(
            miladysContract,
            tbaRegistry,
            tbaAccountImpl,
            chainId
        );

        rewardsContract = new Rewards(address(avatarContract), miladysContract);

        liquidAccessoriesContract = new LiquidAccessories(
            tbaRegistry,
            rewardsContract,
            revenueRecipient,
            liquidAccessoriesURI
        );

        soulboundAccessoriesContract = new SoulboundAccessories(
            tbaRegistry,
            tbaAccountImpl,
            chainId,
            soulboundAccessoriesURI
        );   

        onboardingContract = new Onboarding(
            tbaRegistry,
            tbaAccountImpl,
            chainId,
            miladysContract,
            soulboundAccessoriesContract,
            miladyAuthorityAddress
        );

        avatarContract.setOtherContracts(liquidAccessoriesContract, soulboundAccessoriesContract, rewardsContract);
        liquidAccessoriesContract.setAvatarContract(avatarContract);
        soulboundAccessoriesContract.setOtherContracts(avatarContract, address(onboardingContract));
    }
}