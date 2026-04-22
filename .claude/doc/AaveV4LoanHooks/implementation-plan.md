# Aave V4 Loan Hooks - Implementation Plan

## Overview

Build 6 lending protocol hooks for Aave V4's Hub-and-Spoke architecture on Ethereum mainnet, following the established Morpho loan hook patterns in `src/hooks/loan/morpho/`.

**Reference Morpho files studied:**
- `src/hooks/loan/BaseLoanHook.sol` -- parent of all loan hooks
- `src/hooks/loan/morpho/BaseMorphoLoanHook.sol` -- protocol-specific base
- `src/hooks/loan/morpho/MorphoSupplyHook.sol`
- `src/hooks/loan/morpho/MorphoWithdrawHook.sol`
- `src/hooks/loan/morpho/MorphoBorrowHook.sol`
- `src/hooks/loan/morpho/MorphoRepayHook.sol`
- `src/hooks/loan/morpho/MorphoSupplyAndBorrowHook.sol`
- `src/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol`
- `test/unit/hooks/loan/MorphoLoanHooks.t.sol`

---

## Architecture

```
BaseHook (NONACCOUNTING)
  |
  v
BaseLoanHook (ISuperHookLoans, defines AMOUNT_POSITION=80, USE_PREV_HOOK_AMOUNT_POSITION=144)
  |
  v
BaseAaveV4LoanHook (overrides offsets, decode functions, NO constructor storage)
  |
  +-- AaveV4SupplyHook          (HookSubTypes.LOAN)
  +-- AaveV4WithdrawHook        (HookSubTypes.LOAN_REPAY)
  +-- AaveV4BorrowHook          (HookSubTypes.LOAN)
  +-- AaveV4RepayHook           (HookSubTypes.LOAN_REPAY)
  +-- AaveV4SupplyAndBorrowHook (HookSubTypes.LOAN)
  +-- AaveV4RepayAndWithdrawHook(HookSubTypes.LOAN_REPAY)
```

---

## CRITICAL: Data Layout & Offset Override Issue

BaseLoanHook defines these constants that are referenced by its own methods:
```solidity
uint256 internal constant AMOUNT_POSITION = 80;                  // Used by _decodeAmount()
uint256 internal constant USE_PREV_HOOK_AMOUNT_POSITION = 144;   // Used by decodeUsePrevHookAmount()
```

The Aave V4 data layout places fields at DIFFERENT positions because we insert `spoke` (address, 20 bytes) and two `reserveId` fields (uint256, 32 bytes each) before the amount:

```
Morpho layout:   loanToken(0) | collateral(20) | oracle(40) | irm(60) | amount(80) | lltv(112) | usePrev(144) | isFull(145)
Aave V4 layout:  loanToken(0) | collateral(20) | spoke(40)  | supplyReserveId(60) | borrowReserveId(92) | amount(124) | usePrev(156) | isFull(157)
```

**Since Solidity constants cannot be overridden by inheritance** (child constants shadow parent constants but parent methods still reference their own constants), BaseAaveV4LoanHook MUST:

1. **Override `decodeUsePrevHookAmount(bytes memory data)`** -- the external function from BaseLoanHook that calls `_decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION)`. The override will call `_decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION)` with the Aave-specific offset 156.

2. **Override `_decodeAmount(bytes memory data)`** -- the internal function from BaseLoanHook. The override will use offset 124 instead of 80.

Both parent functions are `internal pure` / `external pure`, and the override can work cleanly because Solidity allows overriding virtual functions. However, `_decodeAmount` is NOT marked `virtual` in BaseLoanHook. Looking at the code, `_decodeAmount` is just `internal pure` without `virtual`. This means **we cannot override it**.

**Solution**: Do NOT call `_decodeAmount()` from BaseAaveV4LoanHook or its children. Instead, define new decode functions (e.g., `_decodeAaveV4Amount()`) and use them directly. The concrete hooks will call these new functions, not the inherited `_decodeAmount()`.

For `decodeUsePrevHookAmount`, this IS a public/external function. Looking at BaseLoanHook:
```solidity
function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
    return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
}
```
This is NOT virtual either. So BaseAaveV4LoanHook MUST add a new implementation. Since ISuperHookLoans/ISuperHookContextAware requires this function to exist, and it's inherited, the child CANNOT redeclare it.

**Revised Solution**: BaseAaveV4LoanHook's concrete decode functions will use the correct offsets internally. The inherited `decodeUsePrevHookAmount` and `_decodeAmount` will exist but **should never be called by Aave V4 hooks** -- they will use the protocol-specific decode functions that return the full struct. The inherited functions returning wrong offsets are a documentation concern but NOT a runtime issue, because:
- `_decodeAmount()` is internal and only called if explicitly used -- Aave V4 hooks will not call it
- `decodeUsePrevHookAmount()` is external and may be called by the off-chain system

**IMPORTANT**: We need `decodeUsePrevHookAmount` to work correctly for the off-chain bundler. Since we cannot override it, we should make the BaseLoanHook version virtual. This requires a **one-line change to BaseLoanHook.sol**.

### Proposed BaseLoanHook Change

In `src/hooks/loan/BaseLoanHook.sol`, make `decodeUsePrevHookAmount` virtual:

```solidity
// BEFORE:
function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
    return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
}

// AFTER:
function decodeUsePrevHookAmount(bytes memory data) external pure virtual returns (bool) {
    return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
}
```

Then BaseAaveV4LoanHook can override it:
```solidity
function decodeUsePrevHookAmount(bytes memory data) external pure override returns (bool) {
    return _decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION);
}
```

**Risk assessment of this change**: Adding `virtual` to an existing function is backwards-compatible. All existing Morpho hooks that rely on this function will still work identically. No ABI change, no behavior change for existing code. Low risk.

---

## Files to Create/Change

### New Files (8 files)

| # | File | Purpose |
|---|------|---------|
| 1 | `src/vendor/aave-v4/IAaveV4Spoke.sol` | Minimal interface for Aave V4 Spoke |
| 2 | `src/hooks/loan/aave-v4/BaseAaveV4LoanHook.sol` | Protocol-specific base |
| 3 | `src/hooks/loan/aave-v4/AaveV4SupplyHook.sol` | Supply collateral |
| 4 | `src/hooks/loan/aave-v4/AaveV4WithdrawHook.sol` | Withdraw collateral |
| 5 | `src/hooks/loan/aave-v4/AaveV4BorrowHook.sol` | Borrow loan tokens |
| 6 | `src/hooks/loan/aave-v4/AaveV4RepayHook.sol` | Repay loan tokens |
| 7 | `src/hooks/loan/aave-v4/AaveV4SupplyAndBorrowHook.sol` | Combined supply+borrow |
| 8 | `src/hooks/loan/aave-v4/AaveV4RepayAndWithdrawHook.sol` | Combined repay+withdraw |

