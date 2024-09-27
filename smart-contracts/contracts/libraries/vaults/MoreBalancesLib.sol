// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Id, MarketParams, Market, IMoreMarkets} from "../../interfaces/IMoreMarkets.sol";
import {IIrm} from "../../interfaces/IIrm.sol";

import {MoreLib} from "./MoreLib.sol";
import {MarketParamsLib} from "../MarketParamsLib.sol";

import {MathLib, WAD} from "@morpho-org/morpho-blue/src/libraries/MathLib.sol";
import {UtilsLib} from "@morpho-org/morpho-blue/src/libraries/UtilsLib.sol";
import {SharesMathLib} from "@morpho-org/morpho-blue/src/libraries/SharesMathLib.sol";

/// @title MoreBalancesLib
/// @author MORE Labs
/// @notice Helper library exposing getters with the expected value after interest accrual. Fork of the Morpho's library.
/// @dev This library is not used in Morpho itself and is intended to be used by integrators.
/// @dev The getter to retrieve the expected total borrow shares is not exposed because interest accrual does not apply
/// to it. The value can be queried directly on Morpho using `totalBorrowShares`.
library MoreBalancesLib {
    using MathLib for uint256;
    using MathLib for uint128;
    using UtilsLib for uint256;
    using MoreLib for IMoreMarkets;
    using SharesMathLib for uint256;
    using MarketParamsLib for MarketParams;

    /// @notice Returns the expected market balances of a market after having accrued interest.
    /// @return The expected total supply assets.
    /// @return The expected total supply shares.
    /// @return The expected total borrow assets.
    /// @return The expected total borrow shares.
    function expectedMarketBalances(
        IMoreMarkets moreMarkets,
        MarketParams memory marketParams
    ) internal view returns (uint256, uint256, uint256, uint256) {
        Id id = marketParams.id();
        Market memory market = moreMarkets.market(id);

        uint256 elapsed = block.timestamp - market.lastUpdate;

        // Skipped if elapsed == 0 or totalBorrowAssets == 0 because interest would be null, or if irm == address(0).
        if (
            elapsed != 0 &&
            market.totalBorrowAssets != 0 &&
            marketParams.irm != address(0)
        ) {
            uint256 borrowRate = IIrm(marketParams.irm).borrowRateView(
                marketParams,
                market
            );
            uint256 interest = market.totalBorrowAssets.wMulDown(
                borrowRate.wTaylorCompounded(elapsed)
            );
            market.totalBorrowAssets += interest.toUint128();
            market.totalSupplyAssets += interest.toUint128();

            if (market.fee != 0) {
                uint256 feeAmount = interest.wMulDown(market.fee);
                // The fee amount is subtracted from the total supply in this calculation to compensate for the fact
                // that total supply is already updated.
                uint256 feeShares = feeAmount.toSharesDown(
                    market.totalSupplyAssets - feeAmount,
                    market.totalSupplyShares
                );
                market.totalSupplyShares += feeShares.toUint128();
            }
        }

        return (
            market.totalSupplyAssets,
            market.totalSupplyShares,
            market.totalBorrowAssets,
            market.totalBorrowShares
        );
    }

    /// @notice Returns the expected total supply assets of a market after having accrued interest.
    function expectedTotalSupplyAssets(
        IMoreMarkets moreMarkets,
        MarketParams memory marketParams
    ) internal view returns (uint256 totalSupplyAssets) {
        (totalSupplyAssets, , , ) = expectedMarketBalances(
            moreMarkets,
            marketParams
        );
    }

    /// @notice Returns the expected total borrow assets of a market after having accrued interest.
    function expectedTotalBorrowAssets(
        IMoreMarkets moreMarkets,
        MarketParams memory marketParams
    ) internal view returns (uint256 totalBorrowAssets) {
        (, , totalBorrowAssets, ) = expectedMarketBalances(
            moreMarkets,
            marketParams
        );
    }

    /// @notice Returns the expected total supply shares of a market after having accrued interest.
    function expectedTotalSupplyShares(
        IMoreMarkets moreMarkets,
        MarketParams memory marketParams
    ) internal view returns (uint256 totalSupplyShares) {
        (, totalSupplyShares, , ) = expectedMarketBalances(
            moreMarkets,
            marketParams
        );
    }

    /// @notice Returns the expected supply assets balance of `user` on a market after having accrued interest.
    /// @dev Warning: Wrong for `feeRecipient` because their supply shares increase is not taken into account.
    /// @dev Warning: Withdrawing using the expected supply assets can lead to a revert due to conversion roundings from
    /// assets to shares.
    function expectedSupplyAssets(
        IMoreMarkets moreMarkets,
        MarketParams memory marketParams,
        address user
    ) internal view returns (uint256) {
        Id id = marketParams.id();
        uint256 supplyShares = moreMarkets.supplyShares(id, user);
        (
            uint256 totalSupplyAssets,
            uint256 totalSupplyShares,
            ,

        ) = expectedMarketBalances(moreMarkets, marketParams);

        return supplyShares.toAssetsDown(totalSupplyAssets, totalSupplyShares);
    }

    /// @notice Returns the expected borrow assets balance of `user` on a market after having accrued interest.
    /// @dev Warning: The expected balance is rounded up, so it may be greater than the market's expected total borrow
    /// assets.
    function expectedBorrowAssets(
        IMoreMarkets moreMarkets,
        MarketParams memory marketParams,
        address user
    ) internal view returns (uint256) {
        Id id = marketParams.id();
        uint256 borrowShares = moreMarkets.borrowShares(id, user);
        (
            ,
            ,
            uint256 totalBorrowAssets,
            uint256 totalBorrowShares
        ) = expectedMarketBalances(moreMarkets, marketParams);

        return borrowShares.toAssetsUp(totalBorrowAssets, totalBorrowShares);
    }
}
