/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC721/IERC721.sol";
import "TokenGatedAccount/TGARegistry.sol";
import "TokenGatedAccount/TokenGatedAccount.sol";

contract TestUtils {
    TGARegistry tgaRegistry;
    TokenGatedAccount tgaAccountImpl;

    constructor(TGARegistry _tgaRegistry, TokenGatedAccount _tgaAccountImpl) {
        tgaRegistry = _tgaRegistry;
        tgaAccountImpl = _tgaAccountImpl;
    }

    function createTGA(IERC721 tokenContract, uint tokenId)
        public
        returns(address payable)
    {
        return payable(tgaRegistry.createAccount(
            address(tgaAccountImpl),
            block.chainid, 
            address(tokenContract),
            tokenId,
            0,
            ""
        ));
    }

    function getTGA(IERC721 tokenContract, uint tokenId)
        public
        returns (TokenGatedAccount)
    {
        return TokenGatedAccount(getTgaAddress(tokenContract, tokenId));
    }

    function getTgaAddress(IERC721 tokenContract, uint tokenId)
        public
        returns(address payable)
    {
        return payable(tgaRegistry.account(
            address(tgaAccountImpl),
            block.chainid, 
            address(tokenContract),
            tokenId,
            0
        ));
    }

    function tgaReverseLookup(address addr)
        public
        returns (address tokenAddress, uint tokenId)
    {
        return tgaRegistry.registeredAccounts(addr);
    }
        
}