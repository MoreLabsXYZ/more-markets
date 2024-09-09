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

        // TODO script can be improved by reading these values from the environment or JSON CONFIG
        // address initialOwner = 0x2690eEF879dF58B97ec7CF830F7627Fb1B51f826;
        // uint256 initialTimelock = 100;
        // address asset1 = 0xdC9C26ECbB6Af88ac6E44e9e0cc85743B4701291;
        // address asset2 = 0xbe36C502663c3F08c7080f632031C370F745C3aC;
        // address asset3 = 0xC4F1dFC005Cb2285b8A9Ede7c525b0eEdF24F5db;
        address initialOwner = address(uint160(vm.envUint("OWNER")));
        uint256 initialTimelock = 0;
        address asset1 = address(0xBbd2cff02c8b908Dcb4B2C0aBf59622129BB32C0);
        string memory name1 = "MOCK VAULT 1";
        string memory symbol1 = "MCKVLT1";

        bytes32 salt = "1";

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