### New Test File (1 file)

| # | File | Purpose |
|---|------|---------|
| 9 | `test/unit/hooks/loan/AaveV4LoanHooks.t.sol` | All unit tests |

### Modified Files (5 files)

| # | File | Change |
|---|------|--------|
| 10 | `src/hooks/loan/BaseLoanHook.sol` | Add `virtual` to `decodeUsePrevHookAmount` |
| 11 | `script/utils/Constants.sol` | Add 6 hook key constants |
| 12 | `script/utils/ConstantsOtherHooks.sol` | Add Aave V4 Spoke address(es) |
| 13 | `script/utils/ConfigOtherHooks.sol` | Add chain mapping for spoke addresses |
| 14 | `script/DeployV2OtherHooks.s.sol` | Add Aave V4 hooks deployment |
| 15 | `script/run/regenerate_bytecode.sh` | Add Aave V4 hooks to array |

---

## Phase 0: Interface

### File: `src/vendor/aave-v4/IAaveV4Spoke.sol`

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IAaveV4Spoke
/// @notice Minimal interface for Aave V4 Spoke contracts
/// @dev Only includes the 4 functions needed by Superform hooks.
///      The actual Aave V4 Spoke is BUSL-licensed; this minimal interface avoids license conflict.
///      Spoke functions are protected by onlyPositionManager(onBehalfOf). The Superform smart account
///      must be registered as a Position Manager (or be the caller for self-operations).
interface IAaveV4Spoke {
    /// @notice Supply assets to a reserve
    /// @param reserveId The reserve identifier within this Spoke
    /// @param amount The amount of underlying asset to supply
    /// @param onBehalfOf The address that will receive the supply position
    /// @return supplyShares The amount of shares minted
    /// @return fee The fee charged (if any)
    function supply(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);

    /// @notice Withdraw assets from a reserve
    /// @param reserveId The reserve identifier within this Spoke
    /// @param amount The amount of underlying asset to withdraw (use type(uint256).max for full withdrawal)
    /// @param onBehalfOf The address that owns the supply position
    /// @return withdrawnAmount The actual amount withdrawn
    /// @return fee The fee charged (if any)
    function withdraw(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);

    /// @notice Borrow assets from a reserve
    /// @param reserveId The reserve identifier within this Spoke
    /// @param amount The amount of underlying asset to borrow
    /// @param onBehalfOf The address that will receive the borrowed assets and incur the debt
    /// @return borrowedAmount The actual amount borrowed
    /// @return fee The fee charged (if any)
    function borrow(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);

