// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreVaults} from "../contracts/MoreVaults.sol";
import {MoreVaultsFactory, IMoreVaultsFactory} from "../contracts/MoreVaultsFactory.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MoreUupsProxy} from "../contracts/proxy/MoreUupsProxy.sol";

// forge script script/DeployVaults.s.sol:DeployVaults --chain-id 747 --rpc-url https://mainnet.evm.nodes.onflow.org --broadcast -vvvv --verify --slow --verifier blockscout --verifier-url 'https://evm.flowscan.io/api'
contract DeployVaults is Script {
    MoreVaultsFactory vaultsFactory;
    MoreVaults moreVaultsImpl;
    MoreUupsProxy proxy;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address morpho = vm.envAddress("MARKETS");

        vm.startBroadcast(deployerPrivateKey);

        moreVaultsImpl = new MoreVaults();
        vaultsFactory = new MoreVaultsFactory();
        proxy = new MoreUupsProxy(address(vaultsFactory));
        IMoreVaultsFactory(address(proxy)).initialize(
            morpho,
            address(moreVaultsImpl)
        );

        console.log("more vaults implementation: ", address(moreVaultsImpl));
        console.log(
            "more vaults factory implementation: ",
            address(vaultsFactory)
        );
        console.log("more vaults factory proxy: ", address(proxy));

        vm.stopBroadcast();
    }
}
