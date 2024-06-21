// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseKnightSafeAnalyser} from "./BaseKnightSafeAnalyser.sol";
import {IKnightSafeAnalyser} from "../interfaces/IKnightSafeAnalyser.sol";

contract GMXAnalyser is BaseKnightSafeAnalyser {
    event FeeReceiverUpdated(address indexed from, address indexed to);

    address public owner;
    address public feeReceiver;
    address public immutable NATIVE_TOKEN;
    address public immutable DATA_STORE;

    bytes32 public constant CLAIMABLE_FUNDING_AMOUNT = keccak256(abi.encode("CLAIMABLE_FUNDING_AMOUNT"));

    constructor(address nativeToken_, address datastore) {
        owner = msg.sender;
        feeReceiver = address(0);
        NATIVE_TOKEN = nativeToken_;
        DATA_STORE = datastore;
    }

    modifier onlyOwner() {
        if (owner != msg.sender) revert Unauthorized("Owner");
        _;
    }

    function updateFeeReceiver(address feeReceiver_) public onlyOwner {
        address _feeReceiver = feeReceiver;
        feeReceiver = feeReceiver_;
        emit FeeReceiverUpdated(_feeReceiver, feeReceiver_);
    }

    /// @inheritdoc IKnightSafeAnalyser
    function extractAddressesWithValue(address to, bytes calldata data)
        external
        view
        override
        returns (address[] memory addrList, uint256[] memory valueList)
    {
        bytes4 selector = getSelector(data);
        /// GMX V2 function from multicall
        if (selector == Selectors.MULTICALL) {
            bytes[] calldata multicallData;
            assembly {
                let dataOffset := add(data.offset, 4)

                let mcDataOffset := calldataload(dataOffset)
                multicallData.offset := add(add(dataOffset, mcDataOffset), 0x20)
                multicallData.length := calldataload(add(dataOffset, mcDataOffset))
            }

            (addrList, valueList) = _getAddressArrayFromMulticall(multicallData, to);
            // in case all check is valid but no address to check, we return "to" instead of empty array
            if (addrList.length == 0) {
                addrList = new address[](1);
                addrList[0] = to;

                valueList = new uint256[](1);
                valueList[0] = 0;
            }
        } else if (selector == Selectors.CLAIM_FUNDING_FEES) {
            address[] calldata markets = _getAddressArray(data, 0);
            address[] calldata tokens = _getAddressArray(data, 1);

            addrList = new address[](tokens.length + 1);
            valueList = new uint256[](addrList.length);
            for (uint256 i = 0; i < tokens.length; i++) {
                addrList[i] = tokens[i];
                valueList[i] = _getClaimableAmount(markets[i], tokens[i], msg.sender);
            }

            addrList[tokens.length] = _getAddressFromBytes(data, 2); // receiver
            valueList[tokens.length] = 0;
        }

        revert UnsupportedCommand();
    }

    function _getAddressArrayFromMulticall(bytes[] calldata multicall, address to)
        internal
        view
        returns (address[] memory, uint256[] memory)
    {
        address[][] memory _addressArrays = new address[][](multicall.length);
        uint256[][] memory _intArrays = new uint256[][](multicall.length);
        uint256 _addressCount = 0;
        for (uint256 i = 0; i < multicall.length; i++) {
            bytes calldata _data = multicall[i];
            bytes4 _selector;
            assembly {
                _selector := calldataload(_data.offset)
            }
            (address[] memory _addressArray, uint256[] memory _intArray) = _dispatch(_selector, _data);
            _addressCount += _addressArray.length;
            _addressArrays[i] = _addressArray;
            _intArrays[i] = _intArray;
        }

        address[] memory rv = new address[](_addressCount);
        uint256[] memory ri = new uint256[](_addressCount);
        uint256 x = 0;
        for (uint256 i = 0; i < _addressArrays.length; i++) {
            for (uint256 j = 0; j < _addressArrays[i].length; j++) {
                rv[x] = _map(_addressArrays[i][j], to);
                ri[x] = _intArrays[i][j];
                x++;
            }
        }

        return (rv, ri);
    }

    function _dispatch(bytes4 selector, bytes calldata data)
        internal
        view
        returns (address[] memory rv, uint256[] memory rint)
    {
        if (selector == Selectors.SEND_WNT) {
            // sendWnt(receiver:address, amount:uint256)
            rv = new address[](2);
            rv[0] = _getAddressFromBytes(data, 0);
            rv[1] = NATIVE_TOKEN;
            rint = new uint256[](rv.length);
            rint[0] = 0;
            rint[1] = 0;
            return (rv, rint);
        } else if (selector == Selectors.SEND_TOKENS) {
            // sendTokens(token:address, receiver:address, amount:uint256)
            rv = new address[](2);
            rv[0] = _getAddressFromBytes(data, 0); // token
            rv[1] = _getAddressFromBytes(data, 1); // receiver

            rint = new uint256[](rv.length);
            rint[0] = _getUintFromBytes(data, 2);
            rint[1] = 0;
            return (rv, rint);
        } else if (selector == Selectors.CREATE_DEPOSIT) {
            // createDeposit(param:tuple)
            rv = new address[](6);
            rv[0] = _getAddressFromBytes(data, 1); // receiver
            rv[1] = _getAddressFromBytes(data, 2); // callbackContract
            address uiFeeReceiver = _getAddressFromBytes(data, 3); // uiFeeReceiver
            if (uiFeeReceiver == feeReceiver) {
                rv[2] = address(0);
            } else {
                rv[2] = uiFeeReceiver;
            }
            rv[3] = _getAddressFromBytes(data, 4); // marketToken
            rv[4] = _getAddressFromBytes(data, 5); // longToken
            rv[5] = _getAddressFromBytes(data, 6); // shortToken
            rint = new uint256[](rv.length);
            for (uint256 i = 0; i < rint.length; i++) {
                rint[i] = 0;
            }
            return (rv, rint);
        } else if (selector == Selectors.CREATE_WITHDRAWAL) {
            // createWithdrawal(param:tuple)
            rv = new address[](4);
            rv[0] = _getAddressFromBytes(data, 1); // receiver
            rv[1] = _getAddressFromBytes(data, 2); // callbackContract
            address uiFeeReceiver = _getAddressFromBytes(data, 3); // uiFeeReceiver
            if (uiFeeReceiver == feeReceiver) {
                rv[2] = address(0);
            } else {
                rv[2] = uiFeeReceiver;
            }
            rv[3] = _getAddressFromBytes(data, 4); // marketToken
            rint = new uint256[](rv.length);
            for (uint256 i = 0; i < rint.length; i++) {
                rint[i] = 0;
            }

            return (rv, rint);
        } else if (selector == Selectors.CREATE_ORDER) {
            // createOrder(param:tuple)
            rv = new address[](5);
            rv[0] = _getAddressFromBytes(data, 14); // receiver
            rv[1] = _getAddressFromBytes(data, 15); // callbackContract
            address uiFeeReceiver = _getAddressFromBytes(data, 16); // uiFeeReceiver
            if (uiFeeReceiver == feeReceiver) {
                rv[2] = address(0);
            } else {
                rv[2] = uiFeeReceiver;
            }
            rv[3] = _getAddressFromBytes(data, 17); // marketToken
            rv[4] = _getAddressFromBytes(data, 18); // initialCollateralToken
            rint = new uint256[](rv.length);
            for (uint256 i = 0; i < rint.length; i++) {
                rint[i] = 0;
            }
            return (rv, rint);
        } else if (
            selector == Selectors.CANCEL_DEPOSIT || selector == Selectors.CANCEL_WITHDRAWAL
                || selector == Selectors.CANCEL_ORDER || selector == Selectors.UPDATE_ORDER
        ) {
            rv = new address[](1);
            rint = new uint256[](rv.length);
            rv[0] = address(0);
            rint[0] = 0;
            return (rv, rint);
        }
        revert UnsupportedCommand();
    }

    function _map(address recipient, address to) internal pure returns (address) {
        if (recipient == address(0)) {
            return to;
        } else {
            return recipient;
        }
    }

    function _getClaimableAmount(address market, address token, address account) private view returns (uint256) {
        bytes32 key = keccak256(abi.encode(CLAIMABLE_FUNDING_AMOUNT, market, token, account));
        return IDataStore(DATA_STORE).getUint(key);
    }
}

