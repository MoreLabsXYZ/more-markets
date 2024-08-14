// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id, MathLib, NothingToClaim} from "../contracts/MoreMarkets.sol";
import {DebtTokenFactory} from "../contracts/factories/DebtTokenFactory.sol";
import {DebtToken} from "../contracts/tokens/DebtToken.sol";
import {ICredoraMetrics} from "../contracts/interfaces/ICredoraMetrics.sol";
import {OracleMock} from "../contracts/mocks/OracleMock.sol";
import {AdaptiveCurveIrm} from "../contracts/AdaptiveCurveIrm.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract DeployMarketContracts is Script {
    ICredoraMetrics public credora;
    address public credoraAdmin;
    OracleMock public oracleMock;

    MoreMarkets public markets;
    DebtTokenFactory public debtTokenFactory;
    DebtToken public debtToken;
    address public owner;
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

    MarketParams public marketParams;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        credoraAdmin = vm.envAddress("CREDORA_ADMIN");
        owner = vm.envAddress("OWNER");
        credora = ICredoraMetrics(vm.envAddress("CREDORA_METRICS"));
        oracleMock = OracleMock(vm.envAddress("ORACLE"));

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

        string memory jsonObj = string(
            abi.encodePacked(
                "{ 'debtToken': ",
                Strings.toHexString(address(debtToken)),
                ", 'debtTokenFactory': ",
                Strings.toHexString(address(debtTokenFactory)),
                " , 'markets': ",
                Strings.toHexString(address(markets)),
                ", 'irm': ",
                Strings.toHexString(address(irm)),
                "}"
            )
        );
        vm.writeJson(jsonObj, "./output/deployedContracts.json");

        vm.stopBroadcast();
    }
}
