// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { ITokenMessengerV2 } from "../../../vendor/bridges/cctp/ITokenMessengerV2.sol";
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

/// @title CCTPSendHook
/// @author Superform Labs
/// @dev Burns USDC via Circle's CCTP V2 TokenMessengerV2.depositForBurnWithHook for cross-chain transfers
/// @dev No approval pattern — caller must have already approved TOKEN_MESSENGER for the burn token
/// @dev For the approve-and-send variant, use ApproveAndCCTPSendHook instead
/// @dev No native ETH needed — CCTP V2 deducts fees from the transfer amount via maxFee
/// @dev `hookCallData` field won't contain the signature for the destination executor
/// @dev      signature is retrieved from the validator contract transient storage
/// @dev      This is needed to avoid circular dependency between merkle root which contains the signature needed to
/// sign it
/// @dev data has the following structure
/// @notice         address burnToken = BytesLib.toAddress(data, 0);
/// @notice         uint256 amount = BytesLib.toUint256(data, 20);
/// @notice         uint32 destinationDomain = BytesLib.toUint32(data, 52);
/// @notice         bytes32 mintRecipient = BytesLib.toBytes32(data, 56);
/// @notice         bytes32 destinationCaller = BytesLib.toBytes32(data, 88);
/// @notice         uint256 maxFee = BytesLib.toUint256(data, 120);
/// @notice         uint32 minFinalityThreshold = BytesLib.toUint32(data, 152);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 156);
/// @notice         bytes hookCallData = BytesLib.slice(data, 157, data.length - 157);
contract CCTPSendHook is BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable TOKEN_MESSENGER;
    address private immutable VALIDATOR;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 156;
    uint256 private constant AMOUNT_POSITION = 20;

    struct CCTPSendData {
        address burnToken;
        uint256 amount;
        uint32 destinationDomain;
        bytes32 mintRecipient;
        bytes32 destinationCaller;
        uint256 maxFee;
        uint32 minFinalityThreshold;
        bytes hookCallData;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the input data length is less than the minimum required or variable fields exceed bounds
    error DATA_NOT_VALID();

    /// @notice Thrown when the mint recipient is the zero bytes32 value
    error RECIPIENT_NOT_VALID();

    /// @param tokenMessenger_ The CCTP V2 TokenMessengerV2 contract address
    /// @param validator_ The validator contract address for signature retrieval
    constructor(
        address tokenMessenger_,
        address validator_
    ) BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE) {
        if (tokenMessenger_ == address(0) || validator_ == address(0)) revert ADDRESS_NOT_VALID();
        TOKEN_MESSENGER = tokenMessenger_;
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
        if (data.length < 157) revert DATA_NOT_VALID();

        CCTPSendData memory s;
        s.burnToken = BytesLib.toAddress(data, 0);
        s.amount = BytesLib.toUint256(data, 20);
        s.destinationDomain = BytesLib.toUint32(data, 52);
        s.mintRecipient = BytesLib.toBytes32(data, 56);
        s.destinationCaller = BytesLib.toBytes32(data, 88);
        s.maxFee = BytesLib.toUint256(data, 120);
        s.minFinalityThreshold = BytesLib.toUint32(data, 152);

        // Fail-fast validation on fixed fields before external calls
        if (s.burnToken == address(0)) revert ADDRESS_NOT_VALID();
        if (s.mintRecipient == bytes32(0)) revert RECIPIENT_NOT_VALID();

        // Decode variable-length hookCallData (last field — length derived from total data length)
        if (data.length > 157) {
            s.hookCallData = BytesLib.slice(data, 157, data.length - 157);
        }

        if (_decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION)) {
            uint256 outAmount = ISuperHookResult(prevHook).getOutAmount(account);

            // Scale maxFee proportionally to the new amount
            if (s.amount > 0 && s.maxFee > 0) {
                s.maxFee = Math.mulDiv(s.maxFee, outAmount, s.amount);
            }

            s.amount = outAmount;
        }

        if (s.amount == 0) revert AMOUNT_NOT_VALID();

        // Append signature to hookCallData if present
        if (s.hookCallData.length > 0) {
            // Minimum ABI-encoded size for (bytes, bytes, address, address[], uint256[])
            if (s.hookCallData.length < 160) revert DATA_NOT_VALID();

            bytes memory signature = ISuperSignatureStorage(VALIDATOR).retrieveSignatureData(account);

            (
                bytes memory initData,
                bytes memory executorCalldata,
                address _account,
                address[] memory dstTokens,
                uint256[] memory intentAmounts
            ) = abi.decode(s.hookCallData, (bytes, bytes, address, address[], uint256[]));

            s.hookCallData = abi.encode(initData, executorCalldata, _account, dstTokens, intentAmounts, signature);
        }

        // Build 1 execution — no approval pattern (caller must have already approved)
        executions = new Execution[](1);

        // Execution 0: CCTP V2 depositForBurnWithHook (value = 0, no native ETH needed)
        executions[0] = Execution({
            target: TOKEN_MESSENGER,
            value: 0,
            callData: abi.encodeCall(
                ITokenMessengerV2.depositForBurnWithHook,
                (
                    s.amount,
                    s.destinationDomain,
                    s.mintRecipient,
                    s.burnToken,
                    s.destinationCaller,
                    s.maxFee,
                    s.minFinalityThreshold,
                    s.hookCallData
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
            BytesLib.toAddress(data, 0), // burnToken
            address(uint160(uint256(BytesLib.toBytes32(data, 56)))) // mintRecipient (as address from bytes32)
        );
    }
}
