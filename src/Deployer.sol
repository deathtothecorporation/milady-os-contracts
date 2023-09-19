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

library Deployer {
    function deploy(
        TBARegistry tbaRegistry,
        TokenBasedAccount tbaAccountImpl,
        IERC721 miladyContract,
        address miladyAuthorityAddress,
        address payable revenueRecipient,
        uint chainId,
        string memory liquidAccessoriesURI,
        string memory soulboundAccessoriesURI
    )
        public
        returns (MiladyAvatar avatarContract, LiquidAccessories liquidAccessoriesContract, SoulboundAccessories soulboundAccessoriesContract, Rewards rewardsContract)
    {
        avatarContract = new MiladyAvatar(
            miladyContract,
            tbaRegistry,
            tbaAccountImpl,
            chainId
        );

        rewardsContract = new Rewards(address(avatarContract), miladyContract);

        liquidAccessoriesContract = new LiquidAccessories(
            tbaRegistry,
            rewardsContract,
            revenueRecipient,
            liquidAccessoriesURI
        );

        soulboundAccessoriesContract = new SoulboundAccessories(
            miladyAuthorityAddress,
            tbaRegistry,
            tbaAccountImpl,
            chainId,
            soulboundAccessoriesURI
        );        

        avatarContract.setOtherContracts(liquidAccessoriesContract, soulboundAccessoriesContract, rewardsContract);
        liquidAccessoriesContract.setAvatarContract(avatarContract);
        soulboundAccessoriesContract.setAvatarContract(avatarContract);
    }
}