    /// @notice Repay borrowed assets to a reserve
    /// @param reserveId The reserve identifier within this Spoke
    /// @param amount The amount of underlying asset to repay (use type(uint256).max for full repayment)
    /// @param onBehalfOf The address whose debt will be repaid
    /// @return repaidAmount The actual amount repaid
    /// @return fee The fee charged (if any)
    function repay(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);
}
```

**IMPORTANT NOTE on return types**: The interview notes specify `returns (uint256, uint256)` for all 4 functions. However, this MUST be verified against the actual Aave V4 Spoke deployment before implementation. If the return types differ (e.g., `withdraw` returns only `uint256`), update accordingly. Since we encode calls with `abi.encodeCall`, wrong return types will cause revert at execution time, not compilation time, making this hard to catch in unit tests that mock calls.

**IMPORTANT NOTE on `type(uint256).max`**: The spec has an open question about whether Aave V4 supports `type(uint256).max` for full repayment (like V3). The implementation plan assumes it DOES, based on the V3 convention. If it does not, the RepayHook and RepayAndWithdrawHook will need debt-querying logic similar to Morpho's `sharesToAssets()` pattern. This must be verified in Phase 0.

---

## Phase 1: BaseAaveV4LoanHook

### File: `src/hooks/loan/aave-v4/BaseAaveV4LoanHook.sol`

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";

// Superform
import { BaseLoanHook } from "../BaseLoanHook.sol";

/// @title BaseAaveV4LoanHook
/// @author Superform Labs
/// @notice Base abstract hook for Aave V4 Hub-and-Spoke lending protocol integrations
/// @dev All Aave V4 hooks inherit from this contract. Unlike Morpho hooks, the Spoke address
///      comes from calldata rather than the constructor, enabling a single hook deployment to
///      work with any Aave V4 Spoke (Core, e-Mode, Isolation, RWA, Vault Spokes).
///      SECURITY INVARIANT: onBehalfOf is always hardcoded to `account` -- never arbitrary.
abstract contract BaseAaveV4LoanHook is BaseLoanHook {

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Aave V4 data layout byte offsets
    uint256 internal constant LOAN_TOKEN_OFFSET = 0;
    uint256 internal constant COLLATERAL_TOKEN_OFFSET = 20;
    uint256 internal constant SPOKE_OFFSET = 40;
    uint256 internal constant SUPPLY_RESERVE_ID_OFFSET = 60;
    uint256 internal constant BORROW_RESERVE_ID_OFFSET = 92;
    uint256 internal constant AAVE_V4_AMOUNT_OFFSET = 124;
    uint256 internal constant AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION = 156;
    uint256 internal constant IS_FULL_REPAYMENT_OFFSET = 157;

    /// @notice Minimum data lengths for validation
    uint256 internal constant SUPPLY_MIN_DATA_LENGTH = 157;    // through usePrevHookAmount
    uint256 internal constant WITHDRAW_MIN_DATA_LENGTH = 157;  // through usePrevHookAmount
    uint256 internal constant BORROW_MIN_DATA_LENGTH = 157;    // through usePrevHookAmount
    uint256 internal constant REPAY_MIN_DATA_LENGTH = 158;     // through isFullRepayment
    uint256 internal constant COMBINED_MIN_DATA_LENGTH = 158;  // through isFullRepayment (for combined hooks)

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct SupplyHookLocalVars {
        address loanToken;
        address collateralToken;
        address spoke;
        uint256 supplyReserveId;
        uint256 amount;
        bool usePrevHookAmount;
    }

    struct WithdrawHookLocalVars {
        address loanToken;
        address collateralToken;
        address spoke;
        uint256 supplyReserveId;
        uint256 amount;
        bool usePrevHookAmount;
    }

    struct BorrowHookLocalVars {
        address loanToken;
        address collateralToken;
        address spoke;
        uint256 borrowReserveId;
        uint256 amount;
        bool usePrevHookAmount;
    }

    struct RepayHookLocalVars {
        address loanToken;
        address collateralToken;
        address spoke;
        uint256 borrowReserveId;
        uint256 amount;
        bool usePrevHookAmount;
        bool isFullRepayment;
    }

    struct SupplyAndBorrowHookLocalVars {
        address loanToken;
        address collateralToken;
        address spoke;
        uint256 supplyReserveId;
        uint256 borrowReserveId;
        uint256 amount;           // supply/collateral amount
        bool usePrevHookAmount;
    }

    struct RepayAndWithdrawHookLocalVars {
        address loanToken;
        address collateralToken;
        address spoke;
        uint256 supplyReserveId;
        uint256 borrowReserveId;
        uint256 amount;           // repay amount
        bool usePrevHookAmount;
        bool isFullRepayment;
    }

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when hook calldata is shorter than the required minimum
    error INVALID_DATA_LENGTH();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice No constructor args -- Spoke address comes from calldata
    /// @param hookSubtype_ Hook subtype identifier (LOAN or LOAN_REPAY)
    constructor(bytes32 hookSubtype_) BaseLoanHook(hookSubtype_) { }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseLoanHook
    /// @dev Overrides parent to use Aave V4 offset (156) instead of Morpho offset (144)
    function decodeUsePrevHookAmount(bytes memory data) external pure virtual override returns (bool) {
        return _decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Decodes supply hook data
    function _decodeSupplyHookData(bytes memory data) internal pure returns (SupplyHookLocalVars memory vars) {
        if (data.length < SUPPLY_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.spoke = BytesLib.toAddress(data, SPOKE_OFFSET);

        if (vars.loanToken == address(0) || vars.collateralToken == address(0) || vars.spoke == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        vars.supplyReserveId = BytesLib.toUint256(data, SUPPLY_RESERVE_ID_OFFSET);
        vars.amount = BytesLib.toUint256(data, AAVE_V4_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @dev Decodes withdraw hook data (same layout as supply)
    function _decodeWithdrawHookData(bytes memory data) internal pure returns (WithdrawHookLocalVars memory vars) {
        if (data.length < WITHDRAW_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.spoke = BytesLib.toAddress(data, SPOKE_OFFSET);

        if (vars.loanToken == address(0) || vars.collateralToken == address(0) || vars.spoke == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        vars.supplyReserveId = BytesLib.toUint256(data, SUPPLY_RESERVE_ID_OFFSET);
        vars.amount = BytesLib.toUint256(data, AAVE_V4_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @dev Decodes borrow hook data -- uses borrowReserveId (not supplyReserveId)
    function _decodeBorrowHookData(bytes memory data) internal pure returns (BorrowHookLocalVars memory vars) {
        if (data.length < BORROW_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.spoke = BytesLib.toAddress(data, SPOKE_OFFSET);

        if (vars.loanToken == address(0) || vars.collateralToken == address(0) || vars.spoke == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        vars.borrowReserveId = BytesLib.toUint256(data, BORROW_RESERVE_ID_OFFSET);
        vars.amount = BytesLib.toUint256(data, AAVE_V4_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @dev Decodes repay hook data -- uses borrowReserveId + isFullRepayment
    function _decodeRepayHookData(bytes memory data) internal pure returns (RepayHookLocalVars memory vars) {
        if (data.length < REPAY_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.spoke = BytesLib.toAddress(data, SPOKE_OFFSET);

        if (vars.loanToken == address(0) || vars.collateralToken == address(0) || vars.spoke == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        vars.borrowReserveId = BytesLib.toUint256(data, BORROW_RESERVE_ID_OFFSET);
        vars.amount = BytesLib.toUint256(data, AAVE_V4_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION);
        vars.isFullRepayment = _decodeBool(data, IS_FULL_REPAYMENT_OFFSET);
    }

    /// @dev Decodes supply-and-borrow hook data -- uses BOTH reserveIds
    function _decodeSupplyAndBorrowHookData(bytes memory data)
        internal
        pure
        returns (SupplyAndBorrowHookLocalVars memory vars)
    {
        if (data.length < SUPPLY_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.spoke = BytesLib.toAddress(data, SPOKE_OFFSET);

        if (vars.loanToken == address(0) || vars.collateralToken == address(0) || vars.spoke == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        vars.supplyReserveId = BytesLib.toUint256(data, SUPPLY_RESERVE_ID_OFFSET);
        vars.borrowReserveId = BytesLib.toUint256(data, BORROW_RESERVE_ID_OFFSET);
        vars.amount = BytesLib.toUint256(data, AAVE_V4_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @dev Decodes repay-and-withdraw hook data -- uses BOTH reserveIds + isFullRepayment
    function _decodeRepayAndWithdrawHookData(bytes memory data)
        internal
        pure
        returns (RepayAndWithdrawHookLocalVars memory vars)
    {
        if (data.length < COMBINED_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.spoke = BytesLib.toAddress(data, SPOKE_OFFSET);

        if (vars.loanToken == address(0) || vars.collateralToken == address(0) || vars.spoke == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        vars.supplyReserveId = BytesLib.toUint256(data, SUPPLY_RESERVE_ID_OFFSET);
        vars.borrowReserveId = BytesLib.toUint256(data, BORROW_RESERVE_ID_OFFSET);
        vars.amount = BytesLib.toUint256(data, AAVE_V4_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION);
        vars.isFullRepayment = _decodeBool(data, IS_FULL_REPAYMENT_OFFSET);
    }
}
```

### Key Differences from BaseMorphoLoanHook

| Aspect | BaseMorphoLoanHook | BaseAaveV4LoanHook |
|--------|-------------------|-------------------|
| Constructor args | `address morpho_` | NONE |
| Protocol address | Stored as `address public morpho` | Decoded from calldata each time |
| Market identification | 4 addresses (loan, collateral, oracle, irm) + lltv | 2 uint256 reserveIds |
| Amount offset | 80 (inherited from BaseLoanHook) | 124 (custom) |
| usePrevHookAmount offset | 144 (inherited) | 156 (overridden) |
| isFullRepayment offset | 145 | 157 |
| Multi-chain flexibility | One deployment per chain per morpho address | One deployment works for ALL Spokes |

---

## Phase 2: Individual Hooks (4 hooks)

### 2.1 AaveV4SupplyHook

**File**: `src/hooks/loan/aave-v4/AaveV4SupplyHook.sol`

```
/// @dev data has the following structure
/// @notice         address loanToken = BytesLib.toAddress(data, 0);
/// @notice         address collateralToken = BytesLib.toAddress(data, 20);
/// @notice         address spoke = BytesLib.toAddress(data, 40);
/// @notice         uint256 supplyReserveId = BytesLib.toUint256(data, 60);
/// @notice         uint256 borrowReserveId = BytesLib.toUint256(data, 92);
/// @notice         uint256 amount = BytesLib.toUint256(data, 124);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 156);
```

**Constructor**: `constructor() BaseAaveV4LoanHook(HookSubTypes.LOAN) { }` -- NO arguments.

**Executions array** (4 elements):
```
[0] approve(collateralToken, spoke, 0)          // Reset for USDT-like
[1] approve(collateralToken, spoke, amount)      // Exact approval
[2] spoke.supply(supplyReserveId, amount, account)   // Supply call
[3] approve(collateralToken, spoke, 0)           // P1-1: cleanup
```

