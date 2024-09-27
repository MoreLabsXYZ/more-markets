// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreVaults} from "../contracts/MoreVaults.sol";
import {MoreVaultsFactory, IMoreVaultsFactory} from "../contracts/MoreVaultsFactory.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MoreUupsProxy} from "../contracts/proxy/MoreUupsProxy.sol";

// forge script script/DeployVaults.s.sol:DeployVaults --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vv --verify --slow --verifier blockscout --verifier-url 'https://evm-testnet.flowscan.io/api'
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
        // vaultsFactory = new MoreVaultsFactory(morpho, address(moreVaultsImpl));
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

        string memory jsonObj = string(
            abi.encodePacked(
                "{ 'vaultsFactory': ",
                Strings.toHexString(address(proxy)),
                "}"
            )
        );
        vm.writeJson(jsonObj, "./output/deployedVault.json");

        vm.stopBroadcast();
    }
}
