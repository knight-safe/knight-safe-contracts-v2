// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./OwnerManagerEventUtils.sol";
import "../interfaces/IOwnerManager.sol";
import "../error/Errors.sol";
import "../base/ControlCenterManager.sol";

/// @notice inherit Doc {IOwnerManager}
abstract contract OwnerManager is IOwnerManager, Context, ControlCenterManager {
    using EnumerableSet for EnumerableSet.AddressSet;

    address private _owner;
    address private _backupOwner;
    uint256 private _takeoverDelayIsSecond;
    bool private _isTakeoverInProgress;
    uint256 private _takeoverTimestamp;

    EnumerableSet.AddressSet private _admins;

    modifier onlyOwner() {
        if (!_checkOwner()) revert Errors.Unauthorized(_msgSender(), "OWNER");
        _;
    }

    modifier onlyAdminOrOwner() {
        if (!_checkOwner() && !isAdmin(_msgSender())) revert Errors.Unauthorized(_msgSender(), "ADMIN+");
        _;
    }

    function _checkOwner() internal view returns (bool) {
        return _owner == _msgSender();
    }

    function _checkBackupOwner() private view returns (bool) {
        return _backupOwner == _msgSender();
    }

    function _initOwnerManager(address owner) internal {
        if (_owner != address(0)) revert Errors.InvalidOperation();
        if (owner == address(0)) revert Errors.InvalidAddress(owner);
        _owner = owner;
    }

    /// @inheritdoc IOwnerManager
    function getOwner() public view returns (address) {
        return _owner;
    }

    /// @inheritdoc IOwnerManager
    function getIsTakeoverInProgress() public view returns (bool) {
        return _isTakeoverInProgress;
    }

    /// @inheritdoc IOwnerManager
    function getTakeoverTimestamp() public view returns (uint256) {
        return _isTakeoverInProgress ? _takeoverTimestamp : 0;
    }

    /// @inheritdoc IOwnerManager
    function getTakeoverStatus() public view returns (address, bool, uint256, uint256) {
        return (_backupOwner, _isTakeoverInProgress, getTakeoverTimestamp(), _takeoverDelayIsSecond);
    }

    /// @inheritdoc IOwnerManager
    function setBackupOwner(address backupOwner, uint256 takeoverDelayIsSecond) public onlyOwner {
        if (_isTakeoverInProgress) revert Errors.InvalidTakeoverStatus(_isTakeoverInProgress);
        if (backupOwner == address(this) || backupOwner == address(0)) revert Errors.InvalidAddress(backupOwner);
        _backupOwner = backupOwner;
        _takeoverDelayIsSecond = takeoverDelayIsSecond;

        OwnerManagerEventUtils.emitUpdatedBackupOwner(_controlCenter, address(this), backupOwner, takeoverDelayIsSecond);
    }

    /// @inheritdoc IOwnerManager
    function requestTakeover() public {
        if (!_checkBackupOwner()) revert Errors.Unauthorized(_msgSender(), "BACKUP");
        if (_isTakeoverInProgress) revert Errors.InvalidTakeoverStatus(_isTakeoverInProgress);
        _isTakeoverInProgress = true;
        _takeoverTimestamp = block.timestamp + _takeoverDelayIsSecond;

        OwnerManagerEventUtils.emitRequestedTakeover(
            _controlCenter, address(this), _backupOwner, _owner, _takeoverTimestamp
        );
    }

    /// @inheritdoc IOwnerManager
    function confirmTakeover() public {
        if (!_isTakeoverInProgress) revert Errors.InvalidTakeoverStatus(_isTakeoverInProgress);
        if (!_checkOwner() && block.timestamp < _takeoverTimestamp) revert Errors.TakeoverIsNotReady();
        address prevOwner = _owner;
        _takeover();

        OwnerManagerEventUtils.emitConfirmedTakeover(_controlCenter, address(this), _owner, prevOwner);
    }

    /// @inheritdoc IOwnerManager
    function instantTakeover() public {
        if (!_checkBackupOwner()) revert Errors.Unauthorized(_msgSender(), "BACKUP");
        if (_isTakeoverInProgress) revert Errors.InvalidTakeoverStatus(_isTakeoverInProgress);
        if (_takeoverDelayIsSecond > 0) revert Errors.TakeoverIsNotReady();
        address prevOwner = _owner;
        _takeover();

        OwnerManagerEventUtils.emitInstantTakeover(_controlCenter, address(this), _owner, prevOwner);
    }

    /// @inheritdoc IOwnerManager
    function revokeTakeover() public {
        if (!_checkBackupOwner() && !_checkOwner()) revert Errors.Unauthorized(_msgSender(), "BACKUP+");
        if (!_isTakeoverInProgress) revert Errors.InvalidTakeoverStatus(_isTakeoverInProgress);
        _isTakeoverInProgress = false;

        OwnerManagerEventUtils.emitRevokeTakeover(_controlCenter, address(this), _owner, _backupOwner);
    }

    /// @inheritdoc IOwnerManager
    function isAdmin(address admin) public view returns (bool) {
        return _admins.contains(admin);
    }

    /// @inheritdoc IOwnerManager
    function getAdmins() external view returns (address[] memory) {
        return _admins.values();
    }

    /// @inheritdoc IOwnerManager
    function addAdmin(address admin) public onlyOwner {
        if (isAdmin(admin)) revert Errors.AddressAlreadyExist(admin);
        _admins.add(admin);

        OwnerManagerEventUtils.emitAddedAdmin(_controlCenter, address(this), admin);
    }

    /// @inheritdoc IOwnerManager
    function removeAdmin(address admin) public onlyOwner {
        if (!isAdmin(admin)) revert Errors.AddressNotExist(admin);
        _admins.remove(admin);

        OwnerManagerEventUtils.emitRemovedAdmin(_controlCenter, address(this), admin);
    }

    function _takeover() private {
        _owner = _backupOwner;
        _isTakeoverInProgress = false;
    }
}
