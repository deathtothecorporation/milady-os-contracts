// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/TGA/TokenGatedAccount.sol";
import "../src/TGA/TBARegistry.sol";
import "../src/MiladyAvatar.sol";
import "../src/LiquidAccessories.sol";
import "../src/SoulboundAccessories.sol";
import "../src/Rewards.sol";
import "../src/Deployer.sol";
import "./TestConstants.sol";
import "./TestUtils.sol";
import "./Miladys.sol";

library TestSetup {
    function deploy(uint numMiladysToMint, address miladyAuthorityAddress)
        public
        returns
    (
        TBARegistry tbaRegistry,
        TokenGatedAccount tbaAccountImpl,
        Miladys miladyContract,
        MiladyAvatar avatarContract,
        LiquidAccessories liquidAccessoriesContract,
        SoulboundAccessories soulboundAccessoriesContract,
        Rewards rewardsContract,
        TestUtils testUtils
    )
    {
        tbaRegistry = new TBARegistry();
        tbaAccountImpl = new TokenGatedAccount();

        testUtils = new TestUtils(tbaRegistry, tbaAccountImpl);

        miladyContract = new Miladys();
        miladyContract.flipSaleState();

        // mint miladys to msg.sender for testing
        miladyContract.mintMiladys{value:60000000000000000*numMiladysToMint}(numMiladysToMint);
        
        Deployer d = new Deployer(
            tbaRegistry,
            tbaAccountImpl,
            31337, // chain id of Forge's test chain
            miladyContract,
            miladyAuthorityAddress,
            PROJECT_REVENUE_RECIPIENT,
            "",
            "",
            ""
        );

        avatarContract = d.avatarContract();
        liquidAccessoriesContract = d.liquidAccessoriesContract();
        soulboundAccessoriesContract = d.soulboundAccessoriesContract();
        rewardsContract = d.rewardsContract();

        for (uint i=0; i<numMiladysToMint; i++) {
            tbaRegistry.createAccount(
                address(tbaAccountImpl),
                31337, // chain id of Forge's test chain
                address(miladyContract),
                i,
                0,
                ""
            );

            tbaRegistry.createAccount(
                address(tbaAccountImpl),
                31337, // chain id of Forge's test chain
                address(avatarContract),
                i,
                0,
                ""
            );
        }
    }
}