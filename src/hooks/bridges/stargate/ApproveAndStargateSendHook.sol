// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IStargate } from "../../../vendor/bridges/stargate/IStargate.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperSignatureStorage } from "../../../interfaces/ISuperSignatureStorage.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title ApproveAndStargateSendHook
/// @author Superform Labs
/// @dev ERC20-only version of StargateSendHook with approval pattern
/// @dev For ERC20 sends: msg.value = lzNativeFee only (tokens pulled via approve)
/// @dev Supports paying LZ messaging fee in native ETH or LZ token (ZRO)
/// @dev When lzTokenFee > 0: approves lzToken to the pool (pool pulls via safeTransferFrom to endpoint)
/// @dev This hook adds approval pattern (approve 0 -> approve amount -> execute -> approve 0) to the bridge operation
/// @dev For native token transfers, use StargateSendHook instead
/// @dev WARNING: refundAddress is set to the account. If the native fee is overestimated, Stargate synchronously
/// @dev refunds the excess to the account during sendToken. ERC7579/7702 accounts with non-payable fallbacks or
/// @dev fallbacks that reenter the executor will cause sendToken to revert (liveness DoS, no fund loss).
/// @dev `composeMsg` field won't contain the signature for the destination executor
/// @dev      signature is retrieved from the validator contract transient storage
/// @dev      This is needed to avoid circular dependency between merkle root which contains the signature needed to
/// sign it
/// @dev data has the following structure
/// @notice         uint256 lzNativeFee = BytesLib.toUint256(data, 0);
/// @notice         uint256 lzTokenFee = BytesLib.toUint256(data, 32);
/// @notice         address stargatePool = BytesLib.toAddress(data, 64);
/// @notice         address inputToken = BytesLib.toAddress(data, 84);
/// @notice         address lzToken = BytesLib.toAddress(data, 104);
/// @notice         uint32 dstEid = BytesLib.toUint32(data, 124);
/// @notice         bytes32 to = BytesLib.toBytes32(data, 128);
/// @notice         uint256 amountLD = BytesLib.toUint256(data, 160);
/// @notice         uint256 minAmountLD = BytesLib.toUint256(data, 192);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 224);
/// @notice         bool isBusMode = _decodeBool(data, 225);
/// @notice         uint256 extraOptionsLength = BytesLib.toUint256(data, 226);
/// @notice         bytes extraOptions = BytesLib.slice(data, 258, extraOptionsLength);
/// @notice         uint256 composeMsgLength = BytesLib.toUint256(data, 258 + extraOptionsLength);
/// @notice         bytes composeMsg = BytesLib.slice(data, 290 + extraOptionsLength, composeMsgLength);
contract ApproveAndStargateSendHook is BaseHook, ISuperHookContextAware {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address private immutable VALIDATOR;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 224;

    struct StargateSendData {
        uint256 lzNativeFee;
        uint256 lzTokenFee;
        address stargatePool;
        address inputToken;
        address lzToken;
        uint32 dstEid;
        bytes32 to;
        uint256 amountLD;
        uint256 minAmountLD;
        bool isBusMode;
        bytes extraOptions;
        bytes composeMsg;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the input data length is less than the minimum required or variable fields exceed bounds
    error DATA_NOT_VALID();

    /// @notice Thrown when the Stargate pool address is invalid or does not match the input token
    error POOL_NOT_VALID();

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
        if (data.length < 290) revert DATA_NOT_VALID();

        StargateSendData memory s;
        s.lzNativeFee = BytesLib.toUint256(data, 0);
        s.lzTokenFee = BytesLib.toUint256(data, 32);
        s.stargatePool = BytesLib.toAddress(data, 64);
        s.inputToken = BytesLib.toAddress(data, 84);
        s.lzToken = BytesLib.toAddress(data, 104);
        s.dstEid = BytesLib.toUint32(data, 124);
        s.to = BytesLib.toBytes32(data, 128);
        s.amountLD = BytesLib.toUint256(data, 160);
        s.minAmountLD = BytesLib.toUint256(data, 192);
        s.isBusMode = _decodeBool(data, 225);

        // Fail-fast validation on fixed fields before external calls
        if (s.stargatePool == address(0)) revert POOL_NOT_VALID();
        if (s.inputToken == address(0)) revert ADDRESS_NOT_VALID();
        if (s.to == bytes32(0)) revert ADDRESS_NOT_VALID();
        if (s.lzTokenFee > 0 && s.lzToken == address(0)) revert ADDRESS_NOT_VALID();

        // Verify pool is a legitimate Stargate pool and matches the input token
        if (IStargate(s.stargatePool).token() != s.inputToken) revert POOL_NOT_VALID();

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

            s.composeMsg = abi.encode(initData, executorCalldata, _account, dstTokens, intentAmounts, signature);
        }

        // Build executions
        executions = _buildExecutions(s, account);
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
            BytesLib.toAddress(data, 64), // stargatePool
            BytesLib.toAddress(data, 84), // inputToken
            address(uint160(uint256(BytesLib.toBytes32(data, 128)))) // to (as address)
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds execution calls with approval pattern
    /// @dev lzTokenFee == 0: approve(0) -> approve(amount) -> sendToken -> approve(0) [4 executions]
    /// @dev lzTokenFee > 0 && inputToken == lzToken: combined approval for amountLD + lzTokenFee [4 executions]
    /// @dev lzTokenFee > 0 && inputToken != lzToken: separate approvals [7 executions]
    function _buildExecutions(
        StargateSendData memory s,
        address account
    )
        private
        pure
        returns (Execution[] memory executions)
    {
        IStargate.SendParam memory sendParam = IStargate.SendParam({
            dstEid: s.dstEid,
            to: s.to,
            amountLD: s.amountLD,
            minAmountLD: s.minAmountLD,
            extraOptions: s.extraOptions,
            composeMsg: s.composeMsg,
            // Bus mode (batched, lower fee) has delivery latency - only sent when bus is full or driven
            oftCmd: s.isBusMode ? abi.encodePacked(uint8(1)) : bytes("")
        });

        if (s.lzTokenFee > 0) {
            IStargate.MessagingFee memory messagingFee =
                IStargate.MessagingFee({ nativeFee: s.lzNativeFee, lzTokenFee: s.lzTokenFee });

            if (s.inputToken == s.lzToken) {
                // Same token for bridge amount and LZ fee: combine into single approval
                // Pool pulls amountLD (for bridging) + lzTokenFee (forwarded to LZ endpoint)
                uint256 combinedAmount = s.amountLD + s.lzTokenFee;

                executions = new Execution[](4);
                executions[0] = Execution({
                    target: s.inputToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, 0))
                });
                executions[1] = Execution({
                    target: s.inputToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, combinedAmount))
                });
                executions[2] = Execution({
                    target: s.stargatePool,
                    value: s.lzNativeFee,
                    callData: abi.encodeCall(IStargate.sendToken, (sendParam, messagingFee, account))
                });
                executions[3] = Execution({
                    target: s.inputToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, 0))
                });
            } else {
                // Different tokens: separate approval sequences (7 executions)
                executions = new Execution[](7);

                // Input token approval
                executions[0] = Execution({
                    target: s.inputToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, 0))
                });
                executions[1] = Execution({
                    target: s.inputToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, s.amountLD))
                });

                // LZ token approval (pool pulls via safeTransferFrom to endpoint)
                executions[2] = Execution({
                    target: s.lzToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, 0))
                });
                executions[3] = Execution({
                    target: s.lzToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, s.lzTokenFee))
                });

                // Bridge call (value = lzNativeFee only for ERC20)
                executions[4] = Execution({
                    target: s.stargatePool,
                    value: s.lzNativeFee,
                    callData: abi.encodeCall(IStargate.sendToken, (sendParam, messagingFee, account))
                });

                // Cleanup LZ token approval
                executions[5] = Execution({
                    target: s.lzToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, 0))
                });

                // Cleanup input token approval
                executions[6] = Execution({
                    target: s.inputToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, 0))
                });
            }
        } else {
            IStargate.MessagingFee memory messagingFee =
                IStargate.MessagingFee({ nativeFee: s.lzNativeFee, lzTokenFee: 0 });

            // ERC20 only: 4 executions
            executions = new Execution[](4);

            // Execution 0: Reset approval to 0 (prevents approval race conditions)
            executions[0] = Execution({
                target: s.inputToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (s.stargatePool, 0))
            });

            // Execution 1: Approve exact amount
            executions[1] = Execution({
                target: s.inputToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (s.stargatePool, s.amountLD))
            });

            // Execution 2: Bridge call (value = lzNativeFee only for ERC20)
            executions[2] = Execution({
                target: s.stargatePool,
                value: s.lzNativeFee,
                callData: abi.encodeCall(IStargate.sendToken, (sendParam, messagingFee, account))
            });

            // Execution 3: Cleanup approval to 0
            executions[3] = Execution({
                target: s.inputToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (s.stargatePool, 0))
            });
        }
    }
}
