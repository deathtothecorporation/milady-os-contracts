/* solhint-disable private-vars-leading-underscore */

pragma solidity 0.8.18;

import "openzeppelin/token/ERC721/IERC721.sol";
import "TokenGatedAccount/TGARegistry.sol";
import "TokenGatedAccount/TokenGatedAccount.sol";
import "./MiladyAvatar.sol";
import "./LiquidAccessories.sol";
import "./SoulboundAccessories.sol";
import "./Rewards.sol";

contract Deployer {
    MiladyAvatar public avatarContract;
    Rewards public rewardsContract;
    LiquidAccessories public liquidAccessoriesContract;
    SoulboundAccessories public soulboundAccessoriesContract;

    event Deployed(
        address avatarContractAddress,
        address liquidAccessoriesContractAddress,
        address soulboundAccessoriesContractAddress,
        address rewardsContractAddress
    );

    constructor(
        TGARegistry tgaRegistry,
        TokenGatedAccount tgaAccountImpl,
        IERC721 miladysContract,
        address miladyAuthorityAddress,
        address liquidAccessoriesOwner,
        address soulboundAccessoriesOwner,
        address payable revenueRecipient,
        string memory avatarBaseURI,
        string memory liquidAccessoriesURI,
        string memory soulboundAccessoriesURI
    )
    {
        avatarContract = new MiladyAvatar(
            miladysContract,
            tgaRegistry,
            tgaAccountImpl,
            avatarBaseURI
        );

        rewardsContract = new Rewards(address(avatarContract), miladysContract);

        liquidAccessoriesContract = new LiquidAccessories(
            tgaRegistry,
            rewardsContract,
            revenueRecipient,
            liquidAccessoriesURI
        );

        soulboundAccessoriesContract = new SoulboundAccessories(
            tgaRegistry,
            tgaAccountImpl,
            miladyAuthorityAddress,
            soulboundAccessoriesURI
        );

        avatarContract.setOtherContracts(liquidAccessoriesContract, soulboundAccessoriesContract, rewardsContract);
        liquidAccessoriesContract.setAvatarContract(avatarContract);
        soulboundAccessoriesContract.setAvatarContract(avatarContract);

        liquidAccessoriesContract.transferOwnership(liquidAccessoriesOwner);
        soulboundAccessoriesContract.transferOwnership(soulboundAccessoriesOwner);

        emit Deployed(
            address(avatarContract),
            address(liquidAccessoriesContract),
            address(soulboundAccessoriesContract),
            address(rewardsContract)
        );
    }
}