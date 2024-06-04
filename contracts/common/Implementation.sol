// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title implemenation
 * @notice implemenation layout for proxy design pattern
 */
abstract contract Implementation {    
    // implementation address needs to be the first declared variable.
    // it should be the first inheritance declaration in order to make proxy storage align.
    address private _implementation;
}