// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IOwnerManager {
    /// @notice get owner of the contract
    function getOwner() external view returns (address);
    /**
     * @notice set new backup owner to recovery contract
     * @dev only owner can call
     * @param backupOwner new owner address
     * @param takeoverDelayIsSecond delay time for takeover in seconds
     */
    function setBackupOwner(address backupOwner, uint256 takeoverDelayIsSecond) external;
    /// @notice get recovery is started
    function getIsTakeoverInProgress() external view returns (bool);
    /// @notice get recovery process timestamp
    function getTakeoverTimestamp() external view returns (uint256);
    /// @notice get backup progress status
    function getTakeoverStatus() external view returns (address, bool, uint256, uint256);

    /**
     * @notice request recovery process
     * @dev only backup owner can call
     */
    function requestTakeover() external;
    /**
     * @notice confirm recovery process
     * @dev if owner confirm, takeover will be done instantly;
     * @dev backup owner can confirm takeover after delay time
     */
    function confirmTakeover() external;
    /**
     * @notice instantly takeover
     * @dev if takeover delay set to 0,  backup owner can confirm takeover instantly after requestTakeover()
     */
    function instantTakeover() external;
    /**
     * @notice revoke takeover request
     * @dev owner and backup owner can revoke takeover request
     */
    function revokeTakeover() external;

    /// @notice get admin list
    function getAdmins() external view returns (address[] memory);
    /// @notice check address is admin
    function isAdmin(address admin) external view returns (bool);
    /// @notice set new admin
    function addAdmin(address admin) external;
    /// @notice disable admin
    function removeAdmin(address admin) external;
}
