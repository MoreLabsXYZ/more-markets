// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {MoreBundle} from "../contracts/MoreBundle.sol";

contract MoreBundlerScript is Script {
    MoreBundle moreBundle;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address morpho = vm.envAddress("MARKETS");

        vm.startBroadcast(deployerPrivateKey);

        moreBundle = new MoreBundle(morpho);

        string memory jsonObj = string(
            abi.encodePacked(
                "{ 'MoreBundle': ",
                Strings.toHexString(address(moreBundle)),
                "}"
            )
        );
        vm.writeJson(jsonObj, "./output/deployedBundle.json");

        vm.stopBroadcast();
    }
}
