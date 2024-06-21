// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Multicall.sol";
import "./common/NativeCurrencyReceiver.sol";
import "./common/SignatureValidator.sol";
import "./interfaces/IKnightSafe.sol";
import "./interfaces/IControlCenter.sol";
import "./base/PolicyManager.sol";
import "./base/ControlCenterManager.sol";
import "./base/FallbackManager.sol";
import "./setting/SettingRequest.sol";
import "./transaction/TransactionRequest.sol";

contract KnightSafe is
    NativeCurrencyReceiver,
    TransactionRequest,
    SettingRequest,
    IKnightSafe,
    SignatureValidator,
    Multicall,
    FallbackManager
{
    string public constant override VERSION = "2.0.0";

    constructor() {
        _initOwnerManager(address(1));
    }

    /// @inheritdoc IKnightSafe
    function initialize(address owner, address controlCenter, address fallbackHandler) external {
        _initOwnerManager(owner);
        _initPolicyManager();
        _setControlCenter(controlCenter);
        if (fallbackHandler != address(0)) _internalSetFallbackHandler(fallbackHandler);
    }

    /// @inheritdoc IKnightSafe
    function updateFallbackHandler(address handler) external onlyOwner {
        _internalSetFallbackHandler(handler);
    }

    /// @inheritdoc IKnightSafe
    function updateControlCenter(address controlCenter) external onlyOwner {
        _setControlCenter(controlCenter);
    }
}
