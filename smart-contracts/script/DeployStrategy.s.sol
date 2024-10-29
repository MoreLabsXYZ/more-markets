// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {LoopStrategy, Id} from "../contracts/LoopStrategy.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// forge script script/DeployStrategy.s.sol:DeployStrategy --chain-id 747 --rpc-url https://mainnet.evm.nodes.onflow.org --broadcast -vvvv --verify --slow --verifier blockscout --verifier-url 'https://evm.flowscan.io/api'
contract DeployStrategy is Script {
    address public ankrFlow =
        address(0x1b97100eA1D7126C4d60027e231EA4CB25314bdb);
    address public wFlow = address(0xd3bF53DAC106A0290B0483EcBC89d40FcC961f3e);
    address public staking =
        address(0xFE8189A3016cb6A3668b8ccdAC520CE572D4287a);
    Id public marketId =
        Id.wrap(
            bytes32(
                0x2ae0c40dc06f58ff0243b44116cd48cc4bdab19e2474792fbf1f413600ceab3a
            )
        );
    uint256 public targetUtilization = 0.9e18;
    uint256 public targetStrategyLtv = 0.85e18;
    address public markets;
    address public owner;
    address public vault = address(0xe2aaC46C1272EEAa49ec7e7B9e7d34B90aaDB966);

    TransparentUpgradeableProxy public transparentProxy;
    LoopStrategy public implementation;
    LoopStrategy public strategy;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        markets = vm.envAddress("MARKETS");
        owner = address(uint160(vm.envUint("OWNER")));

        vm.startBroadcast(deployerPrivateKey);

        LoopStrategy strategyImpl = new LoopStrategy();
        // transparentProxy = new TransparentUpgradeableProxy(
        //     address(strategyImpl),
        //     address(owner),
        //     ""
        // );
        // strategy = LoopStrategy(payable(transparentProxy));
        // strategy.initialize(
        //     owner,
        //     address(markets),
        //     address(vault),
        //     address(staking),
        //     address(wFlow),
        //     address(ankrFlow),
        //     marketId,
        //     targetUtilization,
        //     targetStrategyLtv,
        //     "LoopStrategy",
        //     "LS"
        // );

        console.log("strategy implementation: ", address(strategyImpl));
        // console.log("strategy proxy: ", address(strategy));

        vm.stopBroadcast();
    }
}
