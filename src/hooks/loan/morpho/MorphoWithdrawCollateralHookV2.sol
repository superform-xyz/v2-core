// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IMorphoBase, MarketParams } from "../../../vendor/morpho/IMorpho.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseMorphoStandaloneLoanHookV2 } from "./BaseMorphoStandaloneLoanHookV2.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookInspector, ISuperHookInflowOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title MorphoWithdrawCollateralHookV2
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 yieldSourceOracleId = data.extractYieldSourceOracleId(); // Superform Morpho Blue YS id
/// @notice         address yieldSource = data.extractYieldSource(); // Morpho Blue singleton (call target)
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address oracle = BytesLib.toAddress(data, 92);
/// @notice         address irm = BytesLib.toAddress(data, 112);
/// @notice         uint256 withdrawAmount = BytesLib.toUint256(data, 132); // exact collateral;
///                     type(uint256).max = all posted collateral
/// @notice         uint256 reserved = BytesLib.toUint256(data, 164); // must be zero
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 196);
/// @notice         uint256 lltv = BytesLib.toUint256(data, 197);
/// @notice         byte reserved2 = data[229]; // must be 0x00
/// @dev Standalone RELEASE: withdraws collateral from a Morpho market and nothing else — no
///      repay leg (this is NOT a variant of the MONEY_MARKET MorphoWithdrawHook), no
///      ratio/oracle derivation inside the hook; whether the remaining position stays healthy is
///      arbitrated solely by Morpho's own health check, and an over-withdraw on the exact path
///      is arbitrated by Morpho's underflow. The account is both onBehalf and receiver.
///      type(uint256).max resolves to the account's full posted collateral read at build/preExecute time
///      (collateral does not accrue, so the value is exact within the transaction); zero posted
///      collateral reverts before the Morpho call. With usePrevHookAmount the calldata amount
///      word (max or otherwise) is ignored and the previous hook's output (denominated in the
///      collateral token) becomes the amount — the sentinel is therefore only reachable with
///      usePrevHookAmount = false. Publishes the measured collateral-token wallet delta with
///      outToken = collateralToken.
contract MorphoWithdrawCollateralHookV2 is BaseMorphoStandaloneLoanHookV2 {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param morpho_ Address of the Morpho Blue singleton
    constructor(address morpho_) BaseMorphoStandaloneLoanHookV2(morpho_, HookSubTypes.LOAN) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Morpho Withdraw Collateral V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Withdraws an exact or full collateral amount from a Morpho market without repaying";
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
        _requireYieldSourceIsMorpho(vars.yieldSource);
        MarketParams memory marketParams = _marketParams(vars);
        uint256 amount = _resolveReleaseAmount(prevHook, account, vars, marketParams);

        executions = new Execution[](1);
        executions[0] = Execution({
            target: vars.yieldSource,
            value: 0,
            callData: abi.encodeCall(IMorphoBase.withdrawCollateral, (marketParams, amount, account, account))
        });
    }

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev Single produced-token slot: the released collateral flows OUT of the provider to the
    ///      wallet
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        return _oneOutTokenRole();
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return _inspectMorphoV2(_decodeMorphoV2(data, true));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Resolves the release amount. PREV path: previous hook's output, denominated in the
    ///      collateral token (zero/max prev outputs revert inside _resolvePrevHookOutput); the
    ///      calldata word is ignored. Calldata path: exact word, or the type(uint256).max
    ///      sentinel resolving to the full posted collateral with a zero-position revert BEFORE
    ///      any Morpho call. Exact-path over-withdrawals are arbitrated by Morpho's underflow —
    ///      no position pre-read (mirrors the close hook's withdraw leg).
    /// @param prevHook The previous hook in the chain
    /// @param account The executing smart account
    /// @param vars The decoded hook parameters
    /// @param marketParams The Morpho market params derived from `vars`
    /// @return amount The exact collateral amount the withdrawCollateral call will move
    function _resolveReleaseAmount(
        address prevHook,
        address account,
        MorphoV2Vars memory vars,
        MarketParams memory marketParams
    )
        internal
        view
        returns (uint256 amount)
    {
        if (vars.usePrevHookAmount) return _resolvePrevHookOutput(prevHook, account, vars.collateralToken);
        if (vars.amount1 == 0) revert AMOUNT_NOT_VALID();
        if (vars.amount1 != type(uint256).max) return vars.amount1;
        amount = _positionCollateral(marketParams, account);
        if (amount == 0) revert AMOUNT_NOT_VALID();
    }

    /// @inheritdoc BaseHook
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        MorphoV2Vars memory vars = _decodeMorphoV2(data, true);
        _requireYieldSourceIsMorpho(vars.yieldSource);

        expectedPrimaryAmount = _resolveReleaseAmount(prevHook, account, vars, _marketParams(vars));
        _snapshotBalances(account, data);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _settleWithdrawCollateral(account, data);
    }
}
