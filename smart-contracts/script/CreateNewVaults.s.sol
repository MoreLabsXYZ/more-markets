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

        address initialOwner = 0x0000000000000000000000000000000000000000;
        uint256 initialTimelock = 12345;
        address asset = 0x0000000000000000000000000000000000000000;
        string memory name = "MOCK_VAULT";
        string memory symbol = "MCKVLT";
        bytes32 salt = "12345";

        vm.startBroadcast(deployerPrivateKey);

        vaultsFactory.createMetaMorpho(
            initialOwner,
            initialTimelock,
            asset,
            name,
            symbol,
            salt
        );

        vm.stopBroadcast();
    }
}
