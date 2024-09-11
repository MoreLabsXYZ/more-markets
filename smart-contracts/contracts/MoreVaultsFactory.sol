// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IMetaMorpho} from "./interfaces/IMetaMorpho.sol";
import {IMetaMorphoFactory, PremiumFeeInfo} from "./interfaces/IMetaMorphoFactory.sol";

import {EventsLib} from "./libraries/vaults/EventsLib.sol";
import {ErrorsLib} from "./libraries/vaults/ErrorsLib.sol";

// import {MoreVaults} from "./MoreVaults.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {Ownable2StepUpgradeable, OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title MoreVaultsFactory
/// @author MoreMarkets
/// @notice This contract allows to create More vaults, and to index them easily. Fork of Morpho's MetaMorphoFactory.
contract MoreVaultsFactory is
    UUPSUpgradeable,
    IMetaMorphoFactory,
    Ownable2StepUpgradeable,
    IBeacon
{
    // using ClonesUpgradeable for address;

    /* IMMUTABLES */

    /// @inheritdoc IMetaMorphoFactory
    address public MORE_MARKETS;

    /// @inheritdoc IMetaMorphoFactory
    address public moreVaultsImpl;

    /* STORAGE */

    /// @inheritdoc IMetaMorphoFactory
    mapping(address => bool) public isMetaMorpho;

    /// @inheritdoc IMetaMorphoFactory
    mapping(address => PremiumFeeInfo) public premiumFeeInfo;

    /// @notice array of all vaults created with the factory.
    address[] private _metaMorphos;
    /// @notice Maximum fee percent that can be set for the particular vault.
    uint96 private _maxFee = 1e18;

    /* INITIALIZER */

    /// @inheritdoc IMetaMorphoFactory
    function initialize(
        address moreMarkets,
        address _moreVaultsImpl
    ) external initializer {
        if (moreMarkets == address(0)) revert ErrorsLib.ZeroAddress();
        if (_moreVaultsImpl == address(0)) revert ErrorsLib.ZeroAddress();
        __Ownable_init();
        __UUPSUpgradeable_init();

        moreVaultsImpl = _moreVaultsImpl;
        MORE_MARKETS = moreMarkets;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

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
            address(new BeaconProxy{salt: salt}(address(this), ""))
        );
        // metaMorpho = IMetaMorpho(moreVaultsImpl.cloneDeterministic(salt));
        metaMorpho.initialize(
            initialOwner,
            MORE_MARKETS,
            address(this),
            initialTimelock,
            asset,
            name,
            symbol
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

    /// @inheritdoc IBeacon
    function implementation() external view returns (address) {
        return moreVaultsImpl;
    }

    /// @inheritdoc IMetaMorphoFactory
    function arrayOfVaults() external view returns (address[] memory) {
        address[] memory morphoArray = _metaMorphos;
        return morphoArray;
    }

    /// @inheritdoc IMetaMorphoFactory
    function setFeeInfo(
        address vault,
        PremiumFeeInfo memory _feeInfo
    ) external onlyOwner {
        if (!isMetaMorpho[vault]) revert ErrorsLib.NotTheVault();
        if (_feeInfo.feeRecipient == address(0)) revert ErrorsLib.ZeroAddress();
        if (_feeInfo.fee > _maxFee) revert ErrorsLib.MaxFeeExceeded();

        premiumFeeInfo[vault] = _feeInfo;

        emit EventsLib.SetPremiumFeeInfo(vault, _feeInfo);
    }
}
