// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/AccessoryUtils.sol";

contract BitPacking is Test {
    function test_packBackAndForth(uint accessoryId) public {
        (uint128 accType, uint128 accVariant) = AccessoryUtils.idToTypeAndVariantHashes(accessoryId);
        uint recoveredId = AccessoryUtils.typeAndVariantHashesToId(accType, accVariant);

        require(recoveredId == accessoryId);
    }
}