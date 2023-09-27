# Milady OS Contracts

Milady OS (mOS) is to be an Urbit app where Milady holders can change the dress state of their Milady by equipping/unequipping different clothing items, and where doing so will affect the visual representation of the user's avatar as well as the kinds of communication channels available to them.

This repo is focused only on the smart contracts underlying such a system, which supports the above equip/unequip functionality as well as financial incentives to have popular items equipped - funded from a 10% buy/sell spread across a bonding curve.

### Terms

* **MiladyMaker** - The original NFT set of 9998 "Miladys" (or one item in the set, depending on context), of which this project is a derivative of. [Contract](https://etherscan.io/address/0x5af0d9827e0c53e4799bb226655a1de152a425a5).
* **Metadata** - the set of attributes defined as canonically "part of" the original MiladyMaker NFT. This maps to `Accessories`, defined below.

## Avatars

An `Avatar`, defined in `MiladyAvatar.sol`, is an NFT set that is soulbound to the TBAs of the MiladyMaker NFTs. This NFT set is defined "by fiat", and involves no minting. Instead, some of the IERC721 functions can be deduced without additional state - for example, the `ownerOf` an Avatar is always the TBA of the MiladyMaker with the same token ID, and the `balanceOf` for the Avatar NFT contract is simply 1 if the target address is a MiladyMaker TBA, and 0 otherwise. The rest of the IERC721 functions, having to do with transfers, simply revert, making it soulbound to the MiladyMaker TBA.

This contract is also where the main equip/unequip functionality is defined. For a given accessory type, only one accessory can be equipped at once; any existing equipped item will be unequipped if another one is equipped in its place. Equipping and unequipping items registers and deregisters the Milady from participating in revenue sharing for when a `LiquidAccessory` is minted, as discussed below.

## Accessories

An `Accessory` is an ERC1155 NFT that represents some particular clothing or accessory item which could be found in the metadata for a given Milady (see the "attributes" from [this example](https://www.miladymaker.net/milady/json/2751)).

An accessory's NFT ID is deterministic with regard to its type and variant IDs. These type/variant IDs, in turn, can be determined by hashing the strings for the "trait_type" and "value" fields in the metadata. `AccessoryUtils.sol` defines the relevant transformations of these data types, and can be treated as a reference implementation for off-chain transformation between these data types.

Accessories are either soulbound or liquid, but share this ID scheme, as well as the "equip space" of an Avatar.

### Soulbound Accessories

`Soulbound Accessories` (`SoulboundAccessories.sol`) represent the initial set of accessories that "came with" a given Milady - in other words, the accessories listed at the above endpoint for a given Milady, and displayed as part of the canonical MiladyMaker image. These accessories cannot be sent away from the Avatar's TBA.

During or before onboarding of a particular MiladyMaker holder, a server holding a key authorized as `ROLE_MILADY_AUTHORITY` is expected to call `onboardMilady` with a set of `uint256` IDs. This uploads the "missing metadata" onto the EVM as a set of `uint256`s, encoded as described in `AccessoryUtils.sol`.

### Liquid Accessories

`Liquid Accessories` (`LiquidAccessories.sol`) can be freely minted by anyone from an accessory-specific bonding curve, with a 10% spread between buy and sell prices for a given existing supply of that particular item. Revenue is taken from this action and split between an external fee capture address, and a `Rewards` contract, leaving enough in the contract to at any time buy back the entire supply of all items.

## Rewards

`Rewards.sol` takes revenue from the minting of new Liquid Accessories and accrues them to Avatars that have that particular item equipped. Given X ETH accrued in this way, and N Avatars with that item equipped, X/N is earmarked for future claims by that Avatar. These rewards can be claimed manually, and are also automatically disbursed upon unequipping of an accessory.

# Notes

* If a user wants to claim all claimable rewards for their Milady across all equipped items, the interface/app is expected to track/enumerate this set of equipped items off-chain. This set is then passed into `Rewards.claimRewardsForMilady` as a list.
* This system of contracts has no conception of which types of accessories are canonical versus non-canonical, for both item categories and item variants. Thus, an agent could in theory mint any item they want (a blue mood ring, a halo, etc.) without regard for whether it was ever seen in the original Milady Maker set - and even equip it and earn rewards from other users minting that item.
  * Rather than attempt to constrain this behavior in Solidity/Ethereum, the Milady OS app and interfaces will simply ignore items it does not recognize as canonical, both for purposes of rendering and gating comms and chat. This leaves the door open in the future for adding to the set of supported items, without having to update the contracts.

# Goerli Addresses (for internal testing)

Will try to keep these updated! These are all on Goerli and verified.

* [fakeMiladys](https://goerli.etherscan.io/address/0xd0d0ec651a9FF604E9E44Ed02C5799d641024D6F#code)
  * This is nothing more than an ERC721 contract that allows anyone to freely mint, which the rest of the system considers Miladys. To get one of these, call the "gimme" function on etherscan, and a fresh fake Milady will be sent to the wallet that initiates the transaction.
* [TBARegistry](https://goerli.etherscan.io/address/0x4584DbF0510E86Dcc2F36038C6473b1a0FC5Aef3#code)
* [TokenGatedAccount](https://goerli.etherscan.io/address/0x67d12C4dB022c543cb7a678F882eDc935B898940#code)
* [Rewards](https://goerli.etherscan.io/address/0xAd6e965DB39DcD028B6B9088482794Dbeecb57Bd#code)
* [MiladyAvatar](https://goerli.etherscan.io/address/0xa75d842b3Dd775C7310AD6D4E6154b5723B222CF#code)
* [LiquidAccessories](https://goerli.etherscan.io/address/0xd960e80251f965204028382c52046D9b1988f177#code)
* [SoulboundAccessories](https://goerli.etherscan.io/address/0xE417BB57a2dAf3f5c24F507EFF81345506D1B85e#code)
* [Rewards](https://goerli.etherscan.io/address/0xAd6e965DB39DcD028B6B9088482794Dbeecb57Bd#code)

`revenueRecipient` and `miladyAuthority` are both currently Logan's address: 0xBB5eb03535FA2bCFe9FE3BBb0F9cC48385818d92. Contact him if you need to test out the soulboundAccessories stuff, as this involves a permissioned call to SoulboundAccessoires from `miladyAuthority`.