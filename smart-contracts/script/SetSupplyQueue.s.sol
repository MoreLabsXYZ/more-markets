// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreVaults} from "../contracts/MoreVaults.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id, MathLib} from "../contracts/MoreMarkets.sol";

// forge script script/SetSupplyQueue.s.sol:SetSupplyQueue --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vvvv --slow
contract SetSupplyQueue is Script {
    using MarketParamsLib for MarketParams;

    MoreVaults moreVault;
    MoreMarkets markets;

    uint256[] public lltvs = [
        800000000000000000,
        945000000000000000,
        965000000000000000
    ];

    uint8 numberOfPremiumBuckets = 5;
    uint256[] public premiumLltvs = [
        1000000000000000000,
        1200000000000000000,
        1400000000000000000,
        1600000000000000000,
        2000000000000000000
    ];
    uint96 public categoryMultipliers = 2 ether;
    uint16[] public categorySteps = [4, 8, 12, 16, 24];

    MarketParams public marketParams;

    Id[] public marketsArray;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        moreVault = MoreVaults(vm.envAddress("MORE_VAULT"));
        markets = MoreMarkets(vm.envAddress("MARKETS"));

        Id[] memory memAr = markets.arrayOfMarkets();
        vm.startBroadcast(deployerPrivateKey);
        uint256 length = memAr.length;
        console.log("lenght of memAr is %d", length);
        for (uint256 i = 0; i < length; i++) {
            console.log("- - - - - - - - - - - - - - - - - - - - - - - - - -");
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
            ) = markets.idToMarketParams(memAr[i]);
            marketParams.isPremiumMarket = isPremium;
            marketParams.loanToken = loanToken;
            marketParams.collateralToken = collateralToken;
            marketParams.oracle = marketOracle;
            marketParams.irm = marketIrm;
            marketParams.lltv = lltv;
            marketParams.creditAttestationService = creditAttestationService;
            marketParams.irxMaxLltv = irxMaxLltv;
            marketParams.categoryLltv = categoryLltv;

            if (
                marketParams.loanToken ==
                address(0x58f3875DBeFcf784Ea40A886eC24e3C3FaB2dB19)
            ) {
                console.log(moreVault.asset());
                console.log("dosmth");
                moreVault.submitCap(marketParams, 1000 ether);
                moreVault.acceptCap(marketParams);
                marketsArray.push(marketParams.id());
            }
        }

        moreVault.setSupplyQueue(marketsArray);

        vm.stopBroadcast();
    }
}
