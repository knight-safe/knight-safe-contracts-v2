// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ControlCenterManager} from "../base/ControlCenterManager.sol";
import {Cast} from "../utils/Cast.sol";
import {EventUtils} from "../event/EventUtils.sol";

/**
 * @title NativeCurrencyReceiver
 * @notice Implementation to receive native currency payments.
 */
abstract contract NativeCurrencyReceiver is ControlCenterManager {
    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;

    /**
     * @notice Receive native currency payment and emit an event.
     */
    receive() external payable {
        EventUtils.EventLogData memory eventData;
        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "value", msg.value);
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "from", msg.sender);

        _controlCenter.emitEventLog1("NativeCurrencyReceived", Cast._toBytes32(address(this)), eventData);
    }
}
