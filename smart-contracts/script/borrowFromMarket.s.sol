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

// // forge script script/borrowFromMarket.s.sol:borrowFromMarket --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vvvv --slow
contract borrowFromMarket is Script {
    using MarketParamsLib for MarketParams;
    ICredoraMetrics public credora;
    address public credoraAdmin;
    OracleMock public oracle;

    MoreMarkets public markets;
    DebtTokenFactory public debtTokenFactorye;
    DebtToken public debtToken;
    address public owner;
    AdaptiveCurveIrm public irm;

    function setUp() public {}

    function run() external {
        // vm.startPrank(address(0x5D7de68283A0AFcd5A1411596577CC389CDF4BAE));
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        owner = address(uint160(vm.envUint("OWNER")));
        markets = MoreMarkets(vm.envAddress("MARKETS"));

        vm.startBroadcast(deployerPrivateKey);

        Id[] memory memAr = markets.arrayOfMarkets();
        uint256 length = memAr.length;
        console.log("lenght of memAr is %d", length);
        for (uint i = 0; i < length; i++) {
            console.log("- - - - - - - - - - - - - - - - - - - - - - - - - -");
            // console.log("market id is ", memAr[i]);
            // (
            //     uint128 totalSupplyAssets,
            //     uint128 totalSupplyShares,
            //     uint128 totalBorrowAssets,
            //     uint128 totalBorrowShares,
            //     uint128 lastUpdate,
            //     uint128 fee
            // ) = markets.market(memAr[i]);
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
            MarketParams memory marketParams = MarketParams({
                isPremiumMarket: isPremium,
                loanToken: loanToken,
                collateralToken: collateralToken,
                oracle: marketOracle,
                irm: marketIrm,
                lltv: lltv,
                creditAttestationService: creditAttestationService,
                irxMaxLltv: irxMaxLltv,
                categoryLltv: categoryLltv
            });
            ERC20MintableMock(collateralToken).approve(
                address(markets),
                100000 ether
            );
            // markets.supplyCollateral(marketParams, 10 ether, owner, "");
            markets.borrow(marketParams, 7 ether, 0, owner, owner);
        }

        // Start broadcasting for deployment
        vm.stopBroadcast();
    }
}
