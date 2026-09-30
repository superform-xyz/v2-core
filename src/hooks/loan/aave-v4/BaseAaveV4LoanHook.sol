// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IAaveV4Spoke } from "../../../vendor/aave-v4/IAaveV4Spoke.sol";

// Superform
import { BaseLoanHook } from "../BaseLoanHook.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { AaveV4ReserveKey } from "../../../libraries/AaveV4ReserveKey.sol";
import { ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title BaseAaveV4LoanHook
/// @author Superform Labs
/// @notice Base abstract hook for Aave V4 Hub-and-Spoke lending protocol integrations
/// @dev All Aave V4 hooks inherit from this contract. Unlike Morpho hooks, the Spoke address
///      comes from calldata rather than the constructor, enabling a single hook deployment to
///      work with any Aave V4 Spoke (Core, e-Mode, Isolation, RWA, Vault Spokes).
///      HEADER IDENTITY (SUP-21143): `yieldSource` (offset 32) MUST equal
///      `AaveV4ReserveKey.computeReserveKey(spoke, primaryReserveId)` (supply reserve for Supply /
///      Withdraw / SupplyAndBorrow / RepayAndWithdraw, borrow reserve for Borrow / Repay); every decoder
///      pins it (`AaveV4ReserveKey.RESERVE_KEY_MISMATCH`, on build(), preExecute() and inspect()) and every
///      `inspect()` packs it first; a zero oracle id is refused (ORACLE_ID_NOT_VALID). Flag-setting supplies refuse
///      an idle position (RESERVE_HAS_IDLE_POSITION) and withdraw legs refuse an un-flagged one
///      (RESERVE_NOT_COLLATERAL). The Spoke (offset 92) stays the only call target. `yieldSourceOracleId` (offset 0)
///      is identity only (LOAN is NONACCOUNTING).
///      SIZING APIs ARE TRANSFORMATION-ONLY (V1): `decodeAmounts` / `replaceCalldataAmounts` /
///      `decodeUsePrevHookAmount` read or rewrite the amount word(s) and do not run the header decoder
///      (unlike the V2 hooks, whose sizing views run the strict decoder). A template that sizes here has NOT
///      passed identity validation — it must also pass inspect() / build(). The V1 decoders keep their
///      inherited minimum-length and nonzero-byte-is-true boolean rules; V2 is exact-length / canonical-bool.
///      V1 hooks are not used for new roots; their bytecode changed with this bind (accepted).
///      SECURITY INVARIANT: onBehalfOf is always hardcoded to `account` — never arbitrary.
abstract contract BaseAaveV4LoanHook is BaseLoanHook {
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Aave V4 data layout byte offsets
    uint256 internal constant LOAN_TOKEN_OFFSET = 52;
    uint256 internal constant COLLATERAL_TOKEN_OFFSET = 72;
    uint256 internal constant SPOKE_OFFSET = 92;
    uint256 internal constant SUPPLY_RESERVE_ID_OFFSET = 112;
    uint256 internal constant BORROW_RESERVE_ID_OFFSET = 144;
    uint256 internal constant AAVE_V4_AMOUNT_OFFSET = 176;
    uint256 internal constant AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION = 208;
    /// @dev Byte 209 is used by TWO DIFFERENT data layouts (never both at once):
    ///      - SupplyAndBorrow: uint256 borrowAmount starts at 209 (no isFullRepayment field)
    ///      - RepayAndWithdraw: bool isFullRepayment at 209, then uint256 withdrawAmount at 210
    uint256 internal constant IS_FULL_REPAYMENT_OFFSET = 209;
    uint256 internal constant BORROW_AMOUNT_OFFSET = 209;
    uint256 internal constant WITHDRAW_AMOUNT_OFFSET = 210;

    /// @notice Minimum data lengths for validation
    uint256 internal constant SUPPLY_MIN_DATA_LENGTH = 209;
    uint256 internal constant WITHDRAW_MIN_DATA_LENGTH = 209;
    uint256 internal constant BORROW_MIN_DATA_LENGTH = 209;
    uint256 internal constant REPAY_MIN_DATA_LENGTH = 210;
    uint256 internal constant SUPPLY_AND_BORROW_MIN_DATA_LENGTH = 241;
    uint256 internal constant REPAY_AND_WITHDRAW_MIN_DATA_LENGTH = 242;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct SupplyHookLocalVars {
        address reserveKey;
        address loanToken;
        address collateralToken;
        address spoke;
        uint256 supplyReserveId;
        uint256 borrowReserveId; // identity only
        uint256 amount;
        bool usePrevHookAmount;
    }

    struct WithdrawHookLocalVars {
        address reserveKey;
        address loanToken;
        address collateralToken;
        address spoke;
        uint256 supplyReserveId;
        uint256 borrowReserveId; // identity only
        uint256 amount;
        bool usePrevHookAmount;
    }

    struct BorrowHookLocalVars {
        address reserveKey;
        address loanToken;
        address collateralToken;
        address spoke;
        uint256 supplyReserveId; // identity only
        uint256 borrowReserveId;
        uint256 amount;
        bool usePrevHookAmount;
    }

    struct RepayHookLocalVars {
        address reserveKey;
        address loanToken;
        address collateralToken;
        address spoke;
        uint256 supplyReserveId; // identity only
        uint256 borrowReserveId;
        uint256 amount;
        bool usePrevHookAmount;
        bool isFullRepayment;
    }

    struct SupplyAndBorrowHookLocalVars {
        address reserveKey;
        address loanToken;
        address collateralToken;
        address spoke;
        uint256 supplyReserveId;
        uint256 borrowReserveId;
        uint256 amount;
        bool usePrevHookAmount;
        uint256 borrowAmount;
    }

    struct RepayAndWithdrawHookLocalVars {
        address reserveKey;
        address loanToken;
        address collateralToken;
        address spoke;
        uint256 supplyReserveId;
        uint256 borrowReserveId;
        uint256 amount;
        bool usePrevHookAmount;
        bool isFullRepayment;
        uint256 withdrawAmount;
    }

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when hook calldata is shorter than the required minimum
    error INVALID_DATA_LENGTH();

    /// @notice Thrown when a supply that would flag the reserve as collateral targets a reserve already carrying an
    ///         un-flagged (idle MONEY_MARKET, ledger-tracked) position
    error RESERVE_HAS_IDLE_POSITION();

    /// @notice Thrown when the header `yieldSourceOracleId` (offset 0) is zero
    error ORACLE_ID_NOT_VALID();

    /// @notice Thrown when a withdraw leg (Withdraw, RepayAndWithdraw) targets a reserve that is not enabled as
    ///         collateral for the account — an un-flagged position is the idle MONEY_MARKET side's (ledger-tracked)
    error RESERVE_NOT_COLLATERAL();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice No constructor args — Spoke address comes from calldata
    /// @param hookSubtype_ Hook subtype identifier (LOAN or LOAN_REPAY)
    constructor(bytes32 hookSubtype_) BaseLoanHook(hookSubtype_) { }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseLoanHook
    /// @dev Overrides parent to use Aave V4 offset (156) instead of Morpho offset (144)
    function decodeUsePrevHookAmount(bytes memory data) external pure override returns (bool) {
        return _decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev Transformation-only: reads the amount word, does not authenticate the header (inspect / build do)
    function decodeAmounts(bytes memory data) external pure virtual override returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, AAVE_V4_AMOUNT_OFFSET);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory)
        external
        pure
        virtual
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
    }

    /// @inheritdoc ISuperHookOutflow
    /// @dev Transformation-only: rewrites the amount word and returns the rest of the payload — header included —
    ///      untouched and unchecked; a mis-keyed template still fails at inspect / build
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
        if (amounts.length != 1) revert INVALID_AMOUNTS_LENGTH();
        return _replaceCalldataAmount(data, amounts[0], AAVE_V4_AMOUNT_OFFSET);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Mode guard for the V1 flag-setting supplies (Supply, SupplyAndBorrow): a supplied position that is NOT
    ///      flagged as collateral belongs to the idle MONEY_MARKET side (ledger-tracked) and is refused
    ///      (RESERVE_HAS_IDLE_POSITION) on build() and preExecute(); a fresh or already-flagged reserve passes.
    /// @param spoke The calldata Spoke
    /// @param supplyReserveId The reserve the supply targets
    /// @param account The executing smart account
    function _requireNoIdlePosition(address spoke, uint256 supplyReserveId, address account) internal view {
        (bool flagged,) = IAaveV4Spoke(spoke).getUserReserveStatus(supplyReserveId, account);
        if (!flagged && IAaveV4Spoke(spoke).getUserSuppliedAssets(supplyReserveId, account) != 0) {
            revert RESERVE_HAS_IDLE_POSITION();
        }
    }

    /// @dev Gate for the V1 withdraw legs (Withdraw, RepayAndWithdraw), on build() and preExecute(): the account must
    ///      hold a position on the supply reserve (empty → AMOUNT_NOT_VALID) and it must be flagged as collateral
    ///      (RESERVE_NOT_COLLATERAL otherwise) — a V1 withdraw can never pay an idle, ledger-tracked position out.
    /// @param spoke The calldata Spoke
    /// @param supplyReserveId The reserve the withdraw targets
    /// @param account The executing smart account
    /// @return supplied The account's live supplied assets on the supply reserve
    function _requireCollateralPosition(address spoke, uint256 supplyReserveId, address account)
        internal
        view
        returns (uint256 supplied)
    {
        supplied = IAaveV4Spoke(spoke).getUserSuppliedAssets(supplyReserveId, account);
        if (supplied == 0) revert AMOUNT_NOT_VALID();
        (bool flagged,) = IAaveV4Spoke(spoke).getUserReserveStatus(supplyReserveId, account);
        if (!flagged) revert RESERVE_NOT_COLLATERAL();
    }

    /// @dev Inspector payload shared by every V1 hook, same 144-byte shape as the V2 family: reserve key
    ///      FIRST, then spoke, loan token, collateral token and both reserve ids
    function _inspectAaveV4(
        address reserveKey,
        address spoke,
        address loanToken,
        address collateralToken,
        uint256 supplyReserveId,
        uint256 borrowReserveId
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(reserveKey, spoke, loanToken, collateralToken, supplyReserveId, borrowReserveId);
    }

    /// @dev Decodes supply hook data
    function _decodeSupplyHookData(bytes memory data) internal pure returns (SupplyHookLocalVars memory vars) {
        if (data.length < SUPPLY_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        if (data.extractYieldSourceOracleId() == bytes32(0)) revert ORACLE_ID_NOT_VALID();
        vars.reserveKey = data.extractYieldSource();
        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.spoke = BytesLib.toAddress(data, SPOKE_OFFSET);

        if (
            vars.reserveKey == address(0) || vars.loanToken == address(0) || vars.collateralToken == address(0)
                || vars.spoke == address(0)
        ) {
            revert ADDRESS_NOT_VALID();
        }
        vars.supplyReserveId = BytesLib.toUint256(data, SUPPLY_RESERVE_ID_OFFSET);
        vars.borrowReserveId = BytesLib.toUint256(data, BORROW_RESERVE_ID_OFFSET);

        vars.amount = BytesLib.toUint256(data, AAVE_V4_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION);
        AaveV4ReserveKey.requireHeaderKey(vars.reserveKey, vars.spoke, vars.supplyReserveId);
    }

    /// @dev Decodes withdraw hook data (same layout as supply)
    function _decodeWithdrawHookData(bytes memory data) internal pure returns (WithdrawHookLocalVars memory vars) {
        if (data.length < WITHDRAW_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        if (data.extractYieldSourceOracleId() == bytes32(0)) revert ORACLE_ID_NOT_VALID();
        vars.reserveKey = data.extractYieldSource();
        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.spoke = BytesLib.toAddress(data, SPOKE_OFFSET);

        if (
            vars.reserveKey == address(0) || vars.loanToken == address(0) || vars.collateralToken == address(0)
                || vars.spoke == address(0)
        ) {
            revert ADDRESS_NOT_VALID();
        }
        vars.supplyReserveId = BytesLib.toUint256(data, SUPPLY_RESERVE_ID_OFFSET);
        vars.borrowReserveId = BytesLib.toUint256(data, BORROW_RESERVE_ID_OFFSET);

        vars.amount = BytesLib.toUint256(data, AAVE_V4_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION);
        AaveV4ReserveKey.requireHeaderKey(vars.reserveKey, vars.spoke, vars.supplyReserveId);
    }

    /// @dev Decodes borrow hook data — uses borrowReserveId (not supplyReserveId)
    function _decodeBorrowHookData(bytes memory data) internal pure returns (BorrowHookLocalVars memory vars) {
        if (data.length < BORROW_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        if (data.extractYieldSourceOracleId() == bytes32(0)) revert ORACLE_ID_NOT_VALID();
        vars.reserveKey = data.extractYieldSource();
        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.spoke = BytesLib.toAddress(data, SPOKE_OFFSET);

        if (
            vars.reserveKey == address(0) || vars.loanToken == address(0) || vars.collateralToken == address(0)
                || vars.spoke == address(0)
        ) {
            revert ADDRESS_NOT_VALID();
        }
        vars.supplyReserveId = BytesLib.toUint256(data, SUPPLY_RESERVE_ID_OFFSET);
        vars.borrowReserveId = BytesLib.toUint256(data, BORROW_RESERVE_ID_OFFSET);

        vars.amount = BytesLib.toUint256(data, AAVE_V4_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION);
        AaveV4ReserveKey.requireHeaderKey(vars.reserveKey, vars.spoke, vars.borrowReserveId);
    }

    /// @dev Decodes repay hook data — uses borrowReserveId + isFullRepayment
    function _decodeRepayHookData(bytes memory data) internal pure returns (RepayHookLocalVars memory vars) {
        if (data.length < REPAY_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        if (data.extractYieldSourceOracleId() == bytes32(0)) revert ORACLE_ID_NOT_VALID();
        vars.reserveKey = data.extractYieldSource();
        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.spoke = BytesLib.toAddress(data, SPOKE_OFFSET);

        if (
            vars.reserveKey == address(0) || vars.loanToken == address(0) || vars.collateralToken == address(0)
                || vars.spoke == address(0)
        ) {
            revert ADDRESS_NOT_VALID();
        }
        vars.supplyReserveId = BytesLib.toUint256(data, SUPPLY_RESERVE_ID_OFFSET);
        vars.borrowReserveId = BytesLib.toUint256(data, BORROW_RESERVE_ID_OFFSET);

        vars.amount = BytesLib.toUint256(data, AAVE_V4_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION);
        vars.isFullRepayment = _decodeBool(data, IS_FULL_REPAYMENT_OFFSET);
        AaveV4ReserveKey.requireHeaderKey(vars.reserveKey, vars.spoke, vars.borrowReserveId);
    }

    /// @dev Decodes supply-and-borrow hook data — uses BOTH reserveIds + borrowAmount at position 157
    function _decodeSupplyAndBorrowHookData(bytes memory data)
        internal
        pure
        returns (SupplyAndBorrowHookLocalVars memory vars)
    {
        if (data.length < SUPPLY_AND_BORROW_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        if (data.extractYieldSourceOracleId() == bytes32(0)) revert ORACLE_ID_NOT_VALID();
        vars.reserveKey = data.extractYieldSource();
        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.spoke = BytesLib.toAddress(data, SPOKE_OFFSET);

        if (
            vars.reserveKey == address(0) || vars.loanToken == address(0) || vars.collateralToken == address(0)
                || vars.spoke == address(0)
        ) {
            revert ADDRESS_NOT_VALID();
        }
        vars.supplyReserveId = BytesLib.toUint256(data, SUPPLY_RESERVE_ID_OFFSET);
        vars.borrowReserveId = BytesLib.toUint256(data, BORROW_RESERVE_ID_OFFSET);

        vars.amount = BytesLib.toUint256(data, AAVE_V4_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION);
        vars.borrowAmount = BytesLib.toUint256(data, BORROW_AMOUNT_OFFSET);
        AaveV4ReserveKey.requireHeaderKey(vars.reserveKey, vars.spoke, vars.supplyReserveId);
    }

    /// @dev Decodes repay-and-withdraw hook data — uses BOTH reserveIds + isFullRepayment + withdrawAmount
    function _decodeRepayAndWithdrawHookData(bytes memory data)
        internal
        pure
        returns (RepayAndWithdrawHookLocalVars memory vars)
    {
        if (data.length < REPAY_AND_WITHDRAW_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        if (data.extractYieldSourceOracleId() == bytes32(0)) revert ORACLE_ID_NOT_VALID();
        vars.reserveKey = data.extractYieldSource();
        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.spoke = BytesLib.toAddress(data, SPOKE_OFFSET);

        if (
            vars.reserveKey == address(0) || vars.loanToken == address(0) || vars.collateralToken == address(0)
                || vars.spoke == address(0)
        ) {
            revert ADDRESS_NOT_VALID();
        }
        vars.supplyReserveId = BytesLib.toUint256(data, SUPPLY_RESERVE_ID_OFFSET);
        vars.borrowReserveId = BytesLib.toUint256(data, BORROW_RESERVE_ID_OFFSET);

        vars.amount = BytesLib.toUint256(data, AAVE_V4_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION);
        vars.isFullRepayment = _decodeBool(data, IS_FULL_REPAYMENT_OFFSET);
        vars.withdrawAmount = BytesLib.toUint256(data, WITHDRAW_AMOUNT_OFFSET);
        AaveV4ReserveKey.requireHeaderKey(vars.reserveKey, vars.spoke, vars.supplyReserveId);
    }
}
