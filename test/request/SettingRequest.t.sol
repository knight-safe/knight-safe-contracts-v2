// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./TransactionRequest.t.sol";
import "../base/OwnerManager.t.sol";
import "../base/PolicyManager.t.sol";
import "@/utils/Cast.sol";
import "@/KnightSafe.sol";
import "@/knightSafeAnalyser/SampleKnightSafeAnalyser.sol";
import "@/base/PolicyManager.sol";
import "@/interfaces/IEventEmitter.sol";

abstract contract SettingRequestTest is TransactionRequestTest {
    function _requestSetting() internal {
        vm.startPrank(adminAddress);
        assertEq(knightSafe.getNextSettingRequestId(), 0);

        knightSafe.requestSetting(0, abi.encode()); // Create Policy
        assertEq(knightSafe.getNextSettingRequestId(), 1);
        knightSafe.requestSetting(1, abi.encode(defaultPolicyId, whiteListAddress0, address(ksa))); // Update Whitelist
        assertEq(knightSafe.getNextSettingRequestId(), 2);
        knightSafe.requestSetting(2, abi.encode(0, trader)); // Add Trader
        assertEq(knightSafe.getNextSettingRequestId(), 3);
        vm.stopPrank();
    }

    function test_requestSetting() public {
        _addAdmin();
        assertEq(knightSafe.getNextSettingRequestId(), 0);
        SettingUtils.Request memory request;
        request.requester = address(adminAddress);
        request.selector = 0; // CreatePolicy
        request.data = abi.encodePacked(abi.encode());
        request.status = SettingUtils.Status.Pending;

        vm.expectEmit(true, true, false, true);
        emit SettingEventLog(
            address(policyManager),
            "CreatedSettingRequest",
            "CreatedSettingRequest",
            Cast._toBytes32(address(policyManager)),
            0
        );
        _requestSetting();
        assertEq(knightSafe.getNextSettingRequestId(), 3);
    }

    function test_requestSetting_fail() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidReqId.selector, 10));
        knightSafe.getSettingRequest(10);

        assertEq(knightSafe.getNextSettingRequestId(), 0);

        vm.prank(unauthorizedOwnerAddress);
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, unauthorizedOwnerAddress, "ADMIN+"));
        knightSafe.requestSetting(0, abi.encode()); // Create policy

        assertEq(knightSafe.getNextSettingRequestId(), 0);
    }

    function test_executeSettingByReqId() public {
        _addAdmin();
        _requestSetting();
        assertEq(knightSafe.getNextSettingRequestId(), 3);

        SettingUtils.Request memory settingRequest;
        knightSafe.executeSettingByReqId(0);
        settingRequest = knightSafe.getSettingRequest(0);
        assertTrue(settingRequest.status == SettingUtils.Status.Completed);
        assertEq(knightSafe.getActivePolicyIds().length, 2);

        knightSafe.executeSettingByReqId(1);
        settingRequest = knightSafe.getSettingRequest(1);
        assertTrue(settingRequest.status == SettingUtils.Status.Completed);
        assertTrue(knightSafe.isPolicyWhitelistAddress(defaultPolicyId, whiteListAddress0));

        knightSafe.executeSettingByReqId(2);
        settingRequest = knightSafe.getSettingRequest(2);
        assertTrue(settingRequest.status == SettingUtils.Status.Completed);
        assertTrue(policyManager.isTrader(0, trader));
    }

    function _cancelSettingByReqId() internal {
        SettingUtils.Request memory settingRequest;
        vm.prank(adminAddress);
        knightSafe.cancelSettingByReqId(0);
        settingRequest = knightSafe.getSettingRequest(0);
        assertTrue(settingRequest.status == SettingUtils.Status.Cancelled);
    }

    function test_executeSettingByReqId_fail() public {
        _addAdmin();
        _requestSetting();
        assertEq(knightSafe.getNextSettingRequestId(), 3);

        vm.prank(adminAddress);
        knightSafe.requestSetting(3, abi.encode(1)); // REMOVE_POLICY
        assertEq(knightSafe.getNextSettingRequestId(), 4);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.ExecutionFailedWith.selector, abi.encodeWithSelector(Errors.PolicyNotExist.selector, 1)
            )
        );
        knightSafe.executeSettingByReqId(3);

        vm.prank(adminAddress);
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, adminAddress, "OWNER"));
        knightSafe.executeSettingByReqId(0);

        _cancelSettingByReqId();
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidSettingStatus.selector));
        knightSafe.executeSettingByReqId(0);

        knightSafe.requestSetting(2, abi.encode(10, whiteListAddress0, address(ksa))); // Update Whitelist
        assertEq(knightSafe.getNextSettingRequestId(), 5);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.ExecutionFailedWith.selector, abi.encodeWithSelector(Errors.PolicyNotExist.selector, 10)
            )
        );
        knightSafe.executeSettingByReqId(4);

        // fail with invalid selector
        knightSafe.requestSetting(9, abi.encode(10, whiteListAddress0, address(ksa)));
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidOperation.selector));
        knightSafe.executeSettingByReqId(5);
    }

    function test_cancelSettingByReqId() public {
        _addAdmin();
        _requestSetting();
        assertEq(knightSafe.getNextSettingRequestId(), 3);

        _cancelSettingByReqId();
    }

    function testRevert_cancelSettingByReqId() public {
        _addAdmin();
        _requestSetting();
        assertEq(knightSafe.getNextSettingRequestId(), 3);

        _cancelSettingByReqId();

        vm.prank(adminAddress);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidSettingStatus.selector));
        knightSafe.cancelSettingByReqId(0);

        // test revert when sender is not owner
        vm.prank(unauthorizedOwnerAddress);
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, unauthorizedOwnerAddress, "ADMIN+"));
        knightSafe.cancelSettingByReqId(1);

        vm.prank(ownerAddress);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidOperation.selector));
        knightSafe.cancelSettingByReqId(1);
    }

    function test_rejectSettingByReqId() public {
        _addAdmin();
        _requestSetting();
        assertEq(knightSafe.getNextSettingRequestId(), 3);

        knightSafe.rejectSettingByReqId(0);
        SettingUtils.Request memory settingRequest = knightSafe.getSettingRequest(0);
        assertTrue(settingRequest.status == SettingUtils.Status.Rejected);
    }

    function test_rejectSettingByReqId_fail() public {
        _addAdmin();
        _requestSetting();
        assertEq(knightSafe.getNextSettingRequestId(), 3);

        _cancelSettingByReqId();

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidSettingStatus.selector));
        knightSafe.rejectSettingByReqId(0);

        uint256 invalidReqId = knightSafe.getNextSettingRequestId() + 1;
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidReqId.selector, invalidReqId));
        knightSafe.rejectSettingByReqId(invalidReqId);

        // test revert when sender is not owner
        vm.prank(adminAddress);
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, adminAddress, "OWNER"));
        knightSafe.rejectSettingByReqId(1);
    }

    function test_requestIncreasePolicyLimit() public {
        _addAdmin();
        controlCenter.setSpendingLimitEnabled(address(knightSafe), true);
        assertTrue(controlCenter.isSpendingLimitEnabled(address(knightSafe)));

        vm.startPrank(adminAddress);

        assertEq(knightSafe.getNextSettingRequestId(), 0);
        knightSafe.requestSetting(6, abi.encode(defaultPolicyId, _castToDefaultDecimal(20 * 1000))); // Update Whitelist
        assertEq(knightSafe.getNextSettingRequestId(), 1);

        vm.stopPrank();

        SettingUtils.Request memory settingRequest;
        knightSafe.executeSettingByReqId(0);
        settingRequest = knightSafe.getSettingRequest(0);
        assertTrue(settingRequest.status == SettingUtils.Status.Completed);
        assertEq(knightSafe.getMaxSpendingLimit(defaultPolicyId), _castToDefaultDecimal(20 * 1000));
    }

    event SettingEventLog(
        address msgSender, string eventName, string indexed eventNameHash, bytes32 indexed profile, uint256 reqId
    );
}
