// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC1155/ERC1155.sol";
import "openzeppelin/access/AccessControl.sol";
import "./TBA/IERC6551Registry.sol";
import "./TBA/IERC6551Account.sol";
import "./TBA/TokenBasedAccount.sol";
import "./AccessoryUtils.sol";
import "./Interfaces.sol";

contract SoulboundAccessories is ERC1155, AccessControl {
    bytes32 constant ROLE_MILADY_AUTHORITY = keccak256("MILADY_AUTHORITY");

    IMiladyAvatar public miladyAvatarContract;

    // state needed for TBA determination
    IERC6551Registry tbaRegistry;
    IERC6551Account tbaAccountImpl;
    uint chainId;

    mapping(uint => bool) public avatarActivated;

    // only used for initial deploy contract
    address deployer;

    constructor(
        address miladyAuthority,
        IERC6551Registry _tbaRegistry,
        IERC6551Account _tbaAccountImpl,
        uint _chainId,
        string memory uri_
    )
        ERC1155(uri_)
    {
        deployer = msg.sender;

        _grantRole(ROLE_MILADY_AUTHORITY, miladyAuthority);

        tbaRegistry = _tbaRegistry;
        tbaAccountImpl = _tbaAccountImpl;
        chainId = _chainId;
    }

    function setAvatarContract(IMiladyAvatar _miladyAvatarContract)
        external
    {
        require(msg.sender == deployer, "Only callable by the initial deployer");
        require(address(miladyAvatarContract) == address(0), "avatar contract already set");

        miladyAvatarContract = _miladyAvatarContract;
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
            address(tbaAccountImpl),
            chainId,
            address(miladyAvatarContract),
            miladyId,
            0,
            ""
        );

        for (uint i=0; i<accessories.length; i++) {
            _mint(avatarTbaAddress, accessories[i], 1, "");
        }
    }

    // disable all token transfers, making these soulbound.
    function _beforeTokenTransfer(address, address, address, uint256[] memory, uint256[] memory, bytes memory)
        internal
        override
    {
        revert("These accessories are soulbound to the Milady Avatar and cannot be transferred");
    }

    // Because we inherit from two contracts that define supportsInterface,
    // We resolve this by defining our own (try taking this out to see the error message)
    // We'll just return true if either of our parent contracts return true:
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl) returns (bool)
    {
        return ERC1155.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
    }

    // todo: need to do anything for uri func?
    // should we do something special if not yet activated (like forward to Milady's uri?)
}