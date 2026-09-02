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
/// @notice         uint256 repayAmount = BytesLib.toUint256(data, 113); // CAP: actual repay = min(cap, debt)
/// @notice         uint256 reserved = BytesLib.toUint256(data, 145); // must be zero
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 177);
/// @dev The repay word is a CAP: the resolved repayment is min(cap, current variable debt). A cap
///      covering the whole debt (including type(uint256).max, subsumed by the min — no separate
///      sentinel) emits repay(type(uint256).max) so Aave clears the debt natively without
///      rounding dust, while the approval always uses the resolved amount. Zero outstanding debt
///      SKIPS the repay leg (build returns no executions, the settle asserts a zero spend)
///      instead of reverting. With usePrevHookAmount the calldata cap word is ignored and the
///      previous hook's output (denominated in loanToken) becomes the cap; an output larger than
///      the debt caps to the debt and the leftover stays in the wallet. The settle asserts the
///      measured spend equals the RESOLVED amount, not the calldata word. This is a terminal
///      hook: it spends the debt asset and publishes outAmount = 0 (outToken = loanToken for
///      classification).
/// @dev Cap semantics close the third-party-repayment griefing vector: a partial third-party
///      repayment shrinks the resolved amount and a complete one skips the leg — neither cancels
///      a signed intent.
contract AaveV3RepayHookV2 is BaseAaveV3LoanHookV2 {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() BaseAaveV3LoanHookV2(HookSubTypes.LOAN_REPAY) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Aave V3 Repay V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Repays variable debt up to a cap to an Aave V3 pool, clearing natively when the cap covers the debt";
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
        if (repayAssets == 0) return new Execution[](0); // zero debt: nothing to repay

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
