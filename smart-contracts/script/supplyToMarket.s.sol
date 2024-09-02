// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id, MathLib, NothingToClaim} from "../contracts/MoreMarkets.sol";
import {DebtTokenFactory} from "../contracts/factories/DebtTokenFactory.sol";
import {DebtToken} from "../contracts/tokens/DebtToken.sol";
import {ICredoraMetrics} from "../contracts/interfaces/ICredoraMetrics.sol";
import {OracleMock} from "../contracts/mocks/OracleMock.sol";
import {AdaptiveCurveIrm} from "../contracts/AdaptiveCurveIrm.sol";
import {MathLib, UtilsLib, SharesMathLib, SafeTransferLib, EventsLib, ErrorsLib, IERC20, IIrm, IOracle, WAD} from "@morpho-org/morpho-blue/src/Morpho.sol";

import {ERC20MintableMock} from "../contracts/mocks/ERC20MintableMock.sol";

contract supplyToMarket is Script {
    using MarketParamsLib for MarketParams;
    ICredoraMetrics public credora;
    address public credoraAdmin;
    OracleMock public oracle;

    MoreMarkets public markets;
    DebtTokenFactory public debtTokenFactorye;
    DebtToken public debtToken;
    address public owner;
    AdaptiveCurveIrm public irm;

    // MarketParams public marketParams;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting for deploymentcredoraAdmin = vm.envAddress("CREDORA_ADMIN");
        owner = address(uint160(vm.envUint("OWNER")));
        credora = ICredoraMetrics(vm.envAddress("CREDORA_METRICS"));
        oracle = OracleMock(vm.envAddress("ORACLE"));
        markets = MoreMarkets(vm.envAddress("MARKETS"));
        debtTokenFactorye = DebtTokenFactory(
            vm.envAddress("DEBT_TOKEN_FACTORY")
        );
        debtToken = DebtToken(vm.envAddress("DEBT_TOKEN"));
        irm = AdaptiveCurveIrm(vm.envAddress("IRM"));

        vm.startBroadcast(deployerPrivateKey);

        Id[] memory memAr = markets.arrayOfMarkets();
        uint256 length = memAr.length;
        console.log("lenght of memAr is %d", length);
        MarketParams memory marketParams;
        for (uint i = 0; i < length; i++) {
            console.log("- - - - - - - - - - - - - - - - - - - - - - - - - -");
            {
                (
                    bool isPremium,
                    address loanToken,
                    address collateralToken,
                    address marketOracle,
                    address marketIrm,
                    uint256 lltv,
                    address CAS,
                    uint96 irxMaxLltv,
                    uint256[] memory categoryLltv
                ) = markets.idToMarketParams(memAr[i]);
                marketParams = MarketParams(
                    isPremium,
                    loanToken,
                    collateralToken,
                    marketOracle,
                    marketIrm,
                    lltv,
                    CAS,
                    irxMaxLltv,
                    categoryLltv
                );
            }
            ERC20MintableMock(marketParams.collateralToken).approve(
                address(markets),
                100000 ether
            );
            markets.supplyCollateral(marketParams, 10 ether, owner, "");
            markets.borrow(marketParams, 0, 1 ether, owner, owner);
            ERC20MintableMock(marketParams.loanToken).mint(
                0x2cc510002cE9D04ac6f837277e411468cA10c1A5,
                10000 ether
            );
            ERC20MintableMock(marketParams.collateralToken).mint(
                0x2cc510002cE9D04ac6f837277e411468cA10c1A5,
                10000 ether
            );
        }

        // Start broadcasting for deployment
        vm.stopBroadcast();
    }
}
