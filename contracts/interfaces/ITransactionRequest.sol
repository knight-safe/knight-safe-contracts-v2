// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "../transaction/Transaction.sol";

/// @dev Interface of the TransactionRequest contract
interface ITransactionRequest {
    /// @notice get daily volume spent in USD
    function dailyVolumeSpent() external view returns (uint256);
    /// @notice get total volume spent in USD
    function accountVolumeSpent() external view returns (uint256);
    /// @notice get last updated volume date
    function lastDailyVolumeDate() external view returns (uint256);
    /// @notice get sum of daily and total volume spent  in USD
    function getTotalVolumeSpent() external view returns (uint256);

    /// @notice get transaction request nonce
    function getNextTransactionRequestId() external view returns (uint256);
    /// @notice get transaction request information by request id
    function getTransactionRequest(uint256 reqId) external view returns (Transaction.Request memory);

    /**
     * @notice validate trading access for transaction
     * @dev if ksa set to 1, will skip whitelist check
     * @dev check address is in whitelist
     * @param policyId policy id
     * @param useGlobalWhitelist use global whitelist or policy whitelist
     * @param to transaction to address
     * @param data transaction data
     */
    function validateTradingAccess(
        uint256 policyId,
        bool useGlobalWhitelist,
        address to, /* uint256 value, */
        bytes memory data
    ) external returns (address[] memory addresses, uint256[] memory amounts);
    /**
     * @notice validate trading limit for transaction
     * @dev get transaction volume in USD from price feed
     * @param addresses address list
     * @param amounts amount list
     * @param value transaction value
     */
    function validateTradingLimit(address[] memory addresses, uint256[] memory amounts, uint256 value)
        external
        returns (uint256);
    /**
     * @notice validate policy limit for transaction
     * @dev validate on user in subscribed feature
     * @param policyId policy id
     * @param useGlobalWhitelist use global whitelist or policy whitelist
     * @param volume transaction volume in USD
     */
    function validatePolicyLimit(uint256 policyId, bool useGlobalWhitelist, uint256 volume) external;

    /**
     * @notice request transaction
     * @param onBehalfOfPolicyId policy id to request transaction
     * @param to to contract
     * @param value transaction value
     * @param data encoded transaction data
     */
    function requestTransaction(uint256 onBehalfOfPolicyId, address to, uint256 value, bytes memory data)
        external
        returns (uint256 reqId);
    /// @notice cancel transaction by request id
    function cancelTransactionByReqId(uint256 onBehalfOfPolicyId, uint256 reqId) external;
    /// @notice reject transaction by request id
    function rejectTransactionByReqId(uint256 onBehalfOfPolicyId, bool useGlobalWhitelist, uint256 reqId) external;
    /// @notice execute transaction by request id
    function executeTransactionByReqId(uint256 onBehalfOfPolicyId, bool useGlobalWhitelist, uint256 reqId) external;
    /**
     * @notice execute transaction
     * @dev this function will call execute with out request
     */
    function executeTransaction(
        uint256 onBehalfOfPolicyId,
        bool useGlobalWhitelist,
        address to,
        uint256 value,
        bytes memory data
    ) external;
}
