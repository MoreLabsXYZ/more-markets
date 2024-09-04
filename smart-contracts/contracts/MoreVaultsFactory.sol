// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IMetaMorpho} from "./interfaces/IMetaMorpho.sol";
import {IMetaMorphoFactory} from "./interfaces/IMetaMorphoFactory.sol";

import {EventsLib} from "./libraries/vaults/EventsLib.sol";
import {ErrorsLib} from "./libraries/vaults/ErrorsLib.sol";

import {MoreVaults} from "./MoreVaults.sol";

/// @title MoreVaultsFactory
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice This contract allows to create More vaults, and to index them easily. Fork of Morpho's MetaMorphoFactory.
contract MoreVaultsFactory is IMetaMorphoFactory {
    /* IMMUTABLES */

    /// @inheritdoc IMetaMorphoFactory
    address public immutable MORPHO;

    /* STORAGE */

    /// @inheritdoc IMetaMorphoFactory
    mapping(address => bool) public isMetaMorpho;

    address[] private _metaMorphos;

    /* CONSTRUCTOR */

    /// @dev Initializes the contract.
    /// @param morpho The address of the Morpho contract.
    constructor(address morpho) {
        if (morpho == address(0)) revert ErrorsLib.ZeroAddress();

        MORPHO = morpho;
    }

    /* EXTERNAL */

    /// @inheritdoc IMetaMorphoFactory
    function createMetaMorpho(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (IMetaMorpho metaMorpho) {
        metaMorpho = IMetaMorpho(
            address(
                new MoreVaults{salt: salt}(
                    initialOwner,
                    MORPHO,
                    initialTimelock,
                    asset,
                    name,
                    symbol
                )
            )
        );

        isMetaMorpho[address(metaMorpho)] = true;
        _metaMorphos.push(address(metaMorpho));

        emit EventsLib.CreateMetaMorpho(
            address(metaMorpho),
            msg.sender,
            initialOwner,
            initialTimelock,
            asset,
            name,
            symbol,
            salt
        );
    }

    function arrayOfMorphos() external view returns (address[] memory) {
        address[] memory morphoArray = _metaMorphos;
        return morphoArray;
    }
}