**prevHook chaining**: If `usePrevHookAmount` is true, replace `amount` with `ISuperHookResult(prevHook).getOutAmount(account)`.

**outAmount tracking**:
- `_preExecute`: stores `getCollateralTokenBalance(account, data)` (collateral balance before)
- `_postExecute`: sets `preBalance - getCollateralTokenBalance(account, data)` (collateral consumed)

**inspect**: Returns `abi.encodePacked(vars.spoke)` -- ONLY the spoke address (protocol requirement: only addresses).

### 2.2 AaveV4WithdrawHook

**File**: `src/hooks/loan/aave-v4/AaveV4WithdrawHook.sol`

```
/// @dev data has the following structure
/// @notice         address loanToken = BytesLib.toAddress(data, 0);
/// @notice         address collateralToken = BytesLib.toAddress(data, 20);
/// @notice         address spoke = BytesLib.toAddress(data, 40);
/// @notice         uint256 supplyReserveId = BytesLib.toUint256(data, 60);
/// @notice         uint256 borrowReserveId = BytesLib.toUint256(data, 92);
/// @notice         uint256 amount = BytesLib.toUint256(data, 124);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 156);
```

**Constructor**: `constructor() BaseAaveV4LoanHook(HookSubTypes.LOAN_REPAY) { }` -- NO arguments.

**Executions array** (1 element):
```
[0] spoke.withdraw(supplyReserveId, amount, account)   // Withdraw call
```

No approval needed -- the Spoke transfers tokens OUT, not in.

**prevHook chaining**: If `usePrevHookAmount` is true, replace `amount` with `ISuperHookResult(prevHook).getOutAmount(account)`.

**outAmount tracking**:
- `_preExecute`: stores `getCollateralTokenBalance(account, data)` (collateral balance before)
- `_postExecute`: sets `getCollateralTokenBalance(account, data) - preBalance` (collateral received)

**inspect**: Returns `abi.encodePacked(vars.spoke)`.

**DESIGN NOTE**: Following the Morpho WithdrawHook pattern, this hook does NOT support `usePrevHookAmount` in the Morpho implementation. Morpho's WithdrawHook uses assets/shares directly. For Aave V4, the simpler model (amount-based) is used, and `usePrevHookAmount` is supported for flexibility.

### 2.3 AaveV4BorrowHook

**File**: `src/hooks/loan/aave-v4/AaveV4BorrowHook.sol`

```
/// @dev data has the following structure
/// @notice         address loanToken = BytesLib.toAddress(data, 0);
/// @notice         address collateralToken = BytesLib.toAddress(data, 20);
/// @notice         address spoke = BytesLib.toAddress(data, 40);
/// @notice         uint256 supplyReserveId = BytesLib.toUint256(data, 60);
/// @notice         uint256 borrowReserveId = BytesLib.toUint256(data, 92);
/// @notice         uint256 amount = BytesLib.toUint256(data, 124);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 156);
```

**Constructor**: `constructor() BaseAaveV4LoanHook(HookSubTypes.LOAN) { }` -- NO arguments.

**Executions array** (1 element):
```
[0] spoke.borrow(borrowReserveId, amount, account)   // Borrow call
```

No approval needed -- borrowing does not transfer tokens FROM the account.

**prevHook chaining**: If `usePrevHookAmount` is true, replace `amount` with `ISuperHookResult(prevHook).getOutAmount(account)`.

**outAmount tracking**:
- `_preExecute`: stores `getLoanTokenBalance(account, data)` (loan token balance before)
- `_postExecute`: sets `getLoanTokenBalance(account, data) - preBalance` (loan tokens received)

**inspect**: Returns `abi.encodePacked(vars.spoke)`.

### 2.4 AaveV4RepayHook

**File**: `src/hooks/loan/aave-v4/AaveV4RepayHook.sol`

```
/// @dev data has the following structure
/// @notice         address loanToken = BytesLib.toAddress(data, 0);
/// @notice         address collateralToken = BytesLib.toAddress(data, 20);
/// @notice         address spoke = BytesLib.toAddress(data, 40);
/// @notice         uint256 supplyReserveId = BytesLib.toUint256(data, 60);
/// @notice         uint256 borrowReserveId = BytesLib.toUint256(data, 92);
/// @notice         uint256 amount = BytesLib.toUint256(data, 124);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 156);
/// @notice         bool isFullRepayment = _decodeBool(data, 157);
```

**Constructor**: `constructor() BaseAaveV4LoanHook(HookSubTypes.LOAN_REPAY) { }` -- NO arguments.

**Executions array** (4 elements):

For **partial repayment** (`isFullRepayment = false`):
```
[0] approve(loanToken, spoke, 0)              // Reset for USDT-like
[1] approve(loanToken, spoke, amount)          // Exact approval
[2] spoke.repay(borrowReserveId, amount, account)   // Repay call
[3] approve(loanToken, spoke, 0)              // P1-1: cleanup
```

For **full repayment** (`isFullRepayment = true`):
```
[0] approve(loanToken, spoke, 0)              // Reset for USDT-like
[1] approve(loanToken, spoke, type(uint256).max)  // Max approval (Aave V4 consumes exact debt)
[2] spoke.repay(borrowReserveId, type(uint256).max, account)   // Full repay
[3] approve(loanToken, spoke, 0)              // P1-1: cleanup
```

**CRITICAL NOTE on full repayment**: This assumes Aave V4 supports `type(uint256).max` as the amount parameter for full repayment (like V3). If Aave V4 does NOT support this, we need an alternative approach:
- Query the Spoke for the current debt amount
- Add a small buffer for interest accrual between build() and execution
- The implementation should be adapted once this is verified in Phase 0

**prevHook chaining**: If `usePrevHookAmount` is true AND `isFullRepayment` is false, replace `amount` with `ISuperHookResult(prevHook).getOutAmount(account)`.

**outAmount tracking**:
- `_preExecute`: stores `getLoanTokenBalance(account, data)` (loan token balance before)
- `_postExecute`: sets `preBalance - getLoanTokenBalance(account, data)` (loan tokens consumed)

**inspect**: Returns `abi.encodePacked(vars.spoke)`.

---

## Phase 3: Combined Hooks (2 hooks)

### 3.1 AaveV4SupplyAndBorrowHook

**File**: `src/hooks/loan/aave-v4/AaveV4SupplyAndBorrowHook.sol`

```
/// @dev data has the following structure
/// @notice         address loanToken = BytesLib.toAddress(data, 0);
/// @notice         address collateralToken = BytesLib.toAddress(data, 20);
/// @notice         address spoke = BytesLib.toAddress(data, 40);
/// @notice         uint256 supplyReserveId = BytesLib.toUint256(data, 60);
/// @notice         uint256 borrowReserveId = BytesLib.toUint256(data, 92);
/// @notice         uint256 amount = BytesLib.toUint256(data, 124);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 156);
```

