// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IEVC } from "../../../vendor/euler/IEVC.sol";
import { IEVault } from "../../../vendor/euler/IEVault.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseEulerLoanHook } from "./BaseEulerLoanHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookInspector, ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title EulerRepayAndWithdrawHook
/// @author Superform Labs
/// @dev data has the following structure (52-byte strategy header carrying meaningful fields + hook-specific):
/// @notice         bytes32 configId = BytesLib.toBytes32(data, 0); // carried, not validated
/// @notice         address collateralVault = BytesLib.toAddress(data, 32);
/// @notice         address debtAsset = BytesLib.toAddress(data, 52);
/// @notice         address collateralAsset = BytesLib.toAddress(data, 72);
/// @notice         address evc = BytesLib.toAddress(data, 92); // must equal the pinned EVC_ADDRESS
/// @notice         address controllerVault = BytesLib.toAddress(data, 112);
/// @notice         uint256 repayAmount = BytesLib.toUint256(data, 132); // CAP: actual repay = min(cap, debtOf)
/// @notice         uint256 withdrawAmount = BytesLib.toUint256(data, 164); // exact assets, no sentinel
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 196);
/// @dev Repayment executes strictly before collateral withdrawal. The repay leg uses CAP
///      semantics (min(cap, debtOf), cap of type(uint256).max means "repay everything"; a zero
///      outstanding debt skips the leg instead of reverting, so a third party gifting a full
///      repayment cannot cancel a signed intent); the withdraw leg is exact assets only —
///      type(uint256).max is rejected (deviation from the Morpho/Aave V2 closes: a full exit
///      passes maxWithdraw-exact assets computed off-chain). A close whose withdrawal would strip
///      the full collateral while residual debt remains is rejected at resolution time
///      (RESIDUAL_DEBT_FULL_WITHDRAW) — it could never pass EVK's health check and would
///      otherwise surface as an opaque provider revert. When no debt will remain, the controller
///      is disabled via controllerVault.disableController() BEFORE the withdrawal and the
///      collateral is released on the EVC after it (both emitted only while still enabled;
///      releasing the collateral flag never locks funds — shares stay redeemable and the next
///      open re-enables automatically — and keeps the account's EVC collateral set from
///      accumulating stale entries toward its hard cap). With residual debt the controller stays
///      enabled and EVK's own end-of-call health check guards the withdrawal — the hook adds no
///      LTV policy of its own. Post-execution verifies from live chain state that a zero-debt
///      position has neither controller nor this collateral enabled. outAmount publishes the
///      actual released collateral-asset wallet delta with outToken = collateralAsset.
contract EulerRepayAndWithdrawHook is BaseEulerLoanHook {
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param evc_ The canonical EVC singleton for this chain
    /// @param eVaultFactory_ The canonical EVK GenericFactory for this chain
    constructor(address evc_, address eVaultFactory_) BaseEulerLoanHook(evc_, eVaultFactory_, HookSubTypes.LOAN_REPAY) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Euler Repay and Withdraw";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Repays debt up to a cap and withdraws an exact collateral amount from Euler EVK vaults";
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
        EulerVars memory vars = _decodeEuler(data, false);
        _validateBindings(vars, false);
        (uint256 actualRepay, bool predictedClear) = _resolveCloseLegs(prevHook, account, vars);
        // With debt outstanding the controller is necessarily enabled; the gates only matter on
        // the skipped-repay (already-clear) path
        bool needControllerDisable =
            predictedClear && IEVC(vars.evc).isControllerEnabled(account, vars.controllerVault);
        bool needCollateralDisable =
            predictedClear && IEVC(vars.evc).isCollateralEnabled(account, vars.collateralVault);

        uint256 repayCount = actualRepay == 0 ? 0 : 4;
        uint256 count = repayCount + 1 + (needControllerDisable ? 1 : 0) + (needCollateralDisable ? 1 : 0);
        executions = new Execution[](count);
        uint256 i;
        if (actualRepay != 0) {
            executions[i++] = Execution({
                target: vars.debtAsset, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.controllerVault, 0))
            });
            executions[i++] = Execution({
                target: vars.debtAsset,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (vars.controllerVault, actualRepay))
            });
            executions[i++] = Execution({
                target: vars.controllerVault, value: 0, callData: abi.encodeCall(IEVault.repay, (actualRepay, account))
            });
            executions[i++] = Execution({
                target: vars.debtAsset, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.controllerVault, 0))
            });
        }
        if (needControllerDisable) {
            // Disable the controller BEFORE withdrawing (vault self-disable path); this also
            // removes the health-check dependency for a full-collateral withdrawal
            executions[i++] = Execution({
                target: vars.controllerVault, value: 0, callData: abi.encodeCall(IEVault.disableController, ())
            });
        }
        // Withdrawal executes strictly after repayment; exact assets, owner and receiver = account
        executions[i++] = Execution({
            target: vars.collateralVault,
            value: 0,
            callData: abi.encodeCall(IEVault.withdraw, (vars.secondary, account, account))
        });
        if (needCollateralDisable) {
            // Debt cleared: release the collateral flag on the EVC (never locks funds; keeps the
            // EVC collateral set from accumulating stale entries; the next open re-enables)
            executions[i] = Execution({
                target: vars.evc,
                value: 0,
                callData: abi.encodeCall(IEVC.disableCollateral, (account, vars.collateralVault))
            });
        }
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        return _decodeTwoAmounts(data, AMOUNT_POSITION, SECONDARY_AMOUNT_OFFSET);
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
        return _replaceTwoAmounts(data, amounts, AMOUNT_POSITION, SECONDARY_AMOUNT_OFFSET);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return _inspectComposite(_decodeEuler(data, false));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Resolves both close legs; the single shared resolution path for build and preExecute
    ///      (identical within one transaction — EVK views virtually accrue by timestamp), so the
    ///      two can never drift. Reverts before any provider call on an invalid withdraw amount
    ///      (zero or the rejected max sentinel) or when the withdrawal would strip the full
    ///      collateral while residual debt remains — such a close can never pass EVK's end-of-call
    ///      health check, so it fails fast with a precise error instead of an opaque provider
    ///      revert.
    /// @param prevHook The previous hook in the chain
    /// @param account The executing smart account
    /// @param vars The decoded hook parameters
    /// @return actualRepay The exact debt-asset amount the repay call will pull (0 = leg skipped)
    /// @return predictedClear True when no debt will remain after the repay leg
    function _resolveCloseLegs(
        address prevHook,
        address account,
        EulerVars memory vars
    )
        internal
        view
        returns (uint256 actualRepay, bool predictedClear)
    {
        if (vars.secondary == 0 || vars.secondary == type(uint256).max) revert AMOUNT_NOT_VALID();
        (actualRepay, predictedClear) = _resolveRepayCap(prevHook, account, vars);
        if (
            !predictedClear
                && IEVault(vars.collateralVault).previewWithdraw(vars.secondary)
                    >= IEVault(vars.collateralVault).balanceOf(account)
        ) {
            revert RESIDUAL_DEBT_FULL_WITHDRAW();
        }
    }

    /// @inheritdoc BaseHook
    /// @dev Re-resolves both legs (identical to build within one transaction — EVK views
    ///      virtually accrue by timestamp), stores the exact expected legs, and snapshots both
    ///      wallet balances
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        EulerVars memory vars = _decodeEuler(data, false);
        _validateBindings(vars, false);
        (uint256 actualRepay,) = _resolveCloseLegs(prevHook, account, vars);

        expectedPrimaryAmount = actualRepay;
        expectedSecondaryAmount = vars.secondary;
        _snapshotBalances(account, data);
    }

    /// @inheritdoc BaseHook
    /// @dev Settles both wallet deltas, then verifies from live chain state that a zero-debt
    ///      position has neither controller nor this collateral enabled (state-derived,
    ///      poison-proof)
    function _postExecute(address, address account, bytes calldata data) internal override {
        _settleClose(account, data);
        _verifyReleaseState(_decodeEuler(data, false), account, true);
    }
}
