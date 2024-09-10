// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {OracleMock} from "../contracts/mocks/OracleMock.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// // forge script script/DeployMockOracle.s.sol:DeployMockOracle --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vvvv --verify --slow --verifier blockscout --verifier-url 'https://evm-testnet.flowscan.io/api'
contract DeployMockOracle is Script {
    OracleMock public oracleMock;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting for deployment
        vm.startBroadcast(deployerPrivateKey);
        oracleMock = new OracleMock();
        oracleMock.setPrice(1e36);

        vm.stopBroadcast();
    }
}
