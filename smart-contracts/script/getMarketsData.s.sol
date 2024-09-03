// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id, MathLib, NothingToClaim} from "../contracts/MoreMarkets.sol";
import {DebtTokenFactory} from "../contracts/factories/DebtTokenFactory.sol";
import {DebtToken} from "../contracts/tokens/DebtToken.sol";
import {ICredoraMetrics} from "../contracts/interfaces/ICredoraMetrics.sol";
import {OracleMock} from "../contracts/mocks/OracleMock.sol";
import {AdaptiveCurveIrm} from "../contracts/AdaptiveCurveIrm.sol";
import {MathLib, UtilsLib, SharesMathLib, SafeTransferLib, EventsLib, ErrorsLib, IERC20, IIrm, IOracle, WAD} from "../contracts/fork/Morpho.sol";

import {ERC20MintableMock} from "../contracts/mocks/ERC20MintableMock.sol";

// forge script script/getMarketsData.s.sol:getMarketsData --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vvvv
contract getMarketsData is Script {
    using MarketParamsLib for MarketParams;
    ICredoraMetrics public credora;
    address public credoraAdmin;
    OracleMock public oracle;

    MoreMarkets public markets;
    DebtTokenFactory public debtTokenFactory;
    DebtToken public debtToken;
    address public owner;
    AdaptiveCurveIrm public irm;

    MarketParams public marketParams;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        owner = address(uint160(vm.envUint("OWNER")));
        markets = MoreMarkets(vm.envAddress("MARKETS"));

        vm.startBroadcast(deployerPrivateKey);

        Id[] memory memAr = markets.arrayOfMarkets();
        uint256 length = memAr.length;
        console.log("lenght of memAr is %d", length);
        for (uint256 i = 0; i < length; i++) {
            console.log("- - - - - - - - - - - - - - - - - - - - - - - - - -");
            // console.log("market id is ", memAr[i]);

            Market memory market;
            // stack to deep avoiding, to run coverage safely, since foundry doesn't provide the way to exclude files from coverage
            {
                (
                    uint128 totalSupplyAssets,
                    uint128 totalSupplyShares,
                    uint128 totalBorrowAssets,
                    uint128 totalBorrowShares,
                    uint128 lastUpdate,
                    uint128 fee
                ) = markets.market(memAr[i]);
                market.totalSupplyAssets = totalSupplyAssets;
                market.totalSupplyShares = totalSupplyShares;
                market.totalBorrowAssets = totalBorrowAssets;
                market.totalBorrowShares = totalBorrowShares;
                market.lastUpdate = lastUpdate;
                market.fee = fee;
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
                marketParams
                    .creditAttestationService = creditAttestationService;
                marketParams.irxMaxLltv = irxMaxLltv;
                marketParams.categoryLltv = categoryLltv;
            }
            console.log(
                "total supply asset for market is ",
                market.totalSupplyAssets
            );
            console.log(
                "total supply shares for market is ",
                market.totalSupplyShares
            );
            console.log(
                "total borrow assets for market is ",
                market.totalBorrowAssets
            );
            console.log(
                "total borrow shares for market is ",
                market.totalBorrowShares
            );
            console.log("last update for market is ", market.lastUpdate);
            console.log("fee for market is ", market.fee);

            console.log("is market premium ", marketParams.isPremiumMarket);
            console.log("loan token is ", marketParams.loanToken);
            console.log("collateral token is ", marketParams.collateralToken);
            console.log("market oracle is ", marketParams.oracle);
            console.log("market Irm is ", marketParams.irm);
            console.log("lltv is ", marketParams.lltv);
            console.log(
                "credit attestation service is ",
                marketParams.creditAttestationService
            );
            console.log("irx max lltv is ", marketParams.irxMaxLltv);
            for (uint256 j; j < marketParams.categoryLltv.length; ) {
                console.log(
                    "category #",
                    j,
                    " lltv is ",
                    marketParams.categoryLltv[j]
                );
                unchecked {
                    ++j;
                }
            }
        }

        // Start broadcasting for deployment
        vm.stopBroadcast();
    }
}
