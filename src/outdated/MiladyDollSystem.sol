// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC721/ERC721.sol";
import "openzeppelin/token/ERC721/IERC721.sol";
import "openzeppelin/access/Ownable.sol";
// import "./TokenBasedAccount.sol";
// import "../ERC6551/TBARegistry.sol";
// import "./Miladys.sol";


// Simply sets various references in a single tx:
//  * DollContract, AccessoryContract -> Deconstructor (needed to limit minting conditions)
//  * DollContract <-> AccessoryContract (mutual reference required for equip functionality)
//  * DollContract -> TBA contracts (needed to view TBA balance)

// contract Deployer {
//     event Deployed(address miladyAccessoryContract, address miladyDollContract, address deconstructor);

//     function deploy(TBARegistry tbaRegistry, TokenBasedAccount tbaImpl, Miladys miladyContract, uint chainID)
//         public
//         returns (MiladyAccessory, MiladyDoll, MiladyDeconstructor)
//     {
//         MiladyAccessory accessoryContract = new MiladyAccessory();
//         MiladyDoll dollContract = new MiladyDoll(tbaRegistry, tbaImpl);
//         MiladyDeconstructor deconstructor = new MiladyDeconstructor(miladyContract, dollContract, accessoryContract, chainID);

//         dollContract.transferOwnership(address(deconstructor));
//         accessoryContract.transferOwnership(address(deconstructor));

//         dollContract.setMiladyAccessoryContract(accessoryContract);
//         accessoryContract.setMiladyDollContract(dollContract);

//         return (accessoryContract, dollContract, deconstructor);
//     }
// }