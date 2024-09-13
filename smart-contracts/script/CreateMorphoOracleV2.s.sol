// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {IMorphoChainlinkOracleV2Factory, IERC4626, AggregatorV3Interface, MorphoChainlinkOracleV2} from "morpho-blue-oracles/interfaces/IMorphoChainlinkOracleV2Factory.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// 0.001731335314099271314119104189818979
// 1000000000000000000000000000000000000

// forge verify-contract \
//   --rpc-url https://evm-testnet.flowscan.io/api/eth-rpc \
//   --verifier blockscout \
//   --verifier-url 'https://evm-testnet.flowscan.io/api' \
//   --chain-id 545\
//   --constructor-args $(cast abi-encode "constructor(address,uint256,address,address,uint256,address,uint256,address,address,uint256,bytes32)" 0x0000000000000000000000000000000000000000 1 0xEf6c4E2AD21917337C84089400B6d1f191764D31 0x0000000000000000000000000000000000000000 6 0x0000000000000000000000000000000000000000 1 0x4639CAeb838946b8fbc53684cD2aEc90CB8b5C84 0x0000000000000000000000000000000000000000 8 0x0000000000000000000000000000000000000000000000000000000000000001) \
//   0x8D715b5cE4b0555B1f844FA627b6251cf8d03b88 \
//   lib/morpho-blue-oracles/src/morpho-chainlink/MorphoChainlinkOracleV2.sol:MorphoChainlinkOracleV2

// // forge script script/CreateMorphoOracleV2.s.sol:CreateMorphoOracleV2 --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vvvv --verify --slow --verifier blockscout --verifier-url 'https://evm-testnet.flowscan.io/api'
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
            0x0000000000000000000000000000000000000000000000000000000000000003
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
                address(0xEf6c4E2AD21917337C84089400B6d1f191764D31)
            ),
            6
        );
        feedInfos["pyUsd/USD"] = FeedInfo(
            AggregatorV3Interface(
                address(0x116930C32f2D8a52062FD37C2814fd4eB00E101C)
            ),
            6
        );
        feedInfos["WBTC/USD"] = FeedInfo(
            AggregatorV3Interface(
                address(0x4639CAeb838946b8fbc53684cD2aEc90CB8b5C84)
            ),
            8
        );
        feedInfos["WETH/USD"] = FeedInfo(
            AggregatorV3Interface(
                address(0x253E4f5040a3B1ADCc20D034b7D52650AA90D272)
            ),
            18
        );
        feedInfos["WFLOW/USD"] = FeedInfo(
            AggregatorV3Interface(
                address(0x78B348c0559F7e2f9BB70612a7766De200ec8bcc)
            ),
            18
        );
        feedInfos["ANKR/USD"] = FeedInfo(
            AggregatorV3Interface(
                address(0xb243C23EF13000e7107b021760a217434B513d50)
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

        for (uint256 i = 0; i < stableFeedsNames.length; i++) {
            for (uint256 j = 0; j < nonStableFeedsNames.length; j++) {
                baseVault = IERC4626(address(0));
                baseVaultConversionSample = 1;
                baseFeed1 = feedInfos[stableFeedsNames[i]].baseFeed;
                baseFeed2 = AggregatorV3Interface(address(0));
                baseDecimals = feedInfos[stableFeedsNames[i]].decimals;
                quoteVault = IERC4626(address(0));
                quoteVaultConversionSample = 1;
                quoteFeed1 = feedInfos[nonStableFeedsNames[j]].baseFeed;
                quoteFeed2 = AggregatorV3Interface(address(0));
                quoteDecimals = feedInfos[nonStableFeedsNames[j]].decimals;

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
                    // "Morpho oracle for ",
                    // stableFeedsNames[i],
                    // "and ",
                    // nonStableFeedsNames[j],
                    " deployed at ",
                    address(morphoOracleV2)
                );

                baseVault = IERC4626(address(0));
                baseVaultConversionSample = 1;
                baseFeed1 = feedInfos[nonStableFeedsNames[j]].baseFeed;
                baseFeed2 = AggregatorV3Interface(address(0));
                baseDecimals = feedInfos[nonStableFeedsNames[j]].decimals;
                quoteVault = IERC4626(address(0));
                quoteVaultConversionSample = 1;
                quoteFeed1 = feedInfos[stableFeedsNames[i]].baseFeed;
                quoteFeed2 = AggregatorV3Interface(address(0));
                quoteDecimals = feedInfos[stableFeedsNames[i]].decimals;

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
                    // "Morpho oracle for ",
                    // nonStableFeedsNames[j],
                    // " and ",
                    // stableFeedsNames[i],
                    " deployed at ",
                    address(morphoOracleV2)
                );
            }
        }

        baseVault = IERC4626(address(0));
        baseVaultConversionSample = 1;
        baseFeed1 = feedInfos["USDC/USD"].baseFeed;
        baseFeed2 = AggregatorV3Interface(address(0));
        baseDecimals = feedInfos["USDC/USD"].decimals;
        quoteVault = IERC4626(address(0));
        quoteVaultConversionSample = 1;
        quoteFeed1 = feedInfos["pyUsd/USD"].baseFeed;
        quoteFeed2 = AggregatorV3Interface(address(0));
        quoteDecimals = feedInfos["pyUsd/USD"].decimals;

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
            "Morpho oracle for USDC/USD and pyUsd/USD deployed at ",
            address(morphoOracleV2)
        );

        baseVault = IERC4626(address(0));
        baseVaultConversionSample = 1;
        baseFeed1 = feedInfos["WBTC/USD"].baseFeed;
        baseFeed2 = AggregatorV3Interface(address(0));
        baseDecimals = feedInfos["WBTC/USD"].decimals;
        quoteVault = IERC4626(address(0));
        quoteVaultConversionSample = 1;
        quoteFeed1 = feedInfos["WETH/USD"].baseFeed;
        quoteFeed2 = AggregatorV3Interface(address(0));
        quoteDecimals = feedInfos["WETH/USD"].decimals;

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
            "Morpho oracle for WBTC/USD and WETH/USD deployed at ",
            address(morphoOracleV2)
        );

        baseVault = IERC4626(address(0));
        baseVaultConversionSample = 1;
        baseFeed1 = feedInfos["WETH/USD"].baseFeed;
        baseFeed2 = AggregatorV3Interface(address(0));
        baseDecimals = feedInfos["WETH/USD"].decimals;
        quoteVault = IERC4626(address(0));
        quoteVaultConversionSample = 1;
        quoteFeed1 = feedInfos["WBTC/USD"].baseFeed;
        quoteFeed2 = AggregatorV3Interface(address(0));
        quoteDecimals = feedInfos["WBTC/USD"].decimals;

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
            "Morpho oracle for WETH/USD and WBTC/USD deployed at ",
            address(morphoOracleV2)
        );

        baseVault = IERC4626(address(0));
        baseVaultConversionSample = 1;
        baseFeed1 = feedInfos["WFLOW/USD"].baseFeed;
        baseFeed2 = AggregatorV3Interface(address(0));
        baseDecimals = feedInfos["WFLOW/USD"].decimals;
        quoteVault = IERC4626(address(0));
        quoteVaultConversionSample = 1;
        quoteFeed1 = feedInfos["WBTC/USD"].baseFeed;
        quoteFeed2 = AggregatorV3Interface(address(0));
        quoteDecimals = feedInfos["WBTC/USD"].decimals;

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
            "Morpho oracle for WFLOW/USD and WBTC/USD deployed at ",
            address(morphoOracleV2)
        );

        vm.stopBroadcast();
    }
}
