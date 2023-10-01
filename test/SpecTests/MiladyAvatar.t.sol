// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../MiladyOSTestBase.sol";
import "../Harnesses.t.sol";

contract MiladyAvatarTests is MiladyOSTestBase {
    function test_MA_ESA_3(uint _miladyId, uint _numberOfAccessories, uint _seed) public
    {
        // conditions:
        // * msg.sender is correct
        // * NOT all accessories are owned by the milady

        // arrange
        vm.assume(_miladyId <= NUM_MILADYS_MINTED);
        vm.assume(_numberOfAccessories > 0);
        vm.assume(_numberOfAccessories <= 10);

        // fuzz some accessories
        uint[] memory liquidAccessoryIds = new uint[](_numberOfAccessories);
        uint[] memory soulboundAccessoryIds = new uint[](_numberOfAccessories);
        uint[] memory mintAmounts = new uint[](_numberOfAccessories);
        vm.startPrank(liquidAccessoriesContract.owner());
        for (uint i = 0; i < _numberOfAccessories; i++) {
            liquidAccessoryIds[i] = uint256(keccak256(abi.encodePacked(_seed, i)));
            liquidAccessoriesContract.defineBondingCurveParameter(liquidAccessoryIds[i], 0.001 ether);
            soulboundAccessoryIds[i] = uint256(keccak256(abi.encodePacked(_seed, i+1))); 
            mintAmounts[i] = 1;
        }
        vm.stopPrank();
        
        // milady should already be stolen at this point
        TokenGatedAccount tba = testUtils.getTGA(avatarContract, _miladyId);
        
        vm.deal(address(this), 1e18 * 1000); // send 1000 eth to this contract
        address payable overpayRecipient = payable(address(0xb055e5b055e5b055e5));
        liquidAccessoriesContract.mintAccessories
            {value : 1 ether}
            (liquidAccessoryIds, 
            mintAmounts, 
            avatarContract.getAvatarTBA(_miladyId), 
            overpayRecipient);
        vm.prank(avatarContract.ownerOf(_miladyId));
        avatarContract.updateEquipSlotsByAccessoryIds(_miladyId, liquidAccessoryIds);

        // mint a set of soulbound accessories for the milady but...
        // change one to another type to be equiped
        soulboundAccessoriesContract.mintBatch(
            address(tba),
            soulboundAccessoryIds,
            mintAmounts,
            "");

        uint accessoryIdToNOTHave = uint256(keccak256(abi.encodePacked(_numberOfAccessories, _miladyId))) % _numberOfAccessories;
        soulboundAccessoryIds[accessoryIdToNOTHave] = uint256(keccak256(abi.encodePacked(accessoryIdToNOTHave)));

        // act
        vm.prank(address(soulboundAccessoriesContract));
        vm.expectRevert("Not accessory owner");
        avatarContract.equipSoulboundAccessories(_miladyId, soulboundAccessoryIds);

        // assert
        // revert above is the expected assert
    }

    function test_MA_ESA_8(uint _miladyId, uint _numberOfAccessories, uint _seed) public
    {
        // conditions:
        // * msg.sender is correct
        // * all accessories are owned by the milady
        // * none of the accessories are the null item, ie not instructed to be unequiped
        // * the accessories slots have something equiped
        // * deregistering for currently equiped accessory rewards succeeds
        // * registering for equiping accessory rewards succeeds

        // arrange
        vm.assume(_miladyId <= NUM_MILADYS_MINTED);
        vm.assume(_numberOfAccessories <= 10);

        // fuzz some accessories
        uint[] memory liquidAccessoryIds = new uint[](_numberOfAccessories);
        uint[] memory soulboundAccessoryIds = new uint[](_numberOfAccessories);
        uint[] memory mintAmounts = new uint[](_numberOfAccessories);
        vm.startPrank(liquidAccessoriesContract.owner());
        for (uint i = 0; i < _numberOfAccessories; i++) {
            liquidAccessoryIds[i] = uint256(keccak256(abi.encodePacked(_seed, i)));
            liquidAccessoriesContract.defineBondingCurveParameter(liquidAccessoryIds[i], 0.001 ether);
            soulboundAccessoryIds[i] = uint256(keccak256(abi.encodePacked(_seed, i+1))); 
            mintAmounts[i] = 1;
        }
        vm.stopPrank();
        
        // milady should already be stolen at this point
        TokenGatedAccount tba = testUtils.getTGA(avatarContract, _miladyId);
        
        vm.deal(address(this), 1e18 * 1000); // send 1000 eth to this contract
        address payable overpayRecipient = payable(address(0xb055e5b055e5b055e5));
        liquidAccessoriesContract.mintAccessories
            {value : 1 ether}
            (liquidAccessoryIds, 
            mintAmounts, 
            avatarContract.getAvatarTBA(_miladyId), 
            overpayRecipient);
        vm.prank(avatarContract.ownerOf(_miladyId));
        avatarContract.updateEquipSlotsByAccessoryIds(_miladyId, liquidAccessoryIds);


        soulboundAccessoriesContract.mintBatch(
            address(tba),
            soulboundAccessoryIds,
            mintAmounts,
            "");

        // act
        vm.prank(address(soulboundAccessoriesContract));
        avatarContract.equipSoulboundAccessories(_miladyId, soulboundAccessoryIds);

        // assert
        for (uint i = 0; i < _numberOfAccessories; i++) {
            (uint128 accType,) = avatarContract.accessoryIdToTypeAndVariantIds(soulboundAccessoryIds[i]);
            require(avatarContract.equipSlots(_miladyId, accType) == soulboundAccessoryIds[i], "Soulbound Accessory not equiped!");
        }
    }
}