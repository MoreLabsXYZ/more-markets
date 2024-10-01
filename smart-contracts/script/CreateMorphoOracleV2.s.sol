// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {IMorphoChainlinkOracleV2Factory, IERC4626, AggregatorV3Interface, MorphoChainlinkOracleV2} from "morpho-blue-oracles/interfaces/IMorphoChainlinkOracleV2Factory.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// forge verify-contract \
//   --rpc-url https://evm.flowscan.io/api/eth-rpc \
//   --verifier blockscout \
//   --verifier-url 'https://evm.flowscan.io/api' \
//   --chain-id 747 \
//   --constructor-args $(cast abi-encode "constructor(address,uint256,address,address,uint256,address,uint256,address,address,uint256,bytes32)" 0x0000000000000000000000000000000000000000 1 0x0000000000000000000000000000000000000000 0x0000000000000000000000000000000000000000 18 0x0000000000000000000000000000000000000000 1 0xA787422E22E4722d2052eaC8ab967A8e32f30bc2 0x0000000000000000000000000000000000000000 18 0x0000000000000000000000000000000000000000000000000000000000000004) \
//   0xC5aB0dA655760825c0b2746D9b865892B8A117Dc \
//   lib/morpho-blue-oracles/src/morpho-chainlink/MorphoChainlinkOracleV2.sol:MorphoChainlinkOracleV2

