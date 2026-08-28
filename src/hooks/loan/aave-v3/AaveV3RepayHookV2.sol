// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IPool } from "../../../vendor/aave-v3/IPool.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseAaveV3LoanHookV2 } from "./BaseAaveV3LoanHookV2.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title AaveV3RepayHookV2
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address pool = BytesLib.toAddress(data, 92);
/// @notice         uint8   interestRateMode = BytesLib.toUint8(data, 112); // must == 2
/// @notice         uint256 repayAmount = BytesLib.toUint256(data, 113); // type(uint256).max = full repayment
/// @notice         uint256 reserved = BytesLib.toUint256(data, 145); // must be zero
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 177);
/// @dev type(uint256).max is the only full-repayment sentinel and requires usePrevHookAmount ==
///      false; Aave resolves the full variable debt natively. Repaying a zero-debt position
///      reverts before any approval. A non-sentinel repayAmount greater than the outstanding debt
///      makes Aave pull only the debt, which fails the post-execution exactness check and reverts.
///      outAmount publishes the measured debt-token wallet spend with outToken = loanToken.
contract AaveV3RepayHookV2 is BaseAaveV3LoanHookV2 {
    constructor() BaseAaveV3LoanHookV2(HookSubTypes.LOAN_REPAY) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Aave V3 Repay V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Repays an exact amount or the full variable debt to an Aave V3 pool";
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
        AaveV3V2Vars memory vars = _decodeAaveV3V2(data, true);
        (uint256 repayAssets, bool fullRepay) = _resolveRepayLeg(prevHook, account, vars);

        executions = new Execution[](4);
        executions[0] =
            Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.pool, 0)) });
        executions[1] = Execution({
            target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.pool, repayAssets))
        });
        executions[2] = Execution({
            target: vars.pool,
            value: 0,
            callData: abi.encodeCall(
                IPool.repay, (vars.loanToken, fullRepay ? type(uint256).max : repayAssets, VARIABLE_RATE_MODE, account)
            )
        });
        // Reset approval — critical even after repay(max)
        executions[3] =
            Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.pool, 0)) });
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return _inspectAaveV3V2(_decodeAaveV3V2(data, true));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Resolves the repay leg. Reverts before any approval/provider call when the account has
    ///      no outstanding variable debt, when a full-repayment sentinel is combined with
    ///      usePrevHookAmount, or when the previous-hook output is invalid. For the sentinel,
    ///      `repayAssets` resolves to the current variable-debt balance — exact for the
    ///      transaction because debt accrual is per-timestamp and build, approval and repay execute in
    ///      the same transaction.
    function _resolveRepayLeg(
        address prevHook,
        address account,
        AaveV3V2Vars memory vars
    )
        internal
        view
        returns (uint256 repayAssets, bool fullRepay)
    {
        uint256 debt = _variableDebtBalance(vars, account);
        if (debt == 0) revert NO_OUTSTANDING_DEBT();

        fullRepay = vars.amount1 == type(uint256).max;
        if (fullRepay) {
            if (vars.usePrevHookAmount) revert MAX_WITH_PREV_NOT_ALLOWED();
            repayAssets = debt;
        } else {
            repayAssets =
                vars.usePrevHookAmount ? _resolvePrevHookOutput(prevHook, account, vars.loanToken) : vars.amount1;
            if (repayAssets == 0) revert AMOUNT_NOT_VALID();
        }
    }

    /// @inheritdoc BaseHook
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        AaveV3V2Vars memory vars = _decodeAaveV3V2(data, true);
        (uint256 repayAssets,) = _resolveRepayLeg(prevHook, account, vars);

        expectedPrimaryAmount = repayAssets;
        _snapshotBalances(account, data);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _settleRepay(account, data);
    }
}
