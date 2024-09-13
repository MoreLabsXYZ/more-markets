// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreVaults} from "../contracts/MoreVaults.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id, MathLib} from "../contracts/MoreMarkets.sol";

// forge script script/SetSupplyQueue.s.sol:SetSupplyQueue --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vv --slow
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

    // sentinel
    bytes32 MarketIdUSDfxFLOW =
        bytes32(
            0x769217350736fc9c8a2b7814717e497e0fe4e78e5c52c90c1e6ffae68e7160fb
        );
    bytes32 MarketIdUSDfxANKR =
        bytes32(
            0x512297e2ec6b1e2d1b4c7f2d70bec4bb454536048426251fb12464d371a48d61
        );

    // prime
    bytes32 MarketIdwFLOWxBTCf =
        bytes32(
            0x5c3f0292d070a566c7ec11372b1c5402979251a270d3c58f08cbe8cd1d031790
        );
    bytes32 MarketIdwFLOWxUSDf =
        bytes32(
            0x88a1d6d0295e9416d5cd017e0c3a83dacca5a35f4768e9d69ea532816ff8d221
        );

    // horizon
    bytes32 MarketIdwUSDCfxBTCf =
        bytes32(
            0x768bb35d4960f49298d3f3222c43a808c98c23366b9e8f4637063bf142aea245
        );
    bytes32 MarketIdwUSDCfxETHf =
        bytes32(
            0x64bc2e22799fd7c2eb29aa0a2a9feca73786de3b7c5bb77529cdca7179d50e34
        );
    bytes32 MarketIdwUSDCfxUSDf =
        bytes32(
            0xa6d374693ad40a81d35f62a5eae559ee498bba536788eabdf886a8a80dd07987
        );

    // apex

    // nimbus
    bytes32 MarketIdBTCfxUSDCf =
        bytes32(
            0x234dd8f59c552f9d3e7dc7ae4bb27da08a2184e567fd265ad024a0d0bf9bab73
        );

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        moreVault = MoreVaults(vm.envAddress("NIMBUS_VAULT"));
        markets = MoreMarkets(vm.envAddress("MARKETS"));
        address owner = vm.envAddress("OWNER");

        vm.startBroadcast(deployerPrivateKey);
        marketsArray.push(Id.wrap(MarketIdBTCfxUSDCf));
        // marketsArray.push(Id.wrap(MarketIdwFLOWxBTCf));
        // marketsArray.push(Id.wrap(MarketIdwUSDCfxUSDf));

        marketParams = getMarketParams(Id.wrap(MarketIdBTCfxUSDCf));

        moreVault.submitCap(marketParams, 10000 * 1e8);
        // moreVault.acceptCap(marketParams);

        // marketParams = getMarketParams(Id.wrap(MarketIdwFLOWxBTCf));

        // moreVault.submitCap(marketParams, 9000 * 1e18);
        // moreVault.acceptCap(marketParams);

        // moreVault.setSupplyQueue(marketsArray);
        // moreVault.setFeeRecipient(owner);
        // moreVault.setFee(0.15e18);
        // moreVault.setCurator(
        //     address(0xA1947019F5989c5C417cc6EEcE404d684b855bB2)
        // );

        vm.stopBroadcast();
    }

    function getMarketParams(
        Id marketId
    ) internal view returns (MarketParams memory _marketParams) {
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
        ) = markets.idToMarketParams(marketId);
        _marketParams.isPremiumMarket = isPremium;
        _marketParams.loanToken = loanToken;
        _marketParams.collateralToken = collateralToken;
        _marketParams.oracle = marketOracle;
        _marketParams.irm = marketIrm;
        _marketParams.lltv = lltv;
        _marketParams.creditAttestationService = creditAttestationService;
        _marketParams.irxMaxLltv = irxMaxLltv;
        _marketParams.categoryLltv = categoryLltv;
    }
}
