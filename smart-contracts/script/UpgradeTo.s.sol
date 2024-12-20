// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {OracleMock} from "../contracts/mocks/OracleMock.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MoreMarkets} from "../contracts/MoreMarkets.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// // forge script script/UpgradeTo.s.sol:UpgradeTo --chain-id 747 --rpc-url https://mainnet.evm.nodes.onflow.org --broadcast -vv --slow
contract UpgradeTo is Script {
    OracleMock public oracleMock;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        ITransparentUpgradeableProxy marketsProxy = ITransparentUpgradeableProxy(
                vm.envAddress("MARKETS")
            );
        ProxyAdmin proxyAdmin = ProxyAdmin(
            vm.envAddress("MARKETS_PROXY_ADMIN")
        );

        // Start broadcasting for deployment
        vm.startBroadcast(deployerPrivateKey);

        MoreMarkets newMarketsImpl = new MoreMarkets();
        proxyAdmin.upgradeAndCall(marketsProxy, address(newMarketsImpl), "");

        vm.stopBroadcast();
    }
}
