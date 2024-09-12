// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {ERC20MintableMock} from "../contracts/mocks/ERC20MintableMock.sol";
import {WFLOWMock} from "../contracts/mocks/WFLOWMock.sol";

// // forge script script/DeployMockTokens.s.sol:DeployMockTokens --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vvvv --verify --slow --verifier blockscout --verifier-url 'https://evm-testnet.flowscan.io/api'
contract DeployMockTokens is Script {
    address owner;

    struct TokenInfo {
        string name;
        string symbol;
        uint8 decimals;
    }

    TokenInfo[] public tokenInfos;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        owner = address(uint160(vm.envUint("OWNER")));

        tokenInfos.push(TokenInfo("USDCf(USDC) mock coin", "USDCf", 6));
        tokenInfos.push(TokenInfo("USDf(PYUSD) mock coin", "USDf", 6));
        tokenInfos.push(TokenInfo("BTCf(wBTC) mock coin", "BTCf", 8));
        tokenInfos.push(TokenInfo("ETHf(wETH) mock coin", "ETHf", 18));
        tokenInfos.push(TokenInfo("ankr.FLOW mock coin", "ankr.FLOW", 18));
        tokenInfos.push(TokenInfo("wrapped FLOW mock coin", "wFLOW", 18));

        // Start broadcasting for deployment
        vm.startBroadcast(deployerPrivateKey);

        ERC20MintableMock[] memory tokens = new ERC20MintableMock[](
            tokenInfos.length
        );
        for (uint256 i = 0; i < tokenInfos.length - 1; i++) {
            tokens[i] = new ERC20MintableMock(
                owner,
                tokenInfos[i].name,
                tokenInfos[i].symbol,
                tokenInfos[i].decimals
            );

            console.log(
                "Token ",
                tokenInfos[i].symbol,
                " deployed at ",
                address(tokens[i])
            );
        }

        WFLOWMock wflow = new WFLOWMock();
        console.log(
            "Token ",
            tokenInfos[5].symbol,
            " deployed at ",
            address(wflow)
        );

        vm.stopBroadcast();
    }
}
