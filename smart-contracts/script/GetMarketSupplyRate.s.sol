// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id} from "../contracts/MoreMarkets.sol";
import {MathLib, UtilsLib, SharesMathLib, SafeTransferLib, EventsLib, ErrorsLib, IERC20, IIrm, IOracle, WAD} from "../contracts/fork/Morpho.sol";
import {IAprFeed} from "../contracts/interfaces/IAprFeed.sol";

// forge script script/GetMarketSupplyRate.s.sol:GetMarketSupplyRate --chain-id 747 --rpc-url https://mainnet.evm.nodes.onflow.org --broadcast -vv
contract GetMarketSupplyRate is Script {
    using MarketParamsLib for MarketParams;
    using MathLib for uint256;

    MoreMarkets public markets;
    address public owner;

    MarketParams public marketParams;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        owner = address(uint160(vm.envUint("OWNER")));
        markets = MoreMarkets(vm.envAddress("MARKETS"));

        vm.startBroadcast(deployerPrivateKey);

        (
            bool isPremium,
            address loanToken,
            address collateralToken,
            address marketOracle,
            address marketIrm,
            uint256 lltv,
            address creditAttestationService,
            uint96 irxMaxLltv,
            uint256[] memory categoryLltv
        ) = markets.idToMarketParams(
                Id.wrap(
                    bytes32(
                        0x93c256e9fa38ee67d0b6cd5bac0aae32cc0498d5a1103ba52d41b772b82c2bef
                    )
                )
            );
        marketParams.isPremiumMarket = isPremium;
        marketParams.loanToken = loanToken;
        marketParams.collateralToken = collateralToken;
        marketParams.oracle = marketOracle;
        marketParams.irm = marketIrm;
        marketParams.lltv = lltv;
        marketParams.creditAttestationService = creditAttestationService;
        marketParams.irxMaxLltv = irxMaxLltv;
        marketParams.categoryLltv = categoryLltv;

        (uint256 regularRate, uint256 premiumRate) = IAprFeed(
            address(0x266340Dc2bDDCc7D37B1d19412a67e445b6D0E5a)
        ).getMarketSupplyRate(
                Id.wrap(
                    bytes32(
                        0x93c256e9fa38ee67d0b6cd5bac0aae32cc0498d5a1103ba52d41b772b82c2bef
                    )
                )
            );

        console.log(regularRate);
        console.log(premiumRate);

        // Start broadcasting for deployment
        vm.stopBroadcast();
    }
}
