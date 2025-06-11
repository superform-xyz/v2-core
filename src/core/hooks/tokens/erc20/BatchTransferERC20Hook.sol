// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import {BytesLib} from "../../../../vendor/BytesLib.sol";
import {Execution} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import {BaseHook} from "../../BaseHook.sol";
import {HookSubTypes} from "../../../libraries/HookSubTypes.sol";
import {ISuperHookInspector} from "../../../interfaces/ISuperHook.sol";

/// @title BatchTransferERC20Hook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address to = BytesLib.toAddress(data, 0);
/// @notice         bytes tokensArr = BytesLib.slice(data, 20, data.length - 20);
contract BatchTransferERC20Hook is BaseHook, ISuperHookInspector {
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 52;

    error LENGTH_MISMATCH();

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.TOKEN) {}

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    function _buildHookExecutions(address, address, bytes calldata data)
        internal
        pure
        override
        returns (Execution[] memory executions)
    {
        address to = BytesLib.toAddress(data, 0);
        bytes memory tokensData = BytesLib.slice(data, 20, data.length - 20);

        (address[] memory tokens, uint256[] memory amounts) = abi.decode(tokensData, (address[], uint256[]));

        uint256 tokensLen = tokens.length;
        if (tokensLen != amounts.length) revert LENGTH_MISMATCH();

        executions = new Execution[](tokensLen);
        for (uint i; i < tokensLen; i++) {
            executions[i] = Execution({target: tokens[i], value: 0, callData: abi.encodeCall(IERC20.transfer, (to, amounts[i]))});
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure returns (bytes memory) {
        bytes memory tokensData = BytesLib.slice(data, 53, data.length - 53);
        (address[] memory tokens,) = abi.decode(tokensData, (address[], uint256[]));
        
        bytes memory result = abi.encodePacked(
            BytesLib.toAddress(data, 0) //to
        );

        uint256 tokensLen = tokens.length;
        for (uint i; i < tokensLen; i++) {
            result = abi.encodePacked(result, tokens[i]);
        }

        return result;
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address, bytes calldata data) internal override {}

    function _postExecute(address, address, bytes calldata data) internal override {}
}
