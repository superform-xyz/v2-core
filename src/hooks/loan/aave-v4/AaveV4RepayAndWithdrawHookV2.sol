// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IAaveV4Spoke } from "../../../vendor/aave-v4/IAaveV4Spoke.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseAaveV4LoanHookV2 } from "./BaseAaveV4LoanHookV2.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookInspector, ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title AaveV4RepayAndWithdrawHookV2
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 yieldSourceOracleId = data.extractYieldSourceOracleId(); // Superform Aave V4 YS oracle id
/// @notice         address yieldSource = data.extractYieldSource(); // AaveV4ReserveKey(spoke, supplyReserveId)
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address spoke = BytesLib.toAddress(data, 92);
/// @notice         uint256 supplyReserveId = BytesLib.toUint256(data, 112);
/// @notice         uint256 borrowReserveId = BytesLib.toUint256(data, 144);
/// @notice         uint256 repayAmount = BytesLib.toUint256(data, 176); // CAP: actual repay = min(cap, debt)
/// @notice         uint256 withdrawAmount = BytesLib.toUint256(data, 208); // type(uint256).max = full collateral
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 240);
/// @dev Repayment executes strictly before collateral withdrawal. The repay word is a CAP: the
///      resolved repayment is min(cap, total debt) with the total debt read as drawn + premium; a
///      cap covering the whole debt (including type(uint256).max, subsumed by the min — no
///      separate repay sentinel) emits repay(type(uint256).max) so the Spoke clears the debt
///      natively without rounding dust, while the approval always uses the resolved amount. Zero
///      outstanding debt SKIPS the repay leg — the withdraw leg still executes and the Spoke's
///      own health check arbitrates whether releasing the collateral is valid. With
///      usePrevHookAmount the calldata cap word is ignored and the previous hook's output becomes
///      the cap; an output larger than the debt caps to the debt and the leftover stays in the
///      wallet. The withdraw leg is exact and never derived from the repayment; it is resolved against the
///      live position before any provider execution (empty → AMOUNT_NOT_VALID, un-flagged idle position →
///      RESERVE_NOT_COLLATERAL, above the position → WITHDRAW_EXCEEDS_SUPPLIED); type(uint256).max on the
///      withdraw slot resolves to the full supplied balance (Spoke-native). Each reserve id must resolve to the
///      declared token. outAmount publishes
///      the actual released collateral-token wallet delta with outToken = collateralToken.
/// @dev Cap semantics close the third-party-repayment griefing vector: a partial third-party
///      repayment shrinks the resolved amount and a complete one skips the repay leg — neither
///      cancels a signed close intent.
contract AaveV4RepayAndWithdrawHookV2 is BaseAaveV4LoanHookV2 {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() BaseAaveV4LoanHookV2(HookSubTypes.LOAN_REPAY) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Aave V4 Repay and Withdraw V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Repays debt up to a cap and withdraws an exact collateral amount from an Aave V4 spoke";
    }

    /// @dev Header pin target (BaseAaveV4LoanHookV2._primaryReserveId): the header yield source must be the
    ///      reserve key of the supply reserve
    function _primaryReserveId(AaveV4V2Vars memory vars) internal pure override returns (uint256) {
        return vars.supplyReserveId;
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
        AaveV4V2Vars memory vars = _decodeAaveV4V2(data, false);
        _validateReserves(vars);
        (uint256 repayAssets, bool fullRepay) = _resolveRepayLeg(prevHook, account, vars);
        // Resolves the withdraw leg against the live position (empty / un-flagged / zero / above position all
        // revert here) before any provider call; the sentinel itself is passed through so the Spoke resolves it
        // natively
        _resolveWithdrawLeg(account, vars);

        // Zero debt skips the 4 repay executions; the withdraw leg always runs, strictly last
        executions = new Execution[]((repayAssets == 0 ? 0 : 4) + 1);
        uint256 i;
        if (repayAssets != 0) {
            executions[i++] = Execution({
                target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.spoke, 0))
            });
            executions[i++] = Execution({
                target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.spoke, repayAssets))
            });
            executions[i++] = Execution({
                target: vars.spoke,
                value: 0,
                callData: abi.encodeCall(
                    IAaveV4Spoke.repay, (vars.borrowReserveId, fullRepay ? type(uint256).max : repayAssets, account)
                )
            });
            // Reset approval — critical even after repay(max)
            executions[i++] = Execution({
                target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.spoke, 0))
            });
        }
        // Withdrawal executes strictly after any repayment
        executions[i] = Execution({
            target: vars.spoke,
            value: 0,
            callData: abi.encodeCall(IAaveV4Spoke.withdraw, (vars.supplyReserveId, vars.amount2, account))
        });
    }

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev Strict: full decode (length, addresses, header key, bool) before reading the two slots
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        _decodeAaveV4V2(data, false);
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
        _decodeAaveV4V2(data, false);
        return _replaceTwoAmounts(data, amounts, AMOUNT1_OFFSET, AMOUNT2_OFFSET);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return _inspectAaveV4V2(_decodeAaveV4V2(data, false));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Resolves the withdraw leg against the account's live position, read BEFORE any provider execution (same
    ///      gate and order as the standalone RELEASE): an empty position reverts (AMOUNT_NOT_VALID), an un-flagged
    ///      position is the idle MONEY_MARKET side's and reverts (RESERVE_NOT_COLLATERAL), a zero word reverts
    ///      (AMOUNT_NOT_VALID), the sentinel resolves to the full
    ///      supplied balance (passed through so the Spoke withdraws everything natively), and an exact word above the
    ///      position is refused with the typed WITHDRAW_EXCEEDS_SUPPLIED — Aave would otherwise silently convert it
    ///      into a full withdrawal and the hook would fail late as DELTA_MISMATCH.
    /// @param account The executing smart account
    /// @param vars The decoded hook parameters
    /// @return The exact collateral amount the withdraw call will release
    function _resolveWithdrawLeg(address account, AaveV4V2Vars memory vars) internal view returns (uint256) {
        uint256 supplied = _requireCollateralPosition(vars, account);
        if (vars.amount2 == 0) revert AMOUNT_NOT_VALID();
        if (vars.amount2 == type(uint256).max) return supplied;
        if (vars.amount2 > supplied) revert WITHDRAW_EXCEEDS_SUPPLIED(vars.amount2, supplied);
        return vars.amount2;
    }

    /// @inheritdoc BaseHook
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        AaveV4V2Vars memory vars = _decodeAaveV4V2(data, false);
        _validateReserves(vars);
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
