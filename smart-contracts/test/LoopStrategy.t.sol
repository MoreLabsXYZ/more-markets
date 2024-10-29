// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {IMoreMarkets, Market, Position} from "../contracts/interfaces/IMoreMarkets.sol";
import {IMoreVaults} from "../contracts/interfaces/IMoreVaults.sol";
import {IMoreVaultsFactory} from "../contracts/interfaces/factories/IMoreVaultsFactory.sol";
import {Id, MoreMarkets, MarketParams, MarketParamsLib, MathLib, SharesMathLib} from "../contracts/MoreMarkets.sol";
import {MoreVaultsFactory, PremiumFeeInfo, ErrorsLib, OwnableUpgradeable} from "../contracts/MoreVaultsFactory.sol";
import {MoreVaults, IERC20Upgradeable, MathUpgradeable} from "../contracts/MoreVaults.sol";
import {ERC20MintableMock} from "../contracts/mocks/ERC20MintableMock.sol";
import {ICreditAttestationService} from "../contracts/interfaces/ICreditAttestationService.sol";
import {OracleMock} from "../contracts/mocks/OracleMock.sol";
import {AdaptiveCurveIrm} from "../contracts/AdaptiveCurveIrm.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {MoreUupsProxy} from "../contracts/proxy/MoreUupsProxy.sol";

import {LoopStrategy} from "../contracts/LoopStrategy.sol";
import {ICertificateToken} from "../contracts/interfaces/ankr/ICertificateToken.sol";
import {ILiquidTokenStakingPool} from "../contracts/interfaces/ILiquidTokenStakingPool.sol";
import {IWNative} from "../contracts/interfaces/bundlers/IWNative.sol";

