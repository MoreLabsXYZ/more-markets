// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {AprFeed} from "../contracts/AprFeed.sol";

// // forge script script/DeployAprFeed.s.sol:DeployAprFeed --chain-id 747 --rpc-url https://mainnet.evm.nodes.onflow.org --broadcast -vvvv --verify --slow --verifier blockscout --verifier-url 'https://evm.flowscan.io/api'
contract DeployAprFeed is Script {
    AprFeed aprFeed;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        aprFeed = new AprFeed(vm.envAddress("MARKETS"));

        vm.stopBroadcast();
    }
}
