// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {AnkrRatioFeedWrapper} from "../contracts/AnkrRatioFeedWrapper.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// // forge script script/DeployAnkrWrapper.s.sol:DeployAnkrWrapper --chain-id 747 --rpc-url https://mainnet.evm.nodes.onflow.org --broadcast -vvvv --verify --slow --verifier blockscout --verifier-url 'https://evm.flowscan.io/api'
contract DeployAnkrWrapper is Script {
    AnkrRatioFeedWrapper ankrRatioFeedWrapper;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        ankrRatioFeedWrapper = new AnkrRatioFeedWrapper(
            vm.envAddress("ANKR_RATIO_FEED"),
            vm.envAddress("ANKR_FLOW")
        );

        vm.stopBroadcast();
    }
}
