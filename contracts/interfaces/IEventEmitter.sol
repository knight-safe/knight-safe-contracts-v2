// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "../event/EventUtils.sol";
import "../transaction/Transaction.sol";
import "../setting/SettingUtils.sol";

/// @notice EventEmitter interface
/// All KnightSafe event will emit through this interface
interface IEventEmitter {
    event TransactionEventLog(
        address msgSender, string eventName, string indexed eventNameHash, bytes32 indexed profile, uint256 reqId
    );

    event SettingEventLog(
        address msgSender, string eventName, string indexed eventNameHash, bytes32 indexed profile, uint256 reqId
    );

    event EventLog(
        address msgSender, string eventName, string indexed eventNameHash, EventUtils.EventLogData eventData
    );

    event EventLog1(
        address msgSender,
        string eventName,
        string indexed eventNameHash,
        bytes32 indexed profile,
        EventUtils.EventLogData eventData
    );

    event EventLog2(
        address msgSender,
        string eventName,
        string indexed eventNameHash,
        bytes32 indexed profile,
        bytes32 indexed topic2,
        EventUtils.EventLogData eventData
    );
    /// @notice check if sender is factory

    function isFactory(address sender) external view returns (bool);
    /// @notice set sender as factory
    function setFactory(address factory) external;
    /// @notice disable factory
    function disableFactory(address factory) external;

    /// @notice check if sender is available to send event
    function isActiveAccount(address sender) external view returns (bool);
    /// @notice set sender as active account
    function setActiveAccount(address sender) external;
    /// @notice disable active account
    function disableActiveAccount(address sender) external;

    /**
     * @notice emit event log
     * @param eventName event name, Topic 0
     * @param eventData event data, data
     */
    function emitEventLog(string memory eventName, EventUtils.EventLogData memory eventData) external;
    /**
     * @notice emit event log with 1 topic
     * @param eventName event name, Topic 0
     * @param profile profile address, Topic 1
     * @param eventData event data, data
     */
    function emitEventLog1(string memory eventName, bytes32 profile, EventUtils.EventLogData memory eventData)
        external;

    /**
     * @notice emit event log with 2 topic
     * @param eventName event name, Topic 0
     * @param profile profile address, Topic 1
     * @param topic2 second topic information , Topic 2
     * @param eventData event data, data
     */
    function emitEventLog2(
        string memory eventName,
        bytes32 profile,
        bytes32 topic2,
        EventUtils.EventLogData memory eventData
    ) external;

    /**
     * @notice emit transaction event log
     * @dev this will trigger on every transaction request
     * @param eventName event name
     * @param profile profile address
     * @param reqId request id
     */
    function emitTransactionEventLog(string memory eventName, bytes32 profile, uint256 reqId) external;

    /**
     * @notice emit setting event log
     * @dev this will trigger on every setting request
     * @param eventName event name
     * @param profile profile address
     * @param reqId request id
     */
    function emitSettingEventLog(string memory eventName, bytes32 profile, uint256 reqId) external;
}
