// This contract is a only slightly modified version of the reference implementation of a TokanBasedAccount form [EIP 6551](https://eips.ethereum.org/EIPS/eip-6551).

// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.13;

import "openzeppelin/utils/introspection/IERC165.sol";
import "openzeppelin/token/ERC721/IERC721.sol";
import "openzeppelin/interfaces/IERC1271.sol";
import "openzeppelin/token/ERC1155/IERC1155Receiver.sol";
import "openzeppelin/utils/cryptography/SignatureChecker.sol";
import "sstore2/utils/Bytecode.sol";
import "./IERC6551Account.sol";

// todo: should this also be a 721 receiver?

contract TokenGatedAccount is IERC165, IERC1271, IERC6551Account, IERC1155Receiver {
    address public bondedAddress;
    address public tokenOwnerAtLastBond;

    // ensures the msg.sender is either:
    //  * the token owner
    //  * the bonded account - UNLESS owner() has changed since that bond call
    modifier onlyAuthorizedMsgSender() {
        require(msg.sender == owner() || (msg.sender == bondedAddress && tokenOwnerAtLastBond == owner()), "Unauthorized caller");
        _;
    }

    event NewBondedAddress(address indexed _newBondedAddress);

    // Note that we the bonded address can pass this bond on without authorization from owner()
    function bond(address _addressToBond) 
        external
        onlyAuthorizedMsgSender()
    {
        bondedAddress = _addressToBond;
        tokenOwnerAtLastBond = owner();

        emit NewBondedAddress(_addressToBond);
    }

    uint _nonce;

    receive() external payable {}

    function executeCall(address _to, uint256 _value, bytes calldata _data)
        external
        payable
        onlyAuthorizedMsgSender()
        returns (bytes memory result)
    {
        _nonce += 1;

        bool success;
        (success, result) = _to.call{value: _value}(_data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function token()
        external
        view
        returns (
            uint256 _chainId,
            address _tokenContract,
            uint256 _tokenId
        )
    {
        uint256 length = address(this).code.length;
        return
            abi.decode(
                Bytecode.codeAt(address(this), length - 0x60, length),
                (uint256, address, uint256)
            );
    }

    function owner() public view returns (address) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = this.token();
        if (chainId != block.chainid) return address(0);

        return IERC721(tokenContract).ownerOf(tokenId);
    }

    function supportsInterface(bytes4 _interfaceId) public pure returns (bool) {
        return (_interfaceId == type(IERC165).interfaceId ||
            _interfaceId == type(IERC6551Account).interfaceId);
    }

    function isValidSignature(bytes32 _hash, bytes memory _signature)
        external
        view
        returns (bytes4 magicValue)
    {
        bool isValid = SignatureChecker.isValidSignatureNow(
            owner(),
            _hash,
            _signature
        );

        if (isValid) {
            return IERC1271.isValidSignature.selector;
        }

        return "";
    }

    function nonce() external view returns (uint) {
        return _nonce;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }
}
