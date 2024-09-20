// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreBundler} from "../contracts/MoreBundler.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// // forge script script/DeployBundler.s.sol:DeployBundler --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vvvv --verify --slow --verifier blockscout --verifier-url 'https://evm-testnet.flowscan.io/api'
contract DeployBundler is Script {
    MoreBundler moreBundler;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        moreBundler = new MoreBundler(
            vm.envAddress("MARKETS"),
            vm.envAddress("WRAPPED_NATIVE")
        );

        vm.stopBroadcast();
    }
}
