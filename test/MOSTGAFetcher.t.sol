pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "./MiladyOSTestBase.sol";
import "../src/MOSTGAFetcher.sol";

contract MOSTGAFetcherTests is MiladyOSTestBase {
    MOSTGAFetcher fetcher;

    function test_stuff(uint mintedMilady, uint miladyNotMinted) public {
        vm.assume(mintedMilady < NUM_MILADYS_MINTED);
        vm.assume(miladyNotMinted > NUM_MILADYS_MINTED);

        fetcher = new MOSTGAFetcher(
            tgaRegistry,
            tgaAccountImpl,

            address(0), // not testing functions specific to ships
            address(0), // not testing functions specific to MOS Pills
            address(miladysContract),
            address(avatarContract)
        );
        
        require(fetcher.getDeployedMiladyTGA(mintedMilady) != address(0), "should be able to fetch TGA for minted Milady");
        require(fetcher.getDeployedMiladyTGA(miladyNotMinted) == address(0), "should not be able to fetch TGA for non-minted Milady");

        require(fetcher.getDeployedAvatarTGA(mintedMilady) != address(0), "should be able to fetch TGA for minted Avatar");
        require(fetcher.getDeployedAvatarTGA(miladyNotMinted) == address(0), "should not be able to fetch TGA for non-minted Avatar");

        require(fetcher.calcMiladyTGA(mintedMilady) == tgaRegistry.account(
            address(tgaAccountImpl),
            1, // chainId
            address(miladysContract),
            mintedMilady,
            0 // salt
        ), "calcMiladyTGA is not the same as TGARegistry.account");

        require(fetcher.calcAvatarTGA(mintedMilady) == tgaRegistry.account(
            address(tgaAccountImpl),
            1, // chainId
            address(avatarContract),
            mintedMilady,
            0 // salt
        ), "calcAvatarTGA is not the same as TGARegistry.account");
    }
}