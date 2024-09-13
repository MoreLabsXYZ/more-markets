// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreBundler} from "../contracts/MoreBundler.sol";
import {CredoraMetrics} from "@credora/on-chain-metrics-test/contracts/CredoraMetrics.sol";

// // forge script script/DeployCredora.s.sol:DeployCredora --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vv --verify --slow --verifier blockscout --verifier-url 'https://evm-testnet.flowscan.io/api'
contract DeployCredora is Script {
    CredoraMetrics credora;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = address(uint160(vm.envUint("OWNER")));
        address router = address(0xb83E47C2bC239B3bf370bc41e1459A34b41238D0);
        address eas = address(0xf3D64De1778cB566c77dBf041A06d6979142cb95);
        bytes32 donId = bytes32(
            0x66756e2d746573742d3100000000000000000000000000000000000000000000
        );

        vm.startBroadcast(deployerPrivateKey);

        credora = new CredoraMetrics(router, eas, donId);

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
        credora.grantPermission(owner, owner, type(uint128).max);

        console.log(credora.getScore(owner));

        vm.stopBroadcast();
    }
}
