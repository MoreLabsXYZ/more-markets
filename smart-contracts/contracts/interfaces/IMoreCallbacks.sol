// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title IMoreLiquidateCallback
/// @notice Interface that liquidators willing to use `liquidate`'s callback must implement.
interface IMoreLiquidateCallback {
    /// @notice Callback called when a liquidation occurs.
    /// @dev The callback is called only if data is not empty.
    /// @param repaidAssets The amount of repaid assets.
    /// @param data Arbitrary data passed to the `liquidate` function.
    function onMoreLiquidate(
        uint256 repaidAssets,
        bytes calldata data
    ) external;
}

/// @title IMoreRepayCallback
/// @notice Interface that users willing to use `repay`'s callback must implement.
interface IMoreRepayCallback {
    /// @notice Callback called when a repayment occurs.
    /// @dev The callback is called only if data is not empty.
    /// @param assets The amount of repaid assets.
    /// @param data Arbitrary data passed to the `repay` function.
    function onMoreRepay(uint256 assets, bytes calldata data) external;
}

/// @title IMoreSupplyCallback
/// @notice Interface that users willing to use `supply`'s callback must implement.
interface IMoreSupplyCallback {
    /// @notice Callback called when a supply occurs.
    /// @dev The callback is called only if data is not empty.
    /// @param assets The amount of supplied assets.
    /// @param data Arbitrary data passed to the `supply` function.
    function onMoreSupply(uint256 assets, bytes calldata data) external;
}

/// @title IMoreSupplyCollateralCallback
/// @notice Interface that users willing to use `supplyCollateral`'s callback must implement.
interface IMoreSupplyCollateralCallback {
    /// @notice Callback called when a supply of collateral occurs.
    /// @dev The callback is called only if data is not empty.
    /// @param assets The amount of supplied collateral.
    /// @param data Arbitrary data passed to the `supplyCollateral` function.
    function onMoreSupplyCollateral(
        uint256 assets,
        bytes calldata data
    ) external;
}

/// @title IMoreFlashLoanCallback
/// @notice Interface that users willing to use `flashLoan`'s callback must implement.
interface IMoreFlashLoanCallback {
    /// @notice Callback called when a flash loan occurs.
    /// @dev The callback is called only if data is not empty.
    /// @param assets The amount of assets that was flash loaned.
    /// @param data Arbitrary data passed to the `flashLoan` function.
    function onMoreFlashLoan(uint256 assets, bytes calldata data) external;
}
