// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./OwnerManager.sol";
import "./PolicyManagerEventUtils.sol";
import "../interfaces/IPolicyManager.sol";
import "../interfaces/IKnightSafeAnalyser.sol";

/// @notice inherit Doc {IPolicyManager}
abstract contract PolicyManager is IPolicyManager, OwnerManager {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    struct Policy {
        EnumerableSet.AddressSet traders;
        EnumerableSet.AddressSet whitelistKeys;
        mapping(address => address) whitelistValues;
        uint256 maxSpendingLimit;
        uint256 lastDailyVolumeDate;
        uint256 dailyVolumeSpent;
    }

    uint256 public nextPolicyId;
    EnumerableSet.UintSet internal _activePolicyIds;
    mapping(uint256 => Policy) internal _policyMap;

    modifier onlyTrader(uint256 policyId) {
        if (!_activePolicyIds.contains(policyId)) revert Errors.PolicyNotExist(policyId);
        if (!isTrader(0, _msgSender()) && !isTrader(policyId, _msgSender())) {
            revert Errors.Unauthorized(_msgSender(), "TRADER");
        }
        _;
    }

    function _initPolicyManager() internal {
        if (nextPolicyId != 0) revert Errors.InvalidOperation();
        _activePolicyIds.add(0);
        nextPolicyId = 1;
    }

    /// @inheritdoc IPolicyManager
    function getActivePolicyIds() public view returns (uint256[] memory) {
        return _activePolicyIds.values();
    }

    /// @inheritdoc IPolicyManager
    function isActivePolicy(uint256 policyId) external view returns (bool) {
        return _activePolicyIds.contains(policyId);
    }

    /// @inheritdoc IPolicyManager
    function createPolicy() external onlyAdminOrOwner {
        uint256 maxPolicyCount = (IControlCenter(_controlCenter)).getMaxPolicyAllowed(address(this));
        if (_activePolicyIds.length() > maxPolicyCount) revert Errors.MaxPolicyCountReached(maxPolicyCount);
        uint256 policyId = nextPolicyId;
        nextPolicyId += 1;
        _activePolicyIds.add(policyId);

        PolicyManagerEventUtils.emitCreatedPolicy(_controlCenter, address(this), policyId);
    }

    /// @inheritdoc IPolicyManager
    function removePolicy(uint256 policyId) public onlyAdminOrOwner {
        if (policyId == 0) revert Errors.InvalidOperation();
        if (!_activePolicyIds.contains(policyId)) revert Errors.PolicyNotExist(policyId);
        _activePolicyIds.remove(policyId);

        PolicyManagerEventUtils.emitRemovedPolicy(_controlCenter, address(this), policyId);
    }

    /// @inheritdoc IPolicyManager
    function getTraders(uint256 policyId) external view returns (address[] memory) {
        return _policyMap[policyId].traders.values();
    }

    /// @inheritdoc IPolicyManager
    function isTrader(uint256 policyId, address trader) public view returns (bool) {
        return _policyMap[policyId].traders.contains(trader);
    }

    /// @inheritdoc IPolicyManager
    function addTrader(uint256 policyId, address trader) public onlyOwner {
        if (!_activePolicyIds.contains(policyId)) revert Errors.PolicyNotExist(policyId);
        if (isTrader(policyId, trader)) revert Errors.AddressAlreadyExist(trader);
        _policyMap[policyId].traders.add(trader);

        PolicyManagerEventUtils.emitAddedTrader(_controlCenter, address(this), policyId, trader);
    }

    /// @inheritdoc IPolicyManager
    function removeTrader(uint256 policyId, address trader) public onlyAdminOrOwner {
        if (!_activePolicyIds.contains(policyId)) revert Errors.PolicyNotExist(policyId);
        if (!isTrader(policyId, trader)) revert Errors.AddressNotExist(trader);
        _policyMap[policyId].traders.remove(trader);

        PolicyManagerEventUtils.emitRemovedTrader(_controlCenter, address(this), policyId, trader);
    }

    /// @inheritdoc IPolicyManager
    function getWhitelistAddresses(uint256 policyId) external view returns (address[] memory) {
        return _policyMap[policyId].whitelistKeys.values();
    }

    /// @inheritdoc IPolicyManager
    function isPolicyWhitelistAddress(uint256 policyId, address _address) public view returns (bool) {
        return _policyMap[policyId].whitelistKeys.contains(_address);
    }

    /// @inheritdoc IPolicyManager
    function isPolicyOrGlobalWhitelistAddress(uint256 policyId, address _address) public view returns (bool) {
        return _policyMap[policyId].whitelistKeys.contains(_address) || _policyMap[0].whitelistKeys.contains(_address);
    }

    /// @inheritdoc IPolicyManager
    function updateWhitelist(uint256 policyId, address whitelistAddress, address officialAnalyserAddress)
        external
        onlyOwner
    {
        if (!_activePolicyIds.contains(policyId)) revert Errors.PolicyNotExist(policyId);
        if (whitelistAddress == address(0)) revert Errors.InvalidAddress(address(0));
        if (!(IControlCenter(_controlCenter)).isOfficialAnalyser(officialAnalyserAddress)) {
            revert Errors.AddressIsNotKnightSafeAnalyser(officialAnalyserAddress);
        }

        _policyMap[policyId].whitelistValues[whitelistAddress] = officialAnalyserAddress;

        if (_policyMap[policyId].whitelistKeys.contains(whitelistAddress)) {
            PolicyManagerEventUtils.emitUpdatedWhitelist(
                _controlCenter, address(this), policyId, whitelistAddress, officialAnalyserAddress
            );
        } else {
            _policyMap[policyId].whitelistKeys.add(whitelistAddress);
            PolicyManagerEventUtils.emitAddedWhitelist(
                _controlCenter, address(this), policyId, whitelistAddress, officialAnalyserAddress
            );
        }
    }

    /// @inheritdoc IPolicyManager
    function removeWhitelist(uint256 policyId, address whitelistAddress) public onlyAdminOrOwner {
        if (!_activePolicyIds.contains(policyId)) revert Errors.PolicyNotExist(policyId);
        if (whitelistAddress == address(0)) revert Errors.InvalidAddress(address(0));
        if (!_policyMap[policyId].whitelistKeys.contains(whitelistAddress)) {
            revert Errors.AddressNotExist(whitelistAddress);
        }
        _policyMap[policyId].whitelistValues[whitelistAddress] = address(0);
        _policyMap[policyId].whitelistKeys.remove(whitelistAddress);

        PolicyManagerEventUtils.emitRemovedWhitelist(_controlCenter, address(this), policyId, whitelistAddress);
    }

    /// @inheritdoc IPolicyManager
    function getKnightSafeAnalyserAddress(uint256 policyId, address whitelistAddress) public view returns (address) {
        return _policyMap[policyId].whitelistValues[whitelistAddress];
    }

    /// @inheritdoc IPolicyManager
    function getMaxSpendingLimit(uint256 policyId) public view returns (uint256) {
        return _policyMap[policyId].maxSpendingLimit;
    }

    /// @inheritdoc IPolicyManager
    function getDailyVolumeSpent(uint256 policyId) public view returns (uint256) {
        return _policyMap[policyId].dailyVolumeSpent;
    }

    /// @inheritdoc IPolicyManager
    function setMaxSpendingLimit(uint256 policyId, uint256 maxSpendingLimit) public onlyOwner {
        if (!_activePolicyIds.contains(policyId)) revert Errors.PolicyNotExist(policyId);
        if (!_controlCenter.isSpendingLimitEnabled(address(this))) revert Errors.FeatureNotSupport("RETAIL");

        _policyMap[policyId].maxSpendingLimit = maxSpendingLimit;
    }

    /// @inheritdoc IPolicyManager
    function reduceSpendingLimit(uint256 policyId, uint256 maxSpendingLimit) public onlyAdminOrOwner {
        if (!_activePolicyIds.contains(policyId)) revert Errors.PolicyNotExist(policyId);
        if (!_controlCenter.isSpendingLimitEnabled(address(this))) revert Errors.FeatureNotSupport("RETAIL");
        if (maxSpendingLimit > _policyMap[policyId].maxSpendingLimit) {
            revert Errors.InvalidValue();
        }

        _policyMap[policyId].maxSpendingLimit = maxSpendingLimit;
    }

    /// @inheritdoc IPolicyManager
    function resetDailySpent(uint256 policyId) public onlyOwner {
        _policyMap[policyId].dailyVolumeSpent = 0;
    }
}
