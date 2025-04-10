// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { ISuperHookResult, ISuperHookInflowOutflow, ISuperHookContextAware } from "../../../interfaces/ISuperHook.sol";
import { IGearboxFarmingPool } from "../../../../vendor/gearbox/IGearboxFarmingPool.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title ApproveAndGearboxStakeHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes4 yieldSourceOracleId = bytes4(BytesLib.slice(data, 0, 4), 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 4);
/// @notice         address token = BytesLib.toAddress(data, 24);
/// @notice         uint256 amount = BytesLib.toUint256(data, 44);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 76);
/// @notice         bool lockForSP = _decodeBool(data, 77);
contract ApproveAndGearboxStakeHook is BaseHook, ISuperHookInflowOutflow, ISuperHookContextAware {
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 44;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 76;

    constructor(address registry_) BaseHook(registry_, HookType.INFLOW) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function build(
        address prevHook,
        address,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        address yieldSource = data.extractYieldSource();
        // yieldSource is spender for approval
        address token = BytesLib.toAddress(data, 24);
        uint256 amount = _decodeAmount(data);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (yieldSource == address(0) || token == address(0)) revert ADDRESS_NOT_VALID();
        if (amount == 0) revert AMOUNT_NOT_VALID();

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).outAmount();
        }

        executions = new Execution[](4);
        executions[0] =
            Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (yieldSource, 0)) });
        executions[1] =
            Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (yieldSource, amount)) });
        executions[2] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IGearboxFarmingPool.deposit, (amount))
        });
        executions[3] =
            Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (yieldSource, 0)) });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmount(bytes memory data) external pure returns (uint256) {
        return _decodeAmount(data);
    }

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        outAmount = _getBalance(account, data);
        lockForSP = _decodeBool(data, 77);
        spToken = data.extractYieldSource();
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        outAmount = _getBalance(account, data) - outAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeAmount(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        return IGearboxFarmingPool(data.extractYieldSource()).balanceOf(account);
    }
}
