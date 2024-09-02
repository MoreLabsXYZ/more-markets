// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.21;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract DebtToken is ERC20Upgradeable, OwnableUpgradeable {
    uint8 private _decimals;

    function initialize(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        address deployer
    ) external initializer {
        __ERC20_init(name, symbol);
        __Ownable_init();
        _transferOwnership(deployer);
        _decimals = decimals_;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
