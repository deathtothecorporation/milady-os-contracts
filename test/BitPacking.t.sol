/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./MiladyOSTestBase.sol";

contract BitPacking is MiladyOSTestBase {
    function test_packBackAndForth(uint accessoryId) public {
        (uint128 accType, uint128 accVariant) = avatarContract.accessoryIdToTypeAndVariantIds(accessoryId);
        uint recoveredId = avatarContract.typeAndVariantIdsToAccessoryId(accType, accVariant);

        require(recoveredId == accessoryId);
    }
}