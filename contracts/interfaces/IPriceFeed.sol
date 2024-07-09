// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

interface IPriceFeed {
    /// @notice get wrapped native token address
    function getNativeToken() external view returns (address);
    /// @notice get price feed for token
    function getTransactionVolume(address[] memory contractAddresses, uint256[] memory amounts)
        external
        view
        returns (uint256);
    /// @notice get price feed for native token
    function getNativeTokenVolume(uint256 amount) external view returns (uint256);

    /// @notice get price feed address from token
    function getPriceFeed(address token) external view returns (address);
    /**
     * @notice Set price feed address for token
     * @dev Price Feed must return as USD price
     * @param token token address
     * @param priceFeed price feed address
     */
    function setPriceFeed(address token, address priceFeed, uint256 heartbeatTime) external;
    /**
     * @notice batch set price feed address for token
     * @dev Price Feed must return as USD price
     */
    function batchSetPriceFeed(address[] memory tokens, address[] memory priceFeeds, uint256[] memory heartbeatTimes)
        external;
}
