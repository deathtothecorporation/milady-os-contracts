// SPDX-License-Identifier: UNLICENSED

/* solhint-disable private-vars-leading-underscore */

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Metadata.sol";

contract MetadataTest is Test {
    MiladyMetadata metadata;

    address[] lotsOfAddresses;

    function setUp() external {
        metadata = new MiladyMetadata();

        for (uint i=0; i<10000; i++)
        {
            lotsOfAddresses.push(address(uint160(i)));
        }
    }

    function test_populate() external {
        metadata.populate(
            0,
            lotsOfAddresses
        );
    }
}