contract LoopStrategyTest is Test {
    using MarketParamsLib for MarketParams;
    using MathUpgradeable for uint256;
    using MathLib for uint128;
    using MathLib for uint256;
    using SharesMathLib for uint256;

    ICertificateToken public ankrFlow =
        ICertificateToken(address(0x1b97100eA1D7126C4d60027e231EA4CB25314bdb));
    IWNative public wFlow =
        IWNative(address(0xd3bF53DAC106A0290B0483EcBC89d40FcC961f3e));
    ILiquidTokenStakingPool public staking =
        ILiquidTokenStakingPool(
            address(0xFE8189A3016cb6A3668b8ccdAC520CE572D4287a)
        );
    Id public marketId =
        Id.wrap(
            bytes32(
                0x2ae0c40dc06f58ff0243b44116cd48cc4bdab19e2474792fbf1f413600ceab3a
            )
        );
    uint256 targetUtilization = 0.9e18;
    uint256 targetStrategyLtv = 0.85e18;
    IMoreMarkets public markets =
        IMoreMarkets(0x94A2a9202EFf6422ab80B6338d41c89014E5DD72);
    IMoreVaults public vault =
        IMoreVaults(address(0xe2aaC46C1272EEAa49ec7e7B9e7d34B90aaDB966));

    TransparentUpgradeableProxy public transparentProxy;
    ProxyAdmin public proxyAdmin;
    LoopStrategy public implementation;
    LoopStrategy public strategy;
    address public owner = address(0x89a76D7a4D006bDB9Efd0923A346fAe9437D434F);

    uint256 sepoliaFork;
    uint256 flowTestnetFork;
    uint256 flowMainnetFork;

    address alice = address(0xABCD);
    address bob = address(0xABCE);

    uint256 constant MAX_TEST_DEPOSIT = 10000000 ether;
    uint256 constant MIN_TEST_DEPOSIT = 0.1 ether;

    function setUp() public {
        sepoliaFork = vm.createFork(
            "https://eth-sepolia.g.alchemy.com/v2/jXLoZTSjTIhZDB9nNhJsSmvrcMAbdrNT"
        );
        flowTestnetFork = vm.createFork("https://testnet.evm.nodes.onflow.org");
        flowMainnetFork = vm.createFork("https://mainnet.evm.nodes.onflow.org");
        vm.selectFork(flowMainnetFork);

        implementation = new LoopStrategy();
        transparentProxy = new TransparentUpgradeableProxy(
            address(implementation),
            address(owner),
            ""
        );
        strategy = LoopStrategy(payable(transparentProxy));
        strategy.initialize(
            owner,
            address(markets),
            address(vault),
            address(staking),
            address(wFlow),
            address(ankrFlow),
            marketId,
            targetUtilization,
            targetStrategyLtv,
            "LoopStrategy",
            "LS"
        );

        deal(alice, MAX_TEST_DEPOSIT * 1e5);
        deal(bob, MAX_TEST_DEPOSIT * 1e5);
    }

    function test_withdrawOnFork() public {
        alice = address(0xF56EcB3b2204f12069bf99E94Cf9a01F3DedC1c8);
        startHoax(alice);
        strategy = LoopStrategy(
            payable(address(0xBEe4769E53d1A6BABC4fC2E91F9B730770453bad))
        );

        uint256 amountToWithdraw = strategy.convertToAssets(
            strategy.balanceOf(alice)
        );
        (
            uint256 amountToRepay,
            uint256 wFlowAmount,
            uint256 ankrFlowAmount
        ) = strategy.expectedAmountsToWithdraw(amountToWithdraw);

        console.log("check");
        console.log(amountToRepay);
        console.log(amountToRepay + 1e13);
        wFlow.approve(address(strategy), amountToRepay + 1e13);
        strategy.withdraw(amountToWithdraw, alice, alice);
    }

    function test_deposit_oneUserSharesMintedCorrectly(
        uint256 amountToDeposit
    ) public {
        vm.assume(amountToDeposit > MIN_TEST_DEPOSIT);
        vm.assume(amountToDeposit < MAX_TEST_DEPOSIT);
        startHoax(alice);
        IWNative(wFlow).deposit{value: amountToDeposit * 1e4}();
        assertEq(wFlow.balanceOf(alice), amountToDeposit * 1e4);

        wFlow.approve(address(strategy), amountToDeposit);
        strategy.deposit(amountToDeposit, alice);

        assertEq(strategy.balanceOf(alice), amountToDeposit);
        assertApproxEqAbs(strategy.totalAssets(), amountToDeposit, 1e3);
        assertEq(
            strategy.convertToAssets(strategy.balanceOf(alice)),
            strategy.totalAssets()
        );

        Market memory market = markets.market(marketId);
        uint256 utilization = uint256(
            market.totalSupplyAssets > 0
                ? (market.totalBorrowAssets).wDivDown(market.totalSupplyAssets)
                : 0
        );
        assertLe(utilization, targetUtilization);

        Position memory position = markets.position(
            marketId,
            address(strategy)
        );

        assertEq(position.supplyShares, 0);
        assertGt(position.borrowShares, 0);
        assertGt(position.collateral, 0);
        assertGt(vault.balanceOf(address(strategy)), 0);
    }

    function test_deposit_oneUserUtilizationShouldBeLessThanTarget(
        uint256 amountToDeposit
    ) public {
        vm.assume(amountToDeposit > MIN_TEST_DEPOSIT);
        vm.assume(amountToDeposit < MAX_TEST_DEPOSIT);
        startHoax(alice);
        IWNative(wFlow).deposit{value: amountToDeposit * 1e4}();
        assertEq(wFlow.balanceOf(alice), amountToDeposit * 1e4);

        wFlow.approve(address(strategy), amountToDeposit);
        strategy.deposit(amountToDeposit, alice);

        Market memory market = markets.market(marketId);
        uint256 utilization = uint256(
            market.totalSupplyAssets > 0
                ? (market.totalBorrowAssets).wDivDown(market.totalSupplyAssets)
                : 0
        );
        assertLe(utilization, targetUtilization);
    }

    function test_deposit_shouldRevertIfUtilizationExceedsTarget() public {
        uint256 amountToDeposit = MAX_TEST_DEPOSIT;
        startHoax(alice);
        IWNative(wFlow).deposit{value: amountToDeposit * 1e4}();
        assertEq(wFlow.balanceOf(alice), amountToDeposit * 1e4);

        wFlow.approve(address(strategy), amountToDeposit);
        strategy.deposit(amountToDeposit, alice);

        Market memory market = markets.market(marketId);
        uint256 utilization = uint256(
            market.totalSupplyAssets > 0
                ? (market.totalBorrowAssets).wDivDown(market.totalSupplyAssets)
                : 0
        );
        assertApproxEqAbs(utilization, targetUtilization, 1);

        uint256 amountToDepositSecond = 1 ether;
        startHoax(bob);
        IWNative(wFlow).deposit{value: amountToDepositSecond}();
        assertEq(wFlow.balanceOf(bob), amountToDepositSecond);

        uint256 expectedMintedAmount = strategy.previewDeposit(
            amountToDepositSecond
        );
        wFlow.approve(address(strategy), amountToDepositSecond);
        vm.expectRevert(LoopStrategy.TargetUtilizationReached.selector);
        strategy.deposit(amountToDepositSecond, bob);
    }

    function test_deposit_twoUsersSharesMintedCorrectly(
        uint256 amountToDepositFirst,
        uint256 amountToDepositSecond
    ) public {
        vm.assume(amountToDepositFirst > MIN_TEST_DEPOSIT);
        vm.assume(amountToDepositFirst < MAX_TEST_DEPOSIT);
        vm.assume(amountToDepositSecond > MIN_TEST_DEPOSIT);
        vm.assume(amountToDepositSecond < MAX_TEST_DEPOSIT);

        startHoax(alice);
        IWNative(wFlow).deposit{value: amountToDepositFirst * 1e4}();
        assertEq(wFlow.balanceOf(alice), amountToDepositFirst * 1e4);

        // uint256 expectedMintedAmountAlice = strategy.previewDeposit(
        //     amountToDepositFirst
        // );
        wFlow.approve(address(strategy), amountToDepositFirst);
        strategy.deposit(amountToDepositFirst, alice);

        assertEq(strategy.balanceOf(alice), amountToDepositFirst);
        // assertEq(strategy.balanceOf(alice), expectedMintedAmountAlice);
        assertApproxEqAbs(strategy.totalAssets(), amountToDepositFirst, 1e3);
        assertEq(
            strategy.convertToAssets(strategy.balanceOf(alice)),
            strategy.totalAssets()
        );

        startHoax(bob);
        IWNative(wFlow).deposit{value: amountToDepositSecond * 1e4}();
        assertEq(wFlow.balanceOf(bob), amountToDepositSecond * 1e4);

        uint256 expectedMintedAmount = strategy.previewDeposit(
            amountToDepositSecond
        );
        wFlow.approve(address(strategy), amountToDepositSecond);

        // calculation of amount that will be supplied and borrowed
        uint256 toSupply = _calcAmountToSupplyAndBorrow(amountToDepositSecond);

        Market memory market = markets.market(marketId);
        uint256 utilization = uint256(
            market.totalSupplyAssets > 0
                ? (market.totalBorrowAssets + toSupply).wDivDown(
                    market.totalSupplyAssets + toSupply
                )
                : 0
        );
        if (utilization >= targetUtilization) {
            vm.expectRevert(LoopStrategy.TargetUtilizationReached.selector);
            strategy.deposit(amountToDepositSecond, bob);
        } else {
            strategy.deposit(amountToDepositSecond, bob);
            assertApproxEqAbs(
                strategy.balanceOf(bob),
                expectedMintedAmount,
                1e3
            );
            assertApproxEqAbs(
                strategy.totalAssets(),
                amountToDepositFirst + amountToDepositSecond,
                1e3
            );
            assertApproxEqAbs(
                strategy.convertToAssets(strategy.balanceOf(alice)) +
                    strategy.convertToAssets(strategy.balanceOf(bob)),
                strategy.totalAssets(),
                10
            );

            assertApproxEqAbs(
                strategy.balanceOf(bob),
                expectedMintedAmount,
                1e3
            );
            assertApproxEqAbs(
                strategy.totalAssets(),
                amountToDepositFirst + amountToDepositSecond,
                1e3
            );
            assertApproxEqAbs(
                strategy.convertToAssets(strategy.balanceOf(alice)) +
                    strategy.convertToAssets(strategy.balanceOf(bob)),
                strategy.totalAssets(),
                10
            );
        }
    }

    function test_deposit_twoUsersUtilizationShouldBeLessThanTarget(
        uint256 amountToDepositFirst,
        uint256 amountToDepositSecond
    ) public {
        vm.assume(amountToDepositFirst > MIN_TEST_DEPOSIT);
        vm.assume(amountToDepositFirst < MAX_TEST_DEPOSIT);
        vm.assume(amountToDepositSecond > MIN_TEST_DEPOSIT);
        vm.assume(amountToDepositSecond < MAX_TEST_DEPOSIT);

        startHoax(alice);
        IWNative(wFlow).deposit{value: amountToDepositFirst * 1e4}();

        wFlow.approve(address(strategy), amountToDepositFirst);
        strategy.deposit(amountToDepositFirst, alice);

        Market memory market = markets.market(marketId);
        uint256 utilization = uint256(
            market.totalSupplyAssets > 0
                ? (market.totalBorrowAssets).wDivDown(market.totalSupplyAssets)
                : 0
        );
        assertLe(utilization, targetUtilization);

        startHoax(bob);
        IWNative(wFlow).deposit{value: amountToDepositSecond * 1e4}();

        wFlow.approve(address(strategy), amountToDepositSecond);

        // calculation of amount that will be supplied and borrowed
        uint256 toSupply = _calcAmountToSupplyAndBorrow(amountToDepositSecond);

        market = markets.market(marketId);
        utilization = uint256(
            market.totalSupplyAssets > 0
                ? (market.totalBorrowAssets + toSupply).wDivDown(
                    market.totalSupplyAssets + toSupply
                )
                : 0
        );
        if (utilization >= targetUtilization) {
            vm.expectRevert(LoopStrategy.TargetUtilizationReached.selector);
            strategy.deposit(amountToDepositSecond, bob);
        } else {
            strategy.deposit(amountToDepositSecond, bob);

            market = markets.market(marketId);
            utilization = uint256(
                market.totalSupplyAssets > 0
                    ? (market.totalBorrowAssets).wDivDown(
                        market.totalSupplyAssets
                    )
                    : 0
            );
            assertLe(utilization, targetUtilization);
        }
    }

    function test_withdraw_fullWithdrawOneUser(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit > MIN_TEST_DEPOSIT);
        vm.assume(amountToDeposit < MAX_TEST_DEPOSIT);
        startHoax(alice);
        IWNative(wFlow).deposit{value: amountToDeposit * 1e4}();
        assertEq(wFlow.balanceOf(alice), amountToDeposit * 1e4);

        wFlow.approve(address(strategy), amountToDeposit);
        strategy.deposit(amountToDeposit, alice);

        assertEq(strategy.balanceOf(alice), amountToDeposit);
        assertApproxEqAbs(strategy.totalAssets(), amountToDeposit, 1e3);
        assertEq(
            strategy.convertToAssets(strategy.balanceOf(alice)),
            strategy.totalAssets()
        );

        (
            uint256 amountToRepay,
            uint256 wFlowAmount,
            uint256 ankrFlowAmount
        ) = strategy.expectedAmountsToWithdraw(
                strategy.convertToAssets(strategy.balanceOf(alice))
            );
        uint256 aliceClaimable = strategy.convertToAssets(
            strategy.balanceOf(alice)
        );

        uint256 ankrFlowBalanceBefore = ankrFlow.balanceOf(alice);
        uint256 wFlowBalanceBefore = wFlow.balanceOf(alice);

        wFlow.approve(address(strategy), amountToRepay);
        strategy.redeem(strategy.balanceOf(alice), alice, alice);

        assertEq(strategy.balanceOf(alice), 0);
        assertEq(
            aliceClaimable,
            ankrFlow.sharesToBonds(ankrFlowAmount) + wFlowAmount - amountToRepay
        );
        assertEq(
            ankrFlow.balanceOf(alice),
            ankrFlowBalanceBefore + ankrFlowAmount
        );
        assertEq(
            wFlow.balanceOf(alice),
            wFlowBalanceBefore + wFlowAmount - amountToRepay
        );

        Position memory position = markets.position(
            marketId,
            address(strategy)
        );
        assertEq(position.borrowShares, 0);
        assertEq(position.collateral, 0);
        assertEq(vault.balanceOf(address(strategy)), 0);
    }

    function test_withdraw_partialWithdrawOneUser(
        uint256 amountToDeposit,
        uint256 percentToWithdraw
    ) public {
        vm.assume(amountToDeposit > MIN_TEST_DEPOSIT);
        vm.assume(amountToDeposit < MAX_TEST_DEPOSIT);
        percentToWithdraw = bound(percentToWithdraw, 0.001e18, 0.99e18);

        startHoax(alice);
        IWNative(wFlow).deposit{value: amountToDeposit * 1e4}();
        assertEq(wFlow.balanceOf(alice), amountToDeposit * 1e4);

        wFlow.approve(address(strategy), amountToDeposit);
        strategy.deposit(amountToDeposit, alice);

        assertEq(strategy.balanceOf(alice), amountToDeposit);
        assertApproxEqAbs(strategy.totalAssets(), amountToDeposit, 1e3);
        assertEq(
            strategy.convertToAssets(strategy.balanceOf(alice)),
            strategy.totalAssets()
        );

        uint256 amountToWithdraw = amountToDeposit.wMulDown(percentToWithdraw);
        (
            uint256 amountToRepay,
            uint256 wFlowAmount,
            uint256 ankrFlowAmount
        ) = strategy.expectedAmountsToWithdraw(amountToWithdraw);
        uint256 aliceSharesToBurn = strategy.convertToShares(amountToWithdraw);

        uint256 strategySharesBefore = strategy.balanceOf(alice);
        uint256 ankrFlowBalanceBefore = ankrFlow.balanceOf(alice);
        uint256 wFlowBalanceBefore = wFlow.balanceOf(alice);

        Position memory strategyPositionBefore = markets.position(
            marketId,
            address(strategy)
        );
        uint256 strategyVaultBalanceBefore = vault.balanceOf(address(strategy));

        uint256 totalBorrowSharesForMultiplier = markets
            .totalBorrowSharesForMultiplier(
                marketId,
                strategyPositionBefore.lastMultiplier
            );
        uint256 totalBorrowAssetsForMultiplier = markets
            .totalBorrowAssetsForMultiplier(
                marketId,
                strategyPositionBefore.lastMultiplier
            );
        uint256 borrowSharesToRepay = amountToRepay.toSharesDown(
            totalBorrowAssetsForMultiplier,
            totalBorrowSharesForMultiplier
        );
        uint256 vaultSharesToWithdraw = vault.previewWithdraw(wFlowAmount);

        wFlow.approve(address(strategy), amountToRepay);
        strategy.withdraw(amountToWithdraw, alice, alice);

        assertApproxEqAbs(
            strategy.balanceOf(alice),
            strategySharesBefore - aliceSharesToBurn,
            10
        );
        assertEq(
            ankrFlow.balanceOf(alice),
            ankrFlowBalanceBefore + ankrFlowAmount
        );
        assertEq(
            wFlow.balanceOf(alice),
            wFlowBalanceBefore + wFlowAmount - amountToRepay
        );

        Position memory position = markets.position(
            marketId,
            address(strategy)
        );
        assertApproxEqAbs(
            position.borrowShares,
            strategyPositionBefore.borrowShares - borrowSharesToRepay,
            1e6
        );
        assertEq(
            position.collateral,
            strategyPositionBefore.collateral - ankrFlowAmount
        );
        assertEq(
            vault.balanceOf(address(strategy)),
            strategyVaultBalanceBefore - vaultSharesToWithdraw
        );
    }

    function _calcAmountToSupplyAndBorrow(
        uint256 assets
    ) internal view returns (uint256 toSupply) {
        // simulation deposit
        // calculating amount of deposit in ankrFlow
        uint256 depositAmountInAnkrFlow = ankrFlow.bondsToShares(assets);
        // calculating how much we should provide as collateral in ankrFlow
        uint256 toSupplyAsCollateral = depositAmountInAnkrFlow
            .wMulDown(100 * 1e18)
            .wDivDown(100 * 1e18 + (targetStrategyLtv.wMulDown(100 * 1e18)))
            .wMulDown(100 * 1e18)
            .wDivDown(100 * 1e18) - 1;
        // calcaulating how much should be provided as supply to the vault in FLOW
        toSupply = ankrFlow.sharesToBonds(
            toSupplyAsCollateral.wMulDown(targetStrategyLtv)
        );
    }
}
