// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {EventUtils} from "../event/EventUtils.sol";
import {EventEmitter} from "../event/EventEmitter.sol";
import {Cast} from "../utils/Cast.sol";

library ControlCenterEventUtils {
    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BoolItems;

    function emitSetAdmin(EventEmitter eventEmitter, address _admin, bool _isAdmin) external {
        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "admin", _admin);
        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "isAdmin", _isAdmin);

        eventEmitter.emitEventLog1("SetAdmin", Cast._toBytes32(_admin), eventData);
    }

    function emitAddedOfficialControlCenter(EventEmitter eventEmitter, address controlCenterAddress, bytes32 version)
        external
    {
        EventUtils.EventLogData memory eventData;
        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "version", version);

        eventEmitter.emitEventLog1("AddedOfficialControlCenter", Cast._toBytes32(controlCenterAddress), eventData);
    }

    function emitRemovedOfficialControlCenter(EventEmitter eventEmitter, address controlCenterAddress) external {
        EventUtils.EventLogData memory eventData;

        eventEmitter.emitEventLog1("RemovedOfficialControlCenter", Cast._toBytes32(controlCenterAddress), eventData);
    }

    function emitAddedOfficialImplementation(EventEmitter eventEmitter, address implementationAddress, bytes32 version)
        external
    {
        EventUtils.EventLogData memory eventData;
        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "version", version);

        eventEmitter.emitEventLog1("AddedOfficialImplementation", Cast._toBytes32(implementationAddress), eventData);
    }

    function emitRemovedOfficialImplementation(EventEmitter eventEmitter, address implementationAddress) external {
        EventUtils.EventLogData memory eventData;

        eventEmitter.emitEventLog1("RemovedOfficialImplementation", Cast._toBytes32(implementationAddress), eventData);
    }

    function emitAddedOfficialAnalyser(EventEmitter eventEmitter, address analyser, bytes32 version) external {
        EventUtils.EventLogData memory eventData;
        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "version", version);

        eventEmitter.emitEventLog1("AddedOfficialAnalyser", Cast._toBytes32(analyser), eventData);
    }

    function emitRemoveOfficialAnalyser(EventEmitter eventEmitter, address analyser) external {
        EventUtils.EventLogData memory eventData;

        eventEmitter.emitEventLog1("RemoveOfficialAnalyser", Cast._toBytes32(analyser), eventData);
    }

    function emitSetSpendingLimitEnabled(EventEmitter eventEmitter, address knightSafeAddress, bool _isSpendingLimit)
        external
    {
        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "knightSafeAddress", knightSafeAddress);
        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "isSpendingLimit", _isSpendingLimit);

        eventEmitter.emitEventLog1("SetSpendingLimitEnabled", Cast._toBytes32(knightSafeAddress), eventData);
    }

    function emitSetMaxPolicyAllowed(EventEmitter eventEmitter, address knightSafeAddress, uint256 _maxPolicyAllowed)
        external
    {
        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "knightSafeAddress", knightSafeAddress);
        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "maxPolicyAllowed", _maxPolicyAllowed);

        eventEmitter.emitEventLog1("SetMaxPolicyAllowed", Cast._toBytes32(knightSafeAddress), eventData);
    }

    function emitSetGlobalMinPolicyAllowed(EventEmitter eventEmitter, uint256 _maxPolicyAllowed) external {
        EventUtils.EventLogData memory eventData;
        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "maxPolicyAllowed", _maxPolicyAllowed);

        eventEmitter.emitEventLog("SetGlobalMinPolicyAllowed", eventData);
    }

    function emitSetPriceFeed(EventEmitter eventEmitter, address priceFeed) external {
        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "priceFeed", priceFeed);

        eventEmitter.emitEventLog("SetPriceFeed", eventData);
    }

    function emitSetDailyLimit(EventEmitter eventEmitter, address knightSafeAddress, uint256 volume) external {
        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "knightSafeAddress", knightSafeAddress);
        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "dailyLimit", volume);

        eventEmitter.emitEventLog1("SetDailyLimit", Cast._toBytes32(knightSafeAddress), eventData);
    }

    function emitSetDailyLimitExpiry(EventEmitter eventEmitter, address knightSafeAddress, uint256 expirationDate)
        external
    {
        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "knightSafeAddress", knightSafeAddress);
        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "expirationDate", expirationDate);

        eventEmitter.emitEventLog1("SetDailyLimitExpiry", Cast._toBytes32(knightSafeAddress), eventData);
    }

    function emitSetMaxTradingVolume(EventEmitter eventEmitter, address knightSafeAddress, uint256 maxTradingVolume)
        external
    {
        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "knightSafeAddress", knightSafeAddress);
        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "maxTradingVolume", maxTradingVolume);

        eventEmitter.emitEventLog1("SetMaxTradingVolume", Cast._toBytes32(knightSafeAddress), eventData);
    }

    function emitSetMaxTradingVolumeExpiry(EventEmitter eventEmitter, address knightSafeAddress, uint256 expirationDate)
        external
    {
        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "knightSafeAddress", knightSafeAddress);
        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "expirationDate", expirationDate);

        eventEmitter.emitEventLog1("SetMaxTradingVolumeExpiry", Cast._toBytes32(knightSafeAddress), eventData);
    }
}
