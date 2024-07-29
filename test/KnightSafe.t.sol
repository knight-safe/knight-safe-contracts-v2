// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import "../contracts/interfaces/IKnightSafe.sol";
import "../contracts/interfaces/IOwnerManager.sol";
import "../contracts/interfaces/IPolicyManager.sol";
import "../contracts/controlCenter/ControlCenter.sol";
import "../contracts/KnightSafe.sol";
import "../contracts/base/OwnerManager.sol";
import "../contracts/common/TokenCallbackHandler.sol";
import "../contracts/proxies/KnightSafeProxy.sol";
import "../contracts/proxies/KnightSafeProxyFactory.sol";
import "../contracts/error/Errors.sol";
import "../contracts/knightSafeAnalyser/SampleKnightSafeAnalyser.sol";
import "../contracts/priceFeed/ChainlinkPriceFeed.sol";
import {MockERC20Token} from "../contracts/mocks/MockERC20.sol";

// This test file is used to test the OwnerManager contract
contract KnightSafeProxyTest is Test {
    KnightSafe implementation;
    KnightSafe knightSafe;
    KnightSafeProxy ksProxy;
    KnightSafeProxyFactory knightSafeProxyFactory;
    ControlCenter eventEmitter;
    ControlCenter controlCenter;
    TokenCallbackHandler tokenCallbackHandler;

    MockERC20Token mockETH;
    MockV3Aggregator dataFeed;
    ChainlinkPriceFeed priceFeed;

    address ksa;

    address internal ownerAddress = address(this);
    address internal unauthorizedOwnerAddress = vm.addr(10);
    address internal adminAddress = vm.addr(20);
    address internal backupOwnerAddress = vm.addr(30);

    uint8 constant DECIMALS = 18;
    uint8 constant PRICE_FEED_DECIMALS = 8;
    uint8 constant PRICE_DECIMALS = 30;

    uint256 constant DECIMALS18 = 10 ** DECIMALS;
    uint256 constant PRICE_DECIMALS18 = 10 ** PRICE_FEED_DECIMALS;

    int256 INITIAL_ANSWER = 10;
    int256 LATEST_ANSWER_VALUE = 1000;
    int256 LATEST_ANSWER = LATEST_ANSWER_VALUE * int256(PRICE_DECIMALS18);
    uint80 LATEST_ROUND = 1;

    uint256 timestamp = block.timestamp;

    uint256 internal MAGIC_DECIMAL_VALUE = 10 ** 4; //  10 ** 4 : 30 - 18 - 8 decimal

    function setUp() public virtual {
        _deployKnightSafe();
        _deployProxy();
        _deployPriceFeed();
    }

    // function test_deploy() public {
    //     _deployKnightSafe();
    //     _deployProxy();
    //     _deployPriceFeed();
    // }

    function _deployKnightSafe() private {
        implementation = new KnightSafe();
        assertEq(implementation.getOwner(), address(1));

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidOperation.selector));
        implementation.initialize(ownerAddress, address(0), address(0));

        eventEmitter = new ControlCenter(ownerAddress);
        controlCenter = ControlCenter(eventEmitter);
        tokenCallbackHandler = new TokenCallbackHandler();

        knightSafeProxyFactory = new KnightSafeProxyFactory(address(eventEmitter));
        assertTrue(address(knightSafeProxyFactory) != address(0));
        assertEq(address(knightSafeProxyFactory.CONTROL_CENTER()), address(eventEmitter));

        controlCenter.setFactory(address(knightSafeProxyFactory));
        assertTrue(controlCenter.isFactory(address(knightSafeProxyFactory)));

        // ksa = new SampleKnightSafeAnalyser();
        // @TODO: Fix this
        ksa = address(1);
        // @TODO: Enable this line if KSA !== 0x1
        // eventEmitter.addOfficialAnalyser(address(ksa), "SampleKnightSafeAnalyser");

        controlCenter.addOfficialImplementation(address(implementation), "master_1.0");
    }

    function _deployProxy() public {
        bytes memory data = abi.encodePacked(
            KnightSafe.initialize.selector,
            abi.encode(ownerAddress, address(eventEmitter), address(tokenCallbackHandler))
        );

        uint256 salt = 1234;

        ksProxy = knightSafeProxyFactory.createProxy(address(implementation), data, salt);

        knightSafe = KnightSafe(payable(address(ksProxy)));

        address ownerAsExpected = knightSafe.getOwner();
        assertEq(ownerAsExpected, ownerAddress);

        address[] memory adminsAsExpected = knightSafe.getAdmins();
        assertEq(adminsAsExpected.length, 0);

        assertTrue(knightSafe.isActivePolicy(0));
    }

    function _deployPriceFeed() public {
        // Mock ERC20 price
        mockETH = new MockERC20Token();
        mockETH.initialize("ETH", "meth", 18);
        // mockETH.mint(address(knightSafe), 100_000_000_011 * (10 ** 18));

        // Mock chainlink price feed
        dataFeed = new MockV3Aggregator(PRICE_FEED_DECIMALS, INITIAL_ANSWER);
        dataFeed.updateRoundData(LATEST_ROUND, LATEST_ANSWER, timestamp, timestamp);
        (uint80 roundId, int256 answer,,,) = dataFeed.latestRoundData();
        assertEq(roundId, LATEST_ROUND);
        assertEq(answer, LATEST_ANSWER);

        priceFeed =
            new ChainlinkPriceFeed(ownerAddress, address(eventEmitter), address(mockETH), address(dataFeed), 86400);
        assertEq(priceFeed.getPriceFeed(address(mockETH)), address(dataFeed));

        (eventEmitter).setPriceFeed(address(priceFeed));
        assertTrue(eventEmitter.isActiveAccount(address(priceFeed)));
        assertEq(eventEmitter.getPriceFeed(), address(priceFeed));
    }

    function testRevert_deployProxy() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidOperation.selector));
        implementation.initialize(ownerAddress, address(controlCenter), address(tokenCallbackHandler));

        bytes memory revertData = abi.encodePacked(
            KnightSafe.initialize.selector, abi.encode(0, address(eventEmitter), address(tokenCallbackHandler))
        );
        uint256 salt = 2468;
        // vm.expectRevert(abi.encodeWithSelector(Errors.InvalidAddress.selector, address(0)));
        vm.expectRevert();
        knightSafeProxyFactory.createProxy(address(implementation), revertData, salt);

        bytes memory data = abi.encodePacked(
            KnightSafe.initialize.selector,
            abi.encode(ownerAddress, address(eventEmitter), address(tokenCallbackHandler))
        );
        vm.expectRevert(abi.encodeWithSelector(Errors.IsNullValue.selector));
        knightSafeProxyFactory.createProxy(address(0), data, salt);

        vm.expectRevert(abi.encodeWithSelector(Errors.AddressIsNotKnightSafeImplementation.selector, address(ksa)));
        knightSafeProxyFactory.createProxy(address(ksa), data, salt);

        vm.expectRevert();
        knightSafeProxyFactory.createProxy(
            address(implementation),
            abi.encodePacked(
                KnightSafe.initialize.selector,
                abi.encode(address(ownerAddress), address(0), address(tokenCallbackHandler))
            ),
            salt
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidAddress.selector, address(0)));
        knightSafe.updateControlCenter(address(0));
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidAddress.selector, address(12304)));
        knightSafe.updateControlCenter(address(12304));

        knightSafe.updateFallbackHandler(address(0));
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidAddress.selector, address(knightSafe)));
        knightSafe.updateFallbackHandler(address(knightSafe));
    }

    address[] preA = new address[](1);

    function test__preDeploy() public {
        bytes memory data = abi.encodePacked(
            KnightSafe.initialize.selector,
            abi.encode(ownerAddress, address(eventEmitter), address(tokenCallbackHandler))
        );
        uint256 salt = 2424;

        KnightSafeProxy deployedAddress = knightSafeProxyFactory.createProxy(address(implementation), data, salt);
        console.log(address(deployedAddress), "test__preDeploy");
        // console.log(address(preA), "preA");
    }

    function test_create2() public {
        bytes memory data = abi.encodePacked(
            KnightSafe.initialize.selector,
            abi.encode(ownerAddress, address(eventEmitter), address(tokenCallbackHandler))
        );

        knightSafeProxyFactory.createProxy(address(implementation), data, 4123);
        knightSafeProxyFactory.createProxy(address(implementation), data, 6666);
        knightSafeProxyFactory.createProxy(address(implementation), data, 5522);
        knightSafeProxyFactory.createProxy(address(implementation), data, 1357);

        uint256 salt = 2424;

        address computeAddress = knightSafeProxyFactory.computeAddress(salt, address(implementation));
        KnightSafeProxy deployedAddress = knightSafeProxyFactory.createProxy(address(implementation), data, salt);

        console.log(address(deployedAddress), "test_create2");

        assertEq(address(computeAddress), address(deployedAddress));

        vm.expectRevert(abi.encodeWithSelector(Errors.FailedDeployment.selector));
        knightSafeProxyFactory.createProxy(address(implementation), data, salt);
    }

    function testRevert_upgradeProxy() public {
        KnightSafe implementation2 = new KnightSafe();
        controlCenter.addOfficialImplementation(address(implementation2), "master_2.0");

        vm.expectRevert(abi.encodeWithSelector(Errors.IsNullValue.selector));
        ksProxy.upgradeTo(address(0));

        vm.prank(address(adminAddress));
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, address(adminAddress), "OWNER"));
        ksProxy.upgradeTo(address(implementation2));

        KnightSafe unsetImplementation = new KnightSafe();
        vm.expectRevert(
            abi.encodeWithSelector(Errors.AddressIsNotKnightSafeImplementation.selector, address(unsetImplementation))
        );
        ksProxy.upgradeTo(address(unsetImplementation));
    }

    function test_upgradeProxy() public {
        vm.deal(address(ksProxy), 1 ether);

        KnightSafe implementation2 = new KnightSafe();
        controlCenter.addOfficialImplementation(address(implementation2), "master_2.0");

        ksProxy.upgradeTo(address(implementation2));

        assertEq(address(ksProxy).balance, 1 ether);
    }

    function test_multicall() public {
        address trader = vm.addr(9091);
        address whiteListAddress = vm.addr(5001);

        bytes memory mutil_createPolicy = abi.encodePacked(PolicyManager.createPolicy.selector);
        bytes memory multi_addWhitelist =
            abi.encodePacked(PolicyManager.updateWhitelist.selector, abi.encode(1, whiteListAddress, address(ksa)));
        bytes memory multi_addTrader = abi.encodePacked(PolicyManager.addTrader.selector, abi.encode(1, trader));

        bytes[] memory data = new bytes[](3);
        data[0] = mutil_createPolicy;
        data[1] = multi_addWhitelist;
        data[2] = multi_addTrader;

        assertEq(knightSafe.getActivePolicyIds().length, 1);
        knightSafe.multicall(data);
        uint256[] memory activeIds = knightSafe.getActivePolicyIds();
        assertEq(activeIds.length, 2);
        assertTrue(knightSafe.isPolicyWhitelistAddress(1, whiteListAddress));
        assertTrue(knightSafe.isTrader(1, trader));
    }

    function testRevert_multicall() public {
        knightSafe.createPolicy();
        uint256[] memory activeIds = knightSafe.getActivePolicyIds();
        assertEq(activeIds.length, 2);

        bytes memory createPolicySelector = abi.encodePacked(PolicyManager.createPolicy.selector);
        bytes[] memory data = new bytes[](3);
        data[0] = createPolicySelector;
        data[1] = createPolicySelector;
        data[2] = createPolicySelector;

        vm.expectRevert(abi.encodeWithSelector(Errors.MaxPolicyCountReached.selector, 3));
        knightSafe.multicall(data);

        activeIds = knightSafe.getActivePolicyIds();
        assertEq(activeIds.length, 2);
    }

    function test_updateControlCenter() public {
        ControlCenter cc = new ControlCenter(address(1));
        controlCenter.addOfficialControlCenter(address(cc), "cc_1");
        knightSafe.updateControlCenter(address(cc));
        assertEq(knightSafe.getControlCenter(), address(cc));
    }

    function _castToEthers(uint256 amount) internal pure returns (uint256) {
        return amount * (10 ** (DECIMALS));
    }

    function _castToDefaultDecimal(uint256 amount) internal pure returns (uint256) {
        return amount * (10 ** (PRICE_DECIMALS));
    }

    function _castToValue(uint256 amount) internal pure returns (uint256) {
        return amount / (10 ** (PRICE_DECIMALS));
    }

    //todo move this to ControlCenter.t.sol
    function test_setBaseVolume() public {
        uint256 baseVolume = 1000;
        controlCenter.setBaseVolume(baseVolume);
        assertEq(controlCenter.baseTradingVolume(), baseVolume);

        vm.expectRevert(abi.encodeWithSelector(Errors.IsNullValue.selector));
        controlCenter.setBaseVolume(0);
    }
}

// yarn test --match-contract KnightSafeProxyTest
