// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IMoreVaults} from "./interfaces/IMoreVaults.sol";
import {IMoreVaultsFactory, PremiumFeeInfo} from "./interfaces/factories/IMoreVaultsFactory.sol";

import {EventsLib} from "./libraries/vaults/EventsLib.sol";
import {ErrorsLib} from "./libraries/vaults/ErrorsLib.sol";

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {Ownable2StepUpgradeable, OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title MoreVaultsFactory
/// @author MORE Labs
/// @notice This contract allows to create More vaults, and to index them easily. Also manages premium fees of the vaults. Fork of Morpho's MetaMorphoFactory.
contract MoreVaultsFactory is
    UUPSUpgradeable,
    IMoreVaultsFactory,
    Ownable2StepUpgradeable,
    IBeacon
{
    /* IMMUTABLES */

    /// @inheritdoc IMoreVaultsFactory
    address public MORE_MARKETS;

    /// @inheritdoc IMoreVaultsFactory
    address public moreVaultsImpl;

    /* STORAGE */

    /// @inheritdoc IMoreVaultsFactory
    mapping(address => bool) public isMoreVault;

    /// @inheritdoc IMoreVaultsFactory
    mapping(address => PremiumFeeInfo) public premiumFeeInfo;

    /// @notice array of all vaults created with the factory.
    address[] private _metaMorphos;
    /// @notice Maximum fee percent that can be set for the particular vault.
    uint96 private constant _maxFee = 1e18;

    /* CONSTRUCTOR */

    constructor() {
        _disableInitializers();
    }

    /* INITIALIZER */

    /// @inheritdoc IMoreVaultsFactory
    function initialize(
        address moreMarkets,
        address _moreVaultsImpl
    ) external initializer {
        if (moreMarkets == address(0)) revert ErrorsLib.ZeroAddress();
        if (_moreVaultsImpl == address(0)) revert ErrorsLib.ZeroAddress();
        __Ownable_init();
        __UUPSUpgradeable_init();

        _setVaultImplementation(_moreVaultsImpl);
        MORE_MARKETS = moreMarkets;
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /* EXTERNAL */

    /// @inheritdoc IMoreVaultsFactory
    function createMoreVault(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (IMoreVaults metaMorpho) {
        metaMorpho = IMoreVaults(
            address(new BeaconProxy{salt: salt}(address(this), ""))
        );
        metaMorpho.initialize(
            initialOwner,
            MORE_MARKETS,
            address(this),
            initialTimelock,
            asset,
            name,
            symbol
        );

        isMoreVault[address(metaMorpho)] = true;
        _metaMorphos.push(address(metaMorpho));

        emit EventsLib.createMoreVault(
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

    /// @inheritdoc IBeacon
    function implementation() external view returns (address) {
        return moreVaultsImpl;
    }

    /// @inheritdoc IMoreVaultsFactory
    function arrayOfVaults() external view returns (address[] memory) {
        address[] memory morphoArray = _metaMorphos;
        return morphoArray;
    }

    /// @inheritdoc IMoreVaultsFactory
    function setPremiumFeeInfo(
        address vault,
        PremiumFeeInfo memory _feeInfo
    ) external onlyOwner {
        if (!isMoreVault[vault]) revert ErrorsLib.NotTheVault();
        if (_feeInfo.feeRecipient == address(0)) revert ErrorsLib.ZeroAddress();
        if (_feeInfo.fee > _maxFee) revert ErrorsLib.MaxFeeExceeded();

        premiumFeeInfo[vault] = _feeInfo;

        emit EventsLib.SetPremiumFeeInfo(vault, _feeInfo);
    }

    /// @inheritdoc IMoreVaultsFactory
    function upgradeVaultImplemtationTo(
        address newImplementation
    ) public onlyOwner {
        _setVaultImplementation(newImplementation);
    }

    /// @dev Function that sets vault implementation address.
    /// @param newImplementation new implementation address.
    function _setVaultImplementation(address newImplementation) private {
        if (newImplementation.code.length == 0) {
            revert ErrorsLib.BeaconInvalidImplementation(newImplementation);
        }
        moreVaultsImpl = newImplementation;
        emit EventsLib.VaultImplementationUpgraded(newImplementation);
    }
}
