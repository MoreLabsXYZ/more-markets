// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Vm, StdCheats, Test, console} from "forge-std/Test.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id, MathLib, SharesMathLib} from "../../contracts/MoreMarkets.sol";
import {DebtTokenFactory} from "../../contracts/factories/DebtTokenFactory.sol";
import {DebtToken} from "../../contracts/tokens/DebtToken.sol";
import {ICreditAttestationService} from "../../contracts/interfaces/ICreditAttestationService.sol";
import {OracleMock} from "../../contracts/mocks/OracleMock.sol";
import {AdaptiveCurveIrm} from "../../contracts/AdaptiveCurveIrm.sol";
import {ERC20MintableMock} from "../../contracts/mocks/ERC20MintableMock.sol";
import {MoreVaults} from "../../contracts/MoreVaults.sol";
import {IMetaMorpho} from "../../contracts/interfaces/IMetaMorpho.sol";
import {MoreVaultsFactory, PremiumFeeInfo, OwnableUpgradeable} from "../../contracts/MoreVaultsFactory.sol";
import {MoreProxy} from "../../contracts/proxy/MoreProxy.sol";

contract MoreProxyTest is Test {
    event Upgraded(address indexed implementation);

    uint256 sepoliaFork;
    uint256 flowTestnetFork;

    MoreProxy proxy;

    MoreVaults moreVaultsImpl;
    MoreVaultsFactory factory;
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

    uint256 globalSnapshotId;

    address deployer = address(0xde410e4);

    function setUp() public {
        sepoliaFork = vm.createFork(
            "https://eth-sepolia.g.alchemy.com/v2/jXLoZTSjTIhZDB9nNhJsSmvrcMAbdrNT"
        );
        flowTestnetFork = vm.createFork("https://testnet.evm.nodes.onflow.org");
        vm.selectFork(flowTestnetFork);

        debtToken = new DebtToken();
        debtTokenFactory = new DebtTokenFactory(address(debtToken));

        markets = new MoreMarkets();

        asset = new ERC20MintableMock(deployer, "Asset", "ASSET");

        startHoax(owner);
    }

    function test_setUpMoreMarketsProxy_basicFunctinalityShouldWorkCorrectly()
        public
    {
        _setUpMoreMarketsProxy();

        assertEq(MoreMarkets(address(proxy)).irxMaxAvailable(), 2 ether);
        MoreMarkets(address(proxy)).setIrxMax(1.5 ether);
        assertEq(MoreMarkets(address(proxy)).irxMaxAvailable(), 1.5 ether);
    }

    function test_setUpMoreVaultsFactoryProxy_basicFunctinalityShouldWorkCorrectly()
        public
    {
        _setUpMoreVaultsFactoryProxy();

        assertEq(
            MoreVaultsFactory(address(proxy)).implementation(),
            address(moreVaultsImpl)
        );

        address initialOwner = deployer;
        uint256 initialTimelock = 0;
        string memory name = "MOCK VAULT 1";
        string memory symbol = "MOCK1";
        bytes32 salt = "1";

        address[] memory vaults = MoreVaultsFactory(address(proxy))
            .arrayOfVaults();
        assertEq(vaults.length, 0);

        IMetaMorpho vault = MoreVaultsFactory(address(proxy)).createMetaMorpho(
            initialOwner,
            initialTimelock,
            address(asset),
            name,
            symbol,
            salt
        );

        assertEq(vault.owner(), initialOwner);
        assertEq(vault.timelock(), initialTimelock);
        assertEq(vault.asset(), address(asset));
        assertEq(vault.name(), name);
        assertEq(vault.symbol(), symbol);
        assertEq(address(vault.VAULTS_FACTORY()), address(proxy));
    }

    function test_upgradeTo_shouldRevertIfCalledNotByTheOwner() public {
        _setUpMoreMarketsProxy();

        startHoax(credoraAdmin);
        vm.expectRevert("not owner");
        MoreMarkets(address(proxy)).upgradeTo(address(debtToken));
    }

    function test_upgradeTo_shouldChangeImlementationAddress() public {
        _setUpMoreMarketsProxy();

        factory = new MoreVaultsFactory();

        vm.expectEmit(address(proxy));
        emit Upgraded(address(factory));
        MoreMarkets(address(proxy)).upgradeTo(address(factory));

        vm.expectRevert();
        MoreMarkets(address(proxy)).irxMaxAvailable();

        assertFalse(
            MoreVaultsFactory(address(proxy)).isMetaMorpho(address(proxy))
        );
    }

    function _setUpMoreMarketsProxy() internal {
        proxy = new MoreProxy(address(markets));
        MoreMarkets(address(proxy)).initialize(
            owner,
            address(debtTokenFactory)
        );
        irm = new AdaptiveCurveIrm(address(proxy));

        MoreMarkets(address(proxy)).enableIrm(address(irm));
        MoreMarkets(address(proxy)).setMaxLltvForCategory(premiumLltvs[4]);

        for (uint256 i; i < lltvs.length; ) {
            MoreMarkets(address(proxy)).enableLltv(lltvs[i]);
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
        MoreMarkets(address(proxy)).createMarket(marketParams);

        loanToken.mint(address(owner), 1000000 ether);
        loanToken.approve(address(proxy), 1000000 ether);
        collateralToken.mint(address(owner), 1000000 ether);
        collateralToken.approve(address(proxy), 1000000 ether);

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
        MoreMarkets(address(proxy)).supply(
            marketParams,
            10000 ether,
            0,
            owner,
            ""
        );
    }

    function _setUpMoreVaultsFactoryProxy() internal {
        moreVaultsImpl = new MoreVaults();

        factory = new MoreVaultsFactory();

        proxy = new MoreProxy(address(factory));
        MoreVaultsFactory(address(proxy)).initialize(
            address(markets),
            address(moreVaultsImpl)
        );
    }
}
