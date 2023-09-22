// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC1155/ERC1155.sol";
import "./TBA/IERC6551Registry.sol";
import "./TBA/IERC6551Account.sol";
import "./TBA/TokenGatedAccount.sol";
import "./AccessoryUtils.sol";
import "./MiladyAvatar.sol";

contract SoulboundAccessories is ERC1155 {
    MiladyAvatar public miladyAvatarContract;

    // state needed for TBA determination
    IERC6551Registry tbaRegistry;
    IERC6551Account tbaAccountImpl;
    uint chainId;

    address public miladyAuthority;

    mapping(uint => bool) public avatarActivated;

    // only used for initial deploy
    address deployer;

    constructor(
        IERC6551Registry _tbaRegistry,
        IERC6551Account _tbaAccountImpl,
        uint _chainId,
        address _miladyAuthority,
        string memory uri_
    )
        ERC1155(uri_)
    {
        deployer = msg.sender;

        tbaRegistry = _tbaRegistry;
        tbaAccountImpl = _tbaAccountImpl;
        chainId = _chainId;

        miladyAuthority = _miladyAuthority;
    }

    function setAvatarContract(MiladyAvatar _miladyAvatarContract)
        external
    {
        require(msg.sender == deployer, "Not initial deployer");
        require(address(miladyAvatarContract) == address(0), "Avatar already set");

        miladyAvatarContract = _miladyAvatarContract;

        // Todo : @Logan @Schalk, put in an event here? Or is it not necessary?
    }

    function mintAndEquipSoulboundAccessories(uint miladyId, uint[] calldata accessories)
        external
    {
        require(msg.sender == miladyAuthority, "Not miladyAuthority");

        require(!avatarActivated[miladyId], "Avatar already activated");
        avatarActivated[miladyId] = true;

        address avatarTbaAddress = tbaRegistry.account(
            address(tbaAccountImpl),
            chainId,
            address(miladyAvatarContract),
            miladyId,
            0
        );

        for (uint i=0; i<accessories.length; i++) {
            _mint(avatarTbaAddress, accessories[i], 1, "");
            miladyAvatarContract.equipSoulboundAccessory(miladyId, accessories[i]);
        }

        // Todo : @Logan <| Event here?
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