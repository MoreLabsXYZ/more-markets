// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreVaultsFactory} from "../contracts/MoreVaultsFactory.sol";
import {IMoreVaults} from "../contracts/interfaces/IMoreVaults.sol";
import {ERC20MintableMock} from "../contracts/mocks/ERC20MintableMock.sol";

// forge verify-contract \
//   --rpc-url https://evm.flowscan.io/api/eth-rpc \
//   --verifier blockscout \
//   --verifier-url 'https://evm.flowscan.io/api' \
//   --chain-id 747\
//   --constructor-args $(cast abi-encode "constructor(address)" 0xF56EcB3b2204f12069bf99E94Cf9a01F3DedC1c8 0 0xd3bF53DAC106A0290B0483EcBC89d40FcC961f3e "Flow All Day" "fadFLOW" 0x0000000000000000000000000000000000000000000000000000000000000000) \
//   0x8434D9E41C822F4e10AACcc1D777AAcDf9D4BA60 \
//   contracts/MoreVaults.sol:MoreVaults

// forge script script/CreateNewVaults.s.sol:CreateNewVaults --chain-id 747 --rpc-url https://mainnet.evm.nodes.onflow.org --broadcast -vv
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

    address mainnetAnkrFlow =
        address(0x1b97100eA1D7126C4d60027e231EA4CB25314bdb);
    address mainnetWFlow = address(0xd3bF53DAC106A0290B0483EcBC89d40FcC961f3e);

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address initialOwner = address(uint160(vm.envUint("OWNER")));
        uint256 initialTimelock = 0;
        address asset1 = mainnetAnkrFlow;
        string memory name1 = "Super Flow";
        string memory symbol1 = "sfFLOW";

        bytes32 salt = "1";

        vm.startBroadcast(deployerPrivateKey);
        vaultsFactory = MoreVaultsFactory(vm.envAddress("VAULT_FACTORY"));

        IMoreVaults vault = vaultsFactory.createMoreVault(
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
