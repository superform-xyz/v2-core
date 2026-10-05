// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IAaveV4Spoke } from "../../../vendor/aave-v4/IAaveV4Spoke.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseAaveV4MoneyMarketHook } from "./BaseAaveV4MoneyMarketHook.sol";
import { ISuperHook, ISuperHookInspector, ISuperHookInflowOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title AaveV4RedeemHook
/// @author Superform Labs
/// @dev data has the following structure (exact 189 bytes; standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 yieldSourceOracleId = data.extractYieldSourceOracleId(); // Superform Aave V4 supply YS id
/// @notice         address yieldSource = data.extractYieldSource(); // computeMarketKey(spoke, supplyId, borrowId)
/// @notice         address underlying = BytesLib.toAddress(data, 52);
/// @notice         address spoke = BytesLib.toAddress(data, 72);
/// @notice         uint256 supplyReserveId = BytesLib.toUint256(data, 92);
/// @notice         uint256 amount = BytesLib.toUint256(data, 124); // share wei (1:1); > supplied or max = full
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 156);
/// @dev MONEY_MARKET / OUTFLOW. Redeems idle supply from an Aave V4 reserve: `withdraw` only — no
///      repay and no collateral toggle. A non-collateral idle supply withdraws partially and fully
///      without any `setUsingAsCollateral(false)` call (verified on the live Base and Ethereum spokes).
///      If the reserve was made collateral elsewhere and backs debt, the Spoke enforces its own health
///      factor and may revert; this hook never changes the flag. See BaseAaveV4MoneyMarketHook for the
///      header identity (the MARKET key at offset 32).
/// @dev Accounting: outAmount = underlying received in the wallet, asserted to equal exactly
///      min(amount, supplied-before) (exact-in withdraw pays `amount`; full withdrawal pays the pre-read
///      supplied assets); `usedShares` = supplied-assets position consumed (before - after), the same
///      oracle units the lend hook credited, so the ledger nets to zero. Partial withdraws may consume
///      `amount +/- 1 wei` of position through share rounding — usedShares is never equated with the
///      wallet receipt. outToken = underlying (a real ERC-20), so this hook chains cleanly into swaps
///      and deposits.
/// @dev OMS sizing: one IN / SHARES slot at offset 124 (1:1 share wei). A previous hook feeding this
///      slot must have produced the SAME market key as its output token (so lend and redeem must name the same market,
/// not merely the same reserve — a different borrow leg reverts PREV_TOKEN_MISMATCH) (i.e. AaveV4LendHook); a chained
/// full withdrawal is impossible by design (the prev pipe rejects max) — use an explicit max in
///      calldata.
contract AaveV4RedeemHook is BaseAaveV4MoneyMarketHook {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @dev OUTFLOW: SuperExecutor posts outAmount (underlying received) and `usedShares` (supplied
    ///      assets consumed) to SuperLedger keyed by the header market key, and charges any
    ///      realized-profit fee in `asset` (the underlying). feePercent is 0 by operational invariant.
    constructor() BaseAaveV4MoneyMarketHook(ISuperHook.HookType.OUTFLOW) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Aave V4 Redeem";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Redeems idle supply from an Aave V4 reserve";
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
        IdleVars memory vars = _decodeIdle(data);
        _requireUnderlyingMatchesReserve(vars);
        _requireNotCollateral(vars, account);

        uint256 amount = _resolveIdleAmount(prevHook, account, vars, vars.marketKey);
        if (amount == 0) revert AMOUNT_NOT_VALID();

        // type(uint256).max (or any amount above the supplied position) passes straight through as a
        // full withdrawal, per the Spoke's own semantics. No approvals, no collateral toggle.
        executions = new Execution[](1);
        executions[0] = Execution({
            target: vars.spoke,
            value: 0,
            callData: abi.encodeCall(IAaveV4Spoke.withdraw, (vars.supplyReserveId, amount, account))
        });
    }

    /// @inheritdoc ISuperHookInspector
    /// @dev Identity = market key + spoke + underlying + supplyReserveId (92 bytes) — identical bytes to
    ///      AaveV4LendHook for the same reserve.
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return _inspectIdle(_decodeIdle(data));
    }

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev One IN / SHARES slot (1:1 share wei consumed). Overrides BaseLoanHook's IN / TOKEN default.
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(
            ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.SHARES
        );
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    /// @dev Requires an existing position, resolves the exact receipt (min(amount, supplied)), records
    ///      the fee asset (underlying), snapshots the wallet balance (outAmount baseline) and the
    ///      supplied-assets position (usedShares baseline).
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        IdleVars memory vars = _decodeIdle(data);
        _requireUnderlyingMatchesReserve(vars);
        _requireNotCollateral(vars, account);

        uint256 suppliedBefore = _suppliedAssets(vars, account);
        // Nothing to redeem: fail closed rather than post a zero outflow.
        if (suppliedBefore == 0) revert AMOUNT_NOT_VALID();

        uint256 amount = _resolveIdleAmount(prevHook, account, vars, vars.marketKey);
        if (amount == 0) revert AMOUNT_NOT_VALID();

        expectedPrimaryAmount = amount > suppliedBefore ? suppliedBefore : amount;
        asset = vars.underlying;
        preLoanTokenBalance = IERC20(vars.underlying).balanceOf(account);
        usedShares = suppliedBefore;
    }

    /// @inheritdoc BaseHook
    /// @dev Wallet receipt must equal the resolved amount exactly; usedShares = position consumed
    ///      (before - after); outToken = the underlying.
    function _postExecute(address, address account, bytes calldata data) internal override {
        IdleVars memory vars = _decodeIdle(data);

        uint256 received = _balanceIncrease(preLoanTokenBalance, IERC20(vars.underlying).balanceOf(account));
        if (received != expectedPrimaryAmount) revert DELTA_MISMATCH(expectedPrimaryAmount, received);

        uint256 suppliedAfter = _suppliedAssets(vars, account);
        if (suppliedAfter > usedShares) revert NEGATIVE_BALANCE_DELTA();
        usedShares -= suppliedAfter;

        _setOutAmount(received, account);
        _setOutToken(vars.underlying, account);
    }
}
