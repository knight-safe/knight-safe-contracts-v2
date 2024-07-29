// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./OwnerManager.t.sol";
import "@/KnightSafe.sol";
import "@/base/PolicyManager.sol";
import "@/interfaces/IEventEmitter.sol";

abstract contract PolicyManagerTest is OwnerManagerTest {
    PolicyManager policyManager;
    uint256 defaultPolicyId = 0;
    address trader = vm.addr(40);

    address whiteListAddress0 = vm.addr(1001);
    address whiteListAddress1 = vm.addr(1002);
    address whiteListAddress2 = vm.addr(1003);

    function setUp() public override {
        super.setUp();
        policyManager = PolicyManager(address(ksProxy));
        policyManager.addTrader(defaultPolicyId, address(this));
    }

    function test_log() public view {
        console.log("Owner:", ownerAddress);
        console.log("Unauth Owner:", unauthorizedOwnerAddress);
        console.log("Admin:", adminAddress);
        console.log("backup Owner:", backupOwnerAddress);

        console.log("implementation", address(implementation));
        console.log("knightSafeProxyFactory", address(knightSafeProxyFactory));
        console.log("proxy", address(knightSafe));
        console.log("ksa", address(ksa));

        console.log("trader:", trader);
        console.log("whiteListAddress0:", whiteListAddress0);
        console.log("whiteListAddress1:", whiteListAddress1);
        console.log("whiteListAddress2:", whiteListAddress2);

        console.log("mockETH:", address(mockETH));
    }

    // Policy
    function test_getActivePolicyIds() public view {
        uint256[] memory policyIds = policyManager.getActivePolicyIds();
        assertGt(policyIds.length, 0);
    }

    function test_isActivePolicy() public view {
        assertTrue(policyManager.isActivePolicy(0));
    }

    function _createPolicy() internal {
        knightSafe.createPolicy();
    }

    function test_createPolicy() public {
        _createPolicy();
        assertEq(policyManager.getActivePolicyIds().length, 2);
    }

    function testRevert_createPolicy() public {
        uint256 maxPolicyCount = 3;

        assertEq(policyManager.getActivePolicyIds().length, 1);
        for (uint256 i = 0; i < maxPolicyCount + 1; i++) {
            if (i >= maxPolicyCount) {
                vm.expectRevert(abi.encodeWithSelector(Errors.MaxPolicyCountReached.selector, maxPolicyCount));
            }
            knightSafe.createPolicy();
        }
    }

    function test_removePolicy() public {
        _createPolicy();

        uint256 policyLength = policyManager.getActivePolicyIds().length;
        policyManager.removePolicy(policyLength - 1);

        assertEq(policyManager.getActivePolicyIds().length, 1);
    }

    function testRevert_removePolicy() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidOperation.selector));
        policyManager.removePolicy(0);

        vm.expectRevert(abi.encodeWithSelector(Errors.PolicyNotExist.selector, defaultPolicyId + 1));
        policyManager.removePolicy(defaultPolicyId + 1);
    }

    // Trader
    function _addTrader() internal {
        policyManager.addTrader(defaultPolicyId, trader);
    }

    function test_addTrader() public {
        _addTrader();
        assertEq(policyManager.getTraders(defaultPolicyId).length, 2);
        assertTrue(policyManager.isTrader(defaultPolicyId, trader));
        assertTrue(!policyManager.isTrader(defaultPolicyId + 1, trader));
    }

    function testRevert_addTrader() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.PolicyNotExist.selector, defaultPolicyId + 1));
        policyManager.addTrader(defaultPolicyId + 1, trader);

        _addTrader();
        assertTrue(policyManager.isTrader(defaultPolicyId, trader));
        vm.expectRevert(abi.encodeWithSelector(Errors.AddressAlreadyExist.selector, trader));
        _addTrader();
    }

    function test_removeTrader() public {
        _addTrader();
        assertTrue(policyManager.isTrader(defaultPolicyId, trader));
        assertFalse(policyManager.isTrader(defaultPolicyId + 1, trader));

        policyManager.removeTrader(defaultPolicyId, trader);
        assertFalse(policyManager.isTrader(defaultPolicyId, trader));
    }

    function testRevert_removeTrader() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.PolicyNotExist.selector, defaultPolicyId + 1));
        policyManager.removeTrader(defaultPolicyId + 1, trader);

        vm.expectRevert(abi.encodeWithSelector(Errors.AddressNotExist.selector, trader));
        policyManager.removeTrader(defaultPolicyId, trader);

        vm.prank(unauthorizedOwnerAddress);
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, unauthorizedOwnerAddress, "ADMIN+"));
        policyManager.removeTrader(defaultPolicyId, trader);
    }

    // Whitelist
    function _updateWhitelist() internal {
        knightSafe.updateWhitelist(defaultPolicyId, whiteListAddress0, address(ksa));
    }

    function test_updateWhitelist() public {
        _updateWhitelist();
        assertEq(policyManager.getWhitelistAddresses(defaultPolicyId).length, 3);
        assertTrue(policyManager.isPolicyWhitelistAddress(defaultPolicyId, whiteListAddress0));
        assertTrue(!policyManager.isPolicyWhitelistAddress(defaultPolicyId, whiteListAddress1));

        assertEq(policyManager.getKnightSafeAnalyserAddress(defaultPolicyId, whiteListAddress0), address(ksa));

        // SampleKnightSafeAnalyser ksa2 = new SampleKnightSafeAnalyser();
        // @TODO: fix this
        address ksa2 = address(1);
        // @TODO: Enable this line if KSA !== 0x1
        // eventEmitter.addOfficialAnalyser(address(ksa2), "SampleKnightSafeAnalyser2");

        knightSafe.updateWhitelist(defaultPolicyId, whiteListAddress0, address(ksa2));
        assertEq(policyManager.getKnightSafeAnalyserAddress(defaultPolicyId, whiteListAddress0), address(ksa2));

        knightSafe.updateWhitelist(defaultPolicyId, address(112211), address(1));
        assertEq(policyManager.getKnightSafeAnalyserAddress(defaultPolicyId, address(112211)), address(1));
    }

    function testRevert_updateWhitelist() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.PolicyNotExist.selector, defaultPolicyId + 1));
        knightSafe.updateWhitelist(defaultPolicyId + 1, whiteListAddress0, address(ksa));

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidAddress.selector, address(0)));
        knightSafe.updateWhitelist(defaultPolicyId, address(0), address(ksa));

        vm.prank(address(unauthorizedOwnerAddress));
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, unauthorizedOwnerAddress, "OWNER"));
        knightSafe.updateWhitelist(defaultPolicyId, whiteListAddress0, address(ksa));

        vm.expectRevert(abi.encodeWithSelector(Errors.AddressIsNotKnightSafeAnalyser.selector, address(1212)));
        knightSafe.updateWhitelist(defaultPolicyId, whiteListAddress0, address(1212));
    }

    function test_removeWhitelist() public {
        _updateWhitelist();
        policyManager.removeWhitelist(defaultPolicyId, whiteListAddress0);
    }

    function testRevert_removeWhitelist() public {
        _updateWhitelist();
        vm.expectRevert(abi.encodeWithSelector(Errors.PolicyNotExist.selector, defaultPolicyId + 1));
        policyManager.removeWhitelist(defaultPolicyId + 1, whiteListAddress0);

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidAddress.selector, address(0)));
        policyManager.removeWhitelist(defaultPolicyId, address(0));

        vm.expectRevert(abi.encodeWithSelector(Errors.AddressNotExist.selector, whiteListAddress1));
        policyManager.removeWhitelist(defaultPolicyId, whiteListAddress1);
        assertTrue(policyManager.isPolicyWhitelistAddress(defaultPolicyId, whiteListAddress0));
    }

    function test_setMaxSpendingLimit() public {
        controlCenter.setSpendingLimitEnabled(address(knightSafe), true);
        assertTrue(controlCenter.isSpendingLimitEnabled(address(knightSafe)));

        uint256 maxSpendingLimit = 1000;
        knightSafe.setMaxSpendingLimit(defaultPolicyId, maxSpendingLimit);
        assertEq(knightSafe.getMaxSpendingLimit(defaultPolicyId), maxSpendingLimit);
    }

    function testRevert_setMaxSpendingLimit() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.FeatureNotSupport.selector, "RETAIL"));
        knightSafe.setMaxSpendingLimit(defaultPolicyId, 1000);

        controlCenter.setSpendingLimitEnabled(address(knightSafe), true);
        assertTrue(controlCenter.isSpendingLimitEnabled(address(knightSafe)));

        vm.expectRevert(abi.encodeWithSelector(Errors.PolicyNotExist.selector, 2));
        knightSafe.setMaxSpendingLimit(2, 1000);

        vm.prank(adminAddress);
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, adminAddress, "OWNER"));
        knightSafe.setMaxSpendingLimit(defaultPolicyId, 1000);

        assertEq(knightSafe.getMaxSpendingLimit(defaultPolicyId), 0);
    }

    function test_reduceSpendingLimit() public {
        controlCenter.setSpendingLimitEnabled(address(knightSafe), true);
        assertTrue(controlCenter.isSpendingLimitEnabled(address(knightSafe)));

        uint256 maxSpendingLimit = 1000;
        knightSafe.setMaxSpendingLimit(defaultPolicyId, maxSpendingLimit);

        knightSafe.addAdmin(adminAddress);
        vm.prank(adminAddress);

        knightSafe.reduceSpendingLimit(defaultPolicyId, maxSpendingLimit - 500);
        assertEq(knightSafe.getMaxSpendingLimit(defaultPolicyId), maxSpendingLimit - 500);
    }

    function testRevert_reduceSpendingLimit() public {
        uint256 maxSpendingLimit = 1000;
        vm.expectRevert(abi.encodeWithSelector(Errors.FeatureNotSupport.selector, "RETAIL"));
        knightSafe.reduceSpendingLimit(defaultPolicyId, maxSpendingLimit);

        controlCenter.setSpendingLimitEnabled(address(knightSafe), true);
        assertTrue(controlCenter.isSpendingLimitEnabled(address(knightSafe)));
        knightSafe.setMaxSpendingLimit(defaultPolicyId, maxSpendingLimit);

        knightSafe.addAdmin(adminAddress);
        vm.prank(adminAddress);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidValue.selector));
        knightSafe.reduceSpendingLimit(defaultPolicyId, maxSpendingLimit + 10);
        assertEq(knightSafe.getMaxSpendingLimit(defaultPolicyId), maxSpendingLimit);
    }

    function test_resetDailySpent() public {
        vm.deal(address(knightSafe), 100_000_000_011 ether);

        controlCenter.setSpendingLimitEnabled(address(knightSafe), true);
        assertTrue(controlCenter.isSpendingLimitEnabled(address(knightSafe)));

        uint256 maxSpendingLimit = 1000;
        knightSafe.setMaxSpendingLimit(defaultPolicyId, _castToDefaultDecimal(20 * 1000));
        assertEq(knightSafe.getMaxSpendingLimit(defaultPolicyId), _castToDefaultDecimal(20 * 1000));

        _updateWhitelist();
        knightSafe.executeTransaction(defaultPolicyId, false, whiteListAddress0, _castToEthers(10), abi.encodePacked());
        assertEq(
            knightSafe.getDailyVolumeSpent(defaultPolicyId),
            _castToEthers(10) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE)
        );
        knightSafe.resetDailySpent(defaultPolicyId);
        assertEq(knightSafe.getDailyVolumeSpent(defaultPolicyId), 0);
        knightSafe.executeTransaction(defaultPolicyId, false, whiteListAddress0, _castToEthers(10), abi.encodePacked());
        assertEq(
            knightSafe.getDailyVolumeSpent(defaultPolicyId),
            _castToEthers(10) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE)
        );
    }
}
