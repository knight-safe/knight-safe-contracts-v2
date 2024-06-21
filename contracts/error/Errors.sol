// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

library Errors {
    error FailedDeployment();

    error InvalidOperation();
    error Unauthorized(address msgSender, string role);

    error InvalidAddress(address _address);
    error AddressAlreadyExist(address _address);
    error AddressNotExist(address _address);

    error IsNullValue();
    error InvalidLength();
    error InvalidValue();

    // error PolicyAlreadyExist(uint256 policyId);
    error PolicyNotExist(uint256 policyId);
    error MaxPolicyCountReached(uint256 maxPolicyCount);
    // error PolicyWhitelistAddressNotFound(address _address);

    error InvalidTakeoverStatus(bool inProgress);
    error TakeoverIsNotReady();

    error InvalidReqId(uint256 reqId);
    error InvalidTransactionStatus();
    error InvalidSettingStatus();

    error InterfaceNotSupport(address _address);
    error AddressIsNotKnightSafeImplementation(address _address);
    error AddressIsNotKnightSafeAnalyser(address _address);
    error AddressIsReadOnlyWhitelist(uint256 policyId, address _address);
    error AddressNotInWhitelist(uint256 policyId, address _address);
    error SelectorNotSupport();
    error ExceedMaxTradingVolume(uint256 txnVolume, uint256 maxVolume);
    error ExceedPolicyVolume(uint256 policyId, uint256 volume);

    error ExecutionFailed();
    error ExecutionFailedWith(bytes data);
    error FeatureNotSupport(string plan);
}