**Constructor**: `constructor() BaseAaveV4LoanHook(HookSubTypes.LOAN) { }` -- NO arguments.

**DESIGN DECISION on borrow amount derivation**:

Unlike Morpho's `MorphoSupplyAndBorrowHook` which uses an on-chain oracle to derive the borrow amount from the collateral amount and an LTV ratio, the Aave V4 version takes a simpler approach: **the borrow amount is computed off-chain by the bundler and passed in calldata**.

Rationale:
- Aave V4 does not expose a simple oracle.price() function like Morpho's IOracle
- Aave V4's risk pricing is complex (User Risk Premium, e-Mode multipliers, etc.)
- Off-chain computation gives the bundler full control over LTV targeting
- The `amount` field represents the collateral supply amount, and a second amount field is needed for borrow

**REVISED DATA LAYOUT for SupplyAndBorrow**:

We need an additional field for the borrow amount. Options:
1. **Add a `borrowAmount` field after `usePrevHookAmount`** (at position 157)
2. **Repurpose the `borrowReserveId` position to carry both reserveId AND amount in the same calldata**

Option 1 is cleaner and consistent:

```
address loanToken            (position 0)
address collateralToken      (position 20)
address spoke                (position 40)
uint256 supplyReserveId      (position 60)
uint256 borrowReserveId      (position 92)
uint256 supplyAmount         (position 124)   // amount of collateral to supply
bool    usePrevHookAmount    (position 156)
uint256 borrowAmount         (position 157)   // amount of loan token to borrow
```

New min data length: 157 + 32 = 189 bytes.

This requires a dedicated struct and decode function for SupplyAndBorrow that extends beyond the standard layout.

**Executions array** (5 elements):
```
[0] approve(collateralToken, spoke, 0)                         // Reset for USDT-like
[1] approve(collateralToken, spoke, supplyAmount)              // Exact approval
[2] spoke.supply(supplyReserveId, supplyAmount, account)       // Supply collateral
[3] spoke.borrow(borrowReserveId, borrowAmount, account)       // Borrow loan tokens
[4] approve(collateralToken, spoke, 0)                         // P1-1: cleanup
```

**prevHook chaining**: If `usePrevHookAmount` is true, replace `supplyAmount` with `ISuperHookResult(prevHook).getOutAmount(account)`. The `borrowAmount` is always from calldata (off-chain computed based on the expected supply amount).

**outAmount tracking** (tracks collateral consumed, same as MorphoSupplyAndBorrowHook):
- `_preExecute`: stores `getCollateralTokenBalance(account, data)` (collateral balance before)
- `_postExecute`: sets `preBalance - getCollateralTokenBalance(account, data)` (collateral consumed)

**NOTE**: Like Morpho, outAmount tracks collateral consumed, NOT the borrowed loan amount. Downstream hooks using `usePrevHookAmount` will get the collateral amount, not the borrow amount.

**inspect**: Returns `abi.encodePacked(vars.spoke)`.

### 3.2 AaveV4RepayAndWithdrawHook

**File**: `src/hooks/loan/aave-v4/AaveV4RepayAndWithdrawHook.sol`

```
/// @dev data has the following structure
/// @notice         address loanToken = BytesLib.toAddress(data, 0);
/// @notice         address collateralToken = BytesLib.toAddress(data, 20);
/// @notice         address spoke = BytesLib.toAddress(data, 40);
/// @notice         uint256 supplyReserveId = BytesLib.toUint256(data, 60);
/// @notice         uint256 borrowReserveId = BytesLib.toUint256(data, 92);
/// @notice         uint256 repayAmount = BytesLib.toUint256(data, 124);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 156);
/// @notice         bool isFullRepayment = _decodeBool(data, 157);
/// @notice         uint256 withdrawAmount = BytesLib.toUint256(data, 158);
```

New min data length: 158 + 32 = 190 bytes.

**DESIGN DECISION on withdraw amount derivation**:

Like SupplyAndBorrow, the withdraw amount is computed off-chain by the bundler. For full repayment, `withdrawAmount` can be `type(uint256).max` to withdraw all collateral.

**Executions array** (5 elements):

For **partial repayment**:
```
[0] approve(loanToken, spoke, 0)                                  // Reset for USDT-like
[1] approve(loanToken, spoke, repayAmount)                        // Exact approval
[2] spoke.repay(borrowReserveId, repayAmount, account)            // Repay debt
[3] approve(loanToken, spoke, 0)                                  // P1-1: cleanup
[4] spoke.withdraw(supplyReserveId, withdrawAmount, account)      // Withdraw collateral
```

For **full repayment** (`isFullRepayment = true`):
```
[0] approve(loanToken, spoke, 0)                                  // Reset for USDT-like
[1] approve(loanToken, spoke, type(uint256).max)                  // Max approval
[2] spoke.repay(borrowReserveId, type(uint256).max, account)      // Full repay
[3] approve(loanToken, spoke, 0)                                  // P1-1: cleanup
[4] spoke.withdraw(supplyReserveId, type(uint256).max, account)   // Full withdraw
```

**prevHook chaining**: If `usePrevHookAmount` is true AND `isFullRepayment` is false, replace `repayAmount` with `ISuperHookResult(prevHook).getOutAmount(account)`. The `withdrawAmount` is always from calldata.

**outAmount tracking** (tracks collateral received, same as MorphoRepayAndWithdrawHook):
- `_preExecute`: stores `getCollateralTokenBalance(account, data)` (collateral balance before)
- `_postExecute`: sets `getCollateralTokenBalance(account, data) - preBalance` (collateral received)

**inspect**: Returns `abi.encodePacked(vars.spoke)`.

---

## Phase 1 Addendum: BaseLoanHook Change

### File: `src/hooks/loan/BaseLoanHook.sol`

**Change**: Add `virtual` keyword to `decodeUsePrevHookAmount`:

```solidity
// Line 31, change from:
function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {

// To:
function decodeUsePrevHookAmount(bytes memory data) external pure virtual returns (bool) {
```

