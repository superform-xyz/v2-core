// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IAaveV4Spoke } from "../../../vendor/aave-v4/IAaveV4Spoke.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseAaveV4StandaloneLoanHookV2 } from "./BaseAaveV4StandaloneLoanHookV2.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title AaveV4SupplyHookV2
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 yieldSourceOracleId = data.extractYieldSourceOracleId(); // Superform Aave V4 YS oracle id
/// @notice         address yieldSource = data.extractYieldSource(); // AaveV4ReserveKey(spoke, supplyReserveId)
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address spoke = BytesLib.toAddress(data, 92);
/// @notice         uint256 supplyReserveId = BytesLib.toUint256(data, 112);
/// @notice         uint256 borrowReserveId = BytesLib.toUint256(data, 144);
/// @notice         uint256 collateralAmount = BytesLib.toUint256(data, 176); // exact assets to pledge
/// @notice         uint256 reserved = BytesLib.toUint256(data, 208); // must be zero
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 240);
/// @dev Standalone PLEDGE (LOAN): supplies an exact collateral amount to an Aave V4 spoke and
///      enables the reserve as collateral — no borrow leg, no ratio/oracle derivation inside the
///      hook. Aave V4 does not auto-enable collateral on supply, so setUsingAsCollateral(true) is
///      emitted explicitly; it is a no-op when already enabled. Each reserve id must resolve to the
///      declared token or the hook reverts before any provider call. With usePrevHookAmount the
///      calldata amount word is ignored and the previous hook's output (denominated in the
///      collateral token) becomes the amount. Approvals are granted for the resolved amount and
///      reset to zero in the same transaction. This is a terminal hook: it spends the collateral
///      asset and publishes outAmount = 0 (outToken = collateralToken for classification); the
///      exact spend is still enforced against the measured wallet delta.
/// @dev Idle-mode interaction: pledging flips the account's collateral flag for the reserve, after
///      which the idle MONEY_MARKET hooks refuse that (account, reserve) by design
///      (RESERVE_IS_COLLATERAL). The reverse is guarded here: a reserve that already carries an
///      un-flagged (idle, ledger-tracked) position is refused (RESERVE_HAS_IDLE_POSITION) before any
///      provider execution is emitted, so every (account, reserve) is in exactly one mode on-chain.
contract AaveV4SupplyHookV2 is BaseAaveV4StandaloneLoanHookV2 {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() BaseAaveV4StandaloneLoanHookV2(HookSubTypes.LOAN) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Aave V4 Supply V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Supplies an exact collateral amount to an Aave V4 spoke and enables it as collateral without borrowing";
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
        AaveV4V2Vars memory vars = _decodeAndBind(data);
        _requireNoIdlePosition(vars, account);
        uint256 amount =
            _resolveExactPrimary(prevHook, account, vars.collateralToken, vars.amount1, vars.usePrevHookAmount);

        executions = new Execution[](5);
        executions[0] = Execution({
            target: vars.collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.spoke, 0))
        });
        executions[1] = Execution({
            target: vars.collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.spoke, amount))
        });
        executions[2] = Execution({
            target: vars.spoke,
            value: 0,
            callData: abi.encodeCall(IAaveV4Spoke.supply, (vars.supplyReserveId, amount, account))
        });
        // Aave V4 does NOT auto-enable collateral on supply — explicit enablement required.
        // Calling when already enabled is a no-op.
        executions[3] = Execution({
            target: vars.spoke,
            value: 0,
            callData: abi.encodeCall(IAaveV4Spoke.setUsingAsCollateral, (vars.supplyReserveId, true, account))
        });
        // Reset approval after supply to prevent dangling allowance
        executions[4] = Execution({
            target: vars.collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.spoke, 0))
        });
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return _inspectAaveV4V2(_decodeAaveV4V2(data, true));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        AaveV4V2Vars memory vars = _decodeAndBind(data);
        _requireNoIdlePosition(vars, account);
        expectedPrimaryAmount =
            _resolveExactPrimary(prevHook, account, vars.collateralToken, vars.amount1, vars.usePrevHookAmount);
        _snapshotBalances(account, data);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _settleSupplyCollateral(account, data);
    }
}
