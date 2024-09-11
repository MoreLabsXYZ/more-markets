// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {ERC1967Utils, StorageSlot} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

/// @title MoreProxy
/// @author MoreMarkets
/// @notice This contract can be used as a proxy for MoreMarkets and MoreVaultsFactory, since they are upgradeable for now.
contract MoreProxy is Proxy {
    /// @dev Initializes the proxy.
    /// @notice The address of the implementation.
    constructor(address implementation) {
        ERC1967Utils.upgradeToAndCall(implementation, "");
    }

    /// @inheritdoc Proxy
    function _implementation() internal view override returns (address) {
        return ERC1967Utils.getImplementation();
    }
}
