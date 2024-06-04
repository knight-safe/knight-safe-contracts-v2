// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {ControlCenterEventUtils} from "./ControlCenterEventUtils.sol";
import {Errors} from "../error/Errors.sol";
import {IControlCenter} from "../interfaces/IControlCenter.sol";
import {EventEmitter} from "../event/EventEmitter.sol";
import {IKnightSafeAnalyser} from "../interfaces/IKnightSafeAnalyser.sol";
import {SettingSelectors} from "../setting/SettingUtils.sol";

/// @notice inherit Doc {IControlCenter}
contract ControlCenter is IControlCenter, EventEmitter {
    string public constant override VERSION = "0.0.0";

    struct AccountLimit {
        uint256 dailyLimit;
        uint256 dailyLimitExpiryDate;
        uint256 volume;
        uint256 volumeExpiryDate;
    }

    mapping(address => bool) private _adminMap;

    address private _priceFeed;
    uint256 private constant _BASE_TRADING_VOLUME = 100_000 * (10 ** 30); // 100,000 USD for Retail plan
    mapping(address => AccountLimit) private _tradingLimitMap;

    mapping(address => bytes32) private _knightSafeVersionMap;
    mapping(address => bytes32) private _analyserVersionMap;
    mapping(address => bool) private _spendingLimitMap;
    mapping(address => uint256) private _maxPolicyAllowedMap;
    bytes4[8] private _adminEventAccess = [
        SettingSelectors.CREATE_POLICY,
        SettingSelectors.UPDATE_WHITELIST,
        SettingSelectors.ADD_TRADER,
        SettingSelectors.REMOVE_POLICY,
        SettingSelectors.REMOVE_TRADER,
        SettingSelectors.REMOVE_WHITELIST,
        SettingSelectors.INCREASE_SPENDING_LIMIT,
        SettingSelectors.RESET_SPENDING_LIMIT
    ];

    uint256 private _minPolicyAllowed = 3;

    constructor() {
        _adminMap[_owner] = true;
        _analyserVersionMap[address(0)] = "0x0";
        _analyserVersionMap[address(1)] = "0x1";
    }

    modifier onlyAdmin() {
        if (!_checkOwner() && !_checkAdmin()) revert Errors.Unauthorized(_msgSender(), "ADMIN");
        _;
    }

    function _checkAdmin() private view returns (bool) {
        return _adminMap[_msgSender()];
    }

    function setAdmin(address admin, bool isAdmin) public onlyOwner {
        _adminMap[admin] = isAdmin;
        ControlCenterEventUtils.emitSetAdmin(this, admin, isAdmin);
    }

    function isOfficialImplementation(address implementationAddress) public view returns (bool) {
        return _knightSafeVersionMap[implementationAddress] != 0;
    }

    function addOfficialImplementation(address implementationAddress, bytes32 version) public onlyOwner {
        if (isOfficialImplementation(implementationAddress)) revert Errors.AddressAlreadyExist(implementationAddress);
        if (version == 0) revert Errors.IsNullValue();
        _knightSafeVersionMap[implementationAddress] = version;

        ControlCenterEventUtils.emitAddedOfficialImplementation(this, implementationAddress, version);
    }

    function removeOfficialImplementation(address implementationAddress) public onlyOwner {
        if (!isOfficialImplementation(implementationAddress)) revert Errors.AddressNotExist(implementationAddress);
        _knightSafeVersionMap[implementationAddress] = 0;

        ControlCenterEventUtils.emitRemovedOfficialImplementation(this, implementationAddress);
    }

    function isOfficialAnalyser(address analyserAddress) public view returns (bool) {
        return _analyserVersionMap[analyserAddress] != 0;
    }

    function addOfficialAnalyser(address analyserAddress, bytes32 version) public onlyAdmin {
        if (isOfficialAnalyser(analyserAddress)) revert Errors.AddressAlreadyExist(analyserAddress);
        if (version == 0) revert Errors.IsNullValue();
        if (!_isKnightSafeAnalyser(analyserAddress)) {
            revert Errors.InterfaceNotSupport(analyserAddress);
        }

        _analyserVersionMap[analyserAddress] = version;

        ControlCenterEventUtils.emitAddedOfficialAnalyser(this, analyserAddress, version);
    }

    function removeOfficialAnalyser(address analyserAddress) public onlyAdmin {
        if (!isOfficialAnalyser(analyserAddress)) revert Errors.AddressNotExist(analyserAddress);
        _analyserVersionMap[analyserAddress] = 0;

        ControlCenterEventUtils.emitRemoveOfficialAnalyser(this, analyserAddress);
    }

    function isSpendingLimitEnabled(address knightSafeAddress) public view returns (bool) {
        return _spendingLimitMap[knightSafeAddress];
    }

    function setSpendingLimitEnabled(address knightSafeAddress, bool isEnabled) public onlyAdmin {
        _spendingLimitMap[knightSafeAddress] = isEnabled;
        ControlCenterEventUtils.emitSetSpendingLimitEnabled(this, knightSafeAddress, isEnabled);
    }

    function getMaxPolicyAllowed(address knightSafeAddress) public view returns (uint256) {
        return _maxPolicyAllowedMap[knightSafeAddress] > _minPolicyAllowed
            ? _maxPolicyAllowedMap[knightSafeAddress]
            : _minPolicyAllowed;
    }

    function setMaxPolicyAllowed(address knightSafeAddress, uint256 maxPolicyAllowed) public onlyAdmin {
        _maxPolicyAllowedMap[knightSafeAddress] = maxPolicyAllowed;

        ControlCenterEventUtils.emitSetMaxPolicyAllowed(this, knightSafeAddress, maxPolicyAllowed);
    }

    function setGlobalMinPolicyAllowed(uint256 minPolicyAllowed) public onlyOwner {
        _minPolicyAllowed = minPolicyAllowed;

        ControlCenterEventUtils.emitSetGlobalMinPolicyAllowed(this, minPolicyAllowed);
    }

    function getAdminEventAccess() external view returns (bytes4[] memory) {
        bytes4[] memory eventList = new bytes4[](_adminEventAccess.length);
        for (uint256 i = 0; i < _adminEventAccess.length; i++) {
            eventList[i] = _adminEventAccess[i];
        }
        return eventList;
    }

    function getAdminEventAccessCount() external view returns (uint256) {
        return _adminEventAccess.length;
    }

    function getAdminEventAccessById(uint8 id) public view returns (bytes4) {
        return _adminEventAccess[id];
    }

    function _isKnightSafeAnalyser(address _address) internal view returns (bool) {
        bytes memory encodedParams = abi.encodeCall(IERC165.supportsInterface, (type(IKnightSafeAnalyser).interfaceId)); // to be updated with constant

        bool success;
        uint256 returnSize;
        uint256 returnValue;

        /* solhint-disable no-inline-assembly */
        assembly {
            success := staticcall(30000, _address, add(encodedParams, 0x20), mload(encodedParams), 0x00, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0x00)
        }

        return success && returnSize >= 0x20 && returnValue > 0;
    }

    function setPriceFeed(address priceFeed) public onlyOwner {
        _priceFeed = priceFeed;
        isKnightSafe[priceFeed] = true;

        ControlCenterEventUtils.emitSetPriceFeed(this, priceFeed);
    }

    function getPriceFeed() public view returns (address) {
        return _priceFeed;
    }

    function getDailyVolume(address knightSafeAddress) public view returns (uint256) {
        if (
            _tradingLimitMap[knightSafeAddress].dailyLimitExpiryDate < block.timestamp
                || _tradingLimitMap[knightSafeAddress].dailyLimit < _BASE_TRADING_VOLUME
        ) {
            return _BASE_TRADING_VOLUME;
        }
        return _tradingLimitMap[knightSafeAddress].dailyLimit;
    }

    function setDailyVolume(address knightSafeAddress, uint256 volume) public onlyAdmin {
        _tradingLimitMap[knightSafeAddress].dailyLimit = volume;

        ControlCenterEventUtils.emitSetDailyLimit(this, knightSafeAddress, volume);
    }

    function setDailyVolumeExpiryDate(address knightSafeAddress, uint256 expiryDate) public onlyAdmin {
        _tradingLimitMap[knightSafeAddress].dailyLimitExpiryDate = expiryDate;

        ControlCenterEventUtils.emitSetDailyLimitExpiry(this, knightSafeAddress, expiryDate);
    }

    function setMaxTradingVolume(address knightSafeAddress, uint256 volume) public onlyAdmin {
        _tradingLimitMap[knightSafeAddress].volume = volume;

        ControlCenterEventUtils.emitSetMaxTradingVolume(this, knightSafeAddress, volume);
    }

    function setMaxTradingVolumeExpiryDate(address knightSafeAddress, uint256 expiryDate) public onlyAdmin {
        _tradingLimitMap[knightSafeAddress].volumeExpiryDate = expiryDate;

        ControlCenterEventUtils.emitSetMaxTradingVolumeExpiry(this, knightSafeAddress, expiryDate);
    }

    function getMaxTradingVolume(address knightSafeAddress) public view returns (uint256) {
        if (_tradingLimitMap[knightSafeAddress].volumeExpiryDate < block.timestamp) {
            return 0;
        }
        return _tradingLimitMap[knightSafeAddress].volume;
    }
}
