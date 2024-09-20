// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreVaultsFactory} from "../contracts/MoreVaultsFactory.sol";
import {IMetaMorpho} from "../contracts/interfaces/IMetaMorpho.sol";
import {ERC20MintableMock} from "../contracts/mocks/ERC20MintableMock.sol";

// forge script script/CreateNewVaults.s.sol:CreateNewVaults --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vv --verify --slow --verifier blockscout --verifier-url 'https://evm-testnet.flowscan.io/api'
contract CreateNewVaults is Script {
    MoreVaultsFactory vaultsFactory;

    ERC20MintableMock public USDCf =
        ERC20MintableMock(0x5e65b6B04fbA51D95409712978Cb91E99d93aE73);
    ERC20MintableMock public USDf =
        ERC20MintableMock(0xd7d43ab7b365f0d0789aE83F4385fA710FfdC98F);
    ERC20MintableMock public BTCf =
        ERC20MintableMock(0x208d09d2a6Dd176e3e95b3F0DE172A7471C5B2d6);
    ERC20MintableMock public ETHf =
        ERC20MintableMock(0x059A77239daFa770977DD9f1E98632C3E4559848);
    ERC20MintableMock public ANKR =
        ERC20MintableMock(0xe132751AB5A14ac0bD3Cb40571a9248Ee7a2a9EA);
    ERC20MintableMock public wFLOW =
        ERC20MintableMock(0xe0fd0a2A4C2E59a479AaB0cF44244E355C508766);

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // TODO script can be improved by reading these values from the environment or JSON CONFIG
        address initialOwner = address(uint160(vm.envUint("OWNER")));
        uint256 initialTimelock = 0;
        address asset1 = address(BTCf);
        string memory name1 = "Nimbus BTC Core";
        string memory symbol1 = "nBTCc";

        bytes32 salt = "10";

        vm.startBroadcast(deployerPrivateKey);
        vaultsFactory = MoreVaultsFactory(vm.envAddress("VAULT_FACTORY"));

        IMetaMorpho vault = vaultsFactory.createMetaMorpho(
            initialOwner,
            initialTimelock,
            asset1,
            name1,
            symbol1,
            salt
        );

        console.log(name1, " vault address: ", address(vault));

        vm.stopBroadcast();
    }
}
