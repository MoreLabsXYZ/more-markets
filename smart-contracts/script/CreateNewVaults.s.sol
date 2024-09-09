// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreVaultsFactory} from "../contracts/MoreVaultsFactory.sol";

// forge script script/CreateNewVaults.s.sol:CreateNewVaults --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vvvv --slow
contract CreateNewVaults is Script {
    MoreVaultsFactory vaultsFactory;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // TODO script can be improved by reading these values from the environment or JSON CONFIG
        address initialOwner = address(uint160(vm.envUint("OWNER")));
        uint256 initialTimelock = 0;
        address asset1 = address(0x58f3875DBeFcf784Ea40A886eC24e3C3FaB2dB19);
        string memory name1 = "MOCK VAULT 2";
        string memory symbol1 = "MCKVLT2";

        bytes32 salt = "1";

        vm.startBroadcast(deployerPrivateKey);
        vaultsFactory = MoreVaultsFactory(vm.envAddress("VAULT_FACTORY"));

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
