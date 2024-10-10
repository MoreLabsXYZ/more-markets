// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Id, MarketParams} from "../interfaces/IMoreMarkets.sol";

/// @title MarketParamsLib
/// @author MORE Labs
/// @notice Library to convert a market to its id. Fork of the Morpho's library.
library MarketParamsLib {
    /// @notice Returns the id of the market `marketParams`.
    function id(
        MarketParams memory marketParams
    ) internal pure returns (Id marketParamsId) {
        marketParamsId = Id.wrap(keccak256(abi.encode(marketParams)));
    }
}
