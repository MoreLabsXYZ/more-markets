// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IMoreVaults} from "../IMoreVaults.sol";

struct PremiumFeeInfo {
    address feeRecipient;
    uint96 fee;
}

/// @title IMoreVaultsFactory
/// @author MoreMarkets
/// @notice Interface of MoreVaults's factory.
interface IMoreVaultsFactory {
    /// @notice The address of the MoreMarkets contract.
    function MORE_MARKETS() external view returns (address);

    /// @notice Whether a MoreVault vault was created with the factory.
    function isMoreVault(address target) external view returns (bool);

    /// @notice Returns implementation address of MoreVaults contract, to create minimal proxy of it.
    function moreVaultsImpl() external view returns (address);

    /// @dev Initializes the contract.
    /// @param moreMarkets The address of the More Markets contract.
    /// @param _moreVaultsImpl The address of the MoreVaults implementation contract.
    function initialize(address moreMarkets, address _moreVaultsImpl) external;

    /// @notice Creates a new MoreVault vault.
    /// @param initialOwner The owner of the vault.
    /// @param initialTimelock The initial timelock of the vault.
    /// @param asset The address of the underlying asset.
    /// @param name The name of the vault.
    /// @param symbol The symbol of the vault.
    /// @param salt The salt to use for the MoreVault vault's CREATE2 address.
    function createMoreVault(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (IMoreVaults moreVault);

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
    /// Can be called only by the owner.
    /// @param vault The address of the vault.
    /// @param _premiumFeeInfo The premium fee info.
    function setPremiumFeeInfo(
        address vault,
        PremiumFeeInfo memory _premiumFeeInfo
    ) external;

    /// @notice Function that sets vault implementation address.
    /// Can be called only by the owner.
    /// @param newImplementation new implementation address.
    function upgradeVaultImplemtationTo(address newImplementation) external;
}
