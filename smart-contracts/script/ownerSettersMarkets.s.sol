// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id, MathLib, NothingToClaim} from "../contracts/MoreMarkets.sol";
import {DebtTokenFactory} from "../contracts/factories/DebtTokenFactory.sol";
import {DebtToken} from "../contracts/tokens/DebtToken.sol";
import {ICredoraMetrics} from "../contracts/interfaces/ICredoraMetrics.sol";
import {OracleMock} from "../contracts/mocks/OracleMock.sol";
import {AdaptiveCurveIrm} from "../contracts/AdaptiveCurveIrm.sol";
import {MathLib, UtilsLib, SharesMathLib, SafeTransferLib, MarketParamsLib, EventsLib, ErrorsLib, IERC20, IIrm, IOracle, WAD} from "@morpho-org/morpho-blue/src/Morpho.sol";

import {ERC20MintableMock} from "../contracts/mocks/ERC20MintableMock.sol";

contract getMarketsData is Script {
    using MarketParamsLib for MarketParams;
    ICredoraMetrics public credora;
    address public credoraAdmin;
    OracleMock public oracle;

    MoreMarkets public markets;
    DebtTokenFactory public debtTokenFactorye;
    DebtToken public debtToken;
    address public owner;
    AdaptiveCurveIrm public irm;

    MarketParams public marketParams;

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

        // @dev uncomment
        markets.setCredora(credora);

        // markets.enableIrm(irm);

        // uint256 lltv = 12345;
        // markets.enableLltv(lltv);
        // address feeRecipient = ;
        // markets.setFeeRecipient(feeRecipient);

        // Start broadcasting for deployment
        vm.stopBroadcast();
    }
}
