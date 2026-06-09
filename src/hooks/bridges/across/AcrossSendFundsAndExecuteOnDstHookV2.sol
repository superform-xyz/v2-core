// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IAcrossSpokePoolV3 } from "../../../vendor/bridges/across/IAcrossSpokePoolV3.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperSignatureStorage } from "../../../interfaces/ISuperSignatureStorage.sol";
import {
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";

/// @title AcrossSendFundsAndExecuteOnDstHookV2
/// @author Superform Labs
/// @dev V2 version — sends cross-chain via Across V3 with compact message encoding
/// @dev destinationMessage uses 2-field format: abi.encode(initData, sigData) instead of V1's 6-field format
/// @dev The destinationMessage input from the bundler contains only abi.encode(initData) (1-field).
/// @dev The hook retrieves sigData from the validator's transient storage and appends it.
/// @dev This eliminates duplicate data (executorCalldata, account, dstTokens, intentAmounts) per message.
/// @dev inputAmount and outputAmount have to be predicted by the SuperBundler
/// @dev data has the following structure
/// @notice         uint256 value = BytesLib.toUint256(data, 0);
/// @notice         address recipient = BytesLib.toAddress(data, 32);
/// @notice         address inputToken = BytesLib.toAddress(data, 52);
/// @notice         address outputToken = BytesLib.toAddress(data, 72);
/// @notice         uint256 inputAmount = BytesLib.toUint256(data, 92);
/// @notice         uint256 outputAmount = BytesLib.toUint256(data, 124);
/// @notice         uint256 destinationChainId = BytesLib.toUint256(data, 156);
/// @notice         address exclusiveRelayer = BytesLib.toAddress(data, 188);
/// @notice         uint32 fillDeadlineOffset = BytesLib.toUint32(data, 208);
/// @notice         uint32 exclusivityPeriod = BytesLib.toUint32(data, 212);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 216);
/// @notice         bytes destinationMessage = BytesLib.slice(data, 217, data.length - 217);
///                 V2: destinationMessage = abi.encode(initData) — 1-field only
contract AcrossSendFundsAndExecuteOnDstHookV2 is BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable SPOKE_POOL_V3;
    address private immutable VALIDATOR;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 216;
    uint256 private constant AMOUNT_POSITION = 92;

    struct AcrossV3DepositAndExecuteData {
        uint256 value;
        address recipient;
        address inputToken;
        address outputToken;
        uint256 inputAmount;
        uint256 outputAmount;
        uint256 destinationChainId;
        address exclusiveRelayer;
        uint32 fillDeadlineOffset;
        uint32 exclusivityPeriod;
        bool usePrevHookAmount;
        bytes destinationMessage;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error DATA_NOT_VALID();

    constructor(address spokePoolV3_, address validator_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE) {
        if (spokePoolV3_ == address(0) || validator_ == address(0)) revert ADDRESS_NOT_VALID();
        SPOKE_POOL_V3 = spokePoolV3_;
        VALIDATOR = validator_;
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
        if (data.length < 217) revert DATA_NOT_VALID();

        AcrossV3DepositAndExecuteData memory d;
        d.value = BytesLib.toUint256(data, 0);
        d.recipient = BytesLib.toAddress(data, 32);
        d.inputToken = BytesLib.toAddress(data, 52);
        d.outputToken = BytesLib.toAddress(data, 72);
        d.inputAmount = BytesLib.toUint256(data, 92);
        d.outputAmount = BytesLib.toUint256(data, 124);
        d.destinationChainId = BytesLib.toUint256(data, 156);
        d.exclusiveRelayer = BytesLib.toAddress(data, 188);
        d.fillDeadlineOffset = BytesLib.toUint32(data, 208);
        d.exclusivityPeriod = BytesLib.toUint32(data, 212);
        d.usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
        d.destinationMessage = BytesLib.slice(data, 217, data.length - 217);

        if (d.usePrevHookAmount) {
            uint256 outAmount = ISuperHookResult(prevHook).getOutAmount(account);

            // update `outputAmount` with the % `inputAmount` was updated by
            if (d.inputAmount > 0 && d.outputAmount > 0) {
                d.outputAmount = Math.mulDiv(d.outputAmount, outAmount, d.inputAmount);
            }

            d.inputAmount = outAmount;
            if (
                d.inputToken == address(IAcrossSpokePoolV3(SPOKE_POOL_V3).wrappedNativeToken())
                    && d.value != 0
            ) {
                d.value = outAmount;
            }
        }

        if (d.inputAmount == 0) revert AMOUNT_NOT_VALID();

        if (d.recipient == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        // V2: if `destinationMessage` is present, append sigData in compact format
        if (d.destinationMessage.length > 0) {
            // Minimum ABI-encoded size for (bytes) — offset pointer (32) + length (32) = 64
            if (d.destinationMessage.length < 64) revert DATA_NOT_VALID();

            bytes memory sigData = ISuperSignatureStorage(VALIDATOR).retrieveSignatureData(account);

            // Decode the 1-field input to extract initData
            bytes memory initData = abi.decode(d.destinationMessage, (bytes));

            // Re-encode as compact 2-field format
            d.destinationMessage = abi.encode(initData, sigData);
        }

        // build execution
        executions = new Execution[](1);
        executions[0] = Execution({
            target: SPOKE_POOL_V3,
            value: d.value,
            callData: abi.encodeCall(
                IAcrossSpokePoolV3.depositV3Now,
                (
                    account,
                    d.recipient,
                    d.inputToken,
                    d.outputToken,
                    d.inputAmount,
                    d.outputAmount,
                    d.destinationChainId,
                    d.exclusiveRelayer,
                    d.fillDeadlineOffset,
                    d.exclusivityPeriod,
                    d.destinationMessage
                )
            )
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmount(bytes memory data) external pure returns (uint256) {
        return BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookOutflow
    function replaceCalldataAmount(bytes memory data, uint256 amount) external pure returns (bytes memory) {
        return _replaceCalldataAmount(data, amount, AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(
            BytesLib.toAddress(data, 32), // recipient
            BytesLib.toAddress(data, 52), // inputToken
            BytesLib.toAddress(data, 72), // outputToken
            BytesLib.toAddress(data, 188) // exclusiveRelayer
        );
    }
}
