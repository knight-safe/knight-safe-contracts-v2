// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import "./base/PolicyManager.t.sol";
import "./PausableUtils.t.sol";
import {UniswapAnalyser, Commands} from "@/knightSafeAnalyser/UniswapAnalyser.sol";

contract UseCase is PolicyManagerTest, PausableUtilsTest {
    /**
     * @dev Create a policy group usage
     */
    function test_case1() public {
        _createPolicy();
        _createPolicy();
        _createPolicy();

        uint256[] memory policyIds = policyManager.getActivePolicyIds();
        assertTrue(policyIds.length == 4);

        address pplA = vm.addr(5001);
        address pplB = vm.addr(5002);
        address pplC = vm.addr(5003);

        address peter = vm.addr(9091);
        address mary = vm.addr(9092);
        address john = vm.addr(9093);
        // global = 0
        // policy , 1-2

        knightSafe.updateWhitelist(0, pplA, address(ksa));
        knightSafe.updateWhitelist(1, pplB, address(ksa));
        knightSafe.updateWhitelist(2, pplC, address(ksa));

        policyManager.addTrader(0, peter);
        policyManager.addTrader(1, mary);
        policyManager.addTrader(2, john);

        vm.prank(peter);
        policyManager.executeTransaction(0, false, pplA, 0, "0x99999");

        vm.prank(peter);
        policyManager.executeTransaction(0, true, pplA, 0, "0x99999");
        vm.prank(mary);
        policyManager.executeTransaction(1, true, pplA, 0, "0x99999");
        vm.prank(john);
        policyManager.executeTransaction(2, true, pplA, 0, "0x99999");

        vm.prank(peter);
        policyManager.executeTransaction(1, false, pplB, 0, "0x99999");
        vm.prank(mary);
        policyManager.executeTransaction(1, false, pplB, 0, "0x99999");
        vm.prank(john);
        vm.expectRevert();
        policyManager.executeTransaction(2, false, pplB, 0, "0x99999");

        vm.prank(peter);
        policyManager.executeTransaction(2, false, pplC, 0, "0x99999");
        vm.prank(mary);
        vm.expectRevert();
        policyManager.executeTransaction(1, false, pplC, 0, "0x99999");
        vm.prank(john);
        policyManager.executeTransaction(2, false, pplC, 0, "0x99999");

        vm.prank(peter);
        vm.expectRevert();
        policyManager.executeTransaction(0, false, pplB, 0, "0x99999");
        vm.prank(peter);
        vm.expectRevert();
        policyManager.executeTransaction(0, false, pplC, 0, "0x99999");

        vm.prank(mary);
        vm.expectRevert();
        policyManager.executeTransaction(1, false, pplA, 0, "0x99999");
        vm.prank(john);
        vm.expectRevert();
        policyManager.executeTransaction(2, false, pplA, 0, "0x99999");
    }

    /**
     * @dev Create a user create group by multi call
     */
    function test_case2() public {
        address trader = vm.addr(9091);
        address whiteListAddress = vm.addr(5001);

        knightSafe.createPolicy();
        knightSafe.createPolicy();
        knightSafe.removePolicy(2);
        // policies: [0,1]
        uint256 policyLength = knightSafe.nextPolicyId();

        bytes memory mutil_createPolicy = abi.encodePacked(PolicyManager.createPolicy.selector);
        bytes memory multi_addWhitelist = abi.encodePacked(
            PolicyManager.updateWhitelist.selector, abi.encode(policyLength, whiteListAddress, address(ksa))
        );
        bytes memory multi_addTrader =
            abi.encodePacked(PolicyManager.addTrader.selector, abi.encode(policyLength, trader));

        bytes[] memory data = new bytes[](3);
        data[0] = mutil_createPolicy;
        data[1] = multi_addWhitelist;
        data[2] = multi_addTrader;

        assertEq(knightSafe.getActivePolicyIds().length, 2);
        knightSafe.multicall(data);
        // policies: [0,1,3]
        assertEq(knightSafe.getActivePolicyIds().length, 3);

        assertTrue(knightSafe.isPolicyWhitelistAddress(3, whiteListAddress));
        assertTrue(knightSafe.isTrader(3, trader));
    }

    function test_uniswap() public {
        address mockNative = address(0x1111111111111); // any address
        UniswapAnalyser ksa = new UniswapAnalyser(mockNative, msg.sender);
        MockERC20 mockTOKEN = new MockERC20();
        address mockUni = address(1234321);

        controlCenter.addOfficialAnalyser(address(ksa), "uni_0.01");

        knightSafe.updateWhitelist(0, mockUni, address(ksa));
        knightSafe.updateWhitelist(0, 0xeC8B0F7Ffe3ae75d7FfAb09429e3675bb63503e4, address(ksa)); //<< UniversalRouter
        knightSafe.updateWhitelist(0, 0xaf88d065e77c8cC2239327C5EDb3A432268e5831, address(ksa)); // usdc
        knightSafe.updateWhitelist(0, 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9, address(ksa)); // usdt
        // 2.0
        knightSafe.updateWhitelist(0, address(0x1C986661170c1834db49C3830130D4038eEeb866), address(ksa));
        knightSafe.updateWhitelist(0, address(mockTOKEN), address(ksa));
        knightSafe.updateWhitelist(0, 0x9A608d9F416518b5F11acf3dC5594C90D6998e2c, address(ksa));
        knightSafe.updateWhitelist(0, mockNative, address(ksa));

        // solhint-disable-next-line
        // bytes memory data =
        //     hex"3593564c000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000006669deb300000000000000000000000000000000000000000000000000000000000000030a000c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000001e000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000160000000000000000000000000dF82aA9B82f68F8227be34DB26150809F1F6560f000000000000000000000000ffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000667319330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ec8b0f7ffe3ae75d7ffab09429e3675bb63503e4000000000000000000000000000000000000000000000000000000006669deb300000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000004108db68e89b06fbb06c9fee5e69e8ef16db91ff1268b24c90766cec4d0ae56464050965d14c336bc5fe7bd82d044f4a91f251e21cf4b4e978655992b9b56fa7541b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000bf182b30000000000000000000000000000000000000000000000000015addf06304e7500000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002bdF82aA9B82f68F8227be34DB26150809F1F6560f00271082af49447d8a07e3bd95bd0d56f35241523fbab100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000009a608d9f416518b5f11acf3dc5594c90d6998e2c0000000000000000000000000000000000000000000000000015addf06304e75";
        bytes memory data =
            hex"3593564c000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000006669deb300000000000000000000000000000000000000000000000000000000000000030a000c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000001600000000000000000000000001c986661170c1834db49c3830130d4038eeeb866000000000000000000000000ffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000667319330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ec8b0f7ffe3ae75d7ffab09429e3675bb63503e4000000000000000000000000000000000000000000000000000000006669deb300000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000004108db68e89b06fbb06c9fee5e69e8ef16db91ff1268b24c90766cec4d0ae56464050965d14c336bc5fe7bd82d044f4a91f251e21cf4b4e978655992b9b56fa7541b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000bf182b30000000000000000000000000000000000000000000000000015addf06304e7500000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002b1c986661170c1834db49c3830130d4038eeeb86600271082af49447d8a07e3bd95bd0d56f35241523fbab100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000009a608d9f416518b5f11acf3dc5594c90d6998e2c0000000000000000000000000000000000000000000000000015addf06304e75";

        knightSafe.executeTransaction(0, false, mockUni, 0, data);
    }
}

// $ yarn test --match-contract UseCase
