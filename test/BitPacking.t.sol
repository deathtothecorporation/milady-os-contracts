// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/AccessoryBase.sol";

contract BitPacking is Test {
    function test_packBackAndForth(uint accessoryId) public {
        AccessoryBase b = new AccessoryBase("");

        (uint128 accType, uint128 accVariant) = b.idToTypeAndVariant(accessoryId);
        uint recoveredId = b.typeAndVariantToId(accType, accVariant);

        require(recoveredId == accessoryId);
    }
}