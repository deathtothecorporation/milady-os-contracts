pragma solidity ^0.8.18;

import "TokenGatedAccount/TGARegistry.sol";
import "TokenGatedAccount/TokenGatedAccount.sol";

contract MOSTGAFetcher {
    TGARegistry public tgaRegistry;
    TokenGatedAccount public tgaImpl;

    address public azimuthOwnerWrapperContractAddress;
    address public mosPillContractAddress;
    address public miladysContractAddress;
    address public avatarContractAddress;

    constructor (TGARegistry _tgaRegistry, TokenGatedAccount _tgaImpl, address _azimuthOwnerWrapperContractAddress, address _mosPillContractAddress, address _miladysContractAddress, address _avatarContractAddress) {
        tgaRegistry = _tgaRegistry;
        tgaImpl = _tgaImpl;

        azimuthOwnerWrapperContractAddress = _azimuthOwnerWrapperContractAddress;
        mosPillContractAddress = _mosPillContractAddress;
        miladysContractAddress = _miladysContractAddress;
        avatarContractAddress = _avatarContractAddress;
    }

    function calcShipTGA(uint _shipId)
        public
        view
        returns(address)
    {
        // we could take a uint32 as an argument, but it's safer to take a full uint and perform the following check.
        // this way, an agent that passes in a number that is too large to be valid will get a revert -
        // instead of a silent cast to uint32 that would result in an invalid ship, thus an inaccessible TGA.
        require(_shipId == uint32(_shipId), "shipId must be castable to uint32");
        return calcTGA(azimuthOwnerWrapperContractAddress, _shipId);
    }

    function calcMosPillTGA(uint _pillId)
        public
        view
        returns(address)
    {
        return calcTGA(mosPillContractAddress, _pillId);
    }

    function calcMiladyTGA(uint _miladyId)
        public
        view
        returns(address)
    {
        return calcTGA(miladysContractAddress, _miladyId);
    }

    function calcAvatarTGA(uint _avatarId)
        public
        view
        returns(address)
    {
        return calcTGA(avatarContractAddress, _avatarId);
    }

    function getDeployedShipTGA(uint _shipId)
        public
        view
        returns(address)
    {
        address tgaAddress = calcShipTGA(_shipId);
        if (tgaAddress.code.length != 0) {
            return tgaAddress;
        } else {
            return address(0);
        }
    }

    function getDeployedMosPillTGA(uint _pillId)
        public
        view
        returns(address)
    {
        address tgaAddress = calcMosPillTGA(_pillId);
        if (tgaAddress.code.length != 0) {
            return tgaAddress;
        } else {
            return address(0);
        }
    }

    function getDeployedMiladyTGA(uint _miladyId)
        public
        view
        returns(address)
    {
        address tgaAddress = calcMiladyTGA(_miladyId);
        if (tgaAddress.code.length != 0) {
            return tgaAddress;
        } else {
            return address(0);
        }
    }

    function getDeployedAvatarTGA(uint _avatarId)
        public
        view
        returns(address)
    {
        address tgaAddress = calcAvatarTGA(_avatarId);
        if (tgaAddress.code.length != 0) {
            return tgaAddress;
        } else {
            return address(0);
        }
    }

    function calcTGA(address _tokenContractAddress, uint _tokenId)
        public
        view
        returns(address)
    {
        return tgaRegistry.account(
            address(tgaImpl),
            block.chainid,
            _tokenContractAddress,
            _tokenId,
            0
        );
    }
}