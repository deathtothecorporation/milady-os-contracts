// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC721/IERC721.sol";
import "./SoulboundAccessories.sol";
import "./TBA/TBARegistry.sol";

contract Onboarding {
    TBARegistry public tbaRegistry;
    TokenBasedAccount public tbaAccountImpl;
    uint public chainId;

    SoulboundAccessories public soulboundAccessories;
    IERC721 public miladysContract;
    address public miladyAuthorityAddress;

    constructor(
        TBARegistry _tbaRegistry,
        TokenBasedAccount _tbaAccountImpl,
        uint _chainId,
        IERC721 _miladysContract,
        SoulboundAccessories _soulboundAccessories,
        address _miladyAuthorityAddress
    )
    {
        tbaRegistry = _tbaRegistry;
        tbaAccountImpl = _tbaAccountImpl;
        chainId = _chainId;

        miladyAuthorityAddress = _miladyAuthorityAddress;
        miladysContract = _miladysContract;
        soulboundAccessories = _soulboundAccessories;
    }

    function onboardMilady(uint miladyId, uint[] calldata accessories)
        external
    {
        require(msg.sender == miladyAuthorityAddress, "msg.sender is not authorized to call this function.");
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