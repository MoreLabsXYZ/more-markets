// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IMoreMarketsStaticTyping, Position, CategoryInfo, MarketParams, Market, Id, Authorization, Signature, IMoreMarketsBase} from "./interfaces/IMoreMarkets.sol";
import {IIrm} from "./interfaces/IIrm.sol";
import {MathLib, UtilsLib, SharesMathLib, SafeTransferLib, IERC20, IOracle, WAD} from "./fork/Morpho.sol";
import {IMorphoLiquidateCallback, IMorphoRepayCallback, IMorphoSupplyCallback, IMorphoSupplyCollateralCallback, IMorphoFlashLoanCallback} from "@morpho-org/morpho-blue/src/interfaces/IMorphoCallbacks.sol";
import "@morpho-org/morpho-blue/src/libraries/ConstantsLib.sol";
import {ErrorsLib} from "./libraries/markets/ErrorsLib.sol";
import {EventsLib} from "./libraries/markets/EventsLib.sol";
import {MarketParamsLib} from "./libraries/MarketParamsLib.sol";
import {ICreditAttestationService} from "./interfaces/ICreditAttestationService.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IDebtTokenFactory} from "./interfaces/factories/IDebtTokenFactory.sol";
import {IDebtToken} from "./interfaces/tokens/IDebtToken.sol";
import "hardhat/console.sol";

