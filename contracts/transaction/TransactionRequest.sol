// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Transaction} from "./Transaction.sol";
import "./TransactionEventUtils.sol";
import "../error/Errors.sol";
import "../base/OwnerManager.sol";
import "../base/PolicyManager.sol";
import "../base/ControlCenterManager.sol";
import "../common/PausableUtils.sol";
import "../interfaces/IPriceFeed.sol";
import "../interfaces/ITransactionRequest.sol";

/// @notice inherit doc {ITransactionRequest}
abstract contract TransactionRequest is ControlCenterManager, PolicyManager, PausableUtils {
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 private _nonce;

    mapping(uint256 => Transaction.Request) private _transactionRequest;

    /// @inheritdoc ITransactionRequest
    uint256 public dailyVolumeSpent = 0;

    /// @inheritdoc ITransactionRequest
    uint256 public accountVolumeSpent = 0;
    /// @inheritdoc ITransactionRequest
    uint256 public lastDailyVolumeDate = 0;

    /// @inheritdoc ITransactionRequest
    function getNextTransactionRequestId() public view returns (uint256) {
        return _nonce;
    }

    /// @inheritdoc ITransactionRequest
    function getTransactionRequest(uint256 reqId) public view returns (Transaction.Request memory) {
        if (reqId >= _nonce) revert Errors.InvalidReqId(reqId);
        return _transactionRequest[reqId];
    }

    /// @inheritdoc ITransactionRequest
    function getTotalVolumeSpent() public view returns (uint256) {
        return dailyVolumeSpent + accountVolumeSpent;
    }

    /// @inheritdoc ITransactionRequest
    function validateTradingAccess(
        uint256 policyId,
        bool useGlobalWhitelist,
        address to, /* uint256 value, */
        bytes memory data
    ) public view returns (address[] memory addresses, uint256[] memory amounts) {
        if (!_activePolicyIds.contains(policyId)) revert Errors.PolicyNotExist(policyId);
        uint256 ksaPolicyId = useGlobalWhitelist ? 0 : policyId;
        if (!isPolicyWhitelistAddress(ksaPolicyId, to)) revert Errors.AddressNotInWhitelist(ksaPolicyId, to);

        if (data.length > 0) {
            address ksa = _policyMap[ksaPolicyId].whitelistValues[to];
            if (ksa == address(0)) revert Errors.AddressIsReadOnlyWhitelist(policyId, ksa);

            if (ksa != address(1)) {
                (addresses, amounts) = IKnightSafeAnalyser(ksa).extractAddressesWithValue(to, data);
                if (addresses.length == 0) {
                    revert Errors.SelectorNotSupport();
                }
                for (uint256 i = 0; i < addresses.length; i++) {
                    if (!isPolicyOrGlobalWhitelistAddress(policyId, addresses[i])) {
                        revert Errors.AddressNotInWhitelist(policyId, addresses[i]);
                    }
                }
            }
        }
    }

    /// @inheritdoc ITransactionRequest
    function validateTradingLimit(address[] memory addresses, uint256[] memory amounts, uint256 value)
        public
        returns (uint256)
    {
        uint256 currentTime = block.timestamp;
        if (currentTime - lastDailyVolumeDate > 1 days) {
            dailyVolumeSpent = 0;
            lastDailyVolumeDate = currentTime - (currentTime % 1 days); // new day starts at 00:00:00
        }

        uint256 volumeSpent = dailyVolumeSpent + accountVolumeSpent;
        uint256 txnVolume = volumeSpent;

        address priceFeed = _controlCenter.getPriceFeed();

        uint256 maxVolume =
            _controlCenter.getDailyVolume(address(this)) + _controlCenter.getMaxTradingVolume(address(this));

        if (value > 0) {
            txnVolume += IPriceFeed(priceFeed).getNativeTokenVolume(value);
            if (txnVolume > maxVolume) revert Errors.ExceedMaxTradingVolume(txnVolume, maxVolume);
        }

        txnVolume += IPriceFeed(priceFeed).getTransactionVolume(addresses, amounts);
        if (txnVolume > maxVolume) {
            revert Errors.ExceedMaxTradingVolume(txnVolume, maxVolume);
        }
        return txnVolume - volumeSpent;
    }

    /// @inheritdoc ITransactionRequest
    function validatePolicyLimit(uint256 policyId, uint256 volume) public {
        // feature disable for unsubscribed user
        if (!_controlCenter.isSpendingLimitEnabled(address(this))) return;

        uint256 currentTime = block.timestamp;

        if (currentTime - _policyMap[policyId].lastDailyVolumeDate > 1 days) {
            _policyMap[policyId].dailyVolumeSpent = 0;
            _policyMap[policyId].lastDailyVolumeDate = currentTime - (currentTime % 1 days); // new day starts at 00:00:00
        }

        if (volume + _policyMap[policyId].dailyVolumeSpent > _policyMap[policyId].maxSpendingLimit) {
            revert Errors.ExceedPolicyVolume(policyId, volume);
        }
    }

    /// @inheritdoc ITransactionRequest
    function requestTransaction(uint256 onBehalfOfPolicyId, address to, uint256 value, bytes memory data)
        public
        onlyTrader(onBehalfOfPolicyId)
        returns (uint256 reqId)
    {
        reqId = _nonce;
        _nonce += 1;

        Transaction.Request memory request;
        request.requester = _msgSender();
        request.policyId = onBehalfOfPolicyId;
        request.params = Transaction.Params(to, value, data);
        request.status = Transaction.Status.Pending;

        _transactionRequest[reqId] = request;

        TransactionEventUtils.emitCreatedTransactionRequest(_controlCenter, address(this), reqId);
    }

    /// @inheritdoc ITransactionRequest
    function cancelTransactionByReqId(uint256 onBehalfOfPolicyId, uint256 reqId)
        public
        onlyTrader(onBehalfOfPolicyId)
    {
        Transaction.Request memory request = getTransactionRequest(reqId);
        _updateTransactionRequestStatus(reqId, Transaction.Status.Cancelled);

        if (request.requester != _msgSender()) revert Errors.InvalidOperation();

        TransactionEventUtils.emitCancelledTransactionRequest(_controlCenter, address(this), reqId);
    }

    /// @inheritdoc ITransactionRequest
    function rejectTransactionByReqId(uint256 onBehalfOfPolicyId, bool useGlobalWhitelist, uint256 reqId)
        public
        onlyTrader(onBehalfOfPolicyId)
    {
        Transaction.Request memory request = getTransactionRequest(reqId);

        _updateTransactionRequestStatus(reqId, Transaction.Status.Rejected);
        validateTradingAccess(onBehalfOfPolicyId, useGlobalWhitelist, request.params.to, request.params.data);

        TransactionEventUtils.emitRejectedTransactionRequest(_controlCenter, address(this), reqId);
    }

    /// @inheritdoc ITransactionRequest
    function executeTransaction(
        uint256 onBehalfOfPolicyId,
        bool useGlobalWhitelist,
        address to,
        uint256 value,
        bytes memory data
    ) public {
        _executeTransaction(onBehalfOfPolicyId, useGlobalWhitelist, to, value, data);

        TransactionEventUtils.emitExecutedTransaction(
            _controlCenter, address(this), onBehalfOfPolicyId, value, _msgSender(), to, data
        );
    }

    /// @inheritdoc ITransactionRequest
    function executeTransactionByReqId(uint256 onBehalfOfPolicyId, bool useGlobalWhitelist, uint256 reqId) public {
        Transaction.Request memory request = getTransactionRequest(reqId);
        _updateTransactionRequestStatus(reqId, Transaction.Status.Completed);

        _executeTransaction(
            onBehalfOfPolicyId, useGlobalWhitelist, request.params.to, request.params.value, request.params.data
        );

        TransactionEventUtils.emitExecutedTransactionRequest(_controlCenter, address(this), reqId);
    }

    function _updateTransactionRequestStatus(uint256 reqId, Transaction.Status status) private {
        if (_transactionRequest[reqId].status != Transaction.Status.Pending || status == Transaction.Status.Pending) {
            revert Errors.InvalidTransactionStatus();
        }
        _transactionRequest[reqId].status = status;
    }

    function _executeTransaction(
        uint256 onBehalfOfPolicyId,
        bool useGlobalWhitelist,
        address to,
        uint256 value,
        bytes memory data
    ) internal onlyTrader(onBehalfOfPolicyId) whenNotPaused returns (bool success) {
        (address[] memory addresses, uint256[] memory amounts) =
            validateTradingAccess(onBehalfOfPolicyId, useGlobalWhitelist, to, data);

        uint256 amount = validateTradingLimit(addresses, amounts, value);
        validatePolicyLimit(onBehalfOfPolicyId, amount);

        _updateVolumeSpent(onBehalfOfPolicyId, amount);

        bytes memory returnData;
        (success, returnData) = to.call{value: value}(data);

        if (!success) revert Errors.ExecutionFailedWith(returnData);
    }

    function _updateVolumeSpent(uint256 policyId, uint256 amount) private {
        uint256 maxVolume = _controlCenter.getDailyVolume(address(this));

        uint256 remainingDailyVolume = maxVolume - dailyVolumeSpent;

        if (dailyVolumeSpent == maxVolume) {
            accountVolumeSpent += amount;
        } else if (amount > remainingDailyVolume) {
            dailyVolumeSpent += remainingDailyVolume;
            accountVolumeSpent += amount - remainingDailyVolume;
        } else {
            dailyVolumeSpent += amount;
        }
        // feature disable for unsubscribed user
        if (!_controlCenter.isSpendingLimitEnabled(address(this))) return;
        _policyMap[policyId].dailyVolumeSpent += amount;
    }
}
