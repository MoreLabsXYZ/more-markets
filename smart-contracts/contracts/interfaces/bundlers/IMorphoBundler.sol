// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IMoreLiquidateCallback, IMoreRepayCallback, IMoreSupplyCallback, IMoreSupplyCollateralCallback, IMoreFlashLoanCallback} from "../IMoreCallbacks.sol";

/// @title IMorphoBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Interface of MorphoBundler.
interface IMorphoBundler is
    IMoreSupplyCallback,
    IMoreRepayCallback,
    IMoreSupplyCollateralCallback,
    IMoreFlashLoanCallback
{}
