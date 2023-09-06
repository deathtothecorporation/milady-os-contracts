// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC721/ERC721.sol";
import "openzeppelin/access/AccessControl.sol";
import "./TBA/IERC6551Registry.sol";
import "./TBA/IERC6551Account.sol";
import "./TBA/TokenBasedAccount.sol";
import "./MiladyAvatar.sol";
import "./AccessoryBase.sol";

contract MiladyAvatarAccessories is AccessoryBase, AccessControl {
    bytes32 constant ROLE_MILADY_AUTHORITY = keccak256("MILADY_AUTHORITY");

    MiladyAvatar public miladyAvatarContract;

    // state needed for TBA determination
    IERC6551Registry tbaRegistry;
    IERC6551Account tbaAccountImpl;
    uint chainId;

    mapping(uint => bool) public avatarActivated;

    constructor(address miladyAuthority, MiladyAvatar _miladyAvatarContract, IERC6551Registry _tbaRegistry, IERC6551Account _tbaAccountImpl, uint _chainId) {
        _grantRole(ROLE_MILADY_AUTHORITY, miladyAuthority);
        miladyAvatarContract = _miladyAvatarContract;

        tbaRegistry = _tbaRegistry;
        tbaAccountImpl = _tbaAccountImpl;
        chainId = _chainId;
    }

    function mintSoulboundAccessories(uint miladyId, uint[] calldata accessories)
        onlyRole(ROLE_MILADY_AUTHORITY)
        external
    {
        require(!avatarActivated[miladyId], "This avatar has already been activated");
        avatarActivated[miladyId] = true;

        // todo: do we want to worry about the authority making a mistake, and being able to address this?

        // create the TBA for the avatar (or find it if it already exists)
        address avatarTbaAddress = tbaRegistry.createAccount(
            tbaAccountImpl,
            chainId,
            miladyAvatarContract,
            miladyId,
            0
        );

        for (uint i=0; i<accessories.length; i++) {
            _mint(avatarTbaAddress, accessories[i], 1, "");
        }
    }

    // disable all token transfers, making these soulbound.
    function _beforeTokenTransfer(address, address, address, uint256[] memory, uint256[] memory, bytes memory)
        internal
    {
        revert("These accessories are soulbound to the Milady Avatar and cannot be transferred");
    }

    // todo: need to do anything for uri func?
    // should we do something special if not yet activated (like forward to Milady's uri?)
}