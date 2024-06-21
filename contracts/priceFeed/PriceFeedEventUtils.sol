// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import "../event/EventUtils.sol";
import "../event/EventEmitter.sol";
import "../interfaces/IEventEmitter.sol";
import "../utils/Cast.sol";

library PriceFeedEventUtils {
    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.BoolItems;

    function emitSetPriceFeed(address eventEmitter, address token, address priceFeed) external {
        EventUtils.EventLogData memory eventData;
        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "length", 1);
        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "token", token);
        eventData.addressItems.setItem(1, "priceFeed", priceFeed);

        IEventEmitter(eventEmitter).emitEventLog("setPriceFeed", eventData);
    }

    function emitSetPriceFeed(address eventEmitter, address[] memory token, address[] memory priceFeed) external {
        EventUtils.EventLogData memory eventData;
        eventData.uintItems.initItems(token.length);
        eventData.uintItems.setItem(0, "length", 1);
        eventData.addressItems.initItems(token.length + priceFeed.length);
        for (uint256 i = 0; i < token.length; i++) {
            eventData.addressItems.setItem(i, "token", token[i]);
            eventData.addressItems.setItem(i + token.length, "priceFeed", priceFeed[i]);
        }

        IEventEmitter(eventEmitter).emitEventLog("setPriceFeed", eventData);
    }
}
