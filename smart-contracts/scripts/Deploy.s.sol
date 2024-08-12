// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id, MathLib, NothingToClaim} from "../contracts/MoreMarkets.sol";
import {DebtTokenFactory} from "../contracts/factories/DebtTokenFactory.sol";
import {DebtToken} from "../contracts/tokens/DebtToken.sol";
import {ICredoraMetrics} from "../contracts/interfaces/ICredoraMetrics.sol";
import {OracleMock} from "../contracts/mocks/OracleMock.sol";
import {AdaptiveCurveIrm} from "../contracts/AdaptiveCurveIrm.sol";

contract DeployCrowdfunding is Script {
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

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting for deployment
        vm.startBroadcast(deployerPrivateKey);

        debtToken = new DebtToken();
        console.log("Debt token was deployed at", address(debtToken));
        debtTokenFactory = new DebtTokenFactory(address(debtToken));
        console.log(
            "Debt token factory was deployed at",
            address(debtTokenFactory)
        );
        markets = new MoreMarkets(owner, address(debtTokenFactory));
        console.log("More markets was deplyed at", address(markets));
        irm = new AdaptiveCurveIrm(address(markets));
        console.log("AdaptiveCurveIrm was deplyed at", address(irm));

        markets.enableIrm(address(irm));
        markets.setCredora(address(credora));

        for (uint256 i; i < lltvs.length; ) {
            markets.enableLltv(lltvs[i]);
            unchecked {
                ++i;
            }
        }

        // minting mocks for testnet
        loanToken = new ERC20MintableMock(owner);
        collateralToken = new ERC20MintableMock(owner);
        // minting mocks for testnet

        // create a market
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

        // Start broadcasting for deployment
        vm.startBroadcast(deployerPrivateKey);
    }
}
