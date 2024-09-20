// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreVaults} from "../contracts/MoreVaults.sol";

// forge script script/GetLastTotalAssets.s.sol:GetLastTotalAssets --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vv
contract GetLastTotalAssets is Script {
    MoreVaults vault;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vault = MoreVaults(vm.envAddress("NIMBUS_VAULT"));

        vm.startBroadcast(deployerPrivateKey);

        console.log(vault.lastTotalAssets());

        vm.stopBroadcast();
    }
}
