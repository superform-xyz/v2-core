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
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title EulerRepayHook
/// @author Superform Labs
/// @dev data has the following structure (52-byte strategy header carrying meaningful fields + hook-specific):
/// @notice         bytes32 configId = BytesLib.toBytes32(data, 0); // carried, not validated
/// @notice         address collateralVault = BytesLib.toAddress(data, 32); // reserved, must be ZERO
/// @notice         address debtAsset = BytesLib.toAddress(data, 52);
/// @notice         address collateralAsset = BytesLib.toAddress(data, 72); // reserved, must be ZERO
/// @notice         address evc = BytesLib.toAddress(data, 92); // must equal the pinned EVC_ADDRESS
/// @notice         address controllerVault = BytesLib.toAddress(data, 112);
/// @notice         uint256 repayAmount = BytesLib.toUint256(data, 132); // CAP: actual repay = min(cap, debtOf)
/// @notice         uint256 reserved = BytesLib.toUint256(data, 164); // must be zero
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 196);
/// @dev The repay amount is a CAP: the hook reads the current debt at build time and repays
///      min(cap, debtOf(account)), which absorbs accrued interest without a full-repayment
///      sentinel (a cap of type(uint256).max naturally means "repay everything"). A zero
///      outstanding debt skips the repay leg entirely instead of reverting, so a third party
///      gifting a full repayment cannot cancel a signed intent. When no debt will remain, the
///      hook additionally calls controllerVault.disableController() (the vault's own disable
///      path, emitted only while the controller is still enabled) and post-verifies from live
///      chain state that a zero-debt position has no enabled controller. EVK repay is
///      controller-neutral, so this hook is intentionally independent of collateral, LTV, oracle
///      and release configuration — none of those enter its validation or inspector identity.
///      The settle still verifies the measured debt-asset wallet spend equals the resolved
///      repayment, but publishes outAmount = 0 with outToken = debtAsset: the hook is a terminal
///      sink, and a zero output makes any downstream usePrevHookAmount chaining fail closed.
/// @dev LIMITATION: the inherited non-virtual getCollateralTokenBalance(account, data) reverts for
///      this hook's data (collateralAsset is the reserved zero address), so this hook does NOT
///      advertise ISuperHookLoans via ERC-165 (_supportsLoanInterface returns false) — honest
///      advertisement for interface-driven consumers. The individual loan-token getters remain
///      directly callable; consumers reading collateral fields must check
///      getCollateralTokenAddress(data) == address(0) first. The hook's own execution path never
///      calls the collateral getter (loan-only snapshot).
contract EulerRepayHook is BaseEulerLoanHook {
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param evc_ The canonical EVC singleton for this chain
    /// @param eVaultFactory_ The canonical EVK GenericFactory for this chain
    constructor(address evc_, address eVaultFactory_) BaseEulerLoanHook(evc_, eVaultFactory_, HookSubTypes.LOAN_REPAY) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Euler Repay";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Repays debt to an Euler EVK vault up to a cap, disabling the controller when the debt clears";
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
        EulerVars memory vars = _decodeEuler(data, true);
        _validateBindings(vars, true);
        (uint256 actualRepay, bool predictedClear) = _resolveRepayCap(prevHook, account, vars);
        // With debt outstanding the controller is necessarily enabled; the gate only matters on
        // the skipped-repay (already-clear) path
        bool needControllerDisable =
            predictedClear && IEVC(vars.evc).isControllerEnabled(account, vars.controllerVault);

        uint256 repayCount = actualRepay == 0 ? 0 : 4;
        executions = new Execution[](repayCount + (needControllerDisable ? 1 : 0));
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
            // The vault self-disables via the EVC; reverts E_OutstandingDebt if any debt remains
            executions[i] = Execution({
                target: vars.controllerVault, value: 0, callData: abi.encodeCall(IEVault.disableController, ())
            });
        }
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return _inspectRepay(_decodeEuler(data, true));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev The reserved-zero collateral slot makes the inherited getCollateralTokenBalance revert
    ///      on this hook's data, so the full ISuperHookLoans surface is not honored — do not
    ///      advertise it via ERC-165
    function _supportsLoanInterface() internal pure override returns (bool) {
        return false;
    }

    /// @inheritdoc BaseHook
    /// @dev Re-resolves the cap (identical to build within one transaction — EVK views virtually
    ///      accrue by timestamp), stores the exact expected spend, and snapshots the loan-token
    ///      balance only (the collateral field is reserved zero)
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        EulerVars memory vars = _decodeEuler(data, true);
        _validateBindings(vars, true);
        (uint256 actualRepay,) = _resolveRepayCap(prevHook, account, vars);

        expectedPrimaryAmount = actualRepay;
        _snapshotLoanBalance(account, data);
    }

    /// @inheritdoc BaseHook
    /// @dev Settles the exact debt-asset spend, then verifies from live chain state that a
    ///      zero-debt position has no enabled controller (state-derived, poison-proof)
    function _postExecute(address, address account, bytes calldata data) internal override {
        _settleRepay(account, data);
        _verifyReleaseState(_decodeEuler(data, true), account, false);
    }
}
