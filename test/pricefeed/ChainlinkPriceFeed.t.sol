// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import "@/knightSafeAnalyser/ERC20Analyser.sol";
import "@/controlCenter/ControlCenter.sol";
import "@/priceFeed/ChainlinkPriceFeed.sol";
import "@/interfaces/IEventEmitter.sol";

contract ChainlinkPriceFeedTest is Test {
    ControlCenter controlCenter;
    ChainlinkPriceFeed priceFeed;
    MockERC20 mockETH;
    MockV3Aggregator dataFeed;
    address mockToken = address(0x10001);

    uint8 constant DECIMALS = 18;
    uint8 constant PRICE_FEED_DECIMALS = 8;
    uint8 constant PRICE_DECIMALS = 30;

    uint256 constant DECIMALS18 = 10 ** DECIMALS;
    uint256 constant PRICE_DECIMALS18 = 10 ** PRICE_DECIMALS;

    int256 INITIAL_ANSWER = 1000;
    int256 LATEST_ANSWER = 2000 * int256(DECIMALS18);
    uint80 LATEST_ROUND = 1;

    uint256 timestamp = block.timestamp;
    address internal ownerAddress = address(this);

    function setUp() public {
        controlCenter = new ControlCenter(ownerAddress);

        mockETH = new MockERC20();
        mockETH.initialize("ETH", "meth", 18);

        dataFeed = new MockV3Aggregator(PRICE_FEED_DECIMALS, INITIAL_ANSWER);
        dataFeed.updateRoundData(LATEST_ROUND, LATEST_ANSWER, timestamp, timestamp);

        priceFeed =
            new ChainlinkPriceFeed(ownerAddress, address(controlCenter), address(mockETH), address(dataFeed), 86400);

        assertEq(priceFeed.getPriceFeed(address(mockETH)), address(dataFeed));
        IEventEmitter(controlCenter).setFactory(address(priceFeed));
    }

    function test_successSetUp() public {
        assertEq(priceFeed.getNativeToken(), address(mockETH));
        assertTrue(priceFeed.isControlCenter(address(controlCenter)));
    }

    function test_setPriceFeed() public {
        priceFeed.setPriceFeed(mockToken, address(0x1010), 86400);
        assertEq(priceFeed.getPriceFeed(mockToken), address(0x1010));
    }

    function test_batchSetPriceFeed() public {
        address[] memory tokens = new address[](2);
        tokens[0] = address(0x1001);
        tokens[1] = address(0x1002);
        address[] memory priceFeeds = new address[](2);
        priceFeeds[0] = address(0x1010);
        priceFeeds[1] = address(0x1011);
        uint256[] memory heartbeatTime = new uint256[](2);
        priceFeed.batchSetPriceFeed(tokens, priceFeeds, heartbeatTime);
        assertEq(priceFeed.getPriceFeed(tokens[0]), priceFeeds[0]);
        assertEq(priceFeed.getPriceFeed(tokens[1]), priceFeeds[1]);
    }

    function testRevert_batchSetPriceFeed() public {
        address[] memory tokens = new address[](2);
        tokens[0] = address(0x1001);
        tokens[1] = address(0x1002);
        address[] memory priceFeeds = new address[](1);
        priceFeeds[0] = address(0x1010);
        uint256[] memory heartbeatTime = new uint256[](2);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidLength.selector));
        priceFeed.batchSetPriceFeed(tokens, priceFeeds, heartbeatTime);

        address[] memory priceFeed2 = new address[](2);
        priceFeed2[0] = address(0x1010);
        priceFeed2[1] = address(0x1011);
        vm.prank(address(1010));
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, address(1010), "OWNER"));
        priceFeed.batchSetPriceFeed(tokens, priceFeed2, heartbeatTime);

        assertEq(priceFeed.getPriceFeed(tokens[0]), address(0));
    }

    function test_getPrice() public view {
        (uint80 roundId, int256 answer,,,) = dataFeed.latestRoundData();
        assertEq(roundId, LATEST_ROUND);
        assertEq(answer, LATEST_ANSWER);

        address[] memory feedAddress = new address[](1);
        feedAddress[0] = address(mockETH);
        uint256[] memory feedAmount = new uint256[](1);
        feedAmount[0] = 10 * (10 ** uint256(PRICE_FEED_DECIMALS));

        uint256 amt = priceFeed.getNativeTokenVolume(feedAmount[0]);

        assertEq(amt, _scalePrice(uint256(LATEST_ANSWER) * feedAmount[0], PRICE_FEED_DECIMALS + DECIMALS));

        amt = priceFeed.getTransactionVolume(feedAddress, feedAmount);
        assertEq(amt, _scalePrice(uint256(LATEST_ANSWER) * feedAmount[0], PRICE_FEED_DECIMALS + DECIMALS));

        feedAddress = new address[](2);
        feedAddress[0] = address(mockETH);
        feedAddress[1] = address(mockETH);
        feedAmount = new uint256[](2);
        feedAmount[0] = 10 * (10 ** uint256(PRICE_FEED_DECIMALS));
        feedAmount[1] = 20 * (10 ** uint256(PRICE_FEED_DECIMALS));
        amt = priceFeed.getTransactionVolume(feedAddress, feedAmount);
        assertEq(
            amt,
            _scalePrice(
                uint256(LATEST_ANSWER) * feedAmount[0] + uint256(LATEST_ANSWER) * feedAmount[1],
                PRICE_FEED_DECIMALS + DECIMALS
            )
        );
    }

    function _scalePrice(uint256 _price, uint8 _priceDecimals) internal pure returns (uint256) {
        if (_priceDecimals < PRICE_DECIMALS) {
            return _price * (10 ** uint256(PRICE_DECIMALS - _priceDecimals));
        } else if (_priceDecimals > PRICE_DECIMALS) {
            return _price / (10 ** uint256(_priceDecimals - PRICE_DECIMALS));
        }
        return _price;
    }
}

// $ yarn test --match-contract ChainlinkPriceFeedTest
