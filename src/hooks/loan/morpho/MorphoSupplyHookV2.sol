// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IMorphoBase, MarketParams } from "../../../vendor/morpho/IMorpho.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseMorphoStandaloneLoanHookV2 } from "./BaseMorphoStandaloneLoanHookV2.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title MorphoSupplyHookV2
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address oracle = BytesLib.toAddress(data, 92);
/// @notice         address irm = BytesLib.toAddress(data, 112);
/// @notice         uint256 collateralAmount = BytesLib.toUint256(data, 132); // exact assets to pledge
/// @notice         uint256 reserved = BytesLib.toUint256(data, 164); // must be zero
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 196);
/// @notice         uint256 lltv = BytesLib.toUint256(data, 197);
/// @notice         byte reserved2 = data[229]; // must be 0x00
/// @dev Standalone PLEDGE: supplies an exact collateral amount to a Morpho market and nothing
///      else — no borrow leg, no ratio/oracle derivation inside the hook. With usePrevHookAmount
///      the calldata amount word is ignored and the previous hook's output (denominated in the
///      collateral token) becomes the amount. Approvals are granted for the resolved amount and
///      reset to zero in the same transaction. This is a terminal hook: it spends the collateral
///      asset and publishes outAmount = 0 (outToken = collateralToken for classification) so a
///      downstream usePrevHookAmount consumer cannot mistake the spend for produced tokens; the
///      exact spend is still enforced against the measured wallet delta.
contract MorphoSupplyHookV2 is BaseMorphoStandaloneLoanHookV2 {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param morpho_ Address of the Morpho Blue singleton
    constructor(address morpho_) BaseMorphoStandaloneLoanHookV2(morpho_, HookSubTypes.LOAN) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Morpho Supply Collateral V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Supplies an exact collateral amount to a Morpho market without borrowing";
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
        uint256 amount =
            _resolveExactPrimary(prevHook, account, vars.collateralToken, vars.amount1, vars.usePrevHookAmount);

        MarketParams memory marketParams = _marketParams(vars);

        executions = new Execution[](4);
        executions[0] = Execution({
            target: vars.collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0))
        });
        executions[1] = Execution({
            target: vars.collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, amount))
        });
        executions[2] = Execution({
            target: morpho,
            value: 0,
            callData: abi.encodeCall(IMorphoBase.supplyCollateral, (marketParams, amount, account, ""))
        });
        // Reset approval after supply to prevent dangling allowance
        executions[3] = Execution({
            target: vars.collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0))
        });
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external view override returns (bytes memory) {
        return _inspectMorphoV2(_decodeMorphoV2(data, true));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        MorphoV2Vars memory vars = _decodeMorphoV2(data, true);

        expectedPrimaryAmount =
            _resolveExactPrimary(prevHook, account, vars.collateralToken, vars.amount1, vars.usePrevHookAmount);
        _snapshotBalances(account, data);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _settleSupplyCollateral(account, data);
    }
}
