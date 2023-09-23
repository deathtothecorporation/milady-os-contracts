// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/TGA/TBARegistry.sol";
import "../src/TGA/TokenGatedAccount.sol";
import "./TestSetup.sol";
import "./TestUtils.sol";
import "./TestConstants.sol";
import "./Miladys.sol";

contract TGATests is Test {
    Miladys miladysContract;
    TestUtils testUtils;

    // Schalk: I'm using an NFT "approve" tx for the inner tx to try to execute, for testing.
    // Ideally this would instead be a straight send of ETH, to simplify the logic below
    // But I have no idea how to structure this... tga.executeCall(targetAddress, ethValToSend, "") doesn't work.

    function setUp() public {
        (
            ,//TBARegistry tbaRegistry,
            ,//TokenGatedAccount tbaAccountImpl,
            Miladys _miladysContract,
            ,//MiladyAvatar miladyAvatarContract,
            ,//LiquidAccessories liquidAccessoriesContract,
            ,//soulboundAccessoriesContract,
            ,//rewardsContract
            TestUtils _testUtils
        )
         =
        TestSetup.deploy(NUM_MILADYS_MINTED, MILADY_AUTHORITY_ADDRESS);

        miladysContract = _miladysContract;
        testUtils = _testUtils;
    }
    
    function test_expectedPermissions() public {
        // send a Milady to a new address `firstNFTHolder`
        address firstNFTHolder = address(uint160(10));
        miladysContract.transferFrom(address(this), firstNFTHolder, 0);

        // create TGA for NFT
        address payable tgaAddress = testUtils.createTGA(miladysContract, 0);
        
        // send that TGA some eth to play with
        miladysContract.transferFrom(address(this), tgaAddress, 1);
        // tgaAddress.transfer(100);

        TokenGatedAccount tga = TokenGatedAccount(tgaAddress);

        address someOtherAddress = address(uint160(11));

        vm.expectRevert("Unauthorized caller");
        tga.executeCall(address(miladysContract), 0, abi.encodeCall(miladysContract.approve, (someOtherAddress, 1)));

        vm.prank(firstNFTHolder);
        tga.executeCall(address(miladysContract), 0, abi.encodeCall(miladysContract.approve, (someOtherAddress, 1)));

        // test that bonded account can act
        address bondedAccount = address(uint160(12));
        vm.prank(firstNFTHolder);
        tga.bond(bondedAccount);
        vm.prank(bondedAccount);
        tga.executeCall(address(miladysContract), 0, abi.encodeCall(miladysContract.approve, (someOtherAddress, 1)));

        // test that this stops working once the base NFT is send somewhere else
        vm.prank(firstNFTHolder);
        miladysContract.transferFrom(firstNFTHolder, someOtherAddress, 0);
        vm.prank(bondedAccount);
        vm.expectRevert("Unauthorized caller");
        tga.executeCall(address(miladysContract), 0, abi.encodeCall(miladysContract.approve, (someOtherAddress, 1)));

        // now let's rebond the account and test that it can change the bonded account itself
        vm.prank(someOtherAddress);
        tga.bond(bondedAccount);
        vm.prank(bondedAccount);
        tga.bond(someOtherAddress);
    }

    // define functions to allow receiving ether and NFTs

    receive() external payable {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }
}