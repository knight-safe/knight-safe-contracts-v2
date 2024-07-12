// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Errors} from "../error/Errors.sol";
import {IEventEmitter, EventUtils} from "../interfaces/IEventEmitter.sol";

/// @notice inherit Doc {IEventEmitter}
abstract contract EventEmitter is IEventEmitter, Context, Ownable2Step {
    mapping(address => bool) private _factory;
    mapping(address => bool) internal isKnightSafe;

    constructor(address owner) Ownable(owner) {}

    modifier onlyKnightSafe() {
        if (!isActiveAccount(_msgSender()) && !isFactory(_msgSender()) && _msgSender() != address(this)) {
            revert Errors.Unauthorized(_msgSender(), "KNIGHTSAFE");
        }
        _;
    }

    /// @inheritdoc IEventEmitter
    function isFactory(address sender) public view returns (bool) {
        return _factory[sender];
    }

    /// @inheritdoc IEventEmitter
    function setFactory(address factory) public onlyOwner {
        _factory[factory] = true;
    }

    /// @inheritdoc IEventEmitter
    function disableFactory(address factory) public onlyOwner {
        _factory[factory] = false;
    }

    /// @inheritdoc IEventEmitter
    function isActiveAccount(address sender) public view returns (bool) {
        return isKnightSafe[sender];
    }

    /// @inheritdoc IEventEmitter
    function setActiveAccount(address sender) public {
        if (!isFactory(_msgSender())) {
            revert Errors.Unauthorized(_msgSender(), "FACTORY");
        }
        isKnightSafe[sender] = true;
    }

    /// @inheritdoc IEventEmitter
    function disableActiveAccount(address sender) public onlyOwner {
        isKnightSafe[sender] = false;
    }

    /// @inheritdoc IEventEmitter
    function emitEventLog(string memory eventName, EventUtils.EventLogData memory eventData) external onlyKnightSafe {
        emit EventLog((address(_msgSender())), eventName, eventName, eventData);
    }

    /// @inheritdoc IEventEmitter
    function emitEventLog1(string memory eventName, bytes32 profile, EventUtils.EventLogData memory eventData)
        external
        onlyKnightSafe
    {
        emit EventLog1((address(_msgSender())), eventName, eventName, profile, eventData);
    }

    /// @inheritdoc IEventEmitter
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

    /**
     * @dev Disable owner renounce ownership
     */
    function renounceOwnership() public virtual override onlyOwner {
        // do nothing
    }
}
