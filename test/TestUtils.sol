/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC721/IERC721.sol";
import "TokenGatedAccount/TBARegistry.sol";
import "TokenGatedAccount/TokenGatedAccount.sol";

contract TestUtils {
    TBARegistry tbaRegistry;
    TokenGatedAccount tbaAccountImpl;

    constructor(TBARegistry _tbaRegistry, TokenGatedAccount _tbaAccountImpl) {
        tbaRegistry = _tbaRegistry;
        tbaAccountImpl = _tbaAccountImpl;
    }

    function createTGA(IERC721 tokenContract, uint tokenId)
        public
        returns(address payable)
    {
        return payable(tbaRegistry.createAccount(
            address(tbaAccountImpl),
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
        return payable(tbaRegistry.account(
            address(tbaAccountImpl),
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
        return tbaRegistry.registeredAccounts(addr);
    }
        
}