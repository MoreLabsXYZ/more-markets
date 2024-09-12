// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Vm, StdCheats, Test, console} from "forge-std/Test.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id, MathLib} from "../contracts/MoreMarkets.sol";
import {DebtTokenFactory} from "../contracts/factories/DebtTokenFactory.sol";
import {DebtToken} from "../contracts/tokens/DebtToken.sol";
import {ICreditAttestationService} from "../contracts/interfaces/ICreditAttestationService.sol";
import {OracleMock} from "../contracts/mocks/OracleMock.sol";
import {AdaptiveCurveIrm} from "../contracts/AdaptiveCurveIrm.sol";
import {ERC20MintableMock} from "../contracts/mocks/ERC20MintableMock.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract MoreMarketsTest is Test {
    using MarketParamsLib for MarketParams;
    using MathLib for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 sepoliaFork;
    uint256 flowTestnetFork;

    ICreditAttestationService public credora =
        ICreditAttestationService(
            address(0x29306A367e1185BbC2a8E92A54a33c0B52350564)
        );
    address public credoraAdmin =
        address(0x98ADc891Efc9Ce18cA4A63fb0DfbC2864566b5Ab);
    OracleMock public oracle;

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
    uint256[] public premiumLltvs = [
        1000000000000000000,
        1200000000000000000,
        1400000000000000000,
        1600000000000000000,
        2000000000000000000
    ];
    uint96 public categoryMultiplier = 2 ether;
    uint16[] public categorySteps = [4, 8, 12, 16, 24];

    EnumerableSet.UintSet private multipliersArray;
    uint64[] private _multipliers;

    ERC20MintableMock public loanToken;
    ERC20MintableMock public collateralToken;
    MarketParams public marketParams;

    address[] public users;
    uint256[] public borrowAmountsForUsers;

    mapping(uint128 => uint256) public totalBorrowAssetsMapping;

    function setUp() public {
        sepoliaFork = vm.createFork(
            "https://eth-sepolia.g.alchemy.com/v2/jXLoZTSjTIhZDB9nNhJsSmvrcMAbdrNT"
        );
        flowTestnetFork = vm.createFork("https://testnet.evm.nodes.onflow.org");
        vm.selectFork(flowTestnetFork);

        debtToken = new DebtToken();
        debtTokenFactory = new DebtTokenFactory(address(debtToken));
        markets = new MoreMarkets(owner, address(debtTokenFactory));
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

        loanToken = new ERC20MintableMock(owner, "Loan Mock Token", "LMT", 18);
        collateralToken = new ERC20MintableMock(
            owner,
            "Collateral Mock Token",
            "CMT",
            18
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

        loanToken.mint(address(owner), 1000000000 ether);
        loanToken.approve(address(markets), 1000000000 ether);
        collateralToken.mint(address(owner), 1000000 ether);
        collateralToken.approve(address(markets), 1000000 ether);

        markets.supply(marketParams, 1000000000 ether, 0, owner, "");

        _getAvailableMultipliers(categoryMultiplier);
        multipliersArray.add(1 ether);
        for (uint256 i = 0; i < multipliersArray.length(); ++i) {
            _multipliers.push(uint64(multipliersArray.at(i)));
        }
        // markets.setAvailableMultipliers(_multipliers);
        _fulfillUsers(64, 1000 ether);
    }

    function test_loadOfContract_with64usersWithDiffMultipliers() public {
        for (uint256 i; i < 64; ) {
            startHoax(owner);
            collateralToken.mint(users[i], 1000000 ether);
            startHoax(users[i]);
            collateralToken.approve(address(markets), 1000000 ether);

            markets.supplyCollateral(marketParams, 1000 ether, users[i], "");

            markets.borrow(
                marketParams,
                borrowAmountsForUsers[i],
                0,
                users[i],
                users[i]
            );
            // skip(1);
            unchecked {
                ++i;
            }
        }

        (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares,
            uint128 totalBorrowAssets,
            uint128 totalBorrowShares,
            uint128 lastUpdate,
            uint128 fee,
            uint256 premiumFee
        ) = markets.market(marketParams.id());

        address nonPremUser = address(0x0101);
        startHoax(owner);
        collateralToken.mint(nonPremUser, 1000000 ether);
        startHoax(nonPremUser);
        collateralToken.approve(address(markets), 1000000 ether);
        markets.supplyCollateral(marketParams, 1000 ether, nonPremUser, "");

        skip(200);
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

        for (uint256 i; i < _multipliers.length; ) {
            uint256 totalBorrowAssetsForMultiplier = markets
                .totalBorrowAssetsForMultiplier(
                    marketParams.id(),
                    _multipliers[i]
                );
            totalBorrowAssetsMapping[_multipliers[i]] =
                totalBorrowAssetsForMultiplier
                    .wMulDown(borrowRate.wMulDown(_multipliers[i]))
                    .wTaylorCompounded(200) +
                totalBorrowAssetsForMultiplier;
            unchecked {
                ++i;
            }
        }
        markets.borrow(marketParams, 700 ether, 0, nonPremUser, nonPremUser);
        totalBorrowAssetsMapping[1 ether] = markets
            .totalBorrowAssetsForMultiplier(marketParams.id(), 1 ether);

        for (uint256 i; i < _multipliers.length; ) {
            uint256 totalBorrowAssetsForMultiplier = markets
                .totalBorrowAssetsForMultiplier(
                    marketParams.id(),
                    _multipliers[i]
                );

            assertEq(
                totalBorrowAssetsMapping[_multipliers[i]],
                totalBorrowAssetsForMultiplier
            );
            unchecked {
                ++i;
            }
        }
    }

    function _calcAmountToBorrowForUser(
        uint256 collateral,
        uint256 lltv,
        uint256 numberOfSteps,
        uint256 numberOfStep
    ) internal pure returns (uint256) {
        uint256 defaultBorrow = 800 ether;
        uint256 maxBorrow = collateral.wMulDown(lltv);

        uint256 borrowStep = (maxBorrow - defaultBorrow).wDivUp(
            numberOfSteps * 10 ** 18
        );

        return defaultBorrow + borrowStep * numberOfStep + 1;
    }

    function _getAvailableMultipliers(uint96 marketMultiplier) internal {
        for (uint256 i; i < marketParams.categoryLltv.length; ) {
            uint256 categoryStepNumber = (marketParams.categoryLltv[i] -
                marketParams.lltv) / 50000000000000000;
            uint256 multiplierStep = (uint256(marketMultiplier) - 1 ether)
                .wDivUp(uint256(categoryStepNumber) * 10 ** 18);
            for (uint256 j; j < categoryStepNumber; ) {
                uint256 multiplier = multiplierStep * (j + 1);
                multipliersArray.add(multiplier + 1 ether);
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    function _fulfillUsers(uint256 numberOfUsers, uint256 collateral) internal {
        uint160 startNumber = 10 ** 24;
        uint256 accumNumber = categorySteps[0];
        uint256 numOfCategory;
        for (uint256 i = 0; i < numberOfUsers; ) {
            users.push(address(uint160(startNumber + i)));

            startHoax(credoraAdmin);

            if (i >= accumNumber && numOfCategory < 5) {
                ++numOfCategory;
                accumNumber += categorySteps[numOfCategory];
            }
            credora.setData(
                0,
                abi.encode(
                    users[i],
                    uint256((99 + (numOfCategory * 200)) * 10 ** 18),
                    uint64(0),
                    bytes8("AAA+"),
                    uint64(0),
                    uint64(0),
                    uint64(0)
                ),
                ""
            );
            credora.grantPermission(
                users[i],
                address(markets),
                type(uint128).max
            );

            unchecked {
                ++i;
            }
        }

        for (uint256 i = 0; i < 5; ) {
            for (uint256 j = 0; j < categorySteps[i]; ) {
                borrowAmountsForUsers.push(
                    _calcAmountToBorrowForUser(
                        collateral,
                        premiumLltvs[numOfCategory],
                        categorySteps[numOfCategory],
                        j
                    )
                );
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
    }
}
