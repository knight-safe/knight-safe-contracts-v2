// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title Helpers library
 */
library AaveHelpers {
    /**
     * @notice Fetches the user current stable and variable debt balances
     * @param user The user address
     * @param reserve The reserve data object
     * @return The stable debt balance
     * @return The variable debt balance
     */
    function getUserCurrentDebt(address user, IAavePoolV3.ReserveData memory reserve)
        internal
        view
        returns (uint256, uint256)
    {
        return (
            IAToken(reserve.stableDebtTokenAddress).balanceOf(user),
            IAToken(reserve.variableDebtTokenAddress).balanceOf(user)
        );
    }

    /**
     * @notice Decodes compressed repay params to standard params
     * @param args The packed repay params
     * @param to Contract to call
     * @return The address of the underlying reserve
     * @return The amount to repay
     * @return The interestRateMode, 1 for stable or 2 for variable debt
     */
    function decodeL2RepayParams(bytes32 args, address to) internal view returns (address, uint256, uint256) {
        uint16 assetId;
        uint256 amount;
        uint256 interestRateMode;

        assembly {
            assetId := and(args, 0xFFFF)
            amount := and(shr(16, args), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            interestRateMode := and(shr(144, args), 0xFF)
        }

        if (amount == type(uint128).max) {
            amount = type(uint256).max;
        }
        address assets = getAddressByAssetId(to, assetId);
        return (assets, amount, interestRateMode);
    }

    function mapRepayAmount(address asset, uint256 amount, address to, bool useAToken, uint256 interestRateMode)
        internal
        view
        returns (uint256)
    {
        address user = msg.sender;
        IAavePoolV3.ReserveData memory reserve = IAavePoolV3(to).getReserveData(asset);

        uint256 stableDebt = IAToken(reserve.stableDebtTokenAddress).balanceOf(user);
        uint256 variableDebt = IAToken(reserve.variableDebtTokenAddress).balanceOf(user);
        IAavePoolV3.InterestRateMode mode = IAavePoolV3.InterestRateMode(interestRateMode);

        uint256 paybackAmount = mode == IAavePoolV3.InterestRateMode.STABLE ? stableDebt : variableDebt;

        if (useAToken && amount == type(uint256).max) {
            amount = IAToken(reserve.aTokenAddress).balanceOf(user);
        }

        if (amount < paybackAmount) {
            paybackAmount = amount;
        }

        return paybackAmount;
    }

    function mapWithdrawAmount(address asset, uint256 amount, address to) internal view returns (uint256) {
        uint256 halfRay = 0.5e27; // magicValue from aave
        uint256 ray = 1e27; // magicValue from aave

        IAavePoolV3.ReserveData memory reserve = IAavePoolV3(to).getReserveData(asset);

        uint256 a = IAToken(reserve.aTokenAddress).scaledBalanceOf(msg.sender);
        uint256 b = reserve.liquidityIndex;

        uint256 userBalance;
        assembly {
            if iszero(or(iszero(b), iszero(gt(a, div(sub(not(0), halfRay), b))))) { revert(0, 0) }

            userBalance := div(add(mul(a, b), halfRay), ray)
        }
        uint256 amountToWithdraw = amount;

        if (amount == type(uint256).max) {
            amountToWithdraw = userBalance;
        }

        return amountToWithdraw;
    }

    function getAssetId(bytes calldata data, uint256 pos) internal pure returns (uint16 id) {
        /* solhint-disable no-inline-assembly */
        assembly {
            let args := calldataload(add(add(data.offset, shl(5, pos)), 4))
            id := and(args, 0xFFFF)
        }
    }

    function getAmount(bytes calldata data, uint256 pos) internal pure returns (uint256 amount) {
        /* solhint-disable no-inline-assembly */
        assembly {
            let args := calldataload(add(add(data.offset, shl(5, pos)), 4))
            amount := and(shr(16, args), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        }
        if (amount == type(uint128).max) {
            amount = type(uint256).max; // handle max amount,
        }
        return (amount);
    }

    function getAddressByAssetId(address to, uint16 assetId) internal view returns (address) {
        return IAavePoolV3(to).getReserveAddressById(assetId);
    }
}

interface IAavePoolV3 {
    enum InterestRateMode {
        NONE,
        STABLE,
        VARIABLE
    }

    struct ReserveConfigurationMap {
        uint256 data;
    }

    struct ReserveData {
        //stores the reserve configuration
        ReserveConfigurationMap configuration;
        //the liquidity index. Expressed in ray
        uint128 liquidityIndex;
        //the current supply rate. Expressed in ray
        uint128 currentLiquidityRate;
        //variable borrow index. Expressed in ray
        uint128 variableBorrowIndex;
        //the current variable borrow rate. Expressed in ray
        uint128 currentVariableBorrowRate;
        //the current stable borrow rate. Expressed in ray
        uint128 currentStableBorrowRate;
        //timestamp of last update
        uint40 lastUpdateTimestamp;
        //the id of the reserve. Represents the position in the list of the active reserves
        uint16 id;
        //aToken address
        address aTokenAddress;
        //stableDebtToken address
        address stableDebtTokenAddress;
        //variableDebtToken address
        address variableDebtTokenAddress;
        //address of the interest rate strategy
        address interestRateStrategyAddress;
        //the current treasury balance, scaled
        uint128 accruedToTreasury;
        //the outstanding unbacked aTokens minted through the bridging feature
        uint128 unbacked;
        //the outstanding debt borrowed against this asset in isolation mode
        uint128 isolationModeTotalDebt;
    }

    function getReserveAddressById(uint16 id) external view returns (address);
    function getReserveData(address asset) external view returns (ReserveData memory);
}

interface IAToken {
    function scaledBalanceOf(address user) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}
