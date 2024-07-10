// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {BaseKnightSafeAnalyser} from "./BaseKnightSafeAnalyser.sol";
import {IKnightSafeAnalyser} from "../interfaces/IKnightSafeAnalyser.sol";

contract GMXAnalyser is BaseKnightSafeAnalyser {
    event FeeReceiverUpdated(address indexed from, address indexed to);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    address public feeReceiver;
    address public immutable owner;
    address public immutable NATIVE_TOKEN;
    address public immutable DATA_STORE;

    bytes32 public constant CLAIMABLE_FUNDING_AMOUNT = keccak256(abi.encode("CLAIMABLE_FUNDING_AMOUNT"));

    constructor(address nativeToken_, address datastore, address owner_) {
        owner = owner_;
        feeReceiver = address(0);
        NATIVE_TOKEN = nativeToken_;
        DATA_STORE = datastore;
    }

    modifier onlyOwner() {
        if (owner != msg.sender) revert Unauthorized("OWNER");
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
            return (addrList, valueList);
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
            return (addrList, valueList);
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
        if (selector == Selectors.SEND_WNT || selector == Selectors.SEND_NATIVE_TOKEN) {
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
            rv = new address[](6);
            rv[0] = _getAddressFromBytes(data, 15); // receiver
            rv[1] = _getAddressFromBytes(data, 16); // cancellationReceiver
            rv[2] = _getAddressFromBytes(data, 17); // callbackContract
            address uiFeeReceiver = _getAddressFromBytes(data, 18); // uiFeeReceiver
            if (uiFeeReceiver == feeReceiver) {
                rv[3] = address(0);
            } else {
                rv[3] = uiFeeReceiver;
            }
            rv[4] = _getAddressFromBytes(data, 19); // marketToken
            rv[5] = _getAddressFromBytes(data, 20); // initialCollateralToken
            rint = new uint256[](rv.length);
            for (uint256 i = 0; i < rint.length; i++) {
                rint[i] = 0;
            }
            return (rv, rint);
        } else if (selector == Selectors.CREATE_SHIFT) {
            // createShift(param:tuple)
            rv = new address[](5);
            rv[0] = _getAddressFromBytes(data, 1); // receiver
            rv[1] = _getAddressFromBytes(data, 2); // callbackContract
            address uiFeeReceiver = _getAddressFromBytes(data, 3); // uiFeeReceiver
            if (uiFeeReceiver == feeReceiver) {
                rv[2] = address(0);
            } else {
                rv[2] = uiFeeReceiver;
            }
            rv[3] = _getAddressFromBytes(data, 4); // fromMarket
            rv[4] = _getAddressFromBytes(data, 5); // toMarket
            rint = new uint256[](rv.length);
            for (uint256 i = 0; i < rint.length; i++) {
                rint[i] = 0;
            }
            return (rv, rint);
        } else if (
            selector == Selectors.CANCEL_DEPOSIT || selector == Selectors.CANCEL_WITHDRAWAL
                || selector == Selectors.CANCEL_ORDER || selector == Selectors.UPDATE_ORDER
                || selector == Selectors.CANCEL_SHIFT
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
    // sendNativeToken(receiver:address, amount:uint256)
    bytes4 internal constant SEND_NATIVE_TOKEN = 0x53ead2d3;
    // sendTokens(token:address, receiver:address, amount:uint256)
    bytes4 internal constant SEND_TOKENS = 0xe6d66ac8;
    // createDeposit(param:tuple) << 0
    bytes4 internal constant CREATE_DEPOSIT = 0x5b4e9561;
    // createWithdrawal(param:tuple)
    bytes4 internal constant CREATE_WITHDRAWAL = 0xad23c5a1;
    // createOrder(param:tuple)
    bytes4 internal constant CREATE_ORDER = 0x083cfcee;
    // cancelDeposit(bytes32 key)
    bytes4 internal constant CANCEL_DEPOSIT = 0x31404484;
    //  cancelWithdrawal(bytes32 key)
    bytes4 internal constant CANCEL_WITHDRAWAL = 0x7489ec23;
    // cancelOrder(bytes32 key)
    bytes4 internal constant CANCEL_ORDER = 0x7213c5a0;
    // updateOrder(bytes32 key, uint256 sizeDeltaUsd, uint256 acceptablePrice, uint256 triggerPrice, uint256 minOutputAmount)
    bytes4 internal constant UPDATE_ORDER = 0xf82a2272;
    // createShift(param:tuple)
    bytes4 internal constant CREATE_SHIFT = 0xb1f906b9;
    // cancelShift(key:bytes32)
    bytes4 internal constant CANCEL_SHIFT = 0x96be2898;
}
