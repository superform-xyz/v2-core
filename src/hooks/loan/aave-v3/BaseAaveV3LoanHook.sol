// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";

// Superform
import { BaseLoanHook } from "../BaseLoanHook.sol";
import { ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title BaseAaveV3LoanHook
/// @author Superform Labs
/// @notice Base abstract hook for Aave V3 lending integrations.
/// @dev All Aave V3 hooks inherit from this contract. Like the V4 suite, the Pool address comes from
///      calldata rather than the constructor, so a single hook deployment works with every Aave V3
///      market (Core / Prime / EtherFi / …) on every chain. Aave V3 keys operations on the asset
///      address (not a reserveId), so the layout drops V4's two reserveId slots and adds a pool
///      address at offset 92 plus a single interestRateMode byte (validated == 2; stable rate was
///      removed in V3.2).
///      SECURITY INVARIANT: onBehalfOf / to is always hardcoded to `account` — never arbitrary.
abstract contract BaseAaveV3LoanHook is BaseLoanHook {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/
    // Shared header (mandated by BaseLoanHook: loanToken@52, collateralToken@72)
    uint256 internal constant LOAN_TOKEN_OFFSET = 52;
    uint256 internal constant COLLATERAL_TOKEN_OFFSET = 72;
    uint256 internal constant POOL_OFFSET = 92;

    // Supply / Withdraw (single asset, no rate byte)
    uint256 internal constant SW_AMOUNT_OFFSET = 112;
    uint256 internal constant SW_USE_PREV_OFFSET = 144;
    uint256 internal constant SW_MIN_LEN = 145;

    // Borrow / Repay / RepayWithATokens (rate byte + single amount)
    uint256 internal constant RATE_MODE_OFFSET = 112;
    uint256 internal constant BR_AMOUNT_OFFSET = 113;
    uint256 internal constant BR_USE_PREV_OFFSET = 145;
    uint256 internal constant BR_MIN_LEN = 146;

    // Combined (rate byte + two amounts)
    uint256 internal constant CB_AMOUNT1_OFFSET = 113;
    uint256 internal constant CB_AMOUNT2_OFFSET = 145;
    uint256 internal constant CB_USE_PREV_OFFSET = 177;
    uint256 internal constant CB_MIN_LEN = 178;

    /// @notice The only interest rate mode valid on live Aave V3 markets (stable removed in V3.2).
    uint8 internal constant VARIABLE_RATE_MODE = 2;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct SupplyWithdrawVars {
        address loanToken;
        address collateralToken;
        address pool;
        uint256 amount;
        bool usePrevHookAmount;
    }

    struct BorrowRepayVars {
        address loanToken;
        address collateralToken;
        address pool;
        uint8 interestRateMode;
        uint256 amount;
        bool usePrevHookAmount;
    }

    struct SupplyAndBorrowVars {
        address loanToken;
        address collateralToken;
        address pool;
        uint8 interestRateMode;
        uint256 supplyAmount;
        uint256 borrowAmount;
        bool usePrevHookAmount;
    }

    struct RepayAndWithdrawVars {
        address loanToken;
        address collateralToken;
        address pool;
        uint8 interestRateMode;
        uint256 repayAmount;
        uint256 withdrawAmount;
        bool usePrevHookAmount;
    }

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when hook calldata is shorter than the required minimum
    error INVALID_DATA_LENGTH();
    /// @notice Thrown when interestRateMode != 2 (only variable is valid on Aave V3.2+)
    error INVALID_RATE_MODE();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @notice No constructor args — Pool address comes from calldata
    /// @param hookSubtype_ Hook subtype identifier (LOAN or LOAN_REPAY)
    constructor(bytes32 hookSubtype_) BaseLoanHook(hookSubtype_) { }

    /*//////////////////////////////////////////////////////////////
                       SIZING-INTERFACE PLUMBING
    //////////////////////////////////////////////////////////////*/
    /// @dev Single-amount families select their offsets via these accessors; combined hooks override
    ///      decodeAmounts/replaceCalldataAmounts/amountRoles directly.
    function _amountOffset() internal pure virtual returns (uint256) {
        return SW_AMOUNT_OFFSET;
    }

    function _usePrevOffset() internal pure virtual returns (uint256) {
        return SW_USE_PREV_OFFSET;
    }

    /// @inheritdoc BaseLoanHook
    function decodeUsePrevHookAmount(bytes memory data) external pure virtual override returns (bool) {
        return _decodeBool(data, _usePrevOffset());
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure virtual override returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, _amountOffset());
    }

    /// @inheritdoc ISuperHookOutflow
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
        return _replaceCalldataAmount(data, amounts[0], _amountOffset());
    }

    /*//////////////////////////////////////////////////////////////
                            DECODERS
    //////////////////////////////////////////////////////////////*/
    function _decodeSupplyWithdraw(bytes memory data) internal pure returns (SupplyWithdrawVars memory v) {
        if (data.length < SW_MIN_LEN) revert INVALID_DATA_LENGTH();
        v.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        v.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        v.pool = BytesLib.toAddress(data, POOL_OFFSET);
        if (v.loanToken == address(0) || v.collateralToken == address(0) || v.pool == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        v.amount = BytesLib.toUint256(data, SW_AMOUNT_OFFSET);
        v.usePrevHookAmount = _decodeBool(data, SW_USE_PREV_OFFSET);
    }

    function _decodeBorrowRepay(bytes memory data) internal pure returns (BorrowRepayVars memory v) {
        if (data.length < BR_MIN_LEN) revert INVALID_DATA_LENGTH();
        v.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        v.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        v.pool = BytesLib.toAddress(data, POOL_OFFSET);
        if (v.loanToken == address(0) || v.collateralToken == address(0) || v.pool == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        v.interestRateMode = BytesLib.toUint8(data, RATE_MODE_OFFSET);
        if (v.interestRateMode != VARIABLE_RATE_MODE) revert INVALID_RATE_MODE();
        v.amount = BytesLib.toUint256(data, BR_AMOUNT_OFFSET);
        v.usePrevHookAmount = _decodeBool(data, BR_USE_PREV_OFFSET);
    }

    function _decodeSupplyAndBorrow(bytes memory data) internal pure returns (SupplyAndBorrowVars memory v) {
        if (data.length < CB_MIN_LEN) revert INVALID_DATA_LENGTH();
        v.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        v.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        v.pool = BytesLib.toAddress(data, POOL_OFFSET);
        if (v.loanToken == address(0) || v.collateralToken == address(0) || v.pool == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        v.interestRateMode = BytesLib.toUint8(data, RATE_MODE_OFFSET);
        if (v.interestRateMode != VARIABLE_RATE_MODE) revert INVALID_RATE_MODE();
        v.supplyAmount = BytesLib.toUint256(data, CB_AMOUNT1_OFFSET);
        v.borrowAmount = BytesLib.toUint256(data, CB_AMOUNT2_OFFSET);
        v.usePrevHookAmount = _decodeBool(data, CB_USE_PREV_OFFSET);
    }

    function _decodeRepayAndWithdraw(bytes memory data) internal pure returns (RepayAndWithdrawVars memory v) {
        if (data.length < CB_MIN_LEN) revert INVALID_DATA_LENGTH();
        v.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        v.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        v.pool = BytesLib.toAddress(data, POOL_OFFSET);
        if (v.loanToken == address(0) || v.collateralToken == address(0) || v.pool == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        v.interestRateMode = BytesLib.toUint8(data, RATE_MODE_OFFSET);
        if (v.interestRateMode != VARIABLE_RATE_MODE) revert INVALID_RATE_MODE();
        v.repayAmount = BytesLib.toUint256(data, CB_AMOUNT1_OFFSET);
        v.withdrawAmount = BytesLib.toUint256(data, CB_AMOUNT2_OFFSET);
        v.usePrevHookAmount = _decodeBool(data, CB_USE_PREV_OFFSET);
    }
}
