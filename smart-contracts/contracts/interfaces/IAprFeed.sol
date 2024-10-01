// SPDX-License-Identifier: GNU General Public License v3.0 (GNU GPLv3)
pragma solidity >=0.5.0;

import {IMoreMarkets, MarketParams, Market, Position, Id} from "./IMoreMarkets.sol";

interface IAprFeed {
    /// @notice Returns the supply rates for the given market. Full supply rate is summary of this two.
    /// @dev To get supply rate for each particular multiplier bucket of the users(includes regular) You need to get borrow rate
    /// from IRM SC, multiply it with SECONDS_PER_YEAR, utilization, 100% - feePercent of the market and weitght of the
    /// multiplier bucket.
    /// @param id The id of particular market.
    /// @return regularSupplyRate supply rate for non premium debt.
    /// @return premiumSupplyRate supply rate for premium debt.
    function getMarketSupplyRate(
        Id id
    )
        external
        view
        returns (uint256 regularSupplyRate, uint256 premiumSupplyRate);

    /// @notice Returns the borrow rate for the given market.
    /// @dev To get borrow rate for each particular it will get borrow rate from IRM SC and multiply it with SECONDS_PER_YEAR.
    /// @param id The id of particular market.
    /// @return borrowRate borrow rate.
    function getBorrowRate(Id id) external view returns (uint256);

    /// @notice Returns the supply rate for the given vault.
    /// @dev To get supply rate of the vault, this function will go through all markets in `withdrawQueue` and
    /// fetch its full supply rate. Then based on the weight of the markets it will return supply rate of the vault.
    /// @param vault The address of the `MoreMarkets` contract.
    /// @return supplyRate supply rate of the vault.
    function getVaultSupplyRate(address vault) external view returns (uint256);
}
