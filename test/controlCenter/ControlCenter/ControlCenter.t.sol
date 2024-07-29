// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import "@/knightSafeAnalyser/ERC20Analyser.sol";
import "@/controlCenter/ControlCenter.sol";
import "@/priceFeed/ChainlinkPriceFeed.sol";
import "@/interfaces/IEventEmitter.sol";
import "@/KnightSafe.sol";

contract ControlCenterTest is Test {
    ControlCenter controlCenter;
    KnightSafe implementation;
    ChainlinkPriceFeed priceFeed;
    MockERC20 mockETH;
    MockV3Aggregator dataFeed;
    address mockToken = address(0x10001);

    address internal ownerAddress = address(this);
    address internal adminAddress = address(10);

    function setUp() public {
        controlCenter = new ControlCenter(ownerAddress);
    }

    function test_setAdmin() public {
        controlCenter.setAdmin(adminAddress, true);
    }

    function test_checkAdmin() public {
        controlCenter.setAdmin(adminAddress, true);

        ERC20Analyser newKSA = new ERC20Analyser();
        vm.prank(adminAddress);
        controlCenter.addOfficialAnalyser(address(newKSA), "cc_1.0");
        assertTrue(controlCenter.isOfficialAnalyser(address(newKSA)));

        ERC20Analyser newKsa2 = new ERC20Analyser();

        vm.prank(address(123123));
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, address(123123), "ADMIN"));
        controlCenter.addOfficialAnalyser(address(newKsa2), "cc_1.1");

        assertFalse(controlCenter.isOfficialAnalyser(address(newKsa2)));
    }

    function test_updateOfficialControlCenter() public {
        ControlCenter newControlCenter = new ControlCenter(ownerAddress);
        controlCenter.addOfficialControlCenter(address(newControlCenter), "cc_1.0");

        assertTrue(controlCenter.isOfficialControlCenter(address(newControlCenter)));

        controlCenter.removeOfficialControlCenter(address(newControlCenter));
        assertFalse(controlCenter.isOfficialControlCenter(address(newControlCenter)));
    }

    function testRevert_updateOfficialControlCenter() public {
        ControlCenter newControlCenter = new ControlCenter(ownerAddress);

        vm.expectRevert(abi.encodeWithSelector(Errors.IsNullValue.selector));
        controlCenter.addOfficialControlCenter(address(newControlCenter), 0);

        controlCenter.addOfficialControlCenter(address(newControlCenter), "cc_1.0");

        vm.expectRevert(abi.encodeWithSelector(Errors.AddressAlreadyExist.selector, address(newControlCenter)));
        controlCenter.addOfficialControlCenter(address(newControlCenter), "cc_1.0");

        assertTrue(controlCenter.isOfficialControlCenter(address(newControlCenter)));

        controlCenter.removeOfficialControlCenter(address(newControlCenter));
        assertFalse(controlCenter.isOfficialControlCenter(address(newControlCenter)));

        vm.expectRevert(abi.encodeWithSelector(Errors.AddressNotExist.selector, address(newControlCenter)));
        controlCenter.removeOfficialControlCenter(address(newControlCenter));
    }

    function test_updateOfficialImplementation() public {
        KnightSafe newImplementation = new KnightSafe();

        controlCenter.addOfficialImplementation(address(newImplementation), "cc_1.0");

        assertTrue(controlCenter.isOfficialImplementation(address(newImplementation)));

        controlCenter.removeOfficialImplementation(address(newImplementation));
        assertFalse(controlCenter.isOfficialImplementation(address(newImplementation)));
    }

    function testRevert_updateOfficialImplementation() public {
        KnightSafe newImplementation = new KnightSafe();

        vm.expectRevert(abi.encodeWithSelector(Errors.IsNullValue.selector));
        controlCenter.addOfficialImplementation(address(newImplementation), 0);

        controlCenter.addOfficialImplementation(address(newImplementation), "cc_1.0");

        vm.expectRevert(abi.encodeWithSelector(Errors.AddressAlreadyExist.selector, address(newImplementation)));
        controlCenter.addOfficialImplementation(address(newImplementation), "cc_1.0");

        assertTrue(controlCenter.isOfficialImplementation(address(newImplementation)));

        controlCenter.removeOfficialImplementation(address(newImplementation));
        assertFalse(controlCenter.isOfficialImplementation(address(newImplementation)));

        vm.expectRevert(abi.encodeWithSelector(Errors.AddressNotExist.selector, address(newImplementation)));
        controlCenter.removeOfficialImplementation(address(newImplementation));
    }

    function test_updateOfficialAnalyser() public {
        ERC20Analyser newKSA = new ERC20Analyser();

        controlCenter.addOfficialAnalyser(address(newKSA), "cc_1.0");

        assertTrue(controlCenter.isOfficialAnalyser(address(newKSA)));

        controlCenter.removeOfficialAnalyser(address(newKSA));
        assertFalse(controlCenter.isOfficialAnalyser(address(newKSA)));
    }

    function testRevert_updateOfficialAnalyser() public {
        ERC20Analyser newKSA = new ERC20Analyser();

        vm.expectRevert(abi.encodeWithSelector(Errors.IsNullValue.selector));
        controlCenter.addOfficialAnalyser(address(newKSA), 0);

        controlCenter.addOfficialAnalyser(address(newKSA), "cc_1.0");

        vm.expectRevert(abi.encodeWithSelector(Errors.AddressAlreadyExist.selector, address(newKSA)));
        controlCenter.addOfficialAnalyser(address(newKSA), "cc_1.0");

        vm.expectRevert(abi.encodeWithSelector(Errors.InterfaceNotSupport.selector, address(101)));
        controlCenter.addOfficialAnalyser(address(101), "cc_1.0");

        assertTrue(controlCenter.isOfficialAnalyser(address(newKSA)));

        controlCenter.removeOfficialAnalyser(address(newKSA));
        assertFalse(controlCenter.isOfficialAnalyser(address(newKSA)));

        vm.expectRevert(abi.encodeWithSelector(Errors.AddressNotExist.selector, address(newKSA)));
        controlCenter.removeOfficialAnalyser(address(newKSA));
    }

    function test_policyAllowed() public {
        controlCenter.setMaxPolicyAllowed(address(101), 10);
        assertEq(controlCenter.getMaxPolicyAllowed(address(101)), 10);

        controlCenter.setGlobalMinPolicyAllowed(20);
        assertEq(controlCenter.getMaxPolicyAllowed(address(101)), 20);
    }

    bytes4 internal constant CREATE_POLICY = 0xa91a0ca3;
    bytes4 internal constant UPDATE_WHITELIST = 0x725d42f5;
    bytes4 internal constant ADD_TRADER = 0xedbdf62b;
    bytes4 internal constant REMOVE_POLICY = 0x6caddcdc;
    bytes4 internal constant REMOVE_TRADER = 0x29953ff5;
    bytes4 internal constant REMOVE_WHITELIST = 0x94008a6e;
    bytes4 internal constant INCREASE_SPENDING_LIMIT = 0xcc19223b;
    bytes4 internal constant RESET_SPENDING_LIMIT = 0x86e43e16;

    function test_getAdminEventAccess() public view {
        bytes4[] memory access = controlCenter.getAdminEventAccess();
        assertEq(access.length, 8);
        assertEq(access[0], CREATE_POLICY);
        assertEq(access[3], REMOVE_POLICY);
        assertEq(access[7], RESET_SPENDING_LIMIT);
    }

    function test_updateMaxVolumeExpiryDate() public {
        controlCenter.setMaxTradingVolumeExpiryDate(address(101), block.timestamp + 100);
        assertEq(controlCenter.getMaxVolumeExpiryDate(address(101)), block.timestamp + 100);
    }
}

// $ yarn test --match-contract ControlCenterTest
