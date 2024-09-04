// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import {Multicall} from "./bundlers/Multicall.sol";
import {TransferBundler} from "./bundlers/TransferBundler.sol";
import {BaseBundler} from "./bundlers/BaseBundler.sol";

/// @title EthereumBundlerV2
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Bundler contract specific to Ethereum.
contract EthereumBundlerV2 is TransferBundler, BaseBundler {
    /* CONSTRUCTOR */

    constructor(address morpho) BaseBundler(morpho) {}

    /* INTERNAL */

    /// @inheritdoc BaseBundler
    function _isSenderAuthorized()
        internal
        view
        override(Multicall, BaseBundler)
        returns (bool)
    {
        return BaseBundler._isSenderAuthorized();
    }
}
