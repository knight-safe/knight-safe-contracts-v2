// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "../event/EventUtils.sol";
import "../event/EventEmitter.sol";
import "../utils/Cast.sol";

library ProxyFactoryEventUtils {
    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.Bytes32Items;

    function emitProxyCreation(
        EventEmitter eventEmitter,
        address implementation,
        address proxy,
        address owner,
        bytes32 salt
    ) external {
        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "account", proxy);
        eventData.addressItems.setItem(1, "owner", owner);
        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "salt", salt);

        eventEmitter.emitEventLog2("ProxyCreation", Cast._toBytes32(implementation), Cast._toBytes32(proxy), eventData);
    }
}
