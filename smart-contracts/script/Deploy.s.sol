// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id, MathLib} from "../contracts/MoreMarkets.sol";
import {IMoreMarkets} from "../contracts/interfaces/IMoreMarkets.sol";
import {ICreditAttestationService} from "../contracts/interfaces/ICreditAttestationService.sol";
import {OracleMock} from "../contracts/mocks/OracleMock.sol";
import {AdaptiveCurveIrm} from "../contracts/AdaptiveCurveIrm.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// forge verify-contract \
//   --rpc-url https://evm-testnet.flowscan.io/api/eth-rpc \
//   --verifier blockscout \
//   --verifier-url 'https://evm-testnet.flowscan.io/api' \
//   --chain-id 545\
//   0x7EBf3217f8A54De432ACFe6E803576CB859E22a3 \
//   contracts/proxy/MoreUupsProxy.sol:MoreUupsProxy

// // forge script script/Deploy.s.sol:DeployMarketContracts --chain-id 747 --rpc-url https://mainnet.evm.nodes.onflow.org --broadcast -vvvv --verify --slow --verifier blockscout --verifier-url 'https://evm.flowscan.io/api'
contract DeployMarketContracts is Script {
    ICreditAttestationService public credora;
    address public credoraAdmin;
    OracleMock public oracleMock;

    TransparentUpgradeableProxy public proxy;

    MoreMarkets public marketsImpl;
    MoreMarkets public markets;
    address public owner;
    AdaptiveCurveIrm public irm;

    uint256[] public lltvs = [
        // 720000000000000000,
        // 770000000000000000,
        // 800000000000000000,
        // 850000000000000000,
        900000000000000000
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

        // Start broadcasting for deployment
        vm.startBroadcast(deployerPrivateKey);

        marketsImpl = new MoreMarkets();
        proxy = new TransparentUpgradeableProxy(
            address(marketsImpl),
            address(owner),
            ""
        );

        markets = MoreMarkets(address(proxy));
        markets.initialize(owner);

        // console.log("Proxy admin was deployed at ", address(proxyAdmin));
        console.log("More markets impl was deployed at", address(marketsImpl));
        console.log("More markets proxy was deployed at", address(proxy));
        irm = new AdaptiveCurveIrm(address(proxy));
        console.log("AdaptiveCurveIrm was deployed at", address(irm));

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
                "{ 'markets': ",
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
