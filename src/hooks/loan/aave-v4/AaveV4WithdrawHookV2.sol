// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IAaveV4Spoke } from "../../../vendor/aave-v4/IAaveV4Spoke.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseAaveV4StandaloneLoanHookV2 } from "./BaseAaveV4StandaloneLoanHookV2.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookInspector, ISuperHookInflowOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title AaveV4WithdrawHookV2
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address spoke = BytesLib.toAddress(data, 92);
/// @notice         uint256 supplyReserveId = BytesLib.toUint256(data, 112);
/// @notice         uint256 borrowReserveId = BytesLib.toUint256(data, 144);
/// @notice         uint256 withdrawAmount = BytesLib.toUint256(data, 176); // exact collateral; max = all supplied
/// @notice         uint256 reserved = BytesLib.toUint256(data, 208); // must be zero
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 240);
/// @dev Standalone RELEASE (LOAN): withdraws collateral from an Aave V4 spoke and nothing else —
///      no repay leg (this is NOT the MONEY_MARKET AaveV4RedeemHook), no collateral-flag toggle, no
///      ratio/oracle derivation inside the hook; whether the remaining position stays healthy is
///      arbitrated solely by the Spoke's health check. The account is both onBehalfOf and receiver.
///      The account's supplied assets and collateral flag are read before any provider execution is
///      emitted: an empty position reverts; a position that is not flagged as collateral belongs to the idle
///      MONEY_MARKET side (ledger-tracked) and reverts RESERVE_NOT_COLLATERAL;
///      type(uint256).max resolves to the full supplied position and is passed through so the Spoke
///      withdraws everything natively (the pre-read is the exact expected receipt); an exact word or
///      previous-hook output above the position reverts — Aave would otherwise silently convert it
///      into a full withdrawal. Note the supply credit rounds down (≤ 1 wei of the pledge), so an
///      exact word equal to the pledged amount is above the position in the same block: size an
///      exact release from getUserSuppliedAssets or use the sentinel. With usePrevHookAmount the
///      calldata word (max or otherwise) is ignored and the previous hook's output (denominated in
///      the collateral token) becomes the amount, so the sentinel is only reachable with
///      usePrevHookAmount = false. Publishes the measured collateral-token wallet delta with
///      outToken = collateralToken.
/// @dev Mode marker caveat: "flag true" is taken as LOAN mode. The flag can also be set over an
///      un-flagged idle position by the composite AaveV4SupplyAndBorrowHookV2, the legacy V1 supply
///      hooks (both bytecode-locked, no idle guard) or a direct setUsingAsCollateral(true) self-call;
///      after that a RELEASE(max) pays the merged position out with no ledger outflow. Those entry
///      points are signed intents of the same account, never third parties, so the guard stays an
///      OMS routing rule: never route OPEN / V1 supply / PLEDGE onto an (account, spoke, reserveId)
///      that carries an idle position.
contract AaveV4WithdrawHookV2 is BaseAaveV4StandaloneLoanHookV2 {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() BaseAaveV4StandaloneLoanHookV2(HookSubTypes.LOAN) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Aave V4 Withdraw V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Withdraws an exact or full collateral amount from an Aave V4 spoke without repaying";
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
        (uint256 amount, bool fullWithdraw) = _resolveReleaseAmount(prevHook, account, vars);

        executions = new Execution[](1);
        executions[0] = Execution({
            target: vars.spoke,
            value: 0,
            callData: abi.encodeCall(
                IAaveV4Spoke.withdraw, (vars.supplyReserveId, fullWithdraw ? type(uint256).max : amount, account)
            )
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
        return _inspectAaveV4V2(_decodeAaveV4V2(data, true));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        AaveV4V2Vars memory vars = _decodeAndBind(data);
        (expectedPrimaryAmount,) = _resolveReleaseAmount(prevHook, account, vars);
        _snapshotBalances(account, data);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _settleWithdrawCollateral(account, data);
    }
}
