// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Vm, StdCheats, Test, console} from "forge-std/Test.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id, MathLib, ErrorsLib, SharesMathLib} from "../contracts/MoreMarkets.sol";
import {ICreditAttestationService} from "../contracts/interfaces/ICreditAttestationService.sol";
import {OracleMock} from "../contracts/mocks/OracleMock.sol";
import {AdaptiveCurveIrm} from "../contracts/AdaptiveCurveIrm.sol";
import {ERC20MintableMock} from "../contracts/mocks/ERC20MintableMock.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract MoreMarketsTest is Test {
    using MarketParamsLib for MarketParams;
    using MathLib for uint256;
    using SharesMathLib for uint256;

    uint256 sepoliaFork;
    uint256 flowTestnetFork;

    TransparentUpgradeableProxy public transparentProxy;
    ProxyAdmin public proxyAdmin;

    ICreditAttestationService public credora =
        ICreditAttestationService(
            address(0x29306A367e1185BbC2a8E92A54a33c0B52350564)
        );
    address public credoraAdmin =
        address(0x98ADc891Efc9Ce18cA4A63fb0DfbC2864566b5Ab);
    OracleMock public oracle;

    MoreMarkets public marketsImpl;
    MoreMarkets public markets;
    address public owner = address(0x89a76D7a4D006bDB9Efd0923A346fAe9437D434F);
    AdaptiveCurveIrm public irm;

    uint256[] public lltvs = [
        800000000000000000,
        945000000000000000,
        965000000000000000
    ];

    uint8 numberOfPremiumBuckets = 5;
    uint256[] public premiumLltvs = [
        1000000000000000000,
        1200000000000000000,
        1400000000000000000,
        1600000000000000000,
        2000000000000000000
    ];
    uint96 public categoryMultiplier = 2 ether;
    uint16[] public categorySteps = [4, 8, 12, 16, 24];

    ERC20MintableMock public loanToken;
    ERC20MintableMock public collateralToken;
    MarketParams public marketParams;

    uint256 globalSnapshotId;

    function setUp() public {
        sepoliaFork = vm.createFork(
            "https://eth-sepolia.g.alchemy.com/v2/jXLoZTSjTIhZDB9nNhJsSmvrcMAbdrNT"
        );
        flowTestnetFork = vm.createFork("https://testnet.evm.nodes.onflow.org");
        vm.selectFork(flowTestnetFork);

        proxyAdmin = new ProxyAdmin(owner);
        marketsImpl = new MoreMarkets();
        transparentProxy = new TransparentUpgradeableProxy(
            address(marketsImpl),
            address(proxyAdmin),
            ""
        );

        markets = MoreMarkets(address(transparentProxy));
        markets.initialize(owner);
        irm = new AdaptiveCurveIrm(address(markets));
        oracle = new OracleMock();
        // set price as 1 : 1
        oracle.setPrice(1000000000000000000000000000000000000);

        startHoax(owner);
        markets.enableIrm(address(irm));
        // markets.setCreditAttestationService(address(credora));
        markets.setMaxLltvForCategory(premiumLltvs[4]);

        for (uint256 i; i < lltvs.length; ) {
            markets.enableLltv(lltvs[i]);
            unchecked {
                ++i;
            }
        }

        loanToken = new ERC20MintableMock(owner, "Loan Mock Token", "LMT");
        collateralToken = new ERC20MintableMock(
            owner,
            "Collateral Mock Token",
            "CMT"
        );

        marketParams = MarketParams(
            true,
            address(loanToken),
            address(collateralToken),
            address(oracle),
            address(irm),
            lltvs[0],
            address(credora),
            categoryMultiplier,
            premiumLltvs
        );
        markets.createMarket(marketParams);

        loanToken.mint(address(owner), 1000000 ether);
        loanToken.approve(address(markets), 1000000 ether);
        collateralToken.mint(address(owner), 1000000 ether);
        collateralToken.approve(address(markets), 1000000 ether);

        startHoax(credoraAdmin);
        credora.setData(
            0,
            abi.encode(
                owner,
                uint256(190 * 10 ** 18),
                uint64(0),
                bytes8("AAA+"),
                uint64(0),
                uint64(0),
                uint64(0)
            ),
            ""
        );

        startHoax(owner);
        markets.supply(marketParams, 10000 ether, 0, owner, "");
    }

    function test_deployment() public view {
        assertTrue(markets.isIrmEnabled(address(irm)));
        // assertEq(address(markets.creditAttestationService()), address(credora));
        assertEq(markets.owner(), owner);
    }

    function test_setIrxMax_shouldSetIrxMax() public {
        assertEq(markets.irxMaxAvailable(), 2 ether);
        markets.setIrxMax(1.5 ether);
        assertEq(markets.irxMaxAvailable(), 1.5 ether);
    }

    function test_setIrxMax_shouldRevertIfSameValueAlreadySet() public {
        assertEq(markets.irxMaxAvailable(), 2 ether);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        markets.setIrxMax(2 ether);
    }

    function test_setIrxMax_shouldRevertIfCalledNotByAnOwner() public {
        address someUser = address(0x000011111);
        startHoax(someUser);
        assertEq(markets.irxMaxAvailable(), 2 ether);
        vm.expectRevert(ErrorsLib.NotOwner.selector);
        markets.setIrxMax(2 ether);
    }

    function test_setMaxLltvForCategory_shouldSetMaxLltvForCategory() public {
        assertEq(markets.maxLltvForCategory(), 2 ether);
        markets.setMaxLltvForCategory(1.5 ether);
        assertEq(markets.maxLltvForCategory(), 1.5 ether);
    }

    function test_setMaxLltvForCategory_shouldRevertIfSameValueAlreadySet()
        public
    {
        assertEq(markets.maxLltvForCategory(), 2 ether);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        markets.setMaxLltvForCategory(2 ether);
    }

    function test_setMaxLltvForCategory_shouldRevertIfCalledNotByAnOwner()
        public
    {
        address someUser = address(0x000011111);
        startHoax(someUser);
        assertEq(markets.maxLltvForCategory(), 2 ether);
        vm.expectRevert(ErrorsLib.NotOwner.selector);
        markets.setMaxLltvForCategory(2 ether);
    }

    function test_setPremiumFee_shouldSetPremiumFee() public {
        (, , , , , , uint256 premiumFee) = markets.market(marketParams.id());
        assertEq(premiumFee, 0);

        markets.setPremiumFee(marketParams, 0.10e18);

        (, , , , , , premiumFee) = markets.market(marketParams.id());
        assertEq(premiumFee, 0.10e18);
    }

    function test_setPremiumFee_shouldRevertIfParamTheSame() public {
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        markets.setPremiumFee(marketParams, 0);
    }

    function test_setPremiumFee_shouldRevertIfMarketDoesNotExist() public {
        marketParams.loanToken = address(0x000011111);

        vm.expectRevert(ErrorsLib.MarketNotCreated.selector);
        markets.setPremiumFee(marketParams, 0.10e18);
    }

    function test_setPremiumFee_shouldRevertIfCalledNotByAnOwner() public {
        address someUser = address(0x000011111);
        startHoax(someUser);
        vm.expectRevert(ErrorsLib.NotOwner.selector);
        markets.setPremiumFee(marketParams, 0.10e18);
    }

    function test_setPremiumFee_shouldRevertIfProvidedFeeExccedsMax() public {
        vm.expectRevert("max fee exceeded");
        uint256 maxPremiumFee = 0.5e18;
        markets.setPremiumFee(marketParams, maxPremiumFee + 0.01e18);
    }

    function test_setPremiumFee_shouldAccrueInterest() public {
        markets.supplyCollateral(marketParams, 1000 ether, owner, "");
        markets.borrow(marketParams, 700 ether, 0, owner, owner);
        skip(1 days);
        (
            uint256 totalSupplyAssetsBefore,
            ,
            uint256 totalBorrowAssetsBefore,
            ,
            ,
            ,

        ) = markets.market(marketParams.id());
        markets.setPremiumFee(marketParams, 0.10e18);

        (
            uint256 totalSupplyAssets,
            ,
            uint256 totalBorrowAssets,
            ,
            ,
            ,

        ) = markets.market(marketParams.id());

        assertGt(totalSupplyAssets, totalSupplyAssetsBefore);
        assertGt(totalBorrowAssets, totalBorrowAssetsBefore);
    }

    function test_setPremiumFee_shouldNotMintSharesToRecipientOnSetPremiumFee()
        public
    {
        address newFeeRecipient = address(0x000011111);
        markets.setFeeRecipient(newFeeRecipient);

        address userNonPrem = address(0x1010);
        collateralToken.mint(address(userNonPrem), 1000000 ether);

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

        startHoax(owner);
        markets.supplyCollateral(marketParams, 1000 ether, owner, "");
        markets.borrow(marketParams, 700 ether, 0, owner, owner);

        (uint128 supplySharesBefore, , , ) = markets.position(
            marketParams.id(),
            newFeeRecipient
        );

        skip(1 days);
        markets.setPremiumFee(marketParams, 0.10e18);

        (uint128 supplySharesAfter, , , ) = markets.position(
            marketParams.id(),
            newFeeRecipient
        );
        assertEq(supplySharesBefore, supplySharesAfter);
    }

    function test_setPremiumFee_shouldCorrectlyCalculatePremiumFeeWhenOneUserIsPremAndOneNot()
        public
    {
        startHoax(credoraAdmin);
        credora.grantPermission(owner, address(markets), type(uint128).max);
        address newFeeRecipient = address(0x000011111);

        address userNonPrem = address(0x1010);
        collateralToken.mint(address(userNonPrem), 1000000 ether);

        uint256 userNonPremAmountToBorrow = 700 ether;
        uint256 ownerAmountToBorrow = 900 ether; // his LLTV 100%

        startHoax(userNonPrem);
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

        startHoax(owner);
        markets.setFeeRecipient(newFeeRecipient);
        markets.supplyCollateral(marketParams, 1000 ether, owner, "");
        markets.borrow(marketParams, ownerAmountToBorrow, 0, owner, owner);

        uint256 premFee = 0.10e18;
        markets.setPremiumFee(marketParams, premFee);

        uint256 timeToSkip = 1 days;
        skip(timeToSkip);
        (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares,
            uint128 totalBorrowAssets,
            uint128 totalBorrowShares,
            uint128 lastUpdate,
            uint128 fee,
            uint256 premiumFee
        ) = markets.market(marketParams.id());
        uint256 borrowRate = irm.borrowRateView(
            marketParams,
            Market(
                totalSupplyAssets,
                totalSupplyShares,
                totalBorrowAssets,
                totalBorrowShares,
                lastUpdate,
                fee,
                premiumFee
            )
        );
        (, , , uint256 ownerLastMultiplier) = markets.position(
            marketParams.id(),
            owner
        );

        uint256 totalBorrowAssetsBefore = totalBorrowAssets;
        uint256 nonPremUserInterest = userNonPremAmountToBorrow.wMulDown(
            borrowRate.wTaylorCompounded(timeToSkip)
        );
        uint256 ownerInterest = ownerAmountToBorrow
            .wMulDown(borrowRate.wTaylorCompounded(timeToSkip))
            .wMulDown(ownerLastMultiplier);
        uint256 premiumFeeGenerated = ownerAmountToBorrow
            .wMulDown(borrowRate.wTaylorCompounded(timeToSkip))
            .wMulDown(ownerLastMultiplier.wMulDown(premFee));
        uint256 sumOfInterests = nonPremUserInterest + ownerInterest;
        uint256 totalSupplySharesBefore = totalSupplyShares;
        uint256 totalSupplyAssetsBefore = totalSupplyAssets;

        markets.accrueInterest(marketParams);

        (
            totalSupplyAssets,
            totalSupplyShares,
            totalBorrowAssets,
            totalBorrowShares,
            lastUpdate,
            fee,
            premiumFee
        ) = markets.market(marketParams.id());

        assertEq(
            sumOfInterests + premiumFeeGenerated,
            totalBorrowAssets - totalBorrowAssetsBefore
        );
        assertEq(sumOfInterests, totalSupplyAssets - totalSupplyAssetsBefore);

        (uint128 feeRecipientSupplySharesAfter, , , ) = markets.position(
            marketParams.id(),
            newFeeRecipient
        );

        uint256 feeRecipientAssets = uint256(feeRecipientSupplySharesAfter)
            .toAssetsDown(totalSupplyAssets, totalSupplyShares);

        (uint128 ownerSupplyShares, , , ) = markets.position(
            marketParams.id(),
            owner
        );

        assertApproxEqAbs(
            uint256(ownerSupplyShares).toAssetsDown(
                totalSupplyAssets,
                totalSupplyShares
            ) +
                uint256(feeRecipientSupplySharesAfter).toAssetsDown(
                    totalSupplyAssets,
                    totalSupplyShares
                ),
            totalSupplyAssets,
            1e2
        );

        assertEq(
            feeRecipientSupplySharesAfter,
            totalSupplyShares - totalSupplySharesBefore
        );

        assertApproxEqAbs(premiumFeeGenerated, feeRecipientAssets, 1);
    }

    function test_setPremiumFee_shouldCorrectlyCalculatePremiumFeeWhenOneUserIsPremAndOneNotAndDefaultFeeAppliedToo()
        public
    {
        startHoax(credoraAdmin);
        credora.grantPermission(owner, address(markets), type(uint128).max);
        address newFeeRecipient = address(0x000011111);

        address userNonPrem = address(0x1010);
        collateralToken.mint(address(userNonPrem), 1000000 ether);

        uint256 userNonPremAmountToBorrow = 700 ether;
        uint256 ownerAmountToBorrow = 900 ether; // his LLTV 100%

        startHoax(userNonPrem);
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

        startHoax(owner);
        markets.setFeeRecipient(newFeeRecipient);
        markets.supplyCollateral(marketParams, 1000 ether, owner, "");
        markets.borrow(marketParams, ownerAmountToBorrow, 0, owner, owner);

        uint256 premFee = 0.10e18;
        uint256 defaultFee = 0.05e18;
        markets.setPremiumFee(marketParams, premFee);
        markets.setFee(marketParams, defaultFee);

        uint256 timeToSkip = 1 days;
        skip(timeToSkip);
        (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares,
            uint128 totalBorrowAssets,
            uint128 totalBorrowShares,
            uint128 lastUpdate,
            uint128 fee,
            uint256 premiumFee
        ) = markets.market(marketParams.id());
        uint256 borrowRate = irm.borrowRateView(
            marketParams,
            Market(
                totalSupplyAssets,
                totalSupplyShares,
                totalBorrowAssets,
                totalBorrowShares,
                lastUpdate,
                fee,
                premiumFee
            )
        );
        (, , , uint256 ownerLastMultiplier) = markets.position(
            marketParams.id(),
            owner
        );

        uint256 totalBorrowAssetsBefore = totalBorrowAssets;
        uint256 totalSupplyAssetsBefore = totalSupplyAssets;
        uint256 nonPremUserInterest = userNonPremAmountToBorrow.wMulDown(
            borrowRate.wTaylorCompounded(timeToSkip)
        );
        uint256 ownerInterest = ownerAmountToBorrow
            .wMulDown(borrowRate.wTaylorCompounded(timeToSkip))
            .wMulDown(ownerLastMultiplier);
        uint256 premiumFeeGenerated = ownerAmountToBorrow
            .wMulDown(borrowRate.wTaylorCompounded(timeToSkip))
            .wMulDown(ownerLastMultiplier.wMulDown(premFee));

        uint256 defaultFeeAssets = (nonPremUserInterest + ownerInterest)
            .wMulDown(defaultFee);
        uint256 totalFee = defaultFeeAssets + premiumFeeGenerated;

        uint256 sumOfInterests = nonPremUserInterest + ownerInterest;

        markets.accrueInterest(marketParams);

        (
            totalSupplyAssets,
            totalSupplyShares,
            totalBorrowAssets,
            totalBorrowShares,
            lastUpdate,
            fee,
            premiumFee
        ) = markets.market(marketParams.id());

        assertEq(
            sumOfInterests + premiumFeeGenerated,
            totalBorrowAssets - totalBorrowAssetsBefore
        );
        assertEq(sumOfInterests, totalSupplyAssets - totalSupplyAssetsBefore);

        (uint128 feeRecipientSupplySharesAfter, , , ) = markets.position(
            marketParams.id(),
            newFeeRecipient
        );

        uint256 feeRecipientAssets = uint256(feeRecipientSupplySharesAfter)
            .toAssetsDown(totalSupplyAssets, totalSupplyShares);
        assertApproxEqAbs(totalFee, feeRecipientAssets, 1);
    }

    function test_createMarket_shouldAbleToDeployMarketWithDifferentCategoriesLltv()
        public
    {
        marketParams = MarketParams(
            true,
            address(loanToken),
            address(collateralToken),
            address(oracle),
            address(irm),
            lltvs[1],
            address(credora),
            categoryMultiplier,
            premiumLltvs
        );
        markets.createMarket(marketParams);

        uint256[] memory newPremiumLltvs = premiumLltvs;
        markets.setMaxLltvForCategory(3000000000000000000);
        newPremiumLltvs[4] = 2000000000000000001;

        marketParams = MarketParams(
            true,
            address(loanToken),
            address(collateralToken),
            address(oracle),
            address(irm),
            lltvs[1],
            address(credora),
            categoryMultiplier,
            newPremiumLltvs
        );
        markets.createMarket(marketParams);
        (
            bool isPrem,
            ,
            ,
            ,
            ,
            ,
            address CAS,
            uint96 irxMaxLltv,
            uint256[] memory lltvsFromContract
        ) = markets.idToMarketParams(marketParams.id());
        assertEq(isPrem, true);
        assertEq(address(credora), CAS);
        assertEq(categoryMultiplier, irxMaxLltv);
        for (uint256 i = 0; i < lltvsFromContract.length; ) {
            assertEq(newPremiumLltvs[i], lltvsFromContract[i]);
            unchecked {
                ++i;
            }
        }

        vm.expectRevert("market already created");
        markets.createMarket(marketParams);
    }

    function test_createMarket_shouldRevertIfProvidedNotFiveLltvs() public {
        uint256[] memory newPremiumLltvs = new uint256[](4);
        marketParams = MarketParams(
            true,
            address(loanToken),
            address(collateralToken),
            address(oracle),
            address(irm),
            lltvs[1],
            address(credora),
            categoryMultiplier,
            newPremiumLltvs
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorsLib.InvalidLengthOfCategoriesLltvsArray.selector,
                5,
                4
            )
        );
        markets.createMarket(marketParams);

        uint256[] memory newPremiumLltvs2 = new uint256[](6);
        marketParams = MarketParams(
            true,
            address(loanToken),
            address(collateralToken),
            address(oracle),
            address(irm),
            lltvs[1],
            address(credora),
            categoryMultiplier,
            newPremiumLltvs2
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorsLib.InvalidLengthOfCategoriesLltvsArray.selector,
                5,
                6
            )
        );
        markets.createMarket(marketParams);
    }

    function test_createMarket_shouldRevertIfIrxLessThanOne() public {
        marketParams = MarketParams(
            true,
            address(loanToken),
            address(collateralToken),
            address(oracle),
            address(irm),
            lltvs[1],
            address(credora),
            1e18 - 1,
            premiumLltvs
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorsLib.InvalidIrxMaxValue.selector,
                2e18,
                1e18,
                1e18 - 1
            )
        );
        markets.createMarket(marketParams);
    }

    function test_createMarket_shouldRevertIfIrxMoreThanAllowed() public {
        marketParams = MarketParams(
            true,
            address(loanToken),
            address(collateralToken),
            address(oracle),
            address(irm),
            lltvs[1],
            address(credora),
            2e18 + 1,
            premiumLltvs
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorsLib.InvalidIrxMaxValue.selector,
                2e18,
                1e18,
                2e18 + 1
            )
        );
        markets.createMarket(marketParams);
    }

    function test_createMarket_shouldRevertIfCategoryLltvMoreThanAllowed()
        public
    {
        premiumLltvs[4] = 2000000000000000001;
        marketParams = MarketParams(
            true,
            address(loanToken),
            address(collateralToken),
            address(oracle),
            address(irm),
            lltvs[1],
            address(credora),
            2e18,
            premiumLltvs
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorsLib.InvalidCategoryLltvValue.selector,
                4,
                2e18,
                lltvs[1],
                2e18 + 1
            )
        );
        markets.createMarket(marketParams);
    }

    function test_createMarket_shouldRevertIfCategoryLltvLessThanDefaultLltv()
        public
    {
        premiumLltvs[0] = lltvs[1] - 1;
        marketParams = MarketParams(
            true,
            address(loanToken),
            address(collateralToken),
            address(oracle),
            address(irm),
            lltvs[1],
            address(credora),
            2e18,
            premiumLltvs
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorsLib.InvalidCategoryLltvValue.selector,
                0,
                2e18,
                lltvs[1],
                lltvs[1] - 1
            )
        );
        markets.createMarket(marketParams);
    }

    function test_createMarket_shouldRevertIfCategoryLltvMoreThanMaxLltv()
        public
    {
        premiumLltvs[4] += 1;
        marketParams = MarketParams(
            true,
            address(loanToken),
            address(collateralToken),
            address(oracle),
            address(irm),
            lltvs[1],
            address(credora),
            2e18,
            premiumLltvs
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ErrorsLib.InvalidCategoryLltvValue.selector,
                4,
                2e18,
                lltvs[1],
                premiumLltvs[4]
            )
        );
        markets.createMarket(marketParams);
    }

    function test_createMarket_shouldRevertIfLltvsNotInAscendingOrder() public {
        premiumLltvs[2] = premiumLltvs[3] + 1;
        marketParams = MarketParams(
            true,
            address(loanToken),
            address(collateralToken),
            address(oracle),
            address(irm),
            lltvs[1],
            address(credora),
            2e18,
            premiumLltvs
        );

        vm.expectRevert(
            abi.encodeWithSelector(ErrorsLib.LLTVsNotInAscendingOrder.selector)
        );
        markets.createMarket(marketParams);
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
        (, , , uint64 lastMultiplier) = markets.position(
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

    function test_borrow_checkBorrowInNonPremMarketWithACategoryShouldntBeAbleToBorrowOverDefaultLltv()
        public
    {
        uint256[] memory arrayOfZeros = new uint256[](5);
        arrayOfZeros[0] = 0;
        arrayOfZeros[1] = 0;
        arrayOfZeros[2] = 0;
        arrayOfZeros[3] = 0;
        arrayOfZeros[4] = 0;

        marketParams = MarketParams(
            false,
            address(loanToken),
            address(collateralToken),
            address(oracle),
            address(irm),
            lltvs[0], // 80%
            address(0),
            1e18,
            arrayOfZeros
        );
        markets.createMarket(marketParams);
        markets.supply(marketParams, 850 ether, 0, owner, "");

        startHoax(credoraAdmin);
        credora.setData(
            0,
            abi.encode(
                owner,
                uint256(800 * 10 ** 18),
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

        vm.expectRevert(ErrorsLib.InsufficientCollateral.selector);
        markets.borrow(marketParams, 800 ether + 1, 0, owner, owner);

        markets.borrow(marketParams, 800 ether, 0, owner, owner);
    }

    function test_borrow_checkBorrowMultipliersForCategoryD() public {
        startHoax(credoraAdmin);
        credora.setData(
            0,
            abi.encode(
                owner,
                uint256(201 * 10 ** 18),
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
                uint256(401 * 10 ** 18),
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
                uint256(601 * 10 ** 18),
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
                uint256(800 * 10 ** 18),
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
                uint256(201 * 10 ** 18),
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
                uint256(401 * 10 ** 18),
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
                uint256(601 * 10 ** 18),
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
                uint256(800 * 10 ** 18),
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
        (, , , uint64 lastMultiplier) = markets.position(
            marketParams.id(),
            owner
        );
        assertEq(lastMultiplier, 2 ether);

        // to 820
        markets.repay(marketParams, 179 ether, 0, owner, "");
        (, , , lastMultiplier) = markets.position(marketParams.id(), owner);
        assertEq(lastMultiplier, 1.25 ether);

        // to 890
        markets.borrow(marketParams, 70 ether, 0, owner, owner);
        (, , , lastMultiplier) = markets.position(marketParams.id(), owner);
        assertEq(lastMultiplier, 1.5 ether);

        // to 930
        markets.borrow(marketParams, 40 ether, 0, owner, owner);
        (, , , lastMultiplier) = markets.position(marketParams.id(), owner);
        assertEq(lastMultiplier, 1.75 ether);

        // to 951
        markets.borrow(marketParams, 21 ether, 0, owner, owner);
        (, , , lastMultiplier) = markets.position(marketParams.id(), owner);
        assertEq(lastMultiplier, 2 ether);

        // to 1001
        vm.expectRevert(ErrorsLib.InsufficientCollateral.selector);
        markets.borrow(marketParams, 50 ether, 0, owner, owner);
    }

    function test_borrow_scenarioForCategoryA() public {
        startHoax(credoraAdmin);

        credora.setData(
            0,
            abi.encode(
                owner,
                uint256(900 * 10 ** 18),
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
        (, , , uint64 lastMultiplier) = markets.position(
            marketParams.id(),
            owner
        );
        assertApproxEqAbs(lastMultiplier, 2 ether, 10 ** 3);

        uint256 multiplierStep = (uint256(1 ether)).wDivUp(
            uint256(categorySteps[4]) * 10 ** 18
        );

        // to 820
        markets.repay(marketParams, 1179 ether, 0, owner, "");
        (, , , lastMultiplier) = markets.position(marketParams.id(), owner);
        assertApproxEqAbs(lastMultiplier, 1 ether + multiplierStep, 10 ** 3);

        // to 890
        markets.borrow(marketParams, 70 ether, 0, owner, owner);
        (, , , lastMultiplier) = markets.position(marketParams.id(), owner);
        assertApproxEqAbs(
            lastMultiplier,
            1 ether + multiplierStep * 2,
            10 ** 3
        );

        // to 930
        markets.borrow(marketParams, 40 ether, 0, owner, owner);
        (, , , lastMultiplier) = markets.position(marketParams.id(), owner);
        assertApproxEqAbs(
            lastMultiplier,
            1 ether + multiplierStep * 3,
            10 ** 3
        );

        // to 2001
        vm.expectRevert(ErrorsLib.InsufficientCollateral.selector);
        markets.borrow(marketParams, 1071 ether, 0, owner, owner);

        // to 2000
        markets.borrow(marketParams, 1070 ether, 0, owner, owner);
        (, , , lastMultiplier) = markets.position(marketParams.id(), owner);
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
                uint256(100 * 10 ** 18),
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
                uint256(700 * 10 ** 18),
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
        (, , , uint256 lastMultiplier) = markets.position(
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
        (, , , lastMultiplier) = markets.position(marketParams.id(), userB);
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
        (, , , lastMultiplier) = markets.position(
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
            uint128 fee,
            uint256 premiumFee
        ) = markets.market(marketParams.id());
        uint256 borrowRate = irm.borrowRateView(
            marketParams,
            Market(
                totalSupplyAssets,
                totalSupplyShares,
                totalBorrowAssets,
                totalBorrowShares,
                lastUpdate,
                fee,
                premiumFee
            )
        );

        uint256 totalBorrowAssetsBefore = totalBorrowAssets;
        markets.accrueInterest(marketParams);

        uint256 sumOfInterests = userEAmountToBorrow
            .wMulDown(borrowRate.wTaylorCompounded(timeToSkip))
            .wMulDown(eUserMultiplier) +
            userBAmountToBorrow
                .wMulDown(borrowRate.wTaylorCompounded(timeToSkip))
                .wMulDown(bUserMultiplier) +
            userNonPremAmountToBorrow.wMulDown(
                borrowRate.wTaylorCompounded(timeToSkip)
            );

        (
            totalSupplyAssets,
            totalSupplyShares,
            totalBorrowAssets,
            totalBorrowShares,
            lastUpdate,
            fee,
            premiumFee
        ) = markets.market(marketParams.id());

        // total interest calculated correctly
        assertApproxEqAbs(
            sumOfInterests,
            totalBorrowAssets - totalBorrowAssetsBefore,
            10
        );

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
        (uint256 ownerSupplyShares, , , ) = markets.position(
            marketParams.id(),
            owner
        );
        (uint256 oneMoreLenderSupplyShares, , , ) = markets.position(
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
                uint256(700 * 10 ** 18),
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

        markets.liquidate(marketParams, owner, 500 ether, 0, "");
        markets.liquidate(marketParams, owner, 100 ether, 0, "");
        markets.liquidate(marketParams, owner, 100 ether, 0, "");
        markets.liquidate(marketParams, owner, 100 ether, 0, "");
        markets.liquidate(marketParams, owner, 100 ether, 0, "");
        markets.liquidate(marketParams, owner, 99 ether, 0, "");
        markets.liquidate(marketParams, owner, 1 ether, 0, "");
        vm.expectRevert("position is healthy");
        markets.liquidate(marketParams, owner, 1 ether, 0, "");
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
        (, , , uint64 lastMultiplier) = markets.position(
            marketParams.id(),
            owner
        );
        assertEq(lastMultiplier, 1 ether);
        for (uint256 i = 0; i < numberOfSteps; ) {
            markets.borrow(marketParams, borrowStep, 0, owner, owner);
            (, , , lastMultiplier) = markets.position(marketParams.id(), owner);
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
        (, , , uint64 lastMultiplier) = markets.position(
            marketParams.id(),
            owner
        );
        assertApproxEqAbs(lastMultiplier, 2 ether, 10 ** 3);
        for (uint256 i = 0; i < numberOfSteps; ) {
            markets.repay(marketParams, borrowStep, 0, owner, "");
            (, , , lastMultiplier) = markets.position(marketParams.id(), owner);
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

        (, uint256 borrowShares, , ) = markets.position(
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
        (, uint256 borrowShares, , ) = markets.position(
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
        (uint256 supplyShares, , , ) = markets.position(
            marketParams.id(),
            user
        );
        (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares,
            ,
            ,
            ,
            ,

        ) = markets.market(marketParams.id());
        (uint256 assetsWithdrawn, ) = markets.withdraw(
            marketParams,
            0,
            supplyShares,
            user,
            user
        );

        assertApproxEqAbs(assetsWithdrawn, amountToWithdraw, 10);

        (
            uint128 newTotalSupplyAssets,
            uint128 newTotalSupplyShares,
            ,
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
        (supplyShares, , , ) = markets.position(marketParams.id(), user);
        assertApproxEqAbs(supplyShares, 0, 10 ** 3);
    }

    function _setupLiquidation(
        address borrowerB,
        uint256 collateral,
        uint256 borrow
    ) internal {
        startHoax(credoraAdmin);
        credora.setData(
            0,
            abi.encode(
                borrowerB,
                uint256(700 * 10 ** 18),
                uint64(0),
                bytes8(""),
                uint64(0),
                uint64(0),
                uint64(0)
            ),
            ""
        );
        credora.grantPermission(borrowerB, address(markets), type(uint128).max);

        startHoax(owner);
        collateralToken.mint(address(borrowerB), 1000000 ether);
        loanToken.mint(address(borrowerB), 1000000 ether);

        startHoax(borrowerB);
        collateralToken.approve(address(markets), 1000000 ether);
        markets.supplyCollateral(marketParams, collateral, borrowerB, "");

        markets.borrow(marketParams, borrow, 0, borrowerB, borrowerB);
        skip(2000);

        markets.accrueInterest(marketParams);
    }
}
