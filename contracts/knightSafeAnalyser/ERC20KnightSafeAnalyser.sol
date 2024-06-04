// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./BaseKnightSafeAnalyser.sol";
import "../interfaces/IKnightSafeAnalyser.sol";

contract ERC20KnightSafeAnalyser is BaseKnightSafeAnalyser {
    /// @inheritdoc IKnightSafeAnalyser
    function extractAddressesWithValue(address to, bytes calldata data)
        external
        pure
        override
        returns (address[] memory addrList, uint256[] memory valueList)
    {
        bytes4 selector = getSelector(data);

        if (
            selector == Selectors.APPROVE || selector == Selectors.DECREASE_ALLOWANCE
                || selector == Selectors.INCREASE_ALLOWANCE
        ) {
            addrList = new address[](2);
            addrList[0] = _getAddressFromBytes(data, 0); // spender
            addrList[1] = to; // token
            valueList = new uint256[](2);
            valueList[0] = 0;
            valueList[1] = 0;
            return (addrList, valueList);
        } else if (selector == Selectors.PERMIT) {
            addrList = new address[](3);
            addrList[0] = _getAddressFromBytes(data, 0); // owner
            addrList[1] = _getAddressFromBytes(data, 1); // spender
            addrList[2] = to; // token
            valueList = new uint256[](3);
            valueList[0] = 0;
            valueList[1] = 0;
            valueList[2] = 0;
            return (addrList, valueList);
        } else if (selector == Selectors.TRANSFER) {
            addrList = new address[](2);
            addrList[0] = _getAddressFromBytes(data, 0); // _recipient
            addrList[1] = to; // _token
            valueList = new uint256[](2);
            valueList[0] = 0;
            valueList[1] = _getUintFromBytes(data, 1);
            return (addrList, valueList);
        } else if (selector == Selectors.TRANSFER_FROM) {
            addrList = new address[](3);
            addrList[0] = _getAddressFromBytes(data, 0); // _sender
            addrList[1] = _getAddressFromBytes(data, 1); // _recipient
            addrList[2] = to; // token

            valueList = new uint256[](3);
            valueList[0] = 0;
            valueList[1] = 0;
            valueList[2] = _getUintFromBytes(data, 2);
            return (addrList, valueList);
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
}

library Selectors {
    bytes4 internal constant APPROVE = 0x095ea7b3; // approve(_spender:address,_amount:uint256)
    bytes4 internal constant DECREASE_ALLOWANCE = 0xa457c2d7; // decreaseAllowance(spender:address,subtractedValue:uint256)
    bytes4 internal constant INCREASE_ALLOWANCE = 0x39509351; // increaseAllowance(spender:address,addedValue:uint256)
    bytes4 internal constant PERMIT = 0xd505accf; // permit(owner:address,spender:address,value:uint256,deadline:uint256,v:uint8,r:bytes32,s:bytes32)

    bytes4 internal constant TRANSFER = 0xa9059cbb; // transfer(_recipient:address,_amount:uint256)
    bytes4 internal constant TRANSFER_FROM = 0x23b872dd; // transferFrom(_sender:address,_recipient:address,_amount:uint256)
}
