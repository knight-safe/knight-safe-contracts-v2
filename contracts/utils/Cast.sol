// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

library Cast {
    function _toBytes32(address value) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(value)));
    }
}
