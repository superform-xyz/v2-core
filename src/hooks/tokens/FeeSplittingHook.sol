// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { HookSubTypes } from "../../libraries/HookSubTypes.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../interfaces/ISuperHook.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title FeeSplittingHook
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         bytes transfersArr = BytesLib.slice(data, 52, data.length - 52);
/// @notice         // transfersArr = abi.encode(address[] tokens, uint256[] amounts, address[] receivers)
contract FeeSplittingHook is BaseHook, ISuperHookInflowOutflow {
    /// @notice Thrown when tokens, amounts and receivers arrays have different lengths
    error LENGTH_MISMATCH();

    /// @notice Thrown when the number of transfers exceeds MAX_TRANSFERS
    error TOO_MANY_TRANSFERS();

    /// @notice Thrown when the hook data is too short to contain the strategy header and transfers payload
    error INVALID_DATA_LENGTH();

    /// @notice Maximum number of transfers in a single split
    uint256 public constant MAX_TRANSFERS = 50;

    /// @dev This is not a constant because some chains have different representations for the native token
    ///      https://github.com/d-xo/weird-erc20?tab=readme-ov-file#erc-20-representation-of-native-currency
    address public immutable NATIVE_TOKEN;

    constructor(address _nativeToken) BaseHook(HookType.NONACCOUNTING, HookSubTypes.TOKEN) {
        NATIVE_TOKEN = _nativeToken;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Fee Splitting";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Transfers multiple tokens to multiple recipients pairwise in a single call";
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    function _buildHookExecutions(
        address,
        address,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        (address[] memory tokens, uint256[] memory amounts, address[] memory receivers) = _decodeTransfers(data);

        uint256 tokensLen = tokens.length;
        executions = new Execution[](tokensLen);
        for (uint256 i; i < tokensLen; i++) {
            if (receivers[i] == address(0)) revert ADDRESS_NOT_VALID();
            if (amounts[i] == 0) revert AMOUNT_NOT_VALID();
            if (tokens[i] == NATIVE_TOKEN) {
                // For native token, send ETH directly to the recipient
                executions[i] = Execution({ target: receivers[i], value: amounts[i], callData: "" });
            } else {
                // Calls to codeless targets succeed with empty returndata, silently skipping the fee
                if (tokens[i].code.length == 0) revert ADDRESS_NOT_VALID();
                // For ERC20 tokens, use the standard transfer
                executions[i] = Execution({
                    target: tokens[i],
                    value: 0,
                    callData: abi.encodeCall(IERC20.transfer, (receivers[i], amounts[i]))
                });
            }
        }
    }

    /// @dev Decodes and validates the transfers payload; shared by build and inspect so a payload
    ///      that inspects cleanly can never revert on structural validation at execution time
    function _decodeTransfers(bytes calldata data)
        private
        pure
        returns (address[] memory tokens, uint256[] memory amounts, address[] memory receivers)
    {
        if (data.length <= 52) revert INVALID_DATA_LENGTH();
        bytes memory transfersData = BytesLib.slice(data, 52, data.length - 52);

        (tokens, amounts, receivers) = abi.decode(transfersData, (address[], uint256[], address[]));

        uint256 tokensLen = tokens.length;
        if (tokensLen != amounts.length || tokensLen != receivers.length) revert LENGTH_MISMATCH();
        if (tokensLen > MAX_TRANSFERS) revert TOO_MANY_TRANSFERS();
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev Sizeless — variable-length amounts[] in ABI-encoded data
    function decodeAmounts(bytes memory) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](0);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory) external pure override returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](0);
    }

    /// @inheritdoc IERC165
    /// @dev S2: implements ISuperHookInflowOutflow (decode-only) but NOT ISuperHookOutflow
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        if (interfaceId == type(ISuperHookInflowOutflow).interfaceId) return true;
        if (interfaceId == type(ISuperHookOutflow).interfaceId) return false;
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(ISuperHook).interfaceId
            || interfaceId == type(ISuperHookResult).interfaceId
            || interfaceId == type(ISuperHookInspector).interfaceId;
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        (,, address[] memory receivers) = _decodeTransfers(data);

        uint256 receiversLen = receivers.length;
        bytes memory out;
        for (uint256 i; i < receiversLen; i++) {
            out = abi.encodePacked(out, receivers[i]);
        }
        return out;
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Side-effect-only hook: forwards the previous hook's outAmount/outToken so a
    ///      downstream hook using usePrevHookAmount is not fed 0 after a mid-chain fee split
    function _pipeMode() internal pure override returns (PipeMode) {
        return PipeMode.PASSTHROUGH;
    }
}
