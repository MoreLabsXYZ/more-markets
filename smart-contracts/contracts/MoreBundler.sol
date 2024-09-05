// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import {MoreMulticall} from "./bundlers/MoreMulticall.sol";
import {TransferBundler} from "./bundlers/TransferBundler.sol";
import {BaseBundler} from "./bundlers/BaseBundler.sol";

/// @title MoreBundler
/// @notice Bundler contract specific to MoreMarkets.
contract MoreBundler is TransferBundler, BaseBundler {
    /* CONSTRUCTOR */

    constructor(address morpho) BaseBundler(morpho) {}

    /* INTERNAL */

    /// @inheritdoc BaseBundler
    function _isSenderAuthorized()
        internal
        view
        override(MoreMulticall, BaseBundler)
        returns (bool)
    {
        return BaseBundler._isSenderAuthorized();
    }
}
