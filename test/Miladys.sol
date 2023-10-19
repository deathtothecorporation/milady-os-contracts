// The below is taken from the canonical Milady Maker contract, pulled from etherscan.
// It was then lightly modified to compile with a later version of Solidity and openzeppelin contracts.
// Used only for testing our code against a "real" Milady system;
// the code below is not meant for production and is not deployed as part of the MiladyOS system.

import "openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin/access/Ownable.sol";
import "openzeppelin/utils/math/SafeMath.sol";

pragma solidity 0.8.18;

/**
 * @title Miladys contract
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */
contract Miladys is ERC721Enumerable, Ownable {
    using SafeMath for uint256;

    string public MILADY_PROVENANCE = "";
    uint public constant maxMiladyPurchase = 30;
    uint256 public constant MAX_MILADYS = 9500;
    bool public saleIsActive = false;
    uint256 public standardMiladyCount = 0;
    
    mapping(address => bool) public whitelistOneMint;
    mapping(address => bool) public whitelistTwoMint;

    constructor() ERC721("Milady", "MIL") {
    }
    
    function setProvenanceHash(string memory provenanceHash) public onlyOwner {
        MILADY_PROVENANCE = provenanceHash;
    }
    
    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
    function editWhitelistOne(address[] memory array) public onlyOwner {
        for(uint256 i = 0; i < array.length; i++) {
            address addressElement = array[i];
            whitelistOneMint[addressElement] = true;
        } 
    }

    function editWhitelistTwo(address[] memory array) public onlyOwner {
        for(uint256 i = 0; i < array.length; i++) {
            address addressElement = array[i];
            whitelistTwoMint[addressElement] = true;
        } 
    }

    function reserveMintMiladys() public {
        require(whitelistTwoMint[msg.sender] || whitelistOneMint[msg.sender], "sender not whitelisted");
        uint mintAmount;
        if (whitelistTwoMint[msg.sender]) {
            whitelistTwoMint[msg.sender] = false;
            mintAmount = 2;
        } else {
            whitelistOneMint[msg.sender] = false;
            mintAmount = 1;
        }
        uint i;
        for (i = 0; i < mintAmount && totalSupply() < 10000; i++) {
            uint supply = totalSupply();
            _safeMint(msg.sender, supply);
        }
    }
    
    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }

    function mintMiladys(uint256 numberOfTokens) public payable {
        require(saleIsActive, "Sale must be active to mint Miladys");
        require(numberOfTokens <= maxMiladyPurchase, "Can only mint up to 30 tokens at a time");
        require(standardMiladyCount.add(numberOfTokens) <= MAX_MILADYS, "Purchase would exceed max supply of Miladys");
        uint256 miladyPrice;
        if (numberOfTokens == 30) {
            miladyPrice = 60000000000000000; // 0.06 ETH
            require(miladyPrice.mul(numberOfTokens) <= msg.value, "Ether value sent is not correct");
        } else if (numberOfTokens >= 15) {
            miladyPrice = 70000000000000000; // 0.07 ETH
            require(miladyPrice.mul(numberOfTokens) <= msg.value, "Ether value sent is not correct");
        } else if (numberOfTokens >= 5) {
            miladyPrice = 75000000000000000; // 0.075 ETH
            require(miladyPrice.mul(numberOfTokens) <= msg.value, "Ether value sent is not correct");
        } else {
            miladyPrice = 80000000000000000; // 0.08 ETH
            require(miladyPrice.mul(numberOfTokens) <= msg.value, "Ether value sent is not correct");
        }

        for(uint i = 0; i < numberOfTokens; i++) {
            if (standardMiladyCount < MAX_MILADYS) {
                _safeMint(msg.sender, totalSupply());
                standardMiladyCount++;
            }
        }
    }

}