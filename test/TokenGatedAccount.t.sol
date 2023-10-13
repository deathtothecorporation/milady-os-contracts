/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "../src/TGA/TBARegistry.sol";
import "../src/TGA/TokenGatedAccount.sol";
import "./MiladyOSTestBase.sol";
import "./Miladys.sol";

contract TGATests is MiladyOSTestBase {
    function test_expectedPermissions() public {
        // send a Milady to a new address `firstNFTHolder`
        address firstNFTHolder = address(uint160(10));
        payable(firstNFTHolder).transfer(100);
        miladysContract.transferFrom(address(this), firstNFTHolder, 0);

        // create TGA for NFT
        address payable tgaAddress = testUtils.createTGA(miladysContract, 0);
        TokenGatedAccount tga = TokenGatedAccount(tgaAddress);
        
        // send that TGA some eth to play with
        (bool sent, ) = tgaAddress.call{value: 100}("");
        require(sent, "Failed to send Ether");

        address payable someOtherAddress = payable(address(uint160(11)));

        vm.expectRevert("Unauthorized caller");
        tga.execute{value: 1}(address(this), 1, "", 0);

        vm.startPrank(firstNFTHolder);
        console.log("tgaOwner",tga.owner());
        tga.execute{value: 1}(someOtherAddress, 1, "", 0);
        vm.stopPrank();

        // test that bonded account can act
        address payable bondedAccount = payable(address(uint160(12)));
        bondedAccount.transfer(100);

        vm.prank(firstNFTHolder);
        tga.bond(bondedAccount);
        vm.prank(bondedAccount);
        tga.execute{value:1}(someOtherAddress, 1, "", 0);

        // test that this stops working once the base NFT is send somewhere else
        vm.prank(firstNFTHolder);
        miladysContract.transferFrom(firstNFTHolder, someOtherAddress, 0);
        vm.prank(bondedAccount);
        vm.expectRevert("Unauthorized caller");
        tga.execute{value:1}(someOtherAddress, 1, "", 0);

        // now let's rebond the account and test that it can change the bonded account itself
        vm.prank(someOtherAddress);
        tga.bond(bondedAccount);
        vm.prank(bondedAccount);
        tga.bond(someOtherAddress);
    }
}