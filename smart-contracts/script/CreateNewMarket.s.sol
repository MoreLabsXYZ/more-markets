// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id, MathLib} from "../contracts/MoreMarkets.sol";
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

// // forge script script/CreateNewMarket.s.sol:CreateNewMarket --chain-id 747 --rpc-url https://mainnet.evm.nodes.onflow.org --broadcast -vv
contract CreateNewMarket is Script {
    using MarketParamsLib for MarketParams;
    ICreditAttestationService public credora;
    address public credoraAdmin;

    MoreMarkets public markets;
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

    uint256[] public premiumLltvsZero = [0, 0, 0, 0, 0];
    uint96 public categoryMultipliers = 2 ether;
    uint16[] public categorySteps = [4, 8, 12, 16, 24];

    ERC20MintableMock public USDCf =
        ERC20MintableMock(0x5e65b6B04fbA51D95409712978Cb91E99d93aE73);
    ERC20MintableMock public USDf =
        ERC20MintableMock(0xd7d43ab7b365f0d0789aE83F4385fA710FfdC98F);
    ERC20MintableMock public BTCf =
        ERC20MintableMock(0x208d09d2a6Dd176e3e95b3F0DE172A7471C5B2d6);
    ERC20MintableMock public ETHf =
        ERC20MintableMock(0x059A77239daFa770977DD9f1E98632C3E4559848);
    ERC20MintableMock public ANKR =
        ERC20MintableMock(0xe132751AB5A14ac0bD3Cb40571a9248Ee7a2a9EA);
    ERC20MintableMock public wFLOW =
        ERC20MintableMock(0xe0fd0a2A4C2E59a479AaB0cF44244E355C508766);

    address oracleUSDCfBTCf =
        address(0xC47106bb8103477225813b360200d9c889609653);
    address oracleBTCfUSDCf =
        address(0x273b835185bfC78551Bd4CB6230182908eaAF360);
    address oracleUSDCfETHf =
        address(0x5a15A5292ECbEd7De93A4147B448A34CDb9d9e72);
    address oracleETHfUSDCf =
        address(0x6580a3c3f663282C4A4C3987D66413686e23d3d0);
    address oracleUSDCfwFLOW =
        address(0x6DE0ec05e2de70d3C45c99497069bb2624847BA4);
    address oraclewFLOWUSDCf =
        address(0xE94F4ddf199006F32D83A3FB5738D2efeA4C8894);
    address oracleUSDCfANKR =
        address(0xbB82B26fFD3d198337727cD522918BeFA3B3A874);
    address oracleANKRUSDCf =
        address(0xd823916DCB2f709c592Fd33F02f8dc89384e835f);

    address oracleUSDfBTCf =
        address(0x31e69DB5205c7aeA466FBf7a13F263f982eB40EE);
    address oracleBTCfUSDf =
        address(0x7cbAE42e20C3d23b6E8c892a6A72DCEA297CadD2);
    address oracleUSDfETHf =
        address(0xE0d10202853798CCB3419108Dec13201a159485a);
    address oracleETHfUSDf =
        address(0xDDE1ddC9F16c77046F184Ef1184dD3F69e6a00cB);
    address oracleUSDfwFLOW =
        address(0x447E8e3596450efBdEf6d16d9F4A1D7a06Bbd034);
    address oraclewFLOWUSDf =
        address(0x8ac6e74EBac32F5787Ba00cD4548Bc6B9B9ddEA3);
    address oracleUSDfANKR =
        address(0x3aB80BaB63b4593169f3b0D7c9098F091Ac1dA29);
    address oracleANKRUSDf =
        address(0xbB3851F8F3d0A876096Bdc25Dc9022c6B2a8a78A);

    address oracleUSDCfUSDf =
        address(0x641a72aF874E2CAb030B767AA54Cac931a5459cd);
    address oracleBTCfETHf =
        address(0x36fd5D9cf6c3A18b65477eB56e497D75f68139E2);
    address oracleETHfBTCf =
        address(0x6EdED44649fB1188042cDDDD4097B9998B15999f);
    address oraclewFLOWBTCf =
        address(0xCE47CF8737dC882dcF21F0a79F2627415c5FD401);

    address oracleUSDfUSDCf =
        address(0x968EE176e2A8e1c9Ec3C06Ce0D911c886Dd20424);
    address oracleBTCfwFLOW =
        address(0x8857C969d0E40413AB9C8e972ACE186A39bE4071);

    // MAINNET

    address oracleMainnetwFlowAnkrFlow =
        address(0xA363e8627b5b4A5DC1cf6b5f228665C5CafF770f);
    address oracleMainnetAnkrFlowwFlow =
        address(0xC5aB0dA655760825c0b2746D9b865892B8A117Dc);
    address mainnetAnkrFlow =
        address(0x1b97100eA1D7126C4d60027e231EA4CB25314bdb);
    address mainnetWFlow = address(0xd3bF53DAC106A0290B0483EcBC89d40FcC961f3e);

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
            false,
            mainnetAnkrFlow,
            mainnetWFlow,
            address(oracleMainnetwFlowAnkrFlow),
            address(irm),
            lltv90,
            address(0),
            1 ether,
            premiumLltvsZero
        );
        markets.createMarket(marketParams);

        console.logBytes32(Id.unwrap(marketParams.id()));

        // loanToken.mint(address(owner), 1000000 ether);
        // loanToken.approve(address(markets), 1000000 ether);
        // collateralToken.mint(address(owner), 1000000 ether);
        // collateralToken.approve(address(markets), 1000000 ether);

        // markets.supply(marketParams, 10000 ether, 0, owner, "");

        vm.stopBroadcast();
    }
}
