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
    /// @inheritdoc IControlCenter
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

    mapping(address => bytes32) private _controlCenterVersionMap;
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

    constructor(address owner) EventEmitter(owner) {
        _adminMap[owner] = true;
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

    /// @inheritdoc IControlCenter
    function setAdmin(address admin, bool isAdmin) public onlyOwner {
        _adminMap[admin] = isAdmin;
        ControlCenterEventUtils.emitSetAdmin(this, admin, isAdmin);
    }

    /// @inheritdoc IControlCenter
    function isOfficialControlCenter(address controlCenterAddress) public view returns (bool) {
        return _controlCenterVersionMap[controlCenterAddress] != 0;
    }

    /// @inheritdoc IControlCenter
    function addOfficialControlCenter(address controlCenterAddress, bytes32 version) public onlyOwner {
        if (isOfficialControlCenter(controlCenterAddress)) revert Errors.AddressAlreadyExist(controlCenterAddress);
        if (version == 0) revert Errors.IsNullValue();
        _knightSafeVersionMap[controlCenterAddress] = version;

        ControlCenterEventUtils.emitAddedOfficialControlCenter(this, controlCenterAddress, version);
    }

    /// @inheritdoc IControlCenter
    function removeOfficialControlCenter(address controlCenterAddress) public onlyOwner {
        if (!isOfficialControlCenter(controlCenterAddress)) revert Errors.AddressNotExist(controlCenterAddress);
        _knightSafeVersionMap[controlCenterAddress] = 0;

        ControlCenterEventUtils.emitRemovedOfficialControlCenter(this, controlCenterAddress);
    }

    /// @inheritdoc IControlCenter
    function isOfficialImplementation(address implementationAddress) public view returns (bool) {
        return _knightSafeVersionMap[implementationAddress] != 0;
    }

    /// @inheritdoc IControlCenter
    function addOfficialImplementation(address implementationAddress, bytes32 version) public onlyOwner {
        if (isOfficialImplementation(implementationAddress)) revert Errors.AddressAlreadyExist(implementationAddress);
        if (version == 0) revert Errors.IsNullValue();
        _knightSafeVersionMap[implementationAddress] = version;

        ControlCenterEventUtils.emitAddedOfficialImplementation(this, implementationAddress, version);
    }

    /// @inheritdoc IControlCenter
    function removeOfficialImplementation(address implementationAddress) public onlyOwner {
        if (!isOfficialImplementation(implementationAddress)) revert Errors.AddressNotExist(implementationAddress);
        _knightSafeVersionMap[implementationAddress] = 0;

        ControlCenterEventUtils.emitRemovedOfficialImplementation(this, implementationAddress);
    }

    /// @inheritdoc IControlCenter
    function isOfficialAnalyser(address analyserAddress) public view returns (bool) {
        return _analyserVersionMap[analyserAddress] != 0;
    }

    /// @inheritdoc IControlCenter
    function addOfficialAnalyser(address analyserAddress, bytes32 version) public onlyAdmin {
        if (isOfficialAnalyser(analyserAddress)) revert Errors.AddressAlreadyExist(analyserAddress);
        if (version == 0) revert Errors.IsNullValue();
        if (!_isKnightSafeAnalyser(analyserAddress)) {
            revert Errors.InterfaceNotSupport(analyserAddress);
        }

        _analyserVersionMap[analyserAddress] = version;

        ControlCenterEventUtils.emitAddedOfficialAnalyser(this, analyserAddress, version);
    }

    /// @inheritdoc IControlCenter
    function removeOfficialAnalyser(address analyserAddress) public onlyAdmin {
        if (!isOfficialAnalyser(analyserAddress)) revert Errors.AddressNotExist(analyserAddress);
        _analyserVersionMap[analyserAddress] = 0;

        ControlCenterEventUtils.emitRemoveOfficialAnalyser(this, analyserAddress);
    }

    /// @inheritdoc IControlCenter
    function isSpendingLimitEnabled(address knightSafeAddress) public view returns (bool) {
        return _spendingLimitMap[knightSafeAddress];
    }

    /// @inheritdoc IControlCenter
    function setSpendingLimitEnabled(address knightSafeAddress, bool isEnabled) public onlyAdmin {
        _spendingLimitMap[knightSafeAddress] = isEnabled;
        ControlCenterEventUtils.emitSetSpendingLimitEnabled(this, knightSafeAddress, isEnabled);
    }

    /// @inheritdoc IControlCenter
    function getMaxPolicyAllowed(address knightSafeAddress) public view returns (uint256) {
        return _maxPolicyAllowedMap[knightSafeAddress] > _minPolicyAllowed
            ? _maxPolicyAllowedMap[knightSafeAddress]
            : _minPolicyAllowed;
    }

    /// @inheritdoc IControlCenter
    function setMaxPolicyAllowed(address knightSafeAddress, uint256 maxPolicyAllowed) public onlyAdmin {
        _maxPolicyAllowedMap[knightSafeAddress] = maxPolicyAllowed;

        ControlCenterEventUtils.emitSetMaxPolicyAllowed(this, knightSafeAddress, maxPolicyAllowed);
    }

    /// @inheritdoc IControlCenter
    function setGlobalMinPolicyAllowed(uint256 minPolicyAllowed) public onlyOwner {
        _minPolicyAllowed = minPolicyAllowed;

        ControlCenterEventUtils.emitSetGlobalMinPolicyAllowed(this, minPolicyAllowed);
    }

    /// @inheritdoc IControlCenter
    function getAdminEventAccess() external view returns (bytes4[] memory) {
        bytes4[] memory eventList = new bytes4[](_adminEventAccess.length);
        for (uint256 i = 0; i < _adminEventAccess.length; i++) {
            eventList[i] = _adminEventAccess[i];
        }
        return eventList;
    }

    /// @inheritdoc IControlCenter
    function getAdminEventAccessCount() external view returns (uint256) {
        return _adminEventAccess.length;
    }

    /// @inheritdoc IControlCenter
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

    /// @inheritdoc IControlCenter
    function setPriceFeed(address priceFeed) public onlyOwner {
        isKnightSafe[_priceFeed] = false;

        _priceFeed = priceFeed;
        isKnightSafe[priceFeed] = true;

        ControlCenterEventUtils.emitSetPriceFeed(this, priceFeed);
    }

    /// @inheritdoc IControlCenter
    function getPriceFeed() public view returns (address) {
        return _priceFeed;
    }

    /// @inheritdoc IControlCenter
    function getDailyVolume(address knightSafeAddress) public view returns (uint256) {
        if (
            _tradingLimitMap[knightSafeAddress].dailyLimitExpiryDate < block.timestamp
                || _tradingLimitMap[knightSafeAddress].dailyLimit < _BASE_TRADING_VOLUME
        ) {
            return _BASE_TRADING_VOLUME;
        }
        return _tradingLimitMap[knightSafeAddress].dailyLimit;
    }

    /// @inheritdoc IControlCenter
    function setDailyVolume(address knightSafeAddress, uint256 volume) public onlyAdmin {
        _tradingLimitMap[knightSafeAddress].dailyLimit = volume;

        ControlCenterEventUtils.emitSetDailyLimit(this, knightSafeAddress, volume);
    }

    /// @inheritdoc IControlCenter
    function setDailyVolumeExpiryDate(address knightSafeAddress, uint256 expiryDate) public onlyAdmin {
        _tradingLimitMap[knightSafeAddress].dailyLimitExpiryDate = expiryDate;

        ControlCenterEventUtils.emitSetDailyLimitExpiry(this, knightSafeAddress, expiryDate);
    }

    /// @inheritdoc IControlCenter
    function setMaxTradingVolume(address knightSafeAddress, uint256 volume) public onlyAdmin {
        _tradingLimitMap[knightSafeAddress].volume = volume;

        ControlCenterEventUtils.emitSetMaxTradingVolume(this, knightSafeAddress, volume);
    }

    /// @inheritdoc IControlCenter
    function setMaxTradingVolumeExpiryDate(address knightSafeAddress, uint256 expiryDate) public onlyAdmin {
        _tradingLimitMap[knightSafeAddress].volumeExpiryDate = expiryDate;

        ControlCenterEventUtils.emitSetMaxTradingVolumeExpiry(this, knightSafeAddress, expiryDate);
    }

    /// @inheritdoc IControlCenter
    function getMaxTradingVolume(address knightSafeAddress) public view returns (uint256) {
        if (_tradingLimitMap[knightSafeAddress].volumeExpiryDate < block.timestamp) {
            return 0;
        }
        return _tradingLimitMap[knightSafeAddress].volume;
    }

    /// @inheritdoc IControlCenter
    function getMaxVolumeExpiryDate(address knightSafeAddress) public view returns (uint256) {
        return _tradingLimitMap[knightSafeAddress].volumeExpiryDate;
    }
}
