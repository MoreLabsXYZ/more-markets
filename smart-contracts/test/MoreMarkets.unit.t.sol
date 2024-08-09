// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Vm, StdCheats, Test, console} from "forge-std/Test.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id, MathLib} from "../contracts/MoreMarkets.sol";
import {DebtTokenFactory} from "../contracts/factories/DebtTokenFactory.sol";
import {DebtToken} from "../contracts/tokens/DebtToken.sol";
import {ICredoraMetrics} from "../contracts/interfaces/ICredoraMetrics.sol";
import {OracleMock} from "../contracts/mocks/OracleMock.sol";
import {AdaptiveCurveIrm} from "../contracts/AdaptiveCurveIrm.sol";
import {ERC20MintableMock} from "../contracts/mocks/ERC20MintableMock.sol";

contract MoreMarketsTest is Test {
    using MarketParamsLib for MarketParams;
    using MathLib for uint256;

    uint256 sepoliaFork;

    ICredoraMetrics public credora =
        ICredoraMetrics(address(0xA1CE4fD8470718eB3e8248E40ab489856E125F59));
    address public credoraAdmin =
        address(0x98ADc891Efc9Ce18cA4A63fb0DfbC2864566b5Ab);
    OracleMock public oracle =
        OracleMock(0xC1aB56955958Ac8379567157740F18AAadD8cD04);

    MoreMarkets public markets;
    DebtTokenFactory public debtTokenFactory;
    DebtToken public debtToken;
    address public owner = address(0x89a76D7a4D006bDB9Efd0923A346fAe9437D434F);
    AdaptiveCurveIrm public irm;

    uint256[] public lltvs = [
        800000000000000000,
        945000000000000000,
        965000000000000000
    ];

    uint8 numberOfPremiumBuckets = 5;
    uint128[] public premiumLltvs = [
        1000000000000000000,
        1200000000000000000,
        1400000000000000000,
        1600000000000000000,
        2000000000000000000
    ];
    uint112[] public categoryMultipliers = [
        2 ether,
        2 ether,
        2 ether,
        2 ether,
        2 ether
    ];
    uint16[] public categorySteps = [4, 8, 12, 16, 24];

    ERC20MintableMock public loanToken;
    ERC20MintableMock public collateralToken;
    MarketParams public marketParams;

    uint256 globalSnapshotId;

    function setUp() public {
        sepoliaFork = vm.createFork(
            "https://eth-sepolia.g.alchemy.com/v2/jXLoZTSjTIhZDB9nNhJsSmvrcMAbdrNT"
        );
        vm.selectFork(sepoliaFork);

        debtToken = new DebtToken();
        debtTokenFactory = new DebtTokenFactory(address(debtToken));
        markets = new MoreMarkets(owner, address(debtTokenFactory));
        irm = new AdaptiveCurveIrm(address(markets));

        startHoax(owner);
        markets.enableIrm(address(irm));
        markets.setCredora(address(credora));

        for (uint256 i; i < lltvs.length; ) {
            markets.enableLltv(lltvs[i]);
            unchecked {
                ++i;
            }
        }

        loanToken = new ERC20MintableMock(owner);
        collateralToken = new ERC20MintableMock(owner);

        marketParams = MarketParams(
            address(loanToken),
            address(collateralToken),
            address(oracle),
            address(irm),
            lltvs[0]
        );
        markets.createMarket(marketParams);
        Id id = marketParams.id();

        markets.setCategoryInfo(
            id,
            categoryMultipliers,
            categorySteps,
            premiumLltvs
        );

        loanToken.mint(address(owner), 1000000 ether);
        loanToken.approve(address(markets), 1000000 ether);
        collateralToken.mint(address(owner), 1000000 ether);
        collateralToken.approve(address(markets), 1000000 ether);

        markets.supply(marketParams, 10000 ether, 0, owner, "");
    }

    function test_deployment() public view {
        assertTrue(markets.isIrmEnabled(address(irm)));
        assertEq(address(markets.credoraMetrics()), address(credora));
        assertEq(markets.owner(), owner);
    }

    function test_borrow_correctlyWithShares() public {
        startHoax(credoraAdmin);
        credora.grantPermission(owner, address(markets), type(uint128).max);

        startHoax(owner);
        markets.supplyCollateral(marketParams, 1000 ether, owner, "");

        // default lltv 80%
        // premium lltv 100%
        uint256 defaultBorrow = 800 ether;
        markets.borrow(
            marketParams,
            0,
            (defaultBorrow + 1) * 10 ** 6,
            owner,
            owner
        );
        (, , , uint64 lastMultiplier, , ) = markets.position(
            marketParams.id(),
            owner
        );
        assertEq(lastMultiplier, 1.25 ether);
    }

    function test_borrow_checkBorrowMultipliersForCategoryE() public {
        startHoax(credoraAdmin);
        credora.grantPermission(owner, address(markets), type(uint128).max);

        startHoax(owner);
        markets.supplyCollateral(marketParams, 1000 ether, owner, "");

        // default lltv 80%
        // premium lltv 100%
        _checkCorrectMultipliersOnBorrow(
            800 ether,
            1000 ether,
            categorySteps[0]
        );
    }

    function test_borrow_checkBorrowMultipliersForCategoryD() public {
        startHoax(credoraAdmin);
        credora.setData(
            0,
            abi.encode(
                owner,
                uint64(201 * 10 ** 6),
                uint64(0),
                bytes8("AAA+"),
                uint64(0),
                uint64(0),
                uint64(0)
            ),
            ""
        );
        credora.grantPermission(owner, address(markets), type(uint128).max);

        startHoax(owner);
        markets.supplyCollateral(marketParams, 1000 ether, owner, "");

        // default lltv 80%
        // premium lltv 120%
        _checkCorrectMultipliersOnBorrow(
            800 ether,
            1200 ether,
            categorySteps[1]
        );
    }

    function test_borrow_checkBorrowMultipliersForCategoryC() public {
        startHoax(credoraAdmin);
        credora.setData(
            0,
            abi.encode(
                owner,
                uint64(401 * 10 ** 6),
                uint64(0),
                bytes8("AAA+"),
                uint64(0),
                uint64(0),
                uint64(0)
            ),
            ""
        );
        credora.grantPermission(owner, address(markets), type(uint128).max);

        startHoax(owner);
        markets.supplyCollateral(marketParams, 1000 ether, owner, "");

        // default lltv 80%
        // premium lltv 140%
        _checkCorrectMultipliersOnBorrow(
            800 ether,
            1400 ether,
            categorySteps[2]
        );
    }
    function test_borrow_checkBorrowMultipliersForCategoryB() public {
        startHoax(credoraAdmin);
        credora.setData(
            0,
            abi.encode(
                owner,
                uint64(601 * 10 ** 6),
                uint64(0),
                bytes8("AAA+"),
                uint64(0),
                uint64(0),
                uint64(0)
            ),
            ""
        );
        credora.grantPermission(owner, address(markets), type(uint128).max);

        startHoax(owner);
        markets.supplyCollateral(marketParams, 1000 ether, owner, "");

        // default lltv 80%
        // premium lltv 160%
        _checkCorrectMultipliersOnBorrow(
            800 ether,
            1600 ether,
            categorySteps[3]
        );
    }
    function test_borrow_checkBorrowMultipliersForCategoryA() public {
        startHoax(credoraAdmin);
        credora.setData(
            0,
            abi.encode(
                owner,
                uint64(800 * 10 ** 6),
                uint64(0),
                bytes8("AAA+"),
                uint64(0),
                uint64(0),
                uint64(0)
            ),
            ""
        );
        credora.grantPermission(owner, address(markets), type(uint128).max);

        startHoax(owner);
        markets.supplyCollateral(marketParams, 1000 ether, owner, "");

        // default lltv 80%
        // premium lltv 200%
        _checkCorrectMultipliersOnBorrow(
            800 ether,
            2000 ether,
            categorySteps[4]
        );
    }

    function test_repay_checkBorrowMultipliersForCategoryE() public {
        startHoax(credoraAdmin);
        credora.grantPermission(owner, address(markets), type(uint128).max);

        startHoax(owner);
        markets.supplyCollateral(marketParams, 1000 ether, owner, "");

        // default lltv 80%
        // premium lltv 100%
        _checkCorrectMultipliersOnRepay(
            800 ether,
            1000 ether,
            categorySteps[0]
        );
    }

    function test_repay_checkBorrowMultipliersForCategoryD() public {
        startHoax(credoraAdmin);
        credora.setData(
            0,
            abi.encode(
                owner,
                uint64(201 * 10 ** 6),
                uint64(0),
                bytes8("AAA+"),
                uint64(0),
                uint64(0),
                uint64(0)
            ),
            ""
        );
        credora.grantPermission(owner, address(markets), type(uint128).max);

        startHoax(owner);
        markets.supplyCollateral(marketParams, 1000 ether, owner, "");

        // default lltv 80%
        // premium lltv 120%
        _checkCorrectMultipliersOnRepay(
            800 ether,
            1200 ether,
            categorySteps[1]
        );
    }

    function test_repay_checkBorrowMultipliersForCategoryC() public {
        startHoax(credoraAdmin);
        credora.setData(
            0,
            abi.encode(
                owner,
                uint64(401 * 10 ** 6),
                uint64(0),
                bytes8("AAA+"),
                uint64(0),
                uint64(0),
                uint64(0)
            ),
            ""
        );
        credora.grantPermission(owner, address(markets), type(uint128).max);

        startHoax(owner);
        markets.supplyCollateral(marketParams, 1000 ether, owner, "");

        // default lltv 80%
        // premium lltv 140%
        _checkCorrectMultipliersOnRepay(
            800 ether,
            1400 ether,
            categorySteps[2]
        );
    }
    function test_repay_checkBorrowMultipliersForCategoryB() public {
        startHoax(credoraAdmin);
        credora.setData(
            0,
            abi.encode(
                owner,
                uint64(601 * 10 ** 6),
                uint64(0),
                bytes8("AAA+"),
                uint64(0),
                uint64(0),
                uint64(0)
            ),
            ""
        );
        credora.grantPermission(owner, address(markets), type(uint128).max);

        startHoax(owner);
        markets.supplyCollateral(marketParams, 1000 ether, owner, "");

        // default lltv 80%
        // premium lltv 160%
        _checkCorrectMultipliersOnRepay(
            800 ether,
            1600 ether,
            categorySteps[3]
        );
    }
    function test_repay_checkBorrowMultipliersForCategoryA() public {
        startHoax(credoraAdmin);
        credora.setData(
            0,
            abi.encode(
                owner,
                uint64(800 * 10 ** 6),
                uint64(0),
                bytes8("AAA+"),
                uint64(0),
                uint64(0),
                uint64(0)
            ),
            ""
        );
        credora.grantPermission(owner, address(markets), type(uint128).max);

        startHoax(owner);
        markets.supplyCollateral(marketParams, 1000 ether, owner, "");

        // default lltv 80%
        // premium lltv 200%
        _checkCorrectMultipliersOnRepay(
            800 ether,
            2000 ether,
            categorySteps[4]
        );
    }

    function test_borrow_scenarioForCategoryE() public {
        startHoax(credoraAdmin);
        credora.grantPermission(owner, address(markets), type(uint128).max);

        startHoax(owner);
        markets.supplyCollateral(marketParams, 1000 ether, owner, "");

        markets.borrow(marketParams, 999 ether, 0, owner, owner);
        (, , , uint64 lastMultiplier, , ) = markets.position(
            marketParams.id(),
            owner
        );
        assertEq(lastMultiplier, 2 ether);

        // to 820
        markets.repay(marketParams, 179 ether, 0, owner, "");
        (, , , lastMultiplier, , ) = markets.position(marketParams.id(), owner);
        assertEq(lastMultiplier, 1.25 ether);

        // to 890
        markets.borrow(marketParams, 70 ether, 0, owner, owner);
        (, , , lastMultiplier, , ) = markets.position(marketParams.id(), owner);
        assertEq(lastMultiplier, 1.5 ether);

        // to 930
        markets.borrow(marketParams, 40 ether, 0, owner, owner);
        (, , , lastMultiplier, , ) = markets.position(marketParams.id(), owner);
        assertEq(lastMultiplier, 1.75 ether);

        // to 951
        markets.borrow(marketParams, 21 ether, 0, owner, owner);
        (, , , lastMultiplier, , ) = markets.position(marketParams.id(), owner);
        assertEq(lastMultiplier, 2 ether);

        // to 1001
        vm.expectRevert("insufficient collateral");
        markets.borrow(marketParams, 50 ether, 0, owner, owner);
    }

    function test_borrow_scenarioForCategoryA() public {
        startHoax(credoraAdmin);

        credora.setData(
            0,
            abi.encode(
                owner,
                uint64(900 * 10 ** 6),
                uint64(0),
                bytes8("AAA+"),
                uint64(0),
                uint64(0),
                uint64(0)
            ),
            ""
        );
        credora.grantPermission(owner, address(markets), type(uint128).max);

        startHoax(owner);
        markets.supplyCollateral(marketParams, 1000 ether, owner, "");

        markets.borrow(marketParams, 1999 ether, 0, owner, owner);
        (, , , uint64 lastMultiplier, , ) = markets.position(
            marketParams.id(),
            owner
        );
        assertApproxEqAbs(lastMultiplier, 2 ether, 10 ** 3);

        uint256 multiplierStep = (uint256(1 ether)).wDivUp(
            uint256(categorySteps[4]) * 10 ** 18
        );

        // to 820
        markets.repay(marketParams, 1179 ether, 0, owner, "");
        (, , , lastMultiplier, , ) = markets.position(marketParams.id(), owner);
        assertApproxEqAbs(lastMultiplier, 1 ether + multiplierStep, 10 ** 3);

        // to 890
        markets.borrow(marketParams, 70 ether, 0, owner, owner);
        (, , , lastMultiplier, , ) = markets.position(marketParams.id(), owner);
        assertApproxEqAbs(
            lastMultiplier,
            1 ether + multiplierStep * 2,
            10 ** 3
        );

        // to 930
        markets.borrow(marketParams, 40 ether, 0, owner, owner);
        (, , , lastMultiplier, , ) = markets.position(marketParams.id(), owner);
        assertApproxEqAbs(
            lastMultiplier,
            1 ether + multiplierStep * 3,
            10 ** 3
        );

        // to 2001
        vm.expectRevert("insufficient collateral");
        markets.borrow(marketParams, 1071 ether, 0, owner, owner);

        // to 2000
        markets.borrow(marketParams, 1070 ether, 0, owner, owner);
        (, , , lastMultiplier, , ) = markets.position(marketParams.id(), owner);
        assertApproxEqAbs(lastMultiplier, 2 ether, 10 ** 3);
    }

    // should correctly distribute debt and yield
    function test_borrow_threeUsersTwoOfThemPremium() public {
        startHoax(credoraAdmin);

        address userNonPrem = address(0x1010);
        address userE = address(0xeeee);
        address userB = address(0xbbbb);
        address oneMoreLender = address(0x1e9de6);

        credora.setData(
            0,
            abi.encode(
                userE,
                uint64(100 * 10 ** 6),
                uint64(0),
                bytes8(""),
                uint64(0),
                uint64(0),
                uint64(0)
            ),
            ""
        );
        credora.setData(
            0,
            abi.encode(
                userB,
                uint64(700 * 10 ** 6),
                uint64(0),
                bytes8(""),
                uint64(0),
                uint64(0),
                uint64(0)
            ),
            ""
        );
        credora.grantPermission(userE, address(markets), type(uint128).max);
        credora.grantPermission(userB, address(markets), type(uint128).max);

        startHoax(owner);
        collateralToken.mint(address(userE), 1000000 ether);
        collateralToken.mint(address(userB), 1000000 ether);
        collateralToken.mint(address(userNonPrem), 1000000 ether);
        loanToken.mint(address(userE), 1000000 ether);
        loanToken.mint(address(userB), 1000000 ether);
        loanToken.mint(address(userNonPrem), 1000000 ether);
        loanToken.mint(address(oneMoreLender), 1000000 ether);

        startHoax(oneMoreLender);
        loanToken.approve(address(markets), 1000000 ether);
        markets.supply(marketParams, 5000 ether, 0, oneMoreLender, "");

        startHoax(userE);
        uint256 userEAmountToBorrow = 899 ether;
        loanToken.approve(address(markets), 1000000 ether);
        collateralToken.approve(address(markets), 1000000 ether);
        markets.supplyCollateral(marketParams, 1000 ether, userE, "");
        markets.borrow(marketParams, userEAmountToBorrow, 0, userE, userE);
        uint64 eUserMultiplier = 1.5 ether;
        (, , , uint256 lastMultiplier, , ) = markets.position(
            marketParams.id(),
            userE
        );
        assertApproxEqAbs(lastMultiplier, eUserMultiplier, 10 ** 3);

        startHoax(userB);
        uint256 userBAmountToBorrow = 1399 ether;
        loanToken.approve(address(markets), 1000000 ether);
        collateralToken.approve(address(markets), 1000000 ether);
        markets.supplyCollateral(marketParams, 1000 ether, userB, "");
        markets.borrow(marketParams, userBAmountToBorrow, 0, userB, userB);
        uint64 bUserMultiplier = 1.75 ether;
        (, , , lastMultiplier, , ) = markets.position(marketParams.id(), userB);
        assertApproxEqAbs(lastMultiplier, bUserMultiplier, 10 ** 3);

        startHoax(userNonPrem);
        uint256 userNonPremAmountToBorrow = 700 ether;
        loanToken.approve(address(markets), 1000000 ether);
        collateralToken.approve(address(markets), 1000000 ether);
        markets.supplyCollateral(marketParams, 1000 ether, userNonPrem, "");
        markets.borrow(
            marketParams,
            userNonPremAmountToBorrow,
            0,
            userNonPrem,
            userNonPrem
        );
        uint64 nonPremUserMultiplier = 1 ether;
        (, , , lastMultiplier, , ) = markets.position(
            marketParams.id(),
            userNonPrem
        );
        assertApproxEqAbs(lastMultiplier, nonPremUserMultiplier, 10 ** 3);

        uint256 timeToSkip = 1000;
        skip(timeToSkip);

        (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares,
            uint128 totalBorrowAssets,
            uint128 totalBorrowShares,
            uint128 lastUpdate,
            uint128 fee
        ) = markets.market(marketParams.id());
        uint256 borrowRate = irm.borrowRateView(
            marketParams,
            Market(
                totalSupplyAssets,
                totalSupplyShares,
                totalBorrowAssets,
                totalBorrowShares,
                lastUpdate,
                fee
            )
        );

        uint256 totalBorrowAssetsBefore = totalBorrowAssets;
        markets.accrueInterest(marketParams);

        uint256 sumOfInterests = userEAmountToBorrow
            .wMulDown(borrowRate.wMulDown(eUserMultiplier))
            .wTaylorCompounded(timeToSkip) +
            userBAmountToBorrow
                .wMulDown(borrowRate.wMulDown(bUserMultiplier))
                .wTaylorCompounded(timeToSkip) +
            userNonPremAmountToBorrow.wMulDown(borrowRate).wTaylorCompounded(
                timeToSkip
            );

        (
            totalSupplyAssets,
            totalSupplyShares,
            totalBorrowAssets,
            totalBorrowShares,
            lastUpdate,
            fee
        ) = markets.market(marketParams.id());

        // total interest calculated correctly
        assertEq(sumOfInterests, totalBorrowAssets - totalBorrowAssetsBefore);

        // now all users repaying
        globalSnapshotId = vm.snapshot();

        _userRepayAllDebtWithAssets(userNonPrem, nonPremUserMultiplier);
        _userRepayAllDebtWithAssets(userE, eUserMultiplier);
        _userRepayAllDebtWithAssets(userB, bUserMultiplier);

        vm.revertTo(globalSnapshotId);

        // same with shares
        _userRepayAllDebtWithShares(userNonPrem, nonPremUserMultiplier);
        _userRepayAllDebtWithShares(userE, eUserMultiplier);
        _userRepayAllDebtWithShares(userB, bUserMultiplier);

        // lenders interest calculated correctly
        // since owner lended 10000 and oneMoreLender lended 5000 at the same time, their ratio should be 2 / 1
        (uint256 ownerSupplyShares, , , , , ) = markets.position(
            marketParams.id(),
            owner
        );
        (uint256 oneMoreLenderSupplyShares, , , , , ) = markets.position(
            marketParams.id(),
            oneMoreLender
        );

        uint256 amountToWithdrawByOwner = uint256(totalSupplyAssets).mulDivDown(
            ownerSupplyShares,
            totalSupplyShares
        );
        _withdrawAllWithShares(owner, amountToWithdrawByOwner);

        uint256 amountToWithdrawByOneMoreLender = uint256(totalSupplyAssets)
            .mulDivDown(oneMoreLenderSupplyShares, totalSupplyShares);
        _withdrawAllWithShares(oneMoreLender, amountToWithdrawByOneMoreLender);
    }

    function test_liquidate_undercollateralizedPosition() public {
        startHoax(credoraAdmin);
        credora.setData(
            0,
            abi.encode(
                owner,
                uint64(700 * 10 ** 6),
                uint64(0),
                bytes8(""),
                uint64(0),
                uint64(0),
                uint64(0)
            ),
            ""
        );
        credora.grantPermission(owner, address(markets), type(uint128).max);

        startHoax(owner);
        markets.supplyCollateral(marketParams, 1000 ether, owner, "");

        markets.borrow(marketParams, 1600 ether, 0, owner, owner);
        skip(2000);

        uint256 newPrice = oracle.price() / 2;
        oracle.setPrice(newPrice);

        // console.log("liquidate1");
        markets.liquidate(marketParams, owner, 500 ether, 0, "");
        // console.log("liquidate2");
        markets.liquidate(marketParams, owner, 100 ether, 0, "");
        // console.log("liquidate3");
        markets.liquidate(marketParams, owner, 100 ether, 0, "");
        // console.log("liquidate4");
        markets.liquidate(marketParams, owner, 100 ether, 0, "");
        // console.log("liquidate5");
        markets.liquidate(marketParams, owner, 100 ether, 0, "");
        // console.log("liquidate6");
        markets.liquidate(marketParams, owner, 99 ether, 0, "");
        // console.log("liquidate7");
        markets.liquidate(marketParams, owner, 1 ether, 0, "");

        // markets.liquidate(marketParams, owner, 1000 ether, 0, "");
        // markets.liquidate(marketParams, owner, 1 ether, 0, "");
    }

    function _checkCorrectMultipliersOnBorrow(
        uint256 defaultBorrow,
        uint256 maxBorrow,
        uint256 numberOfSteps
    ) internal {
        uint256 borrowStep = (maxBorrow - defaultBorrow).wDivUp(
            numberOfSteps * 10 ** 18
        );
        uint256 multiplierStep = (uint256(1 ether)).wDivUp(
            numberOfSteps * 10 ** 18
        );

        markets.borrow(marketParams, defaultBorrow - 1, 0, owner, owner);
        (, , , uint64 lastMultiplier, , ) = markets.position(
            marketParams.id(),
            owner
        );
        assertEq(lastMultiplier, 1 ether);
        for (uint256 i = 0; i < numberOfSteps; ) {
            markets.borrow(marketParams, borrowStep, 0, owner, owner);
            (, , , lastMultiplier, , ) = markets.position(
                marketParams.id(),
                owner
            );
            assertApproxEqAbs(
                lastMultiplier,
                1 ether + multiplierStep * (i + 1),
                10 ** 3
            );

            unchecked {
                ++i;
            }
        }
    }

    function _checkCorrectMultipliersOnRepay(
        uint256 defaultBorrow,
        uint256 maxBorrow,
        uint256 numberOfSteps
    ) internal {
        uint256 borrowStep = (maxBorrow - defaultBorrow).wDivUp(
            numberOfSteps * 10 ** 18
        );
        uint256 multiplierStep = (uint256(1 ether)).wDivUp(
            numberOfSteps * 10 ** 18
        );

        markets.borrow(marketParams, maxBorrow, 0, owner, owner);
        (, , , uint64 lastMultiplier, , ) = markets.position(
            marketParams.id(),
            owner
        );
        assertApproxEqAbs(lastMultiplier, 2 ether, 10 ** 3);
        for (uint256 i = 0; i < numberOfSteps; ) {
            markets.repay(marketParams, borrowStep, 0, owner, "");
            (, , , lastMultiplier, , ) = markets.position(
                marketParams.id(),
                owner
            );
            assertApproxEqAbs(
                lastMultiplier,
                2 ether - multiplierStep * (i + 1),
                10 ** 3
            );

            unchecked {
                ++i;
            }
        }
    }

    function _userRepayAllDebtWithAssets(
        address user,
        uint64 userMultiplier
    ) internal {
        startHoax(user);
        uint256 userLoanBalanceBefore = loanToken.balanceOf(user);
        uint256 marketLoanBalanceBefore = loanToken.balanceOf(address(markets));

        uint256 amountToRepay = markets.totalBorrowAssetsForMultiplier(
            marketParams.id(),
            userMultiplier
        );
        markets.repay(marketParams, amountToRepay, 0, user, "");

        (, uint256 borrowShares, , , , ) = markets.position(
            marketParams.id(),
            user
        );
        assertApproxEqAbs(borrowShares, 0, 10 ** 3);

        assertApproxEqAbs(
            markets.totalBorrowSharesForMultiplier(
                marketParams.id(),
                userMultiplier
            ),
            0,
            10 ** 3
        );
        assertApproxEqAbs(
            markets.totalBorrowAssetsForMultiplier(
                marketParams.id(),
                userMultiplier
            ),
            0,
            10 ** 3
        );
        assertApproxEqAbs(
            loanToken.balanceOf(user),
            userLoanBalanceBefore - amountToRepay,
            10
        );
        assertApproxEqAbs(
            loanToken.balanceOf(address(markets)),
            marketLoanBalanceBefore + amountToRepay,
            10
        );
    }

    function _userRepayAllDebtWithShares(
        address user,
        uint64 userMultiplier
    ) internal {
        startHoax(user);
        uint256 userLoanBalanceBefore = loanToken.balanceOf(user);
        uint256 marketLoanBalanceBefore = loanToken.balanceOf(address(markets));
        uint256 amountToRepay = markets.totalBorrowAssetsForMultiplier(
            marketParams.id(),
            userMultiplier
        );
        uint256 sharesToRepay = markets.totalBorrowSharesForMultiplier(
            marketParams.id(),
            userMultiplier
        );
        markets.repay(marketParams, 0, sharesToRepay, user, "");
        (, uint256 borrowShares, , , , ) = markets.position(
            marketParams.id(),
            user
        );
        assertApproxEqAbs(borrowShares, 0, 10 ** 3);
        assertApproxEqAbs(
            markets.totalBorrowSharesForMultiplier(
                marketParams.id(),
                userMultiplier
            ),
            0,
            10 ** 3
        );
        assertApproxEqAbs(
            markets.totalBorrowAssetsForMultiplier(
                marketParams.id(),
                userMultiplier
            ),
            0,
            10 ** 3
        );
        assertApproxEqAbs(
            loanToken.balanceOf(user),
            userLoanBalanceBefore - amountToRepay,
            10
        );
        assertApproxEqAbs(
            loanToken.balanceOf(address(markets)),
            marketLoanBalanceBefore + amountToRepay,
            10
        );
    }

    function _withdrawAllWithShares(
        address user,
        uint256 amountToWithdraw
    ) internal {
        startHoax(user);

        uint256 userLoanBalanceBefore = loanToken.balanceOf(user);
        uint256 marketLoanBalanceBefore = loanToken.balanceOf(address(markets));
        (uint256 supplyShares, , , , , ) = markets.position(
            marketParams.id(),
            user
        );
        (uint128 totalSupplyAssets, uint128 totalSupplyShares, , , , ) = markets
            .market(marketParams.id());
        markets.withdraw(marketParams, 0, supplyShares, user, user);

        (
            uint128 newTotalSupplyAssets,
            uint128 newTotalSupplyShares,
            ,
            ,
            ,

        ) = markets.market(marketParams.id());
        assertApproxEqAbs(
            newTotalSupplyShares,
            totalSupplyShares - supplyShares,
            10 ** 3
        );
        assertApproxEqAbs(
            newTotalSupplyAssets,
            totalSupplyAssets - amountToWithdraw,
            10 ** 3
        );
        assertApproxEqAbs(
            loanToken.balanceOf(user),
            userLoanBalanceBefore + amountToWithdraw,
            10
        );
        assertApproxEqAbs(
            loanToken.balanceOf(address(markets)),
            marketLoanBalanceBefore - amountToWithdraw,
            10
        );
        (supplyShares, , , , , ) = markets.position(marketParams.id(), user);
        assertApproxEqAbs(supplyShares, 0, 10 ** 3);
    }
}
