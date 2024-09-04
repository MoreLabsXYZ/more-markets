// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

interface ICredoraMetrics {
    /**
     * @notice Set the DON ID
     * @param newDonId The new DON ID to be set
     */
    function setDonId(bytes32 newDonId) external;

    /**
     * @notice Set the fee required for granting permission
     * @param _requiredPayment The new fee amount for granting permission
     */
    function setFeePermissionGrant(uint256 _requiredPayment) external;

    /**
     * @notice Set the fee required for data refresh
     * @param _requiredPayment The new fee amount for data refresh
     */
    function setFeeDataRefresh(uint256 _requiredPayment) external;

    /**
     * @notice Send a data request to the Functions DON
     * @param source The source code of the function
     * @param secretsLocation The location of the secrets
     * @param encryptedSecretsReference Reference to the encrypted secrets
     * @param args Arguments for the function
     * @param paymentDirections Addresses for payment directions
     * @param subscriptionId The ID of the subscription
     * @param callbackGasLimit The gas limit for the callback
     */
    function sendRequest(
        string calldata source,
        FunctionsRequest.Location secretsLocation,
        bytes calldata encryptedSecretsReference,
        string[] calldata args,
        address[] calldata paymentDirections,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) external;

    /**
     * @notice Direct set data in the smart contract with no oracle
     * @param requestId The ID of the request
     * @param response The content of the data
     * @param err Any errors encountered
     */
    function setData(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) external;

    /**
     * @notice Access entity data for testing purposes
     * @param entity The entity ID
     * @return The entity data
     */
    function testAccessData(address entity) external returns (bytes memory);

    /**
     * @notice Get the score of an entity
     * @param entity The entity ID
     * @return The score of the entity
     */
    function getScore(address entity) external view returns (uint256);

    /**
     * @notice Get the NAV of an entity
     * @param entity The entity ID
     * @return The NAV of the entity
     */
    function getNAV(address entity) external view returns (uint64);

    /**
     * @notice Get the RAE of an entity
     * @param entity The entity ID
     * @return The RAE of the entity
     */
    function getRAE(address entity) external view returns (bytes8);

    /**
     * @notice Get the borrow capacity of an entity
     * @param entity The entity ID
     * @return The borrow capacity of the entity
     */
    function getBorrowCapacity(address entity) external view returns (uint64);

    /**
     * @notice Get the implied PD of an entity
     * @param entity The entity ID
     * @return The implied PD of the entity
     */
    function getImpliedPD(address entity) external view returns (uint64);

    /**
     * @notice Get the implied PD tenor of an entity
     * @param entity The entity ID
     * @return The implied PD tenor of the entity
     */
    function getImpliedPDTenor(address entity) external view returns (uint64);

    /**
     * @notice Grant permission to a third party to access entity data
     * @param entity The entity ID
     * @param thirdParty The address of the third party
     * @param duration The duration of the permission
     * @param tokenAddress The address of the token used for payment
     * @param tokenSender The address sending the payment
     */
    function grantPermission(
        address entity,
        address thirdParty,
        uint128 duration,
        address tokenAddress,
        address tokenSender
    ) external;

    /**
     * @notice Grant permission to a third party to access entity data
     * @param entity The entity ID
     * @param thirdParty The address of the third party
     * @param duration The duration of the permission
     */
    function grantPermission(
        address entity,
        address thirdParty,
        uint128 duration
    ) external;

    /**
     * @notice Subscribe to updates for an entity
     * @param entity The entity ID
     * @param subscribedContract The address of the subscribing contract
     * @param duration The duration of the subscription
     * @param tokenAddress The address of the token used for payment
     */
    function subscribe(
        address entity,
        address subscribedContract,
        uint128 duration,
        address tokenAddress,
        address tokenSender
    ) external;

    /**
     * @notice Subscribe to updates for an entity
     * @param entity The entity ID
     * @param subscribedContract The address of the subscribing contract
     * @param duration The duration of the subscription
     */
    function subscribe(
        address entity,
        address subscribedContract,
        uint128 duration
    ) external;

    /**
     * @notice Unsubscribe from updates for an entity
     * @param entity The entity ID
     * @param subscribedContract The address of the subscribing contract
     */
    function unsubscribe(address entity, address subscribedContract) external;
}
