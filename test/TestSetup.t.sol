// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/TBA/TokenBasedAccount.sol";
import "../src/TBA/TBARegistry.sol";
import "./Miladys.sol";
import "../src/MiladyAvatar.sol";
import "../src/LiquidAccessories.sol";
import "../src/SoulboundAccessories.sol";
import "../src/Rewards.sol";
import "../src/Deployer.sol";

library TestSetup {
    function deploy(uint numMiladysToMint, address miladyAuthorityAddress)
        public
        returns
    (
        TBARegistry tbaRegistry,
        TokenBasedAccount tbaAccountImpl,
        Miladys miladyContract,
        MiladyAvatar miladyAvatarContract,
        LiquidAccessories liquidAccessoriesContract,
        SoulboundAccessories soulboundAccessoriesContract,
        Rewards rewardsContract
    )
    {
        tbaRegistry = new TBARegistry();
        tbaAccountImpl = new TokenBasedAccount();

        miladyContract = new Miladys();
        miladyContract.flipSaleState();

        // mint miladys to msg.sender for testing
        miladyContract.mintMiladys{value:60000000000000000*numMiladysToMint}(numMiladysToMint);
        
        (
            miladyAvatarContract, liquidAccessoriesContract, soulboundAccessoriesContract, rewardsContract
        ) =
        Deployer.deploy(
            tbaRegistry,
            tbaAccountImpl,
            miladyContract,
            miladyAuthorityAddress,
            31337, // chain id of Forge's test chain
            "",
            ""
        );
    }
}