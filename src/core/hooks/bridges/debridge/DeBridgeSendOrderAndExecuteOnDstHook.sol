// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { IDlnSource } from "../../../../vendor/bridges/debridge/IDlnSource.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperSignatureStorage } from "../../../interfaces/ISuperSignatureStorage.sol";
import { ISuperHookResult, ISuperHookContextAware } from "../../../interfaces/ISuperHook.sol";

/// @title DeBridgeSendOrderAndExecuteOnDstHook
/// @author Superform Labs
/// @dev `externalCall` field won't contain the signature for the destination executor
/// @dev      signature is retrieved from the validator contract transient storage
/// @dev      This is needed to avoid circular dependency between merkle root which contains the signature needed to sign it
/// @dev data has the following structure
/// @notice         bool usePrevHookAmount = _decodeBool(0);
/// @notice         uint256 value = BytesLib.toUint256(data, 1);
/// @notice         address giveTokenAddress = BytesLib.toAddress(data, 33);
/// @notice         uint256 giveAmount = BytesLib.toUint256(data, 53);
/// @notice         uint256 takeTokenAddressLength = BytesLib.toUint256(data, 85);
/// @notice         bytes takeTokenAddress = BytesLib.slice(data, 117, takeTokenAddressLength);
/// @notice         uint256 takeAmount = BytesLib.toUint256(data, 149 + takeTokenAddressLength);
/// @notice         uint256 takeChainId = BytesLib.toUint256(data, 181 + takeTokenAddressLength);
/// @notice         uint256 receiverDstLength = BytesLib.toUint256(data, 213 + takeTokenAddressLength);
/// @notice         bytes receiverDst = BytesLib.slice(data, 245 + takeTokenAddressLength, receiverDstLength);
/// @notice         address givePatchAuthoritySrc = BytesLib.toAddress(data, 277 + takeTokenAddressLength +
/// receiverDstLength);
/// @notice         uint256 orderAuthorityAddress_paramLength = BytesLib.toUint256(data, 329 + takeTokenAddressLength +
/// receiverDstLength);
/// @notice         bytes orderAuthorityAddressDst = BytesLib.slice(data, 361 + takeTokenAddressLength +
/// receiverDstLength, orderAuthorityAddress_paramLength);
/// @notice         uint256 allowedTakerDst_paramLength = BytesLib.toUint256(data, 393 + takeTokenAddressLength +
/// receiverDstLength + orderAuthorityAddress_paramLength);
/// @notice         bytes allowedTakerDst = BytesLib.slice(data, 425 + takeTokenAddressLength + receiverDstLength +
/// orderAuthorityAddress_paramLength, allowedTakerDst_paramLength);
/// @notice         uint256 externalCall_paramLength = BytesLib.toUint256(data, 457 + takeTokenAddressLength +
/// receiverDstLength + orderAuthorityAddress_paramLength + allowedTakerDst_paramLength);
/// @notice         bytes externalCall = BytesLib.slice(data, 489 + takeTokenAddressLength + receiverDstLength +
/// orderAuthorityAddress_paramLength + allowedTakerDst_paramLength, externalCall_paramLength);
/// @notice         uint256 allowedCancelBeneficiarySrc_paramLength = BytesLib.toUint256(data, 521 + takeTokenAddressLength +
/// receiverDstLength + orderAuthorityAddress_paramLength + allowedTakerDst_paramLength + externalCall_paramLength);
/// @notice         bytes allowedCancelBeneficiarySrc = BytesLib.slice(data, 553 + takeTokenAddressLength +
/// receiverDstLength + orderAuthorityAddress_paramLength + allowedTakerDst_paramLength + externalCall_paramLength,
/// allowedCancelBeneficiarySrc_paramLength);
/// @notice         uint256 affiliateFee_paramLength = BytesLib.toUint256(data, 585 + takeTokenAddressLength +
/// receiverDstLength + orderAuthorityAddress_paramLength + allowedTakerDst_paramLength + externalCall_paramLength +
/// allowedCancelBeneficiarySrc_paramLength);
/// @notice         bytes affiliateFee = BytesLib.slice(data, 617 + takeTokenAddressLength + receiverDstLength +
/// orderAuthorityAddress_paramLength + allowedTakerDst_paramLength + externalCall_paramLength +
/// allowedCancelBeneficiarySrc_paramLength, affiliateFee_paramLength);
/// @notice         uint256 referralCode = BytesLib.toUint256(data, 649 + takeTokenAddressLength + receiverDstLength +
/// orderAuthorityAddress_paramLength + allowedTakerDst_paramLength + externalCall_paramLength +
/// allowedCancelBeneficiarySrc_paramLength + affiliateFee_paramLength);
contract DeBridgeSendOrderAndExecuteOnDstHook is BaseHook, ISuperHookContextAware {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable dlnSource;
    address private immutable _validator;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 0;

    constructor(address dlnSource_, address validator_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE) {
        if (dlnSource_ == address(0) || validator_ == address(0)) revert ADDRESS_NOT_VALID();
        dlnSource = dlnSource_;
        _validator = validator_;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function build(
        address prevHook,
        address account,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        (
            IDlnSource.OrderCreation memory orderCreation,
            uint256 value,
            bytes memory affiliateFee,
            uint32 referralCode
        ) = _createOrder(data);

        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
        if (usePrevHookAmount) {
            uint256 outAmount = ISuperHookResult(prevHook).outAmount();
            uint256 _oldGiveAmount = orderCreation.giveAmount;
            orderCreation.giveAmount = outAmount;
            if (orderCreation.giveTokenAddress == address(0)) {
                value -= _oldGiveAmount;
                value += outAmount;
            }
        }

        // append signature to `orderCreation.externalCall`
        bytes memory signature = ISuperSignatureStorage(_validator).retrieveSignatureData(account);
        orderCreation.externalCall = _recreateExternalCallEnvelope(orderCreation.externalCall, signature);

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

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    // because of stack too deep
    struct LocalVars {
        uint256 offset;
        uint256 len;
        address giveTokenAddress;
        uint256 giveAmount;
        bytes takeTokenAddress;
        uint256 takeAmount;
        uint256 takeChainId;
        bytes receiverDst;
        address givePatchAuthoritySrc;
        bytes orderAuthorityAddressDst;
        bytes allowedTakerDst;
        bytes externalCall;
        bytes allowedCancelBeneficiarySrc;
    }

    function _createOrder(bytes memory data)
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
        vars.externalCall = BytesLib.slice(data, vars.offset, vars.len);
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
            externalCall: vars.externalCall,
            allowedCancelBeneficiarySrc: vars.allowedCancelBeneficiarySrc
        });
    }

    function _preExecute(address, address, bytes calldata) internal override { }

    function _postExecute(address, address, bytes calldata) internal override { }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _recreateExternalCallEnvelope(bytes memory input, bytes memory sigData) private pure returns (bytes memory) {
        uint8 version = uint8(input[0]);
        bytes memory encodedStruct = BytesLib.slice(input, 1, input.length - 1); // skip version

        IDlnSource.ExternalCallEnvelopV1 memory envelope = abi.decode(
            encodedStruct,
            (IDlnSource.ExternalCallEnvelopV1)
        );
        (
            bytes memory initData,
            bytes memory executorCalldata,
            address account,
            uint256 intentAmount
        ) = abi.decode(envelope.payload, (bytes, bytes, address, uint256));
        envelope.payload = abi.encode(initData, executorCalldata, account, intentAmount, sigData);
        return abi.encodePacked(version, abi.encode(envelope));
    }
}
