// SPDX-License-Identifier: GNU General Public License v3.0 (GNU GPLv3)
pragma solidity ^0.8.19;

import {BaseBundler} from "./bundlers/BaseBundler.sol";
import {TransferBundler} from "./bundlers/TransferBundler.sol";
import {MorphoBundler} from "./bundlers/MorphoBundler.sol";
import {PermitBundler} from "./bundlers/PermitBundler.sol";
import {Permit2Bundler} from "./bundlers/Permit2Bundler.sol";
import {ERC4626Bundler} from "./bundlers/ERC4626Bundler.sol";
import {WNativeBundler} from "./bundlers/WNativeBundler.sol";
import {ERC20WrapperBundler} from "./bundlers/ERC20WrapperBundler.sol";

/// @title MoreBundler
/// @notice Bundler contract specific to MoreMarkets.
contract MoreBundler is
    TransferBundler,
    PermitBundler,
    Permit2Bundler,
    ERC4626Bundler,
    MorphoBundler,
    ERC20WrapperBundler,
    WNativeBundler
{
    /* CONSTRUCTOR */

    constructor(
        address morpho,
        address wNative
    ) MorphoBundler(morpho) WNativeBundler(wNative) {}

    /* INTERNAL */

    /// @inheritdoc BaseBundler
    function _isSenderAuthorized()
        internal
        view
        override(BaseBundler, MorphoBundler)
        returns (bool)
    {
        return BaseBundler._isSenderAuthorized();
    }
}
