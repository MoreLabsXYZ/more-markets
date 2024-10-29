// SPDX-License-Identifier: GNU General Public License v3.0 (GNU GPLv3)
pragma solidity >=0.5.0;

import {IERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC4626Upgradeable.sol";
import {IOwnable} from "./IMoreVaults.sol";
import {Id} from "./IMoreMarkets.sol";

/// @title ILoopStrategy
/// @author MORE Labs
/// @dev Use this interface for LoopStrategy.
interface ILoopStrategy is IERC4626Upgradeable, IOwnable {
    function initialize(
        address owner,
        address moreMarkets,
        address _vault,
        address _staking,
        address _asset,
        address _ankrFlow,
        Id _marketId,
        uint256 _targetUtilization,
        uint256 _targetStrategyLtv,
        string memory _name,
        string memory _symbol
    ) external;

    function expectedAmountsToWithdraw(
        uint256 assets
    )
        external
        view
        returns (
            uint256 amountToRepay,
            uint256 wFlowAmount,
            uint256 ankrFlowAmount
        );
}
