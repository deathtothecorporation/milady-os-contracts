// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "../MiladyOSTestBase.sol";

contract SoulboundAccessoriesTests is MiladyOSTestBase {
    function test_SA_SAC_3(address _newAvatarContractAddress) public
    {
        // Conditions:
        // 1. msg.sender is deployer
        // 2. avatarContract != 0x00

        SoulboundAccessories soulboundAccessories = new SoulboundAccessories(
            IERC6551Registry(payable(address(1))),
            IERC6551Account(payable(address(2))),
            address(3),
            "https://n.a/");
        address avatarContractAddressBefore = address(soulboundAccessories.avatarContract());

        vm.prank(address(this)); // added for clarity
        soulboundAccessories.setAvatarContract(MiladyAvatar(_newAvatarContractAddress));

        address avatarContractAddressAfter = address(soulboundAccessories.avatarContract());
        require(avatarContractAddressAfter == _newAvatarContractAddress, "avatarContractAddressAfter != _newAvatarContractAddress");
    }
}