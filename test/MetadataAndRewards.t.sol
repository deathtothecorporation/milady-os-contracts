// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/MetadataAndRewards.sol";
import "../src/Miladys.sol";

uint constant NUM_MILADYS_MINTED = 30;

address constant metadataAuthorityAddress = address(uint160(1));

contract MetadataAndRewardsTest is Test {
    MiladyMetadataAndRewards metadataAndRewardsContract;
    Miladys miladyContract;
    MockOffchainMetadataSource mockMetdataSource;

    function setUp() external {
        miladyContract = new Miladys();
        miladyContract.flipSaleState();

        // mint miladys to msg.sender for testing
        miladyContract.mintMiladys{value:60000000000000000*NUM_MILADYS_MINTED}(NUM_MILADYS_MINTED);

        console.log(metadataAuthorityAddress);
        metadataAndRewardsContract = new MiladyMetadataAndRewards(miladyContract, metadataAuthorityAddress);

        mockMetdataSource = new MockOffchainMetadataSource();
    }

    function test_rewardStory() external {
        // onboard a milady
        uint16[NUM_ACCESSORY_TYPES] memory metadata = mockMetdataSource.get(0);
        vm.prank(metadataAuthorityAddress);
        metadataAndRewardsContract.onboardMilady(0, metadata);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract MockOffchainMetadataSource {
    function get(uint miladyID)
        pure
        public
        returns (uint16[NUM_ACCESSORY_TYPES] memory accessories)
    {
        for (uint i=0; i<NUM_ACCESSORY_TYPES; i++)
        {
            accessories[i] = uint16(uint(keccak256(abi.encode(miladyID, i))));
        }

        return accessories;
    }
}