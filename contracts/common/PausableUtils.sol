// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "../base/OwnerManager.sol";
import "../event/EventUtils.sol";
import "../event/EventEmitter.sol";
import "../utils/Cast.sol";

abstract contract PausableUtils is Pausable, OwnerManager {
    function pause() external onlyAdminOrOwner {
        _pause();
        EventUtils.EventLogData memory eventData;
        _controlCenter.emitEventLog1("Paused", Cast._toBytes32(address(this)), eventData);
    }

    function unpause() external onlyOwner {
        _unpause();
        EventUtils.EventLogData memory eventData;
        _controlCenter.emitEventLog1("Unpaused", Cast._toBytes32(address(this)), eventData);
    }
}
