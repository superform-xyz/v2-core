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

/// @title StargateSendHook
/// @author Superform Labs
/// @dev Sends native tokens cross-chain via Stargate V2 with optional destination execution
/// @dev For native sends: msg.value = lzNativeFee + amountLD
/// @dev Supports paying LZ messaging fee in native ETH or LZ token (set lzTokenFee > 0 and provide lzToken address)
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
contract StargateSendHook is BaseHook, ISuperHookContextAware {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address private immutable VALIDATOR;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 224;

    struct StargateSendData {
        uint256 lzNativeFee;
        uint256 lzTokenFee;
        address stargatePool;
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

    /// @notice Thrown when the Stargate pool address is invalid or not a legitimate Stargate pool
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
        s.lzToken = BytesLib.toAddress(data, 104);
        s.dstEid = BytesLib.toUint32(data, 124);
        s.to = BytesLib.toBytes32(data, 128);
        s.amountLD = BytesLib.toUint256(data, 160);
        s.minAmountLD = BytesLib.toUint256(data, 192);
        s.isBusMode = _decodeBool(data, 225);

        // Fail-fast validation on fixed fields before external calls
        if (s.stargatePool == address(0)) revert POOL_NOT_VALID();
        if (s.to == bytes32(0)) revert ADDRESS_NOT_VALID();
        if (s.lzTokenFee > 0 && s.lzToken == address(0)) revert ADDRESS_NOT_VALID();

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

        // Build SendParam
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

        IStargate.MessagingFee memory messagingFee =
            IStargate.MessagingFee({ nativeFee: s.lzNativeFee, lzTokenFee: s.lzTokenFee });

        // Build executions based on fee payment method
        if (s.lzTokenFee > 0) {
            // Pay in LZ token: approve LZ token to pool, then sendToken, then cleanup
            executions = new Execution[](4);

            // Execution 0: Reset LZ token approval to 0
            executions[0] = Execution({
                target: s.lzToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (s.stargatePool, 0))
            });

            // Execution 1: Approve LZ token fee amount
            executions[1] = Execution({
                target: s.lzToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (s.stargatePool, s.lzTokenFee))
            });

            // Execution 2: Bridge call (value = amountLD for native token transfer)
            executions[2] = Execution({
                target: s.stargatePool,
                value: s.lzNativeFee + s.amountLD,
                callData: abi.encodeCall(IStargate.sendToken, (sendParam, messagingFee, account))
            });

            // Execution 3: Cleanup LZ token approval to 0
            executions[3] = Execution({
                target: s.lzToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (s.stargatePool, 0))
            });
        } else {
            // Pay in native ETH: value = lzNativeFee + amountLD
            executions = new Execution[](1);
            executions[0] = Execution({
                target: s.stargatePool,
                value: s.lzNativeFee + s.amountLD,
                callData: abi.encodeCall(IStargate.sendToken, (sendParam, messagingFee, account))
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
            BytesLib.toAddress(data, 64), // stargatePool
            BytesLib.toAddress(data, 84), // inputToken
            address(uint160(uint256(BytesLib.toBytes32(data, 128)))) // to (as address)
        );
    }
}
