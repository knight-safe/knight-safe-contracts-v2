// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IKnightSafeAnalyser} from "../interfaces/IKnightSafeAnalyser.sol";

/// BaseKnightSafeAnalyser, inherit from IERC165 and IKnightSafeAnalyser
abstract contract BaseKnightSafeAnalyser is IERC165, IKnightSafeAnalyser {
    error UnsupportedCommand();
    error Unauthorized(string role);

    function getSelector(bytes memory data) public pure returns (bytes4 selector) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            selector := mload(add(data, add(0x20, 0)))
        }
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IKnightSafeAnalyser).interfaceId;
    }

    function _getBytes32FromBytes(bytes calldata _bytes, uint256 _arg) internal pure returns (bytes32 value) {
        /* solhint-disable no-inline-assembly */
        assembly {
            value := calldataload(add(add(_bytes.offset, shl(5, _arg)), 4))
        }
    }

    function _getAddressFromBytes(bytes calldata _bytes, uint256 _arg) internal pure returns (address addr) {
        /* solhint-disable no-inline-assembly */
        assembly {
            addr := calldataload(add(add(_bytes.offset, shl(5, _arg)), 4))
        }
    }

    function _getUintFromBytes(bytes calldata _bytes, uint256 _arg) internal pure returns (uint256 value) {
        /* solhint-disable no-inline-assembly */
        assembly {
            value := calldataload(add(add(_bytes.offset, shl(5, _arg)), 4))
        }
    }

    function _getBoolFromBytes(bytes calldata _bytes, uint256 pos) internal pure returns (bool rv) {
        /* solhint-disable no-inline-assembly */
        assembly {
            rv := calldataload(add(add(_bytes.offset, shl(5, pos)), 4))
        }
    }

    function _getAddressArray(bytes calldata _bytes, uint256 pos) internal pure returns (address[] calldata rv) {
        /* solhint-disable no-inline-assembly */
        assembly {
            let lengthPtr := add(add(_bytes.offset, calldataload(add(add(_bytes.offset, shl(5, pos)), 4))), 4)
            rv.length := calldataload(lengthPtr)
            rv.offset := add(lengthPtr, 0x20)
        }
    }
}
