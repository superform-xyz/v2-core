// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IDlnSource } from "../../../vendor/bridges/debridge/IDlnSource.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperSignatureStorage } from "../../../interfaces/ISuperSignatureStorage.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title DeBridgeSendOrderAndExecuteOnDstHook
/// @author Superform Labs
/// @dev `externalCall` field won't contain the signature for the destination executor
/// @dev      signature is retrieved from the validator contract transient storage
/// @dev      This is needed to avoid circular dependency between merkle root which contains the signature needed to
/// sign it
/// @dev data has the following structure
/// @notice         bool usePrevHookAmount = _decodeBool(0);
/// @notice         uint256 value = BytesLib.toUint256(data, 1);
/// @notice         address giveTokenAddress = BytesLib.toAddress(data, 33);
/// @notice         uint256 giveAmount = BytesLib.toUint256(data, 53);
/// @notice         uint8 version = BytesLib.toUint8(data, 85);
/// @notice         address fallbackAddress = BytesLib.toAddress(data, 86);
/// @notice         address executorAddress = BytesLib.toAddress(data, 106);
/// @notice         uint256 executionFee = BytesLib.toUint256(data, 126);
/// @notice         bool allowDelayedExecution = _decodeBool(data, 158);
/// @notice         bool requireSuccessfullExecution = _decodeBool(data, 159);
/// @notice         uint256 destinationMessage_paramLength = BytesLib.toUint256(data, 160);
/// @notice         bytes destinationMessage = BytesLib.slice(data, 192, destinationMessage_paramLength);
/// @notice         uint256 takeTokenAddress_paramLength = BytesLib.toUint256(data, 192 +
/// destinationMessage_paramLength);
/// @notice         bytes takeTokenAddress = BytesLib.slice(data, 224 + destinationMessage_paramLength,
/// takeTokenAddress_paramLength);
/// @notice         uint256 takeAmount = BytesLib.toUint256(data, 224 + destinationMessage_paramLength +
/// takeTokenAddress_paramLength);
/// @notice         uint256 takeChainId = BytesLib.toUint256(data, 256 + destinationMessage_paramLength +
/// takeTokenAddress_paramLength);
/// @notice         uint256 receiverDst_paramLength = BytesLib.toUint256(data, 288 + destinationMessage_paramLength +
/// takeTokenAddress_paramLength);
/// @notice         bytes receiverDst = BytesLib.slice(data, 320 + destinationMessage_paramLength +
/// takeTokenAddress_paramLength, receiverDst_paramLength);
/// @notice         address givePatchAuthoritySrc = BytesLib.toAddress(data, 320 + destinationMessage_paramLength +
/// takeTokenAddress_paramLength + receiverDst_paramLength);
/// @notice         uint256 orderAuthorityAddressDst_paramLength = BytesLib.toUint256(data, 340 +
/// destinationMessage_paramLength + takeTokenAddress_paramLength + receiverDst_paramLength);
/// @notice         bytes orderAuthorityAddressDst = BytesLib.slice(data, 372 + destinationMessage_paramLength +
/// takeTokenAddress_paramLength + receiverDst_paramLength, orderAuthorityAddressDst_paramLength);
/// @notice         uint256 allowedTakerDst_paramLength = BytesLib.toUint256(data, 372 + destinationMessage_paramLength
/// + takeTokenAddress_paramLength + receiverDst_paramLength + orderAuthorityAddressDst_paramLength);
/// @notice         bytes allowedTakerDst = BytesLib.slice(data, 404 + destinationMessage_paramLength +
/// takeTokenAddress_paramLength + receiverDst_paramLength + orderAuthorityAddressDst_paramLength,
/// allowedTakerDst_paramLength);
/// @notice         uint256 allowedCancelBeneficiarySrc_paramLength = BytesLib.toUint256(data, 404 +
/// destinationMessage_paramLength + takeTokenAddress_paramLength + receiverDst_paramLength +
/// orderAuthorityAddressDst_paramLength + allowedTakerDst_paramLength);
/// @notice         bytes allowedCancelBeneficiarySrc = BytesLib.slice(data, 436 + destinationMessage_paramLength +
/// takeTokenAddress_paramLength + receiverDst_paramLength + orderAuthorityAddressDst_paramLength +
/// allowedTakerDst_paramLength, allowedCancelBeneficiarySrc_paramLength);
/// @notice         uint256 affiliateFee_paramLength = BytesLib.toUint256(data, 436 + destinationMessage_paramLength +
/// takeTokenAddress_paramLength + receiverDst_paramLength + orderAuthorityAddressDst_paramLength +
/// allowedTakerDst_paramLength + allowedCancelBeneficiarySrc_paramLength);
/// @notice         bytes affiliateFee = BytesLib.slice(data, 468 + destinationMessage_paramLength +
/// takeTokenAddress_paramLength + receiverDst_paramLength + orderAuthorityAddressDst_paramLength +
/// allowedTakerDst_paramLength + allowedCancelBeneficiarySrc_paramLength, affiliateFee_paramLength);
/// @notice         uint256 referralCode = BytesLib.toUint256(data, 468 + destinationMessage_paramLength +
/// takeTokenAddress_paramLength + receiverDst_paramLength + orderAuthorityAddressDst_paramLength +
/// allowedTakerDst_paramLength + allowedCancelBeneficiarySrc_paramLength + affiliateFee_paramLength);
contract DeBridgeSendOrderAndExecuteOnDstHook is BaseHook, ISuperHookContextAware {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable dlnSource;
    address private immutable _validator;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 0;

    error AMOUNT_UNDERFLOW();

    constructor(address dlnSource_, address validator_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE) {
        if (dlnSource_ == address(0) || validator_ == address(0)) revert ADDRESS_NOT_VALID();
        dlnSource = dlnSource_;
        _validator = validator_;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        bytes memory signature = ISuperSignatureStorage(_validator).retrieveSignatureData(account);
        (IDlnSource.OrderCreation memory orderCreation, uint256 value, bytes memory affiliateFee, uint32 referralCode) =
            _createOrder(data, signature);

        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
        if (usePrevHookAmount) {
            uint256 outAmount = ISuperHookResult(prevHook).getOutAmount(account);

            // update `takeAmount` with the % `giveAmount` was updated by
            if (orderCreation.giveAmount > 0 && orderCreation.takeAmount > 0) {
                // takeAmount *= outAmount / giveAmount
                orderCreation.takeAmount = Math.mulDiv(orderCreation.takeAmount, outAmount, orderCreation.giveAmount);
            }

            uint256 _oldGiveAmount = orderCreation.giveAmount;
            orderCreation.giveAmount = outAmount;
            if (orderCreation.giveTokenAddress == address(0)) {
                if (value < _oldGiveAmount) revert AMOUNT_UNDERFLOW();
                value -= _oldGiveAmount;
                value += outAmount;
            }
        }

        // checks
        if (orderCreation.giveAmount == 0) revert AMOUNT_NOT_VALID();

        // build execution
        executions = new Execution[](1);
        executions[0] = Execution({
            target: dlnSource,
            value: value,
            callData: abi.encodeCall(IDlnSource.createOrder, (orderCreation, affiliateFee, referralCode, ""))
        });
    }

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        (IDlnSource.OrderCreation memory orderCreation,,,) = _createOrder(data, "");

        return abi.encodePacked(
            orderCreation.giveTokenAddress,
            address(bytes20(orderCreation.takeTokenAddress)),
            address(bytes20(orderCreation.receiverDst)),
            address(bytes20(orderCreation.givePatchAuthoritySrc)),
            address(bytes20(orderCreation.orderAuthorityAddressDst)),
            address(bytes20(orderCreation.allowedCancelBeneficiarySrc))
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    // because of stack too deep
    struct LocalVars {
        uint256 offset;
        uint256 len;
        uint8 version;
        address giveTokenAddress;
        uint256 giveAmount;
        address fallbackAddress;
        address executorAddress;
        uint256 executionFee;
        bool allowDelayedExecution;
        bool requireSuccessfulExecution;
        bytes destinationMessage;
        bytes takeTokenAddress;
        uint256 takeAmount;
        uint256 takeChainId;
        bytes receiverDst;
        address givePatchAuthoritySrc;
        bytes orderAuthorityAddressDst;
        bytes allowedTakerDst;
        bytes allowedCancelBeneficiarySrc;
    }

    struct ExternalCallParams {
        bytes destinationMessage;
        bytes sigData;
        address fallbackAddress;
        address executorAddress;
        uint256 executionFee;
        bool allowDelayedExecution;
        bool requireSuccessfulExecution;
        uint8 version;
    }

    function _createOrder(
        bytes memory data,
        bytes memory sigData
    )
        internal
        pure
        returns (
            IDlnSource.OrderCreation memory orderCreation,
            uint256 value,
            bytes memory affiliateFee,
            uint32 referralCode
        )
    {
        LocalVars memory vars;
        vars.offset = 1; // skip usePrevHookAmount (bool)

        value = BytesLib.toUint256(data, vars.offset);
        vars.offset += 32;

        vars.giveTokenAddress = BytesLib.toAddress(data, vars.offset);
        vars.offset += 20;

        vars.giveAmount = BytesLib.toUint256(data, vars.offset);
        vars.offset += 32;

        vars.version = BytesLib.toUint8(data, vars.offset);
        vars.offset += 1;

        vars.fallbackAddress = BytesLib.toAddress(data, vars.offset);
        vars.offset += 20;

        vars.executorAddress = BytesLib.toAddress(data, vars.offset);
        vars.offset += 20;

        vars.executionFee = BytesLib.toUint256(data, vars.offset);
        vars.offset += 32;

        vars.allowDelayedExecution = _decodeBool(data, vars.offset);
        vars.offset += 1;

        vars.requireSuccessfulExecution = _decodeBool(data, vars.offset);
        vars.offset += 1;

        vars.len = BytesLib.toUint256(data, vars.offset);
        vars.offset += 32;
        vars.destinationMessage = BytesLib.slice(data, vars.offset, vars.len);
        vars.offset += vars.len;

        vars.len = BytesLib.toUint256(data, vars.offset);
        vars.offset += 32;
        vars.takeTokenAddress = BytesLib.slice(data, vars.offset, vars.len);
        vars.offset += vars.len;

        vars.takeAmount = BytesLib.toUint256(data, vars.offset);
        vars.offset += 32;

        vars.takeChainId = BytesLib.toUint256(data, vars.offset);
        vars.offset += 32;

        vars.len = BytesLib.toUint256(data, vars.offset);
        vars.offset += 32;
        vars.receiverDst = BytesLib.slice(data, vars.offset, vars.len);
        vars.offset += vars.len;

        vars.givePatchAuthoritySrc = BytesLib.toAddress(data, vars.offset);
        vars.offset += 20;

        vars.len = BytesLib.toUint256(data, vars.offset);
        vars.offset += 32;
        vars.orderAuthorityAddressDst = BytesLib.slice(data, vars.offset, vars.len);
        vars.offset += vars.len;

        vars.len = BytesLib.toUint256(data, vars.offset);
        vars.offset += 32;
        vars.allowedTakerDst = BytesLib.slice(data, vars.offset, vars.len);
        vars.offset += vars.len;

        vars.len = BytesLib.toUint256(data, vars.offset);
        vars.offset += 32;
        vars.allowedCancelBeneficiarySrc = BytesLib.slice(data, vars.offset, vars.len);
        vars.offset += vars.len;

        uint256 affiliateFeeLength = BytesLib.toUint256(data, vars.offset);
        vars.offset += 32;
        affiliateFee = BytesLib.slice(data, vars.offset, affiliateFeeLength);
        vars.offset += affiliateFeeLength;

        referralCode = BytesLib.toUint32(data, vars.offset);
        vars.offset += 4;

        orderCreation = IDlnSource.OrderCreation({
            giveTokenAddress: vars.giveTokenAddress,
            giveAmount: vars.giveAmount,
            takeTokenAddress: vars.takeTokenAddress,
            takeAmount: vars.takeAmount,
            takeChainId: vars.takeChainId,
            receiverDst: vars.receiverDst,
            givePatchAuthoritySrc: vars.givePatchAuthoritySrc,
            orderAuthorityAddressDst: vars.orderAuthorityAddressDst,
            allowedTakerDst: vars.allowedTakerDst,
            externalCall: _buildExternalCall(
                ExternalCallParams({
                    destinationMessage: vars.destinationMessage,
                    sigData: sigData,
                    fallbackAddress: vars.fallbackAddress,
                    executorAddress: vars.executorAddress,
                    executionFee: vars.executionFee,
                    allowDelayedExecution: vars.allowDelayedExecution,
                    requireSuccessfulExecution: vars.requireSuccessfulExecution,
                    version: vars.version
                })
            ),
            allowedCancelBeneficiarySrc: vars.allowedCancelBeneficiarySrc
        });
    }

    function _buildExternalCall(ExternalCallParams memory params) internal pure returns (bytes memory) {
        if (params.destinationMessage.length == 0) return bytes("");

        // append signature to `destinationMessage` and build call data
        (
            bytes memory initData,
            bytes memory executorCalldata,
            address account,
            address[] memory dstTokens,
            uint256[] memory intentAmounts
        ) = abi.decode(params.destinationMessage, (bytes, bytes, address, address[], uint256[]));

        IDlnSource.ExternalCallEnvelopV1 memory envelope = IDlnSource.ExternalCallEnvelopV1({
            payload: abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, params.sigData),
            fallbackAddress: params.fallbackAddress,
            executorAddress: params.executorAddress,
            executionFee: uint160(params.executionFee),
            allowDelayedExecution: params.allowDelayedExecution,
            requireSuccessfullExecution: params.requireSuccessfulExecution
        });

        return abi.encodePacked(params.version, abi.encode(envelope));
    }

    function _preExecute(address, address, bytes calldata) internal override { }

    function _postExecute(address, address, bytes calldata) internal override { }
}
