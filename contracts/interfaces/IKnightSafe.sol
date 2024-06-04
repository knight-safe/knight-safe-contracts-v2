// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./IOwnerManager.sol";
import "./IPolicyManager.sol";

interface IKnightSafe {
    /* solhint-disable func-name-mixedcase */
    function VERSION() external view returns (string memory);
    /**
     * @notice proxy contract initialize function
     * @dev this function is called by proxy contract, should not be called directly
     * @param owner owner address
     * @param controlCenter control center address
     * @param fallbackHandler fallback handler address
     */
    function initialize(address owner, address controlCenter, address fallbackHandler) external;
    /// @notice update fallback handler when fallback handler address changed
    function updateFallbackHandler(address handler) external;
    /// @notice update control center when control center address changed
    function updateControlCenter(address controlCenter) external;
}
