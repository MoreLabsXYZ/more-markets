// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreVaultsFactory} from "../contracts/MoreVaultsFactory.sol";
import {IMetaMorpho} from "../contracts/interfaces/IMetaMorpho.sol";
import {ERC20MintableMock} from "../contracts/mocks/ERC20MintableMock.sol";

// forge script script/CreateNewVaults.s.sol:CreateNewVaults --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vvvv --slow
contract CreateNewVaults is Script {
    MoreVaultsFactory vaultsFactory;

    ERC20MintableMock public USDCf =
        ERC20MintableMock(0xaCA1aB5EB856F7645Cd6b9694bA840f3C18BC83e);
    ERC20MintableMock public USDf =
        ERC20MintableMock(0x4D40CDcE3864CA8FCBA1B7De4C0a66f37b28092c);
    ERC20MintableMock public BTCf =
        ERC20MintableMock(0x866E7292A4b9813146591Cb6211AAc33432cF07f);
    ERC20MintableMock public ETHf =
        ERC20MintableMock(0x50bE444228F6f27899E52E56718C0ae67F962185);
    ERC20MintableMock public wFLOW =
        ERC20MintableMock(0xe6De44AC50C1D1C83f67695f6B4820a317285FC6);
    ERC20MintableMock public ANKR =
        ERC20MintableMock(0x3D08ce8bA948ddd6ab0745670134A55e8e35aA8C);

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // TODO script can be improved by reading these values from the environment or JSON CONFIG
        address initialOwner = address(uint160(vm.envUint("OWNER")));
        uint256 initialTimelock = 0;
        address asset1 = address(BTCf);
        string memory name1 = "Nimbus BTC Core";
        string memory symbol1 = "nBTCc";

        bytes32 salt = "5";

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

        console.log(address(vault));

        vm.stopBroadcast();
    }
}
