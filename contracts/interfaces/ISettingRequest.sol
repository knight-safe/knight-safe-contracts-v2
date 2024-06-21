// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "../setting/SettingUtils.sol";

/// @dev Interface of the SettingRequest contract
interface ISettingRequest {
    /// @notice get next setting request id
    function getNextSettingRequestId() external view returns (uint256);
    /// @notice get setting request information by request id
    function getSettingRequest(uint256 reqId) external view returns (SettingUtils.Request memory);

    /**
     * @notice request new setting change
     * @param selector selector id from controlCenter.getAdminEventAccess()
     * @param param encoded setting data
     */
    function requestSetting(uint8 selector, bytes memory param) external returns (uint256 reqId);
    /// @notice cancel setting change by request id
    function cancelSettingByReqId(uint256 reqId) external;
    /// @notice reject setting change by request id
    function rejectSettingByReqId(uint256 reqId) external;
    /// @notice execute setting change by request id
    function executeSettingByReqId(uint256 reqId) external returns (bool success);
}
