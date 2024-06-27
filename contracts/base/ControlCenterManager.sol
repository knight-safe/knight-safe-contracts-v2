// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import {ControlCenter} from "../controlCenter/ControlCenter.sol";
import {Errors} from "../error/Errors.sol";
import "../common/TokenCallbackHandler.sol";

abstract contract ControlCenterManager {
    ControlCenter internal _controlCenter;

    function _setControlCenter(address addr) internal {
        if (addr == address(0)) revert Errors.InvalidAddress(addr);
        _controlCenter = ControlCenter(addr);
    }

    function getControlCenter() public view returns (address) {
        return address(_controlCenter);
    }
}
