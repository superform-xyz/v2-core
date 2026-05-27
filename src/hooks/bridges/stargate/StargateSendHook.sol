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
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title StargateSendHook
/// @author Superform Labs
/// @dev Sends native tokens cross-chain via Stargate V2 with optional destination execution
/// @dev For native sends: msg.value = lzNativeFee + amountLD
/// @dev LZ messaging fee is always paid in native ETH (lzTokenFee is hardcoded to 0)
/// @dev WARNING: refundAddress is set to the account. If the native fee is overestimated, Stargate synchronously
/// @dev refunds the excess to the account during sendToken. ERC7579/7702 accounts with non-payable fallbacks or
/// @dev fallbacks that reenter the executor will cause sendToken to revert (liveness DoS, no fund loss).
/// @dev `composeMsg` field won't contain the signature for the destination executor
/// @dev      signature is retrieved from the validator contract transient storage
/// @dev      This is needed to avoid circular dependency between merkle root which contains the signature needed to
/// sign it
/// @dev data has the following structure
/// @notice         uint256 lzNativeFee = BytesLib.toUint256(data, 0);
/// @notice         address stargatePool = BytesLib.toAddress(data, 32);
/// @notice         address inputToken = BytesLib.toAddress(data, 52);
/// @notice         uint32 dstEid = BytesLib.toUint32(data, 72);
/// @notice         bytes32 to = BytesLib.toBytes32(data, 76);
/// @notice         uint256 amountLD = BytesLib.toUint256(data, 108);
/// @notice         uint256 minAmountLD = BytesLib.toUint256(data, 140);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 172);
/// @notice         uint8 mode = uint8(data[173]);
/// @notice         uint256 extraOptionsLength = BytesLib.toUint256(data, 174);
/// @notice         bytes extraOptions = BytesLib.slice(data, 206, extraOptionsLength);
/// @notice         uint256 composeMsgLength = BytesLib.toUint256(data, 206 + extraOptionsLength);
/// @notice         bytes composeMsg = BytesLib.slice(data, 238 + extraOptionsLength, composeMsgLength);
contract StargateSendHook is BaseHook, ISuperHookContextAware {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address private immutable VALIDATOR;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 172;

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
        if (data.length < 238) revert DATA_NOT_VALID();

        StargateSendData memory s;
        s.lzNativeFee = BytesLib.toUint256(data, 0);
        s.stargatePool = BytesLib.toAddress(data, 32);
        s.dstEid = BytesLib.toUint32(data, 72);
        s.to = BytesLib.toBytes32(data, 76);
        s.amountLD = BytesLib.toUint256(data, 108);
        s.minAmountLD = BytesLib.toUint256(data, 140);
        s.mode = uint8(data[173]);
        if (s.mode > 2) revert MODE_NOT_VALID();

        // Fail-fast validation on fixed fields before external calls
        if (s.stargatePool == address(0)) revert POOL_NOT_VALID();
        if (s.to == bytes32(0)) revert ADDRESS_NOT_VALID();
        if (s.to != bytes32(uint256(uint160(account)))) revert ADDRESS_NOT_VALID();

        // Verify pool implements IStargate interface (reverts on non-pool addresses)
        IStargate(s.stargatePool).token();

        // Validate variable-length field bounds
        uint256 extraOptionsLength = BytesLib.toUint256(data, 174);
        if (data.length < 238 + extraOptionsLength) revert DATA_NOT_VALID();
        s.extraOptions = BytesLib.slice(data, 206, extraOptionsLength);

        uint256 composeMsgOffset = 206 + extraOptionsLength;
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

        // Append signature to composeMsg if present
        if (s.composeMsg.length > 0) {
            // Minimum ABI-encoded size for (bytes, bytes, address, address[], uint256[])
            if (s.composeMsg.length < 160) revert DATA_NOT_VALID();

            bytes memory signature = ISuperSignatureStorage(VALIDATOR).retrieveSignatureData(account);

            (
                bytes memory initData,
                bytes memory executorCalldata,
                address _account,
                address[] memory dstTokens,
                uint256[] memory intentAmounts
            ) = abi.decode(s.composeMsg, (bytes, bytes, address, address[], uint256[]));

            if (_account != account) revert ADDRESS_NOT_VALID();

            s.composeMsg = abi.encode(initData, executorCalldata, _account, dstTokens, intentAmounts, signature);
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
            // Sending amountLD in msg.value to an OFT contract risks permanent ETH loss.
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

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(
            BytesLib.toAddress(data, 32), // stargatePool
            BytesLib.toAddress(data, 52), // inputToken
            address(uint160(uint256(BytesLib.toBytes32(data, 76)))) // to (as address)
        );
    }
}
