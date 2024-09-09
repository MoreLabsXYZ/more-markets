// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreVaultsFactory} from "../contracts/MoreVaultsFactory.sol";

contract CreateNewVaults is Script {
    MoreVaultsFactory vaultsFactory;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vaultsFactory = MoreVaultsFactory(vm.envAddress("VAULTS_FACTORY"));

        vm.startBroadcast(deployerPrivateKey);

        address[] memory morphoArray = vaultsFactory.arrayOfVaults();

        for (uint i = 0; i < morphoArray.length; i++) {
            console.log("there is a vault with address ", morphoArray[i]);
        }

        vm.stopBroadcast();
    }
}
