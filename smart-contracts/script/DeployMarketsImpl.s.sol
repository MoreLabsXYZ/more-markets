// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreMarkets} from "../contracts/MoreMarkets.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// // forge script script/DeployMarketsImpl.s.sol:DeployMarketsImpl --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vvvv --verify --slow --verifier blockscout --verifier-url 'https://evm-testnet.flowscan.io/api'
contract DeployMarketsImpl is Script {
    MoreMarkets markets;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        markets = new MoreMarkets();

        vm.stopBroadcast();
    }
}
