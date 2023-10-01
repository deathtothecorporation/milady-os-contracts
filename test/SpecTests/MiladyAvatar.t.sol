// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../MiladyOSTestBase.sol";
import "../Harnesses.t.sol";

contract MiladyAvatarTests is MiladyOSTestBase {
    event AccessoryUnequipped(uint indexed _miladyId, uint indexed _accessoryId);
    event AccessoryEquipped(uint indexed _miladyId, uint indexed _accessoryId);

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
            liquidAccessoryIds[i] = random(abi.encodePacked(_seed, i));
            liquidAccessoriesContract.defineBondingCurveParameter(liquidAccessoryIds[i], 0.001 ether);
            soulboundAccessoryIds[i] = random(abi.encodePacked(_seed, i+1)); 
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

        uint accessoryIdToNOTHave = random(abi.encodePacked(_seed, _numberOfAccessories, _miladyId));
        soulboundAccessoryIds[accessoryIdToNOTHave % _numberOfAccessories] = random(abi.encodePacked(accessoryIdToNOTHave));

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
            liquidAccessoryIds[i] = random(abi.encodePacked(_seed, i));
            liquidAccessoriesContract.defineBondingCurveParameter(liquidAccessoryIds[i], 0.001 ether);
            soulboundAccessoryIds[i] = random(abi.encodePacked(_seed, i+1)); 
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

    function test_MA_UABSTAV_4(uint _miladyId, uint _seed) public
    {
        // conditions:
        // * something valid is being equiped
        // * the milady does not own the thing being equiped

        // logic:
        // * pick one of the stolen miladies
        // * pick one of the accessories that is not owned by the milady
        // * expect a revert and try to equip it

        // arrange
        vm.assume(_miladyId <= NUM_MILADYS_MINTED);
        uint accessoryId = random(abi.encodePacked(_seed));
        (uint128 accType, uint128 accVariant) = avatarContract.accessoryIdToTypeAndVariantIds(accessoryId);

        // act
        vm.expectRevert("Not accessory owner");
        avatarContract.updateEquipSlotByTypeAndVariant(_miladyId, accType, accVariant);

        // assert
        // revert above is the expected assert        
    }

    function test_MA_UABSTAV_7(uint _miladyId, uint _seed) public
    {
        // conditions
        // * something is being equiped
        // * something is already equiped
        // * the milady owns the thing being equiped
        // * the something alread equiped was properly minted, and disburses rewards when unequiped
        // * the something being equiped was properly minted and is registered for rewards when equiped

        // logic:
        // * pick one of the stolen miladies
        // * buy an accessory for the milady
        // * equip the accessory
        // * buy another accessory for the milady
        // * equip the new something
        
        // checks:
        // * the first something is no longer equiped
        // * the second something is equiped
        // * AccessoryUnequipped event is emitted
        // * AccessoryEquipped event is emitted

        // arrange
        vm.assume(_miladyId <= NUM_MILADYS_MINTED);
        uint accessoryId = random(abi.encodePacked(_seed));
        createAndBuyAccessory(_miladyId, accessoryId, 0.001 ether);

        (uint128 accType, uint128 accVariant) = avatarContract.accessoryIdToTypeAndVariantIds(accessoryId);
        avatarContract.updateEquipSlotByTypeAndVariant(_miladyId, accType, accVariant);

        (, uint128 accVariant2) = avatarContract.accessoryIdToTypeAndVariantIds(random(abi.encodePacked(_seed, accessoryId)));
        uint accessoryId2 = avatarContract.typeAndVariantIdsToAccessoryId(accType, accVariant2);
        createAndBuyAccessory(_miladyId, accessoryId2, 0.001 ether);

        // act
        vm.expectEmit(address(avatarContract));
        emit AccessoryUnequipped(_miladyId, accessoryId);
        vm.expectEmit(address(avatarContract));
        emit AccessoryEquipped(_miladyId, accessoryId2);
        
        avatarContract.updateEquipSlotByTypeAndVariant(_miladyId, accType, accVariant2);
        require(avatarContract.equipSlots(_miladyId, accType) == accessoryId2, "equipSlot not updated");
    }
}