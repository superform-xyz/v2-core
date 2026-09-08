// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IPool } from "../../../vendor/aave-v3/IPool.sol";

// Superform
import { BaseLoanHook } from "../BaseLoanHook.sol";
import { BaseLoanHookV2 } from "../BaseLoanHookV2.sol";
import { ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title BaseAaveV3LoanHookV2
/// @author Superform Labs
/// @notice Base abstract hook for the V2 Aave V3 loan hooks (open / close / standalone repay)
/// @dev One canonical 178-byte layout is shared by all three Aave V3 V2 hooks
///      (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address pool = BytesLib.toAddress(data, 92);
/// @notice         uint8   interestRateMode = BytesLib.toUint8(data, 112); // must == 2
/// @notice         uint256 amount1 = BytesLib.toUint256(data, 113); // open: supply; close/repay: repay CAP
/// @notice         uint256 amount2 = BytesLib.toUint256(data, 145); // open: borrow; close: withdraw; repay: 0
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 177); // canonical 0x00/0x01
/// @dev Standalone repay reserves the amount2 word as zero, keeping one canonical provider layout
///      without advertising a second active leg.
///      The Pool address comes from calldata rather than the constructor, so a single hook
///      deployment works with every Aave V3 market on every chain.
///      SECURITY INVARIANT: onBehalfOf / to is always hardcoded to `account` — never arbitrary.
abstract contract BaseAaveV3LoanHookV2 is BaseLoanHookV2 {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant LOAN_TOKEN_OFFSET = 52;
    uint256 internal constant COLLATERAL_TOKEN_OFFSET = 72;
    uint256 internal constant POOL_OFFSET = 92;
    uint256 internal constant RATE_MODE_OFFSET = 112;
    uint256 internal constant AMOUNT1_OFFSET = 113;
    uint256 internal constant AMOUNT2_OFFSET = 145;
    uint256 internal constant USE_PREV_OFFSET = 177;

    /// @notice Exact hook-data length for every Aave V3 V2 loan hook
    uint256 internal constant AAVE_V3_V2_DATA_LENGTH = 178;

    /// @notice The only interest rate mode valid on live Aave V3 markets (stable removed in V3.2)
    uint8 internal constant VARIABLE_RATE_MODE = 2;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct AaveV3V2Vars {
        address loanToken;
        address collateralToken;
        address pool;
        uint256 amount1;
        uint256 amount2;
        bool usePrevHookAmount;
    }

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when interestRateMode != 2 (only variable is valid on Aave V3.2+)
    error INVALID_RATE_MODE();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice No constructor args — Pool address comes from calldata
    /// @param hookSubtype_ Hook subtype identifier (LOAN or LOAN_REPAY)
    constructor(bytes32 hookSubtype_) BaseLoanHookV2(hookSubtype_) { }

    /*//////////////////////////////////////////////////////////////
                       SIZING-INTERFACE PLUMBING
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseLoanHook
    /// @dev Aave V3 V2 layout stores usePrevHookAmount at offset 177 (not the Morpho-shaped 196).
    ///      Exact-length guard + strict canonical-boolean read so this view never disagrees with
    ///      execution-time decoding on malformed data (custom error instead of an OOB panic).
    function decodeUsePrevHookAmount(bytes memory data) external pure override returns (bool) {
        if (data.length != AAVE_V3_V2_DATA_LENGTH) revert INVALID_DATA_LENGTH();
        return _decodeStrictBool(data, USE_PREV_OFFSET);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev Single-slot default for the standalone repay hook: amount1 lives at offset 113 (not
    ///      the Morpho-shaped 132). Composite hooks override with two-slot versions.
    function decodeAmounts(bytes memory data) external pure virtual override returns (uint256[] memory amounts) {
        if (data.length != AAVE_V3_V2_DATA_LENGTH) revert INVALID_DATA_LENGTH();
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, AMOUNT1_OFFSET);
    }

    /// @inheritdoc ISuperHookOutflow
    /// @dev Single-slot default replacing amount1 at offset 113; composite hooks override
    function replaceCalldataAmounts(
        bytes memory data,
        uint256[] memory amounts
    )
        external
        pure
        virtual
        override
        returns (bytes memory)
    {
        if (data.length != AAVE_V3_V2_DATA_LENGTH) revert INVALID_DATA_LENGTH();
        if (amounts.length != 1) revert INVALID_AMOUNTS_LENGTH();
        return _replaceCalldataAmount(data, amounts[0], AMOUNT1_OFFSET);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Strictly decodes the canonical Aave V3 V2 layout.
    ///      Enforces: exact 178-byte length, nonzero addresses, distinct loan/collateral tokens,
    ///      interestRateMode == 2, canonical usePrevHookAmount boolean, and — when
    ///      `secondaryReserved` is true (standalone repay) — a zero amount2 word.
    /// @param data The hook data
    /// @param secondaryReserved True for standalone repay (amount2 must be zero)
    /// @return vars The decoded hook parameters
    function _decodeAaveV3V2(
        bytes memory data,
        bool secondaryReserved
    )
        internal
        pure
        returns (AaveV3V2Vars memory vars)
    {
        if (data.length != AAVE_V3_V2_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.pool = BytesLib.toAddress(data, POOL_OFFSET);

        if (vars.loanToken == address(0) || vars.collateralToken == address(0) || vars.pool == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        if (vars.loanToken == vars.collateralToken) revert IDENTICAL_TOKENS();
        if (BytesLib.toUint8(data, RATE_MODE_OFFSET) != VARIABLE_RATE_MODE) revert INVALID_RATE_MODE();

        vars.amount1 = BytesLib.toUint256(data, AMOUNT1_OFFSET);
        vars.amount2 = BytesLib.toUint256(data, AMOUNT2_OFFSET);
        vars.usePrevHookAmount = _decodeStrictBool(data, USE_PREV_OFFSET);

        // Reuse the already-decoded word instead of re-reading it
        if (secondaryReserved && vars.amount2 != 0) revert RESERVED_FIELD_NOT_ZERO();
    }

    /// @dev Returns the account's current variable-debt balance for the loan token on the pool
    function _variableDebtBalance(AaveV3V2Vars memory vars, address account) internal view returns (uint256) {
        address variableDebtToken = IPool(vars.pool).getReserveData(vars.loanToken).variableDebtTokenAddress;
        return IERC20(variableDebtToken).balanceOf(account);
    }

    /// @dev Returns the account's current aToken balance for the collateral token on the pool
    function _aTokenBalance(AaveV3V2Vars memory vars, address account) internal view returns (uint256) {
        address aToken = IPool(vars.pool).getReserveData(vars.collateralToken).aTokenAddress;
        return IERC20(aToken).balanceOf(account);
    }

    /// @dev Resolves the repay leg shared by AaveV3RepayHookV2 and AaveV3RepayAndWithdrawHookV2.
    ///      The primary word is a CAP: the resolved repayment is min(cap, current variable-debt
    ///      balance). Zero outstanding debt resolves to (0, true) — the repay leg is skipped —
    ///      instead of reverting, and the debt check precedes previous-hook resolution.
    ///      `repayAssets` is exact for the transaction because debt accrual is per-timestamp and
    ///      build, approval and repay execute in the same transaction. When `fullRepay`
    ///      (predicted clear), the repay call passes type(uint256).max so Aave clears the debt
    ///      natively (avoids 1-wei rayMul/rayDiv dust) while still pulling exactly `repayAssets`;
    ///      the approval always uses the resolved amount, never max.
    ///      CALLER CAVEAT: gate on `repayAssets == 0` BEFORE consulting `fullRepay` — zero debt
    ///      returns (0, true) and a repay(max) call must never be emitted with no debt.
    /// @param prevHook The previous hook in the chain
    /// @param account The executing smart account
    /// @param vars The decoded hook parameters
    /// @return repayAssets The exact debt-asset amount the repay call will pull (0 = leg skipped)
    /// @return fullRepay True when the resolved repayment clears the debt (repay(max) path)
    function _resolveRepayLeg(
        address prevHook,
        address account,
        AaveV3V2Vars memory vars
    )
        internal
        view
        returns (uint256 repayAssets, bool fullRepay)
    {
        (repayAssets, fullRepay) = _resolveRepayCap(
            prevHook, account, vars.loanToken, vars.amount1, vars.usePrevHookAmount, _variableDebtBalance(vars, account)
        );
    }

    /// @dev Full market-identity inspector payload: pool, loan token, collateral token and the
    ///      interest-rate mode. Amount fields, usePrevHookAmount and the strategy header are
    ///      intentionally excluded.
    /// @param vars The decoded hook parameters
    /// @return The packed inspector payload
    function _inspectAaveV3V2(AaveV3V2Vars memory vars) internal pure returns (bytes memory) {
        return abi.encodePacked(vars.pool, vars.loanToken, vars.collateralToken, VARIABLE_RATE_MODE);
    }
}
