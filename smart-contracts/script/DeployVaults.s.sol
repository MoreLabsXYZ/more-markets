// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MoreVaultsFactory} from "../contracts/MoreVaultsFactory.sol";

contract DeployVaults is Script {
    MoreVaultsFactory vaultsFactory;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address morpho = vm.envAddress("MORPHO");

        vm.startBroadcast(deployerPrivateKey);

        vaultsFactory = new MoreVaultsFactory(morpho);

        string memory jsonObj = string(
            abi.encodePacked(
                "{ 'vaultsFactory': ",
                Strings.toHexString(address(vaultsFactory)),
                "}"
            )
        );
        vm.writeJson(jsonObj, "./output/deployedVault.json");

        vm.stopBroadcast();
    }
}
