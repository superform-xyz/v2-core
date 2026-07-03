// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IStargate } from "../../../vendor/bridges/stargate/IStargate.sol";
import { IOFT } from "../../../vendor/bridges/layerzero/IOFT.sol";
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

/// @title StargateSendHookV2
/// @author Superform Labs
/// @dev V2 version — sends native tokens cross-chain via Stargate V2 with compact compose encoding
/// @dev Compose message uses 2-field format: abi.encode(initData, sigData) instead of V1's 6-field format
/// @dev The composeMsg input from the bundler contains only abi.encode(initData) (1-field).
/// @dev The hook retrieves sigData from the validator's transient storage and appends it.
/// @dev This eliminates ~1.5-5.5 KB of duplicate data per message to stay within LayerZero's 10k limit.
/// @dev For native sends: msg.value = lzNativeFee + amountLD
/// @dev LZ messaging fee is always paid in native ETH (lzTokenFee is hardcoded to 0)
/// @dev WARNING: refundAddress is set to the account. If the native fee is overestimated, Stargate synchronously
/// @dev refunds the excess to the account during sendToken.
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes placeholder = BytesLib.slice(data, 0, 52);
/// @notice         uint256 lzNativeFee = BytesLib.toUint256(data, 52);
/// @notice         address stargatePool = BytesLib.toAddress(data, 84);
/// @notice         address inputToken = BytesLib.toAddress(data, 104);
/// @notice         uint32 dstEid = BytesLib.toUint32(data, 124);
/// @notice         bytes32 to = BytesLib.toBytes32(data, 128);
/// @notice         uint256 amountLD = BytesLib.toUint256(data, 160);
/// @notice         uint256 minAmountLD = BytesLib.toUint256(data, 192);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 224);
/// @notice         uint8 mode = BytesLib.toUint8(data, 225);
/// @notice         uint256 extraOptionsLength = BytesLib.toUint256(data, 226);
/// @notice         bytes extraOptions = BytesLib.slice(data, 258, extraOptionsLength);
/// @notice         uint256 composeMsgLength = BytesLib.toUint256(data, 258 + extraOptionsLength);
/// @notice         bytes composeMsg = BytesLib.slice(data, 290 + extraOptionsLength, composeMsgLength);
///                 V2: composeMsg = abi.encode(initData) — 1-field only, no executorCalldata/account/dstTokens/intentAmounts
contract StargateSendHookV2 is BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address private immutable VALIDATOR;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 224;
    uint256 private constant AMOUNT_POSITION = 160;

    struct StargateSendData {
        uint256 lzNativeFee;
        address stargatePool;
        uint32 dstEid;
        bytes32 to;
        uint256 amountLD;
        uint256 minAmountLD;
        uint8 mode;
        bytes extraOptions;
        bytes composeMsg;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the input data length is less than the minimum required or variable fields exceed bounds
    error DATA_NOT_VALID();

    /// @notice Thrown when the Stargate pool address is invalid or not a legitimate Stargate pool
    error POOL_NOT_VALID();

    /// @notice Thrown when the mode flag is not 0 (taxi), 1 (bus), or 2 (OFT)
    error MODE_NOT_VALID();

    /// @param validator_ The validator contract address for signature retrieval
    constructor(address validator_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE) {
        if (validator_ == address(0)) revert ADDRESS_NOT_VALID();
        VALIDATOR = validator_;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Stargate Bridge V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Bridges tokens via Stargate V2 cross-chain messaging";
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
        if (data.length < 290) revert DATA_NOT_VALID();

        StargateSendData memory s;
        s.lzNativeFee = BytesLib.toUint256(data, 52);
        s.stargatePool = BytesLib.toAddress(data, 84);
        s.dstEid = BytesLib.toUint32(data, 124);
        s.to = BytesLib.toBytes32(data, 128);
        s.amountLD = BytesLib.toUint256(data, 160);
        s.minAmountLD = BytesLib.toUint256(data, 192);
        s.mode = BytesLib.toUint8(data, 225);
        if (s.mode > 2) revert MODE_NOT_VALID();

        // Fail-fast validation on fixed fields before external calls
        if (s.stargatePool == address(0)) revert POOL_NOT_VALID();
        if (s.to == bytes32(0)) revert ADDRESS_NOT_VALID();

        // Verify pool implements IStargate interface (reverts on non-pool addresses)
        IStargate(s.stargatePool).token();

        // Validate variable-length field bounds
        uint256 extraOptionsLength = BytesLib.toUint256(data, 226);
        if (data.length < 290 + extraOptionsLength) revert DATA_NOT_VALID();
        s.extraOptions = BytesLib.slice(data, 258, extraOptionsLength);

        uint256 composeMsgOffset = 258 + extraOptionsLength;
        uint256 composeMsgLength = BytesLib.toUint256(data, composeMsgOffset);
        if (data.length < composeMsgOffset + 32 + composeMsgLength) revert DATA_NOT_VALID();
        s.composeMsg = BytesLib.slice(data, composeMsgOffset + 32, composeMsgLength);

        if (_decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION)) {
            uint256 outAmount = ISuperHookResult(prevHook).getOutAmount(account);

            // Scale minAmountLD proportionally
            if (s.amountLD > 0 && s.minAmountLD > 0) {
                s.minAmountLD = Math.mulDiv(s.minAmountLD, outAmount, s.amountLD);
                if (s.minAmountLD == 0) revert AMOUNT_NOT_VALID();
            }

            s.amountLD = outAmount;
        }

        if (s.amountLD == 0) revert AMOUNT_NOT_VALID();

        // V2: Append sigData to composeMsg if present
        // composeMsg input = abi.encode(initData) (1-field from bundler)
        // composeMsg output = abi.encode(initData, sigData) (2-field for adapter)
        if (s.composeMsg.length > 0) {
            // Minimum ABI-encoded size for (bytes) — offset pointer (32) + length (32) = 64
            if (s.composeMsg.length < 64) revert DATA_NOT_VALID();

            bytes memory sigData = ISuperSignatureStorage(VALIDATOR).retrieveSignatureData(account);

            // Decode the 1-field input to extract initData
            bytes memory initData = abi.decode(s.composeMsg, (bytes));

            // Re-encode as compact 2-field format
            s.composeMsg = abi.encode(initData, sigData);
        }

        // Build executions based on mode
        if (s.mode <= 1) {
            // Stargate mode (taxi=0, bus=1)
            IStargate.SendParam memory sendParam = IStargate.SendParam({
                dstEid: s.dstEid,
                to: s.to,
                amountLD: s.amountLD,
                minAmountLD: s.minAmountLD,
                extraOptions: s.extraOptions,
                composeMsg: s.composeMsg,
                // Bus mode (batched, lower fee) has delivery latency - only sent when bus is full or driven
                oftCmd: s.mode == 1 ? abi.encodePacked(uint8(1)) : bytes("")
            });

            IStargate.MessagingFee memory messagingFee =
                IStargate.MessagingFee({ nativeFee: s.lzNativeFee, lzTokenFee: 0 });

            // Pay in native ETH: value = lzNativeFee + amountLD
            executions = new Execution[](1);
            executions[0] = Execution({
                target: s.stargatePool,
                value: s.lzNativeFee + s.amountLD,
                callData: abi.encodeCall(IStargate.sendToken, (sendParam, messagingFee, account))
            });
        } else {
            // OFT mode (mode=2)
            // CRITICAL: value = lzNativeFee ONLY. OFT contracts burn tokens from msg.sender internally.
            IOFT.SendParam memory sendParam = IOFT.SendParam({
                dstEid: s.dstEid,
                to: s.to,
                amountLD: s.amountLD,
                minAmountLD: s.minAmountLD,
                extraOptions: s.extraOptions,
                composeMsg: s.composeMsg,
                oftCmd: bytes("")
            });

            IOFT.MessagingFee memory messagingFee =
                IOFT.MessagingFee({ nativeFee: s.lzNativeFee, lzTokenFee: 0 });

            executions = new Execution[](1);
            executions[0] = Execution({
                target: s.stargatePool,
                value: s.lzNativeFee,
                callData: abi.encodeCall(IOFT.send, (sendParam, messagingFee, account))
            });
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory) external pure override returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
    }

    /// @dev This hook implements ISuperHookInflowOutflow + ISuperHookOutflow
    function _supportsSizingInterface() internal pure override returns (bool) {
        return true;
    }

    /// @inheritdoc ISuperHookOutflow
    function replaceCalldataAmounts(
        bytes memory data,
        uint256[] memory amounts
    )
        external
        pure
        override
        returns (bytes memory)
    {
        if (amounts.length != 1) revert INVALID_AMOUNTS_LENGTH();
        return _replaceCalldataAmount(data, amounts[0], AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(
            BytesLib.toAddress(data, 84), // stargatePool
            BytesLib.toAddress(data, 104), // inputToken
            address(uint160(uint256(BytesLib.toBytes32(data, 128)))) // to (as address)
        );
    }
}
