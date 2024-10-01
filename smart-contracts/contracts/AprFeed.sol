// SPDX-License-Identifier: GNU General Public License v3.0 (GNU GPLv3)
pragma solidity ^0.8.19;

import {IMoreMarkets, MarketParams, Market, Position, Id} from "./interfaces/IMoreMarkets.sol";
import {MarketParamsLib} from "./libraries/MarketParamsLib.sol";
import {MathLib, WAD, SharesMathLib} from "./fork/Morpho.sol";
import {IIrm} from "./interfaces/IIrm.sol";
import {IMoreVaults} from "./interfaces/IMoreVaults.sol";
import {IAprFeed} from "./interfaces/IAprFeed.sol";

/// @title AprFeed
/// @author MORE Labs
/// @notice APR Feed implementation. Calculates the APR of the particular market.
/// @dev This contract is not used in Morpho itself and is intended to be used by integrators.

contract AprFeed is IAprFeed {
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;
    using MathLib for uint256;
    using MathLib for uint128;

    uint256 public constant SECONDS_PER_YEAR = 31536000;
    uint64 public constant REGULAR_MULTIPLIER = 1e18;
    IMoreMarkets public immutable moreMarkets;

    constructor(address moreMarketsAddress) {
        moreMarkets = IMoreMarkets(moreMarketsAddress);
    }

    /// @inheritdoc IAprFeed
    function getMarketSupplyRate(
        Id id
    )
        public
        view
        returns (uint256 regularSupplyRate, uint256 premiumSupplyRate)
    {
        MarketParams memory marketParams;
        (
            marketParams.isPremiumMarket,
            marketParams.loanToken,
            marketParams.collateralToken,
            marketParams.oracle,
            marketParams.irm,
            marketParams.lltv,
            marketParams.creditAttestationService,
            marketParams.irxMaxLltv,
            marketParams.categoryLltv
        ) = moreMarkets.idToMarketParams(id);

        uint256[] memory arrayOfMultipliers = moreMarkets.availableMultipliers(
            id
        );

        Market memory market = moreMarkets.market(id);

        uint256 borrowRate = IIrm(marketParams.irm).borrowRateView(
            marketParams,
            market
        );

        if (market.totalBorrowAssets == 0 || market.totalSupplyAssets == 0) {
            return (0, 0);
        }
        uint256 utilization = market.totalBorrowAssets.wDivDown(
            market.totalSupplyAssets
        );

        uint256 excludingFee = WAD - market.fee;

        regularSupplyRate = _getSupplyRateForMultiplier(
            moreMarkets,
            id,
            market,
            borrowRate,
            REGULAR_MULTIPLIER,
            utilization,
            excludingFee
        );

        for (uint256 i; i < arrayOfMultipliers.length; ) {
            if (
                arrayOfMultipliers[i] == REGULAR_MULTIPLIER ||
                moreMarkets.totalBorrowAssetsForMultiplier(
                    id,
                    uint64(arrayOfMultipliers[i])
                ) ==
                0
            ) {
                unchecked {
                    ++i;
                }
                continue;
            }

            premiumSupplyRate += _getSupplyRateForMultiplier(
                moreMarkets,
                id,
                market,
                borrowRate,
                arrayOfMultipliers[i],
                utilization,
                excludingFee
            );

            unchecked {
                ++i;
            }
        }

        return (regularSupplyRate, premiumSupplyRate);
    }

    /// @inheritdoc IAprFeed
    function getBorrowRate(Id id) external view returns (uint256) {
        MarketParams memory marketParams;
        (
            marketParams.isPremiumMarket,
            marketParams.loanToken,
            marketParams.collateralToken,
            marketParams.oracle,
            marketParams.irm,
            marketParams.lltv,
            marketParams.creditAttestationService,
            marketParams.irxMaxLltv,
            marketParams.categoryLltv
        ) = moreMarkets.idToMarketParams(id);
        Market memory market = moreMarkets.market(id);
        uint256 borrowRate = IIrm(marketParams.irm).borrowRateView(
            marketParams,
            market
        );

        return borrowRate * SECONDS_PER_YEAR;
    }

    /// @inheritdoc IAprFeed
    function getVaultSupplyRate(address vault) external view returns (uint256) {
        IMoreVaults vaults = IMoreVaults(vault);
        uint256 withdrawQuereLength = vaults.withdrawQueueLength();

        IMoreMarkets _moreMarkets = IMoreMarkets(vaults.MORE_MARKETS());
        if (moreMarkets != _moreMarkets) {
            revert("incorrect vault");
        }

        uint256 accumulator;
        uint256 totalDeposits;
        for (uint256 i; i < withdrawQuereLength; ) {
            Id id = vaults.withdrawQueue(i);

            (uint256 regularRate, uint256 premiumRate) = getMarketSupplyRate(
                id
            );
            uint256 fullMarketRate = regularRate + premiumRate;

            Market memory market = _moreMarkets.market(id);
            Position memory vaultPosition = _moreMarkets.position(id, vault);

            uint256 totalAssets = uint256(vaultPosition.supplyShares)
                .toAssetsDown(
                    market.totalSupplyAssets,
                    market.totalSupplyShares
                );

            accumulator += fullMarketRate.wMulDown(totalAssets);
            totalDeposits += totalAssets;

            unchecked {
                ++i;
            }
        }
        if (totalDeposits == 0) {
            return 0;
        }
        return accumulator.wDivDown(totalDeposits);
    }

    function _getSupplyRateForMultiplier(
        IMoreMarkets _moreMarkets,
        Id id,
        Market memory market,
        uint256 borrowRate,
        uint256 multiplier,
        uint256 utilization,
        uint256 excludingFee
    ) internal view returns (uint256) {
        uint256 weightOfMultiplier = _moreMarkets
            .totalBorrowAssetsForMultiplier(id, uint64(multiplier))
            .wDivDown(market.totalBorrowAssets);

        return
            (borrowRate * SECONDS_PER_YEAR)
                .wMulDown(weightOfMultiplier)
                .wMulDown(utilization)
                .wMulDown(excludingFee);
    }
}
