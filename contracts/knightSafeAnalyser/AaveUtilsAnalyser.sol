// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {BaseKnightSafeAnalyser} from "./BaseKnightSafeAnalyser.sol";
import "../interfaces/IKnightSafeAnalyser.sol";

interface IRewardsDistributor {
    function getUserRewards(address[] calldata assets, address user, address reward) external view returns (uint256);
}

contract AaveUtilsAnalyser is BaseKnightSafeAnalyser {
    address public immutable nativeToken;

    constructor(address nativeToken_) {
        nativeToken = nativeToken_;
    }

    function extractAddressesWithValue(address to, bytes calldata data)
        external
        view
        override
        returns (address[] memory addrList, uint256[] memory valueList)
    {
        bytes4 selector = getSelector(data);

        if (
            selector == 0xeed88b8d // emergencyEtherTransfer(to:address,amount:uint256)
        ) {
            addrList = new address[](2);
            valueList = new uint256[](addrList.length);
            addrList[0] = _getAddressFromBytes(data, 0); // to
            addrList[1] = nativeToken;
            valueList[0] = 0;
            valueList[1] = _getUintFromBytes(data, 1); // amount
            return (addrList, valueList);
        } else if (
            selector == 0xf2fde38b // transferOwnership(newOwner:address)
                || selector == 0x0a036351 // renewAllowance(reserve:address)
                || selector == 0x00ae3bf8 // rescueTokens(token:address)
                || selector == 0xc04a8a10 // approveDelegation(delegatee:address,amount:uint256)
        ) {
            addrList = new address[](1);
            valueList = new uint256[](addrList.length);
            addrList[0] = _getAddressFromBytes(data, 0); //
            valueList[0] = 0;
            return (addrList, valueList);
        } else if (
            selector == 0xa3d5b255 // emergencyTokenTransfer(token:address,to:address,amount:uint256)
        ) {
            addrList = new address[](2);
            valueList = new uint256[](addrList.length);
            addrList[0] = _getAddressFromBytes(data, 0); // token
            addrList[1] = _getAddressFromBytes(data, 1); // to address
            valueList[0] = _getUintFromBytes(data, 2); // amount
            valueList[1] = 0;
            return (addrList, valueList);
        } else if (
            selector == 0x474cf53d // depositETH(:address,onBehalfOf:address,referralCode:uint16)
        ) {
            addrList = new address[](2);
            valueList = new uint256[](addrList.length);
            addrList[0] = nativeToken; // ETH
            addrList[1] = _getAddressFromBytes(data, 1); // onBehalfOf
            valueList[0] = 0; // handled msg.value outside
            valueList[1] = 0;
            return (addrList, valueList);
        } else if (
            selector == 0x80500d20 // withdrawETH(:address,amount:uint256,to:address)
                || selector == 0xd4c40b6c
        ) {
            // withdrawETHWithPermit(:address,amount:uint256,to:address,deadline:uint256,permitV:uint8,permitR:bytes32,permitS:bytes32)
            addrList = new address[](2);
            valueList = new uint256[](addrList.length);
            addrList[0] = nativeToken; // ETH
            addrList[1] = _getAddressFromBytes(data, 2); // to
            valueList[0] = _getUintFromBytes(data, 1); // amount
            valueList[1] = 0;
            return (addrList, valueList);
        } else if (
            selector == 0x02c5fcf8 // repayETH(:address,amount:uint256,rateMode:uint256,onBehalfOf:address)
        ) {
            addrList = new address[](2);
            valueList = new uint256[](addrList.length);
            addrList[0] = nativeToken; // ETH
            addrList[1] = _getAddressFromBytes(data, 3); // onBehalfOf
            valueList[0] = _getUintFromBytes(data, 1); // amount
            valueList[1] = 0;
            return (addrList, valueList);
        } else if (
            selector == 0x66514c97 // borrowETH(:address,amount:uint256,interesRateMode:uint256,referralCode:uint16)
                || selector == 0x715018a6 // renounceOwnership()
        ) {
            addrList = new address[](1);
            valueList = new uint256[](addrList.length);
            addrList[0] = to; // Gateway V3
            valueList[0] = 0;
            return (addrList, valueList);
        } else if (
            selector == 0x236300dc // claimRewards(asset:address[],amount:uint256,to:address,reward:address)
        ) {
            address[] calldata assets = _getAddressArray(data, 0);
            uint256 amount = _getUintFromBytes(data, 1);
            address toAddr = _getAddressFromBytes(data, 2);
            address reward = _getAddressFromBytes(data, 3);
            amount = _mapRewardAmount(to, assets, amount, toAddr, reward);

            addrList = new address[](2);
            valueList = new uint256[](addrList.length);
            addrList[0] = _getAddressFromBytes(data, 3); // reward
            addrList[1] = toAddr;
            valueList[0] = amount; // amount
            valueList[1] = 0;
            return (addrList, valueList);
        }
        revert UnsupportedCommand();
    }

    function _mapRewardAmount(address to, address[] calldata assets, uint256 amount, address toAddr, address reward)
        private
        view
        returns (uint256 totalRewards)
    {
        if (amount == 0) {
            return 0;
        }

        totalRewards = IRewardsDistributor(to).getUserRewards(assets, toAddr, reward);
        if (totalRewards == 0) {
            return 0;
        }

        if (totalRewards > amount) {
            return amount;
        }

        return totalRewards;
    }
}
