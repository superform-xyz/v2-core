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

/// @title AaveV4BorrowHookV2
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 yieldSourceOracleId = data.extractYieldSourceOracleId(); // Superform Aave V4 YS oracle id
/// @notice         address yieldSource = data.extractYieldSource(); // computeMarketKey(spoke, supplyId, borrowId)
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address spoke = BytesLib.toAddress(data, 92);
/// @notice         uint256 supplyReserveId = BytesLib.toUint256(data, 112);
/// @notice         uint256 borrowReserveId = BytesLib.toUint256(data, 144);
/// @notice         uint256 borrowAmount = BytesLib.toUint256(data, 176); // exact loan assets
/// @notice         uint256 reserved = BytesLib.toUint256(data, 208); // must be zero
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 240);
/// @dev Standalone BORROW (LOAN): borrows an exact loan-asset amount from an Aave V4 spoke
///      against collateral already flagged on the account — no supply leg, no ratio/oracle
///      derivation inside the hook (whether the borrow is healthy is arbitrated solely by the
///      Spoke's health check, over every collateral-flagged reserve of the account). The account is
///      both onBehalfOf and receiver. With usePrevHookAmount the calldata amount word is ignored
///      and the previous hook's output (denominated in the loan token) becomes the amount.
///      Publishes the measured loan-token wallet delta with outToken = loanToken.
/// @dev The calldata supplyReserveId / collateralToken are IDENTITY ONLY for this hook — they are
///      bound to the Spoke like every V2 sibling so inspect() carries the full (spoke, supplyId,
///      borrowId) market identity, but the borrow itself does not touch that reserve.
contract AaveV4BorrowHookV2 is BaseAaveV4StandaloneLoanHookV2 {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() BaseAaveV4StandaloneLoanHookV2(HookSubTypes.LOAN) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Aave V4 Borrow V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Borrows an exact asset amount from an Aave V4 spoke against already-posted collateral";
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
        uint256 amount = _resolveExactPrimary(prevHook, account, vars.loanToken, vars.amount1, vars.usePrevHookAmount);

        executions = new Execution[](1);
        executions[0] = Execution({
            target: vars.spoke,
            value: 0,
            callData: abi.encodeCall(IAaveV4Spoke.borrow, (vars.borrowReserveId, amount, account))
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
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return _inspectAaveV4V2(_decodeAaveV4V2(data, true));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        AaveV4V2Vars memory vars = _decodeAndBind(data);
        expectedPrimaryAmount =
            _resolveExactPrimary(prevHook, account, vars.loanToken, vars.amount1, vars.usePrevHookAmount);
        _snapshotBalances(account, data);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _settleBorrow(account, data);
    }
}
