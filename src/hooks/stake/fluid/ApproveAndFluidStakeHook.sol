// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IFluidLendingStakingRewards } from "../../../vendor/fluid/IFluidLendingStakingRewards.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHookContextAware, ISuperHookResult, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title ApproveAndFluidStakeHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes32 yieldSourceOracleId = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 32);
/// @notice         address token = BytesLib.toAddress(data, 52);
/// @notice         uint256 amount = BytesLib.toUint256(data, 72);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 104);
contract ApproveAndFluidStakeHook is BaseHook, ISuperHookContextAware {
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 72;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 104;

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.STAKE) { }

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
        address yieldSource = data.extractYieldSource();
        address token = BytesLib.toAddress(data, 52);
        uint256 amount = _decodeAmount(data);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (yieldSource == address(0) || token == address(0)) revert ADDRESS_NOT_VALID();

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).getOutAmount(account);
        }
        if (amount == 0) revert AMOUNT_NOT_VALID();

        executions = new Execution[](4);
        executions[0] =
            Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (yieldSource, 0)) });
        executions[1] =
            Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (yieldSource, amount)) });
        executions[2] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IFluidLendingStakingRewards.stake, (amount))
        });
        executions[3] =
            Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (yieldSource, 0)) });
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
            data.extractYieldSource(),
            BytesLib.toAddress(data, 52) //token
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data), account);
        /// @dev in Fluid, the share token doesn't exist because no shares are minted so we don't assign a spToken
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data) - getOutAmount(account), account);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeAmount(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        return IFluidLendingStakingRewards(data.extractYieldSource()).balanceOf(account);
    }
}
