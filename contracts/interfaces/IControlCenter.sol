// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./IEventEmitter.sol";

/// @dev Interface of the ControlCenter contract
interface IControlCenter is IEventEmitter {
    /* solhint-disable func-name-mixedcase */
    function VERSION() external view returns (string memory);

    /**
     * @notice update Admin access
     * @dev only Owner can call
     * @param admin Address of the admin
     * @param isAdmin toggle admin access
     */
    function setAdmin(address admin, bool isAdmin) external;

    /**
     * @notice Check implementation is official or not supported
     * @param implementationAddress Address of the implementation contract
     * @return bool True if the implementation is official
     */
    function isOfficialImplementation(address implementationAddress) external view returns (bool);
    /**
     * @notice Add a new official implementation contract
     * @dev only Owner can call
     * @dev version  format: [AppName]_[MajorVer.].[MinorVer.]: e.g. ERC20_1.1
     * @param implementationAddress Address of the implementation contract
     * @param version Version of the analyser contract , format:( [Name]_[MajorVer.].[MinorVer.]: e.g. master_1.1 )
     */
    function addOfficialImplementation(address implementationAddress, bytes32 version) external;
    /**
     * @notice remove unsupported implementation contract
     * @dev only Owner can call
     * @param implementationAddress Address of the implementation contract
     */
    function removeOfficialImplementation(address implementationAddress) external;

    /**
     * @notice Check analyser is official or not supported
     * @param analyserAddress Address of the analyser contract
     * @return bool True if the analyser is official
     */
    function isOfficialAnalyser(address analyserAddress) external view returns (bool);
    /**
     * @notice Add a new official analyser contract
     * @dev only Admin can call
     * @dev version format: [AppName]_[MajorVer.].[MinorVer.]: e.g. ERC20_1.1
     * @param analyserAddress Address of the analyser contract
     * @param version Version of the analyser contract , format:( [AppName]_[MajorVer.].[MinorVer.]: e.g. ERC20_1.1 )
     */
    function addOfficialAnalyser(address analyserAddress, bytes32 version) external;
    /**
     * @notice remove unsupported analyser contract
     * @dev only Admin can call
     * @param analyserAddress Address of the analyser contract
     */
    function removeOfficialAnalyser(address analyserAddress) external;

    /**
     * @notice get available policy count for KnightSafe
     * @param knightSafeAddress Address of the analyser contract
     */
    function getMaxPolicyAllowed(address knightSafeAddress) external view returns (uint256);
    /**
     * @notice set available policy count
     * @dev only Admin can call
     * @param knightSafeAddress Address of the analyser contract
     * @param maxPolicyAllowed Maximum policy count
     */
    function setMaxPolicyAllowed(address knightSafeAddress, uint256 maxPolicyAllowed) external;
    /**
     * @notice set global minimum policy count
     * @dev only Owner can call
     */
    function setGlobalMinPolicyAllowed(uint256 minPolicyAllowed) external;

    /**
     * @notice get admin event access list
     */
    function getAdminEventAccess() external view returns (bytes4[] memory);
    /**
     * @notice get admin event access count
     */
    function getAdminEventAccessCount() external view returns (uint256);
    /**
     * @notice get admin event access by id
     * @param id Event id
     */
    function getAdminEventAccessById(uint8 id) external view returns (bytes4);

    /**
     * @notice Check policy spending limit is enabled or not
     * @param knightSafeAddress Address of the analyser contract
     * @return bool True if the spending limit is enabled
     */
    function isSpendingLimitEnabled(address knightSafeAddress) external view returns (bool);
    /**
     * @notice set spending limit
     * @dev only Admin can call
     * @param knightSafeAddress Address of the analyser contract
     * @param isEnabled True if the spending limit is enabled
     */
    function setSpendingLimitEnabled(address knightSafeAddress, bool isEnabled) external;

    /**
     * @notice get price feed address
     * @return Price feed address
     */
    function getPriceFeed() external view returns (address);
    /**
     * @notice get price feed address
     * @dev only owner can call
     * @param priceFeed Price feed address
     */
    function setPriceFeed(address priceFeed) external;

    /**
     * @notice get daily transaction volume limit
     * @param knightSafeAddress  knight safe account
     * @return Limit transaction volume limit as 30 decimals
     */
    function getDailyVolume(address knightSafeAddress) external view returns (uint256);
    /**
     * @notice set daily limit
     * @dev only Admin can call
     * @dev daily Limit must cast to 30 decimals
     * @param knightSafeAddress  knight safe account
     * @param volume daily limit with 30 decimals
     */
    function setDailyVolume(address knightSafeAddress, uint256 volume) external;
    /**
     * @notice set daily limit date due to
     * @dev only Admin can call
     * @param knightSafeAddress  knight safe account
     * @param expiryDate Expiration date of the limit
     */
    function setDailyVolumeExpiryDate(address knightSafeAddress, uint256 expiryDate) external;

    /**
     * @notice get daily transaction volume limit
     * @param knightSafeAddress knight safe account
     * @return Limit transaction volume limit with 30 decimals
     */
    function getMaxTradingVolume(address knightSafeAddress) external view returns (uint256);
    /**
     * @notice set account volume limit
     * @dev only Admin can call
     * @dev volume Limit must cast to 30 decimals
     * @param knightSafeAddress  knight safe account
     * @param volume transaction volume limit with 30 decimals
     */
    function setMaxTradingVolume(address knightSafeAddress, uint256 volume) external;
    /**
     * @notice set account volume limit date due to
     * @dev only Admin can call
     * @param knightSafeAddress  knight safe account
     * @param expiryDate Expiration date of the limit
     */
    function setMaxTradingVolumeExpiryDate(address knightSafeAddress, uint256 expiryDate) external;
}
