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

/// @title AaveV4LendHook
/// @author Superform Labs
/// @dev data has the following structure (exact 189 bytes; standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 yieldSourceOracleId = data.extractYieldSourceOracleId(); // Superform Aave V4 supply YS id
/// @notice         address yieldSource = data.extractYieldSource(); // computeMarketKey(spoke, supplyId, borrowId)
/// @notice         address underlying = BytesLib.toAddress(data, 52);
/// @notice         address spoke = BytesLib.toAddress(data, 72);
/// @notice         uint256 supplyReserveId = BytesLib.toUint256(data, 92);
/// @notice         uint256 amount = BytesLib.toUint256(data, 124); // underlying assets to supply
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 156);
/// @dev MONEY_MARKET / INFLOW. Idle supply into an Aave V4 reserve: `supply` only — this hook NEVER
///      calls `setUsingAsCollateral`, so the reserve stays a plain deposit (no collateral bit, no
///      debt). For a collateral pledge use the standalone AaveV4SupplyHookV2 (LOAN, SUP-21141). See
///      BaseAaveV4MoneyMarketHook for the header identity (the MARKET key at offset 32), the fail-closed
///      allowlist and the mode guards: a reserve the account has flagged as collateral OR already
///      borrows is refused (RESERVE_IS_COLLATERAL / RESERVE_IS_BORROWED); the redeem hook applies only
///      the collateral rule so an exit is never trapped.
/// @dev Accounting: V4 spokes have no share token and the Superform supply oracle is identity PPS, so
///      outAmount is the SUPPLIED-ASSETS DELTA read from the Spoke (`getUserSuppliedAssets`), i.e. the
///      exact units the oracle prices — a later redeem's `usedShares` (the same read) nets the ledger to
///      zero. The wallet spend is separately asserted to equal `amount` (DELTA_MISMATCH otherwise).
///      Aave rounds the credited position DOWN by up to 1 wei of the spend; that is expected and never
///      equated with the spend.
/// @dev OMS sizing: one IN / ASSETS slot at offset 124 (underlying wei), the same value-flow as an
///      ERC-4626 deposit; the 1:1 share side is the measured outAmount.
/// @dev WARNING: outToken is the header MARKET KEY (a codeless pseudo-address), not the underlying,
///      mirroring MorphoLendHook. Asset-denominated downstream hooks that verify the previous output
///      token fail closed; legacy usePrevHookAmount consumers without a token check would receive the
///      supplied-assets figure (<= 1 wei below the spend). Chain only into AaveV4RedeemHook.
contract AaveV4LendHook is BaseAaveV4MoneyMarketHook {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @dev INFLOW: SuperExecutor posts outAmount (supplied assets credited) to SuperLedger keyed by
    ///      the header market key, never by the Spoke.
    constructor() BaseAaveV4MoneyMarketHook(ISuperHook.HookType.INFLOW) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Aave V4 Lend";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Lends assets to an Aave V4 reserve without enabling collateral";
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
        _requireIdleLendable(vars, account);

        uint256 amount = _resolveIdleAmount(prevHook, account, vars, vars.underlying);
        if (amount == 0 || amount == type(uint256).max) revert AMOUNT_NOT_VALID();

        executions = new Execution[](4);
        // 1. Reset approval (handles USDT)
        executions[0] =
            Execution({ target: vars.underlying, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.spoke, 0)) });
        // 2. Approve exactly the supply amount
        executions[1] = Execution({
            target: vars.underlying, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.spoke, amount))
        });
        // 3. Supply as idle lender. NO setUsingAsCollateral — the reserve must stay non-collateral.
        executions[2] = Execution({
            target: vars.spoke,
            value: 0,
            callData: abi.encodeCall(IAaveV4Spoke.supply, (vars.supplyReserveId, amount, account))
        });
        // 4. Reset approval after supply to prevent dangling allowance
        executions[3] =
            Execution({ target: vars.underlying, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.spoke, 0)) });
    }

    /// @inheritdoc ISuperHookInspector
    /// @dev Identity = market key + spoke + underlying + supplyReserveId (92 bytes). Changes when any
    ///      of those change; unchanged when only amount / usePrevHookAmount change.
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return _inspectIdle(_decodeIdle(data));
    }

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev One IN / ASSETS slot (underlying wei supplied). Overrides BaseLoanHook's IN / TOKEN default.
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(
            ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.ASSETS
        );
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    /// @dev Resolves the exact spend, records the fee asset (underlying), snapshots the wallet
    ///      balance and the supplied-assets position (outAmount baseline).
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        IdleVars memory vars = _decodeIdle(data);
        _requireUnderlyingMatchesReserve(vars);
        _requireIdleLendable(vars, account);

        uint256 amount = _resolveIdleAmount(prevHook, account, vars, vars.underlying);
        if (amount == 0 || amount == type(uint256).max) revert AMOUNT_NOT_VALID();

        expectedPrimaryAmount = amount;
        asset = vars.underlying;
        preLoanTokenBalance = IERC20(vars.underlying).balanceOf(account);
        _setOutAmount(_suppliedAssets(vars, account), account);
    }

    /// @inheritdoc BaseHook
    /// @dev Wallet spend must equal the resolved amount exactly; outAmount = supplied-assets credited
    ///      (position after - before, in oracle units); outToken = the header market key.
    function _postExecute(address, address account, bytes calldata data) internal override {
        IdleVars memory vars = _decodeIdle(data);

        uint256 spent = _balanceDecrease(preLoanTokenBalance, IERC20(vars.underlying).balanceOf(account));
        if (spent != expectedPrimaryAmount) revert DELTA_MISMATCH(expectedPrimaryAmount, spent);

        uint256 credited = _balanceIncrease(getOutAmount(account), _suppliedAssets(vars, account));
        // Only reachable when the spend rounds down to nothing (1-wei supply); never post a zero inflow.
        if (credited == 0) revert AMOUNT_NOT_VALID();

        _setOutAmount(credited, account);
        _setOutToken(vars.marketKey, account);
    }
}
