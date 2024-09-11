// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id, MathLib} from "../contracts/MoreMarkets.sol";
import {IMoreMarkets} from "../contracts/interfaces/IMoreMarkets.sol";
import {DebtTokenFactory} from "../contracts/factories/DebtTokenFactory.sol";
import {DebtToken} from "../contracts/tokens/DebtToken.sol";
import {ICreditAttestationService} from "../contracts/interfaces/ICreditAttestationService.sol";
import {OracleMock} from "../contracts/mocks/OracleMock.sol";
import {AdaptiveCurveIrm} from "../contracts/AdaptiveCurveIrm.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MoreProxy} from "../contracts/proxy/MoreProxy.sol";

// // forge script script/Deploy.s.sol:DeployMarketContracts --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vvvv --verify --slow --verifier blockscout --verifier-url 'https://evm-testnet.flowscan.io/api'
contract DeployMarketContracts is Script {
    ICreditAttestationService public credora;
    address public credoraAdmin;
    OracleMock public oracleMock;
    MoreProxy proxy;

    MoreMarkets public marketsImpl;
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
        owner = address(uint160(vm.envUint("OWNER")));
        credora = ICreditAttestationService(vm.envAddress("CREDORA_METRICS"));

        // Start broadcasting for deployment
        vm.startBroadcast(deployerPrivateKey);

        debtToken = new DebtToken();
        console.log("Debt token was deployed at", address(debtToken));
        debtTokenFactory = new DebtTokenFactory(address(debtToken));
        console.log(
            "Debt token factory was deployed at",
            address(debtTokenFactory)
        );
        // markets = new MoreMarkets(owner, address(debtTokenFactory));
        markets = new MoreMarkets();
        proxy = new MoreProxy(address(markets));
        IMoreMarkets(address(proxy)).initialize(
            owner,
            address(debtTokenFactory)
        );

        console.log("More markets was deplyed at", address(markets));
        console.log("More markets proxy was deplyed at", address(proxy));
        irm = new AdaptiveCurveIrm(address(proxy));
        console.log("AdaptiveCurveIrm was deplyed at", address(irm));

        IMoreMarkets(address(proxy)).enableIrm(address(irm));
        // markets.setCreditAttestationService(address(credora));

        for (uint256 i; i < lltvs.length; ) {
            IMoreMarkets(address(proxy)).enableLltv(lltvs[i]);
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
                Strings.toHexString(address(proxy)),
                ", 'irm': ",
                Strings.toHexString(address(irm)),
                "}"
            )
        );
        vm.writeJson(jsonObj, "./output/deployedContracts.json");

        vm.stopBroadcast();
    }
}
