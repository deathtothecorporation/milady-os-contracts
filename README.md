# Milady OS Contracts

Milady OS (mOS) is to be an Urbit app where Milady holders can change the dress state of their Milady by equipping/unequipping different clothing items, and where doing so will affect the visual representation of the user's avatar as well as the kinds of communication channels available to them.

This repo is focused only on the smart contracts underlying such a system, which supports the above equip/unequip functionality as well as financial incentives to have popular items equipped - funded from a 10% buy/sell spread across a bonding curve.

### Terms

* **MiladyMaker** - The original NFT set of 9998 "Miladys" (or one item in the set, depending on context), of which this project is a derivative of. [Contract](https://etherscan.io/address/0x5af0d9827e0c53e4799bb226655a1de152a425a5).
* **Metadata** - the set of attributes defined as canonically "part of" the original MiladyMaker NFT. This maps to `Accessories`, defined below.
* **Avatar** - A "reflective NFT" that is defined as soulbound to the MiladyMaker with the same ID, defined in more detail below.

# TBA Structure

As described in more detail below, there are two levels of TBAs at work here:

* Each MiladyMaker has a TBA which holds (by definition) its own Avatar.
* Each Avatar has a TBA which holds some number of Accessories.
* Some number of these Accessories may be considered "equipped" by its owning Avatar.

## Avatars

An `Avatar` (`MiladyAvatar.sol`), is an NFT set defined as soulbound to the TBAs of the MiladyMaker NFTs. This NFT can be thought of as a "reflective NFT", and is a way of creating new state that follows the original MiladyMaker NFT around.

See the `ownerOf` and `balanceOf` functions to see how this works. The former is defined as always the TBA of the Milady with the same id; the latter is simply 1 if the address being queried is a Milady TBA, and 0 otherwise. All other NFT functionality reverts, resulting in its being soulbound to the Milady TBA.

## Accessories

An `Accessory` is an ERC1155 NFT that represents some particular clothing or accessory item which could be found in the metadata for a given Milady (see the "attributes" from [this example](https://www.miladymaker.net/milady/json/2751)). Each such accessory can be deconstructed into its `type` and `variant`. As an example, we might have a red hat as an accessory, which then has a `type` of "hat" and variant of "red hat"; another item that shares the type (like a blue hat) can thus not be equipped at the same time as the first item.

An accessory's ERC1155 ID is deterministic with regard to its type and variant IDs. These type/variant IDs, in turn, can be determined by hashing strings for the type and variant; in the [metadata](https://www.miladymaker.net/milady/json/2751) these are labeled "trait_type" and "value" respectively. `AccessoryUtils.sol` defines the relevant transformations of these data types, and can be treated as a reference implementation for off-chain transformation between these data types.

The interface is expected to hold a mapping from type/variant identifiers (which are hashes) back to the input string, so as to read the former from the contract state and turn this into a user-meaningful string.

Accessories are either soulbound or liquid (see below), but share this ID scheme, as well as the "equip space" of an Avatar.

## Equipping

`Avatar.sol` is also where the main equip/unequip functionality is defined.

* For an accessory to be equippable, it must be currently held in the Avatar's TBA, and sending away all instances of a given accessory automatically unequips it during transfer (see `LiquidAccessories._beforeTokenTransfer`). Thus, an Avatar should never have an item equipped that it does not own.
* For a given accessory type, only one accessory can be equipped at once; any existing equipped item will be unequipped if another one is equipped in its place. See the mapping `Avatar.equipSlots`.
* Equipping/unequipping items registers/deregisters the Milady from participating in revenue sharing for when a `LiquidAccessory` is minted, as discussed below; this can be seen in `Rewards.registerMiladyForRewardsForAccessory` and `Rewards.deregisterMiladyForRewardsForAccessoryAndClaim`, which is only called during the Avatar's equip/unequip functions.

### Soulbound Accessories

`Soulbound Accessories` (`SoulboundAccessories.sol`) represent the initial set of accessories that "came with" a given Milady - in other words, the accessories listed in that Milady's metadata and displayed as part of the canonical MiladyMaker image. These accessories cannot be sent away from the Avatar's TBA.

During or before onboarding of a particular MiladyMaker holder, a server holding a key authorized as `ROLE_MILADY_AUTHORITY` is expected to call `onboardMilady` with a set of `uint256` IDs. This uploads the "missing metadata" onto the EVM as a set of `uint256`s, encoded as described in `AccessoryUtils.sol` and described in the previous section. The result of this action is to mint a set of 1155s into the Avatar's TBA and equip them, so that after onboarding the user's Milady is dressed up as its canonical, original MiladyMaker visual appearance.

### Liquid Accessories

`Liquid Accessories` (`LiquidAccessories.sol`) can be freely minted by anyone from an accessory-specific bonding curve.

We define the buy-back bonding curve first, as buy-back price = P * supply^2 + 0.005 ETH, where supply is the given liquid supply of that particular accessory, and P is a parameter set for each item by the owner of the LiquidAccessories contract (if the parameter is unset, minting cannot occur). Having defined the buy-back price thusly, the actual mint price is defined as 20% above that.

Upon minting, revenue is taken from this 20% spread and split between an external fee capture address, and a `Rewards` contract. The `LiquidAccessories` contract always retains enough of a balance to buy back all outstanding tokens at the buy-back price.

## Rewards

`Rewards.sol` takes revenue from the minting of new Liquid Accessories and accrues them to Avatars that have that particular item equipped. Given X ETH accrued in this way since a given Avatar had equipped that item, and N Avatars with that item currently equipped, the Avatar holder can claim X/N at any time via the `Rewards` claim functions. Claiming also happens automatically upon unequipping of an accessory.

If a user wants to claim all claimable rewards for their Milady across all equipped items, the interface is expected to track/enumerate this set of equipped items off-chain. This set is then passed into `Rewards.claimRewardsForMilady` as a list.

# Running 'forge test'
* To run 'forge test' successfully, you will need to enter a node RPC endpoint.
  * You need to do this by following the instructions in .env.template