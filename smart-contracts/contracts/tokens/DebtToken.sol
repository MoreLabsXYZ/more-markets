// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract DebtToken is ERC20Upgradeable, OwnableUpgradeable {
    function initialize(
        string memory symbol,
        string memory name,
        address deployer
    ) external initializer {
        __ERC20_init(name, symbol);
        __Ownable_init();
        _transferOwnership(deployer);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
