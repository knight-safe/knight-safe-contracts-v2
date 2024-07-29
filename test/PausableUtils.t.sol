// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../contracts/common/PausableUtils.sol";
import "../contracts/KnightSafe.sol";
import "../contracts/base/PolicyManager.sol";
import "./request/SettingRequest.t.sol";

abstract contract PausableUtilsTest is SettingRequestTest {
    function test_pause() public {
        knightSafe.pause();
        assertTrue(knightSafe.paused());

        knightSafe.unpause();

        _addAdmin();
        vm.prank(adminAddress);
        knightSafe.pause();
        assertTrue(knightSafe.paused());
    }

    function testRevert_pause() public {
        vm.prank(address(unauthorizedOwnerAddress));
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, unauthorizedOwnerAddress, "ADMIN+"));
        knightSafe.pause();
        assertFalse(knightSafe.paused());
    }

    function test_unpause() public {
        knightSafe.pause();
        assertTrue(knightSafe.paused());
        knightSafe.unpause();
        assertFalse(knightSafe.paused());
    }

    function testRevert_unpause() public {
        knightSafe.pause();
        assertTrue(knightSafe.paused());

        vm.prank(address(adminAddress));
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, adminAddress, "OWNER"));
        knightSafe.unpause();
        assertTrue(knightSafe.paused());
    }

    function testRevert_ExecuteTransactionWhenPaused() public {
        _updateWhitelist();

        _requestTransaction();
        assertEq(knightSafe.getNextTransactionRequestId(), 1);

        knightSafe.pause();
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        policyManager.executeTransactionByReqId(defaultPolicyId, false, 0);
    }
}
