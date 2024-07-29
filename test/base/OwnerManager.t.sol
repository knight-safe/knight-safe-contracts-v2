// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import "../KnightSafe.t.sol";

// This test file is used to test the PolicyManager contract
abstract contract OwnerManagerTest is KnightSafeProxyTest {
    OwnerManager ownerManager;

    function setUp() public virtual override {
        super.setUp();
        ownerManager = OwnerManager(address(ksProxy));
    }

    function _addAdmin() internal {
        ownerManager.addAdmin(adminAddress);
    }

    function test_addAdmin() public {
        assertTrue(ownerManager.isAdmin(adminAddress) == false);

        _addAdmin();
        assertTrue(ownerManager.isAdmin(adminAddress) == true);
    }

    function testRevert_addAdmin() public {
        assertTrue(ownerManager.isAdmin(adminAddress) == false);

        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, address(0), "OWNER"));
        ownerManager.addAdmin(adminAddress);
        vm.stopPrank();

        _addAdmin();
        vm.expectRevert(abi.encodeWithSelector(Errors.AddressAlreadyExist.selector, adminAddress));
        ownerManager.addAdmin(adminAddress);
    }

    function test_removeAdmin() public {
        _addAdmin();
        assertTrue(ownerManager.isAdmin(adminAddress) == true);

        ownerManager.removeAdmin(adminAddress);
        assertTrue(ownerManager.isAdmin(adminAddress) == false);
    }

    function testRevert_removeAdmin() public {
        assertTrue(ownerManager.isAdmin(adminAddress) == false);

        vm.expectRevert(abi.encodeWithSelector(Errors.AddressNotExist.selector, adminAddress));
        ownerManager.removeAdmin(adminAddress);
    }

    uint256 deplayTimeSecond = 3600;

    function _setBackupOwner() internal {
        ownerManager.setBackupOwner(backupOwnerAddress, deplayTimeSecond);
    }

    // function test_setBackupOwner() public {
    //     _setBackupOwner();

    //     (address bcOwner, uint256 tackoverDelay) = ownerManager.getBackupOwner();

    //     assertEq(bcOwner, backupOwnerAddress);
    //     assertEq(tackoverDelay, deplayTimeSecond);
    // }

    function _requestTakeover() internal {
        _setBackupOwner();
        vm.startPrank(backupOwnerAddress);
        ownerManager.requestTakeover();
        vm.stopPrank();
    }

    function test_requestTakeover() public {
        _requestTakeover();
        assertTrue(ownerManager.getIsTakeoverInProgress());
        assertGt(ownerManager.getTakeoverTimestamp(), deplayTimeSecond);
    }

    function testRevert_setBackupOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidAddress.selector, address(ksProxy)));
        ownerManager.setBackupOwner(address(ksProxy), deplayTimeSecond);

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidAddress.selector, address(0)));
        ownerManager.setBackupOwner(address(0), deplayTimeSecond);

        _requestTakeover();
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidTakeoverStatus.selector, true));
        ownerManager.setBackupOwner(vm.addr(99), deplayTimeSecond);
    }

    function testRevert_requestTakeover() public {
        vm.prank(address(this));
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, address(this), "BACKUP"));
        ownerManager.requestTakeover();

        _requestTakeover();
        assertEq(ownerManager.getIsTakeoverInProgress(), true);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidTakeoverStatus.selector, true));
        ownerManager.setBackupOwner(vm.addr(99), deplayTimeSecond);
    }

    function test_confirmTakeover_byBackupOwner() public {
        _requestTakeover();
        vm.warp(block.timestamp + deplayTimeSecond + 1 hours);
        vm.prank(backupOwnerAddress);
        ownerManager.confirmTakeover();
        assertEq(ownerManager.getOwner(), backupOwnerAddress);
        assertEq(ownerManager.getIsTakeoverInProgress(), false);
    }

    function test_confirmTakeover_byOwner() public {
        _requestTakeover();
        ownerManager.confirmTakeover();
        assertEq(ownerManager.getOwner(), backupOwnerAddress);
        assertEq(ownerManager.getIsTakeoverInProgress(), false);
    }

    function testRevert_confirmTakeover() public {
        _setBackupOwner();
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidTakeoverStatus.selector, false));
        ownerManager.confirmTakeover();

        _requestTakeover();
        vm.warp(deplayTimeSecond - 10 minutes);
        vm.prank(address(backupOwnerAddress));
        vm.expectRevert(abi.encodeWithSelector(Errors.TakeoverIsNotReady.selector));
        ownerManager.confirmTakeover();
    }

    function test_instantTakeover() public {
        deplayTimeSecond = 0;
        _setBackupOwner();

        vm.prank(address(backupOwnerAddress));
        ownerManager.instantTakeover();
        assertEq(ownerManager.getOwner(), backupOwnerAddress);
        assertEq(ownerManager.getIsTakeoverInProgress(), false);
    }

    function testRrevert_instantTakeover() public {
        _setBackupOwner();
        vm.prank(address(backupOwnerAddress));
        vm.expectRevert(abi.encodeWithSelector(Errors.TakeoverIsNotReady.selector));
        ownerManager.instantTakeover();

        deplayTimeSecond = 0;
        _setBackupOwner();
        vm.prank(address(ownerAddress));
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, ownerAddress, "BACKUP"));
        ownerManager.instantTakeover();

        _requestTakeover();
        vm.prank(address(backupOwnerAddress));
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidTakeoverStatus.selector, true));
        ownerManager.instantTakeover();
    }

    function test_revokeTakeover() public {
        _requestTakeover();
        ownerManager.revokeTakeover();
        assertEq(ownerManager.getIsTakeoverInProgress(), false);

        _requestTakeover();
        vm.prank(backupOwnerAddress);
        ownerManager.revokeTakeover();
        assertEq(ownerManager.getIsTakeoverInProgress(), false);
    }

    function testRevert_revokeTakeover() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidTakeoverStatus.selector, false));
        ownerManager.revokeTakeover();

        _requestTakeover();
        vm.prank(unauthorizedOwnerAddress);
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, unauthorizedOwnerAddress, "BACKUP+"));
        ownerManager.revokeTakeover();
    }

    function test_getTakeoverStatus() public {
        (address owner, bool progress, uint256 time, uint256 canTakeover) = ownerManager.getTakeoverStatus();
        assertEq(owner, address(0));
        assertEq(progress, false);
        assertEq(time, 0);

        _requestTakeover();
        (owner, progress, time, canTakeover) = ownerManager.getTakeoverStatus();
        assertEq(owner, backupOwnerAddress);
        assertEq(progress, true);
        assertEq(time, deplayTimeSecond + block.timestamp);
    }
}
