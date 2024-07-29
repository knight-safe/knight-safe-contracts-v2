// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import "../base/OwnerManager.t.sol";
import "../base/PolicyManager.t.sol";
import "@/KnightSafe.sol";
import "@/knightSafeAnalyser/SampleKnightSafeAnalyser.sol";
import {ERC20Analyser} from "@/knightSafeAnalyser/ERC20Analyser.sol";
import "@/interfaces/IEventEmitter.sol";
import {MockERC20Analyser} from "../mocks/MockERC20Analyser.sol";

contract TransactionRequestTest is PolicyManagerTest {
    bytes data = abi.encodePacked("Some test function");

    function _requestTransaction() internal {
        knightSafe.requestTransaction(defaultPolicyId, whiteListAddress0, 0, data);
    }

    function test_requestTransaction() public {
        assertEq(knightSafe.getNextTransactionRequestId(), 0);
        _requestTransaction();
        assertEq(knightSafe.getNextTransactionRequestId(), 1);

        _createPolicy();

        Transaction.Request memory request;
        request.requester = address(ownerAddress);
        request.policyId = defaultPolicyId + 1;
        request.params = Transaction.Params(whiteListAddress1, 0, data);
        request.status = Transaction.Status.Pending;
        vm.expectEmit(true, true, false, true);
        emit TransactionEventLog(
            address(knightSafe),
            "CreatedTransactionRequest",
            "CreatedTransactionRequest",
            bytes32(uint256(uint160(address(knightSafe)))),
            1
        );

        knightSafe.requestTransaction(defaultPolicyId + 1, whiteListAddress1, 0, data);
        assertEq(knightSafe.getNextTransactionRequestId(), 2);
    }

    function testRevert_requestTransaction() public {
        vm.prank(address(unauthorizedOwnerAddress));
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, unauthorizedOwnerAddress, "TRADER"));
        _requestTransaction();
        assertEq(knightSafe.getNextTransactionRequestId(), 0);

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidReqId.selector, 1));
        knightSafe.getTransactionRequest(1);
    }

    function _cancelTransaction() internal {
        knightSafe.cancelTransactionByReqId(defaultPolicyId, 0);
    }

    function test_cancelTransactionByReqId() public {
        _requestTransaction();
        assertEq(knightSafe.getNextTransactionRequestId(), 1);
        _cancelTransaction();
        Transaction.Request memory txnRequest = knightSafe.getTransactionRequest(0);

        assertTrue(txnRequest.status == Transaction.Status.Cancelled);
    }

    function testRevert_cancelTransactionByReqId() public {
        _requestTransaction();
        assertEq(knightSafe.getNextTransactionRequestId(), 1);
        Transaction.Request memory txnRequest = knightSafe.getTransactionRequest(0);
        assertTrue(txnRequest.status == Transaction.Status.Pending);

        vm.prank(address(unauthorizedOwnerAddress));
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, unauthorizedOwnerAddress, "TRADER"));
        _cancelTransaction();
        assertTrue(txnRequest.status == Transaction.Status.Pending);

        // error when sender is not trader
        knightSafe.addTrader(defaultPolicyId, trader);
        vm.prank(trader);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidOperation.selector));
        _cancelTransaction();
        assertTrue(txnRequest.status == Transaction.Status.Pending);

        // error on txn !pending
        _cancelTransaction();
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidTransactionStatus.selector));
        _cancelTransaction();
    }

    function test_executeTransaction() public {
        _updateWhitelist();
        vm.deal(address(knightSafe), 100_000_000_011 ether);

        assertEq(knightSafe.getNextTransactionRequestId(), 0);
        knightSafe.executeTransaction(defaultPolicyId, false, whiteListAddress0, _castToEthers(10), abi.encodePacked());
        assertEq(knightSafe.getTotalVolumeSpent(), _castToEthers(10) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE));

        assertEq(knightSafe.getNextTransactionRequestId(), 0);
        knightSafe.executeTransaction(defaultPolicyId, false, whiteListAddress0, _castToEthers(5), abi.encodePacked());

        assertEq(
            knightSafe.getTotalVolumeSpent(),
            _castToEthers(10) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE)
                + _castToEthers(5) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE)
        );

        // test reset counter on new day
        vm.warp(block.timestamp + 1.5 days);
        timestamp = block.timestamp;
        dataFeed.updateRoundData(LATEST_ROUND, LATEST_ANSWER, timestamp, timestamp);

        knightSafe.executeTransaction(defaultPolicyId, false, whiteListAddress0, _castToEthers(40), abi.encodePacked());
        assertEq(knightSafe.dailyVolumeSpent(), _castToEthers(40) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE));

        //test account limit , expire check expirationDate
        controlCenter.setMaxTradingVolume(address(knightSafe), _castToDefaultDecimal(100_000_00));
        controlCenter.setMaxTradingVolumeExpiryDate(address(knightSafe), block.timestamp + 1 days);
        assertEq(controlCenter.getMaxTradingVolume(address(knightSafe)), _castToDefaultDecimal(100_000_00));

        knightSafe.executeTransaction(
            defaultPolicyId, false, whiteListAddress0, _castToEthers(1_000), abi.encodePacked()
        );
        assertEq(
            knightSafe.getTotalVolumeSpent(),
            _castToEthers(1_000) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE)
                + _castToEthers(40) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE)
        );
    }

    function test_executeTransaction_withDailyLimit() public {
        _updateWhitelist();
        vm.deal(address(knightSafe), 100_000_000_011 ether);

        assertEq(knightSafe.getNextTransactionRequestId(), 0);
        knightSafe.executeTransaction(defaultPolicyId, false, whiteListAddress0, _castToEthers(10), abi.encodePacked());
        assertEq(knightSafe.getTotalVolumeSpent(), _castToEthers(10) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE));

        assertEq(knightSafe.getNextTransactionRequestId(), 0);
        knightSafe.executeTransaction(defaultPolicyId, false, whiteListAddress0, _castToEthers(5), abi.encodePacked());

        assertEq(
            knightSafe.getTotalVolumeSpent(),
            _castToEthers(10) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE)
                + _castToEthers(5) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE)
        );

        // test reset counter on new day
        vm.warp(block.timestamp + 1.5 days);
        timestamp = block.timestamp;
        dataFeed.updateRoundData(LATEST_ROUND, LATEST_ANSWER, timestamp, timestamp);

        knightSafe.executeTransaction(defaultPolicyId, false, whiteListAddress0, _castToEthers(40), abi.encodePacked());
        assertEq(knightSafe.dailyVolumeSpent(), _castToEthers(40) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE));

        //test account limit , expire check expirationDate
        controlCenter.setDailyVolume(address(knightSafe), _castToDefaultDecimal(100_000_00));
        controlCenter.setDailyVolumeExpiryDate(address(knightSafe), block.timestamp + 1 days);
        assertEq(controlCenter.getDailyVolume(address(knightSafe)), _castToDefaultDecimal(100_000_00));

        knightSafe.executeTransaction(
            defaultPolicyId, false, whiteListAddress0, _castToEthers(1_000), abi.encodePacked()
        );
        assertEq(
            knightSafe.getTotalVolumeSpent(),
            _castToEthers(1_000) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE)
                + _castToEthers(40) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE)
        );
    }

    function test_executeTransaction_withExistDailyLimit() public {
        _updateWhitelist();
        vm.deal(address(knightSafe), 100_000_000_011 ether);

        assertEq(knightSafe.getNextTransactionRequestId(), 0);
        knightSafe.executeTransaction(defaultPolicyId, false, whiteListAddress0, _castToEthers(100), abi.encodePacked());
        assertEq(knightSafe.getTotalVolumeSpent(), _castToEthers(100) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE));
        assertEq(knightSafe.dailyVolumeSpent(), controlCenter.getDailyVolume(address(knightSafe)));

        controlCenter.setMaxTradingVolume(address(knightSafe), _castToDefaultDecimal(100_000_00));
        controlCenter.setMaxTradingVolumeExpiryDate(address(knightSafe), block.timestamp + 1 days);
        knightSafe.executeTransaction(defaultPolicyId, false, whiteListAddress0, _castToEthers(5), abi.encodePacked());
        assertEq(knightSafe.accountVolumeSpent(), _castToEthers(5) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE));
    }

    function test_executeTransaction_withPolicyLimit() public {
        _updateWhitelist();
        knightSafe.createPolicy();
        vm.deal(address(knightSafe), 100_000_000_011 ether);

        controlCenter.setSpendingLimitEnabled(address(knightSafe), true);
        assertTrue(controlCenter.isSpendingLimitEnabled(address(knightSafe)));

        knightSafe.setMaxSpendingLimit(defaultPolicyId, _castToDefaultDecimal(20 * 1000)); // value * last price feeds answer
        knightSafe.setMaxSpendingLimit(1, _castToDefaultDecimal(10 * 1000)); // value * last price feeds answer
        assertEq(knightSafe.getMaxSpendingLimit(defaultPolicyId), _castToDefaultDecimal(20 * 1000));

        // policy 0 used 10$ && policy 1 used 5$
        knightSafe.executeTransaction(defaultPolicyId, false, whiteListAddress0, _castToEthers(10), abi.encodePacked());
        assertEq(_castToValue(knightSafe.getTotalVolumeSpent()), 10 * uint256(LATEST_ANSWER_VALUE));
        knightSafe.executeTransaction(1, true, whiteListAddress0, _castToEthers(5), abi.encodePacked());

        assertEq(
            knightSafe.getTotalVolumeSpent(),
            _castToEthers(10) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE)
                + _castToEthers(5) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE)
        );
        assertEq(
            knightSafe.getDailyVolumeSpent(defaultPolicyId),
            _castToEthers(10) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE)
        );
        assertEq(knightSafe.getDailyVolumeSpent(1), _castToEthers(5) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE));

        // test reset counter on new day
        vm.warp(block.timestamp + 1.5 days);
        timestamp = block.timestamp;
        dataFeed.updateRoundData(LATEST_ROUND, LATEST_ANSWER, timestamp, timestamp);

        knightSafe.executeTransaction(defaultPolicyId, false, whiteListAddress0, _castToEthers(10), abi.encodePacked());
        assertEq(knightSafe.dailyVolumeSpent(), _castToEthers(10) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE));
        assertEq(
            knightSafe.getDailyVolumeSpent(defaultPolicyId),
            _castToEthers(10) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE)
        );
    }

    function test_executeTransaction_revert() public {
        _updateWhitelist();
        vm.expectRevert();
        knightSafe.executeTransaction(defaultPolicyId, false, whiteListAddress0, 10 * (10 ** DECIMALS), data);

        vm.deal(address(knightSafe), 100_000_000_011 ether);

        uint256 value = 100_000_000_010 * (10 ** DECIMALS);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.ExceedMaxTradingVolume.selector,
                (value * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE)),
                controlCenter.getDailyVolume(address(this))
            )
        );
        knightSafe.executeTransaction(defaultPolicyId, false, whiteListAddress0, value, data);
        assertEq(knightSafe.getNextTransactionRequestId(), 0);

        ERC20Analyser erc20Ksa = new ERC20Analyser();
        IControlCenter(controlCenter).addOfficialAnalyser(address(erc20Ksa), "ksa_0.01");
        knightSafe.updateWhitelist(defaultPolicyId, whiteListAddress0, address(erc20Ksa));
        knightSafe.updateWhitelist(defaultPolicyId, address(mockETH), address(erc20Ksa));

        mockETH.mint(address(knightSafe), value);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.ExceedMaxTradingVolume.selector,
                (value * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE)),
                controlCenter.getDailyVolume(address(this))
            )
        );
        bytes memory transferData = abi.encodeWithSelector(MockERC20.transfer.selector, whiteListAddress0, value);
        knightSafe.executeTransaction(defaultPolicyId, false, address(mockETH), 0, transferData);

        IControlCenter(controlCenter).setSpendingLimitEnabled(address(knightSafe), true);
        knightSafe.setMaxSpendingLimit(defaultPolicyId, (20) * 10 ** 18); // value * last price feeds answer

        transferData = abi.encodeWithSelector(MockERC20.transfer.selector, whiteListAddress0, 30 * 10 ** 18);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.ExceedPolicyVolume.selector,
                defaultPolicyId,
                (30 * 10 ** 18) * uint256(LATEST_ANSWER) * (MAGIC_DECIMAL_VALUE)
            )
        );
        knightSafe.executeTransaction(defaultPolicyId, false, address(mockETH), 0, transferData);
    }

    function test_executeTransactionByReqId() public {
        _updateWhitelist();
        _requestTransaction();
        assertEq(knightSafe.getNextTransactionRequestId(), 1);
        knightSafe.executeTransactionByReqId(defaultPolicyId, false, 0);
        Transaction.Request memory txnRequest = knightSafe.getTransactionRequest(0);
        assertTrue(txnRequest.status == Transaction.Status.Completed);
    }

    function testRevert_executeTransactionByReqId() public {
        _updateWhitelist();
        _requestTransaction();
        Transaction.Request memory txnRequest = knightSafe.getTransactionRequest(0);
        assertTrue(txnRequest.status == Transaction.Status.Pending);
        vm.prank(address(unauthorizedOwnerAddress));
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, unauthorizedOwnerAddress, "TRADER"));
        knightSafe.executeTransactionByReqId(defaultPolicyId, false, 0);
        Transaction.Request memory txnRequestAsExpected = knightSafe.getTransactionRequest(0);
        assertTrue(txnRequestAsExpected.status == Transaction.Status.Pending);

        vm.expectRevert(abi.encodeWithSelector(Errors.PolicyNotExist.selector, 1));
        knightSafe.executeTransactionByReqId(1, false, 0);

        _createPolicy();
        vm.expectRevert(abi.encodeWithSelector(Errors.AddressNotInWhitelist.selector, 1, whiteListAddress0));
        knightSafe.executeTransactionByReqId(1, false, 0);

        vm.expectRevert(abi.encodeWithSelector(Errors.AddressIsNotKnightSafeAnalyser.selector, address(1212)));
        knightSafe.updateWhitelist(defaultPolicyId, whiteListAddress0, address(1212));

        _cancelTransaction();
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidTransactionStatus.selector));
        knightSafe.executeTransactionByReqId(defaultPolicyId, false, 0);
    }

    function test_rejectTransactionByReqId() public {
        _updateWhitelist();
        _requestTransaction();
        Transaction.Request memory txnRequest = knightSafe.getTransactionRequest(0);
        assertTrue(txnRequest.status == Transaction.Status.Pending);

        knightSafe.rejectTransactionByReqId(defaultPolicyId, false, 0);
        Transaction.Request memory txnRequestAsExpected = knightSafe.getTransactionRequest(0);
        assertTrue(txnRequestAsExpected.status == Transaction.Status.Rejected);
    }

    function testRevert_rejectTransactionByReqId() public {
        _updateWhitelist();
        _requestTransaction();

        _cancelTransaction();

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidTransactionStatus.selector));
        knightSafe.rejectTransactionByReqId(defaultPolicyId, false, 0);
        Transaction.Request memory txnRequestAsExpected = knightSafe.getTransactionRequest(0);
        assertTrue(txnRequestAsExpected.status == Transaction.Status.Cancelled);
    }

    function test_validateTradingAccess() public {
        data = abi.encodeWithSelector(MockERC20.approve.selector, whiteListAddress0, 100);
        ERC20Analyser erc20Ksa = new ERC20Analyser();
        IControlCenter(controlCenter).addOfficialAnalyser(address(erc20Ksa), "ksa_0.01");

        knightSafe.updateWhitelist(defaultPolicyId, whiteListAddress0, address(erc20Ksa));
        (address[] memory addresses, uint256[] memory amounts) =
            (knightSafe.validateTradingAccess(defaultPolicyId, false, whiteListAddress0, data));
        assertEq(addresses.length, 2);
        bytes memory emptyData;
        (addresses, amounts) = (knightSafe.validateTradingAccess(defaultPolicyId, false, whiteListAddress0, emptyData));
        assertEq(addresses.length, 0);
    }

    function testRevert_validateTradingAccess() public {
        _updateWhitelist();
        _createPolicy();

        vm.expectRevert(abi.encodeWithSelector(Errors.PolicyNotExist.selector, 3));
        knightSafe.validateTradingAccess(3, false, whiteListAddress0, data);

        vm.expectRevert(abi.encodeWithSelector(Errors.AddressNotInWhitelist.selector, 1, whiteListAddress0));
        knightSafe.validateTradingAccess(1, false, whiteListAddress0, data);

        knightSafe.updateWhitelist(1, address(0x1001), address(0));
        vm.expectRevert(abi.encodeWithSelector(Errors.AddressIsReadOnlyWhitelist.selector, 1, address(0)));
        knightSafe.validateTradingAccess(1, false, address(0x1001), data);

        ERC20Analyser erc20Ksa = new ERC20Analyser();
        IControlCenter(controlCenter).addOfficialAnalyser(address(erc20Ksa), "ksa_0.01");
        knightSafe.updateWhitelist(1, whiteListAddress0, address(erc20Ksa));
        data = abi.encodeWithSelector(MockERC20.approve.selector, whiteListAddress1, 100);
        vm.expectRevert(abi.encodeWithSelector(Errors.AddressNotInWhitelist.selector, 1, whiteListAddress1));
        knightSafe.validateTradingAccess(1, false, address(whiteListAddress0), data);

        MockERC20Analyser mockKsa = new MockERC20Analyser();
        IControlCenter(controlCenter).addOfficialAnalyser(address(mockKsa), "fake_ksa_0.01");
        knightSafe.updateWhitelist(1, address(0x1002), address(mockKsa));

        data = abi.encodeWithSelector(MockERC20.approve.selector, whiteListAddress0, 100);
        vm.expectRevert(abi.encodeWithSelector(Errors.SelectorNotSupport.selector));
        knightSafe.validateTradingAccess(1, false, address(0x1002), data);
    }

    event TransactionEventLog(
        address msgSender, string eventName, string indexed eventNameHash, bytes32 indexed profile, uint256 reqId
    );
}

// yarn test --match-contract TransactionRequestTest
