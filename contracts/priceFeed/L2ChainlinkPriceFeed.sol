// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/interfaces/AggregatorV2V3Interface.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Errors} from "@/error/Errors.sol";
import {IPriceFeed} from "@/interfaces/IPriceFeed.sol";
import {PriceFeedEventUtils} from "./PriceFeedEventUtils.sol";

/// @notice inherit Doc {IPriceFeed}
contract ChainlinkPriceFeed is Context, IPriceFeed {
    /**
     * @dev The answer is too old.
     */
    error PriceTooOld();
    /**
     * @dev The sequencer is down.
     */
    error SequencerDown();
    /**
     * @dev The grace period is not over.
     */
    error GracePeriodNotOver();

    address internal _owner;
    address private _controlCenter;

    address private _sequencerUptimeFeed;
    mapping(address => address) private _priceFeedMap;
    mapping(address => uint256) private _heartbeatMap;
    address private _wrappedNativeTokenAddress;

    uint8 private constant _BASE_DECIMALS = 30;
    uint8 private constant _NATIVE_DECIMALS = 18;
    uint256 private constant HEARTBEAT_TIME = 3600;
    uint256 private constant GRACE_PERIOD_TIME = 3600;

    constructor(
        address owner,
        address controlCenter,
        address wrappedNativeTokenAddress,
        address nativeTokenPriceFeed,
        address sequencerUptimeFeed,
        uint256 heartbeatTime
    ) {
        if (
            owner == address(0) || controlCenter == address(0) || wrappedNativeTokenAddress == address(0)
                || nativeTokenPriceFeed == address(0) || heartbeatTime == 0 || sequencerUptimeFeed == address(0)
        ) {
            revert Errors.IsNullValue();
        }

        _owner = owner;
        _controlCenter = controlCenter;
        _wrappedNativeTokenAddress = wrappedNativeTokenAddress;
        _priceFeedMap[wrappedNativeTokenAddress] = nativeTokenPriceFeed;
        _heartbeatMap[nativeTokenPriceFeed] = heartbeatTime;
        _sequencerUptimeFeed = sequencerUptimeFeed;
    }

    modifier onlyOwner() {
        if (!_checkOwner()) revert Errors.Unauthorized(_msgSender(), "OWNER");
        _;
    }

    function _checkOwner() internal view returns (bool) {
        return _owner == _msgSender();
    }

    function isControlCenter(address controlCenter) public view returns (bool) {
        return _controlCenter == controlCenter;
    }

    /// @inheritdoc IPriceFeed
    function getNativeToken() public view returns (address) {
        return _wrappedNativeTokenAddress;
    }

    /// @inheritdoc IPriceFeed
    function setPriceFeed(address token, address priceFeed, uint256 heartbeatTime) public onlyOwner {
        _priceFeedMap[token] = priceFeed;

        if (heartbeatTime == 0) {
            heartbeatTime = HEARTBEAT_TIME;
        }
        _heartbeatMap[priceFeed] = heartbeatTime;

        PriceFeedEventUtils.emitSetPriceFeed(_controlCenter, token, priceFeed);
    }

    /// @inheritdoc IPriceFeed
    function batchSetPriceFeed(address[] memory tokens, address[] memory priceFeeds, uint256[] memory heartbeatTimes)
        public
        onlyOwner
    {
        if (tokens.length != priceFeeds.length) revert Errors.InvalidLength();

        for (uint256 i = 0; i < tokens.length; i++) {
            _priceFeedMap[tokens[i]] = priceFeeds[i];

            if (heartbeatTimes[i] == 0) {
                _heartbeatMap[priceFeeds[i]] = HEARTBEAT_TIME;
            } else {
                _heartbeatMap[priceFeeds[i]] = heartbeatTimes[i];
            }
        }

        PriceFeedEventUtils.emitSetPriceFeed(_controlCenter, tokens, priceFeeds);
    }

    /// @inheritdoc IPriceFeed
    function getPriceFeed(address token) public view returns (address) {
        return _priceFeedMap[token];
    }

    /// @inheritdoc IPriceFeed
    function getTransactionVolume(address[] memory contractAddresses, uint256[] memory amounts)
        external
        view
        returns (uint256)
    {
        uint256 totalVolume = 0;
        for (uint256 i = 0; i < contractAddresses.length; i++) {
            if (amounts[i] == 0) {
                continue;
            }

            (uint256 answer, uint8 priceFeedDecimals) = getChainlinkDataFeedLatestAnswer(contractAddresses[i]);

            uint8 tokenDecimals = 0;

            bytes memory data = abi.encodeWithSelector(IERC20Metadata.decimals.selector);
            (bool success, bytes memory returnData) = contractAddresses[i].staticcall(data);
            if (success && returnData.length == 32) {
                tokenDecimals = abi.decode(returnData, (uint8));
            } else {
                continue;
            }

            totalVolume += _scalePrice((uint256(answer) * amounts[i]), (priceFeedDecimals + tokenDecimals));
        }
        return totalVolume;
    }

    /// @inheritdoc IPriceFeed
    function getNativeTokenVolume(uint256 amount) public view returns (uint256) {
        uint256 totalVolume = 0;
        (uint256 answer, uint8 priceFeedDecimals) = getChainlinkDataFeedLatestAnswer(_wrappedNativeTokenAddress);

        totalVolume += _scalePrice((uint256(answer) * amount), (priceFeedDecimals + _NATIVE_DECIMALS));

        return totalVolume;
    }

    function getChainlinkDataFeedLatestAnswer(address token) public view returns (uint256 amt, uint8 decimals) {
        address priceFeed = _priceFeedMap[token];
        if (priceFeed == address(0)) {
            return (0, 0);
        }

        (
            /*uint80 roundID*/
            ,
            int256 seqAnswer,
            uint256 startedAt,
            /*uint256 updatedAt*/
            ,
            /*uint80 answeredInRound*/
        ) = AggregatorV2V3Interface(_sequencerUptimeFeed).latestRoundData();

        // Answer == 0: Sequencer is up
        // Answer == 1: Sequencer is down
        bool isSequencerUp = seqAnswer == 0;
        if (!isSequencerUp) {
            revert SequencerDown();
        }

        // Make sure the grace period has passed after the
        // sequencer is back up.
        uint256 timeSinceUp = block.timestamp - startedAt;
        if (timeSinceUp <= GRACE_PERIOD_TIME) {
            revert GracePeriodNotOver();
        }

        (, int256 answer,, uint256 updatedAt,) = AggregatorV2V3Interface(priceFeed).latestRoundData();
        if (answer <= 0) {
            revert Errors.IsNullValue();
        }
        uint256 timeSince = block.timestamp - updatedAt;
        if (timeSince >= _heartbeatMap[priceFeed]) {
            revert PriceTooOld();
        }
        decimals = AggregatorV2V3Interface(priceFeed).decimals();

        return (uint256(answer), decimals);
    }

    function _scalePrice(uint256 _price, uint8 _priceDecimals) internal pure returns (uint256) {
        if (_priceDecimals < _BASE_DECIMALS) {
            return _price * (10 ** uint256(_BASE_DECIMALS - _priceDecimals));
        } else if (_priceDecimals > _BASE_DECIMALS) {
            return _price / (10 ** uint256(_priceDecimals - _BASE_DECIMALS));
        }
        return _price;
    }
}
