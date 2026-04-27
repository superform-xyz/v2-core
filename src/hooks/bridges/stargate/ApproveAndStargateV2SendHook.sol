// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IOFT, SendParam, MessagingFee } from "../../../vendor/bridges/stargate/IOFT.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperSignatureStorage } from "../../../interfaces/ISuperSignatureStorage.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title ApproveAndStargateV2SendHook
/// @author Superform Labs
/// @dev ERC20-only version with approval pattern: approve(0)->approve(amount)->send->approve(0)
/// @dev For native token transfers, use StargateV2SendHook instead
/// @dev The OFT contract address is passed in calldata, making this hook generic for any Stargate OFT
/// @dev amountLD and minAmountLD have to be predicted by the SuperBundler
/// @dev nativeFee and lzTokenFee must be pre-quoted via quoteSend()
/// @dev `composeMsg` field won't contain the signature for the destination executor
/// @dev      signature is retrieved from the validator contract transient storage
/// @dev This hook adds approval pattern (approve 0 → approve amount → execute → approve 0) to the bridge operation
/// @dev data has the following structure
/// @notice         address oftContract = BytesLib.toAddress(data, 0);
/// @notice         uint256 value = BytesLib.toUint256(data, 20);
/// @notice         uint32 dstEid = BytesLib.toUint32(data, 52);
/// @notice         bytes32 to = BytesLib.toBytes32(data, 56);
/// @notice         uint256 amountLD = BytesLib.toUint256(data, 88);
/// @notice         uint256 minAmountLD = BytesLib.toUint256(data, 120);
/// @notice         uint256 nativeFee = BytesLib.toUint256(data, 152);
/// @notice         uint256 lzTokenFee = BytesLib.toUint256(data, 184);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 216);
/// @notice         bytes extraOptions = [variable, starting at 217]
/// @notice         bytes composeMsg = [variable, after extraOptions]
/// @notice         bytes oftCmd = [variable, after composeMsg]
contract ApproveAndStargateV2SendHook is BaseHook, ISuperHookContextAware {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address private immutable VALIDATOR;
    uint256 private constant OFT_ADDRESS_SIZE = 20;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 216;
    uint256 private constant MIN_DATA_LENGTH = 217;
    /// @dev Minimum ABI-encoded head size for composeMsg: 5 dynamic type offset pointers (5 * 32)
    uint256 private constant MIN_COMPOSE_MSG_LENGTH = 160;

    struct StargateV2SendData {
        address oftContract;
        uint256 value;
        uint32 dstEid;
        bytes32 to;
        uint256 amountLD;
        uint256 minAmountLD;
        uint256 nativeFee;
        uint256 lzTokenFee;
        bool usePrevHookAmount;
        bytes extraOptions;
        bytes composeMsg;
        bytes oftCmd;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error DATA_NOT_VALID();

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
        if (data.length < MIN_DATA_LENGTH) revert DATA_NOT_VALID();

        StargateV2SendData memory d;
        d.oftContract = BytesLib.toAddress(data, 0);
        d.value = BytesLib.toUint256(data, 20);
        d.dstEid = BytesLib.toUint32(data, 52);
        d.to = BytesLib.toBytes32(data, 56);
        d.amountLD = BytesLib.toUint256(data, 88);
        d.minAmountLD = BytesLib.toUint256(data, 120);
        d.nativeFee = BytesLib.toUint256(data, 152);
        d.lzTokenFee = BytesLib.toUint256(data, 184);
        d.usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        // Decode variable-length fields
        {
            uint256 offset = MIN_DATA_LENGTH;
            (d.extraOptions, offset) = _decodeBytes(data, offset);
            (d.composeMsg, offset) = _decodeBytes(data, offset);
            (d.oftCmd,) = _decodeBytes(data, offset);
        }

        if (d.oftContract == address(0)) revert ADDRESS_NOT_VALID();

        // Handle usePrevHookAmount
        // @dev `value` is not adjusted here; this hook is ERC20-only so `value` represents only LayerZero messaging
        //      fees, not the bridged amount. The SuperBundler must ensure `value` is correct.
        // @dev `minAmountLD` must be pre-computed by the SuperBundler to account for LayerZero OFT dust removal
        //      (decimal truncation via _removeDust in OFTCore)
        if (d.usePrevHookAmount) {
            uint256 outAmount = ISuperHookResult(prevHook).getOutAmount(account);

            if (d.amountLD > 0 && d.minAmountLD > 0) {
                d.minAmountLD = Math.mulDiv(d.minAmountLD, outAmount, d.amountLD);
            } else {
                d.minAmountLD = 0;
            }

            d.amountLD = outAmount;
        }

        if (d.amountLD == 0) revert AMOUNT_NOT_VALID();
        if (d.to == bytes32(0)) revert ADDRESS_NOT_VALID();

        // Append signature to composeMsg if present
        if (d.composeMsg.length > 0) {
            d.composeMsg = _appendSignature(d.composeMsg, account);
        }

        address inputToken = IOFT(d.oftContract).token();

        // Always use approve pattern for ERC20 tokens: approve 0 → approve amount → execute → approve 0
        executions = new Execution[](4);

        // Execution 0: Reset approval to 0 (prevents approval race conditions)
        executions[0] = Execution({
            target: inputToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (d.oftContract, 0))
        });

        // Execution 1: Approve exact amount
        executions[1] = Execution({
            target: inputToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (d.oftContract, d.amountLD))
        });

        // Execution 2: Bridge call
        executions[2] = _buildBridgeExecution(d, account);

        // Execution 3: Cleanup approval to 0
        executions[3] = Execution({
            target: inputToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (d.oftContract, 0))
        });
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
        return abi.encodePacked(BytesLib.toAddress(data, 0));
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds the bridge execution call to the OFT contract
    function _buildBridgeExecution(
        StargateV2SendData memory d,
        address account
    )
        private
        pure
        returns (Execution memory)
    {
        return Execution({
            target: d.oftContract,
            value: d.value,
            callData: abi.encodeCall(
                IOFT.send,
                (
                    SendParam({
                        dstEid: d.dstEid,
                        to: d.to,
                        amountLD: d.amountLD,
                        minAmountLD: d.minAmountLD,
                        extraOptions: d.extraOptions,
                        composeMsg: d.composeMsg,
                        oftCmd: d.oftCmd
                    }),
                    MessagingFee({ nativeFee: d.nativeFee, lzTokenFee: d.lzTokenFee }),
                    account
                )
            )
        });
    }

    /// @dev Appends signature from VALIDATOR to composeMsg
    function _appendSignature(bytes memory composeMsg, address account) private view returns (bytes memory) {
        if (composeMsg.length < MIN_COMPOSE_MSG_LENGTH) revert DATA_NOT_VALID();
        bytes memory signature = ISuperSignatureStorage(VALIDATOR).retrieveSignatureData(account);
        (
            bytes memory initData,
            bytes memory executorCalldata,
            address _account,
            address[] memory dstTokens,
            uint256[] memory intentAmounts
        ) = abi.decode(composeMsg, (bytes, bytes, address, address[], uint256[]));
        return abi.encode(initData, executorCalldata, _account, dstTokens, intentAmounts, signature);
    }

    /// @dev Decodes a length-prefixed bytes field from calldata
    function _decodeBytes(
        bytes calldata data,
        uint256 offset
    )
        private
        pure
        returns (bytes memory result, uint256 newOffset)
    {
        uint256 len = BytesLib.toUint256(data, offset);
        offset += 32;
        if (len > 0) {
            result = BytesLib.slice(data, offset, len);
        } else {
            result = "";
        }
        newOffset = offset + len;
    }
}
