// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id} from "../contracts/MoreMarkets.sol";
import {MathLib, UtilsLib, SharesMathLib, SafeTransferLib, EventsLib, ErrorsLib, IERC20, IIrm, IOracle, WAD} from "../contracts/fork/Morpho.sol";
import {IAprFeed} from "../contracts/interfaces/IAprFeed.sol";

// forge script script/GetMarketSupplyRate.s.sol:GetMarketSupplyRate --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vv
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
                        0x0f0de7ddadc86a7be1a3d3e1a9d2e8090a791299bcf0985626ae4ebd65add87e
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
            address(0x2e201ACF426D45949bF685312f99CBf4f4ceEeC5)
        ).getMarketSupplyRate(
                Id.wrap(
                    bytes32(
                        0x0f0de7ddadc86a7be1a3d3e1a9d2e8090a791299bcf0985626ae4ebd65add87e
                    )
                )
            );

        console.log(regularRate);
        console.log(premiumRate);

        // Start broadcasting for deployment
        vm.stopBroadcast();
    }
}
