// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./ITransactionRequest.sol";

/// @dev Interface of the PolicyManager contract
/// @dev inherit OwnerManager
interface IPolicyManager is ITransactionRequest {
    /// @notice get active policy ids list
    function getActivePolicyIds() external view returns (uint256[] memory);
    /// @notice check policy is active
    function isActivePolicy(uint256 policyId) external view returns (bool);
    /**
     * @notice create new policy group
     * @dev id 0 used for global policy, so length can be maxPolicyCount + 1
     */
    function createPolicy() external;
    /**
     * @notice disable policy group
     * @param policyId policy id
     */
    function removePolicy(uint256 policyId) external;

    /// @notice get active traders ids list
    function getTraders(uint256 policyId) external view returns (address[] memory);
    /// @notice check trader is active
    function isTrader(uint256 policyId, address trader) external view returns (bool);
    /**
     * @notice add trader to policy group
     * @dev only ks owner can add
     * @param policyId policy id
     * @param trader trader address
     */
    function addTrader(uint256 policyId, address trader) external;
    /**
     * @notice remove trader from policy group
     * @dev  ks owner and admin can remove
     * @param policyId policy id
     * @param trader trader address
     */
    function removeTrader(uint256 policyId, address trader) external;

    /// @notice get active whitelist addresses list
    function getWhitelistAddresses(uint256 policyId) external view returns (address[] memory);
    /**
     * @notice check address is in whitelist
     * @param policyId policy id
     * @param _address address to check
     */
    function isPolicyWhitelistAddress(uint256 policyId, address _address) external view returns (bool);
    /**
     * @notice check address is in whitelist
     * @dev this function use for validate trading access
     * @param policyId policy id
     * @param _address address to check
     */
    function isPolicyOrGlobalWhitelistAddress(uint256 policyId, address _address) external view returns (bool);
    /**
     * @notice add trader or contract to whitelist
     * @dev Assume all addresses are checked before adding to the control center
     * @param policyId policy id
     * @param whitelistAddress address to add
     * @param officialAnalyserAddress official analyser address
     */
    function updateWhitelist(uint256 policyId, address whitelistAddress, address officialAnalyserAddress) external;
    /**
     * @notice remove address from whitelist
     * @param policyId policy id
     * @param whitelistAddress address to remove
     */
    function removeWhitelist(uint256 policyId, address whitelistAddress) external;
    /// @notice get analyser address for whitelist
    function getKnightSafeAnalyserAddress(uint256 policyId, address whitelistAddress) external view returns (address);

    /// @notice get spending limit status
    function getMaxSpendingLimit(uint256 policyId) external view returns (uint256);
    /// @notice get daily volume spent in USD with 30 decimals
    function getDailyVolumeSpent(uint256 policyId) external view returns (uint256);
    /**
     * @notice increase or reduce spending limit
     * @dev only owner can call
     * @param policyId policy id
     * @param maxSpendingLimit spending limit with 30 decimals
     */
    function setMaxSpendingLimit(uint256 policyId, uint256 maxSpendingLimit) external;
    /**
     * @notice reduce spending limit to new value
     *  @dev only owner can increase, admin will revert when value is greater than current
     * @param policyId policy id
     * @param maxSpendingLimit spending limit with 30 decimals
     */
    function reduceSpendingLimit(uint256 policyId, uint256 maxSpendingLimit) external;
    /**
     * @notice reset daily spent
     * @dev only owner can call
     * @param policyId policy id
     */
    function resetDailySpent(uint256 policyId) external;
}
