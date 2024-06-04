// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "../event/EventUtils.sol";
import "../event/EventEmitter.sol";
import "../utils/Cast.sol";

library PolicyManagerEventUtils {
    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;

    function emitCreatedPolicy(EventEmitter eventEmitter, address profile, uint256 _policyId) external {
        EventUtils.EventLogData memory eventData;
        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "policyId", _policyId);

        eventEmitter.emitEventLog1("CreatedPolicy", Cast._toBytes32(profile), eventData);
    }

    function emitRemovedPolicy(EventEmitter eventEmitter, address profile, uint256 _policyId) external {
        EventUtils.EventLogData memory eventData;
        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "policyId", _policyId);

        eventEmitter.emitEventLog1("RemovedPolicy", Cast._toBytes32(profile), eventData);
    }

    function emitAddedTrader(EventEmitter eventEmitter, address profile, uint256 _policyId, address _trader) external {
        EventUtils.EventLogData memory eventData;
        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "policyId", _policyId);
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "trader", _trader);
        eventEmitter.emitEventLog1("AddedTrader", Cast._toBytes32(profile), eventData);
    }

    function emitRemovedTrader(EventEmitter eventEmitter, address profile, uint256 _policyId, address _trader)
        external
    {
        EventUtils.EventLogData memory eventData;
        eventData.uintItems.initItems(1);
        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "policyId", _policyId);
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "trader", _trader);
        eventEmitter.emitEventLog1("RemovedTrader", Cast._toBytes32(profile), eventData);
    }

    function emitUpdatedWhitelist(
        EventEmitter eventEmitter,
        address profile,
        uint256 _policyId,
        address _whitelistAddress,
        address _officialAnalyserAddress
    ) external {
        EventUtils.EventLogData memory eventData;
        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "policyId", _policyId);
        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "whitelistAddress", _whitelistAddress);
        eventData.addressItems.setItem(1, "officialAnalyserAddress", _officialAnalyserAddress);

        eventEmitter.emitEventLog1("UpdatedWhitelist", Cast._toBytes32(profile), eventData);
    }

    function emitAddedWhitelist(
        EventEmitter eventEmitter,
        address profile,
        uint256 _policyId,
        address _whitelistAddress,
        address _officialAnalyserAddress
    ) external {
        EventUtils.EventLogData memory eventData;
        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "policyId", _policyId);
        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "whitelistAddress", _whitelistAddress);
        eventData.addressItems.setItem(1, "officialAnalyserAddress", _officialAnalyserAddress);

        eventEmitter.emitEventLog1("AddedWhitelist", Cast._toBytes32(profile), eventData);
    }

    function emitRemovedWhitelist(
        EventEmitter eventEmitter,
        address profile,
        uint256 _policyId,
        address _whitelistAddress
    ) external {
        EventUtils.EventLogData memory eventData;
        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "policyId", _policyId);
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "whitelistAddress", _whitelistAddress);

        eventEmitter.emitEventLog1("RemovedWhitelist", Cast._toBytes32(profile), eventData);
    }
}
