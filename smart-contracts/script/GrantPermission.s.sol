// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreBundler} from "../contracts/MoreBundler.sol";
import {CredoraMetrics} from "@credora/on-chain-metrics-test/contracts/CredoraMetrics.sol";

// // forge script script/GrantPermission.s.sol:GrantPermission --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vv --verify --slow --verifier blockscout --verifier-url 'https://evm-testnet.flowscan.io/api'
contract GrantPermission is Script {
    CredoraMetrics credora;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = address(uint160(vm.envUint("OWNER")));
        credora = CredoraMetrics(vm.envAddress("CREDORA_METRICS"));

        vm.startBroadcast(deployerPrivateKey);

        credora.setData(
            0,
            abi.encode(
                owner,
                uint256(190 * 10 ** 18),
                uint64(0),
                bytes8("AAA+"),
                uint64(0),
                uint64(0),
                uint64(0)
            ),
            ""
        );

        credora.grantPermission(
            owner,
            vm.envAddress("MARKETS"),
            type(uint128).max
        );

        vm.stopBroadcast();
    }
}
