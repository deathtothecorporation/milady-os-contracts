// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./TestConstants.sol";
import "./Miladys.sol";
import "../src/MiladyAvatar.sol";
import "../src/TGA/TBARegistry.sol";

contract GhostNFT is Test {
    TBARegistry public tbaRegistry;
    TokenGatedAccount public tbaAcctImpl;

    Miladys miladyContract;
    MiladyAvatar miladyAvatarContract;

    function setUp() external {
        tbaRegistry = new TBARegistry();
        tbaAcctImpl = new TokenGatedAccount();

        miladyContract = new Miladys();
        miladyContract.flipSaleState();

        // mint miladys to msg.sender for testing
        miladyContract.mintMiladys{value:60000000000000000*NUM_MILADYS_MINTED}(NUM_MILADYS_MINTED);

        miladyAvatarContract = new MiladyAvatar(
            miladyContract,
            tbaRegistry,
            tbaAcctImpl,
            31337, // chain id of Forge's test chain
            ""
        );
    }

    function test_ownershipTracks() public {
        assert(miladyAvatarContract.ownerOf(0) == tbaRegistry.account(
            address(tbaAcctImpl),
            31337,
            address(miladyContract),
            0,
            0
        ));

        miladyContract.transferFrom(address(this), address(0x2), 0);

        assert(miladyAvatarContract.ownerOf(0) == tbaRegistry.account(
            address(tbaAcctImpl),
            31337,
            address(miladyContract),
            0,
            0
        ));
    }

    /*
    more tests:
    * test all transfer-related functions fail
    * test negative cases (owner for an Id with no milady?)
    */

    receive() external payable {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}