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

/// @title MorphoBorrowHookV2
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address oracle = BytesLib.toAddress(data, 92);
/// @notice         address irm = BytesLib.toAddress(data, 112);
/// @notice         uint256 borrowAmount = BytesLib.toUint256(data, 132); // exact loan assets (shares = 0)
/// @notice         uint256 reserved = BytesLib.toUint256(data, 164); // must be zero
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 196);
/// @notice         uint256 lltv = BytesLib.toUint256(data, 197);
/// @notice         byte reserved2 = data[229]; // must be 0x00
/// @dev Standalone BORROW: borrows an exact loan-asset amount from a Morpho market against
///      collateral already posted — no supply leg, no ratio/oracle derivation inside the hook
///      (whether the borrow is healthy is arbitrated solely by Morpho's own health check). The
///      account is both onBehalf and receiver. With usePrevHookAmount the calldata amount word is
///      ignored and the previous hook's output (denominated in the loan token) becomes the
///      amount. Publishes the measured loan-token wallet delta with outToken = loanToken.
/// @dev Thin-market caveat (inherited from the V1 borrow hook): Morpho borrow-share pricing can
///      be manipulated on near-empty markets for dust amounts (< ~1e4 assets); the bundler must
///      not route borrows to thin markets.
contract MorphoBorrowHookV2 is BaseMorphoStandaloneLoanHookV2 {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param morpho_ Address of the Morpho Blue singleton
    constructor(address morpho_) BaseMorphoStandaloneLoanHookV2(morpho_, HookSubTypes.LOAN) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Morpho Borrow V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Borrows an exact asset amount from a Morpho market against already-posted collateral";
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
        uint256 amount = _resolveExactPrimary(prevHook, account, vars.loanToken, vars.amount1, vars.usePrevHookAmount);

        MarketParams memory marketParams = _marketParams(vars);

        executions = new Execution[](1);
        executions[0] = Execution({
            target: morpho,
            value: 0,
            callData: abi.encodeCall(IMorphoBase.borrow, (marketParams, amount, 0, account, account))
        });
    }

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev Single produced-token slot: the borrowed loan assets flow OUT of the provider to the
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
            _resolveExactPrimary(prevHook, account, vars.loanToken, vars.amount1, vars.usePrevHookAmount);
        _snapshotBalances(account, data);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _settleBorrow(account, data);
    }
}