interface IDataStore {
    function getUint(bytes32 key) external view returns (uint256);
}

library Selectors {
    /// GMX V2
    // multicall(data:bytezs[])
    bytes4 internal constant MULTICALL = 0xac9650d8;
    // claimFundingFees(markets:address[],tokens:address[],receiver:address)
    bytes4 internal constant CLAIM_FUNDING_FEES = 0xc41b1ab3;

    //  sendWnt(receiver:address, amount:uint256)
    bytes4 internal constant SEND_WNT = 0x7d39aaf1;
    // sendTokens(token:address, receiver:address, amount:uint256)
    bytes4 internal constant SEND_TOKENS = 0xe6d66ac8;
    // createDeposit(param:tuple) << 0
    bytes4 internal constant CREATE_DEPOSIT = 0x5b4e9561;
    // createWithdrawal(param:tuple)
    bytes4 internal constant CREATE_WITHDRAWAL = 0xad23c5a1;
    // createOrder(param:tuple)
    bytes4 internal constant CREATE_ORDER = 0x4a393a41;
    // cancelDeposit(bytes32 key)
    bytes4 internal constant CANCEL_DEPOSIT = 0x31404484;
    //  cancelWithdrawal(bytes32 key)
    bytes4 internal constant CANCEL_WITHDRAWAL = 0x7489ec23;
    // cancelOrder(bytes32 key)
    bytes4 internal constant CANCEL_ORDER = 0x7213c5a0;
    // updateOrder(bytes32 key, uint256 sizeDeltaUsd, uint256 acceptablePrice, uint256 triggerPrice, uint256 minOutputAmount)
    bytes4 internal constant UPDATE_ORDER = 0xaab286f8;

    /// GMX V1
    // decreasePositionAndSwap(_path:address[],_indexToken:address,_collateralDelta:uint256,_sizeDelta:uint256,_isLong:bool,
    // _receiver:address,_price:uint256,_minOut:uint256)
    bytes4 internal constant DECREASE_POSITION_AND_SWAP = 0x5fc8500e;
    // increasePosition(_path:address[],_indexToken:address,_amountIn:uint256,_minOut:uint256,_sizeDelta:uint256,_isLong:bool,_price:uint256)
    bytes4 internal constant INCREASE_POSITION = 0xb7ddc992;
    // swap(_path:address[],_amountIn:uint256,_minOut:uint256,_receiver:address)
    bytes4 internal constant SWAP = 0x6023e966;
    // createIncreasePosition(_path:address[],_indexToken:address,_amountIn:uint256,_minOut:uint256,_sizeDelta:uint256,
    // _isLong:bool,_acceptablePrice:uint256,_executionFee:uint256,_referralCode:bytes32,_callbackTarget:address)
    bytes4 internal constant CREATE_INCREASE_POSITION = 0xf2ae372f;

    // decreasePositionAndSwapETH(_path:address[],_indexToken:address,_collateralDelta:uint256,_sizeDelta:uint256,
    // _isLong:bool,_receiver:address,_price:uint256,_minOut:uint256)
    bytes4 internal constant DECREASE_POSITION_AND_SWAP_ETH = 0x3039e37f;
    // swapTokensToETH(_path:address[],_amountIn:uint256,_minOut:uint256,_receiver:address)
    bytes4 internal constant SWAP_TOKENS_TO_ETH = 0x2d4ba6a7;

    // increasePositionETH(_path:address[],_indexToken:address,_minOut:uint256,_sizeDelta:uint256,_isLong:bool,_price:uint256)
    bytes4 internal constant INCREASE_POSITION_ETH = 0xb32755de;
    // swapETHToTokens(_path:address[],_minOut:uint256,_receiver:address)
    bytes4 internal constant SWAP_ETH_TO_TOKENS = 0xabe68eaa;
    // createIncreasePositionETH(_path:address[],_indexToken:address,_minOut:uint256,_sizeDelta:uint256,_isLong:bool,_acceptablePrice:uint256,
    // _executionFee:uint256,_referralCode:bytes32,_callbackTarget:address)
    bytes4 internal constant CREATE_INCREASE_POSITION_ETH = 0x5b88e8c6;

    // createDecreasePosition(_path:address[],_indexToken:address,_collateralDelta:uint256,_sizeDelta:uint256,_isLong:bool,_receiver:address,
    // _acceptablePrice:uint256,_minOut:uint256,_executionFee:uint256,_withdrawETH:bool,_callbackTarget:address)
    bytes4 internal constant CREATE_DECREASE_POSITION = 0x7be7d141;

    // createIncreaseOrder(_path:address[],_amountIn:uint256,_indexToken:address,_minOut:uint256,_sizeDelta:uint256,_collateralToken:address,_isLong:bool,
    // _triggerPrice:uint256,_triggerAboveThreshold:bool,_executionFee:uint256,_shouldWrap:bool)
    bytes4 internal constant CREATE_INCREASE_ORDER = 0xb142a4b0;

    // createSwapOrder(_path:address[],_amountIn:uint256,_minOut:uint256,_triggerRatio:uint256,_triggerAboveThreshold:bool,
    // _executionFee:uint256,_shouldWrap:bool,_shouldUnwrap:bool)
    bytes4 internal constant CREATE_SWAP_ORDER = 0x269ae6c2;
}
