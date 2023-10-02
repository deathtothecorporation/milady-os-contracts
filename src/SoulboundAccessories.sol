/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC1155/ERC1155.sol";
import "./TGA/IERC6551Registry.sol";
import "./TGA/IERC6551Account.sol";
import "./TGA/TokenGatedAccount.sol";
import "./MiladyAvatar.sol";

contract SoulboundAccessories is ERC1155 {
    MiladyAvatar public avatarContract;

    // state needed for TBA address calculation
    IERC6551Registry public tbaRegistry;
    IERC6551Account public tbaAccountImpl;

    address public miladyAuthority;

    mapping(uint => bool) public avatarActivated;

    address deployer;

    constructor(
        IERC6551Registry _tbaRegistry,
        IERC6551Account _tbaAccountImpl,
        address _miladyAuthority,
        string memory uri_
    )
        ERC1155(uri_)
    {
        deployer = msg.sender;

        tbaRegistry = _tbaRegistry;
        tbaAccountImpl = _tbaAccountImpl;

        miladyAuthority = _miladyAuthority;
    }

    function setAvatarContract(MiladyAvatar _avatarContract)
        external
    {
        require(msg.sender == deployer, "Not initial deployer");
        require(address(avatarContract) == address(0), "Avatar already set");

        avatarContract = _avatarContract;
    }

    event SoulboundAccessoriesMinted(uint indexed miladyId, uint[] indexed accessories);

    // we assume here that miladyAuthority will never specify an accessory whose decoded accVariant == 0
    function mintAndEquipSoulboundAccessories(uint _miladyId, uint[] calldata _accessories)
        external
    {
        require(msg.sender == miladyAuthority, "Not miladyAuthority");

        require(!avatarActivated[_miladyId], "Avatar already activated");
        avatarActivated[_miladyId] = true;

        address avatarTbaAddress = tbaRegistry.account(
            address(tbaAccountImpl),
            block.chainid,
            address(avatarContract),
            _miladyId,
            0
        );

        uint[] memory listOf1s = new uint[](_accessories.length);
        for (uint i=0; i<listOf1s.length; i++) {
            listOf1s[i] = 1;
        }

        _mintBatch(avatarTbaAddress, _accessories, listOf1s, "");

        avatarContract.equipSoulboundAccessories(_miladyId, _accessories);

        emit SoulboundAccessoriesMinted(_miladyId, _accessories);
    }

    // disable all token transfers, making these soulbound.
    function _beforeTokenTransfer(address, address _from, address, uint256[] memory, uint256[] memory, bytes memory)
        internal
        override
    {
        if (_from == address(0x0)) {
            return; // allow transfers from 0x0, i.e. mints
        }
        revert("Cannot transfer soulbound tokens");
    }

    // prevents spurious approvals
    function _setApprovalForAll(address, address, bool) 
        internal 
        override {
            revert("Cannot approve soulbound tokens");
    }
}