This is a single-word change. Backwards-compatible. No ABI change. All existing Morpho hooks continue to work identically (they don't override this function).

---

## Phase 4: Tests

### File: `test/unit/hooks/loan/AaveV4LoanHooks.t.sol`

**Test structure** (following `MorphoLoanHooks.t.sol` patterns):

#### Mock Contracts (defined inside test file)

```solidity
contract MockAaveV4Spoke {
    // Tracks calls for assertion
    function supply(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256) {
        return (amount, 0); // Return shares minted, fee
    }
    function withdraw(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256) {
        return (amount, 0);
    }
    function borrow(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256) {
        return (amount, 0);
    }
    function repay(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256) {
        return (amount, 0);
    }
}
```

#### Test Contract

```solidity
contract AaveV4LoanHooksTest is Helpers {
    // All 6 hooks
    AaveV4SupplyHook public supplyHook;
    AaveV4WithdrawHook public withdrawHook;
    AaveV4BorrowHook public borrowHook;
    AaveV4RepayHook public repayHook;
    AaveV4SupplyAndBorrowHook public supplyAndBorrowHook;
    AaveV4RepayAndWithdrawHook public repayAndWithdrawHook;

    // Mocks
    MockAaveV4Spoke public mockSpoke;
    MockERC20 public mockLoanToken;
    MockERC20 public mockCollateralToken;

    // Test params
    address public spoke;
    address public loanToken;
    address public collateralToken;
    uint256 public supplyReserveId = 1;
    uint256 public borrowReserveId = 2;
    uint256 public amount = 1e18;
}
```

#### Test Categories Per Hook

For **each of the 6 hooks**, test:

1. **Constructor** -- verify hookType is NONACCOUNTING, verify subtype (LOAN or LOAN_REPAY)
2. **Build (happy path)** -- encode valid data, call `build()`, assert execution count, assert targets and calldata lengths
3. **Build with prevHook** -- create MockHook, set outAmount, call with `usePrevHookAmount=true`, verify execution uses prevHook amount
4. **Build revert: zero address** -- pass address(0) for spoke/loanToken/collateralToken
5. **Build revert: zero amount** -- pass amount=0 with usePrevHookAmount=false
6. **Build revert: invalid data length** -- pass truncated data
7. **Inspector** -- call `inspect()`, verify returns spoke address
8. **Inspector revert: invalid address** -- pass address(0), verify reverts
9. **DecodeUsePrevHookAmount** -- verify returns correct bool for true/false cases
10. **PrePostExecute** -- deal tokens, call preExecute, simulate state change, call postExecute, verify outAmount

For **RepayHook** additionally:
11. **Full repayment build** -- `isFullRepayment=true`, verify type(uint256).max in approval and repay calldata
12. **Full repayment pre/post execute** -- verify correct loan token consumption tracking

For **SupplyAndBorrowHook** additionally:
11. **Verify both supply and borrow calls** -- assert correct reserveIds in each call
12. **BorrowAmount from calldata** -- verify the borrow amount is correctly decoded

For **RepayAndWithdrawHook** additionally:
11. **Partial repayment** -- verify repay and withdraw amounts from calldata
12. **Full repayment** -- verify type(uint256).max for both repay and withdraw
13. **Pre/post execute for full repayment** -- track collateral received

#### Encoding Helpers

```solidity
function _encodeSupplyData(bool usePrevHook) internal view returns (bytes memory) {
    return abi.encodePacked(
        loanToken,
        collateralToken,
        spoke,
        supplyReserveId,
        borrowReserveId,
        amount,
        usePrevHook
    );
}

function _encodeBorrowData(bool usePrevHook) internal view returns (bytes memory) {
    return abi.encodePacked(
        loanToken,
        collateralToken,
        spoke,
        supplyReserveId,
        borrowReserveId,
        amount,
        usePrevHook
    );
}

function _encodeRepayData(bool usePrevHook, bool isFullRepayment) internal view returns (bytes memory) {
    return abi.encodePacked(
        loanToken,
        collateralToken,
        spoke,
        supplyReserveId,
        borrowReserveId,
        amount,
        usePrevHook,
        isFullRepayment
    );
}

function _encodeSupplyAndBorrowData(bool usePrevHook, uint256 borrowAmount) internal view returns (bytes memory) {
    return abi.encodePacked(
        loanToken,
        collateralToken,
        spoke,
        supplyReserveId,
        borrowReserveId,
        amount,          // supply amount
        usePrevHook,
        borrowAmount     // borrow amount at position 157
    );
}

function _encodeRepayAndWithdrawData(
    bool usePrevHook,
    bool isFullRepayment,
    uint256 withdrawAmount
) internal view returns (bytes memory) {
    return abi.encodePacked(
        loanToken,
        collateralToken,
        spoke,
        supplyReserveId,
        borrowReserveId,
        amount,          // repay amount
        usePrevHook,
        isFullRepayment,
        withdrawAmount   // withdraw amount at position 158
    );
}
```

---

## Phase 5: Deployment

### 5.1 Constants.sol

**File**: `script/utils/Constants.sol`

Add after the existing Morpho hook keys (around line 204):

```solidity
// Aave V4 Hook Keys
string internal constant AAVE_V4_SUPPLY_HOOK_KEY = "AaveV4SupplyHook";
string internal constant AAVE_V4_WITHDRAW_HOOK_KEY = "AaveV4WithdrawHook";
string internal constant AAVE_V4_BORROW_HOOK_KEY = "AaveV4BorrowHook";
string internal constant AAVE_V4_REPAY_HOOK_KEY = "AaveV4RepayHook";
string internal constant AAVE_V4_SUPPLY_AND_BORROW_HOOK_KEY = "AaveV4SupplyAndBorrowHook";
string internal constant AAVE_V4_REPAY_AND_WITHDRAW_HOOK_KEY = "AaveV4RepayAndWithdrawHook";
```

### 5.2 ConstantsOtherHooks.sol

**File**: `script/utils/ConstantsOtherHooks.sol`

Add Aave V4 Spoke address(es). Since Aave V4 hooks have NO constructor arguments (Spoke address comes from calldata), we technically do NOT need Spoke addresses here for deployment. However, we should document the known Spoke addresses for reference.

**IMPORTANT**: Since Aave V4 hooks have NO constructor arguments, they deploy identically on any chain. The deployment does NOT need chain-specific configuration for the hook contracts themselves. This is a major simplification vs Morpho hooks.

```solidity
abstract contract ConstantsOtherHooks {
    // Morpho addresses per chain
    address internal constant MORPHO_MAINNET = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address internal constant MORPHO_BASE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address internal constant MORPHO_OPTIMISM = 0xce95AfbB8EA029495c66020883F87aaE8864AF92;
    address internal constant MORPHO_ARBITRUM = 0x6c247b1F6182318877311737BaC0844bAa518F5e;
    address internal constant MORPHO_BNB = 0x01b0Bd309AA75547f7a37Ad7B1219A898E67a83a;

    // Aave V4 Spoke addresses (for reference -- NOT used in constructor args)
    // NOTE: Aave V4 hooks take spoke address from calldata, so these are informational only.
    // Update these when Aave V4 deploys to additional chains.
    // address internal constant AAVE_V4_CORE_SPOKE_MAINNET = 0x...; // TBD: get from aave-address-book
}
```

### 5.3 ConfigOtherHooks.sol

**File**: `script/utils/ConfigOtherHooks.sol`

Since Aave V4 hooks have NO constructor args, the config mapping is optional. However, for conditional deployment (deploy only on chains where Aave V4 exists), we can add an availability flag:

```solidity
struct OtherHooksData {
    mapping(uint64 chainId => address morpho) morphos;
    mapping(uint64 chainId => bool isAaveV4Available) aaveV4Available;
}

function _setOtherHooksConfiguration() internal {
    // Morpho (existing)
    otherHooksConfiguration.morphos[MAINNET_CHAIN_ID] = MORPHO_MAINNET;
    // ... (existing)

    // Aave V4 availability (Ethereum only for now)
    otherHooksConfiguration.aaveV4Available[MAINNET_CHAIN_ID] = true;
    // All other chains default to false (not deployed yet)
}
```

### 5.4 DeployV2OtherHooks.s.sol

**File**: `script/DeployV2OtherHooks.s.sol`

Add the following:

1. **New struct**:
```solidity
struct AaveV4HookAddresses {
    address aaveV4SupplyHook;
    address aaveV4WithdrawHook;
    address aaveV4BorrowHook;
    address aaveV4RepayHook;
    address aaveV4SupplyAndBorrowHook;
    address aaveV4RepayAndWithdrawHook;
}
```

2. **New deployment function** `_deployAaveV4Hooks`:
```solidity
function _deployAaveV4Hooks(uint64 chainId, uint256 env) internal returns (AaveV4HookAddresses memory hookAddresses) {
    if (!otherHooksConfiguration.aaveV4Available[chainId]) {
        console2.log("SKIPPED Aave V4 hooks: not available on chain", chainId);
        return hookAddresses;
    }

    uint256 len = 6;
    HookDeployment[] memory hooks = new HookDeployment[](len);
    address[] memory addresses = new address[](len);

    // NO constructor args for any Aave V4 hook
    hooks[0] = HookDeployment(
        AAVE_V4_SUPPLY_HOOK_KEY, "", __getMorphoHooksBytecode("AaveV4SupplyHook", env)
    );
    hooks[1] = HookDeployment(
        AAVE_V4_WITHDRAW_HOOK_KEY, "", __getMorphoHooksBytecode("AaveV4WithdrawHook", env)
    );
    hooks[2] = HookDeployment(
        AAVE_V4_BORROW_HOOK_KEY, "", __getMorphoHooksBytecode("AaveV4BorrowHook", env)
    );
    hooks[3] = HookDeployment(
        AAVE_V4_REPAY_HOOK_KEY, "", __getMorphoHooksBytecode("AaveV4RepayHook", env)
    );
    hooks[4] = HookDeployment(
        AAVE_V4_SUPPLY_AND_BORROW_HOOK_KEY, "", __getMorphoHooksBytecode("AaveV4SupplyAndBorrowHook", env)
    );
    hooks[5] = HookDeployment(
        AAVE_V4_REPAY_AND_WITHDRAW_HOOK_KEY, "", __getMorphoHooksBytecode("AaveV4RepayAndWithdrawHook", env)
    );

    for (uint256 i = 0; i < len; ++i) {
        HookDeployment memory hook = hooks[i];
        string memory saltName = bytes(hook.saltOverride).length > 0 ? hook.saltOverride : hook.name;
        addresses[i] = __deployContract(hook.name, chainId, __getSalt(saltName), hook.creationCode);
    }

    // Assign hook addresses
    hookAddresses.aaveV4SupplyHook = addresses[0];
    hookAddresses.aaveV4WithdrawHook = addresses[1];
    hookAddresses.aaveV4BorrowHook = addresses[2];
    hookAddresses.aaveV4RepayHook = addresses[3];
    hookAddresses.aaveV4SupplyAndBorrowHook = addresses[4];
    hookAddresses.aaveV4RepayAndWithdrawHook = addresses[5];

    console2.log("All Aave V4 hooks deployed and validated successfully.");
}
```

3. **Update `run` functions** to call `_deployAaveV4Hooks` in addition to `_deployMorphoHooks`:
```solidity
function run(uint256 env, uint64 chainId) public broadcast(env) {
    _setConfiguration(env, "");
    console2.log("Deploying Other Hooks on chainId: ", chainId);
    _deployMorphoHooks(chainId, env);
    _deployAaveV4Hooks(chainId, env);   // ADD THIS
    _writeExportedContracts(chainId);
}
```

**NOTE**: The bytecode directory function `__getMorphoHooksBytecodeDirectory` should be renamed to something more generic (e.g., `__getOtherHooksBytecodeDirectory`) or a new function should be added. For minimal changes, reuse the existing function since it just returns `script/generated-bytecode-other/` or `script/locked-bytecode-other/`.

### 5.5 regenerate_bytecode.sh

**File**: `script/run/regenerate_bytecode.sh`

Add Aave V4 hooks to the `MORPHO_HOOK_CONTRACTS` array (or create a new `AAVE_V4_HOOK_CONTRACTS` array). The simplest approach is to rename the array to something generic or add the Aave V4 hooks alongside the Morpho hooks since they share the same bytecode directory:

```bash
# After MORPHO_HOOK_CONTRACTS array (around line 178), add:
AAVE_V4_HOOK_CONTRACTS=(
    "AaveV4SupplyHook"
    "AaveV4WithdrawHook"
    "AaveV4BorrowHook"
    "AaveV4RepayHook"
    "AaveV4SupplyAndBorrowHook"
    "AaveV4RepayAndWithdrawHook"
)
```

Then in the copy section (around line 241), add a parallel block for Aave V4 hooks that copies to `generated-bytecode-other/`:

```bash
# Copy Aave V4 hook contracts to generated-bytecode-other/
log "INFO" "${BLUE}Copying Aave V4 hook contracts to generated-bytecode-other/...${NC}"
failed_aave_v4=0
for contract in "${AAVE_V4_HOOK_CONTRACTS[@]}"; do
    local_source="out/${contract}.sol/${contract}.json"
    local_dest="script/generated-bytecode-other/${contract}.json"
    if [ ! -f "$local_source" ]; then
        log "ERROR" "${RED}Artifact not found for contract: ${contract} at ${local_source}${NC}"
        failed_aave_v4=$((failed_aave_v4 + 1))
    else
        cp "$local_source" "$local_dest"
        log "INFO" "${GREEN}Copied ${contract} to generated-bytecode-other/${NC}"
    fi
done
```

Also update the summary section to include Aave V4 counts.

### 5.6 deploy_v2_other_hooks_staging_prod.sh

**File**: `script/run/deploy_v2_other_hooks_staging_prod.sh`

Add Aave V4 hooks to the bytecode check section (around line 190):

```bash
AAVE_V4_HOOKS=(
    "AaveV4SupplyHook"
    "AaveV4WithdrawHook"
    "AaveV4BorrowHook"
    "AaveV4RepayHook"
    "AaveV4SupplyAndBorrowHook"
    "AaveV4RepayAndWithdrawHook"
)
```

Add `AAVE_V4_SUPPORTED_CHAINS=("1")` and a corresponding `is_aave_v4_supported()` function. However, since the `DeployV2OtherHooks.s.sol` already handles conditional deployment via the `aaveV4Available` mapping, the shell script only needs the bytecode checks.

---

## Important Notes for Implementation

### Note 1: No Constructor Arguments

This is the BIGGEST difference from Morpho. All 6 Aave V4 hooks have ZERO constructor arguments. The Spoke address comes from calldata. This means:
- One deployment works for ALL Aave V4 Spokes on a chain (Core, e-Mode, Isolation, etc.)
- When Aave V4 deploys to new chains, the SAME hook contracts can be deployed (same bytecode)
- No need for per-chain Spoke address configuration in the deployment scripts
- Deployment is simpler -- no `abi.encode(spokeAddress)` appended to bytecode

### Note 2: Data Layout Consistency

ALL 6 hooks share the same base data layout (positions 0-156). The differences are:
- Supply, Withdraw, Borrow: end at position 157 (after usePrevHookAmount)
- Repay: extends to position 158 (adds isFullRepayment at 157)
- SupplyAndBorrow: extends to position 189 (adds borrowAmount at 157)
- RepayAndWithdraw: extends to position 190 (adds isFullRepayment at 157, withdrawAmount at 158)

Supply and Withdraw use `supplyReserveId` (offset 60). Borrow and Repay use `borrowReserveId` (offset 92). Combined hooks use BOTH. The unused reserveId field is still present in the calldata for layout consistency -- it can be set to 0 by the off-chain bundler.

### Note 3: Inspector Returns Only Spoke Address

Per the protocol requirement, `inspect()` returns ONLY addresses. For Aave V4, this is just the Spoke address:

```solidity
function inspect(bytes calldata data) external pure override returns (bytes memory) {
    address spoke = BytesLib.toAddress(data, SPOKE_OFFSET);
    return abi.encodePacked(spoke);
}
```

This differs from Morpho's inspect which returns 4 addresses (loanToken, collateralToken, oracle, irm). For Aave V4, the Spoke address alone is sufficient for the off-chain system to identify the protocol endpoint. We do NOT include loanToken/collateralToken in inspect -- these are available via `getLoanTokenAddress()` and `getCollateralTokenAddress()` from ISuperHookLoans.

### Note 4: Full Repayment Strategy

The plan assumes `type(uint256).max` works for Aave V4 full repayment (like V3). If verification in Phase 0 shows it does NOT:

**Fallback approach**: Add a debt-querying view function to the hook (similar to MorphoRepayHook's `sharesToAssets()`) that queries the Spoke for the current debt. This would require adding the Spoke's debt-querying interface to `IAaveV4Spoke.sol` and making the full repayment path query the debt amount at build-time (with the known staleness limitation P1-3).

### Note 5: Position Manager Blocker

The technical spec flags a BLOCKER: Aave V4 Spoke functions are protected by `onlyPositionManager(onBehalfOf)`. This must be resolved before implementation begins. The implementation plan is written assuming the blocker IS resolved (Option A: smart account is the caller and onBehalfOf, so self-calls are allowed).

If the blocker is NOT resolved, alternative approaches may include routing through Aave's SignatureGateway or requiring governance registration of Superform's executor.

### Note 6: Branch Requirement

Per the CLAUDE.md instructions, this work MUST be done in the `pre-dev` branch. The current branch is `dev`. Alert the user if the branch needs to be changed before implementation begins.

---

## Execution Order

| Step | Task | Dependencies |
|------|------|-------------|
| 0a | Verify Position Manager access (blocker) | None |
| 0b | Verify Spoke function signatures and return types | None |
| 0c | Verify `type(uint256).max` support for full repayment | None |
| 0d | Create `src/vendor/aave-v4/IAaveV4Spoke.sol` | 0b |
| 1a | Modify `src/hooks/loan/BaseLoanHook.sol` (add `virtual`) | None |
| 1b | Create `src/hooks/loan/aave-v4/BaseAaveV4LoanHook.sol` | 0d, 1a |
| 2a | Create `AaveV4SupplyHook.sol` | 1b |
| 2b | Create `AaveV4WithdrawHook.sol` | 1b |
| 2c | Create `AaveV4BorrowHook.sol` | 1b |
| 2d | Create `AaveV4RepayHook.sol` | 1b |
| 3a | Create `AaveV4SupplyAndBorrowHook.sol` | 1b |
| 3b | Create `AaveV4RepayAndWithdrawHook.sol` | 1b |
| 4  | Create `test/unit/hooks/loan/AaveV4LoanHooks.t.sol` | 2a-3b |
| 5a | Update `script/utils/Constants.sol` | None |
| 5b | Update `script/utils/ConstantsOtherHooks.sol` | None |
| 5c | Update `script/utils/ConfigOtherHooks.sol` | 5b |
| 5d | Update `script/DeployV2OtherHooks.s.sol` | 5a, 5c |
| 5e | Update `script/run/regenerate_bytecode.sh` | None |
| 5f | Update `script/run/deploy_v2_other_hooks_staging_prod.sh` | None |

Steps 2a-2d can be done in parallel. Steps 3a-3b can be done in parallel. Step 4 should be done after all hooks are created. Steps 5a-5f can be done in parallel.

---

## Summary of All File Changes

### New Files (9)
1. `src/vendor/aave-v4/IAaveV4Spoke.sol`
2. `src/hooks/loan/aave-v4/BaseAaveV4LoanHook.sol`
3. `src/hooks/loan/aave-v4/AaveV4SupplyHook.sol`
4. `src/hooks/loan/aave-v4/AaveV4WithdrawHook.sol`
5. `src/hooks/loan/aave-v4/AaveV4BorrowHook.sol`
6. `src/hooks/loan/aave-v4/AaveV4RepayHook.sol`
7. `src/hooks/loan/aave-v4/AaveV4SupplyAndBorrowHook.sol`
8. `src/hooks/loan/aave-v4/AaveV4RepayAndWithdrawHook.sol`
9. `test/unit/hooks/loan/AaveV4LoanHooks.t.sol`

### Modified Files (6)
10. `src/hooks/loan/BaseLoanHook.sol` -- add `virtual` to `decodeUsePrevHookAmount`
11. `script/utils/Constants.sol` -- add 6 hook key constants
12. `script/utils/ConstantsOtherHooks.sol` -- add Aave V4 Spoke address comments
13. `script/utils/ConfigOtherHooks.sol` -- add `aaveV4Available` mapping
14. `script/DeployV2OtherHooks.s.sol` -- add Aave V4 deployment function
15. `script/run/regenerate_bytecode.sh` -- add Aave V4 hooks to array
16. `script/run/deploy_v2_other_hooks_staging_prod.sh` -- add Aave V4 bytecode checks
