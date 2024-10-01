// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IMoreVaultsFactory} from "../contracts/interfaces/factories/IMoreVaultsFactory.sol";

// // forge script script/UpgradeVaultImplementationTo.s.sol:UpgradeVaultImplementationTo --chain-id 747 --rpc-url https://mainnet.evm.nodes.onflow.org --broadcast -vv  --slow
contract UpgradeVaultImplementationTo is Script {
    IMoreVaultsFactory public vaultsFactory;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        IMoreVaultsFactory moreVaultsFactory = IMoreVaultsFactory(
            vm.envAddress("VAULT_FACTORY")
        );

        // Start broadcasting for deployment
        vm.startBroadcast(deployerPrivateKey);
        moreVaultsFactory.upgradeVaultImplemtationTo(
            address(0x86961C1B9a5faF060D7CB7624551E00f53791718)
        );

        vm.stopBroadcast();
    }
}
