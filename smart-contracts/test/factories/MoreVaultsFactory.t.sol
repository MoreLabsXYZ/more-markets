// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {IMoreMarkets} from "../../contracts/interfaces/IMoreMarkets.sol";
import {IMetaMorpho} from "../../contracts/interfaces/IMetaMorpho.sol";
import {IMetaMorphoFactory} from "../../contracts/interfaces/IMetaMorphoFactory.sol";
import {MoreMarkets} from "../../contracts/MoreMarkets.sol";
import {MoreVaultsFactory, PremiumFeeInfo, ErrorsLib, Ownable} from "../../contracts/MoreVaultsFactory.sol";
import {MoreVaults} from "../../contracts/MoreVaults.sol";
import {ERC20MintableMock} from "../../contracts/mocks/ERC20MintableMock.sol";

contract MoreVaultsFactoryTest is Test {
    MoreVaultsFactory factory;
    MoreVaults implementation;
    MoreMarkets markets;
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
        markets = new MoreMarkets(deployer, address(0));

        factory = new MoreVaultsFactory(
            address(markets),
            address(implementation)
        );

        asset = new ERC20MintableMock(deployer, "Asset", "ASSET");
    }

    function test_moreVaultsImpl_shouldReturnCorrectAddress() public view {
        address imp = factory.moreVaultsImpl();
        assertEq(imp, address(implementation));
    }

    function test_createMetaMorpho_shouldSetParametersCorrectly() public {
        address initialOwner = deployer;
        uint256 initialTimelock = 0;
        string memory name = "MOCK VAULT 1";
        string memory symbol = "MOCK1";
        bytes32 salt = "1";

        address[] memory vaults = factory.arrayOfVaults();
        assertEq(vaults.length, 0);

        IMetaMorpho vault = factory.createMetaMorpho(
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

        assertTrue(factory.isMetaMorpho(address(vault)));
        vaults = factory.arrayOfVaults();
        assertEq(vaults.length, 1);
        assertEq(vaults[0], address(vault));
    }

    function test_setFeeInfo_shouldSetPremiumFeeInfoCorrectly() public {
        address initialOwner = deployer;
        uint256 initialTimelock = 0;
        string memory name = "MOCK VAULT 1";
        string memory symbol = "MOCK1";
        bytes32 salt = "1";
        IMetaMorpho vault = factory.createMetaMorpho(
            initialOwner,
            initialTimelock,
            address(asset),
            name,
            symbol,
            salt
        );

        PremiumFeeInfo memory feeInfo = PremiumFeeInfo(deployer, maxFee);
        factory.setFeeInfo(address(vault), feeInfo);

        (address feeRecipient, uint96 fee) = factory.premiumFeeInfo(
            address(vault)
        );
        assertEq(feeRecipient, deployer);
        assertEq(fee, maxFee);
    }

    function test_setFeeInfo_shouldRevertIfProvidedVaultIsIncorrect() public {
        PremiumFeeInfo memory feeInfo = PremiumFeeInfo(address(0), maxFee);
        vm.expectRevert(ErrorsLib.NotTheVault.selector);
        factory.setFeeInfo(address(0), feeInfo);
    }

    function test_setFeeInfo_shouldRevertIfCalledNotByAnOwner() public {
        address initialOwner = deployer;
        uint256 initialTimelock = 0;
        string memory name = "MOCK VAULT 1";
        string memory symbol = "MOCK1";
        bytes32 salt = "1";
        IMetaMorpho vault = factory.createMetaMorpho(
            initialOwner,
            initialTimelock,
            address(asset),
            name,
            symbol,
            salt
        );

        startHoax(alice);
        PremiumFeeInfo memory feeInfo = PremiumFeeInfo(address(0), maxFee);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                alice
            )
        );
        factory.setFeeInfo(address(vault), feeInfo);
    }

    function test_setFeeInfo_shouldRevertIfFeeRecipientIsZeroAddress() public {
        address initialOwner = deployer;
        uint256 initialTimelock = 0;
        string memory name = "MOCK VAULT 1";
        string memory symbol = "MOCK1";
        bytes32 salt = "1";
        IMetaMorpho vault = factory.createMetaMorpho(
            initialOwner,
            initialTimelock,
            address(asset),
            name,
            symbol,
            salt
        );

        PremiumFeeInfo memory feeInfo = PremiumFeeInfo(address(0), maxFee);
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        factory.setFeeInfo(address(vault), feeInfo);
    }

    function test_setFeeInfo_shouldRevertIfFeeValueExceedsMax() public {
        address initialOwner = deployer;
        uint256 initialTimelock = 0;
        string memory name = "MOCK VAULT 1";
        string memory symbol = "MOCK1";
        bytes32 salt = "1";
        IMetaMorpho vault = factory.createMetaMorpho(
            initialOwner,
            initialTimelock,
            address(asset),
            name,
            symbol,
            salt
        );

        PremiumFeeInfo memory feeInfo = PremiumFeeInfo(deployer, maxFee + 1);
        vm.expectRevert(ErrorsLib.MaxFeeExceeded.selector);
        factory.setFeeInfo(address(vault), feeInfo);
    }
}
