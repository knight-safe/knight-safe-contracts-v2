// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "../error/Errors.sol";
import "../interfaces/IEventEmitter.sol";

/// @notice inherit Doc {IEventEmitter}
abstract contract EventEmitter is IEventEmitter, Context {
    address internal _owner;
    mapping(address => bool) private _factory;
    mapping(address => bool) internal isKnightSafe;

    constructor() {
        _owner = _msgSender();
    }

    modifier onlyOwner() {
        if (!_checkOwner()) revert Errors.Unauthorized(_msgSender(), "OWNER");
        _;
    }

    modifier onlyKnightSafe() {
        if (!isActiveAccount(_msgSender()) && !isFactory(_msgSender()) && _msgSender() != address(this)) {
            revert Errors.Unauthorized(_msgSender(), "KNIGHTSAFE");
        }
        _;
    }

    function _checkOwner() internal view returns (bool) {
        return _owner == _msgSender();
    }

    function isFactory(address sender) public view returns (bool) {
        return _factory[sender];
    }

    function setFactory(address factory) public onlyOwner {
        _factory[factory] = true;
    }

    function disableFactory(address factory) public onlyOwner {
        _factory[factory] = false;
    }

    function isActiveAccount(address sender) public view returns (bool) {
        return isKnightSafe[sender];
    }

    function setActiveAccount(address sender) public {
        if (!isFactory(_msgSender())) {
            revert Errors.Unauthorized(_msgSender(), "FACTORY");
        }
        isKnightSafe[sender] = true;
    }

    function disableActiveAccount(address sender) public onlyOwner {
        isKnightSafe[sender] = false;
    }

    function emitEventLog(string memory eventName, EventUtils.EventLogData memory eventData) external onlyKnightSafe {
        emit EventLog((address(_msgSender())), eventName, eventName, eventData);
    }

    function emitEventLog1(string memory eventName, bytes32 profile, EventUtils.EventLogData memory eventData)
        external
        onlyKnightSafe
    {
        emit EventLog1((address(_msgSender())), eventName, eventName, profile, eventData);
    }

    function emitEventLog2(
        string memory eventName,
        bytes32 profile,
        bytes32 topic2,
        EventUtils.EventLogData memory eventData
    ) external onlyKnightSafe {
        emit EventLog2((address(_msgSender())), eventName, eventName, profile, topic2, eventData);
    }

    function emitTransactionEventLog(string memory eventName, bytes32 profile, uint256 reqId) external onlyKnightSafe {
        emit TransactionEventLog((address(_msgSender())), eventName, eventName, profile, reqId);
    }

    function emitSettingEventLog(string memory eventName, bytes32 profile, uint256 reqId) external onlyKnightSafe {
        emit SettingEventLog((address(_msgSender())), eventName, eventName, profile, reqId);
    }
}
