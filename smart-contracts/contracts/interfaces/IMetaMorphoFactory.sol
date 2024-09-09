// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IMetaMorpho} from "./IMetaMorpho.sol";

struct PremiumFeeInfo {
    address feeRecipient;
    uint96 fee;
}

/// @title IMetaMorphoFactory
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Interface of MetaMorpho's factory.
interface IMetaMorphoFactory {
    /// @notice The address of the Morpho contract.
    function MORE_MARKETS() external view returns (address);

    /// @notice Whether a MetaMorpho vault was created with the factory.
    function isMetaMorpho(address target) external view returns (bool);

    /// @notice Returns implementation address of MoreVaults contract, to create minimal proxy of it.
    function moreVaultsImpl() external view returns (address);

    /// @notice Creates a new MetaMorpho vault.
    /// @param initialOwner The owner of the vault.
    /// @param initialTimelock The initial timelock of the vault.
    /// @param asset The address of the underlying asset.
    /// @param name The name of the vault.
    /// @param symbol The symbol of the vault.
    /// @param salt The salt to use for the MetaMorpho vault's CREATE2 address.
    function createMetaMorpho(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (IMetaMorpho metaMorpho);

    /// @notice Returns array of all vaults created with the factory.
    function arrayOfVaults() external view returns (address[] memory);

    /// @notice Returns the fee info of the vault includes feeRecipient and premium fee percentage.
    /// Premium fee percentage is applied to preformance fee of particular vault.
    /// @param vault The address of the vault.
    function premiumFeeInfo(
        address vault
    ) external view returns (address feeRecipient, uint96 premiumFee);

    /// @notice Sets the premium fee info for the particular vault.
    /// Premium fee percentage is applied to preformance fee of particular vault.
    /// @param vault The address of the vault.
    /// @param _premiumFeeInfo The premium fee info.
    function setFeeInfo(
        address vault,
        PremiumFeeInfo memory _premiumFeeInfo
    ) external;
}
