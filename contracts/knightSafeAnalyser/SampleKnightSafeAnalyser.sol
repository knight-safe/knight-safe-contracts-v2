// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./BaseKnightSafeAnalyser.sol";

abstract contract SampleKnightSafeAnalyser is BaseKnightSafeAnalyser {
    function extractAddresses(address to, bytes memory data) public pure returns (address[] memory) {
        bytes4 selector = getSelector(data);
        if (selector == 0x12345678) {
            address[] memory rv = new address[](1);
            rv[0] = address(0);
            return rv;
        } else if (selector == 0x11111111) {
            address[] memory rv = new address[](2);
            rv[0] = 0x1111111111111111111111111111111111111111;
            rv[1] = 0x2222222222222222222222222222222222222222;
            return rv;
        } else {
            address[] memory rv = new address[](1);
            rv[0] = to;
            return rv;
        }
    }

    function extractAddressesWithValue(address to, bytes memory data)
        public
        pure
        returns (address[] memory, uint256[] memory)
    {
        bytes4 selector = getSelector(data);
        if (selector == 0x12345678) {
            address[] memory rv1 = new address[](1);
            uint256[] memory rv2 = new uint256[](1);
            uint256[] memory rv3 = new uint256[](1);
            rv1[0] = address(0);
            rv2[0] = 0;
            rv3[0] = 0;
            return (rv1, rv2);
        } else {
            address[] memory rv1 = new address[](1);
            uint256[] memory rv2 = new uint256[](1);
            uint256[] memory rv3 = new uint256[](1);
            rv1[0] = to;
            rv2[0] = 0;
            rv3[0] = 0;
            return (rv1, rv2);
        }
    }
}
