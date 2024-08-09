// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {Id, MarketParams, Market, IMorphoBase, Authorization, Signature} from "@morpho-org/morpho-blue/src/interfaces/IMorpho.sol";

struct Position {
    uint128 supplyShares;
    uint128 borrowShares;
    uint128 collateral;
    uint64 lastMultiplier;
    uint128 debtTokenMissed;
    uint128 debtTokenGained;
}

struct CategoryInfo {
    uint112 multiplier;
    uint16 numberOfSteps;
    uint128 lltv;
}

interface IMoreMarkets is IMorphoBase {
    function position(
        Id id,
        address user
    )
        external
        view
        returns (
            uint128 supplyShares,
            uint128 borrowShares,
            uint128 collateral,
            uint64 lastMultiplier,
            uint128 debtTokenMissed,
            uint128 debtTokenGained
        );

    /// @notice The state of the market corresponding to `id`.
    /// @dev Warning: `totalSupplyAssets` does not contain the accrued interest since the last interest accrual.
    /// @dev Warning: `totalBorrowAssets` does not contain the accrued interest since the last interest accrual.
    /// @dev Warning: `totalSupplyShares` does not contain the accrued shares by `feeRecipient` since the last interest
    /// accrual.
    function market(
        Id id
    )
        external
        view
        returns (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares,
            uint128 totalBorrowAssets,
            uint128 totalBorrowShares,
            uint128 lastUpdate,
            uint128 fee
        );

    /// @notice The market params corresponding to `id`.
    /// @dev This mapping is not used in Morpho. It is there to enable reducing the cost associated to calldata on layer
    /// 2s by creating a wrapper contract with functions that take `id` as input instead of `marketParams`.
    function idToMarketParams(
        Id id
    )
        external
        view
        returns (
            address loanToken,
            address collateralToken,
            address oracle,
            address irm,
            uint256 lltv
        );

    function updateBorrower(
        MarketParams memory marketParams,
        address borrower
    ) external;
}
