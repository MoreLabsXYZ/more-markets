// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {MoreBundler} from "../contracts/MoreBundler.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract MoreBundlerScript is Script {
    MoreBundler moreBundler;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address morpho = vm.envAddress("MARKETS");

        vm.startBroadcast(deployerPrivateKey);

        moreBundler = new MoreBundler(morpho);

        string memory jsonObj = string(
            abi.encodePacked(
                "{ 'MoreBundler': ",
                Strings.toHexString(address(moreBundler)),
                "}"
            )
        );
        vm.writeJson(jsonObj, "./output/deployedBundle.json");

        vm.stopBroadcast();
    }
}
