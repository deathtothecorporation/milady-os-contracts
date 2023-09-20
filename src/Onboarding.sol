// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "openzeppelin/access/AccessControl.sol";
import "openzeppelin/token/ERC721/IERC721.sol";
import "./SoulboundAccessories.sol";
import "./TBA/TBARegistry.sol";

contract Onboarding is AccessControl {
    bytes32 constant ROLE_MILADY_AUTHORITY = keccak256("MILADY_AUTHORITY");

    TBARegistry tbaRegistry;
    TokenBasedAccount tbaAccountImpl;
    uint chainId;

    SoulboundAccessories public soulboundAccessories;
    IERC721 miladysContract;

    constructor(
        TBARegistry _tbaRegistry,
        TokenBasedAccount _tbaAccountImpl,
        uint _chainId,
        IERC721 _miladysContract,
        SoulboundAccessories _soulboundAccessories,
        address miladyAuthorityAddress
    )
    {
        tbaRegistry = _tbaRegistry;
        tbaAccountImpl = _tbaAccountImpl;
        chainId = _chainId;

        _grantRole(ROLE_MILADY_AUTHORITY, miladyAuthorityAddress);

        miladysContract = _miladysContract;
        soulboundAccessories = _soulboundAccessories;
    }

    function onboardMilady(uint miladyId, uint[] calldata accessories)
        external
        onlyRole(ROLE_MILADY_AUTHORITY)
    {
        // initialize the TBA for the original Milady
        tbaRegistry.createAccount(
            address(tbaAccountImpl),
            chainId,
            address(miladysContract),
            miladyId,
            0,
            ""
        );

        // this call will also initialize the TBA for the avatar
        soulboundAccessories.mintAndEquipSoulboundAccessories(miladyId, accessories);
    }
}