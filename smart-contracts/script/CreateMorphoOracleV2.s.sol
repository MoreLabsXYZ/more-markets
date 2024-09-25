// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {IMorphoChainlinkOracleV2Factory, IERC4626, AggregatorV3Interface, MorphoChainlinkOracleV2} from "morpho-blue-oracles/interfaces/IMorphoChainlinkOracleV2Factory.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// 0.001731335314099271314119104189818979
// 1000000000000000000000000000000000000
// 1043778456684580000000000000000000000
// 1034316096194120000000000000000000000
// forge verify-contract \
//   --rpc-url https://evm-testnet.flowscan.io/api/eth-rpc \
//   --verifier blockscout \
//   --verifier-url 'https://evm-testnet.flowscan.io/api' \
//   --chain-id 545\
//   --constructor-args $(cast abi-encode "constructor(address,uint256,address,address,uint256,address,uint256,address,address,uint256,bytes32)" 0x0000000000000000000000000000000000000000 1 0xe65b5154aE462fD08faD32B2A85841803135894b 0x0000000000000000000000000000000000000000 8 0x0000000000000000000000000000000000000000 1 0xaCAd8eB605A93b8E0fF993f437f64155FB68D5DD 0x0000000000000000000000000000000000000000 18 0x0000000000000000000000000000000000000000000000000000000000000001) \
//   0x8857C969d0E40413AB9C8e972ACE186A39bE4071 \
//   lib/morpho-blue-oracles/src/morpho-chainlink/MorphoChainlinkOracleV2.sol:MorphoChainlinkOracleV2

// // forge script script/CreateMorphoOracleV2.s.sol:CreateMorphoOracleV2 --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vv --verify --slow --verifier blockscout --verifier-url 'https://evm-testnet.flowscan.io/api'
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

        feedInfos["USDC/USD"] = FeedInfo(
            AggregatorV3Interface(
                address(0xBEfB2b2B48fdEece45253b2eD008540a23d25AFE)
            ),
            6
        );
        feedInfos["pyUsd/USD"] = FeedInfo(
            AggregatorV3Interface(
                address(0x2e9EcBf2D63094A08c9ff5eb20A4EbBFfBFc12eD)
            ),
            6
        );
        feedInfos["WBTC/USD"] = FeedInfo(
            AggregatorV3Interface(
                address(0xe65b5154aE462fD08faD32B2A85841803135894b)
            ),
            8
        );
        feedInfos["WETH/USD"] = FeedInfo(
            AggregatorV3Interface(
                address(0x2b40Fc7326E3bF1DB3571e414d006Ee42d49C427)
            ),
            18
        );
        feedInfos["WFLOW/USD"] = FeedInfo(
            AggregatorV3Interface(
                address(0xaCAd8eB605A93b8E0fF993f437f64155FB68D5DD)
            ),
            18
        );
        feedInfos["ANKR/USD"] = FeedInfo(
            AggregatorV3Interface(
                address(0x017efB6272Dc61DCcfc9a757c29Fd99187c9d208)
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

        baseVault = IERC4626(address(0));
        baseVaultConversionSample = 1;
        baseFeed1 = feedInfos["pyUsd/USD"].baseFeed;
        baseFeed2 = AggregatorV3Interface(address(0));
        baseDecimals = feedInfos["pyUsd/USD"].decimals;
        quoteVault = IERC4626(address(0));
        quoteVaultConversionSample = 1;
        quoteFeed1 = feedInfos["USDC/USD"].baseFeed;
        quoteFeed2 = AggregatorV3Interface(address(0));
        quoteDecimals = feedInfos["USDC/USD"].decimals;

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
            "Morpho oracle for pyUsd/USD and USDC/USD deployed at ",
            address(morphoOracleV2)
        );

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
        baseFeed1 = feedInfos["WBTC/USD"].baseFeed;
        baseFeed2 = AggregatorV3Interface(address(0));
        baseDecimals = feedInfos["WBTC/USD"].decimals;
        quoteVault = IERC4626(address(0));
        quoteVaultConversionSample = 1;
        quoteFeed1 = feedInfos["WFLOW/USD"].baseFeed;
        quoteFeed2 = AggregatorV3Interface(address(0));
        quoteDecimals = feedInfos["WFLOW/USD"].decimals;

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
            "Morpho oracle for WBTC/USD and WFLOW/USD deployed at ",
            address(morphoOracleV2)
        );

        vm.stopBroadcast();
    }
}
