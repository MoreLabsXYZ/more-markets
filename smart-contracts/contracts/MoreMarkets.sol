// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import "@morpho-org/morpho-blue/src/Morpho.sol";
import {ErrorsLib} from "@morpho-org/morpho-blue/src/Morpho.sol";
import {ICredoraMetrics} from "./interfaces/ICredoraMetrics.sol";
import "hardhat/console.sol";

/// @title MoreMarkets
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice The More Markets contract fork of Morpho-blue.
contract MoreMarkets is IMorphoStaticTyping {
    using MathLib for uint128;
    using MathLib for uint256;
    using UtilsLib for uint256;
    using SharesMathLib for uint256;
    using SafeTransferLib for IERC20;
    using MarketParamsLib for MarketParams;

    /* IMMUTABLES */

    enum UPDATE_TYPE {
        BORROW,
        REPAY,
        IDLE
    }

    /// @inheritdoc IMorphoBase
    bytes32 public immutable DOMAIN_SEPARATOR;

    /* STORAGE */

    /// @inheritdoc IMorphoBase
    address public owner;
    /// @inheritdoc IMorphoBase
    address public feeRecipient;
    /// @inheritdoc IMorphoStaticTyping
    mapping(Id => mapping(address => Position)) public position;
    /// @inheritdoc IMorphoStaticTyping
    mapping(Id => Market) public market;
    /// @inheritdoc IMorphoBase
    mapping(address => bool) public isIrmEnabled;
    /// @inheritdoc IMorphoBase
    mapping(uint256 => bool) public isLltvEnabled;
    /// @inheritdoc IMorphoBase
    mapping(address => mapping(address => bool)) public isAuthorized;
    /// @inheritdoc IMorphoBase
    mapping(address => uint256) public nonce;
    /// @inheritdoc IMorphoStaticTyping
    mapping(Id => MarketParams) public idToMarketParams;

    mapping(Id => mapping(bytes8 => uint256)) public raeToCustomLltv;

    mapping(Id => mapping(bytes8 => uint256))
        public totalBorrowAssetsForCategory;
    mapping(Id => mapping(bytes8 => uint256))
        public totalBorrowSharesForCategory;
    mapping(Id => mapping(address => bool)) public userExceededDefaultLltv;
    mapping(address => bytes8) private _userLastCategory;
    mapping(bytes8 => uint64) private _categoryMultiplier;

    mapping(Id => mapping(bytes8 => uint256)) public extraSharesForCategory;

    Id[] private _arrayOfMarkets;
    bytes8[] private _availableCategories;
    ICredoraMetrics public credoraMetrics;

    /* CONSTRUCTOR */

    /// @param newOwner The new owner of the contract.
    constructor(address newOwner) {
        require(newOwner != address(0), ErrorsLib.ZERO_ADDRESS);

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(DOMAIN_TYPEHASH, block.chainid, address(this))
        );
        owner = newOwner;

        emit EventsLib.SetOwner(newOwner);
    }

    /* MODIFIERS */

    /// @dev Reverts if the caller is not the owner.
    modifier onlyOwner() {
        require(msg.sender == owner, ErrorsLib.NOT_OWNER);
        _;
    }

    function arrayOfMarkets() external view returns (Id[] memory) {
        Id[] memory memArray = _arrayOfMarkets;
        return memArray;
    }

    /* ONLY OWNER FUNCTIONS */

    function setCredora(address credora) external onlyOwner {
        credoraMetrics = ICredoraMetrics(credora);
    }

    function setLltvToRae(
        Id marketId,
        bytes8 rae,
        uint256 lltv
    ) external onlyOwner {
        raeToCustomLltv[marketId][rae] = lltv;
    }

    // TODO: revisit logic of storing
    function setAvailableCategories(
        bytes8[] memory newAvailableCategories,
        uint64[] memory categoryMultipliers
    ) external onlyOwner {
        _availableCategories = newAvailableCategories;
        for (uint256 i; i < newAvailableCategories.length; ) {
            _categoryMultiplier[
                newAvailableCategories[i]
            ] = categoryMultipliers[i];

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IMorphoBase
    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != owner, ErrorsLib.ALREADY_SET);

        owner = newOwner;

        emit EventsLib.SetOwner(newOwner);
    }

    /// @inheritdoc IMorphoBase
    function enableIrm(address irm) external onlyOwner {
        require(!isIrmEnabled[irm], ErrorsLib.ALREADY_SET);

        isIrmEnabled[irm] = true;

        emit EventsLib.EnableIrm(irm);
    }

    /// @inheritdoc IMorphoBase
    function enableLltv(uint256 lltv) external onlyOwner {
        require(!isLltvEnabled[lltv], ErrorsLib.ALREADY_SET);
        require(lltv < WAD, ErrorsLib.MAX_LLTV_EXCEEDED);

        isLltvEnabled[lltv] = true;

        emit EventsLib.EnableLltv(lltv);
    }

    /// @inheritdoc IMorphoBase
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

    /// @inheritdoc IMorphoBase
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(newFeeRecipient != feeRecipient, ErrorsLib.ALREADY_SET);

        feeRecipient = newFeeRecipient;

        emit EventsLib.SetFeeRecipient(newFeeRecipient);
    }

    /* MARKET CREATION */

    /// @inheritdoc IMorphoBase
    function createMarket(MarketParams memory marketParams) external {
        Id id = marketParams.id();
        require(isIrmEnabled[marketParams.irm], ErrorsLib.IRM_NOT_ENABLED);
        require(isLltvEnabled[marketParams.lltv], ErrorsLib.LLTV_NOT_ENABLED);
        require(market[id].lastUpdate == 0, ErrorsLib.MARKET_ALREADY_CREATED);
        _arrayOfMarkets.push(id);

        // Safe "unchecked" cast.
        market[id].lastUpdate = uint128(block.timestamp);
        idToMarketParams[id] = marketParams;

        emit EventsLib.CreateMarket(id, marketParams);

        // Call to initialize the IRM in case it is stateful.
        if (marketParams.irm != address(0))
            IIrm(marketParams.irm).borrowRate(marketParams, market[id]);
    }

    /* SUPPLY MANAGEMENT */

    /// @inheritdoc IMorphoBase
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

        position[id][onBehalf].supplyShares += shares;
        market[id].totalSupplyShares += shares.toUint128();
        market[id].totalSupplyAssets += assets.toUint128();

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

    /// @inheritdoc IMorphoBase
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

        position[id][onBehalf].supplyShares -= shares;
        market[id].totalSupplyShares -= shares.toUint128();
        market[id].totalSupplyAssets -= assets.toUint128();

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

    /* BORROW MANAGEMENT */

    /// @inheritdoc IMorphoBase
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

        _updatePosition(
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

    /// @inheritdoc IMorphoBase
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

        _updatePosition(
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

    /// @inheritdoc IMorphoBase
    function supplyCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalf,
        bytes calldata data
    ) external {
        console.log("hi1");
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

    /// @inheritdoc IMorphoBase
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

    function updateBorrower(
        MarketParams memory marketParams,
        address borrower
    ) external {
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        _accrueInterest(marketParams, id);

        if (
            !_updatePosition(marketParams, id, borrower, 0, 0, UPDATE_TYPE.IDLE)
        ) {
            revert("No need for update");
        }
    }

    function _updatePosition(
        MarketParams memory marketParams,
        Id id,
        address borrower,
        uint256 assets,
        uint256 shares,
        UPDATE_TYPE updateType
    ) internal returns (bool isCategoryUpdated) {
        (bool success, bytes memory data) = address(credoraMetrics).staticcall(
            abi.encodeWithSignature("getRAE(address)", borrower)
        );

        bytes8 currentCategory;

        // TODO: decide what to do with shares
        if (
            _isDefaultLltvExceeded(
                marketParams,
                id,
                borrower,
                assets,
                updateType
            )
        ) {
            if (success && (data.length > 0)) {
                currentCategory = abi.decode(data, (bytes8));
            } else {
                revert(ErrorsLib.INSUFFICIENT_COLLATERAL);
            }
        }

        bytes8 lastCategory = _userLastCategory[borrower];
        if (assets > 0)
            shares = assets.toSharesUp(
                totalBorrowAssetsForCategory[id][currentCategory],
                totalBorrowSharesForCategory[id][currentCategory]
            );
        else if (shares > 0)
            assets = shares.toAssetsDown(
                totalBorrowAssetsForCategory[id][lastCategory],
                totalBorrowSharesForCategory[id][lastCategory]
            );

        uint256 borrowedSharesBefore = position[id][borrower].borrowShares;
        uint256 borrowedAssetsBefore;

        borrowedAssetsBefore = borrowedSharesBefore.toAssetsDown(
            totalBorrowAssetsForCategory[id][lastCategory],
            totalBorrowSharesForCategory[id][lastCategory]
        );
        if (lastCategory != currentCategory) {
            _updateCategory(
                id,
                lastCategory,
                currentCategory,
                borrower,
                updateType,
                borrowedAssetsBefore,
                borrowedSharesBefore,
                assets
            );
            isCategoryUpdated = true;
        } else if (updateType == UPDATE_TYPE.BORROW) {
            position[id][borrower].borrowShares += shares.toUint128();
            totalBorrowAssetsForCategory[id][currentCategory] += assets
                .toUint128();
            totalBorrowSharesForCategory[id][currentCategory] += shares
                .toUint128();
        } else if (updateType == UPDATE_TYPE.REPAY) {
            position[id][borrower].borrowShares += shares.toUint128();
            totalBorrowAssetsForCategory[id][currentCategory] -= assets
                .toUint128();
            totalBorrowSharesForCategory[id][currentCategory] -= shares
                .toUint128();
        }

        if (updateType == UPDATE_TYPE.BORROW)
            market[id].totalBorrowAssets += assets.toUint128();
        else if (updateType == UPDATE_TYPE.REPAY)
            market[id].totalBorrowAssets = UtilsLib
                .zeroFloorSub(market[id].totalBorrowAssets, assets)
                .toUint128();
    }

    function _updateCategory(
        Id id,
        bytes8 lastCategory,
        bytes8 newCategory,
        address borrower,
        UPDATE_TYPE updateType,
        uint256 borrowedAssetsBefore,
        uint256 borrowedSharesBefore,
        uint256 assets
    ) internal {
        // sub from prev category
        totalBorrowAssetsForCategory[id][lastCategory] -= borrowedAssetsBefore;
        totalBorrowSharesForCategory[id][lastCategory] -= borrowedSharesBefore;

        // calc new shares
        uint256 newAssets = borrowedAssetsBefore;
        if (updateType == UPDATE_TYPE.BORROW) newAssets += assets;
        else if (updateType == UPDATE_TYPE.REPAY) newAssets -= assets;

        uint256 newShares = newAssets.toSharesUp(
            totalBorrowAssetsForCategory[id][newCategory],
            totalBorrowSharesForCategory[id][newCategory]
        );

        // update borrow shares
        position[id][borrower].borrowShares = newShares.toUint128();
        // add to new category
        totalBorrowAssetsForCategory[id][newCategory] +=
            borrowedAssetsBefore +
            assets;
        totalBorrowSharesForCategory[id][newCategory] += newShares;

        // update last category
        _userLastCategory[borrower] = newCategory;
    }

    /* LIQUIDATION */

    /// @inheritdoc IMorphoBase
    function liquidate(
        MarketParams memory marketParams,
        address borrower,
        uint256 seizedAssets,
        uint256 repaidShares,
        bytes calldata data
    ) external returns (uint256, uint256) {
        console.log("hi2");
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        require(
            UtilsLib.exactlyOneZero(seizedAssets, repaidShares),
            ErrorsLib.INCONSISTENT_INPUT
        );

        _accrueInterest(marketParams, id);

        {
            uint256 collateralPrice = IOracle(marketParams.oracle).price();

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
                        totalBorrowAssetsForCategory[id][
                            _userLastCategory[borrower]
                        ],
                        totalBorrowSharesForCategory[id][
                            _userLastCategory[borrower]
                        ]
                    );
            } else {
                seizedAssets = repaidShares
                    .toAssetsDown(
                        totalBorrowAssetsForCategory[id][
                            _userLastCategory[borrower]
                        ],
                        totalBorrowSharesForCategory[id][
                            _userLastCategory[borrower]
                        ]
                    )
                    .wMulDown(liquidationIncentiveFactor)
                    .mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
            }
        }
        uint256 repaidAssets = repaidShares.toAssetsUp(
            totalBorrowAssetsForCategory[id][_userLastCategory[borrower]],
            totalBorrowSharesForCategory[id][_userLastCategory[borrower]]
        );

        console.log("some data");
        console.log(repaidAssets);
        console.log(repaidShares);
        console.log(position[id][borrower].borrowShares);
        position[id][borrower].borrowShares -= repaidShares.toUint128();
        console.log(position[id][borrower].borrowShares);
        totalBorrowSharesForCategory[id][
            _userLastCategory[borrower]
        ] -= repaidShares.toUint128();
        totalBorrowAssetsForCategory[id][_userLastCategory[borrower]] = UtilsLib
            .zeroFloorSub(
                totalBorrowAssetsForCategory[id][_userLastCategory[borrower]],
                repaidAssets
            )
            .toUint128();

        position[id][borrower].collateral -= seizedAssets.toUint128();

        uint256 badDebtShares;
        uint256 badDebtAssets;
        if (position[id][borrower].collateral == 0) {
            badDebtShares = position[id][borrower].borrowShares;
            badDebtAssets = UtilsLib.min(
                // TODO: not sure if we need here total borrow assets for all
                market[id].totalBorrowAssets,
                badDebtShares.toAssetsUp(
                    totalBorrowAssetsForCategory[id][
                        _userLastCategory[borrower]
                    ],
                    totalBorrowSharesForCategory[id][
                        _userLastCategory[borrower]
                    ]
                )
            );

            market[id].totalBorrowAssets -= badDebtAssets.toUint128();
            market[id].totalSupplyAssets -= badDebtAssets.toUint128();
            // TODO: possible underflow
            totalBorrowAssetsForCategory[id][
                _userLastCategory[borrower]
            ] -= badDebtAssets.toUint128();
            totalBorrowSharesForCategory[id][
                _userLastCategory[borrower]
            ] -= badDebtShares.toUint128();
            // market[id].totalBorrowShares -= badDebtShares.toUint128();
            position[id][borrower].borrowShares = 0;
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

    /// @inheritdoc IMorphoBase
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

    /// @inheritdoc IMorphoBase
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

    /// @inheritdoc IMorphoBase
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

    /// @inheritdoc IMorphoBase
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

            uint256 interest;
            //  = market[id].totalBorrowAssets.wMulDown(
            //     borrowRate.wTaylorCompounded(elapsed)
            // );
            for (uint256 i; i < _availableCategories.length; ) {
                bytes8 currentCategory = _availableCategories[i];

                if (totalBorrowAssetsForCategory[id][currentCategory] == 0)
                    continue;
                uint256 interestForCategory = totalBorrowAssetsForCategory[id][
                    currentCategory
                ].wMulDown(
                        borrowRate
                            .wMulDown(_categoryMultiplier[currentCategory])
                            .wTaylorCompounded(elapsed)
                    );
                interest += interestForCategory;

                totalBorrowAssetsForCategory[id][
                    currentCategory
                ] += interestForCategory;

                // // uint256 extraInterest = interestForCategory -
                // //     totalBorrowAssetsForCategory[id][currentCategory].wMulDown(
                // //         borrowRate.wTaylorCompounded(elapsed)
                // //     );
                // uint256 extraInterest = interestForCategory.wDivUp(
                //     _categoryMultiplier[currentCategory]
                // );

                // uint256 sharesToMint = extraInterest.toSharesUp(
                //     market[id].totalBorrowAssets,
                //     market[id].totalBorrowShares
                // );

                // extraSharesForCategory[id][currentCategory] += sharesToMint;

                unchecked {
                    ++i;
                }
            }
            // TODO: we need to mint shares to premium users
            market[id].totalBorrowAssets += interest.toUint128();
            market[id].totalSupplyAssets += interest.toUint128();

            uint256 feeShares;
            if (market[id].fee != 0) {
                uint256 feeAmount = interest.wMulDown(market[id].fee);
                // The fee amount is subtracted from the total supply in this calculation to compensate for the fact
                // that total supply is already increased by the full interest (including the fee amount).
                feeShares = feeAmount.toSharesDown(
                    market[id].totalSupplyAssets - feeAmount,
                    market[id].totalSupplyShares
                );
                position[id][feeRecipient].supplyShares += feeShares;
                market[id].totalSupplyShares += feeShares.toUint128();
            }

            emit EventsLib.AccrueInterest(id, borrowRate, interest, feeShares);
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
        (bool success, bytes memory data) = address(credoraMetrics).staticcall(
            abi.encodeWithSignature("getRAE(address)", borrower)
        );

        bytes8 currentCategory;
        bytes8 lastCategory = _userLastCategory[borrower];
        if (success) {
            currentCategory = abi.decode(data, (bytes8));
            lltvToUse = raeToCustomLltv[id][currentCategory];
        } else {
            lltvToUse = marketParams.lltv;
        }

        uint256 borrowed = uint256(position[id][borrower].borrowShares)
            .toAssetsUp(
                totalBorrowAssetsForCategory[id][lastCategory],
                totalBorrowSharesForCategory[id][lastCategory]
            );

        uint256 maxBorrow = uint256(position[id][borrower].collateral)
            .mulDivDown(collateralPrice, ORACLE_PRICE_SCALE)
            .wMulDown(lltvToUse);

        console.log(collateralPrice.wDivDown(ORACLE_PRICE_SCALE));
        console.log(position[id][borrower].collateral);
        console.log(maxBorrow);
        console.log(borrowed);

        return maxBorrow >= borrowed;
    }

    function _isDefaultLltvExceeded(
        MarketParams memory marketParams,
        Id id,
        address borrower,
        uint256 assets,
        UPDATE_TYPE updateType
    ) internal view returns (bool exceeded) {
        // can remove a lot of variable to avoid stack too deep
        uint256 collateralPrice = IOracle(marketParams.oracle).price();

        bytes8 lastCategory = _userLastCategory[borrower];
        uint256 totalBorrowAssets = totalBorrowAssetsForCategory[id][
            lastCategory
        ];
        uint256 totalBorrowShares = totalBorrowSharesForCategory[id][
            lastCategory
        ];

        uint256 borrowedBefore = uint256(position[id][borrower].borrowShares)
            .toAssetsUp(totalBorrowAssets, totalBorrowShares);

        uint256 borrowed = updateType == UPDATE_TYPE.BORROW
            ? borrowedBefore + assets
            : borrowedBefore - assets;

        uint256 maxBorrowByDefault = uint256(position[id][borrower].collateral)
            .mulDivDown(collateralPrice, ORACLE_PRICE_SCALE)
            .wMulDown(marketParams.lltv);

        if (borrowed > maxBorrowByDefault) exceeded = true;
    }

    /* STORAGE VIEW */

    /// @inheritdoc IMorphoBase
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
