// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title ConstantsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing constants.
library ConstantsLib {
    /// @dev The maximum delay of a timelock.
    uint256 internal constant MAX_TIMELOCK = 2 weeks;

    /// @dev The minimum delay of a timelock.
    uint256 internal constant MIN_TIMELOCK = 1 days;

    /// @dev The maximum number of markets in the supply/withdraw queue.
    uint256 internal constant MAX_QUEUE_LENGTH = 30;

    /// @dev The maximum fee the vault can have (50%).
    uint256 internal constant MAX_FEE = 0.5e18;

    /// @notice Curve steepness (scaled by WAD).
    /// @dev Curve steepness = 4.
    int256 public constant CURVE_STEEPNESS = 4 ether;

    /// @notice Adjustment speed per second (scaled by WAD).
    /// @dev The speed is per second, so the rate moves at a speed of ADJUSTMENT_SPEED * err each second (while being
    /// continuously compounded).
    /// @dev Adjustment speed = 50/year.
    int256 public constant ADJUSTMENT_SPEED = 50 ether / int256(365 days);

    /// @notice Target utilization (scaled by WAD).
    /// @dev Target utilization = 90%.
    int256 public constant TARGET_UTILIZATION = 0.9 ether;

    /// @notice Initial rate at target per second (scaled by WAD).
    /// @dev Initial rate at target = 4% (rate between 1% and 16%).
    int256 public constant INITIAL_RATE_AT_TARGET =
        0.04 ether / int256(365 days);

    /// @notice Minimum rate at target per second (scaled by WAD).
    /// @dev Minimum rate at target = 0.1% (minimum rate = 0.025%).
    int256 public constant MIN_RATE_AT_TARGET = 0.001 ether / int256(365 days);

    /// @notice Maximum rate at target per second (scaled by WAD).
    /// @dev Maximum rate at target = 200% (maximum rate = 800%).
    int256 public constant MAX_RATE_AT_TARGET = 2.0 ether / int256(365 days);

    /// @dev The default value of the initiator of the multicall transaction is not the address zero to save gas.
    address constant UNSET_INITIATOR = address(1);
}
