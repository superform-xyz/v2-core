// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IMorphoBase, MarketParams } from "../../../vendor/morpho/IMorpho.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseMorphoLoanHookV2 } from "./BaseMorphoLoanHookV2.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookInspector, ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title MorphoRepayAndWithdrawHookV2
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address oracle = BytesLib.toAddress(data, 92);
/// @notice         address irm = BytesLib.toAddress(data, 112);
/// @notice         uint256 repayAmount = BytesLib.toUint256(data, 132); // CAP: actual repay = min(cap, debt)
/// @notice         uint256 withdrawAmount = BytesLib.toUint256(data, 164); // type(uint256).max = full collateral
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 196);
/// @notice         uint256 lltv = BytesLib.toUint256(data, 197);
/// @notice         byte reserved = data[229]; // must be 0x00
/// @dev Repayment executes strictly before collateral withdrawal. The repay word is a CAP: the
///      resolved repayment is min(cap, accrued debt); a cap covering the whole debt (including
///      type(uint256).max, subsumed by the min — no separate repay sentinel) repays by borrow
///      shares, clearing the debt dust-free. Zero outstanding debt SKIPS the repay leg — the
///      withdraw leg still executes and Morpho's own health check arbitrates whether stripping
///      the collateral is valid. With usePrevHookAmount the calldata cap word is ignored and the
///      previous hook's output becomes the cap; an output larger than the debt caps to the debt
///      and the leftover stays in the wallet. The withdraw leg is exact and never derived
///      proportionally from the repayment; type(uint256).max on the withdraw slot resolves to
///      the position's full collateral. outAmount publishes the actual released collateral-token
///      wallet delta with outToken = collateralToken.
/// @dev Cap semantics close the third-party-repayment griefing vector: a partial third-party
///      repayment shrinks the resolved amount and a complete one skips the repay leg — neither
///      cancels a signed close intent.
contract MorphoRepayAndWithdrawHookV2 is BaseMorphoLoanHookV2 {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param morpho_ Address of the Morpho Blue singleton
    constructor(address morpho_) BaseMorphoLoanHookV2(morpho_, HookSubTypes.LOAN_REPAY) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Morpho Repay and Withdraw V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Repays debt up to a cap and withdraws an exact collateral amount from a Morpho market";
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
        MorphoV2Vars memory vars = _decodeMorphoV2(data, false);
        MarketParams memory marketParams = _marketParams(vars);
        (uint256 repayAssets, uint256 borrowShares, bool fullRepay) =
            _resolveRepayLeg(prevHook, account, vars, marketParams);
        uint256 withdrawAmount = _resolveWithdrawLeg(account, vars, marketParams);

        // Zero debt skips the 4 repay executions; the withdraw leg always runs, strictly last
        executions = new Execution[]((repayAssets == 0 ? 0 : 4) + 1);
        uint256 i;
        if (repayAssets != 0) {
            executions[i++] =
                Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
            executions[i++] = Execution({
                target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, repayAssets))
            });
            executions[i++] = Execution({
                target: morpho,
                value: 0,
                callData: fullRepay
                    ? abi.encodeCall(IMorphoBase.repay, (marketParams, 0, borrowShares, account, ""))
                    : abi.encodeCall(IMorphoBase.repay, (marketParams, repayAssets, 0, account, ""))
            });
            executions[i++] =
                Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
        }
        executions[i] = Execution({
            target: morpho,
            value: 0,
            callData: abi.encodeCall(IMorphoBase.withdrawCollateral, (marketParams, withdrawAmount, account, account))
        });
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        return _decodeTwoAmounts(data, AMOUNT_POSITION, AMOUNT2_OFFSET);
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
        return _replaceTwoAmounts(data, amounts, AMOUNT_POSITION, AMOUNT2_OFFSET);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external view override returns (bytes memory) {
        return _inspectMorphoV2(_decodeMorphoV2(data, false));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Resolves the withdraw leg: exact amount, or the position's full collateral for the
    ///      type(uint256).max sentinel. Never derived proportionally from the repayment.
    /// @param account The executing smart account
    /// @param vars The decoded hook parameters
    /// @param marketParams The Morpho market params derived from `vars`
    /// @return withdrawAmount The exact collateral amount the withdraw call will release
    function _resolveWithdrawLeg(
        address account,
        MorphoV2Vars memory vars,
        MarketParams memory marketParams
    )
        internal
        view
        returns (uint256 withdrawAmount)
    {
        if (vars.amount2 == 0) revert AMOUNT_NOT_VALID();
        if (vars.amount2 != type(uint256).max) return vars.amount2;
        withdrawAmount = _positionCollateral(marketParams, account);
        if (withdrawAmount == 0) revert AMOUNT_NOT_VALID();
    }

    /// @inheritdoc BaseHook
    /// @dev Accrues interest, then stores the exact expected legs and snapshots wallet balances
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        MorphoV2Vars memory vars = _decodeMorphoV2(data, false);
        _accrueInterest(vars);

        MarketParams memory marketParams = _marketParams(vars);
        (uint256 repayAssets,,) = _resolveRepayLeg(prevHook, account, vars, marketParams);
        expectedPrimaryAmount = repayAssets;
        expectedSecondaryAmount = _resolveWithdrawLeg(account, vars, marketParams);
        _snapshotBalances(account, data);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _settleClose(account, data);
    }
}