/// @title MoreMarkets
/// @author MoreMarkets
/// @notice The More Markets contract fork of Morpho-blue contract with additional feature to make premium users to borrow with a higher LLTV.
/// It is possible to make undercollateralized borrows if contract is set to.
contract MoreMarkets is IMoreMarketsStaticTyping {
    using MathLib for uint128;
    using MathLib for uint256;
    using UtilsLib for uint256;
    using SharesMathLib for uint256;
    using SafeTransferLib for IERC20;
    using MarketParamsLib for MarketParams;
    using EnumerableSet for EnumerableSet.UintSet;

    /* IMMUTABLES */

    enum UPDATE_TYPE {
        BORROW,
        REPAY,
        IDLE
    }

    /// @inheritdoc IMoreMarketsBase
    bytes32 public immutable DOMAIN_SEPARATOR;
    /// Number of categories for attestation service score. 0-199 score is 1st category, 200-399 score is 2nd category, etc
    uint256 constant LENGTH_OF_CATEGORY_LLTVS_ARRAY = 5;

    /* STORAGE */

    /// @inheritdoc IMoreMarketsBase
    address public owner;
    /// @inheritdoc IMoreMarketsBase
    address public feeRecipient;
    /// @inheritdoc IMoreMarketsStaticTyping
    mapping(Id => mapping(address => Position)) public position;
    /// @inheritdoc IMoreMarketsStaticTyping
    mapping(Id => Market) public market;
    /// @inheritdoc IMoreMarketsBase
    mapping(address => bool) public isIrmEnabled;
    /// @inheritdoc IMoreMarketsBase
    mapping(uint256 => bool) public isLltvEnabled;
    /// @inheritdoc IMoreMarketsBase
    mapping(address => mapping(address => bool)) public isAuthorized;
    /// @inheritdoc IMoreMarketsBase
    mapping(address => uint256) public nonce;
    /// The market params corresponding to `id`.
    mapping(Id => MarketParams) private _idToMarketParams;

    /// @inheritdoc IMoreMarketsBase
    mapping(Id => address) public idToDebtToken;
    /// @inheritdoc IMoreMarketsBase
    mapping(Id => uint256) public totalDebtAssetsGenerated;
    /// @inheritdoc IMoreMarketsBase
    mapping(Id => uint256) public lastTotalDebtAssetsGenerated;
    /// @inheritdoc IMoreMarketsBase
    mapping(Id => uint256) public tps;
    /// @inheritdoc IMoreMarketsBase
    mapping(Id => mapping(uint64 => uint256))
        public totalBorrowAssetsForMultiplier;
    /// @inheritdoc IMoreMarketsBase
    mapping(Id => mapping(uint64 => uint256))
        public totalBorrowSharesForMultiplier;
    /// @inheritdoc IMoreMarketsBase
    uint256 public irxMaxAvailable;
    /// @inheritdoc IMoreMarketsBase
    uint256 public maxLltvForCategory;
    /// @inheritdoc IMoreMarketsBase
    address public debtTokenFactory;

    /// Mapping that stores array of available interest rate multipliers for particular market.
    mapping(Id => EnumerableSet.UintSet) private _availableMultipliers;
    /// Array that stores ids of all created markets.
    Id[] private _arrayOfMarkets;

    /* CONSTRUCTOR */

    /// @param newOwner The new owner of the contract.
    /// @param _debtTokenFactory The debt token factory.
    constructor(address newOwner, address _debtTokenFactory) {
        require(newOwner != address(0), ErrorsLib.ZERO_ADDRESS);

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(DOMAIN_TYPEHASH, block.chainid, address(this))
        );
        owner = newOwner;

        debtTokenFactory = _debtTokenFactory;

        _setIrxMax(2 * 1e18); // x2
        _setMaxLltvForCategory(1000000000000000000); // 100%

        emit EventsLib.SetOwner(newOwner);
    }

    /* MODIFIERS */

    /// @dev Reverts if the caller is not the owner.
    modifier onlyOwner() {
        require(msg.sender == owner, ErrorsLib.NOT_OWNER);
        _;
    }

    /* ONLY OWNER FUNCTIONS */

    /// @inheritdoc IMoreMarketsBase
    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != owner, ErrorsLib.ALREADY_SET);

        owner = newOwner;

        emit EventsLib.SetOwner(newOwner);
    }

    /// @inheritdoc IMoreMarketsBase
    function setIrxMax(uint256 _irxMaxAvailable) external onlyOwner {
        _setIrxMax(_irxMaxAvailable);
    }

    /// @inheritdoc IMoreMarketsBase
    function setMaxLltvForCategory(
        uint256 _maxLltvForCategory
    ) external onlyOwner {
        _setMaxLltvForCategory(_maxLltvForCategory);
    }

    /// @inheritdoc IMoreMarketsBase
    function enableIrm(address irm) external onlyOwner {
        require(!isIrmEnabled[irm], ErrorsLib.ALREADY_SET);

        isIrmEnabled[irm] = true;

        emit EventsLib.EnableIrm(irm);
    }

    /// @inheritdoc IMoreMarketsBase
    function enableLltv(uint256 lltv) external onlyOwner {
        require(!isLltvEnabled[lltv], ErrorsLib.ALREADY_SET);
        require(lltv < WAD, ErrorsLib.MAX_LLTV_EXCEEDED);

        isLltvEnabled[lltv] = true;

        emit EventsLib.EnableLltv(lltv);
    }

    /// @inheritdoc IMoreMarketsBase
    function setFee(
        MarketParams memory marketParams,
        uint256 newFee
    ) external onlyOwner {
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        require(newFee != market[id].fee, ErrorsLib.ALREADY_SET);
        require(newFee <= MAX_FEE, ErrorsLib.MAX_FEE_EXCEEDED);

        // Accrue interest using the previous fee set before changing it.
        _accrueInterest(marketParams, id);

        // Safe "unchecked" cast.
        market[id].fee = uint128(newFee);

        emit EventsLib.SetFee(id, newFee);
    }

    /// @inheritdoc IMoreMarketsBase
    function setPremiumFee(
        MarketParams memory marketParams,
        uint256 newPremiumFee
    ) external onlyOwner {
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        require(newPremiumFee != market[id].premiumFee, ErrorsLib.ALREADY_SET);
        require(newPremiumFee <= MAX_FEE, ErrorsLib.MAX_FEE_EXCEEDED);

        // Accrue interest using the previous fee set before changing it.
        _accrueInterest(marketParams, id);

        // Safe "unchecked" cast.
        market[id].premiumFee = uint128(newPremiumFee);

        emit EventsLib.SetPremiumFee(id, newPremiumFee);
    }

    /// @inheritdoc IMoreMarketsBase
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(newFeeRecipient != feeRecipient, ErrorsLib.ALREADY_SET);

        feeRecipient = newFeeRecipient;

        emit EventsLib.SetFeeRecipient(newFeeRecipient);
    }

    /* MARKET CREATION */

    /// @inheritdoc IMoreMarketsBase
    function createMarket(MarketParams memory marketParams) external {
        Id id = marketParams.id();
        require(isIrmEnabled[marketParams.irm], ErrorsLib.IRM_NOT_ENABLED);
        require(isLltvEnabled[marketParams.lltv], ErrorsLib.LLTV_NOT_ENABLED);
        require(market[id].lastUpdate == 0, ErrorsLib.MARKET_ALREADY_CREATED);
        if (marketParams.categoryLltv.length != LENGTH_OF_CATEGORY_LLTVS_ARRAY)
            revert ErrorsLib.InvalidLengthOfCategoriesLltvsArray(
                LENGTH_OF_CATEGORY_LLTVS_ARRAY,
                marketParams.categoryLltv.length
            );

        if (
            marketParams.irxMaxLltv < 1e18 ||
            marketParams.irxMaxLltv > irxMaxAvailable
        )
            revert ErrorsLib.InvalidIrxMaxValue(
                irxMaxAvailable,
                1e18,
                marketParams.irxMaxLltv
            );
        _arrayOfMarkets.push(id);

        if (marketParams.isPremiumMarket) {
            for (uint8 i; i < LENGTH_OF_CATEGORY_LLTVS_ARRAY; ) {
                if (
                    marketParams.categoryLltv[i] <= marketParams.lltv ||
                    marketParams.categoryLltv[i] > maxLltvForCategory
                )
                    revert ErrorsLib.InvalidCategoryLltvValue(
                        i,
                        maxLltvForCategory,
                        marketParams.lltv,
                        marketParams.categoryLltv[i]
                    );
                uint256 categoryStepNumber = (marketParams.categoryLltv[i] -
                    marketParams.lltv) / 50000000000000000;
                if (categoryStepNumber == 0) {
                    _availableMultipliers[id].add(marketParams.irxMaxLltv);
                    continue;
                }
                // calculate available multipliers
                uint256 multiplierStep = (uint256(marketParams.irxMaxLltv) -
                    1e18).wDivUp(categoryStepNumber * 10 ** 18);
                for (uint256 j; j < categoryStepNumber; ) {
                    uint256 multiplier = multiplierStep * (j + 1);
                    _availableMultipliers[id].add(multiplier + 1e18);
                    unchecked {
                        ++j;
                    }
                }
                unchecked {
                    ++i;
                }
            }
        }

        // Safe "unchecked" cast.
        market[id].lastUpdate = uint128(block.timestamp);
        _idToMarketParams[id] = marketParams;

        // debt token creation
        {
            string memory name = IERC20Metadata(marketParams.loanToken).name();
            string memory symbol = IERC20Metadata(marketParams.loanToken)
                .symbol();
            uint8 decimals = IERC20Metadata(marketParams.loanToken).decimals();

            idToDebtToken[id] = IDebtTokenFactory(debtTokenFactory).create(
                string(abi.encodePacked(name, " debt token")),
                string(abi.encodePacked("dt", symbol)),
                decimals,
                address(this)
            );
        }

        _availableMultipliers[id].add(1e18);

        emit EventsLib.CreateMarket(id, marketParams);

        // Call to initialize the IRM in case it is stateful.
        if (marketParams.irm != address(0))
            IIrm(marketParams.irm).borrowRate(marketParams, market[id]);
    }

    /* SUPPLY MANAGEMENT */

    /// @inheritdoc IMoreMarketsBase
    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256, uint256) {
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        require(
            UtilsLib.exactlyOneZero(assets, shares),
            ErrorsLib.INCONSISTENT_INPUT
        );
        require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS);

        _accrueInterest(marketParams, id);
        _updateTps(id);

        if (assets > 0)
            shares = assets.toSharesDown(
                market[id].totalSupplyAssets,
                market[id].totalSupplyShares
            );
        else
            assets = shares.toAssetsUp(
                market[id].totalSupplyAssets,
                market[id].totalSupplyShares
            );

        position[id][onBehalf].supplyShares += shares.toUint128();
        market[id].totalSupplyShares += shares.toUint128();
        market[id].totalSupplyAssets += assets.toUint128();

        //debt token distribution managment
        position[id][onBehalf].debtTokenMissed += (
            shares.mulDivDown(tps[id], 1e24)
        ).toUint128();

        emit EventsLib.Supply(id, msg.sender, onBehalf, assets, shares);

        if (data.length > 0)
            IMorphoSupplyCallback(msg.sender).onMorphoSupply(assets, data);

        IERC20(marketParams.loanToken).safeTransferFrom(
            msg.sender,
            address(this),
            assets
        );

        return (assets, shares);
    }

    /// @inheritdoc IMoreMarketsBase
    function withdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256) {
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        require(
            UtilsLib.exactlyOneZero(assets, shares),
            ErrorsLib.INCONSISTENT_INPUT
        );
        require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);
        // No need to verify that onBehalf != address(0) thanks to the following authorization check.
        require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED);

        _accrueInterest(marketParams, id);
        _updateTps(id);

        if (assets > 0)
            shares = assets.toSharesUp(
                market[id].totalSupplyAssets,
                market[id].totalSupplyShares
            );
        else
            assets = shares.toAssetsDown(
                market[id].totalSupplyAssets,
                market[id].totalSupplyShares
            );

        position[id][onBehalf].supplyShares -= shares.toUint128();
        market[id].totalSupplyShares -= shares.toUint128();
        market[id].totalSupplyAssets -= assets.toUint128();

        //debt token distribution managment
        position[id][onBehalf].debtTokenGained += (
            shares.mulDivDown(tps[id], 1e24)
        ).toUint128();

        require(
            market[id].totalBorrowAssets <= market[id].totalSupplyAssets,
            ErrorsLib.INSUFFICIENT_LIQUIDITY
        );

        emit EventsLib.Withdraw(
            id,
            msg.sender,
            onBehalf,
            receiver,
            assets,
            shares
        );

        IERC20(marketParams.loanToken).safeTransfer(receiver, assets);

        return (assets, shares);
    }

    /// @inheritdoc IMoreMarketsBase
    function claimDebtTokens(
        MarketParams memory marketParams,
        address onBehalf,
        address receiver
    ) external {
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);
        // No need to verify that onBehalf != address(0) thanks to the following authorization check.
        require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED);

        _updateTps(id);

        // div by 1e6, since shares have 24 decimal and debt tokens are 18
        uint256 claimAmount = position[id][onBehalf].supplyShares.mulDivDown(
            tps[id],
            1e24
        ) -
            position[id][onBehalf].debtTokenMissed +
            position[id][onBehalf].debtTokenGained;

        if (claimAmount == 0) revert ErrorsLib.NothingToClaim();

        position[id][onBehalf].debtTokenMissed += uint128(claimAmount);

        IDebtToken(idToDebtToken[id]).mint(receiver, claimAmount);

        // emit Claimed(to, claimAmount);
    }

    /* BORROW MANAGEMENT */

    /// @inheritdoc IMoreMarketsBase
    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256) {
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        require(
            UtilsLib.exactlyOneZero(assets, shares),
            ErrorsLib.INCONSISTENT_INPUT
        );
        require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);
        // No need to verify that onBehalf != address(0) thanks to the following authorization check.
        require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED);

        _accrueInterest(marketParams, id);

        assets = _updatePosition(
            marketParams,
            id,
            onBehalf,
            assets,
            shares,
            UPDATE_TYPE.BORROW
        );

        require(
            _isHealthy(marketParams, id, onBehalf),
            ErrorsLib.INSUFFICIENT_COLLATERAL
        );

        require(
            market[id].totalBorrowAssets <= market[id].totalSupplyAssets,
            ErrorsLib.INSUFFICIENT_LIQUIDITY
        );

        emit EventsLib.Borrow(
            id,
            msg.sender,
            onBehalf,
            receiver,
            assets,
            shares
        );

        IERC20(marketParams.loanToken).safeTransfer(receiver, assets);

        return (assets, shares);
    }

    /// @inheritdoc IMoreMarketsBase
    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256, uint256) {
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        require(
            UtilsLib.exactlyOneZero(assets, shares),
            ErrorsLib.INCONSISTENT_INPUT
        );
        require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS);

        _accrueInterest(marketParams, id);

        assets = _updatePosition(
            marketParams,
            id,
            onBehalf,
            assets,
            shares,
            UPDATE_TYPE.REPAY
        );

        // `assets` may be greater than `totalBorrowAssets` by 1.
        emit EventsLib.Repay(id, msg.sender, onBehalf, assets, shares);

        if (data.length > 0)
            IMorphoRepayCallback(msg.sender).onMorphoRepay(assets, data);

        IERC20(marketParams.loanToken).safeTransferFrom(
            msg.sender,
            address(this),
            assets
        );

        return (assets, shares);
    }

    /* COLLATERAL MANAGEMENT */

    /// @inheritdoc IMoreMarketsBase
    function supplyCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalf,
        bytes calldata data
    ) external {
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        require(assets != 0, ErrorsLib.ZERO_ASSETS);
        require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS);

        // Don't accrue interest because it's not required and it saves gas.

        position[id][onBehalf].collateral += assets.toUint128();

        emit EventsLib.SupplyCollateral(id, msg.sender, onBehalf, assets);

        if (data.length > 0)
            IMorphoSupplyCollateralCallback(msg.sender)
                .onMorphoSupplyCollateral(assets, data);

        IERC20(marketParams.collateralToken).safeTransferFrom(
            msg.sender,
            address(this),
            assets
        );
    }

    /// @inheritdoc IMoreMarketsBase
    function withdrawCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalf,
        address receiver
    ) external {
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        require(assets != 0, ErrorsLib.ZERO_ASSETS);
        require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);
        // No need to verify that onBehalf != address(0) thanks to the following authorization check.
        require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED);

        _accrueInterest(marketParams, id);

        position[id][onBehalf].collateral -= assets.toUint128();

        require(
            _isHealthy(marketParams, id, onBehalf),
            ErrorsLib.INSUFFICIENT_COLLATERAL
        );

        emit EventsLib.WithdrawCollateral(
            id,
            msg.sender,
            onBehalf,
            receiver,
            assets
        );

        IERC20(marketParams.collateralToken).safeTransfer(receiver, assets);
    }

    /// @inheritdoc IMoreMarketsBase
    function updateBorrower(
        MarketParams memory marketParams,
        address borrower
    ) public {
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        _accrueInterest(marketParams, id);

        _updatePosition(marketParams, id, borrower, 0, 0, UPDATE_TYPE.IDLE);
    }

    /* LIQUIDATION */

    /// @inheritdoc IMoreMarketsBase
    function liquidate(
        MarketParams memory marketParams,
        address borrower,
        uint256 seizedAssets,
        uint256 repaidShares,
        bytes calldata data
    ) external returns (uint256, uint256) {
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        require(
            UtilsLib.exactlyOneZero(seizedAssets, repaidShares),
            ErrorsLib.INCONSISTENT_INPUT
        );

        _accrueInterest(marketParams, id);

        uint64 lastMultiplier = position[id][borrower].lastMultiplier;
        {
            require(
                !_isHealthy(
                    marketParams,
                    id,
                    borrower,
                    IOracle(marketParams.oracle).price()
                ),
                ErrorsLib.HEALTHY_POSITION
            );

            // The liquidation incentive factor is min(maxLiquidationIncentiveFactor, 1/(1 - cursor*(1 - lltv))).
            uint256 liquidationIncentiveFactor = UtilsLib.min(
                MAX_LIQUIDATION_INCENTIVE_FACTOR,
                WAD.wDivDown(
                    WAD - LIQUIDATION_CURSOR.wMulDown(WAD - marketParams.lltv)
                )
            );

            if (seizedAssets > 0) {
                uint256 seizedAssetsQuoted = seizedAssets.mulDivUp(
                    IOracle(marketParams.oracle).price(),
                    ORACLE_PRICE_SCALE
                );

                repaidShares = seizedAssetsQuoted
                    .wDivUp(liquidationIncentiveFactor)
                    .toSharesUp(
                        totalBorrowAssetsForMultiplier[id][lastMultiplier],
                        totalBorrowSharesForMultiplier[id][lastMultiplier]
                    );
            } else {
                seizedAssets = repaidShares
                    .toAssetsDown(
                        totalBorrowAssetsForMultiplier[id][lastMultiplier],
                        totalBorrowSharesForMultiplier[id][lastMultiplier]
                    )
                    .wMulDown(liquidationIncentiveFactor)
                    .mulDivDown(
                        ORACLE_PRICE_SCALE,
                        IOracle(marketParams.oracle).price()
                    );
            }
        }
        uint256 repaidAssets = repaidShares.toAssetsUp(
            totalBorrowAssetsForMultiplier[id][lastMultiplier],
            totalBorrowSharesForMultiplier[id][lastMultiplier]
        );

        position[id][borrower].borrowShares -= repaidShares.toUint128();
        totalBorrowSharesForMultiplier[id][lastMultiplier] -= repaidShares
            .toUint128();
        totalBorrowAssetsForMultiplier[id][lastMultiplier] = UtilsLib
            .zeroFloorSub(
                totalBorrowAssetsForMultiplier[id][lastMultiplier],
                repaidAssets
            )
            .toUint128();
        market[id].totalBorrowAssets = UtilsLib
            .zeroFloorSub(market[id].totalBorrowAssets, repaidAssets)
            .toUint128();
        position[id][borrower].collateral -= seizedAssets.toUint128();

        uint256 badDebtShares;
        uint256 badDebtAssets;
        if (position[id][borrower].collateral == 0) {
            badDebtShares = position[id][borrower].borrowShares;
            badDebtAssets = UtilsLib.min(
                totalBorrowAssetsForMultiplier[id][lastMultiplier],
                badDebtShares.toAssetsUp(
                    totalBorrowAssetsForMultiplier[id][lastMultiplier],
                    totalBorrowSharesForMultiplier[id][lastMultiplier]
                )
            );

            market[id].totalBorrowAssets -= badDebtAssets.toUint128();

            market[id].totalSupplyAssets -= badDebtAssets.toUint128();
            totalBorrowAssetsForMultiplier[id][lastMultiplier] -= badDebtAssets
                .toUint128();
            totalBorrowSharesForMultiplier[id][lastMultiplier] -= badDebtShares
                .toUint128();

            position[id][borrower].borrowShares = 0;

            // if user is prem, then issue debt tokens
            if (lastMultiplier != 1e18) {
                totalDebtAssetsGenerated[id] += badDebtAssets;
            }
        }

        // `repaidAssets` may be greater than `totalBorrowAssets` by 1.
        emit EventsLib.Liquidate(
            id,
            msg.sender,
            borrower,
            repaidAssets,
            repaidShares,
            seizedAssets,
            badDebtAssets,
            badDebtShares
        );

        IERC20(marketParams.collateralToken).safeTransfer(
            msg.sender,
            seizedAssets
        );

        if (data.length > 0)
            IMorphoLiquidateCallback(msg.sender).onMorphoLiquidate(
                repaidAssets,
                data
            );

        IERC20(marketParams.loanToken).safeTransferFrom(
            msg.sender,
            address(this),
            repaidAssets
        );

        return (seizedAssets, repaidAssets);
    }

    /* FLASH LOANS */

    /// @inheritdoc IMoreMarketsBase
    function flashLoan(
        address token,
        uint256 assets,
        bytes calldata data
    ) external {
        require(assets != 0, ErrorsLib.ZERO_ASSETS);

        emit EventsLib.FlashLoan(msg.sender, token, assets);

        IERC20(token).safeTransfer(msg.sender, assets);

        IMorphoFlashLoanCallback(msg.sender).onMorphoFlashLoan(assets, data);

        IERC20(token).safeTransferFrom(msg.sender, address(this), assets);
    }

    /* AUTHORIZATION */

    /// @inheritdoc IMoreMarketsBase
    function setAuthorization(
        address authorized,
        bool newIsAuthorized
    ) external {
        require(
            newIsAuthorized != isAuthorized[msg.sender][authorized],
            ErrorsLib.ALREADY_SET
        );

        isAuthorized[msg.sender][authorized] = newIsAuthorized;

        emit EventsLib.SetAuthorization(
            msg.sender,
            msg.sender,
            authorized,
            newIsAuthorized
        );
    }

    /// @inheritdoc IMoreMarketsBase
    function setAuthorizationWithSig(
        Authorization memory authorization,
        Signature calldata signature
    ) external {
        /// Do not check whether authorization is already set because the nonce increment is a desired side effect.
        require(
            block.timestamp <= authorization.deadline,
            ErrorsLib.SIGNATURE_EXPIRED
        );
        require(
            authorization.nonce == nonce[authorization.authorizer]++,
            ErrorsLib.INVALID_NONCE
        );

        bytes32 hashStruct = keccak256(
            abi.encode(AUTHORIZATION_TYPEHASH, authorization)
        );
        bytes32 digest = keccak256(
            bytes.concat("\x19\x01", DOMAIN_SEPARATOR, hashStruct)
        );
        address signatory = ecrecover(
            digest,
            signature.v,
            signature.r,
            signature.s
        );

        require(
            signatory != address(0) && authorization.authorizer == signatory,
            ErrorsLib.INVALID_SIGNATURE
        );

        emit EventsLib.IncrementNonce(
            msg.sender,
            authorization.authorizer,
            authorization.nonce
        );

        isAuthorized[authorization.authorizer][
            authorization.authorized
        ] = authorization.isAuthorized;

        emit EventsLib.SetAuthorization(
            msg.sender,
            authorization.authorizer,
            authorization.authorized,
            authorization.isAuthorized
        );
    }

    /// @dev Returns whether the sender is authorized to manage `onBehalf`'s positions.
    function _isSenderAuthorized(
        address onBehalf
    ) internal view returns (bool) {
        return msg.sender == onBehalf || isAuthorized[onBehalf][msg.sender];
    }

    /* INTEREST MANAGEMENT */

    /// @inheritdoc IMoreMarketsBase
    function accrueInterest(MarketParams memory marketParams) external {
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);

        _accrueInterest(marketParams, id);
    }

    /// @dev Accrues interest for the given market `marketParams`.
    /// @dev Assumes that the inputs `marketParams` and `id` match.
    function _accrueInterest(MarketParams memory marketParams, Id id) internal {
        uint256 elapsed = block.timestamp - market[id].lastUpdate;
        if (elapsed == 0) return;

        if (marketParams.irm != address(0)) {
            uint256 borrowRate = IIrm(marketParams.irm).borrowRate(
                marketParams,
                market[id]
            );

            uint256 totalInterest;
            // interest generated by premium users that have LTV above default LLTV.
            uint256 premiumInterest;
            uint256 premiumFee = market[id].premiumFee;
            for (uint256 i; i < _availableMultipliers[id].length(); ) {
                uint64 currentMultiplier = uint64(
                    _availableMultipliers[id].at(i)
                );

                if (
                    totalBorrowAssetsForMultiplier[id][currentMultiplier] == 0
                ) {
                    unchecked {
                        ++i;
                    }
                    continue;
                }

                uint256 interestForMultiplier;
                uint256 premiumFeeMulAddition;
                if (currentMultiplier != 1e18 && premiumFee != 0) {
                    premiumFeeMulAddition = uint256(
                        uint256(premiumFee).wMulDown(currentMultiplier)
                    );
                }

                interestForMultiplier = totalBorrowAssetsForMultiplier[id][
                    currentMultiplier
                ]
                    .wMulDown(
                        borrowRate.wMulDown(
                            currentMultiplier + premiumFeeMulAddition
                        )
                    )
                    .wTaylorCompounded(elapsed);

                totalInterest += interestForMultiplier;
                if (currentMultiplier != 1e18 && premiumFee != 0) {
                    premiumInterest += interestForMultiplier;
                }

                totalBorrowAssetsForMultiplier[id][
                    currentMultiplier
                ] += interestForMultiplier;

                unchecked {
                    ++i;
                }
            }

            market[id].totalBorrowAssets += totalInterest.toUint128();
            market[id].totalSupplyAssets += totalInterest.toUint128();

            uint256 feeShares;
            if (market[id].fee != 0 || premiumFee != 0) {
                uint256 feeAmount = totalInterest.wMulDown(market[id].fee) +
                    premiumInterest.wMulDown(premiumFee);
                // The fee amount is subtracted from the total supply in this calculation to compensate for the fact
                // that total supply is already increased by the full interest (including the fee amount).
                feeShares = feeAmount.toSharesDown(
                    market[id].totalSupplyAssets - feeAmount,
                    market[id].totalSupplyShares
                );
                position[id][feeRecipient].supplyShares += feeShares
                    .toUint128();
                market[id].totalSupplyShares += feeShares.toUint128();
            }

            emit EventsLib.AccrueInterest(
                id,
                borrowRate,
                totalInterest,
                feeShares
            );
        }

        // Safe "unchecked" cast.
        market[id].lastUpdate = uint128(block.timestamp);
    }

    /* HEALTH CHECK */

    /// @dev Returns whether the position of `borrower` in the given market `marketParams` is healthy.
    /// @dev Assumes that the inputs `marketParams` and `id` match.
    function _isHealthy(
        MarketParams memory marketParams,
        Id id,
        address borrower
    ) internal view returns (bool) {
        if (position[id][borrower].borrowShares == 0) return true;

        uint256 collateralPrice = IOracle(marketParams.oracle).price();

        return _isHealthy(marketParams, id, borrower, collateralPrice);
    }

    /// @dev Returns whether the position of `borrower` in the given market `marketParams` with the given
    /// `collateralPrice` is healthy.
    /// @dev Assumes that the inputs `marketParams` and `id` match.
    /// @dev Rounds in favor of the protocol, so one might not be able to borrow exactly `maxBorrow` but one unit less.
    function _isHealthy(
        MarketParams memory marketParams,
        Id id,
        address borrower,
        uint256 collateralPrice
    ) internal view returns (bool) {
        uint256 lltvToUse;
        uint64 lastMultiplier;

        if (marketParams.isPremiumMarket) {
            (bool success, bytes memory data) = address(
                marketParams.creditAttestationService
            ).staticcall(
                    abi.encodeWithSignature("getScore(address)", borrower)
                );

            uint256 currentScore;
            lastMultiplier = position[id][borrower].lastMultiplier;
            if (success) {
                currentScore = abi.decode(data, (uint256));
                if (currentScore != 0) {
                    uint8 categoryNum;
                    if (currentScore < 1000 * 10 ** 18) {
                        categoryNum = uint8(currentScore / (200 * 10 ** 18));
                    } else {
                        categoryNum = 4;
                    }
                    lltvToUse = marketParams.categoryLltv[categoryNum];
                }
            } else {
                lltvToUse = marketParams.lltv;
            }
        } else {
            lltvToUse = marketParams.lltv;
            lastMultiplier = 1e18;
        }

        uint256 borrowed = uint256(position[id][borrower].borrowShares)
            .toAssetsUp(
                totalBorrowAssetsForMultiplier[id][lastMultiplier],
                totalBorrowSharesForMultiplier[id][lastMultiplier]
            );

        uint256 maxBorrow = uint256(position[id][borrower].collateral)
            .mulDivDown(collateralPrice, ORACLE_PRICE_SCALE)
            .wMulDown(lltvToUse);

        return maxBorrow >= borrowed;
    }

    /* DEBT TOKENS MANAGMENT */

    /// @notice Updates the TPS of the market `id`.
    /// @param id The market id.
    function _updateTps(Id id) internal {
        uint256 _totalDebtAssetsGenerated = totalDebtAssetsGenerated[id];
        uint256 _totalSupplyShares = market[id].totalSupplyShares;

        uint256 amountForLastPeriod = _totalDebtAssetsGenerated -
            lastTotalDebtAssetsGenerated[id];

        if (_totalSupplyShares > 0) {
            // TODO: need to think: for more accurate tps we can multiply by bigger number and then divide in claimDebtTokens, supply and withdraw functions
            // shares' decimal is 24
            tps[id] += (amountForLastPeriod).mulDivDown(
                1e24,
                _totalSupplyShares
            );
        }
        lastTotalDebtAssetsGenerated[id] = _totalDebtAssetsGenerated;
    }

    /* USERS' POSITIONS MANAGMENT */

    /// @notice Updates the position of `borrower` in the market `id`.
    /// @param marketParams The market parameters.
    /// @param id The market id.
    /// @param borrower The borrower address.
    /// @param assets The amount of assets to borrow.
    /// @param shares The amount of shares to borrow.
    /// @param updateType The update type.
    function _updatePosition(
        MarketParams memory marketParams,
        Id id,
        address borrower,
        uint256 assets,
        uint256 shares,
        UPDATE_TYPE updateType
    ) internal returns (uint256) {
        uint64 lastMultiplier = position[id][borrower].lastMultiplier;
        if (shares > 0)
            if (updateType == UPDATE_TYPE.BORROW) {
                assets = shares.toAssetsDown(
                    totalBorrowAssetsForMultiplier[id][lastMultiplier],
                    totalBorrowSharesForMultiplier[id][lastMultiplier]
                );
            } else if (updateType == UPDATE_TYPE.REPAY) {
                assets = shares.toAssetsUp(
                    totalBorrowAssetsForMultiplier[id][lastMultiplier],
                    totalBorrowSharesForMultiplier[id][lastMultiplier]
                );
            }

        uint64 currentMultiplier;
        if (marketParams.isPremiumMarket) {
            currentMultiplier = _getMultiplier(
                marketParams,
                id,
                borrower,
                assets,
                updateType
            );
        } else {
            currentMultiplier = lastMultiplier;
        }

        if (assets > 0 && shares == 0)
            if (updateType == UPDATE_TYPE.BORROW) {
                shares = assets.toSharesUp(
                    totalBorrowAssetsForMultiplier[id][currentMultiplier],
                    totalBorrowSharesForMultiplier[id][currentMultiplier]
                );
            } else if (updateType == UPDATE_TYPE.REPAY) {
                shares = assets.toSharesDown(
                    totalBorrowAssetsForMultiplier[id][currentMultiplier],
                    totalBorrowSharesForMultiplier[id][currentMultiplier]
                );
            }

        uint256 borrowedSharesBefore = position[id][borrower].borrowShares;
        uint256 borrowedAssetsBefore;

        borrowedAssetsBefore = borrowedSharesBefore.toAssetsUp(
            totalBorrowAssetsForMultiplier[id][lastMultiplier],
            totalBorrowSharesForMultiplier[id][lastMultiplier]
        );
        if (lastMultiplier != currentMultiplier) {
            _updateCategory(
                id,
                lastMultiplier,
                currentMultiplier,
                borrower,
                updateType,
                borrowedAssetsBefore,
                borrowedSharesBefore,
                assets
            );
        } else if (updateType == UPDATE_TYPE.BORROW) {
            position[id][borrower].borrowShares += shares.toUint128();
            totalBorrowAssetsForMultiplier[id][currentMultiplier] += assets
                .toUint128();
            totalBorrowSharesForMultiplier[id][currentMultiplier] += shares
                .toUint128();
            market[id].totalBorrowAssets += assets.toUint128();
        } else if (updateType == UPDATE_TYPE.REPAY) {
            position[id][borrower].borrowShares -= shares.toUint128();

            totalBorrowAssetsForMultiplier[id][currentMultiplier] -= assets
                .toUint128();

            totalBorrowSharesForMultiplier[id][currentMultiplier] -= shares
                .toUint128();
            market[id].totalBorrowAssets = UtilsLib
                .zeroFloorSub(market[id].totalBorrowAssets, assets)
                .toUint128();
        }
        return assets;
    }

    /// @notice Calculates the multiplier for premium `borrower` in the market `id`.
    /// @param marketParams The market parameters.
    /// @param id The market id.
    /// @param borrower The borrower address.
    /// @param assets The amount of assets to borrow.
    /// @param updateType The update type.
    /// @return multiplier Actual multiplier of uesr based on his LTV and CAS score.
    function _getMultiplier(
        MarketParams memory marketParams,
        Id id,
        address borrower,
        uint256 assets,
        UPDATE_TYPE updateType
    ) internal view returns (uint64 multiplier) {
        uint64 lastMultiplier = position[id][borrower].lastMultiplier;

        uint256 collateralPrice = IOracle(marketParams.oracle).price();
        uint256 borrowedBefore = uint256(position[id][borrower].borrowShares)
            .toAssetsUp(
                totalBorrowAssetsForMultiplier[id][lastMultiplier],
                totalBorrowSharesForMultiplier[id][lastMultiplier]
            );
        uint256 borrowed = updateType == UPDATE_TYPE.BORROW
            ? borrowedBefore + assets
            : borrowedBefore - assets;

        (bool success, bytes memory data) = address(
            marketParams.creditAttestationService
        ).staticcall(abi.encodeWithSignature("getScore(address)", borrower));

        uint256 maxBorrowByDefault = uint256(position[id][borrower].collateral)
            .mulDivDown(collateralPrice, ORACLE_PRICE_SCALE)
            .wMulDown(marketParams.lltv);

        if (borrowed <= maxBorrowByDefault) return 1 * 10 ** 18;

        uint256 currentScore;
        uint8 categoryNum;

        if (success && (data.length > 0)) {
            currentScore = abi.decode(data, (uint256));
            if (currentScore != 0) {
                if (currentScore < 1000 * 10 ** 18) {
                    categoryNum = uint8(currentScore / (200 * 10 ** 18));
                } else {
                    categoryNum = 4;
                }
            }
        } else revert(ErrorsLib.INSUFFICIENT_COLLATERAL);

        uint256 maxBorrowByScore = uint256(position[id][borrower].collateral)
            .mulDivDown(collateralPrice, ORACLE_PRICE_SCALE)
            .wMulDown(marketParams.categoryLltv[categoryNum]);

        uint256 categoryStepNumber = (marketParams.categoryLltv[categoryNum] -
            marketParams.lltv) / 50000000000000000;
        if (categoryStepNumber == 0) {
            categoryStepNumber = 1;
        }
        uint256 step = (maxBorrowByScore - maxBorrowByDefault).wDivUp(
            uint256(categoryStepNumber) * 10 ** 18
        );

        uint256 nextStep = maxBorrowByDefault + step;
        for (uint64 i = 1; i < categoryStepNumber + 1; ) {
            if (borrowed <= nextStep) {
                multiplier = uint64(
                    ((
                        uint256(marketParams.irxMaxLltv - 1e18).wDivUp(
                            categoryStepNumber * 10 ** 18
                        )
                    ) * i) + 1e18
                );
                break;
            }
            nextStep += step;
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Move borrowed assets from one category of multipliers to another.
    /// @param id The market id.
    /// @param lastMultiplier The last multiplier.
    /// @param newMultiplier The new multiplier.
    /// @param borrower The borrower address.
    /// @param updateType The update type.
    /// @param borrowedAssetsBefore The borrowed assets before the update.
    /// @param borrowedSharesBefore The borrowed shares before the update.
    /// @param assets The amount of assets to borrow.
    function _updateCategory(
        Id id,
        uint64 lastMultiplier,
        uint64 newMultiplier,
        address borrower,
        UPDATE_TYPE updateType,
        uint256 borrowedAssetsBefore,
        uint256 borrowedSharesBefore,
        uint256 assets
    ) internal {
        // sub from prev category
        totalBorrowAssetsForMultiplier[id][
            lastMultiplier
        ] -= borrowedAssetsBefore;
        totalBorrowSharesForMultiplier[id][
            lastMultiplier
        ] -= borrowedSharesBefore;

        // calc new shares
        uint256 newAssets = borrowedAssetsBefore;
        if (updateType == UPDATE_TYPE.BORROW) {
            newAssets += assets;
            market[id].totalBorrowAssets += assets.toUint128();
        } else if (updateType == UPDATE_TYPE.REPAY) {
            newAssets -= assets;
            market[id].totalBorrowAssets -= assets.toUint128();
        }

        uint256 newShares = newAssets.toSharesUp(
            totalBorrowAssetsForMultiplier[id][newMultiplier],
            totalBorrowSharesForMultiplier[id][newMultiplier]
        );

        // update borrow shares
        position[id][borrower].borrowShares = newShares.toUint128();
        // add to new category
        totalBorrowAssetsForMultiplier[id][newMultiplier] += newAssets;
        totalBorrowSharesForMultiplier[id][newMultiplier] += newShares;

        // update last category
        position[id][borrower].lastMultiplier = newMultiplier;
    }

    /* VIEW METHODS */

    /// @inheritdoc IMoreMarketsBase
    function arrayOfMarkets() external view returns (Id[] memory) {
        Id[] memory memArray = _arrayOfMarkets;
        return memArray;
    }

    /// @inheritdoc IMoreMarketsStaticTyping
    function idToMarketParams(
        Id id
    )
        external
        view
        returns (
            bool,
            address,
            address,
            address,
            address,
            uint256,
            address,
            uint96,
            uint256[] memory
        )
    {
        uint256[] memory categoryLltvs = _idToMarketParams[id].categoryLltv;
        return (
            _idToMarketParams[id].isPremiumMarket,
            _idToMarketParams[id].loanToken,
            _idToMarketParams[id].collateralToken,
            _idToMarketParams[id].oracle,
            _idToMarketParams[id].irm,
            _idToMarketParams[id].lltv,
            _idToMarketParams[id].creditAttestationService,
            _idToMarketParams[id].irxMaxLltv,
            categoryLltvs
        );
    }

    /* INTERNAL SETTER FUNCTIONS */

    /// @notice Internal function that sets the `irxMaxAvailable` value.
    /// @param _irxMaxAvailable The new `irxMaxAvailable` value.
    function _setIrxMax(uint256 _irxMaxAvailable) internal {
        require(irxMaxAvailable != _irxMaxAvailable, ErrorsLib.ALREADY_SET);

        irxMaxAvailable = _irxMaxAvailable;

        emit EventsLib.SetIrxMaxAvailable(_irxMaxAvailable);
    }

    /// @notice Internal function that sets the `maxLltvForCategory` value.
    /// @param _maxLltvForCategory The new `maxLltvForCategory` value.
    function _setMaxLltvForCategory(uint256 _maxLltvForCategory) internal {
        require(
            maxLltvForCategory != _maxLltvForCategory,
            ErrorsLib.ALREADY_SET
        );

        maxLltvForCategory = _maxLltvForCategory;

        emit EventsLib.SetMaxLltvForCategory(_maxLltvForCategory);
    }

    /* STORAGE VIEW */

    /// @inheritdoc IMoreMarketsBase
    function extSloads(
        bytes32[] calldata slots
    ) external view returns (bytes32[] memory res) {
        uint256 nSlots = slots.length;

        res = new bytes32[](nSlots);

        for (uint256 i; i < nSlots; ) {
            bytes32 slot = slots[i++];

            assembly ("memory-safe") {
                mstore(add(res, mul(i, 32)), sload(slot))
            }
        }
    }
}
