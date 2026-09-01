// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IAaveV4Spoke } from "../../../vendor/aave-v4/IAaveV4Spoke.sol";

// Superform
import { BaseLoanHook } from "../BaseLoanHook.sol";
import { BaseLoanHookV2 } from "../BaseLoanHookV2.sol";
import { ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title BaseAaveV4LoanHookV2
/// @author Superform Labs
/// @notice Base abstract hook for the V2 Aave V4 Hub-and-Spoke loan hooks (open / close /
///         standalone repay)
/// @dev One canonical 241-byte layout is shared by all three Aave V4 V2 hooks
///      (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address spoke = BytesLib.toAddress(data, 92);
/// @notice         uint256 supplyReserveId = BytesLib.toUint256(data, 112);
/// @notice         uint256 borrowReserveId = BytesLib.toUint256(data, 144);
/// @notice         uint256 amount1 = BytesLib.toUint256(data, 176); // open: supply; close/repay: repay
/// @notice         uint256 amount2 = BytesLib.toUint256(data, 208); // open: borrow; close: withdraw; repay: 0
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 240); // canonical 0x00/0x01
/// @dev Standalone repay reserves the amount2 word as zero, keeping one canonical provider layout
///      without advertising a second active leg.
///      The Spoke address comes from calldata rather than the constructor, enabling a single hook
///      deployment to work with any Aave V4 Spoke.
///      Reserve/token binding: each reserve id is resolved through the Spoke's canonical
///      getReserve(reserveId).underlying and must match the token declared in calldata, otherwise
///      the hook reverts before any provider call.
///      SECURITY INVARIANT: onBehalfOf is always hardcoded to `account` — never arbitrary.
abstract contract BaseAaveV4LoanHookV2 is BaseLoanHookV2 {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant LOAN_TOKEN_OFFSET = 52;
    uint256 internal constant COLLATERAL_TOKEN_OFFSET = 72;
    uint256 internal constant SPOKE_OFFSET = 92;
    uint256 internal constant SUPPLY_RESERVE_ID_OFFSET = 112;
    uint256 internal constant BORROW_RESERVE_ID_OFFSET = 144;
    uint256 internal constant AMOUNT1_OFFSET = 176;
    uint256 internal constant AMOUNT2_OFFSET = 208;
    uint256 internal constant USE_PREV_OFFSET = 240;

    /// @notice Exact hook-data length for every Aave V4 V2 loan hook
    uint256 internal constant AAVE_V4_V2_DATA_LENGTH = 241;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct AaveV4V2Vars {
        address loanToken;
        address collateralToken;
        address spoke;
        uint256 supplyReserveId;
        uint256 borrowReserveId;
        uint256 amount1;
        uint256 amount2;
        bool usePrevHookAmount;
    }

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a reserve id's underlying does not match the declared token
    error TOKEN_RESERVE_MISMATCH();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice No constructor args — Spoke address comes from calldata
    /// @param hookSubtype_ Hook subtype identifier (LOAN or LOAN_REPAY)
    constructor(bytes32 hookSubtype_) BaseLoanHookV2(hookSubtype_) { }

    /*//////////////////////////////////////////////////////////////
                       SIZING-INTERFACE PLUMBING
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseLoanHook
    /// @dev Aave V4 V2 layout stores usePrevHookAmount at offset 240 (not the Morpho-shaped 196).
    ///      Exact-length guard + strict canonical-boolean read so this view never disagrees with
    ///      execution-time decoding on malformed data (custom error instead of an OOB panic).
    function decodeUsePrevHookAmount(bytes memory data) external pure override returns (bool) {
        if (data.length != AAVE_V4_V2_DATA_LENGTH) revert INVALID_DATA_LENGTH();
        return _decodeStrictBool(data, USE_PREV_OFFSET);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev Single-slot default for the standalone repay hook: amount1 lives at offset 176 (not
    ///      the Morpho-shaped 132). Composite hooks override with two-slot versions.
    function decodeAmounts(bytes memory data) external pure virtual override returns (uint256[] memory amounts) {
        if (data.length != AAVE_V4_V2_DATA_LENGTH) revert INVALID_DATA_LENGTH();
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, AMOUNT1_OFFSET);
    }

    /// @inheritdoc ISuperHookOutflow
    /// @dev Single-slot default replacing amount1 at offset 176; composite hooks override
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
        if (data.length != AAVE_V4_V2_DATA_LENGTH) revert INVALID_DATA_LENGTH();
        if (amounts.length != 1) revert INVALID_AMOUNTS_LENGTH();
        return _replaceCalldataAmount(data, amounts[0], AMOUNT1_OFFSET);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Strictly decodes the canonical Aave V4 V2 layout.
    ///      Enforces: exact 241-byte length, nonzero addresses, distinct loan/collateral tokens,
    ///      canonical usePrevHookAmount boolean, and — when `secondaryReserved` is true
    ///      (standalone repay) — a zero amount2 word. Reserve/token binding is validated
    ///      separately via _validateReserves (view) so this decoder stays pure for inspect().
    /// @param data The hook data
    /// @param secondaryReserved True for standalone repay (amount2 must be zero)
    /// @return vars The decoded hook parameters
    function _decodeAaveV4V2(
        bytes memory data,
        bool secondaryReserved
    )
        internal
        pure
        returns (AaveV4V2Vars memory vars)
    {
        if (data.length != AAVE_V4_V2_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.spoke = BytesLib.toAddress(data, SPOKE_OFFSET);

        if (vars.loanToken == address(0) || vars.collateralToken == address(0) || vars.spoke == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        if (vars.loanToken == vars.collateralToken) revert IDENTICAL_TOKENS();

        vars.supplyReserveId = BytesLib.toUint256(data, SUPPLY_RESERVE_ID_OFFSET);
        vars.borrowReserveId = BytesLib.toUint256(data, BORROW_RESERVE_ID_OFFSET);
        vars.amount1 = BytesLib.toUint256(data, AMOUNT1_OFFSET);
        vars.amount2 = BytesLib.toUint256(data, AMOUNT2_OFFSET);
        vars.usePrevHookAmount = _decodeStrictBool(data, USE_PREV_OFFSET);

        // Reuse the already-decoded word instead of re-reading it
        if (secondaryReserved && vars.amount2 != 0) revert RESERVED_FIELD_NOT_ZERO();
    }

    /// @dev Binds both reserve ids to the declared tokens through the Spoke's canonical
    ///      getReserve(reserveId).underlying; reverts before any provider call on mismatch
    function _validateReserves(AaveV4V2Vars memory vars) internal view {
        IAaveV4Spoke spoke = IAaveV4Spoke(vars.spoke);
        if (spoke.getReserve(vars.supplyReserveId).underlying != vars.collateralToken) {
            revert TOKEN_RESERVE_MISMATCH();
        }
        if (spoke.getReserve(vars.borrowReserveId).underlying != vars.loanToken) {
            revert TOKEN_RESERVE_MISMATCH();
        }
    }

    /// @dev Returns the account's total debt (drawn + premium) on the borrow reserve
    function _totalDebt(AaveV4V2Vars memory vars, address account) internal view returns (uint256) {
        (uint256 drawnDebt, uint256 premiumDebt) = IAaveV4Spoke(vars.spoke).getUserDebt(vars.borrowReserveId, account);
        return drawnDebt + premiumDebt;
    }

    /// @dev Returns the account's supplied assets on the supply reserve
    function _suppliedAssets(AaveV4V2Vars memory vars, address account) internal view returns (uint256) {
        return IAaveV4Spoke(vars.spoke).getUserSuppliedAssets(vars.supplyReserveId, account);
    }

    /// @dev Resolves the repay leg shared by AaveV4RepayHookV2 and AaveV4RepayAndWithdrawHookV2.
    ///      Reverts before any approval/provider call when the account has no outstanding debt,
    ///      when a full-repayment sentinel is combined with usePrevHookAmount, or when the
    ///      previous-hook output is invalid. For the sentinel, `repayAssets` resolves to the
    ///      account's total debt (drawn + premium) — exact for the transaction because build,
    ///      approval and repay execute in the same transaction.
    /// @param prevHook The previous hook in the chain
    /// @param account The executing smart account
    /// @param vars The decoded hook parameters
    /// @return repayAssets The exact debt-asset amount the repay call will pull
    /// @return fullRepay True when the sentinel selected a Spoke-native full repayment
    function _resolveRepayLeg(
        address prevHook,
        address account,
        AaveV4V2Vars memory vars
    )
        internal
        view
        returns (uint256 repayAssets, bool fullRepay)
    {
        uint256 debt = _totalDebt(vars, account);
        if (debt == 0) revert NO_OUTSTANDING_DEBT();

        fullRepay = vars.amount1 == type(uint256).max;
        if (fullRepay) {
            if (vars.usePrevHookAmount) revert MAX_WITH_PREV_NOT_ALLOWED();
            repayAssets = debt;
        } else {
            repayAssets =
                vars.usePrevHookAmount ? _resolvePrevHookOutput(prevHook, account, vars.loanToken) : vars.amount1;
            if (repayAssets == 0) revert AMOUNT_NOT_VALID();
        }
    }

    /// @dev Full market-identity inspector payload: spoke, loan token, collateral token and both
    ///      reserve ids. Amount fields, usePrevHookAmount and the strategy header are
    ///      intentionally excluded.
    function _inspectAaveV4V2(AaveV4V2Vars memory vars) internal pure returns (bytes memory) {
        return abi.encodePacked(
            vars.spoke, vars.loanToken, vars.collateralToken, vars.supplyReserveId, vars.borrowReserveId
        );
    }
}
