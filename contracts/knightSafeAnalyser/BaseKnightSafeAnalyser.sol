// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "../interfaces/IKnightSafeAnalyser.sol";

abstract contract BaseKnightSafeAnalyser is IERC165, IKnightSafeAnalyser {
    function getSelector(bytes memory data) public pure returns (bytes4 selector) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            selector := mload(add(data, add(0x20, 0)))
        }
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IKnightSafeAnalyser).interfaceId;
    }
}
