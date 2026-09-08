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

/// @title EulerDepositCollateralAndBorrowHook
/// @author Superform Labs
/// @dev data has the following structure (52-byte strategy header carrying meaningful fields + hook-specific):
/// @notice         bytes32 configId = BytesLib.toBytes32(data, 0); // carried, not validated
/// @notice         address collateralVault = BytesLib.toAddress(data, 32);
/// @notice         address debtAsset = BytesLib.toAddress(data, 52);
/// @notice         address collateralAsset = BytesLib.toAddress(data, 72);
/// @notice         address evc = BytesLib.toAddress(data, 92);
/// @notice         address controllerVault = BytesLib.toAddress(data, 112);
/// @notice         uint256 collateralAmount = BytesLib.toUint256(data, 132);
/// @notice         uint256 borrowAmount = BytesLib.toUint256(data, 164);
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 196);
/// @dev Both legs are exact (no sentinels). usePrevHookAmount applies to the collateral leg only
///      and requires the previous hook's output token to equal the collateral asset. Before any
///      provider call the hook verifies that the calldata evc equals the pinned canonical EVC and
///      both vaults are pinned-factory EVK proxies with matching EVC/asset bindings, that any
///      enabled controller equals the configured one, that the collateral's borrow/liquidation LTVs are configured,
///      that the deposit cap admits the collateral amount, and that controller cash covers the
///      borrow. The EVC collateral/controller enables are emitted only when needed (they are
///      idempotent on the EVC regardless). outAmount publishes the actual borrowed debt-asset
///      wallet delta with outToken = debtAsset.
contract EulerDepositCollateralAndBorrowHook is BaseEulerLoanHook {
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param evc_ The canonical EVC singleton for this chain
    /// @param eVaultFactory_ The canonical EVK GenericFactory for this chain
    constructor(address evc_, address eVaultFactory_) BaseEulerLoanHook(evc_, eVaultFactory_, HookSubTypes.LOAN) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Euler Deposit Collateral and Borrow";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Deposits an exact collateral amount and borrows an exact asset amount from Euler EVK vaults";
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
        _resolveOpenAmounts(prevHook, account, vars);
        _validateBindings(vars, false);
        _validateControllerState(vars, account);
        _validateOpenMarket(vars, account);

        bool needCollateralEnable = !IEVC(vars.evc).isCollateralEnabled(account, vars.collateralVault);
        bool needControllerEnable = !IEVC(vars.evc).isControllerEnabled(account, vars.controllerVault);

        uint256 count = 5 + (needCollateralEnable ? 1 : 0) + (needControllerEnable ? 1 : 0);
        executions = new Execution[](count);
        uint256 i;
        executions[i++] = Execution({
            target: vars.collateralAsset, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.collateralVault, 0))
        });
        executions[i++] = Execution({
            target: vars.collateralAsset,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (vars.collateralVault, vars.primary))
        });
        executions[i++] = Execution({
            target: vars.collateralVault, value: 0, callData: abi.encodeCall(IEVault.deposit, (vars.primary, account))
        });
        // Reset approval — no dangling allowance
        executions[i++] = Execution({
            target: vars.collateralAsset, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.collateralVault, 0))
        });
        // Collateral must be enabled (and deposited) and the controller enabled before borrow's
        // end-of-call health/controller checks; the enables are EVC-idempotent no-ops otherwise
        if (needCollateralEnable) {
            executions[i++] = Execution({
                target: vars.evc,
                value: 0,
                callData: abi.encodeCall(IEVC.enableCollateral, (account, vars.collateralVault))
            });
        }
        if (needControllerEnable) {
            executions[i++] = Execution({
                target: vars.evc,
                value: 0,
                callData: abi.encodeCall(IEVC.enableController, (account, vars.controllerVault))
            });
        }
        executions[i] = Execution({
            target: vars.controllerVault, value: 0, callData: abi.encodeCall(IEVault.borrow, (vars.secondary, account))
        });
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

    /// @dev Resolves both open legs; reverts before any provider call on zero/sentinel amounts or
    ///      an invalid previous-hook output (wrong token, zero hook, zero amount)
    /// @param prevHook The previous hook in the chain
    /// @param account The executing smart account
    /// @param vars The decoded hook parameters (primary is resolved in place)
    function _resolveOpenAmounts(address prevHook, address account, EulerVars memory vars) internal view {
        if (vars.secondary == 0 || vars.secondary == type(uint256).max) revert AMOUNT_NOT_VALID();
        if (vars.usePrevHookAmount) {
            vars.primary = _resolvePrevHookOutput(prevHook, account, vars.collateralAsset);
        }
        if (vars.primary == 0 || vars.primary == type(uint256).max) revert AMOUNT_NOT_VALID();
    }

    /// @inheritdoc BaseHook
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        EulerVars memory vars = _decodeEuler(data, false);
        _resolveOpenAmounts(prevHook, account, vars);
        _validateBindings(vars, false);
        _validateControllerState(vars, account);
        _validateOpenMarket(vars, account);

        expectedPrimaryAmount = vars.primary;
        expectedSecondaryAmount = vars.secondary;
        _snapshotBalances(account, data);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _settleOpen(account, data);
    }
}
