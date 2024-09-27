// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title ErrorsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing error messages.
library ErrorsLib {
    /// @notice Thrown when the LLTV to enable exceeds the maximum LLTV.
    string internal constant MAX_LLTV_EXCEEDED = "max LLTV exceeded";

    /// @notice Thrown when the fee to set exceeds the maximum fee.
    string internal constant MAX_FEE_EXCEEDED = "max fee exceeded";

    /// @notice Thrown when the IRM is not enabled at market creation.
    string internal constant IRM_NOT_ENABLED = "IRM not enabled";

    /// @notice Thrown when the LLTV is not enabled at market creation.
    string internal constant LLTV_NOT_ENABLED = "LLTV not enabled";

    /// @notice Thrown when the market is already created.
    string internal constant MARKET_ALREADY_CREATED = "market already created";

    /// @notice Thrown when a token to transfer doesn't have code.
    string internal constant NO_CODE = "no code";

    /// @notice Thrown when not exactly one of the input amount is zero.
    string internal constant INCONSISTENT_INPUT = "inconsistent input";

    /// @notice Thrown when zero assets is passed as input.
    string internal constant ZERO_ASSETS = "zero assets";

    /// @notice Thrown when a zero address is passed as input.
    string internal constant ZERO_ADDRESS = "zero address";

    /// @notice Thrown when the caller is not authorized to conduct an action.
    string internal constant UNAUTHORIZED = "unauthorized";

    /// @notice Thrown when the liquidity is insufficient to `withdraw` or `borrow`.
    string internal constant INSUFFICIENT_LIQUIDITY = "insufficient liquidity";

    /// @notice Thrown when the position to liquidate is healthy.
    string internal constant HEALTHY_POSITION = "position is healthy";

    /// @notice Thrown when the authorization signature is invalid.
    string internal constant INVALID_SIGNATURE = "invalid signature";

    /// @notice Thrown when the authorization signature is expired.
    string internal constant SIGNATURE_EXPIRED = "signature expired";

    /// @notice Thrown when the nonce is invalid.
    string internal constant INVALID_NONCE = "invalid nonce";

    /// @notice Thrown when a token transfer reverted.
    string internal constant TRANSFER_REVERTED = "transfer reverted";

    /// @notice Thrown when a token transfer returned false.
    string internal constant TRANSFER_RETURNED_FALSE =
        "transfer returned false";

    /// @notice Thrown when a token transferFrom reverted.
    string internal constant TRANSFER_FROM_REVERTED = "transferFrom reverted";

    /// @notice Thrown when a token transferFrom returned false
    string internal constant TRANSFER_FROM_RETURNED_FALSE =
        "transferFrom returned false";

    /// @notice Thrown when the maximum uint128 is exceeded.
    string internal constant MAX_UINT128_EXCEEDED = "max uint128 exceeded";

    /// @notice Thrown when provided categoryLltvs array has invalid length.
    /// @param expectedLength The expected length of the array.
    /// @param providedLength The provided length of the array.
    error InvalidLengthOfCategoriesLltvsArray(
        uint256 expectedLength,
        uint256 providedLength
    );

    /// @notice Thrown when when provided irxMaxValue is not in expected range.
    /// @param maxAvailableValue The maximum allowed value.
    /// @param minAvailableValue The minimum allowed value.
    /// @param providedValue The provided value.
    error InvalidIrxMaxValue(
        uint256 maxAvailableValue,
        uint256 minAvailableValue,
        uint256 providedValue
    );

    /// @notice Thrown when when any of provided categoryLltv values is not in expected range.
    /// @param numberInArray The index of the invalid value in the array.
    /// @param maxAvailableValue The maximum allowed value.
    /// @param minAvailableValue The minimum allowed value.
    /// @param providedValue The provided value.
    error InvalidCategoryLltvValue(
        uint8 numberInArray,
        uint256 maxAvailableValue,
        uint256 minAvailableValue,
        uint256 providedValue
    );

    /// @notice Thrown when the collateral is insufficient to `borrow` or `withdrawCollateral`.
    error InsufficientCollateral();

    /// @notice Thrown when the caller is not the owner.
    error NotOwner();

    /// @notice Thrown when the value is already set.
    error AlreadySet();

    /// @notice Thrown when the market is not created.
    error MarketNotCreated();

    /// @notice Thrown if LLTVs in array not in ascending order.
    error LLTVsNotInAscendingOrder();

    /// @notice Thrown if premium params set for non premium markets.
    error InvalidParamsForNonPremiumMarket();
}
