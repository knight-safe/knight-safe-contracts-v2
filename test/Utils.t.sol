// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Cast} from "@/utils/Cast.sol";

contract UtilTest is Test {
    using Cast for address;

    function test_ToBytes32_Success() public {
        address value = address(0x1234567890123456789012345678901234567890);
        bytes32 expected = bytes32(uint256(uint160(value)));

        bytes32 result = Cast._toBytes32(value);

        assertEq(result, expected);
    }
}
