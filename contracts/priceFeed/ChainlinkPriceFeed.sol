// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import {AggregatorV2V3Interface} from "@chainlink/contracts/interfaces/feeds/AggregatorV2V3Interface.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Errors} from "@/error/Errors.sol";
import {IPriceFeed} from "@/interfaces/IPriceFeed.sol";
import {PriceFeedEventUtils} from "./PriceFeedEventUtils.sol";

/// @notice inherit Doc {IPriceFeed}
contract ChainlinkPriceFeed is Context, IPriceFeed {
    address internal _owner;
    address private _controlCenter;

    mapping(address => address) private _priceFeedMap;
    address private _wrappedNativeTokenAddress;

    uint8 private constant _BASE_DECIMALS = 30;
    uint8 private constant _NATIVE_DECIMALS = 18;

    constructor(address controlCenter, address wrappedNativeTokenAddress, address nativeTokenPriceFeed) {
        if (
            controlCenter == address(0) || wrappedNativeTokenAddress == address(0) || nativeTokenPriceFeed == address(0)
        ) {
            revert Errors.IsNullValue();
        }
        _owner = _msgSender();

        _controlCenter = controlCenter;
        _wrappedNativeTokenAddress = wrappedNativeTokenAddress;
        _priceFeedMap[wrappedNativeTokenAddress] = nativeTokenPriceFeed;
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
    function setPriceFeed(address token, address priceFeed) public onlyOwner {
        _priceFeedMap[token] = priceFeed;

        PriceFeedEventUtils.emitsetPriceFeed(_controlCenter, token, priceFeed);
    }

    /// @inheritdoc IPriceFeed
    function batchSetPriceFeed(address[] memory tokens, address[] memory priceFeeds) public onlyOwner {
        if (tokens.length != priceFeeds.length) revert Errors.InvalidLength();

        for (uint256 i = 0; i < tokens.length; i++) {
            _priceFeedMap[tokens[i]] = priceFeeds[i];
        }

        PriceFeedEventUtils.emitsetPriceFeed(_controlCenter, tokens, priceFeeds);
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
            uint8 tokenDecimals = 0;
            (uint256 answer, uint8 priceFeedDecimals) = getChainlinkDataFeedLatestAnswer(contractAddresses[i]);
            try IERC20Metadata(contractAddresses[i]).decimals() returns (uint8 dec_) {
                tokenDecimals = dec_;
            } catch {
                // catch when contractAddress not implement IERC20Metadata
                // This is executed in case revert() was used.
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
            revert Errors.IsNullValue();
        }

        (, int256 answer,,,) = AggregatorV2V3Interface(priceFeed).latestRoundData();
        decimals = AggregatorV2V3Interface(priceFeed).decimals();

        amt += uint256(answer);
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
