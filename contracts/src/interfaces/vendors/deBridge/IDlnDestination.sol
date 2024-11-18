// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { DlnOrderLib } from "src/libraries/vendors/deBridge/DlnOrderLib.sol";

interface IDlnDestination {
    function externalCallAdapter() external view returns (address);

    /**
     * @dev Executes the order fulfillment process for the provided order.
     *
     * @notice This function executes the process of fulfilling an order within the DLN protocol.
     *         It conducts several validations like verifying if the order is on the correct chain,
     *         if the order IDs match, and if the status and amounts are correct. After the checks,
     *         the function proceeds to handle the transfer of the tokens from the `taker` (either native ETH or
     *         an ERC20 token) to the order's receiver.
     *         If a patch order was taken previously, the patch amount is deducted.
     *
     * @param _order The details of the order being fulfilled.
     * @param _fulFillAmount The amount the taker is fulfilling.
     * @param _orderId The unique identifier of the order.
     * @param _permitEnvelope The signed permit information for ERC20 token transfers.
     * @param _unlockAuthority The authority responsible for unlocking the order.
     *
     *
     * Emits a {FulfilledOrder} event.
     *
     * Requirements:
     * - The order's takeChainId must match the current chain's ID.
     * - The order's status must be `NotSet`.
     * - If the order has an allowed taker (allowedTakerDst), it must match the `_unlockAuthority`.
     * - The taker must provide the correct fulfillment amount.
     * - For ERC20 token transfers, a valid permit must be provided.
     */
    function fulfillOrder(
        DlnOrderLib.Order memory _order,
        uint256 _fulFillAmount,
        bytes32 _orderId,
        bytes calldata _permitEnvelope,
        address _unlockAuthority
    )
        external
        payable;

    /**
     * @dev Executes the order fulfillment process for the provided order.
     *
     * @notice This function executes the process of fulfilling an order and execute external call
     *         within the DLN protocol.
     *         It conducts several validations like verifying if the order is on the correct chain,
     *         if the order IDs match, and if the status and amounts are correct. After the checks,
     *         the function proceeds to handle the transfer of the tokens from the `taker` (either native ETH or
     *         an ERC20 token) to the order's receiver.
     *         If a patch order was taken previously, the patch amount is deducted.
     *         If the order includes an external call and an
     *         `_externalCallRewardBeneficiary` is provided, the external call is executed.
     *
     * @param _order The details of the order being fulfilled.
     * @param _fulFillAmount The amount the taker is fulfilling.
     * @param _orderId The unique identifier of the order.
     * @param _permitEnvelope The signed permit information for ERC20 token transfers.
     * @param _unlockAuthority The authority responsible for unlocking the order.
     * @param _externalCallRewardBeneficiary The beneficiary for rewards from the external call.
     *
     * Emits a {FulfilledOrder} event.
     *
     * Requirements:
     * - The order must be on the correct chain.
     * - The order's takeChainId must match the current chain's ID.
     * - The order's status must be `NotSet`.
     * - If the order has an allowed taker (allowedTakerDst), it must match the `_unlockAuthority`.
     * - The taker must provide the correct fulfillment amount.
     * - For ERC20 token transfers, a valid permit must be provided.
     */
    function fulfillOrder(
        DlnOrderLib.Order memory _order,
        uint256 _fulFillAmount,
        bytes32 _orderId,
        bytes calldata _permitEnvelope,
        address _unlockAuthority,
        address _externalCallRewardBeneficiary
    )
        external
        payable;
}
