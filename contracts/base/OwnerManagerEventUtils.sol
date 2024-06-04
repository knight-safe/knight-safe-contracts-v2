// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "../event/EventUtils.sol";
import "../event/EventEmitter.sol";
import "../utils/Cast.sol";

library OwnerManagerEventUtils {
    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;

    function emitUpdatedBackupOwner(
        EventEmitter eventEmitter,
        address profile,
        address _backupOwner,
        uint256 _takeoverDelayIsSecond
    ) external {
        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "backupOwner", _backupOwner);
        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "takeoverDelayIsSecond", _takeoverDelayIsSecond);

        eventEmitter.emitEventLog1("UpdatedBackupOwner", Cast._toBytes32(profile), eventData);
    }

    function emitRequestedTakeover(
        EventEmitter eventEmitter,
        address profile,
        address _backupOwner,
        address _owner,
        uint256 _takeoverTimestamp
    ) external {
        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "backupOwner", _backupOwner);
        eventData.addressItems.setItem(1, "owner", _owner);
        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "takeoverTimestamp", _takeoverTimestamp);

        eventEmitter.emitEventLog1("RequestedTakeover", Cast._toBytes32(profile), eventData);
    }

    function emitConfirmedTakeover(EventEmitter eventEmitter, address profile, address _owner, address prevOwner)
        external
    {
        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "owner", _owner);
        eventData.addressItems.setItem(1, "prevOwner", prevOwner);

        eventEmitter.emitEventLog1("ConfirmedTakeover", Cast._toBytes32(profile), eventData);
    }

    function emitInstantTakeover(EventEmitter eventEmitter, address profile, address _owner, address _prevOwner)
        external
    {
        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "owner", _owner);
        eventData.addressItems.setItem(1, "prevOwner", _prevOwner);

        eventEmitter.emitEventLog1("InstantTakeover", Cast._toBytes32(profile), eventData);
    }

    function emitRevokeTakeover(EventEmitter eventEmitter, address profile, address _owner, address _backupOwner)
        external
    {
        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "owner", _owner);
        eventData.addressItems.setItem(1, "backupOwner", _backupOwner);
        eventEmitter.emitEventLog1("RevokeTakeover", Cast._toBytes32(profile), eventData);
    }

    function emitAddedAdmin(EventEmitter eventEmitter, address profile, address _admin) external {
        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "user", _admin);
        eventEmitter.emitEventLog1("AddedAdmin", Cast._toBytes32(profile), eventData);
    }

    function emitRemovedAdmin(EventEmitter eventEmitter, address profile, address _admin) external {
        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "user", _admin);
        eventEmitter.emitEventLog1("RemovedAdmin", Cast._toBytes32(profile), eventData);
    }
}
