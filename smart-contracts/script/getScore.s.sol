// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Vm, StdCheats, Test, console} from "forge-std/Test.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id, MathLib, NothingToClaim} from "../contracts/MoreMarkets.sol";
import {DebtTokenFactory} from "../contracts/factories/DebtTokenFactory.sol";
import {DebtToken} from "../contracts/tokens/DebtToken.sol";
import {ICredoraMetrics} from "../contracts/interfaces/ICredoraMetrics.sol";
import {OracleMock} from "../contracts/mocks/OracleMock.sol";
import {AdaptiveCurveIrm} from "../contracts/AdaptiveCurveIrm.sol";
import {MathLib, UtilsLib, SharesMathLib, SafeTransferLib, EventsLib, ErrorsLib, IERC20, IIrm, IOracle, WAD} from "@morpho-org/morpho-blue/src/Morpho.sol";

import {ERC20MintableMock} from "../contracts/mocks/ERC20MintableMock.sol";

// // forge script script/getScore.s.sol:getScore --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vvvv --slow
contract getScore is Script {
    using MarketParamsLib for MarketParams;
    ICredoraMetrics public credora;
    address public credoraAdmin;
    OracleMock public oracle;

    MoreMarkets public markets;
    DebtTokenFactory public debtTokenFactorye;
    DebtToken public debtToken;
    address public owner;
    AdaptiveCurveIrm public irm;

    // MarketParams public marketParams;

    function setUp() public {}

    function run() external {
        credora = ICredoraMetrics(vm.envAddress("CREDORA_METRICS"));
        vm.startPrank(address(0x665EB1F72f2c0771A9C7305b8d735d5410FF3246));
        bytes32 entity = bytes32(
            uint256(
                uint160(address(0x89a76D7a4D006bDB9Efd0923A346fAe9437D434F))
            )
        );
        console.log(
            ICredoraMetrics(credora).getScore(
                address(0xb53CbCaBbDFfd85Dc626B5F26a6b26A31AAE4Dc0)
            )
        );
    }
}
