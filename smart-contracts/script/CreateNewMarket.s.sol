// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id, MathLib} from "../contracts/MoreMarkets.sol";
import {DebtTokenFactory} from "../contracts/factories/DebtTokenFactory.sol";
import {DebtToken} from "../contracts/tokens/DebtToken.sol";
import {ICreditAttestationService} from "../contracts/interfaces/ICreditAttestationService.sol";
import {OracleMock} from "../contracts/mocks/OracleMock.sol";
import {AdaptiveCurveIrm} from "../contracts/AdaptiveCurveIrm.sol";

import {ERC20MintableMock} from "../contracts/mocks/ERC20MintableMock.sol";

// forge verify-contract \
//   --rpc-url https://evm-testnet.flowscan.io/api/eth-rpc \
//   --verifier blockscout \
//   --verifier-url 'https://evm-testnet.flowscan.io/api' \
//   --chain-id 545\
//   --constructor-args $(cast abi-encode "constructor(address)" 0x665EB1F72f2c0771A9C7305b8d735d5410FF3246) \
//   0x66832a1C487aBf864BeC15b0A636b739f41c05E5 \
//   contracts/MoreVaultsFactory.sol:MoreVaultsFactory

// // forge script script/CreateNewMarket.s.sol:CreateNewMarket --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vvvv --slow
contract CreateNewMarket is Script {
    using MarketParamsLib for MarketParams;
    ICreditAttestationService public credora;
    address public credoraAdmin;

    MoreMarkets public markets;
    DebtTokenFactory public debtTokenFactorye;
    DebtToken public debtToken;
    address public owner;
    AdaptiveCurveIrm public irm;

    uint256[] public lltvs = [
        720000000000000000,
        770000000000000000,
        800000000000000000,
        850000000000000000,
        900000000000000000
    ];

    uint256 lltv72 = 720000000000000000;
    uint256 lltv77 = 770000000000000000;
    uint256 lltv80 = 800000000000000000;
    uint256 lltv85 = 850000000000000000;
    uint256 lltv90 = 900000000000000000;

    uint8 numberOfPremiumBuckets = 5;
    uint256[] public premiumLltvs = [
        800000000000000000,
        800000000000000000,
        870000000000000000,
        940000000000000000,
        940000000000000000
    ];
    uint96 public categoryMultipliers = 2 ether;
    uint16[] public categorySteps = [4, 8, 12, 16, 24];

    ERC20MintableMock public USDCf =
        ERC20MintableMock(0xaCA1aB5EB856F7645Cd6b9694bA840f3C18BC83e);
    ERC20MintableMock public USDf =
        ERC20MintableMock(0x4D40CDcE3864CA8FCBA1B7De4C0a66f37b28092c);
    ERC20MintableMock public BTCf =
        ERC20MintableMock(0x866E7292A4b9813146591Cb6211AAc33432cF07f);
    ERC20MintableMock public ETHf =
        ERC20MintableMock(0x50bE444228F6f27899E52E56718C0ae67F962185);
    ERC20MintableMock public wFLOW =
        ERC20MintableMock(0xe6De44AC50C1D1C83f67695f6B4820a317285FC6);
    ERC20MintableMock public ANKR =
        ERC20MintableMock(0x3D08ce8bA948ddd6ab0745670134A55e8e35aA8C);

    address oracleUSDCfBTCf =
        address(0x3793d612cf2BCe408B361379d69E10516Fceb3e7);
    address oracleBTCfUSDCf =
        address(0xe2bA4ddF1031c93b31Ea348D020B277812447936);
    address oracleUSDCfETHf =
        address(0xdeCbe2260EB3A63DC19f818eCcCc8E74eCe04987);
    address oracleETHfUSDCf =
        address(0x58a03e26Ee5a286ac35a98c07798140260Ca5AD6);
    address oracleUSDCfwFLOW =
        address(0xdF507A8662c8f309c7085dAE5B605cc2821f4ae6);
    address oraclewFLOWUSDCf =
        address(0xb7B656441fE69Ae755E61ea296CA8706C6dADB30);
    address oracleUSDCfANKR =
        address(0x54533D32EEe58772B72aE1F5af52f83DCaFcBB6D);
    address oracleANKRUSDCf =
        address(0x3e65485A823321e20B5ac6800Dc40a18E82FAB05);

    address oracleUSDfBTCf =
        address(0x302024D8CA6Fe5B0f217767eB112c752461E8dbF);
    address oracleBTCfUSDf =
        address(0x765E72875a78215Fa127D87bbF113Ae39D4C5e8A);
    address oracleUSDfETHf =
        address(0xc5a19C1DFFb285202B122C6b8D166C7b525cBB98);
    address oracleETHfUSDf =
        address(0x22c8203afafa4614FCF04EFB5C7Ec05c55B1b97a);
    address oracleUSDfwFLOW =
        address(0x3954e987278a6a9d3Fa891282Cc18E66393D3236);
    address oraclewFLOWUSDf =
        address(0x438085beec56255478E534e81399c513cC9031c9);
    address oracleUSDfANKR =
        address(0xFA63102390C63A0CcE67102E434bc466b656A57a);
    address oracleANKRUSDf =
        address(0x55146B2DB99D1A6912a47590c9Ce8aB66EfA784f);

    address oracleUSDCfUSDf =
        address(0xe0B35890C829767DF0C3968238d263a7d640bA46);
    address oracleBTCfETHf =
        address(0x94509717fecF2D13ae62b7CaFD6A55FE54c963f7);
    address oracleETHfBTCf =
        address(0x3EE658322060FD5120f5f33AB52377619847865c);
    address oraclewFLOWBTCf =
        address(0x9aB242f91128B5b2ed1A063E61aaeC7876299388);

    MarketParams public marketParams;

    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting for deploymentcredoraAdmin = vm.envAddress("CREDORA_ADMIN");
        owner = address(uint160(vm.envUint("OWNER")));
        credora = ICreditAttestationService(vm.envAddress("CREDORA_METRICS"));
        // oracle = OracleMock(vm.envAddress("ORACLE"));
        markets = MoreMarkets(vm.envAddress("MARKETS"));
        irm = AdaptiveCurveIrm(vm.envAddress("IRM"));

        vm.startBroadcast(deployerPrivateKey);

        // minting mocks for testnet
        // loanToken = new ERC20MintableMock(owner, "ripple", "RPX");
        // collateralToken = new ERC20MintableMock(owner, "Tether USD", "USDT");
        // loanToken = ERC20MintableMock(
        //     0x58f3875DBeFcf784Ea40A886eC24e3C3FaB2dB19
        // );
        // collateralToken = ERC20MintableMock(
        //     0xc4dD98f4ECEbFB0F86fF6f8a60668Cf60c45E830
        // );

        // create a market
        marketParams = MarketParams(
            true,
            address(wFLOW),
            address(BTCf),
            address(oraclewFLOWBTCf),
            address(irm),
            lltv72,
            address(credora),
            2 ether,
            premiumLltvs
        );
        markets.createMarket(marketParams);

        // loanToken.mint(address(owner), 1000000 ether);
        // loanToken.approve(address(markets), 1000000 ether);
        // collateralToken.mint(address(owner), 1000000 ether);
        // collateralToken.approve(address(markets), 1000000 ether);

        // markets.supply(marketParams, 10000 ether, 0, owner, "");

        // Start broadcasting for deployment
        vm.stopBroadcast();
    }
}
