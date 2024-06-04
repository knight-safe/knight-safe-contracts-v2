// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "../event/EventEmitter.sol";
import "../utils/Cast.sol";

library SettingEventUtils {
    function emitCreatedSettingRequest(EventEmitter eventEmitter, address profile, uint256 reqId) external {
        eventEmitter.emitSettingEventLog("CreatedSettingRequest", Cast._toBytes32(profile), reqId);
    }

    function emitCancelledSettingRequest(EventEmitter eventEmitter, address profile, uint256 reqId) external {
        eventEmitter.emitSettingEventLog("CancelledSettingRequest", Cast._toBytes32(profile), reqId);
    }

    function emitRejectedSettingRequest(EventEmitter eventEmitter, address profile, uint256 reqId) external {
        eventEmitter.emitSettingEventLog("RejectedSettingRequest", Cast._toBytes32(profile), reqId);
    }

    function emitApprovedSettingRequest(EventEmitter eventEmitter, address profile, uint256 reqId) external {
        eventEmitter.emitSettingEventLog("ApprovedSettingRequest", Cast._toBytes32(profile), reqId);
    }
}
