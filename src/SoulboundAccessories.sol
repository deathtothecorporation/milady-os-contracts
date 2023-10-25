/* solhint-disable private-vars-leading-underscore */

pragma solidity 0.8.18;

import "openzeppelin/token/ERC1155/ERC1155.sol";
import "TokenGatedAccount/IERC6551Registry.sol";
import "TokenGatedAccount/IERC6551Account.sol";
import "TokenGatedAccount/TokenGatedAccount.sol";
import "openzeppelin/access/Ownable.sol";
import "./MiladyAvatar.sol";

contract SoulboundAccessories is ERC1155, Ownable {
    MiladyAvatar public avatarContract;

    // state needed for TGA address calculation
    IERC6551Registry public immutable tgaRegistry;
    IERC6551Account public immutable tgaAccountImpl;

    address public miladyAuthority;

    // indexed by miladyId
    mapping(uint => bool) public avatarActivated;

    address immutable initialDeployer;

    constructor(
        IERC6551Registry _tgaRegistry,
        IERC6551Account _tgaAccountImpl,
        address _miladyAuthority,
        string memory uri_
    )
        ERC1155(uri_)
    {
        initialDeployer = msg.sender;

        tgaRegistry = _tgaRegistry;
        tgaAccountImpl = _tgaAccountImpl;

        miladyAuthority = _miladyAuthority;
    }

    function setAvatarContract(MiladyAvatar _avatarContract)
        external
    {
        require(msg.sender == initialDeployer, "Not initial deployer");
        require(address(avatarContract) == address(0), "Avatar already set");

        avatarContract = _avatarContract;
    }

    function changeMiladyAuthority(address _newMiladyAuthority)
        external
        onlyOwner()
    {
        miladyAuthority = _newMiladyAuthority;
    }

    event SoulboundAccessoriesMinted(uint indexed miladyId, uint[] indexed accessories);

    // we assume here that miladyAuthority will never specify an accessory whose decoded accVariant == 0
    function mintAndEquipSoulboundAccessories(uint _miladyId, uint[] calldata _accessories)
        external
    {
        require(msg.sender == miladyAuthority, "Not miladyAuthority");

        // perhaps not strictly necessary, but might prevent the miladyAuthority server doing something stupid
        require(_accessories.length > 0, "empty accessories array");

        require(!avatarActivated[_miladyId], "Avatar already activated");
        avatarActivated[_miladyId] = true;

        address avatarTbaAddress = tgaRegistry.account(
            address(tgaAccountImpl),
            block.chainid,
            address(avatarContract),
            _miladyId,
            0
        );

        uint[] memory listOf1s = new uint[](_accessories.length);
        for (uint i=0; i<listOf1s.length;) {
            listOf1s[i] = 1;

            unchecked { i++; }
        }

        _mintBatch(avatarTbaAddress, _accessories, listOf1s, "");

        avatarContract.equipSoulboundAccessories(_miladyId, _accessories);

        emit SoulboundAccessoriesMinted(_miladyId, _accessories);
    }

    // This function is included as a last-resort option to leverage, in case the miladyAuthority key has been compromised.
    // It allows the owner to reverse any damage done by the key, by unminting and unequipping any erroneous soulboundAccessories.
    function unmintAndUnequipSoulboundAccessories(uint _miladyId, uint[] calldata _accessories)
        external
        onlyOwner()
    {
        require(avatarActivated[_miladyId], "Avatar not activated");
        avatarActivated[_miladyId] = false;

        address avatarTbaAddress = tgaRegistry.account(
            address(tgaAccountImpl),
            block.chainid,
            address(avatarContract),
            _miladyId,
            0
        );

        uint[] memory listOf1s = new uint[](_accessories.length);
        for (uint i=0; i<listOf1s.length;) {
            listOf1s[i] = 1;

            unchecked { i++; }
        }

        _burnBatch(avatarTbaAddress, _accessories, listOf1s);

        avatarContract.unequipSoulboundAccessories(_miladyId, _accessories);
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