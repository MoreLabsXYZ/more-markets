// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {IMoreMarkets} from "../../contracts/interfaces/IMoreMarkets.sol";
import {IMoreVaults} from "../../contracts/interfaces/IMoreVaults.sol";
import {IMoreVaultsFactory} from "../../contracts/interfaces/factories/IMoreVaultsFactory.sol";
import {MoreMarkets} from "../../contracts/MoreMarkets.sol";
import {MoreVaultsFactory, PremiumFeeInfo, ErrorsLib, OwnableUpgradeable} from "../../contracts/MoreVaultsFactory.sol";
import {MoreVaults} from "../../contracts/MoreVaults.sol";
import {ERC20MintableMock} from "../../contracts/mocks/ERC20MintableMock.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {MoreUupsProxy} from "../../contracts/proxy/MoreUupsProxy.sol";

contract MoreVaultsFactoryTest is Test {
    MoreVaultsFactory factoryImpl;
    MoreVaultsFactory factory;
    MoreVaults implementation;
    MoreUupsProxy proxy;

    TransparentUpgradeableProxy public transparentProxy;
    ProxyAdmin public proxyAdmin;
    MoreMarkets public marketsImpl;
    MoreMarkets public markets;

    ERC20MintableMock asset;

    uint256 sepoliaFork;
    uint256 flowTestnetFork;

    address alice = address(0x1234);
    address deployer = address(0xde410e4);

    uint96 maxFee = 1e18;

    function setUp() public {
        sepoliaFork = vm.createFork(
            "https://eth-sepolia.g.alchemy.com/v2/jXLoZTSjTIhZDB9nNhJsSmvrcMAbdrNT"
        );
        flowTestnetFork = vm.createFork("https://testnet.evm.nodes.onflow.org");
        vm.selectFork(flowTestnetFork);

        startHoax(deployer);

        implementation = new MoreVaults();

        proxyAdmin = new ProxyAdmin(deployer);
        marketsImpl = new MoreMarkets();
        transparentProxy = new TransparentUpgradeableProxy(
            address(marketsImpl),
            address(proxyAdmin),
            ""
        );
        markets = MoreMarkets(address(transparentProxy));
        markets.initialize(deployer);

        factoryImpl = new MoreVaultsFactory();
        proxy = new MoreUupsProxy(address(factoryImpl));
        factory = MoreVaultsFactory(address(proxy));
        factory.initialize(address(markets), address(implementation));

        asset = new ERC20MintableMock(deployer, "Asset", "ASSET");
    }

    function test_moreVaultsImpl_shouldReturnCorrectAddress() public view {
        address imp = factory.moreVaultsImpl();
        assertEq(imp, address(implementation));
    }

    function test_createMoreVault_shouldSetParametersCorrectly() public {
        address initialOwner = deployer;
        uint256 initialTimelock = 1 days;
        string memory name = "MOCK VAULT 1";
        string memory symbol = "MOCK1";
        bytes32 salt = "1";

        address[] memory vaults = factory.arrayOfVaults();
        assertEq(vaults.length, 0);

        IMoreVaults vault = factory.createMoreVault(
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
        assertEq(address(vault.VAULTS_FACTORY()), address(factory));

        assertTrue(factory.isMoreVault(address(vault)));
        vaults = factory.arrayOfVaults();
        assertEq(vaults.length, 1);
        assertEq(vaults[0], address(vault));
    }

    function test_setPremiumFeeInfo_shouldSetPremiumFeeInfoCorrectly() public {
        address initialOwner = deployer;
        uint256 initialTimelock = 1 days;
        string memory name = "MOCK VAULT 1";
        string memory symbol = "MOCK1";
        bytes32 salt = "1";
        IMoreVaults vault = factory.createMoreVault(
            initialOwner,
            initialTimelock,
            address(asset),
            name,
            symbol,
            salt
        );

        PremiumFeeInfo memory feeInfo = PremiumFeeInfo(deployer, maxFee);
        factory.setPremiumFeeInfo(address(vault), feeInfo);

        (address feeRecipient, uint96 fee) = factory.premiumFeeInfo(
            address(vault)
        );
        assertEq(feeRecipient, deployer);
        assertEq(fee, maxFee);
    }

    function test_setPremiumFeeInfo_shouldRevertIfProvidedVaultIsIncorrect()
        public
    {
        PremiumFeeInfo memory feeInfo = PremiumFeeInfo(address(0), maxFee);
        vm.expectRevert(ErrorsLib.NotTheVault.selector);
        factory.setPremiumFeeInfo(address(0), feeInfo);
    }

    function test_setPremiumFeeInfo_shouldRevertIfCalledNotByAnOwner() public {
        address initialOwner = deployer;
        uint256 initialTimelock = 1 days;
        string memory name = "MOCK VAULT 1";
        string memory symbol = "MOCK1";
        bytes32 salt = "1";
        IMoreVaults vault = factory.createMoreVault(
            initialOwner,
            initialTimelock,
            address(asset),
            name,
            symbol,
            salt
        );

        startHoax(alice);
        PremiumFeeInfo memory feeInfo = PremiumFeeInfo(address(0), maxFee);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.setPremiumFeeInfo(address(vault), feeInfo);
    }

    function test_setPremiumFeeInfo_shouldRevertIfFeeRecipientIsZeroAddress()
        public
    {
        address initialOwner = deployer;
        uint256 initialTimelock = 1 days;
        string memory name = "MOCK VAULT 1";
        string memory symbol = "MOCK1";
        bytes32 salt = "1";
        IMoreVaults vault = factory.createMoreVault(
            initialOwner,
            initialTimelock,
            address(asset),
            name,
            symbol,
            salt
        );

        PremiumFeeInfo memory feeInfo = PremiumFeeInfo(address(0), maxFee);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        factory.setPremiumFeeInfo(address(vault), feeInfo);
    }

    function test_setPremiumFeeInfo_shouldRevertIfFeeValueExceedsMax() public {
        address initialOwner = deployer;
        uint256 initialTimelock = 1 days;
        string memory name = "MOCK VAULT 1";
        string memory symbol = "MOCK1";
        bytes32 salt = "1";
        IMoreVaults vault = factory.createMoreVault(
            initialOwner,
            initialTimelock,
            address(asset),
            name,
            symbol,
            salt
        );

        PremiumFeeInfo memory feeInfo = PremiumFeeInfo(deployer, maxFee + 1);
        vm.expectRevert(ErrorsLib.MaxFeeExceeded.selector);
        factory.setPremiumFeeInfo(address(vault), feeInfo);
    }
}
