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

/// @title BatchTransferHook
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         uint256 placeholder0 = BytesLib.toUint256(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address to = BytesLib.toAddress(data, 52);
/// @notice         bytes tokensArr = BytesLib.slice(data, 72, data.length - 72);
contract BatchTransferHook is BaseHook, ISuperHookInflowOutflow {
    error LENGTH_MISMATCH();

    /// @dev This is not a constant because some chains have different representations for the native token
    ///      https://github.com/d-xo/weird-erc20?tab=readme-ov-file#erc-20-representation-of-native-currency
    address public immutable NATIVE_TOKEN;

    constructor(address _nativeToken) BaseHook(HookType.NONACCOUNTING, HookSubTypes.TOKEN) {
        NATIVE_TOKEN = _nativeToken;
     }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Batch Transfer";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Transfers tokens to multiple recipients in a single call";
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
        address to = BytesLib.toAddress(data, 52);
        bytes memory tokensData = BytesLib.slice(data, 72, data.length - 72);

        (address[] memory tokens, uint256[] memory amounts) = abi.decode(tokensData, (address[], uint256[]));

        uint256 tokensLen = tokens.length;
        if (tokensLen != amounts.length) revert LENGTH_MISMATCH();

        executions = new Execution[](tokensLen);
        for (uint256 i; i < tokensLen; i++) {
            if (tokens[i] == NATIVE_TOKEN) {
                // For native token, send ETH directly to the recipient
                executions[i] = Execution({ target: to, value: amounts[i], callData: "" });
            } else {
                // For ERC20 tokens, use the standard transfer
                executions[i] = Execution({
                    target: tokens[i],
                    value: 0,
                    callData: abi.encodeCall(IERC20.transfer, (to, amounts[i]))
                });
            }
        }
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
        return abi.encodePacked(BytesLib.toAddress(data, 52)); //to
    }
}
