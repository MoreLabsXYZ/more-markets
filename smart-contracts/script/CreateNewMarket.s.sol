// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id, MathLib, NothingToClaim} from "../contracts/MoreMarkets.sol";
import {DebtTokenFactory} from "../contracts/factories/DebtTokenFactory.sol";
import {DebtToken} from "../contracts/tokens/DebtToken.sol";
import {ICredoraMetrics} from "../contracts/interfaces/ICredoraMetrics.sol";
import {OracleMock} from "../contracts/mocks/OracleMock.sol";
import {AdaptiveCurveIrm} from "../contracts/AdaptiveCurveIrm.sol";

import {ERC20MintableMock} from "../contracts/mocks/ERC20MintableMock.sol";

// // forge script script/CreateNewMarket.s.sol:CreateNewMarket --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vvvv
contract CreateNewMarket is Script {
    using MarketParamsLib for MarketParams;
    ICredoraMetrics public credora;
    address public credoraAdmin;
    OracleMock public oracle;

    MoreMarkets public markets;
    DebtTokenFactory public debtTokenFactorye;
    DebtToken public debtToken;
    address public owner;
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
    uint96 public categoryMultipliers = 2 ether;
    uint16[] public categorySteps = [4, 8, 12, 16, 24];

    ERC20MintableMock public loanToken;
    ERC20MintableMock public collateralToken;
    MarketParams public marketParams;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting for deploymentcredoraAdmin = vm.envAddress("CREDORA_ADMIN");
        owner = address(uint160(vm.envUint("OWNER")));
        credora = ICredoraMetrics(vm.envAddress("CREDORA_METRICS"));
        oracle = OracleMock(vm.envAddress("ORACLE"));
        markets = MoreMarkets(vm.envAddress("MARKETS"));
        irm = AdaptiveCurveIrm(vm.envAddress("IRM"));

        vm.startBroadcast(deployerPrivateKey);

        // minting mocks for testnet
        loanToken = new ERC20MintableMock(owner, "doge", "DOGE");
        collateralToken = new ERC20MintableMock(owner, "USDC Token", "USDC");
        // minting mocks for testnet

        // create a market
        marketParams = MarketParams(
            true,
            address(loanToken),
            address(collateralToken),
            address(oracle),
            address(irm),
            lltvs[0],
            address(credora),
            categoryMultipliers,
            premiumLltvs
        );
        markets.createMarket(marketParams);

        loanToken.mint(address(owner), 1000000 ether);
        loanToken.approve(address(markets), 1000000 ether);
        collateralToken.mint(address(owner), 1000000 ether);
        collateralToken.approve(address(markets), 1000000 ether);

        markets.supply(marketParams, 10000 ether, 0, owner, "");

        // Start broadcasting for deployment
        vm.stopBroadcast();
    }
}
