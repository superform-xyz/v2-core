// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IDlnDestination, Order } from "../../../vendor/debridge/IDlnDestination.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title DeBridgeCancelOrderHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         uint256 value = BytesLib.toUint256(data, 0);
/// @notice         uint64 makerOrderNonce = BytesLib.toUint64(data, 32);
/// @notice         uint256 makerSrc_paramLength = BytesLib.toUint256(data, 40);
/// @notice         bytes makerSrc = BytesLib.slice(data, 72, makerSrc_paramLength);
/// @notice         uint256 giveTokenAddress_paramLength = BytesLib.toUint256(data, 72 + makerSrc_paramLength);
/// @notice         bytes giveTokenAddress = BytesLib.slice(data, 104 + makerSrc_paramLength,
/// giveTokenAddress_paramLength);
/// @notice         uint256 giveAmount = BytesLib.toUint256(data, 104 + makerSrc_paramLength +
/// giveTokenAddress_paramLength);
/// @notice         uint256 giveChainId = BytesLib.toUint256(data, 136 + makerSrc_paramLength +
/// giveTokenAddress_paramLength);
/// @notice         uint256 takeChainId = BytesLib.toUint256(data, 168 + makerSrc_paramLength +
/// giveTokenAddress_paramLength);
/// @notice         uint256 takeTokenAddress_paramLength = BytesLib.toUint256(data, 200 + makerSrc_paramLength +
/// giveTokenAddress_paramLength);
/// @notice         bytes takeTokenAddress = BytesLib.slice(data, 232 + makerSrc_paramLength +
/// giveTokenAddress_paramLength + takeTokenAddress_paramLength);
/// @notice         uint256 takeAmount = BytesLib.toUint256(data, 232 + makerSrc_paramLength +
/// giveTokenAddress_paramLength + takeTokenAddress_paramLength);
/// @notice         uint256 receiverDst_paramLength = BytesLib.toUint256(data, 264 + makerSrc_paramLength +
/// giveTokenAddress_paramLength + takeTokenAddress_paramLength);
/// @notice         bytes receiverDst = BytesLib.slice(data, 296 + makerSrc_paramLength + giveTokenAddress_paramLength +
/// takeTokenAddress_paramLength + receiverDst_paramLength);
/// @notice         uint256 givePatchAuthoritySrc_paramLength = BytesLib.toUint256(data, 296 + makerSrc_paramLength +
/// giveTokenAddress_paramLength + takeTokenAddress_paramLength + receiverDst_paramLength);
/// @notice         bytes givePatchAuthoritySrc = BytesLib.slice(data, 328 + makerSrc_paramLength +
/// giveTokenAddress_paramLength + takeTokenAddress_paramLength + receiverDst_paramLength +
/// givePatchAuthoritySrc_paramLength);
/// @notice         uint256 orderAuthorityAddressDst_paramLength = BytesLib.toUint256(data, 328 + makerSrc_paramLength +
/// giveTokenAddress_paramLength + takeTokenAddress_paramLength + receiverDst_paramLength +
/// givePatchAuthoritySrc_paramLength);
/// @notice         bytes orderAuthorityAddressDst = BytesLib.slice(data, 360 + makerSrc_paramLength +
/// giveTokenAddress_paramLength + takeTokenAddress_paramLength + receiverDst_paramLength +
/// givePatchAuthoritySrc_paramLength + orderAuthorityAddressDst_paramLength);
/// @notice         uint256 allowedTakerDst_paramLength = BytesLib.toUint256(data, 360 + makerSrc_paramLength +
/// giveTokenAddress_paramLength + takeTokenAddress_paramLength + receiverDst_paramLength +
/// givePatchAuthoritySrc_paramLength + orderAuthorityAddressDst_paramLength);
/// @notice         bytes allowedTakerDst = BytesLib.slice(data, 392 + makerSrc_paramLength +
/// giveTokenAddress_paramLength + takeTokenAddress_paramLength + receiverDst_paramLength +
/// givePatchAuthoritySrc_paramLength + orderAuthorityAddressDst_paramLength + allowedTakerDst_paramLength);
/// @notice         uint256 allowedCancelBeneficiarySrc_paramLength = BytesLib.toUint256(data, 392 +
/// makerSrc_paramLength + giveTokenAddress_paramLength + takeTokenAddress_paramLength + receiverDst_paramLength +
/// givePatchAuthoritySrc_paramLength + orderAuthorityAddressDst_paramLength + allowedTakerDst_paramLength);
/// @notice         bytes allowedCancelBeneficiarySrc = BytesLib.slice(data, 424 + makerSrc_paramLength +
/// giveTokenAddress_paramLength + takeTokenAddress_paramLength + receiverDst_paramLength +
/// givePatchAuthoritySrc_paramLength + orderAuthorityAddressDst_paramLength + allowedTakerDst_paramLength +
/// allowedCancelBeneficiarySrc_paramLength);
/// @notice         uint256 executionFee = BytesLib.toUint256(data, 424 + makerSrc_paramLength +
/// giveTokenAddress_paramLength + takeTokenAddress_paramLength + receiverDst_paramLength +
/// givePatchAuthoritySrc_paramLength + orderAuthorityAddressDst_paramLength + allowedTakerDst_paramLength +
/// allowedCancelBeneficiarySrc_paramLength);
contract DeBridgeCancelOrderHook is BaseHook {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable dlnDestination;

    constructor(address dlnDestination_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE) {
        if (dlnDestination_ == address(0)) revert ADDRESS_NOT_VALID();
        dlnDestination = dlnDestination_;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function _buildHookExecutions(
        address,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        (Order memory order, uint256 value, uint256 executionFee) = _createOrder(data);

        // build execution
        executions = new Execution[](1);
        executions[0] = Execution({
            target: dlnDestination,
            value: value,
            callData: abi.encodeCall(IDlnDestination.sendEvmOrderCancel, (order, account, executionFee))
        });
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        (Order memory order,,) = _createOrder(data);

        return abi.encodePacked(
            order.giveTokenAddress,
            address(bytes20(order.takeTokenAddress)),
            address(bytes20(order.receiverDst)),
            address(bytes20(order.givePatchAuthoritySrc)),
            address(bytes20(order.orderAuthorityAddressDst)),
            address(bytes20(order.allowedCancelBeneficiarySrc))
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _createOrder(bytes memory data)
        internal
        pure
        returns (Order memory vars, uint256 value, uint256 executionFee)
    {
        uint256 offset = 0;

        value = BytesLib.toUint256(data, offset);
        offset += 32;

        vars.makerOrderNonce = BytesLib.toUint64(data, offset);
        offset += 8;

        uint256 makerSrcLen = BytesLib.toUint256(data, offset);
        offset += 32;
        vars.makerSrc = BytesLib.slice(data, offset, makerSrcLen);
        offset += makerSrcLen;

        uint256 giveTokenAddressLen = BytesLib.toUint256(data, offset);
        offset += 32;
        vars.giveTokenAddress = BytesLib.slice(data, offset, giveTokenAddressLen);
        offset += giveTokenAddressLen;

        vars.giveAmount = BytesLib.toUint256(data, offset);
        offset += 32;

        vars.giveChainId = BytesLib.toUint256(data, offset);
        offset += 32;

        vars.takeChainId = BytesLib.toUint256(data, offset);
        offset += 32;

        uint256 takeTokenAddressLen = BytesLib.toUint256(data, offset);
        offset += 32;
        vars.takeTokenAddress = BytesLib.slice(data, offset, takeTokenAddressLen);
        offset += takeTokenAddressLen;

        vars.takeAmount = BytesLib.toUint256(data, offset);
        offset += 32;

        uint256 receiverDstLen = BytesLib.toUint256(data, offset);
        offset += 32;
        vars.receiverDst = BytesLib.slice(data, offset, receiverDstLen);
        offset += receiverDstLen;

        uint256 givePatchAuthoritySrcLen = BytesLib.toUint256(data, offset);
        offset += 32;
        vars.givePatchAuthoritySrc = BytesLib.slice(data, offset, givePatchAuthoritySrcLen);
        offset += givePatchAuthoritySrcLen;

        uint256 orderAuthorityAddressDstLen = BytesLib.toUint256(data, offset);
        offset += 32;
        vars.orderAuthorityAddressDst = BytesLib.slice(data, offset, orderAuthorityAddressDstLen);
        offset += orderAuthorityAddressDstLen;

        uint256 allowedTakerDstLen = BytesLib.toUint256(data, offset);
        offset += 32;
        vars.allowedTakerDst = BytesLib.slice(data, offset, allowedTakerDstLen);
        offset += allowedTakerDstLen;

        uint256 allowedCancelBeneficiarySrcLen = BytesLib.toUint256(data, offset);
        offset += 32;
        vars.allowedCancelBeneficiarySrc = BytesLib.slice(data, offset, allowedCancelBeneficiarySrcLen);
        offset += allowedCancelBeneficiarySrcLen;

        vars.externalCall = ""; // Hook is used only for cancelling an order

        executionFee = BytesLib.toUint256(data, offset);
    }

    function _preExecute(address, address, bytes calldata) internal override { }

    function _postExecute(address, address, bytes calldata) internal override { }
}
