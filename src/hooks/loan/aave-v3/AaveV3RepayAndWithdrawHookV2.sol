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
import { ISuperHookInspector, ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title AaveV3RepayAndWithdrawHookV2
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address pool = BytesLib.toAddress(data, 92);
/// @notice         uint8   interestRateMode = BytesLib.toUint8(data, 112); // must == 2
/// @notice         uint256 repayAmount = BytesLib.toUint256(data, 113); // CAP: actual repay = min(cap, debt)
/// @notice         uint256 withdrawAmount = BytesLib.toUint256(data, 145); // type(uint256).max = full collateral
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 177);
/// @dev Repayment executes strictly before collateral withdrawal. The repay word is a CAP: the
///      resolved repayment is min(cap, current variable debt); a cap covering the whole debt
///      (including type(uint256).max, subsumed by the min — no separate repay sentinel) emits
///      repay(type(uint256).max) so Aave clears the debt natively without rounding dust, while
///      the approval always uses the resolved amount. Zero outstanding debt SKIPS the repay leg —
///      the withdraw leg still executes and Aave's own health-factor check arbitrates whether
///      releasing the collateral is valid. With usePrevHookAmount the calldata cap word is
///      ignored and the previous hook's output becomes the cap; an output larger than the debt
///      caps to the debt and the leftover stays in the wallet. The withdraw leg is exact and
///      never derived from the repayment; type(uint256).max on the withdraw slot resolves to the
///      full aToken balance (Aave-native). outAmount publishes the actual released
///      collateral-token wallet delta with outToken = collateralToken.
/// @dev Cap semantics close the third-party-repayment griefing vector: a partial third-party
///      repayment shrinks the resolved amount and a complete one skips the repay leg — neither
///      cancels a signed close intent.
contract AaveV3RepayAndWithdrawHookV2 is BaseAaveV3LoanHookV2 {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() BaseAaveV3LoanHookV2(HookSubTypes.LOAN_REPAY) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Aave V3 Repay and Withdraw V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Repays debt up to a cap and withdraws an exact collateral amount from an Aave V3 pool";
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
        AaveV3V2Vars memory vars = _decodeAaveV3V2(data, false);
        (uint256 repayAssets, bool fullRepay) = _resolveRepayLeg(prevHook, account, vars);
        // Validates the withdraw leg (zero amount / zero aToken balance under the sentinel) before
        // any provider call; the sentinel itself is passed through so Aave resolves it natively
        _resolveWithdrawLeg(account, vars);

        // Zero debt skips the 4 repay executions; the withdraw leg always runs, strictly last
        executions = new Execution[]((repayAssets == 0 ? 0 : 4) + 1);
        uint256 i;
        if (repayAssets != 0) {
            executions[i++] = Execution({
                target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.pool, 0))
            });
            executions[i++] = Execution({
                target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.pool, repayAssets))
            });
            executions[i++] = Execution({
                target: vars.pool,
                value: 0,
                callData: abi.encodeCall(
                    IPool.repay,
                    (vars.loanToken, fullRepay ? type(uint256).max : repayAssets, VARIABLE_RATE_MODE, account)
                )
            });
            // Reset approval — critical even after repay(max)
            executions[i++] = Execution({
                target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.pool, 0))
            });
        }
        // Withdrawal executes strictly after any repayment; max resolves to the full aToken balance
        executions[i] = Execution({
            target: vars.pool,
            value: 0,
            callData: abi.encodeCall(IPool.withdraw, (vars.collateralToken, vars.amount2, account))
        });
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        return _decodeTwoAmounts(data, AMOUNT1_OFFSET, AMOUNT2_OFFSET);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        return _twoTokenRoles();
    }

    /// @inheritdoc ISuperHookOutflow
    function replaceCalldataAmounts(
        bytes memory data,
        uint256[] memory amounts
    )
        external
        pure
        override
        returns (bytes memory)
    {
        return _replaceTwoAmounts(data, amounts, AMOUNT1_OFFSET, AMOUNT2_OFFSET);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return _inspectAaveV3V2(_decodeAaveV3V2(data, false));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Resolves the withdraw leg: exact amount, or the full aToken balance for the sentinel
    /// @param account The executing smart account
    /// @param vars The decoded hook parameters
    /// @return The exact collateral amount the withdraw call will release
    function _resolveWithdrawLeg(address account, AaveV3V2Vars memory vars) internal view returns (uint256) {
        if (vars.amount2 == 0) revert AMOUNT_NOT_VALID();
        if (vars.amount2 != type(uint256).max) return vars.amount2;
        uint256 aTokenBalance = _aTokenBalance(vars, account);
        if (aTokenBalance == 0) revert AMOUNT_NOT_VALID();
        return aTokenBalance;
    }

    /// @inheritdoc BaseHook
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        AaveV3V2Vars memory vars = _decodeAaveV3V2(data, false);
        (uint256 repayAssets,) = _resolveRepayLeg(prevHook, account, vars);

        expectedPrimaryAmount = repayAssets;
        expectedSecondaryAmount = _resolveWithdrawLeg(account, vars);
        _snapshotBalances(account, data);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _settleClose(account, data);
    }
}
