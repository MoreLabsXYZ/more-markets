// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {IERC20MetadataUpgradeable, IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

/**
 * @notice Interface for debt token
 */
interface IDebtToken is IERC20MetadataUpgradeable {
    function initialize(
        string memory symbol,
        string memory name,
        address deployer
    ) external;

    function mint(address to, uint256 amount) external;
}