// // forge script script/CreateMorphoOracleV2.s.sol:CreateMorphoOracleV2 --chain-id 747 --rpc-url https://mainnet.evm.nodes.onflow.org --broadcast -vv --verify --slow --verifier blockscout --verifier-url 'https://evm.flowscan.io/api'
contract CreateMorphoOracleV2 is Script {
    IMorphoChainlinkOracleV2Factory public factory =
        IMorphoChainlinkOracleV2Factory(vm.envAddress("ORACLE_FACTORY"));

    struct FeedInfo {
        AggregatorV3Interface baseFeed;
        uint256 decimals;
    }

    mapping(string => FeedInfo) public feedInfos;

    string[] public stableFeedsNames;
    string[] public nonStableFeedsNames;

    bytes32 salt =
        bytes32(
            0x0000000000000000000000000000000000000000000000000000000000000004
        );

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        stableFeedsNames.push("USDC/USD");
        stableFeedsNames.push("pyUsd/USD");

        nonStableFeedsNames.push("WBTC/USD");
        nonStableFeedsNames.push("WETH/USD");
        nonStableFeedsNames.push("WFLOW/USD");
        nonStableFeedsNames.push("ANKR/USD");

        feedInfos["FLOW/AnkrFLOW"] = FeedInfo(
            AggregatorV3Interface(
                address(0xA787422E22E4722d2052eaC8ab967A8e32f30bc2)
            ),
            18
        );

        // Start broadcasting for deployment
        vm.startBroadcast(deployerPrivateKey);

        IERC4626 baseVault;
        uint256 baseVaultConversionSample;
        AggregatorV3Interface baseFeed1;
        AggregatorV3Interface baseFeed2;
        uint256 baseDecimals;
        IERC4626 quoteVault;
        uint256 quoteVaultConversionSample;
        AggregatorV3Interface quoteFeed1;
        AggregatorV3Interface quoteFeed2;
        uint256 quoteDecimals;

        MorphoChainlinkOracleV2 morphoOracleV2;

        // for (uint256 i = 0; i < stableFeedsNames.length; i++) {
        //     for (uint256 j = 0; j < nonStableFeedsNames.length; j++) {
        //         baseVault = IERC4626(address(0));
        //         baseVaultConversionSample = 1;
        //         baseFeed1 = feedInfos[stableFeedsNames[i]].baseFeed;
        //         baseFeed2 = AggregatorV3Interface(address(0));
        //         baseDecimals = feedInfos[stableFeedsNames[i]].decimals;
        //         quoteVault = IERC4626(address(0));
        //         quoteVaultConversionSample = 1;
        //         quoteFeed1 = feedInfos[nonStableFeedsNames[j]].baseFeed;
        //         quoteFeed2 = AggregatorV3Interface(address(0));
        //         quoteDecimals = feedInfos[nonStableFeedsNames[j]].decimals;

        //         morphoOracleV2 = factory.createMorphoChainlinkOracleV2(
        //             baseVault,
        //             baseVaultConversionSample,
        //             baseFeed1,
        //             baseFeed2,
        //             baseDecimals,
        //             quoteVault,
        //             quoteVaultConversionSample,
        //             quoteFeed1,
        //             quoteFeed2,
        //             quoteDecimals,
        //             salt
        //         );

        //         console.log(
        //             // "Morpho oracle for ",
        //             // stableFeedsNames[i],
        //             // "and ",
        //             // nonStableFeedsNames[j],
        //             " deployed at ",
        //             address(morphoOracleV2)
        //         );

        //         baseVault = IERC4626(address(0));
        //         baseVaultConversionSample = 1;
        //         baseFeed1 = feedInfos[nonStableFeedsNames[j]].baseFeed;
        //         baseFeed2 = AggregatorV3Interface(address(0));
        //         baseDecimals = feedInfos[nonStableFeedsNames[j]].decimals;
        //         quoteVault = IERC4626(address(0));
        //         quoteVaultConversionSample = 1;
        //         quoteFeed1 = feedInfos[stableFeedsNames[i]].baseFeed;
        //         quoteFeed2 = AggregatorV3Interface(address(0));
        //         quoteDecimals = feedInfos[stableFeedsNames[i]].decimals;

        //         morphoOracleV2;

        //         morphoOracleV2 = factory.createMorphoChainlinkOracleV2(
        //             baseVault,
        //             baseVaultConversionSample,
        //             baseFeed1,
        //             baseFeed2,
        //             baseDecimals,
        //             quoteVault,
        //             quoteVaultConversionSample,
        //             quoteFeed1,
        //             quoteFeed2,
        //             quoteDecimals,
        //             salt
        //         );

        //         console.log(
        //             // "Morpho oracle for ",
        //             // nonStableFeedsNames[j],
        //             // " and ",
        //             // stableFeedsNames[i],
        //             " deployed at ",
        //             address(morphoOracleV2)
        //         );
        //     }
        // }

        // baseVault = IERC4626(address(0));
        // baseVaultConversionSample = 1;
        // baseFeed1 = feedInfos["pyUsd/USD"].baseFeed;
        // baseFeed2 = AggregatorV3Interface(address(0));
        // baseDecimals = feedInfos["pyUsd/USD"].decimals;
        // quoteVault = IERC4626(address(0));
        // quoteVaultConversionSample = 1;
        // quoteFeed1 = feedInfos["USDC/USD"].baseFeed;
        // quoteFeed2 = AggregatorV3Interface(address(0));
        // quoteDecimals = feedInfos["USDC/USD"].decimals;

        // morphoOracleV2;

        // morphoOracleV2 = factory.createMorphoChainlinkOracleV2(
        //     baseVault,
        //     baseVaultConversionSample,
        //     baseFeed1,
        //     baseFeed2,
        //     baseDecimals,
        //     quoteVault,
        //     quoteVaultConversionSample,
        //     quoteFeed1,
        //     quoteFeed2,
        //     quoteDecimals,
        //     salt
        // );

        // console.log(
        //     "Morpho oracle for pyUsd/USD and USDC/USD deployed at ",
        //     address(morphoOracleV2)
        // );

        // baseVault = IERC4626(address(0));
        // baseVaultConversionSample = 1;
        // baseFeed1 = feedInfos["WBTC/USD"].baseFeed;
        // baseFeed2 = AggregatorV3Interface(address(0));
        // baseDecimals = feedInfos["WBTC/USD"].decimals;
        // quoteVault = IERC4626(address(0));
        // quoteVaultConversionSample = 1;
        // quoteFeed1 = feedInfos["WETH/USD"].baseFeed;
        // quoteFeed2 = AggregatorV3Interface(address(0));
        // quoteDecimals = feedInfos["WETH/USD"].decimals;

        // morphoOracleV2;

        // morphoOracleV2 = factory.createMorphoChainlinkOracleV2(
        //     baseVault,
        //     baseVaultConversionSample,
        //     baseFeed1,
        //     baseFeed2,
        //     baseDecimals,
        //     quoteVault,
        //     quoteVaultConversionSample,
        //     quoteFeed1,
        //     quoteFeed2,
        //     quoteDecimals,
        //     salt
        // );

        // console.log(
        //     "Morpho oracle for WBTC/USD and WETH/USD deployed at ",
        //     address(morphoOracleV2)
        // );

        // baseVault = IERC4626(address(0));
        // baseVaultConversionSample = 1;
        // baseFeed1 = feedInfos["WETH/USD"].baseFeed;
        // baseFeed2 = AggregatorV3Interface(address(0));
        // baseDecimals = feedInfos["WETH/USD"].decimals;
        // quoteVault = IERC4626(address(0));
        // quoteVaultConversionSample = 1;
        // quoteFeed1 = feedInfos["WBTC/USD"].baseFeed;
        // quoteFeed2 = AggregatorV3Interface(address(0));
        // quoteDecimals = feedInfos["WBTC/USD"].decimals;

        // morphoOracleV2;

        // morphoOracleV2 = factory.createMorphoChainlinkOracleV2(
        //     baseVault,
        //     baseVaultConversionSample,
        //     baseFeed1,
        //     baseFeed2,
        //     baseDecimals,
        //     quoteVault,
        //     quoteVaultConversionSample,
        //     quoteFeed1,
        //     quoteFeed2,
        //     quoteDecimals,
        //     salt
        // );

        // console.log(
        //     "Morpho oracle for WETH/USD and WBTC/USD deployed at ",
        //     address(morphoOracleV2)
        // );

        baseVault = IERC4626(address(0));
        baseVaultConversionSample = 1;
        baseFeed1 = AggregatorV3Interface(address(0)); // feedInfos["FLOW/AnkrFLOW"].baseFeed;
        baseFeed2 = AggregatorV3Interface(address(0));
        baseDecimals = 18; // feedInfos["FLOW/AnkrFLOW"].decimals;
        quoteVault = IERC4626(address(0));
        quoteVaultConversionSample = 1;
        quoteFeed1 = feedInfos["FLOW/AnkrFLOW"].baseFeed; // AggregatorV3Interface(address(0));
        quoteFeed2 = AggregatorV3Interface(address(0));
        quoteDecimals = feedInfos["FLOW/AnkrFLOW"].decimals; // 18;

        morphoOracleV2;

        morphoOracleV2 = factory.createMorphoChainlinkOracleV2(
            baseVault,
            baseVaultConversionSample,
            baseFeed1,
            baseFeed2,
            baseDecimals,
            quoteVault,
            quoteVaultConversionSample,
            quoteFeed1,
            quoteFeed2,
            quoteDecimals,
            salt
        );

        console.log(
            "Morpho oracle for AnkrFLOW/FLOW deployed at ",
            address(morphoOracleV2)
        );

        vm.stopBroadcast();
    }
}
