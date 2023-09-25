// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC1155/ERC1155.sol";
import "./TGA/IERC6551Registry.sol";
import "./TGA/IERC6551Account.sol";
import "./TGA/TokenGatedAccount.sol";
import "./AccessoryUtils.sol";
import "./MiladyAvatar.sol";

contract SoulboundAccessories is ERC1155 {
    MiladyAvatar public avatarContract;

    // state needed for TBA determination
    IERC6551Registry public tbaRegistry;
    IERC6551Account public tbaAccountImpl;
    uint public chainId;

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

    function setAvatarContract(MiladyAvatar _avatarContract)
        external
    {
        require(msg.sender == deployer, "Not initial deployer");
        require(address(avatarContract) == address(0), "Avatar already set");

        avatarContract = _avatarContract;
    }

    event MiladyOnboarded(uint miladyId, uint[] accessories);

    function mintAndEquipSoulboundAccessories(uint miladyId, uint[] calldata accessories)
        external
    {
        require(msg.sender == miladyAuthority, "Not miladyAuthority");

        require(!avatarActivated[miladyId], "Avatar already activated");
        avatarActivated[miladyId] = true;

        address avatarTbaAddress = tbaRegistry.account(
            address(tbaAccountImpl),
            chainId,
            address(avatarContract),
            miladyId,
            0
        );

        uint[] memory listOf1s = new uint[](accessories.length);
        for (uint i=0; i<listOf1s.length; i++) {
            listOf1s[i] = 1;
        }

        _mintBatch(avatarTbaAddress, accessories, listOf1s, "");

        avatarContract.equipSoulboundAccessories(miladyId, accessories);

        emit MiladyOnboarded(miladyId, accessories);
    }

    // disable all token transfers, making these soulbound.
    function _beforeTokenTransfer(address, address from, address, uint256[] memory, uint256[] memory, bytes memory)
        internal
        override
    {
        if (from == address(0x0)) {
            return; // allow transfers from 0x0, i.e. mints
        }
        revert("Cannot transfer soulbound tokens");
    }
}