// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IKnightSafeAnalyser {
    /**
     * @dev this function is used to extract addresses and values from transaction data
     * @param to address of the contract
     * @param data transaction data
     */
    function extractAddressesWithValue(address to, bytes memory data)
        external
        view
        returns (address[] memory, uint256[] memory);
}
