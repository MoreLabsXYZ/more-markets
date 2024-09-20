// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {OracleMock} from "../contracts/mocks/OracleMock.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MoreMarkets} from "../contracts/MoreMarkets.sol";

// // forge script script/UpgradeTo.s.sol:UpgradeTo --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vv  --slow
contract UpgradeTo is Script {
    OracleMock public oracleMock;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        MoreMarkets marketsProxy = MoreMarkets(vm.envAddress("MARKETS"));

        // Start broadcasting for deployment
        vm.startBroadcast(deployerPrivateKey);
        marketsProxy.upgradeTo(
            address(0xF72Dca492aA8Ad4419B55804f4Ce672f25974D34)
        );

        vm.stopBroadcast();
    }
}
