// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC7540 } from "../../../../vendor/vaults/7540/IERC7540.sol";

// Superform
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInflowOutflow,
    ISuperHookNonAccounting
} from "../../../interfaces/ISuperHook.sol";
import { BaseHook } from "../../BaseHook.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title ApproveAndRequestDeposit7540VaultHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes4 yieldSourceOracleId = bytes4(BytesLib.slice(data, 0, 4), 0);
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 4, 20), 0);
/// @notice         address token = BytesLib.toAddress(BytesLib.slice(data, 24, 20), 0);
/// @notice         uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 44, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 76);
contract ApproveAndRequestDeposit7540VaultHook is
    BaseHook,
    ISuperHook,
    ISuperHookInflowOutflow,
    ISuperHookNonAccounting
{
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 44;

    constructor(address registry_, address author_) BaseHook(registry_, author_, HookType.NONACCOUNTING) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(
        address prevHook,
        address account,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        address yieldSource = data.extractYieldSource();
        address token = BytesLib.toAddress(BytesLib.slice(data, 24, 20), 0);
        uint256 amount = _decodeAmount(data);
        bool usePrevHookAmount = _decodeBool(data, 76);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).outAmount();
        }

        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (yieldSource == address(0) || account == address(0) || token == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](4);
        executions[0] =
            Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (yieldSource, 0)) });
        executions[1] =
            Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (yieldSource, amount)) });
        executions[2] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IERC7540.requestDeposit, (amount, account, account))
        });
        executions[3] =
            Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (yieldSource, 0)) });
    }

    /// @inheritdoc ISuperHookNonAccounting
    /// @return outAmount The amount of assets or shares processed by the hook
    /// @return isShares Whether the amount is in shares
    function getUsedAssetsOrShares() external view returns (uint256, bool isShares) {
        return (outAmount, false);
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, address, bytes memory) external view { }

    /// @inheritdoc ISuperHook
    function postExecute(address, address, bytes memory) external view { }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmount(bytes memory data) external pure returns (uint256) {
        return _decodeAmount(data);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeAmount(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(BytesLib.slice(data, AMOUNT_POSITION, 32), 0);
    }
}
