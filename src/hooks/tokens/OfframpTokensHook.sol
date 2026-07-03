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
import { LibSort } from "solady/utils/LibSort.sol";

address constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

/// @title OfframpTokensHook
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         uint256 placeholder0 = BytesLib.toUint256(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address to = BytesLib.toAddress(data, 52);
/// @notice         bytes tokensArr = BytesLib.slice(data, 72, data.length - 72);
contract OfframpTokensHook is BaseHook, ISuperHookInflowOutflow {
    using LibSort for address[];

    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 52;

    error LENGTH_MISMATCH();

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.TOKEN) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Offramp Tokens";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Offramps tokens for fiat withdrawal";
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
        address to = BytesLib.toAddress(data, 52);
        bytes memory tokensData = BytesLib.slice(data, 72, data.length - 72);

        (address[] memory tokens) = abi.decode(tokensData, (address[]));

        // make sure tokens are sorted and unique
        tokens.insertionSort();
        tokens.uniquifySorted();

        uint256 tokensLen = tokens.length;
        uint256 executionIndex;
        executions = new Execution[](tokensLen);

        for (uint256 i; i < tokensLen; ++i) {
            address _token = tokens[i];
            uint256 balance = _token == NATIVE_TOKEN ? account.balance : IERC20(_token).balanceOf(account);

            if (balance == 0) continue;
            
            if (_token == NATIVE_TOKEN) {
                // For native token, send ETH directly to the recipient
                executions[executionIndex] = Execution({ target: to, value: balance, callData: "" });
            } else {
                // For ERC20 tokens, use the standard transfer
                executions[executionIndex] = Execution({
                    target: _token,
                    value: 0,
                    callData: abi.encodeCall(IERC20.transfer, (to, balance))
                });
            }

            executionIndex++;
        }

        assembly ("memory-safe") {
            mstore(executions, executionIndex)
        } 
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(BytesLib.toAddress(data, 52)); //to
    }

    /// @inheritdoc ISuperHookInflowOutflow
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

}
