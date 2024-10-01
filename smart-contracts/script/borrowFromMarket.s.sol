// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Vm, StdCheats, Test, console} from "forge-std/Test.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id, MathLib} from "../contracts/MoreMarkets.sol";
import {ICreditAttestationService} from "../contracts/interfaces/ICreditAttestationService.sol";
import {OracleMock} from "../contracts/mocks/OracleMock.sol";
import {AdaptiveCurveIrm} from "../contracts/AdaptiveCurveIrm.sol";
import {MathLib, UtilsLib, SharesMathLib, SafeTransferLib, EventsLib, ErrorsLib, IERC20, IIrm, IOracle, WAD} from "../contracts/fork/Morpho.sol";

import {ERC20MintableMock} from "../contracts/mocks/ERC20MintableMock.sol";

// // forge script script/borrowFromMarket.s.sol:borrowFromMarket --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vvvv --slow
contract borrowFromMarket is Script {
    using MarketParamsLib for MarketParams;
    ICreditAttestationService public credora;
    address public credoraAdmin;
    OracleMock public oracle;

    MoreMarkets public markets;
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
        ) = markets.idToMarketParams(
                Id.wrap(
                    bytes32(
                        0x75a964099ef99a0c7dc893c659a4dec8f6beeb3d7c9705e28df7d793694b6164
                    )
                )
            );
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
        ERC20MintableMock(collateralToken).mint(
            address(owner),
            60000 * 10 ** ERC20MintableMock(collateralToken).decimals()
        );
        ERC20MintableMock(collateralToken).approve(
            address(markets),
            100000 ether
        );
        markets.supplyCollateral(
            marketParams,
            30000 * 10 ** ERC20MintableMock(collateralToken).decimals(),
            owner,
            ""
        );
        markets.borrow(marketParams, 0.1e8, 0, owner, owner);

        // ERC20MintableMock(loanToken).mint(
        //     address(owner),
        //     10000 * 10 ** ERC20MintableMock(loanToken).decimals()
        // );
        // ERC20MintableMock(loanToken).approve(address(markets), 100000 ether);
        // (
        //     uint128 supplyShares,
        //     uint128 borrowShares,
        //     uint128 collateral,
        //     ,
        //     ,

        // ) = markets.position(
        //         Id.wrap(
        //             bytes32(
        //                 0x16893ff750ddec34e292a65a8cb6a014627b3f4ad0b2b82c6da4cc28d1e0576d
        //             )
        //         ),
        //         address(0x83fbd218bD0CAB5dC90D3b55E14eADaEB1e72b9D)
        //     );
        // console.log(borrowShares);
        // // markets.totalBorrowAssetsForMultiplier(
        // //     Id.wrap(
        // //         bytes32(
        // //             0x6bed9b33d3ee7142f53ba4cf930d61e4aff25a4677150cfe354e9b75a2ee2547
        // //         )
        // //     ),
        // //     0
        // // );
        // markets.repay(
        //     marketParams,
        //     0,
        //     borrowShares,
        //     address(0x83fbd218bD0CAB5dC90D3b55E14eADaEB1e72b9D),
        //     ""
        // );
        // markets.withdraw(marketParams, 0, supplyShares, owner, owner);
        // markets.withdrawCollateral(marketParams, collateral, owner, owner);
        // }

        // (
        //     uint128 supplyShares,
        //     uint128 borrowShares,
        //     uint128 collateral,
        //     ,
        //     ,

        // ) = markets.position(memAr[length - 2], owner);

        // console.log("supply shares: ", supplyShares);
        // console.log("borrow shares: ", borrowShares);
        // console.log("collateral: ", collateral);
        // Start broadcasting for deployment
        vm.stopBroadcast();
    }
}
