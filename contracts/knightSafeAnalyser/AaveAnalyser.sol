// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {BaseKnightSafeAnalyser} from "./BaseKnightSafeAnalyser.sol";
import "../interfaces/IKnightSafeAnalyser.sol";
import {AaveHelpers} from "./helpers/AaveHelpers.sol";

contract AaveAnalyser is BaseKnightSafeAnalyser {
    function extractAddressesWithValue(address to, bytes calldata data)
        external
        view
        override
        returns (address[] memory addrList, uint256[] memory valueList)
    {
        bytes4 selector = getSelector(data);

        if (
            selector == 0xd5eed868 // borrow(args:bytes32)
                || selector == 0xf7a73840 // supply(args:bytes32)
        ) {
            uint16 assetId = AaveHelpers.getAssetId(data, 0);
            uint256 amount = AaveHelpers.getAmount(data, 0);
            addrList = new address[](1);
            valueList = new uint256[](addrList.length);
            addrList[0] = AaveHelpers.getAddressByAssetId(to, assetId); // asset
            valueList[0] = amount; // amount
            return (addrList, valueList);
        } else if (
            selector == 0x563dd613 // repay(args:bytes32)
        ) {
            (address asset, uint256 amount, uint256 interestRateMode) =
                AaveHelpers.decodeL2RepayParams(_getBytes32FromBytes(data, 0), to);

            addrList = new address[](1);
            valueList = new uint256[](addrList.length);
            addrList[0] = asset; // asset
            valueList[0] = AaveHelpers.mapRepayAmount(asset, amount, to, false, interestRateMode); // amount
            return (addrList, valueList);
        } else if (
            selector == 0xdc7c0bff // repayWithATokens(args:bytes32)
        ) {
            (address asset, uint256 amount, uint256 interestRateMode) =
                AaveHelpers.decodeL2RepayParams(_getBytes32FromBytes(data, 0), to);

            addrList = new address[](1);
            valueList = new uint256[](addrList.length);
            addrList[0] = asset; // asset
            valueList[0] = AaveHelpers.mapRepayAmount(asset, amount, to, true, interestRateMode); // amount
            return (addrList, valueList);
        } else if (
            selector == 0x573ade81 // repay(asset:address,amount:uint256,interestRateMode:uint256,onBehalfOf:address)
        ) {
            address asset = _getAddressFromBytes(data, 0);
            uint256 amount = _getUintFromBytes(data, 1);
            uint256 interestRateMode = _getUintFromBytes(data, 2);

            addrList = new address[](2);
            valueList = new uint256[](addrList.length);
            addrList[0] = asset; // asset
            addrList[1] = _getAddressFromBytes(data, 3); // onBehalfOf
            valueList[0] = AaveHelpers.mapRepayAmount(asset, amount, to, false, interestRateMode); // amount
            valueList[1] = 0;
            return (addrList, valueList);
        } else if (
            selector == 0x2dad97d4 // repayWithATokens(asset:address,amount:uint256,interestRateMode:uint256)
        ) {
            address asset = _getAddressFromBytes(data, 0);
            uint256 amount = _getUintFromBytes(data, 1);
            uint256 interestRateMode = _getUintFromBytes(data, 2);

            addrList = new address[](1);
            valueList = new uint256[](addrList.length);
            addrList[0] = asset; // asset
            valueList[0] = AaveHelpers.mapRepayAmount(asset, amount, to, true, interestRateMode); // amount
            return (addrList, valueList);
        } else if (
            selector == 0x8e19899e // withdraw(args:bytes32)
        ) {
            uint16 assetId = AaveHelpers.getAssetId(data, 0);
            uint256 amount = AaveHelpers.getAmount(data, 0);
            address asset = AaveHelpers.getAddressByAssetId(to, assetId);

            addrList = new address[](1);
            valueList = new uint256[](addrList.length);
            addrList[0] = asset; // asset
            valueList[0] = AaveHelpers.mapWithdrawAmount(asset, amount, to); // amount
            return (addrList, valueList);
        } else if (
            selector == 0x69328dec // withdraw(asset:address,amount:uint256,to:address)
        ) {
            address asset = _getAddressFromBytes(data, 0);
            uint256 amount = _getUintFromBytes(data, 1);
            addrList = new address[](2);
            valueList = new uint256[](addrList.length);
            addrList[0] = asset; //  assets
            addrList[1] = _getAddressFromBytes(data, 2); // onBehalfOf
            valueList[0] = AaveHelpers.mapWithdrawAmount(asset, amount, to); // amount
            valueList[1] = 0;
            return (addrList, valueList);
        } else if (
            selector == 0x4d013f03 // setUserUseReserveAsCollateral(args:bytes32
                || selector == 0x1fe3c6f3 // swapBorrowRateMode(args:bytes32)
        ) {
            uint16 assetId = AaveHelpers.getAssetId(data, 0);
            addrList = new address[](1);
            valueList = new uint256[](addrList.length);
            addrList[0] = AaveHelpers.getAddressByAssetId(to, assetId); // asset
            valueList[0] = 0;
            return (addrList, valueList);
        } else if (
            selector == 0xfd21ecff // liquidationCall(args1:bytes32,args2:bytes32)
                || selector == 0x00a718a9 //  liquidationCall(collateralAsset:address,debtAsset:address,user:address,debtToCover:uint256,receiveAToken:bool)
        ) {
            addrList = new address[](1);
            valueList = new uint256[](addrList.length);
            addrList[0] = to; // default to address
            valueList[0] = 0;
            return (addrList, valueList);
        } else if (
            selector == 0x9cd19996 // mintToTreasury(assets:address[])
        ) {
            address[] calldata assets = _getAddressArray(data, 0);
            addrList = new address[](assets.length);
            valueList = new uint256[](addrList.length);
            for (uint256 i = 0; i < assets.length; i++) {
                addrList[i] = assets[i]; // assets
                valueList[i] = 0;
            }
            return (addrList, valueList);
        } else if (
            selector == 0x427da177 // rebalanceStableBorrowRate(args:bytes32)
        ) {
            (address user, uint16 assetId) = _getAddressAndAssetId(data, 0);
            addrList = new address[](2);
            valueList = new uint256[](addrList.length);
            addrList[0] = user;
            addrList[1] = AaveHelpers.getAddressByAssetId(to, assetId); // asset
            valueList[0] = 0;
            valueList[1] = 0;
            return (addrList, valueList);
        } else if (
            selector == 0xd65dc7a1 // backUnbacked(asset:address,amount:uint256,fee:uint256)
        ) {
            addrList = new address[](1);
            valueList = new uint256[](addrList.length);
            addrList[0] = _getAddressFromBytes(data, 0); // asset
            valueList[0] = _getUintFromBytes(data, 1); // amount
            return (addrList, valueList);
        } else if (
            selector == 0xa415bcad // borrow(asset:address,amount:uint256,interestRateMode:uint256,referralCode:uint16,onBehalfOf:address)
        ) {
            addrList = new address[](2);
            valueList = new uint256[](addrList.length);
            addrList[0] = _getAddressFromBytes(data, 0); // asset
            addrList[1] = _getAddressFromBytes(data, 4); // onBehalfOf
            valueList[0] = _getUintFromBytes(data, 1); // amount
            valueList[1] = 0;
            return (addrList, valueList);
        } else if (
            selector == 0xe8eda9df //deposit(asset:address,amount:uint256,onBehalfOf:address,referralCode:uint16)
                || selector == 0x69a933a5 // mintUnbacked(asset:address,amount:uint256,onBehalfOf:address,referralCode:uint16)
                || selector == 0x617ba037 // supply(asset:address,amount:uint256,onBehalfOf:address,referralCode:uint16)
        ) {
            addrList = new address[](2);
            valueList = new uint256[](addrList.length);
            addrList[0] = _getAddressFromBytes(data, 0); //  assets
            addrList[1] = _getAddressFromBytes(data, 2); // onBehalfOf
            valueList[0] = _getUintFromBytes(data, 1); // amount
            valueList[1] = 0;
            return (addrList, valueList);
        } else if (
            selector == 0x63c9b860 // dropReserve(asset:address)
                || selector == 0xc4d66de8 // initialize(provider:address)
                || selector == 0xe43e88a1 // resetIsolationModeTotalDebt(asset:address)
                || selector == 0x5a3b74b9 // setUserUseReserveAsCollateral(asset:address,useAsCollateral:bool)
                || selector == 0x94ba89a2 // swapBorrowRateMode(asset:address,interestRateMode:uint256)
        ) {
            addrList = new address[](1);
            valueList = new uint256[](addrList.length);
            addrList[0] = _getAddressFromBytes(data, 0); // asset
            valueList[0] = 0;
            return (addrList, valueList);
        } else if (selector == 0x7a708e92) {
            // initReserve(asset:address,aTokenAddress:address,stableDebtAddress:address,variableDebtAddress:address,interestRateStrategyAddress:address)

            addrList = new address[](5);
            valueList = new uint256[](addrList.length);
            addrList[0] = _getAddressFromBytes(data, 0); // asset
            addrList[1] = _getAddressFromBytes(data, 1); // aTokenAddress
            addrList[2] = _getAddressFromBytes(data, 2); // stableDebtAddress
            addrList[3] = _getAddressFromBytes(data, 3); // variableDebtAddress
            addrList[4] = _getAddressFromBytes(data, 4); // interestRateStrategyAddress

            for (uint256 i = 0; i < addrList.length; i++) {
                valueList[i] = 0;
            }
            return (addrList, valueList);
        } else if (
            selector == 0xd5ed3933 // finalizeTransfer(asset:address,from:address,to:address,amount:uint256,balanceFromBefore:uint256,balanceToBefore:uint256)
        ) {
            addrList = new address[](3);
            valueList = new uint256[](addrList.length);
            addrList[0] = _getAddressFromBytes(data, 0); // asset
            addrList[1] = _getAddressFromBytes(data, 1); // from
            addrList[2] = _getAddressFromBytes(data, 2); // to
            valueList[0] = _getUintFromBytes(data, 3); // amount
            valueList[1] = 0;
            valueList[2] = 0;
            return (addrList, valueList);
        } else if (
            selector == 0xcd112382 // rebalanceStableBorrowRate(asset:address,user:address)
                || selector == 0xcd112382 // setReserveInterestRateStrategyAddress(asset:address,rateStrategyAddress:address)
        ) {
            addrList = new address[](2);
            valueList = new uint256[](addrList.length);
            addrList[0] = _getAddressFromBytes(data, 0); // asset
            addrList[1] = _getAddressFromBytes(data, 1); // user, rateStrategyAddress
            valueList[0] = 0;
            valueList[1] = 0;
            return (addrList, valueList);
        } else if (
            selector == 0xcea9d26f // rescueTokens(token:address,to:address,amount:uint256)
        ) {
            addrList = new address[](2);
            valueList = new uint256[](addrList.length);
            addrList[0] = _getAddressFromBytes(data, 0); // token
            addrList[1] = _getAddressFromBytes(data, 1); // toAddress
            valueList[0] = _getUintFromBytes(data, 2); // amount
            valueList[1] = 0;
            return (addrList, valueList);
        } else if (
            selector == 0x28530a47 // setUserEMode(categoryId:uint8)
                || selector == 0x3036b439 // updateBridgeProtocolFee(protocolFee:uint256)
                || selector == 0xbcb6e522 // updateFlashloanPremiums(flashLoanPremiumTotal:uint128,flashLoanPremiumToProtocol:uint128)
        ) {
            addrList = new address[](1);
            valueList = new uint256[](addrList.length);
            addrList[0] = to; // AAVE Pool
            valueList[0] = 0;
            return (addrList, valueList);
        }
        revert UnsupportedCommand();
    }

    function _getAddressAndAssetId(bytes calldata data, uint256 pos) internal pure returns (address user, uint16 id) {
        /* solhint-disable no-inline-assembly */
        assembly {
            let args := calldataload(add(add(data.offset, shl(5, pos)), 4))
            id := and(args, 0xFFFF)
            user := and(shr(16, args), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        }
    }
}
