// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {IMoreMarkets, Market, Id, MarketParams, Position} from "./IMoreMarkets.sol";
import {IMoreVaults} from "./interfaces/IMoreVaults.sol";
import {ILiquidTokenStakingPool} from "./interfaces/ILiquidTokenStakingPool.sol";
import {ICertificateToken} from "./interfaces/ankr/ICertificateToken.sol";

import {MathLib, SharesMathLib, WAD} from "./fork/Morpho.sol";
import {MathLib as IrmMathLib} from "./libraries/irm/MathLib.sol";

import {MulticallUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable, OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {IERC4626Upgradeable, ERC4626Upgradeable, MathUpgradeable, SafeERC20Upgradeable, IERC20Upgradeable, ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import {IInternetBondRatioFeed} from "./interfaces/oracle/IInternetBondRatioFeed.sol";
import {IWNative} from "./interfaces/bundlers/IWNative.sol";

contract LoopStrategy is
    ERC4626Upgradeable,
    ERC20PermitUpgradeable,
    Ownable2StepUpgradeable,
    MulticallUpgradeable
{
    using MathLib for uint128;
    using MathLib for uint256;
    using IrmMathLib for int256;
    using SharesMathLib for uint256;

    IMoreMarkets public markets;
    ILiquidTokenStakingPool public staking;
    IMoreVaults public vault;
    Id public marketId;
    address public ankrFlow;
    address public wFlow;

    uint256 public targetUtilization;
    uint256 public targetStrategyLtv;

    error TargetUtilizationReached();

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
    ) external initializer {
        __ERC4626_init(IERC20Upgradeable(_asset));
        __ERC20Permit_init(_name);
        __ERC20_init(_name, _symbol);
        __Ownable_init();
        _transferOwnership(owner);

        markets = IMoreMarkets(moreMarkets);
        staking = ILiquidTokenStakingPool(_staking);
        vault = IMoreVaults(_vault);
        ankrFlow = _ankrFlow;
        wFlow = _asset;
        marketId = _marketId;
        targetUtilization = _targetUtilization;
        targetStrategyLtv = _targetStrategyLtv;

        IWNative(wFlow).approve(address(vault), type(uint256).max);
        ICertificateToken(ankrFlow).approve(
            address(markets),
            type(uint256).max
        );
    }

    /// @inheritdoc IERC20MetadataUpgradeable
    function decimals()
        public
        view
        override(ERC20Upgradeable, ERC4626Upgradeable)
        returns (uint8)
    {
        return ERC4626Upgradeable.decimals();
    }

    function asset()
        public
        view
        override(ERC4626Upgradeable)
        returns (address)
    {
        return wFlow;
    }

    function totalAssets()
        public
        view
        override(ERC4626Upgradeable)
        returns (uint256)
    {
        Position memory position = markets.position(marketId, address(this));
        uint256 totalBorrowSharesForMultiplier = markets
            .totalBorrowSharesForMultiplier(marketId, position.lastMultiplier);
        uint256 totalBorrowAssetsForMultiplier = markets
            .totalBorrowAssetsForMultiplier(marketId, position.lastMultiplier);

        uint256 borrowedAssets = position.borrowShares > 0
            ? uint256(position.borrowShares).toAssetsUp(
                totalBorrowAssetsForMultiplier,
                totalBorrowSharesForMultiplier
            )
            : 0;

        // total assets = vault balance in wFLOW + collateral balance in wFLOW - borrowed assets
        uint256 _totalAssets = vault.convertToAssets(
            vault.balanceOf(address(this))
        ) +
            ICertificateToken(ankrFlow).sharesToBonds(position.collateral) -
            borrowedAssets;

        return _totalAssets;
    }

    receive() external payable {}

    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal override {
        (
            bool isPrem,
            address loanToken,
            address collateralToken,
            address oracle,
            address irm,
            uint256 lltv,
            address cas,
            uint96 irxMaxLltv,
            uint256[] memory lltvsFromContract
        ) = markets.idToMarketParams(marketId);
        MarketParams memory marketParams = MarketParams(
            isPrem,
            loanToken,
            collateralToken,
            oracle,
            irm,
            lltv,
            cas,
            irxMaxLltv,
            lltvsFromContract
        );

        SafeERC20Upgradeable.safeTransferFrom(
            IERC20Upgradeable(asset()),
            caller,
            address(this),
            assets
        );

        // calculating amount of deposit in ankrFlow
        uint256 depositAmountInAnkrFlow = ICertificateToken(ankrFlow)
            .bondsToShares(assets);
        // calculating how much we should provide as collateral in ankrFlow
        uint256 toSupplyAsCollateral = depositAmountInAnkrFlow
            .wMulDown(100 * 1e18)
            .wDivDown(100 * 1e18 + (targetStrategyLtv.wMulDown(100 * 1e18)))
            .wMulDown(100 * 1e18)
            .wDivDown(100 * 1e18) - 1;
        // calcaulating how much should be provided as supply to the vault in FLOW
        uint256 toSupply = ICertificateToken(ankrFlow).sharesToBonds(
            toSupplyAsCollateral.wMulDown(targetStrategyLtv)
        );

        vault.deposit(toSupply, address(this));

        // calculating how much we should provide as collateral in FLOW
        uint256 toSupplyAsCollateralInFlow = assets - toSupply;
        IWNative(wFlow).withdraw(toSupplyAsCollateralInFlow);
        staking.stakeCerts{value: toSupplyAsCollateralInFlow}();

        markets.supplyCollateral(
            marketParams,
            toSupplyAsCollateral,
            address(this),
            ""
        );

        (uint256 borrowedAssets, ) = markets.borrow(
            marketParams,
            toSupply,
            0,
            address(this),
            address(this)
        );

        uint256 currentBorrow = borrowedAssets;

        IWNative(wFlow).withdraw(currentBorrow);
        staking.stakeCerts{value: currentBorrow}();

        uint256 newCollateral = ICertificateToken(ankrFlow).bondsToShares(
            currentBorrow
        );

        markets.supplyCollateral(
            marketParams,
            newCollateral,
            address(this),
            ""
        );

        Market memory market = markets.market(marketId);
        uint256 utilization = uint256(
            market.totalSupplyAssets > 0
                ? (market.totalBorrowAssets).wDivDown(market.totalSupplyAssets)
                : 0
        );
        if (utilization > targetUtilization) revert TargetUtilizationReached();

        uint256 lastCollateral = newCollateral;

        uint256 maxIterates = 10;
        uint256 i;
        while (utilization < targetUtilization) {
            if (i >= maxIterates) break;

            uint256 newAmountToBorrowInFlow = ICertificateToken(ankrFlow)
                .sharesToBonds(lastCollateral.wMulDown(targetStrategyLtv));

            uint256 newUtilization = uint256(
                market.totalSupplyAssets > 0
                    ? (market.totalBorrowAssets + newAmountToBorrowInFlow)
                        .wDivDown(market.totalSupplyAssets)
                    : 0
            );

            if (newUtilization < targetUtilization) {
                (borrowedAssets, ) = markets.borrow(
                    marketParams,
                    newAmountToBorrowInFlow,
                    0,
                    address(this),
                    address(this)
                );
            } else {
                if (
                    market.totalSupplyAssets.wMulDown(targetUtilization) !=
                    market.totalBorrowAssets
                ) {
                    (borrowedAssets, ) = markets.borrow(
                        marketParams,
                        market.totalSupplyAssets.wMulDown(targetUtilization) -
                            market.totalBorrowAssets,
                        0,
                        address(this),
                        address(this)
                    );
                } else break;
            }

            IWNative(wFlow).withdraw(borrowedAssets);
            staking.stakeCerts{value: borrowedAssets}();

            lastCollateral = ICertificateToken(ankrFlow).bondsToShares(
                borrowedAssets
            );

            markets.supplyCollateral(
                marketParams,
                lastCollateral,
                address(this),
                ""
            );

            market = markets.market(marketId);
            utilization = uint256(
                market.totalSupplyAssets > 0
                    ? market.totalBorrowAssets.wDivDown(
                        market.totalSupplyAssets
                    )
                    : 0
            );
            unchecked {
                ++i;
            }
        }

        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override(ERC4626Upgradeable) {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        _burn(owner, shares);

        (
            bool isPrem,
            address loanToken,
            address collateralToken,
            address oracle,
            address irm,
            uint256 lltv,
            address cas,
            uint96 irxMaxLltv,
            uint256[] memory lltvsFromContract
        ) = markets.idToMarketParams(marketId);
        MarketParams memory marketParams = MarketParams(
            isPrem,
            loanToken,
            collateralToken,
            oracle,
            irm,
            lltv,
            cas,
            irxMaxLltv,
            lltvsFromContract
        );

        uint256 percentage = assets.wDivDown(totalAssets());

        markets.accrueInterest(marketParams);

        Position memory position = markets.position(marketId, address(this));
        uint256 collateralToWithdraw = position.collateral.wMulDown(percentage);
        uint256 sharesToRepay = position.borrowShares.wMulDown(percentage);

        uint256 totalBorrowSharesForMultiplier = markets
            .totalBorrowSharesForMultiplier(marketId, position.lastMultiplier);
        uint256 totalBorrowAssetsForMultiplier = markets
            .totalBorrowAssetsForMultiplier(marketId, position.lastMultiplier);

        uint256 assetsToRepay = sharesToRepay.toAssetsUp(
            totalBorrowAssetsForMultiplier,
            totalBorrowSharesForMultiplier
        );

        SafeERC20Upgradeable.safeTransferFrom(
            IERC20Upgradeable(asset()),
            caller,
            address(this),
            assetsToRepay
        );

        IWNative(wFlow).approve(address(markets), assetsToRepay);
        markets.repay(marketParams, 0, sharesToRepay, address(this), "");
        markets.withdrawCollateral(
            marketParams,
            collateralToWithdraw,
            address(this),
            receiver
        );

        uint256 sharesToWithdraw = vault.balanceOf(address(this)).wMulDown(
            percentage
        );

        vault.redeem(sharesToWithdraw, receiver, address(this));

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    /// @notice Calculates the expected amount to repay the loan debt corresponding to the `assets`
    /// value provided, and calculates and returns the amount of `wFlow` and `ankrFlow` to be received.
    /// @param assets The amount of assets to withdraw.
    /// @return amountToRepay The amount of debt to repay.
    /// @return wFlowAmount The amount of `wFlow` to receive.
    /// @return ankrFlowAmount The amount of `ankrFlow` to receive.
    function expectedAmountsToWithdraw(
        uint256 assets
    )
        external
        view
        returns (
            uint256 amountToRepay,
            uint256 wFlowAmount,
            uint256 ankrFlowAmount
        )
    {
        uint256 percentage = assets.wDivDown(totalAssets());

        Position memory position = markets.position(marketId, address(this));
        ankrFlowAmount = position.collateral.wMulDown(percentage);
        uint256 sharesToRepay = position.borrowShares.wMulDown(percentage);

        uint256 totalBorrowSharesForMultiplier = markets
            .totalBorrowSharesForMultiplier(marketId, position.lastMultiplier);
        uint256 totalBorrowAssetsForMultiplier = markets
            .totalBorrowAssetsForMultiplier(marketId, position.lastMultiplier);

        amountToRepay = sharesToRepay.toAssetsUp(
            totalBorrowAssetsForMultiplier,
            totalBorrowSharesForMultiplier
        );

        uint256 sharesToWithdraw = vault.balanceOf(address(this)).wMulDown(
            percentage
        );
        wFlowAmount = vault.previewRedeem(sharesToWithdraw);
    }
}
