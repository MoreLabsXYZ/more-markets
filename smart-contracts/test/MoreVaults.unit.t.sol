// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {IMoreMarkets} from "../contracts/interfaces/IMoreMarkets.sol";
import {IMetaMorpho} from "../contracts/interfaces/IMetaMorpho.sol";
import {IMetaMorphoFactory} from "../contracts/interfaces/IMetaMorphoFactory.sol";
import {Id, MoreMarkets, MarketParams, MarketParamsLib} from "../contracts/MoreMarkets.sol";
import {MoreVaultsFactory, PremiumFeeInfo, ErrorsLib, OwnableUpgradeable} from "../contracts/MoreVaultsFactory.sol";
import {MoreVaults, IERC20Upgradeable, MathUpgradeable} from "../contracts/MoreVaults.sol";
import {ERC20MintableMock} from "../contracts/mocks/ERC20MintableMock.sol";
import {DebtTokenFactory} from "../contracts/factories/DebtTokenFactory.sol";
import {DebtToken} from "../contracts/tokens/DebtToken.sol";
import {ICreditAttestationService} from "../contracts/interfaces/ICreditAttestationService.sol";
import {OracleMock} from "../contracts/mocks/OracleMock.sol";
import {AdaptiveCurveIrm} from "../contracts/AdaptiveCurveIrm.sol";

