// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {DebtToken} from "../../contracts/tokens/DebtToken.sol";

contract DebtTokenFactoryTest is Test {
    DebtToken debtToken;

    uint256 sepoliaFork;

    address deployer = address(0xde410e4);

    function setUp() public {
        sepoliaFork = vm.createFork(
            "https://eth-sepolia.g.alchemy.com/v2/jXLoZTSjTIhZDB9nNhJsSmvrcMAbdrNT"
        );
        vm.selectFork(sepoliaFork);

        startHoax(deployer);
        debtToken = new DebtToken();
    }

    function test_initialize(uint8 decimals) public {
        vm.assume(decimals < 70);
        string memory name = "Debt token";
        string memory symbol = "DBT";

        debtToken.initialize(name, symbol, decimals, deployer);

        assertEq(debtToken.name(), name);
        assertEq(debtToken.symbol(), symbol);
        assertEq(debtToken.owner(), deployer);
        assertEq(debtToken.decimals(), decimals);
    }

    function test_initialize_shouldRevertIfAlreadyInitialized() public {
        string memory name = "Debt token";
        string memory symbol = "DBT";
        uint8 decimals = 18;

        debtToken.initialize(name, symbol, decimals, deployer);

        vm.expectRevert("Initializable: contract is already initialized");
        debtToken.initialize(name, symbol, decimals, deployer);
    }

    function test_mint_shouldMintIfCalledByOwner() public {
        string memory name = "Debt token";
        string memory symbol = "DBT";
        uint8 decimals = 18;

        debtToken.initialize(name, symbol, decimals, deployer);

        assertEq(debtToken.totalSupply(), 0);
        assertEq(debtToken.balanceOf(deployer), 0);

        uint256 amountToMint = 1 ether;
        debtToken.mint(deployer, amountToMint);

        assertEq(debtToken.totalSupply(), amountToMint);
        assertEq(debtToken.balanceOf(deployer), amountToMint);
    }

    function test_mint_shouldRevertIfNotCalledByOwner() public {
        string memory name = "Debt token";
        string memory symbol = "DBT";
        uint8 decimals = 18;

        debtToken.initialize(name, symbol, decimals, deployer);

        assertEq(debtToken.totalSupply(), 0);
        assertEq(debtToken.balanceOf(deployer), 0);

        uint256 amountToMint = 1 ether;
        address maliciousUser = address(0x1010);

        startHoax(maliciousUser);
        vm.expectRevert("Ownable: caller is not the owner");
        debtToken.mint(maliciousUser, amountToMint);
    }
}
