// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IMorpho, IMorphoBase, MarketParams } from "../../../vendor/morpho/IMorpho.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseMorphoLoanHookV2 } from "./BaseMorphoLoanHookV2.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title MorphoRepayHookV2
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address oracle = BytesLib.toAddress(data, 92);
/// @notice         address irm = BytesLib.toAddress(data, 112);
/// @notice         uint256 repayAmount = BytesLib.toUint256(data, 132); // CAP: actual repay = min(cap, debt)
/// @notice         uint256 reserved = BytesLib.toUint256(data, 164); // must be zero
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 196);
/// @notice         uint256 lltv = BytesLib.toUint256(data, 197);
/// @notice         byte reserved2 = data[229]; // must be 0x00
/// @dev The repay word is a CAP: the resolved repayment is min(cap, accrued debt) read live at
///      build/preExecute time. A cap covering the whole debt (including type(uint256).max,
///      subsumed by the min — no separate sentinel) repays by borrow shares, clearing the entire
///      debt dust-free regardless of rounding; a smaller cap repays exactly that amount of
///      assets. Zero outstanding debt SKIPS the repay leg (build returns no executions, the
///      settle asserts a zero spend) instead of reverting. With usePrevHookAmount the calldata
///      cap word is ignored and the previous hook's output (denominated in loanToken) becomes
///      the cap; an output larger than the debt caps to the debt and the leftover stays in the
///      wallet. Approvals are granted for the resolved amount and reset to zero in the same
///      transaction. This is a terminal hook: it spends the debt asset and publishes
///      outAmount = 0 (outToken = loanToken for classification) so a downstream
///      usePrevHookAmount consumer cannot mistake the spend for produced tokens.
/// @dev Cap semantics close the third-party-repayment griefing vector: a partial third-party
///      repayment shrinks the resolved amount and a complete one skips the leg — neither cancels
///      a signed intent.
contract MorphoRepayHookV2 is BaseMorphoLoanHookV2 {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param morpho_ Address of the Morpho Blue singleton
    constructor(address morpho_) BaseMorphoLoanHookV2(morpho_, HookSubTypes.LOAN_REPAY) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Morpho Repay V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Repays debt up to a cap to a Morpho market, clearing by shares when the cap covers the debt";
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
        MorphoV2Vars memory vars = _decodeMorphoV2(data, true);
        MarketParams memory marketParams = _marketParams(vars);
        (uint256 repayAssets, uint256 borrowShares, bool fullRepay) =
            _resolveRepayLeg(prevHook, account, vars, marketParams);
        if (repayAssets == 0) return new Execution[](0); // zero debt: nothing to repay

        executions = new Execution[](4);
        executions[0] =
            Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
        executions[1] = Execution({
            target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, repayAssets))
        });
        executions[2] = Execution({
            target: morpho,
            value: 0,
            callData: fullRepay
                // repay by shares clears the entire debt regardless of interim accrual
                ? abi.encodeCall(IMorphoBase.repay, (marketParams, 0, borrowShares, account, ""))
                : abi.encodeCall(IMorphoBase.repay, (marketParams, repayAssets, 0, account, ""))
        });
        executions[3] =
            Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external view override returns (bytes memory) {
        return _inspectMorphoV2(_decodeMorphoV2(data, true));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    /// @dev Accrues interest so the cap resolution and the shares-denominated repay price debt
    ///      against identical market state, then stores the exact expected debt-token spend
    ///      (zero when the repay leg is skipped) and snapshots wallet balances. `marketParams` is
    ///      materialized once and reused across accrual and resolution.
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        MorphoV2Vars memory vars = _decodeMorphoV2(data, true);
        MarketParams memory marketParams = _marketParams(vars);
        IMorpho(morpho).accrueInterest(marketParams);

        (uint256 repayAssets,,) = _resolveRepayLeg(prevHook, account, vars, marketParams);
        expectedPrimaryAmount = repayAssets;
        _snapshotBalances(account, data);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _settleRepay(account, data);
    }
}
