// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC721/IERC721.sol";
import "openzeppelin/utils/math/SafeMath.sol";
import "./TokenBasedAccount.sol";
import "../ERC6551/IERC6551Registry.sol";
import "../ERC6551/IERC6551Account.sol";
import "./Miladys.sol";

contract MiladyAvatar is IERC721 {
    Miladys miladysContract;
    
    // state needed for TBA determination
    IERC6551Registry tbaRegistry;
    IERC6551Account tbaAccountImpl;
    uint chainId;

    constructor(Miladys _miladysContract, IERC6551Registry _tbaRegistry, IERC6551Account _tbaAccountImpl, uint _chainId) {
        miladysContract = _miladysContract;
        tbaRegistry = _tbaRegistry;
        tbaAccountImpl = _tbaAccountImpl;
        chainId = _chainId;
    }

    function balanceOf(address owner) external view returns (uint256 balance) {
        return 0;
    }
    function ownerOf(uint256 tokenId) external view returns (address owner) {
        return tbaRegistry.account(address(tbaAccountImpl), chainId, address(miladysContract), tokenId, 0);
    }
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external {
        revertWithSoulboundMessage();
    }
    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        revertWithSoulboundMessage();
    }
    function transferFrom(address from, address to, uint256 tokenId) external {
        revertWithSoulboundMessage();
    }
    function approve(address to, uint256 tokenId) external {
        revertWithSoulboundMessage();
    }
    function setApprovalForAll(address operator, bool approved) external {
        revertWithSoulboundMessage();
    }
    function getApproved(uint256 tokenId) external view returns (address operator) {
        revert("Milady Dolls cannot be moved from their soulbound Milady.");
    }
    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        return false;
    }
    function revertWithSoulboundMessage() pure internal {
        revert("Milady Dolls cannot be moved from their soulbound Milady.");
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC721).interfaceId;
    }
}