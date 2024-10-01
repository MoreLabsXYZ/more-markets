// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MorphoChainlinkOracleV2Factory} from "morpho-blue-oracles/MorphoChainlinkOracleV2Factory.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// // forge script script/DeployMorphoOracleV2Factory.s.sol:DeployMorphoOracleV2Factory --chain-id 747 --rpc-url https://mainnet.evm.nodes.onflow.org --broadcast -vv --verify --slow --verifier blockscout --verifier-url 'https://evm.flowscan.io/api'
contract DeployMorphoOracleV2Factory is Script {
    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting for deployment
        vm.startBroadcast(deployerPrivateKey);

        MorphoChainlinkOracleV2Factory factory = new MorphoChainlinkOracleV2Factory();
        console.log("Factory deployed at ", address(factory));

        vm.stopBroadcast();
    }
}
