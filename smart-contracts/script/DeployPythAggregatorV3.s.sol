// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {PythAggregatorV3} from "@pythnetwork/pyth-sdk-solidity/PythAggregatorV3.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// // forge script script/DeployPythAggregatorV3.s.sol:DeployPythAggregatorV3 --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vvvv --verify --slow --verifier blockscout --verifier-url 'https://evm-testnet.flowscan.io/api'
contract DeployPythAggregatorV3 is Script {
    address public pyth = address(vm.envAddress("PYTH_ORACLE"));
    bytes32[] public priceIds;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        priceIds.push(
            0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a
        ); // USDC / USD
        priceIds.push(
            0xc1da1b73d7f01e7ddd54b3766cf7fcd644395ad14f70aa706ec5384c59e76692
        ); // PAYPAL USD / USD
        priceIds.push(
            0xc9d8b075a5c69303365ae23633d4e085199bf5c520a3b90fed1322a0342ffc33
        ); // WBTC / USD
        priceIds.push(
            0x9d4294bbcd1174d6f2003ec365831e64cc31d9f6f15a2b85399db8d5000960f6
        ); // WETH / USD
        priceIds.push(
            0x2fb245b9a84554a0f15aa123cbb5f64cd263b59e9a87d80148cbffab50c69f30
        ); // FLOW / USD
        priceIds.push(
            0x89a58e1cab821118133d6831f5018fba5b354afb78b2d18f575b3cbf69a4f652
        ); // ANKR / USD
        // Start broadcasting for deployment
        vm.startBroadcast(deployerPrivateKey);

        for (uint256 i = 0; i < priceIds.length; i++) {
            PythAggregatorV3 pythAggr = new PythAggregatorV3(pyth, priceIds[i]);

            console.logBytes32(priceIds[i]);
            console.log("Price feed deployed at ", address(pythAggr));
        }

        vm.stopBroadcast();
    }
}
