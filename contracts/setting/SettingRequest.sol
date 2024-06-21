// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./SettingUtils.sol";
import "./SettingEventUtils.sol";
import "../base/ControlCenterManager.sol";
import "../error/Errors.sol";
import "../base/OwnerManager.sol";
import "../interfaces/ISettingRequest.sol";

/// @notice inherit Doc {ISettingRequest}
contract SettingRequest is ControlCenterManager, OwnerManager, ISettingRequest {
    uint256 private _nonce;
    mapping(uint256 => SettingUtils.Request) private _settingRequests;

    /// @notice inherit Doc {ISettingRequest}
    function getNextSettingRequestId() public view returns (uint256) {
        return _nonce;
    }

    /// @notice inherit Doc {ISettingRequest}
    function getSettingRequest(uint256 reqId) public view returns (SettingUtils.Request memory) {
        if (reqId >= _nonce) revert Errors.InvalidReqId(reqId);
        return _settingRequests[reqId];
    }

    /// @notice inherit Doc {ISettingRequest}
    function requestSetting(uint8 selector, bytes memory param) public onlyAdminOrOwner returns (uint256 reqId) {
        SettingUtils.Request memory request;
        request.requester = _msgSender();
        request.selector = selector;
        request.data = param;
        request.status = SettingUtils.Status.Pending;

        reqId = _nonce;
        _nonce += 1;
        _settingRequests[reqId] = request;
        SettingEventUtils.emitCreatedSettingRequest(_controlCenter, address(this), reqId);
    }

    function _updateSettingRequestStatus(uint256 reqId, SettingUtils.Status status) private {
        if (_settingRequests[reqId].status != SettingUtils.Status.Pending || status == SettingUtils.Status.Pending) {
            revert Errors.InvalidSettingStatus();
        }
        _settingRequests[reqId].status = status;
    }

    /// @notice inherit Doc {ISettingRequest}
    function executeSettingByReqId(uint256 reqId) public onlyOwner returns (bool success) {
        SettingUtils.Request memory request = getSettingRequest(reqId);
        _updateSettingRequestStatus(reqId, SettingUtils.Status.Completed);

        if (request.selector >= _controlCenter.getAdminEventAccessCount()) {
            revert Errors.InvalidOperation();
        }

        bytes memory returnData;
        /* solhint-disable  avoid-low-level-calls */
        (success, returnData) = address(this).delegatecall(
            bytes.concat(_controlCenter.getAdminEventAccessById(request.selector), request.data)
        );
        if (!success) revert Errors.ExecutionFailedWith(returnData);

        SettingEventUtils.emitApprovedSettingRequest(_controlCenter, address(this), reqId);
    }

    /// @notice inherit Doc {ISettingRequest}
    function cancelSettingByReqId(uint256 reqId) public onlyAdminOrOwner {
        SettingUtils.Request memory request = getSettingRequest(reqId);
        _updateSettingRequestStatus(reqId, SettingUtils.Status.Cancelled);
        if (request.requester != _msgSender()) revert Errors.InvalidOperation();

        SettingEventUtils.emitCancelledSettingRequest(_controlCenter, address(this), reqId);
    }

    /// @notice inherit Doc {ISettingRequest}
    function rejectSettingByReqId(uint256 reqId) public onlyOwner {
        if (reqId >= _nonce) revert Errors.InvalidReqId(reqId);
        _updateSettingRequestStatus(reqId, SettingUtils.Status.Rejected);
        SettingEventUtils.emitRejectedSettingRequest(_controlCenter, address(this), reqId);
    }
}
