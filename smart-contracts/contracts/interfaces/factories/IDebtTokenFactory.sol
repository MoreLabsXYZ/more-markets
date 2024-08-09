// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/// @title Interface for DebtTokenFactory.
interface IDebtTokenFactory is IERC165 {
    error InvalidImplementationAddress();

    /**
     * @notice This event emitted when new instance of debt token has deployed.
     * @param deployer address of delpoyer.
     * @param instance address of instance that has been deployed.
     */
    event DebtTokenCreated(address deployer, address instance);
    /**
     * @notice This event emitted when debt token implementation address
     * has changed.
     * @param oldImplementation old implementation address.
     * @param newImplementation new implementation address.
     */
    event ImplementationAddressChanged(
        address oldImplementation,
        address newImplementation
    );

    /**
     * @notice Function that returns addresses of debt token implementations.
     * @return address of debt token implementation.
     */
    function getImplementation() external view returns (address);

    /**
     * @notice Function that changes address of debt token implementations,
     * that is used to deploy new minimal proxies.
     * Can be called only be DEPLOYER_ROLE.
     * @param implementation address of new debt token implementation.
     */
    function setImplementationAddress(address implementation) external;

    /**
     * @notice Function that creates a new instance of the debt token
     * contract using the Clones library. It initializes the new instance with
     * the provided parameters.
     * @param _symbol symbol of debt token token.
     * @param _name name of debt token token.
     * @param _owner address of owner for the new debt token contract.
     */
    function create(
        string memory _symbol,
        string memory _name,
        address _owner
    ) external returns (address instance);
}
