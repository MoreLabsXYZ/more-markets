// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id, MathLib} from "../contracts/MoreMarkets.sol";
import {DebtTokenFactory} from "../contracts/factories/DebtTokenFactory.sol";
import {DebtToken} from "../contracts/tokens/DebtToken.sol";
import {ICreditAttestationService} from "../contracts/interfaces/ICreditAttestationService.sol";
import {OracleMock} from "../contracts/mocks/OracleMock.sol";
import {AdaptiveCurveIrm} from "../contracts/AdaptiveCurveIrm.sol";
import {MathLib, UtilsLib, SharesMathLib, SafeTransferLib, EventsLib, ErrorsLib, IERC20, IIrm, IOracle, WAD} from "@morpho-org/morpho-blue/src/Morpho.sol";

import {ERC20MintableMock} from "../contracts/mocks/ERC20MintableMock.sol";

// // forge script script/supplyToMarket.s.sol:supplyToMarket --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vvvv --slow
contract supplyToMarket is Script {
    using MarketParamsLib for MarketParams;
    ICreditAttestationService public credora;
    address public credoraAdmin;
    OracleMock public oracle;

    MoreMarkets public markets;
    DebtTokenFactory public debtTokenFactorye;
    DebtToken public debtToken;
    address public owner;
    AdaptiveCurveIrm public irm;

    // MarketParams public marketParams;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting for deploymentcredoraAdmin = vm.envAddress("CREDORA_ADMIN");
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
            ERC20MintableMock(loanToken).mint(owner, 100000 ether);
            ERC20MintableMock(loanToken).approve(
                address(markets),
                100000 ether
            );
            markets.supply(marketParams, 10000 ether, 0, owner, "");
        }

        // Start broadcasting for deployment
        vm.stopBroadcast();
    }
}
