// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Vm, StdCheats, Test, console} from "forge-std/Test.sol";
import {MoreMarkets, MarketParams, Market, MarketParamsLib, Id, MathLib, SharesMathLib, ErrorsLib} from "../../contracts/MoreMarkets.sol";
import {ICreditAttestationService} from "../../contracts/interfaces/ICreditAttestationService.sol";
import {OracleMock} from "../../contracts/mocks/OracleMock.sol";
import {AdaptiveCurveIrm} from "../../contracts/AdaptiveCurveIrm.sol";
import {ERC20MintableMock} from "../../contracts/mocks/ERC20MintableMock.sol";
import {MoreVaults} from "../../contracts/MoreVaults.sol";
import {IMoreVaults} from "../../contracts/interfaces/IMoreVaults.sol";
import {MoreVaultsFactory, PremiumFeeInfo, OwnableUpgradeable} from "../../contracts/MoreVaultsFactory.sol";
import {MoreUupsProxy} from "../../contracts/proxy/MoreUupsProxy.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract MoreUupsProxyTest is Test {
    event Upgraded(address indexed implementation);

    uint256 sepoliaFork;
    uint256 flowTestnetFork;

    MoreUupsProxy moreUupsProxy;
    TransparentUpgradeableProxy transparentProxy;
    ProxyAdmin proxyAdmin;

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

    MoreMarkets public marketsImpl;
    MoreMarkets public markets;
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

        proxyAdmin = new ProxyAdmin(deployer);
        marketsImpl = new MoreMarkets();
        transparentProxy = new TransparentUpgradeableProxy(
            address(marketsImpl),
            address(proxyAdmin),
            ""
        );
        markets = MoreMarkets(address(transparentProxy));

        asset = new ERC20MintableMock(deployer, "Asset", "ASSET");

        startHoax(owner);
    }

    function test_setUpMoreVaultsFactoryProxy_basicFunctinalityShouldWorkCorrectly()
        public
    {
        _setUpMoreVaultsFactoryProxy();

        assertEq(
            MoreVaultsFactory(address(moreUupsProxy)).implementation(),
            address(moreVaultsImpl)
        );

        address initialOwner = deployer;
        uint256 initialTimelock = 0;
        string memory name = "MOCK VAULT 1";
        string memory symbol = "MOCK1";
        bytes32 salt = "1";

        address[] memory vaults = MoreVaultsFactory(address(moreUupsProxy))
            .arrayOfVaults();
        assertEq(vaults.length, 0);

        IMoreVaults vault = MoreVaultsFactory(address(moreUupsProxy))
            .createMoreVault(
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
        assertEq(address(vault.VAULTS_FACTORY()), address(moreUupsProxy));
    }

    function test_upgradeTo_shouldRevertIfCalledNotByTheOwner() public {
        _setUpMoreVaultsFactoryProxy();

        startHoax(credoraAdmin);
        vm.expectRevert("Ownable: caller is not the owner");
        MoreVaultsFactory(address(moreUupsProxy)).upgradeTo(address(credora));
    }

    function test_upgradeTo_shouldChangeImlementationAddress() public {
        _setUpMoreVaultsFactoryProxy();

        factory = new MoreVaultsFactory();

        vm.expectEmit(address(moreUupsProxy));
        emit Upgraded(address(factory));
        MoreVaultsFactory(address(moreUupsProxy)).upgradeTo(address(factory));
    }

    function _setUpMoreVaultsFactoryProxy() internal {
        moreVaultsImpl = new MoreVaults();

        factory = new MoreVaultsFactory();

        moreUupsProxy = new MoreUupsProxy(address(factory));
        MoreVaultsFactory(address(moreUupsProxy)).initialize(
            address(markets),
            address(moreVaultsImpl)
        );
    }
}
