// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id, MathLib} from "../contracts/MoreMarkets.sol";
import {ICreditAttestationService} from "../contracts/interfaces/ICreditAttestationService.sol";
import {OracleMock} from "../contracts/mocks/OracleMock.sol";
import {AdaptiveCurveIrm} from "../contracts/AdaptiveCurveIrm.sol";
import {MathLib, UtilsLib, SharesMathLib, SafeTransferLib, EventsLib, ErrorsLib, IERC20, IIrm, IOracle, WAD} from "../contracts/fork/Morpho.sol";

import {ERC20MintableMock} from "../contracts/mocks/ERC20MintableMock.sol";

contract ownerSettersMarkets is Script {
    using MarketParamsLib for MarketParams;
    ICreditAttestationService public credora;
    address public credoraAdmin;
    OracleMock public oracle;

    MoreMarkets public markets;
    address public owner;
    AdaptiveCurveIrm public irm;

    MarketParams public marketParams;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting for deploymentcredoraAdmin = vm.envAddress("CREDORA_ADMIN");
        owner = address(uint160(vm.envUint("OWNER")));
        credora = ICreditAttestationService(vm.envAddress("CREDORA_METRICS"));
        oracle = OracleMock(vm.envAddress("ORACLE"));
        markets = MoreMarkets(vm.envAddress("MARKETS"));
        irm = AdaptiveCurveIrm(vm.envAddress("IRM"));

        vm.startBroadcast(deployerPrivateKey);

        // @dev uncomment
        // markets.setCreditAttestationService(address(credora));

        // markets.enableIrm(irm);

        // uint256 lltv = 12345;
        // markets.enableLltv(lltv);
        // address feeRecipient = ;
        // markets.setFeeRecipient(feeRecipient);

        // Start broadcasting for deployment
        vm.stopBroadcast();
    }
}
