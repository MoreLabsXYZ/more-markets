// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IMoreMarketsStaticTyping, Position, CategoryInfo, MarketParams, Market, Id, Authorization, Signature, IMoreMarketsBase} from "./interfaces/IMoreMarkets.sol";
import {IIrm} from "./interfaces/IIrm.sol";
import {MathLib, UtilsLib, SharesMathLib, SafeTransferLib, IERC20, IOracle, WAD} from "./fork/Morpho.sol";
import {IMoreLiquidateCallback, IMoreRepayCallback, IMoreSupplyCallback, IMoreSupplyCollateralCallback, IMoreFlashLoanCallback} from "./interfaces/IMoreCallbacks.sol";
import {ICreditAttestationService} from "./interfaces/ICreditAttestationService.sol";
import "@morpho-org/morpho-blue/src/libraries/ConstantsLib.sol";
import {ErrorsLib} from "./libraries/markets/ErrorsLib.sol";
import {EventsLib} from "./libraries/markets/EventsLib.sol";
import {MarketParamsLib} from "./libraries/MarketParamsLib.sol";
import {ICreditAttestationService} from "./interfaces/ICreditAttestationService.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/// @title MoreMarkets
/// @author MORE Labs
/// @notice The More Markets contract fork of Morpho-blue contract with additional feature to make premium users to borrow with a higher LLTV.
/// It is possible to make undercollateralized borrows if contract is set to.
contract MoreMarkets is Initializable, IMoreMarketsStaticTyping {
    using MathLib for uint128;
    using MathLib for uint256;
    using UtilsLib for uint256;
    using SharesMathLib for uint256;
    using SafeTransferLib for IERC20;
    using MarketParamsLib for MarketParams;
    using EnumerableSet for EnumerableSet.UintSet;

    /* ENUMS */

    /// Type of position update.
    enum UPDATE_TYPE {
        BORROW,
        REPAY,
        IDLE
    }

    /* CONSTANTS */

    /// Number of categories for attestation service score. 0-199 score is 1st category, 200-399 score is 2nd category, etc.
    uint256 constant LENGTH_OF_CATEGORY_LLTVS_ARRAY = 5;
    // Default multiplier for users, that are in default LLTV range.
    uint64 constant DEFAULT_MULTIPLIER = 1e18;
    /// @dev The maximum premium fee a market can have (50%).
    uint256 constant PREMIUM_MAX_FEE = 0.5e18;

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
    mapping(Id => mapping(uint64 => uint256))
        public totalBorrowAssetsForMultiplier;
    /// @inheritdoc IMoreMarketsBase
    mapping(Id => mapping(uint64 => uint256))
        public totalBorrowSharesForMultiplier;
    /// @inheritdoc IMoreMarketsBase
    uint256 public irxMaxAvailable;
    /// @inheritdoc IMoreMarketsBase
    uint256 public maxLltvForCategory;

    /// Mapping that stores array of available interest rate multipliers for particular market.
    mapping(Id => EnumerableSet.UintSet) private _availableMultipliers;
    /// Array that stores ids of all created markets.
    Id[] private _arrayOfMarkets;

    /// @inheritdoc IMoreMarketsBase
    bytes32 public DOMAIN_SEPARATOR;

    /* CONSTRUCTOR */

    constructor() {
        _disableInitializers();
    }

    /* INITIALIZER */

    /// @inheritdoc IMoreMarketsBase
    function initialize(address newOwner) external initializer {
        require(newOwner != address(0), ErrorsLib.ZERO_ADDRESS);

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(DOMAIN_TYPEHASH, block.chainid, address(this))
        );
        owner = newOwner;

        _setIrxMax(2 * DEFAULT_MULTIPLIER); // x2
        _setMaxLltvForCategory(1000000000000000000); // 100%

        emit EventsLib.SetOwner(newOwner);
    }

    function availableMultipliers(
        Id id
    ) public view returns (uint256[] memory) {
        uint256 length = _availableMultipliers[id].length();
        uint256[] memory array = new uint256[](length);

        for (uint256 i; i < length; ) {
            array[i] = _availableMultipliers[id].at(i);
            unchecked {
                ++i;
            }
        }
        return array;
    }

    /* MODIFIERS */

    /// @dev Reverts if the caller is not the owner.
    modifier onlyOwner() {
        // require(msg.sender == owner, ErrorsLib.NOT_OWNER);
        if (msg.sender != owner) revert ErrorsLib.NotOwner();
        _;
    }

    /* ONLY OWNER FUNCTIONS */

    /// @inheritdoc IMoreMarketsBase
    function setOwner(address newOwner) external onlyOwner {
        if (newOwner == owner) revert ErrorsLib.AlreadySet();

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
        if (isIrmEnabled[irm]) revert ErrorsLib.AlreadySet();

        isIrmEnabled[irm] = true;

        emit EventsLib.EnableIrm(irm);
    }

    /// @inheritdoc IMoreMarketsBase
    function enableLltv(uint256 lltv) external onlyOwner {
        if (isLltvEnabled[lltv]) revert ErrorsLib.AlreadySet();
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
        Market storage currentMarket = market[id];
        if (currentMarket.lastUpdate == 0) revert ErrorsLib.MarketNotCreated();
        if (newFee == currentMarket.fee) revert ErrorsLib.AlreadySet();

        require(newFee <= MAX_FEE, ErrorsLib.MAX_FEE_EXCEEDED);

        // Accrue interest using the previous fee set before changing it.
        _accrueInterest(marketParams, id);

        // Safe "unchecked" cast.
        currentMarket.fee = uint128(newFee);

        emit EventsLib.SetFee(id, newFee);
    }

    /// @inheritdoc IMoreMarketsBase
    function setPremiumFee(
        MarketParams memory marketParams,
        uint256 newPremiumFee
    ) external onlyOwner {
        Id id = marketParams.id();
        Market storage currentMarket = market[id];
        if (currentMarket.lastUpdate == 0) revert ErrorsLib.MarketNotCreated();
        if (newPremiumFee == currentMarket.premiumFee)
            revert ErrorsLib.AlreadySet();
        require(newPremiumFee <= PREMIUM_MAX_FEE, ErrorsLib.MAX_FEE_EXCEEDED);

        // Accrue interest using the previous fee set before changing it.
        _accrueInterest(marketParams, id);

        // Safe "unchecked" cast.
        currentMarket.premiumFee = uint128(newPremiumFee);

        emit EventsLib.SetPremiumFee(id, newPremiumFee);
    }

    /// @inheritdoc IMoreMarketsBase
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == feeRecipient) revert ErrorsLib.AlreadySet();

        feeRecipient = newFeeRecipient;

        emit EventsLib.SetFeeRecipient(newFeeRecipient);
    }

    /* MARKET CREATION */

    /// @inheritdoc IMoreMarketsBase
    function createMarket(MarketParams memory marketParams) external {
        Id id = marketParams.id();
        Market storage currentMarket = market[id];
        EnumerableSet.UintSet
            storage avaialableMultipliersForMarket = _availableMultipliers[id];
        require(isIrmEnabled[marketParams.irm], ErrorsLib.IRM_NOT_ENABLED);
        require(isLltvEnabled[marketParams.lltv], ErrorsLib.LLTV_NOT_ENABLED);
        require(
            currentMarket.lastUpdate == 0,
            ErrorsLib.MARKET_ALREADY_CREATED
        );
        if (marketParams.categoryLltv.length != LENGTH_OF_CATEGORY_LLTVS_ARRAY)
            revert ErrorsLib.InvalidLengthOfCategoriesLltvsArray(
                LENGTH_OF_CATEGORY_LLTVS_ARRAY,
                marketParams.categoryLltv.length
            );

        if (
            marketParams.irxMaxLltv < DEFAULT_MULTIPLIER ||
            marketParams.irxMaxLltv > irxMaxAvailable
        )
            revert ErrorsLib.InvalidIrxMaxValue(
                irxMaxAvailable,
                DEFAULT_MULTIPLIER,
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
                if (i != LENGTH_OF_CATEGORY_LLTVS_ARRAY - 1) {
                    if (
                        marketParams.categoryLltv[i] >
                        marketParams.categoryLltv[i + 1]
                    ) revert ErrorsLib.LLTVsNotInAscendingOrder();
                }
                uint256 categoryStepNumber = (marketParams.categoryLltv[i] -
                    marketParams.lltv) / 50000000000000000;
                if (categoryStepNumber == 0) {
                    avaialableMultipliersForMarket.add(marketParams.irxMaxLltv);
                    continue;
                }
                // calculate available multipliers
                uint256 multiplierStep = (uint256(marketParams.irxMaxLltv) -
                    DEFAULT_MULTIPLIER).wDivUp(categoryStepNumber * 10 ** 18);
                for (uint256 j; j < categoryStepNumber; ) {
                    uint256 multiplier = multiplierStep * (j + 1);
                    avaialableMultipliersForMarket.add(
                        multiplier + DEFAULT_MULTIPLIER
                    );
                    unchecked {
                        ++j;
                    }
                }
                unchecked {
                    ++i;
                }
            }
        } else {
            bool isArrayConsistOfZeros = true;
            for (uint256 i; i < marketParams.categoryLltv.length; ) {
                if (marketParams.categoryLltv[i] != 0) {
                    isArrayConsistOfZeros = false;
                    break;
                }
                unchecked {
                    ++i;
                }
            }
            if (
                marketParams.creditAttestationService != address(0) ||
                marketParams.irxMaxLltv != DEFAULT_MULTIPLIER ||
                !isArrayConsistOfZeros
            ) revert ErrorsLib.InvalidParamsForNonPremiumMarket();
        }

        // Safe "unchecked" cast.
        currentMarket.lastUpdate = uint128(block.timestamp);
        _idToMarketParams[id] = marketParams;

        avaialableMultipliersForMarket.add(DEFAULT_MULTIPLIER);

        emit EventsLib.CreateMarket(id, marketParams);

        // Call to initialize the IRM in case it is stateful.
        if (marketParams.irm != address(0))
            IIrm(marketParams.irm).borrowRate(marketParams, currentMarket);
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
        Market storage currentMarket = market[id];
        if (currentMarket.lastUpdate == 0) revert ErrorsLib.MarketNotCreated();
        require(
            UtilsLib.exactlyOneZero(assets, shares),
            ErrorsLib.INCONSISTENT_INPUT
        );
        require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS);

        _accrueInterest(marketParams, id);

        if (assets > 0)
            shares = assets.toSharesDown(
                currentMarket.totalSupplyAssets,
                currentMarket.totalSupplyShares
            );
        else
            assets = shares.toAssetsUp(
                currentMarket.totalSupplyAssets,
                currentMarket.totalSupplyShares
            );

        position[id][onBehalf].supplyShares += shares.toUint128();
        currentMarket.totalSupplyShares += uint128(shares);
        currentMarket.totalSupplyAssets += assets.toUint128();

        emit EventsLib.Supply(id, msg.sender, onBehalf, assets, shares);

        if (data.length > 0)
            IMoreSupplyCallback(msg.sender).onMoreSupply(assets, data);

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
        Market storage currentMarket = market[id];
        if (currentMarket.lastUpdate == 0) revert ErrorsLib.MarketNotCreated();
        require(
            UtilsLib.exactlyOneZero(assets, shares),
            ErrorsLib.INCONSISTENT_INPUT
        );
        require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);
        // No need to verify that onBehalf != address(0) thanks to the following authorization check.
        require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED);

        _accrueInterest(marketParams, id);

        if (assets > 0)
            shares = assets.toSharesUp(
                currentMarket.totalSupplyAssets,
                currentMarket.totalSupplyShares
            );
        else
            assets = shares.toAssetsDown(
                currentMarket.totalSupplyAssets,
                currentMarket.totalSupplyShares
            );

        position[id][onBehalf].supplyShares -= shares.toUint128();
        currentMarket.totalSupplyShares -= uint128(shares);
        currentMarket.totalSupplyAssets -= assets.toUint128();

        require(
            currentMarket.totalBorrowAssets <= currentMarket.totalSupplyAssets,
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
        Market storage currentMarket = market[id];
        if (currentMarket.lastUpdate == 0) revert ErrorsLib.MarketNotCreated();
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

        if (!_isHealthy(marketParams, id, onBehalf))
            revert ErrorsLib.InsufficientCollateral();

        require(
            currentMarket.totalBorrowAssets <= currentMarket.totalSupplyAssets,
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
        if (market[id].lastUpdate == 0) revert ErrorsLib.MarketNotCreated();
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
            IMoreRepayCallback(msg.sender).onMoreRepay(assets, data);

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
        if (market[id].lastUpdate == 0) revert ErrorsLib.MarketNotCreated();
        require(assets != 0, ErrorsLib.ZERO_ASSETS);
        require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS);

        _accrueInterest(marketParams, id);

        position[id][onBehalf].collateral += assets.toUint128();

        _updatePosition(marketParams, id, onBehalf, 0, 0, UPDATE_TYPE.IDLE);

        emit EventsLib.SupplyCollateral(id, msg.sender, onBehalf, assets);

        if (data.length > 0)
            IMoreSupplyCollateralCallback(msg.sender).onMoreSupplyCollateral(
                assets,
                data
            );

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
        if (market[id].lastUpdate == 0) revert ErrorsLib.MarketNotCreated();
        require(assets != 0, ErrorsLib.ZERO_ASSETS);
        require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);
        // No need to verify that onBehalf != address(0) thanks to the following authorization check.
        require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED);

        _accrueInterest(marketParams, id);

        position[id][onBehalf].collateral -= assets.toUint128();

        _updatePosition(marketParams, id, onBehalf, 0, 0, UPDATE_TYPE.IDLE);

        if (!_isHealthy(marketParams, id, onBehalf))
            revert ErrorsLib.InsufficientCollateral();

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
        if (market[id].lastUpdate == 0) revert ErrorsLib.MarketNotCreated();
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
        Market storage currentMarket = market[id];
        if (currentMarket.lastUpdate == 0) revert ErrorsLib.MarketNotCreated();
        require(
            UtilsLib.exactlyOneZero(seizedAssets, repaidShares),
            ErrorsLib.INCONSISTENT_INPUT
        );

        _accrueInterest(marketParams, id);

        _updatePosition(marketParams, id, borrower, 0, 0, UPDATE_TYPE.IDLE);

        Position storage currentPosition = position[id][borrower];
        uint64 lastMultiplier = currentPosition.lastMultiplier;
        uint256 collateralPrice = IOracle(marketParams.oracle).price();
        uint256 totalBorrowAssetsForCurrentLastMultiplier = totalBorrowAssetsForMultiplier[
                id
            ][lastMultiplier];
        uint256 totalBorrowSharesForCurrentLastMultiplier = totalBorrowSharesForMultiplier[
                id
            ][lastMultiplier];
        {
            require(
                !_isHealthy(marketParams, id, borrower, collateralPrice),
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
                    collateralPrice,
                    ORACLE_PRICE_SCALE
                );

                repaidShares = seizedAssetsQuoted
                    .wDivUp(liquidationIncentiveFactor)
                    .toSharesUp(
                        totalBorrowAssetsForCurrentLastMultiplier,
                        totalBorrowSharesForCurrentLastMultiplier
                    );
            } else {
                seizedAssets = repaidShares
                    .toAssetsDown(
                        totalBorrowAssetsForCurrentLastMultiplier,
                        totalBorrowSharesForCurrentLastMultiplier
                    )
                    .wMulDown(liquidationIncentiveFactor)
                    .mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
            }
        }
        uint256 repaidAssets = repaidShares.toAssetsUp(
            totalBorrowAssetsForCurrentLastMultiplier,
            totalBorrowSharesForCurrentLastMultiplier
        );

        currentPosition.borrowShares -= repaidShares.toUint128();
        totalBorrowSharesForCurrentLastMultiplier -= uint128(repaidShares);
        totalBorrowSharesForMultiplier[id][
            lastMultiplier
        ] = totalBorrowSharesForCurrentLastMultiplier;

        totalBorrowAssetsForCurrentLastMultiplier = UtilsLib
            .zeroFloorSub(
                totalBorrowAssetsForCurrentLastMultiplier,
                repaidAssets
            )
            .toUint128();
        totalBorrowAssetsForMultiplier[id][
            lastMultiplier
        ] = totalBorrowAssetsForCurrentLastMultiplier;

        currentMarket.totalBorrowAssets = UtilsLib
            .zeroFloorSub(currentMarket.totalBorrowAssets, repaidAssets)
            .toUint128();
        currentPosition.collateral -= seizedAssets.toUint128();

        _updatePosition(marketParams, id, borrower, 0, 0, UPDATE_TYPE.IDLE);

        uint256 badDebtShares;
        uint256 badDebtAssets;
        if (currentPosition.collateral == 0) {
            badDebtShares = currentPosition.borrowShares;
            badDebtAssets = UtilsLib.min(
                totalBorrowAssetsForCurrentLastMultiplier,
                badDebtShares.toAssetsUp(
                    totalBorrowAssetsForCurrentLastMultiplier,
                    totalBorrowAssetsForCurrentLastMultiplier
                )
            );

            currentMarket.totalBorrowAssets -= badDebtAssets.toUint128();

            currentMarket.totalSupplyAssets -= uint128(badDebtAssets);
            totalBorrowAssetsForMultiplier[id][lastMultiplier] -= uint128(
                badDebtAssets
            );
            totalBorrowSharesForMultiplier[id][lastMultiplier] -= badDebtShares
                .toUint128();

            currentPosition.borrowShares = 0;
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
            IMoreLiquidateCallback(msg.sender).onMoreLiquidate(
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

        IMoreFlashLoanCallback(msg.sender).onMoreFlashLoan(assets, data);

        IERC20(token).safeTransferFrom(msg.sender, address(this), assets);
    }

    /* AUTHORIZATION */

    /// @inheritdoc IMoreMarketsBase
    function setAuthorization(
        address authorized,
        bool newIsAuthorized
    ) external {
        if (newIsAuthorized == isAuthorized[msg.sender][authorized])
            revert ErrorsLib.AlreadySet();

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
        if (market[id].lastUpdate == 0) revert ErrorsLib.MarketNotCreated();

        _accrueInterest(marketParams, id);
    }

    /// @dev Accrues interest for the given market `marketParams`.
    /// @dev Assumes that the inputs `marketParams` and `id` match.
    function _accrueInterest(MarketParams memory marketParams, Id id) internal {
        uint256 elapsed = block.timestamp - market[id].lastUpdate;
        Market storage currentMarket = market[id];
        if (elapsed == 0) return;

        if (marketParams.irm != address(0)) {
            uint256 borrowRate = IIrm(marketParams.irm).borrowRate(
                marketParams,
                currentMarket
            );

            uint256 totalInterest;
            // interest generated by premium users that have LTV above default LLTV.
            uint256 premiumFeeAccumulated;
            uint256 premiumFee = currentMarket.premiumFee;
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
                uint256 totalBorrowAssetsForCurrentMultiplier = totalBorrowAssetsForMultiplier[
                        id
                    ][currentMultiplier];
                interestForMultiplier = totalBorrowAssetsForCurrentMultiplier
                    .wMulDown(borrowRate.wTaylorCompounded(elapsed))
                    .wMulDown(currentMultiplier);

                totalInterest += interestForMultiplier;

                uint256 premiumFeeGeneratedForMultiplier;
                if (
                    currentMultiplier != DEFAULT_MULTIPLIER && premiumFee != 0
                ) {
                    uint256 premiumFeeMulAddition = uint256(premiumFee)
                        .wMulDown(currentMultiplier);
                    premiumFeeGeneratedForMultiplier = totalBorrowAssetsForCurrentMultiplier
                        .wMulDown(borrowRate.wTaylorCompounded(elapsed))
                        .wMulDown(premiumFeeMulAddition);
                    premiumFeeAccumulated += premiumFeeGeneratedForMultiplier;
                }

                totalBorrowAssetsForMultiplier[id][currentMultiplier] +=
                    interestForMultiplier +
                    premiumFeeGeneratedForMultiplier;

                unchecked {
                    ++i;
                }
            }

            currentMarket.totalBorrowAssets +=
                totalInterest.toUint128() +
                premiumFeeAccumulated.toUint128();
            currentMarket.totalSupplyAssets += uint128(totalInterest);

            uint256 feeShares;
            if (currentMarket.fee != 0 || premiumFee != 0) {
                uint256 feeAmount = totalInterest.wMulDown(currentMarket.fee) +
                    premiumFeeAccumulated;
                // The fee amount is subtracted from the total supply in this calculation to compensate for the fact
                // that total supply is already increased by the full interest (including the fee amount).
                feeShares = feeAmount.toSharesDown(
                    currentMarket.totalSupplyAssets - feeAmount,
                    currentMarket.totalSupplyShares
                );
                position[id][feeRecipient].supplyShares += feeShares
                    .toUint128();
                currentMarket.totalSupplyShares += uint128(feeShares);
            }

            emit EventsLib.AccrueInterest(
                id,
                borrowRate,
                totalInterest,
                feeShares
            );
        }

        // Safe "unchecked" cast.
        currentMarket.lastUpdate = uint128(block.timestamp);
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
        Position storage currentPosition = position[id][borrower];

        if (marketParams.isPremiumMarket) {
            (bool success, bytes memory data) = address(
                marketParams.creditAttestationService
            ).staticcall(
                    abi.encodeWithSelector(
                        ICreditAttestationService.getScore.selector,
                        borrower
                    )
                );

            uint256 currentScore;
            lastMultiplier = currentPosition.lastMultiplier;
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
            lastMultiplier = DEFAULT_MULTIPLIER;
        }

        uint256 borrowed = uint256(currentPosition.borrowShares).toAssetsUp(
            totalBorrowAssetsForMultiplier[id][lastMultiplier],
            totalBorrowSharesForMultiplier[id][lastMultiplier]
        );

        uint256 maxBorrow = uint256(currentPosition.collateral)
            .mulDivDown(collateralPrice, ORACLE_PRICE_SCALE)
            .wMulDown(lltvToUse);

        return maxBorrow >= borrowed;
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
        Position storage currentPosition = position[id][borrower];
        Market storage currentMarket = market[id];
        if (currentPosition.lastMultiplier == 0)
            currentPosition.lastMultiplier = DEFAULT_MULTIPLIER;
        uint64 lastMultiplier = currentPosition.lastMultiplier;

        uint256 totalBorrowAssetsForCurrentLastMultiplier = totalBorrowAssetsForMultiplier[
                id
            ][lastMultiplier];
        uint256 totalBorrowSharesForCurrentLastMultiplier = totalBorrowSharesForMultiplier[
                id
            ][lastMultiplier];

        if (shares > 0)
            if (updateType == UPDATE_TYPE.BORROW) {
                assets = shares.toAssetsDown(
                    totalBorrowAssetsForCurrentLastMultiplier,
                    totalBorrowSharesForCurrentLastMultiplier
                );
            } else if (updateType == UPDATE_TYPE.REPAY) {
                assets = shares.toAssetsUp(
                    totalBorrowAssetsForCurrentLastMultiplier,
                    totalBorrowSharesForCurrentLastMultiplier
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
            totalBorrowAssetsForCurrentLastMultiplier,
            totalBorrowSharesForCurrentLastMultiplier
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
            currentPosition.borrowShares += shares.toUint128();
            totalBorrowAssetsForMultiplier[id][currentMultiplier] += assets
                .toUint128();
            totalBorrowSharesForMultiplier[id][currentMultiplier] += uint128(
                shares
            );
            currentMarket.totalBorrowAssets += uint128(assets);
        } else if (updateType == UPDATE_TYPE.REPAY) {
            currentPosition.borrowShares -= shares.toUint128();

            totalBorrowAssetsForMultiplier[id][currentMultiplier] -= assets
                .toUint128();

            totalBorrowSharesForMultiplier[id][currentMultiplier] -= uint128(
                shares
            );
            currentMarket.totalBorrowAssets = UtilsLib
                .zeroFloorSub(currentMarket.totalBorrowAssets, assets)
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
        Position storage currentPosition = position[id][borrower];
        uint64 lastMultiplier = currentPosition.lastMultiplier;

        uint256 collateralPrice = IOracle(marketParams.oracle).price();
        uint256 borrowedBefore = uint256(currentPosition.borrowShares)
            .toAssetsUp(
                totalBorrowAssetsForMultiplier[id][lastMultiplier],
                totalBorrowSharesForMultiplier[id][lastMultiplier]
            );
        uint256 borrowed = updateType == UPDATE_TYPE.BORROW
            ? borrowedBefore + assets
            : borrowedBefore - assets;

        (bool success, bytes memory data) = address(
            marketParams.creditAttestationService
        ).staticcall(
                abi.encodeWithSelector(
                    ICreditAttestationService.getScore.selector,
                    borrower
                )
            );

        uint256 maxBorrowByDefault = uint256(currentPosition.collateral)
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
        } else revert ErrorsLib.InsufficientCollateral();

        uint256 maxBorrowByScore = uint256(currentPosition.collateral)
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
                        uint256(marketParams.irxMaxLltv - DEFAULT_MULTIPLIER)
                            .wDivUp(categoryStepNumber * 10 ** 18)
                    ) * i) + DEFAULT_MULTIPLIER
                );
                break;
            }
            nextStep += step;
            unchecked {
                ++i;
            }
        }
        if (multiplier == 0) multiplier = lastMultiplier;
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
        Market storage currentMarket = market[id];
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
            currentMarket.totalBorrowAssets += assets.toUint128();
        } else if (updateType == UPDATE_TYPE.REPAY) {
            newAssets -= assets;
            currentMarket.totalBorrowAssets = UtilsLib
                .zeroFloorSub(currentMarket.totalBorrowAssets, assets)
                .toUint128();
        }

        Position storage currentPosition = position[id][borrower];
        uint256 newShares = newAssets.toSharesUp(
            totalBorrowAssetsForMultiplier[id][newMultiplier],
            totalBorrowSharesForMultiplier[id][newMultiplier]
        );

        // update borrow shares
        currentPosition.borrowShares = newShares.toUint128();
        // add to new category
        totalBorrowAssetsForMultiplier[id][newMultiplier] += newAssets;
        totalBorrowSharesForMultiplier[id][newMultiplier] += newShares;
        // update last category
        currentPosition.lastMultiplier = newMultiplier;
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
        MarketParams storage currentMarketParams = _idToMarketParams[id];
        uint256[] memory categoryLltvs = currentMarketParams.categoryLltv;
        return (
            currentMarketParams.isPremiumMarket,
            currentMarketParams.loanToken,
            currentMarketParams.collateralToken,
            currentMarketParams.oracle,
            currentMarketParams.irm,
            currentMarketParams.lltv,
            currentMarketParams.creditAttestationService,
            currentMarketParams.irxMaxLltv,
            categoryLltvs
        );
    }

    /* INTERNAL SETTER FUNCTIONS */

    /// @notice Internal function that sets the `irxMaxAvailable` value.
    /// @param _irxMaxAvailable The new `irxMaxAvailable` value.
    function _setIrxMax(uint256 _irxMaxAvailable) internal {
        if (irxMaxAvailable == _irxMaxAvailable) revert ErrorsLib.AlreadySet();

        irxMaxAvailable = _irxMaxAvailable;

        emit EventsLib.SetIrxMaxAvailable(_irxMaxAvailable);
    }

    /// @notice Internal function that sets the `maxLltvForCategory` value.
    /// @param _maxLltvForCategory The new `maxLltvForCategory` value.
    function _setMaxLltvForCategory(uint256 _maxLltvForCategory) internal {
        if (maxLltvForCategory == _maxLltvForCategory)
            revert ErrorsLib.AlreadySet();

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
            bytes32 slot;
            unchecked {
                slot = slots[i++];
            }
            assembly ("memory-safe") {
                mstore(add(res, mul(i, 32)), sload(slot))
            }
        }
    }
}