contract MoreVaultsTest is Test {
    using MarketParamsLib for MarketParams;
    using MathUpgradeable for uint256;

    MoreVaultsFactory factory;
    MoreVaults implementation;
    ERC20MintableMock asset;

    ICreditAttestationService public credora =
        ICreditAttestationService(
            address(0x29306A367e1185BbC2a8E92A54a33c0B52350564)
        );
    address public credoraAdmin =
        address(0x98ADc891Efc9Ce18cA4A63fb0DfbC2864566b5Ab);

    OracleMock public oracle;

    MoreMarkets public markets;
    DebtTokenFactory public debtTokenFactory;
    DebtToken public debtToken;
    address public owner = address(0x89a76D7a4D006bDB9Efd0923A346fAe9437D434F);
    AdaptiveCurveIrm public irm;

    uint256 sepoliaFork;
    uint256 flowTestnetFork;

    address alice = address(0x1234);
    address deployer = address(0xde410e4);

    uint96 maxFee = 1e18;

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
    uint96 public categoryMultiplier = 2 ether;
    uint16[] public categorySteps = [4, 8, 12, 16, 24];

    ERC20MintableMock public loanToken;
    ERC20MintableMock public collateralToken;
    MarketParams public marketParams;

    address initialOwner = owner;
    uint256 initialTimelock = 0;
    string name = "MOCK VAULT 1";
    string symbol = "MOCK1";
    bytes32 salt = "1";

    IMetaMorpho vault;

    address premiumFeeRecipient = address(0x12345678);
    address feeRecipient = address(0x1234567890);

    function setUp() public {
        sepoliaFork = vm.createFork(
            "https://eth-sepolia.g.alchemy.com/v2/jXLoZTSjTIhZDB9nNhJsSmvrcMAbdrNT"
        );
        flowTestnetFork = vm.createFork("https://testnet.evm.nodes.onflow.org");
        vm.selectFork(flowTestnetFork);

        debtToken = new DebtToken();
        debtTokenFactory = new DebtTokenFactory(address(debtToken));
        // markets = new MoreMarkets(owner, address(debtTokenFactory));
        markets = new MoreMarkets();
        markets.initialize(owner, address(debtTokenFactory));
        irm = new AdaptiveCurveIrm(address(markets));
        oracle = new OracleMock();
        // set price as 1 : 1
        oracle.setPrice(1000000000000000000000000000000000000);

        startHoax(owner);
        markets.enableIrm(address(irm));
        markets.setMaxLltvForCategory(premiumLltvs[4]);

        for (uint256 i; i < lltvs.length; ) {
            markets.enableLltv(lltvs[i]);
            unchecked {
                ++i;
            }
        }

        loanToken = new ERC20MintableMock(owner, "Loan Mock Token", "LMT");
        collateralToken = new ERC20MintableMock(
            owner,
            "Collateral Mock Token",
            "CMT"
        );

        marketParams = MarketParams(
            true,
            address(loanToken),
            address(collateralToken),
            address(oracle),
            address(irm),
            lltvs[0],
            address(credora),
            categoryMultiplier,
            premiumLltvs
        );
        markets.createMarket(marketParams);

        loanToken.mint(address(owner), 1000000 ether);
        loanToken.approve(address(markets), 1000000 ether);
        collateralToken.mint(address(owner), 1000000 ether);
        collateralToken.approve(address(markets), 1000000 ether);

        startHoax(credoraAdmin);
        credora.setData(
            0,
            abi.encode(
                owner,
                uint256(190 * 10 ** 18),
                uint64(0),
                bytes8("AAA+"),
                uint64(0),
                uint64(0),
                uint64(0)
            ),
            ""
        );

        startHoax(owner);

        implementation = new MoreVaults();

        // factory = new MoreVaultsFactory(
        //     address(markets),
        //     address(implementation)
        // );
        factory = new MoreVaultsFactory();
        factory.initialize(address(markets), address(implementation));

        vault = factory.createMetaMorpho(
            initialOwner,
            initialTimelock,
            address(loanToken),
            name,
            symbol,
            salt
        );

        vault.submitCap(marketParams, 10000 ether);
        vault.acceptCap(marketParams);

        Id[] memory supplyQueue = new Id[](1);
        supplyQueue[0] = marketParams.id();
        vault.setSupplyQueue(supplyQueue);
    }

    function test_premiumFee_shouldReturnCorrectAmountOfPremiumFeesWhenDefaultFeeIsSet(
        uint96 premiumFeePercent,
        uint96 defaultFeePercent
    ) public {
        vm.assume(premiumFeePercent <= 1e18);
        vm.assume(defaultFeePercent <= 0.5e18 && defaultFeePercent != 0);

        vault.setFeeRecipient(feeRecipient);
        vault.setFee(defaultFeePercent);

        PremiumFeeInfo memory feeInfo = PremiumFeeInfo(
            premiumFeeRecipient,
            premiumFeePercent
        );

        factory.setFeeInfo(address(vault), feeInfo);

        loanToken.approve(address(vault), 1000000 ether);
        vault.deposit(5000 ether, owner);

        markets.supplyCollateral(marketParams, 1000 ether, owner, "");
        markets.borrow(marketParams, 700 ether, 0, owner, owner);

        uint256 timeToSkip = 1 days;

        uint256 balanceOfOwner = vault.balanceOf(owner);
        skip(timeToSkip);

        balanceOfOwner = vault.balanceOf(owner);

        uint256 premiumFeeRecipientBalanceBefore = loanToken.balanceOf(
            premiumFeeRecipient
        );
        uint256 feeRecipientBalanceBefore = loanToken.balanceOf(feeRecipient);

        markets.supply(marketParams, 10000 ether, 0, owner, "");
        vault.redeem(balanceOfOwner, owner, owner);

        uint256 premiumFee = loanToken.balanceOf(premiumFeeRecipient) -
            premiumFeeRecipientBalanceBefore;
        uint256 defaultFee = loanToken.balanceOf(feeRecipient) -
            feeRecipientBalanceBefore;
        uint256 totalFees = premiumFee + defaultFee;

        assertEq(premiumFee, totalFees.mulDiv(premiumFeePercent, 1e18));
        assertEq(defaultFee, totalFees.mulDiv(defaultFeePercent, 1e18));
    }

    function test_premiumFee_shouldNotMintAnyFeeSharesIfDefaultFeeIsZero(
        uint96 premiumFeePercent
    ) public {
        vm.assume(premiumFeePercent <= 1e18);

        vault.setFeeRecipient(feeRecipient);

        PremiumFeeInfo memory feeInfo = PremiumFeeInfo(
            premiumFeeRecipient,
            premiumFeePercent
        );

        factory.setFeeInfo(address(vault), feeInfo);

        loanToken.approve(address(vault), 1000000 ether);
        vault.deposit(5000 ether, owner);

        markets.supplyCollateral(marketParams, 1000 ether, owner, "");
        markets.borrow(marketParams, 700 ether, 0, owner, owner);

        uint256 timeToSkip = 1 days;

        uint256 balanceOfOwner = vault.balanceOf(owner);
        skip(timeToSkip);

        balanceOfOwner = vault.balanceOf(owner);

        uint256 premiumFeeRecipientBalanceBefore = loanToken.balanceOf(
            premiumFeeRecipient
        );
        uint256 feeRecipientBalanceBefore = loanToken.balanceOf(feeRecipient);

        markets.supply(marketParams, 10000 ether, 0, owner, "");
        vault.redeem(balanceOfOwner, owner, owner);

        uint256 premiumFee = loanToken.balanceOf(premiumFeeRecipient) -
            premiumFeeRecipientBalanceBefore;
        uint256 defaultFee = loanToken.balanceOf(feeRecipient) -
            feeRecipientBalanceBefore;

        assertEq(premiumFee, 0);
        assertEq(defaultFee, 0);
    }
}
