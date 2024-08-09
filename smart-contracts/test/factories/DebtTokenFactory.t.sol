// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IDebtTokenFactory, DebtTokenFactory} from "../../contracts/factories/DebtTokenFactory.sol";
import {DebtToken} from "../../contracts/tokens/DebtToken.sol";

contract DebtTokenFactoryTest is Test {
    DebtTokenFactory factory;
    DebtToken implementation;

    uint256 sepoliaFork;

    address manager = address(0x1234);
    address deployer = address(0xde410e4);

    function setUp() public {
        sepoliaFork = vm.createFork(
            "https://eth-sepolia.g.alchemy.com/v2/jXLoZTSjTIhZDB9nNhJsSmvrcMAbdrNT"
        );
        vm.selectFork(sepoliaFork);

        startHoax(deployer);
        implementation = new DebtToken();

        factory = new DebtTokenFactory(address(implementation));
    }

    function test_getImplementation() public view {
        address imp = factory.getImplementation();
        assertEq(imp, address(implementation));
        assertTrue(factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), deployer));
    }

    function test_create_andThenMint() public {
        string memory name = "Debt token";
        string memory symbol = "DBT";
        DebtToken newDebtToken = DebtToken(
            factory.create(name, symbol, deployer)
        );
        assertEq(newDebtToken.name(), name);
        assertEq(newDebtToken.symbol(), symbol);

        assertEq(newDebtToken.owner(), deployer);

        newDebtToken.mint(deployer, 100 ether);
        assertEq(newDebtToken.balanceOf(deployer), 100 ether);
    }

    function test_deploy_cantDeployIfImplAddressNotAContract() public {
        vm.expectRevert(
            IDebtTokenFactory.InvalidImplementationAddress.selector
        );
        factory = new DebtTokenFactory(deployer);
    }
}
