// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "../event/EventUtils.sol";
import "../event/EventEmitter.sol";
import "../utils/Cast.sol";

library TransactionEventUtils {
    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.BytesItems;

    function emitCreatedTransactionRequest(EventEmitter eventEmitter, address profile, uint256 reqId) external {
        eventEmitter.emitTransactionEventLog("CreatedTransactionRequest", Cast._toBytes32(profile), reqId);
    }

    function emitCancelledTransactionRequest(EventEmitter eventEmitter, address profile, uint256 reqId) external {
        eventEmitter.emitTransactionEventLog("CancelledTransactionRequest", Cast._toBytes32(profile), reqId);
    }

    function emitRejectedTransactionRequest(EventEmitter eventEmitter, address profile, uint256 reqId) external {
        eventEmitter.emitTransactionEventLog("RejectedTransactionRequest", Cast._toBytes32(profile), reqId);
    }

    function emitExecutedTransactionRequest(EventEmitter eventEmitter, address profile, uint256 reqId) external {
        eventEmitter.emitTransactionEventLog("ExecutedTransactionRequest", Cast._toBytes32(profile), reqId);
    }

    function emitExecutedTransaction(
        EventEmitter eventEmitter,
        address profile,
        uint256 _onBehalfOfPolicyId,
        uint256 _value,
        address _from,
        address _to,
        bytes memory _data
    ) external {
        EventUtils.EventLogData memory eventData;
        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "onBehalfOfPolicyId", _onBehalfOfPolicyId);
        eventData.uintItems.setItem(1, "value", _value);
        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "user", _from);
        eventData.addressItems.setItem(1, "to", _to);
        eventData.bytesItems.initItems(1);
        eventData.bytesItems.setItem(0, "data", _data);

        eventEmitter.emitEventLog1("ExecutedTransaction", Cast._toBytes32(profile), eventData);
    }
}
