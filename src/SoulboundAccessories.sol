// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC1155/ERC1155.sol";
import "./TBA/IERC6551Registry.sol";
import "./TBA/IERC6551Account.sol";
import "./TBA/TokenBasedAccount.sol";
import "./AccessoryUtils.sol";
import "./MiladyAvatar.sol";

contract SoulboundAccessories is ERC1155 {
    MiladyAvatar public miladyAvatarContract;

    // state needed for TBA determination
    IERC6551Registry tbaRegistry;
    IERC6551Account tbaAccountImpl;
    uint chainId;

    address public onboardingContract;

    mapping(uint => bool) public avatarActivated;

    // only used for initial deploy
    address deployer;

    constructor(
        IERC6551Registry _tbaRegistry,
        IERC6551Account _tbaAccountImpl,
        uint _chainId,
        string memory uri_
    )
        ERC1155(uri_)
    {
        deployer = msg.sender;

        tbaRegistry = _tbaRegistry;
        tbaAccountImpl = _tbaAccountImpl;
        chainId = _chainId;
    }

    function setOtherContracts(MiladyAvatar _miladyAvatarContract, address _onboardingContract)
        external
    {
        require(msg.sender == deployer, "Only callable by the initial deployer");
        require(address(miladyAvatarContract) == address(0), "avatar contract already set");

        miladyAvatarContract = _miladyAvatarContract;
        onboardingContract = _onboardingContract;
    }

    function mintAndEquipSoulboundAccessories(uint miladyId, uint[] calldata accessories)
        external
    {
        require(msg.sender == onboardingContract, "msg.sender is not authorized to call this function.");

        require(!avatarActivated[miladyId], "This avatar has already been activated");
        avatarActivated[miladyId] = true;

        // create the TBA for the avatar (or find it if it already exists)
        address avatarTbaAddress = tbaRegistry.createAccount(
            address(tbaAccountImpl),
            chainId,
            address(miladyAvatarContract),
            miladyId,
            0,
            ""
        );

        for (uint i=0; i<accessories.length; i++) {
            _mint(avatarTbaAddress, accessories[i], 1, "");
            miladyAvatarContract.equipSoulboundAccessory(miladyId, accessories[i]);
        }
    }

    // disable all token transfers, making these soulbound.
    function _beforeTokenTransfer(address, address from, address, uint256[] memory, uint256[] memory, bytes memory)
        internal
        override
    {
        if (from == address(0x0)) {
            return; // allow transfers from 0x0, i.e. mints
        }
        revert("These accessories are soulbound to the Milady Avatar and cannot be transferred");
    }
}