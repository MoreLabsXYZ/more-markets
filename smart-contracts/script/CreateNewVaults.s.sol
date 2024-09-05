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

        // TODO script can be improved by reading these values from the environment or JSON CONFIG
        address initialOwner = 0x2690eEF879dF58B97ec7CF830F7627Fb1B51f826;
        uint256 initialTimelock = 100;
        address asset1 = 0xdC9C26ECbB6Af88ac6E44e9e0cc85743B4701291;
        // address asset2 = 0xbe36C502663c3F08c7080f632031C370F745C3aC;
        // address asset3 = 0xC4F1dFC005Cb2285b8A9Ede7c525b0eEdF24F5db;
        string memory name1 = "MOCK VAULT 1";
        string memory symbol1 = "MCKVLT1";

        bytes32 salt = "1";

        vm.startBroadcast(deployerPrivateKey);

        vaultsFactory.createMetaMorpho(
            initialOwner,
            initialTimelock,
            asset1,
            name1,
            symbol1,
            salt
        );

        vm.stopBroadcast();
    }
}
