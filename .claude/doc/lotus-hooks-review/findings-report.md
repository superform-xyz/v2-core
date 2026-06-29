# Lotus Superform Lending Hooks -- Detailed Review Report

**Review Date**: 2026-06-17
**Reviewer**: superform-hook-master
**Branch**: feat/hook-sizing-manifest
**Scope**: 8 concrete hooks + 1 base hook + 2 vendor files

## Files Reviewed

| File | Path |
|------|------|
| BaseLotusLoanHook.sol | `/Users/cosming/1.Coding/Lotus/src/hooks/loan/lotus/` |
| LotusLendHook.sol | same directory |
| LotusBorrowHook.sol | same directory |
| LotusRepayHook.sol | same directory |
| LotusWithdrawHook.sol | same directory |
| LotusSupplyCollateralHook.sol | same directory |
| LotusWithdrawCollateralHook.sol | same directory |
| LotusSupplyAndBorrowHook.sol | same directory |
| LotusRepayAndWithdrawHook.sol | same directory |
| ILotus.sol | `/Users/cosming/1.Coding/Lotus/src/vendor/lotus/` |
| MarketParamsLib.sol | same directory |

Reference: All Morpho hooks in `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/loan/morpho/`

---

## CATEGORY 1: CRITICAL -- Inspector Function Violations

### Finding 1.1: inspect() returns non-address data -- PROTOCOL VIOLATION

**Severity**: CRITICAL
**Affected Files**: All 8 hooks (via `_inspectLoanTokenVars`, `_inspectCollateralVars`, `_inspectCompositeVars` in BaseLotusLoanHook.sol)

The Superform protocol requirement states: **"Inspector functions MUST only return addresses (never amounts, booleans, or other data)."**

The Lotus `_inspectLoanTokenVars` function returns:
```solidity
return abi.encodePacked(
    address(LOTUS),                          // address -- OK
    vars.marketParams.loanToken,             // address -- OK
    vars.marketParams.riskEngine,            // address -- OK
    vars.marketParams.liquidationModule,     // address -- OK
    vars.marketParams.trancheConfigsHash,    // bytes32 -- VIOLATION (not an address)
    vars.trancheIndex,                       // uint256 -- VIOLATION (not an address)
    keccak256(vars.riskEngineData)           // bytes32 -- VIOLATION (not an address)
);
```

The `_inspectCollateralVars` and `_inspectCompositeVars` have the same violations plus the additional `vars.collateralToken` (which is fine since it is an address).

**Comparison with Morpho**: Morpho's inspect functions only return addresses:
```solidity
return abi.encodePacked(
    marketParams.loanToken,
    marketParams.collateralToken,
    marketParams.oracle,
    marketParams.irm
);
```

**Why This Matters**: Inspector functions are used for Merkle tree validation in SuperVaults. Including non-address data (uint256 trancheIndex, bytes32 hashes) breaks protocol assumptions about data layout and could cause SuperVault validation failures. The ABI-packed encoding of a `bytes32` is 32 bytes while an `address` is 20 bytes -- this will confuse any consumer that parses the returned blob as a sequence of 20-byte addresses.

**Recommendation**: Restructure inspect output to only include addresses. The `trancheConfigsHash` and `trancheIndex` and `keccak256(riskEngineData)` should be removed. If market identity needs to be committed, consider hashing the full market params into a single identifier and still only returning addresses. Alternatively, if the protocol team has explicitly relaxed this rule for loan hooks, document that clearly.

**However** -- note that Morpho's market identity is fully determined by addresses (loanToken, collateralToken, oracle, irm) plus lltv. The Morpho hooks do NOT include lltv in inspect output. This suggests the inspect output is intentionally just the address subset that identifies tokens/contracts involved, not a full market identity commitment.

For Lotus, the addresses that identify the market are: `LOTUS`, `loanToken`, `riskEngine`, `liquidationModule`. The `trancheConfigsHash` is NOT an address -- it is a bytes32 commitment. The `trancheIndex` is a uint256. The collateral token IS an address. A protocol-compliant approach:

```solidity
// Loan token hooks:
return abi.encodePacked(address(LOTUS), vars.marketParams.loanToken, vars.marketParams.riskEngine, vars.marketParams.liquidationModule);

// Collateral hooks (add collateral token):
return abi.encodePacked(address(LOTUS), vars.marketParams.loanToken, vars.marketParams.riskEngine, vars.marketParams.liquidationModule, vars.collateralToken);
```

If `trancheConfigsHash` differentiation is needed, it would need to be handled differently (e.g., by the off-chain system validating the full data blob, not via inspect).

---

## CATEGORY 2: HIGH -- decodeAmount / replaceCalldataAmount Offset Mismatch

### Finding 2.1: decodeAmount and replaceCalldataAmount point to ASSETS_OFFSET for ALL hook types

**Severity**: HIGH
**Affected File**: BaseLotusLoanHook.sol, lines 144-153

```solidity
function decodeAmount(bytes memory data) external pure returns (uint256) {
    if (data.length < ASSETS_OFFSET + 32) revert INVALID_DATA_LENGTH();
    return BytesLib.toUint256(data, ASSETS_OFFSET);  // offset 124
}

function replaceCalldataAmount(bytes memory data, uint256 amount) external pure returns (bytes memory) {
    if (data.length < ASSETS_OFFSET + 32) revert INVALID_DATA_LENGTH();
    return _replaceCalldataAmount(data, amount, ASSETS_OFFSET);  // offset 124
}
```

`ASSETS_OFFSET = 124` is the correct offset for loan-token-layout hooks (LotusLendHook, LotusBorrowHook, LotusRepayHook, LotusWithdrawHook).

**But for collateral hooks** (`LotusSupplyCollateralHook`, `LotusWithdrawCollateralHook`), the amount is ALSO at `COLLATERAL_AMOUNT_OFFSET = 124`, which happens to be the same offset. So for single-operation hooks, offset 124 is coincidentally correct for all of them.

**But for composite hooks** (`LotusSupplyAndBorrowHook`, `LotusRepayAndWithdrawHook`), offset 124 is `collateralAmount` (`COMPOSITE_COLLATERAL_AMOUNT_OFFSET = 124`). Whether this is the intended "amount" for the bundler depends on the semantic intent. For `LotusSupplyAndBorrowHook`, the "primary" amount from a user perspective could be either collateral or loan amount. For `LotusRepayAndWithdrawHook`, the primary amount is likely the repay amount (`loanAssets` at offset 156).

**Key Question**: The composite hooks do not override `decodeAmount`/`replaceCalldataAmount`. If the bundler calls `decodeAmount` on `LotusRepayAndWithdrawHook`, it gets `collateralAmount` (offset 124), but the `_buildHookExecutions` shows that `collateralAmount` must be 0 for non-full-repayment (line 44: `if (vars.collateralAmount != 0 ...) revert AMOUNT_NOT_VALID()`). So `decodeAmount` would always return 0 for the valid case -- the bundler would think there is no amount.

**Recommendation**: The composite hooks (`LotusSupplyAndBorrowHook`, `LotusRepayAndWithdrawHook`) MUST override `decodeAmount` and `replaceCalldataAmount` to return/modify the correct primary amount. For `LotusSupplyAndBorrowHook`, this is `collateralAmount` at offset 124 (happens to be correct). For `LotusRepayAndWithdrawHook`, this should be `loanAssets` at `COMPOSITE_LOAN_AMOUNT_OFFSET = 156`.

Also, `LotusSupplyCollateralHook` and `LotusWithdrawCollateralHook` should consider overriding these methods for clarity, even though the offset coincidentally matches.

### Finding 2.2: Collateral hooks do not override decodeUsePrevHookAmount but DO override it

**Severity**: LOW (informational)

`LotusSupplyCollateralHook` and `LotusWithdrawCollateralHook` correctly override `decodeUsePrevHookAmount` to use their own offsets (`COLLATERAL_USE_PREV_HOOK_AMOUNT_OFFSET = 156`). Good.

`LotusSupplyAndBorrowHook` and `LotusRepayAndWithdrawHook` correctly override to use `COMPOSITE_USE_PREV_HOOK_AMOUNT_OFFSET = 284`. Good.

But the base class `decodeUsePrevHookAmount` uses `USE_PREV_HOOK_AMOUNT_OFFSET = 220` which is correct for loan-token-layout hooks. The non-overriding hooks (`LotusLendHook`, `LotusBorrowHook`, `LotusRepayHook`, `LotusWithdrawHook`) inherit this correctly. This is fine.

---

## CATEGORY 3: MEDIUM -- HookSubType Assignments

### Finding 3.1: LotusWithdrawHook uses LOAN_REPAY subtype -- questionable

**Severity**: MEDIUM
**Affected File**: LotusWithdrawHook.sol, line 14

```solidity
constructor(address lotus_) BaseLotusLoanHook(lotus_, HookSubTypes.LOAN_REPAY) { }
```

`LotusWithdrawHook` withdraws a lender's supply position (loan token). This is semantically the opposite of lending -- it is a lender withdrawal. Morpho's `MorphoWithdrawHook` also uses `LOAN_REPAY`:
```solidity
constructor(address morpho_) BaseMorphoLoanHook(morpho_, HookSubTypes.LOAN_REPAY) { }
```

So this matches the Morpho precedent. The naming is counterintuitive (a lender withdrawal is not a "loan repay") but is consistent with the existing convention where `LOAN_REPAY` appears to mean "outflow from a lending position" (whether that is repaying debt or withdrawing supply). This is acceptable as long as the convention is documented.

### Finding 3.2: Full HookSubType matrix comparison

| Hook | Lotus SubType | Morpho Equivalent | Morpho SubType | Match? |
|------|--------------|-------------------|----------------|--------|
| LotusLendHook | LOAN | MorphoLendHook | LOAN | YES |
| LotusBorrowHook | LOAN | MorphoBorrowHook | LOAN | YES |
| LotusRepayHook | LOAN_REPAY | MorphoRepayHook | LOAN_REPAY | YES |
| LotusWithdrawHook | LOAN_REPAY | MorphoWithdrawHook | LOAN_REPAY | YES |
| LotusSupplyCollateralHook | LOAN | MorphoSupplyHook | LOAN | YES |
| LotusWithdrawCollateralHook | LOAN_REPAY | (no direct equivalent) | N/A | OK |
| LotusSupplyAndBorrowHook | LOAN | MorphoSupplyAndBorrowHook | LOAN | YES |
| LotusRepayAndWithdrawHook | LOAN_REPAY | MorphoRepayAndWithdrawHook | LOAN_REPAY | YES |

All subtypes match the Morpho convention. No issues.

---

## CATEGORY 4: MEDIUM -- Missing NatSpec Data Layout Documentation

### Finding 4.1: No inline NatSpec data layout on hook contracts

**Severity**: MEDIUM
**Affected Files**: All 8 hook contracts

The Superform convention requires: **"ALWAYS place NatSpec documentation for hook data layout immediately after the line `/// @dev data has the following structure`"**

The Morpho hooks follow this pattern:
```solidity
/// @title MorphoLendHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address loanToken = BytesLib.toAddress(data, 0);
/// @notice         address collateralToken = BytesLib.toAddress(data, 20);
/// @notice         address oracle = BytesLib.toAddress(data, 40);
/// ...
contract MorphoLendHook is BaseMorphoLoanHook {
```

The Lotus hooks do NOT have this pattern. They have a README.md with tables, but no inline NatSpec on the contract declarations themselves. The README is good supplementary documentation, but the inline NatSpec is required by convention for tooling and code generation.

**Recommendation**: Add the standard NatSpec data layout documentation to each Lotus hook contract. Example for LotusLendHook:

```solidity
/// @title LotusLendHook
/// @notice Supplies loan assets into a Lotus tranche.
/// @dev data has the following structure
/// @notice         address loanToken = BytesLib.toAddress(data, 0);
/// @notice         address riskEngine = BytesLib.toAddress(data, 20);
/// @notice         address liquidationModule = BytesLib.toAddress(data, 40);
/// @notice         bytes32 trancheConfigsHash = BytesLib.toBytes32(data, 60);
/// @notice         uint256 trancheIndex = BytesLib.toUint256(data, 92);
/// @notice         uint256 assets = BytesLib.toUint256(data, 124);
/// @notice         uint256 shares = BytesLib.toUint256(data, 156);
/// @notice         uint256 sharePriceLimitE27 = BytesLib.toUint256(data, 188);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 220);
/// @notice         bool isFullRepayment = _decodeBool(data, 221);
/// @notice         bytes riskEngineData = BytesLib.slice(data, 222, data.length - 222);
```

---

## CATEGORY 5: LOW-MEDIUM -- _preExecute / _postExecute Patterns

### Finding 5.1: LotusLendHook _preExecute stores supplyShares in outAmount, then _postExecute overwrites it

**Severity**: LOW (working correctly but non-obvious)
**Affected File**: LotusLendHook.sol, lines 52-66

```solidity
function _preExecute(address, address account, bytes calldata data) internal override {
    LoanTokenHookVars memory vars = _decodeLoanTokenHookData(data);
    _setAsset(vars.marketParams.loanToken);
    _setPreAssetBalance(account, getLoanTokenBalance(account, data));
    _setOutAmount(_getPosition(vars.id, account, vars.trancheIndex).supplyShares, account);
    // ^^ Uses outAmount as temporary storage for pre-supply shares
}

function _postExecute(address, address account, bytes calldata data) internal override {
    LoanTokenHookVars memory vars = _decodeLoanTokenHookData(data);
    uint256 mintedShares = _getPosition(vars.id, account, vars.trancheIndex).supplyShares - getOutAmount(account);
    // ^^ Computes delta from stored pre-supply shares
    uint256 assetsSpent = _getPreAssetBalance(account) - getLoanTokenBalance(account, data);
    _checkMaxSharePrice(assetsSpent, mintedShares, vars.sharePriceLimitE27);
    _setOutAmount(mintedShares, account);
    // ^^ Final outAmount = minted supply shares (internal, non-transferable)
}
```

This pattern uses `_setOutAmount` as temporary storage for the pre-execution supply share count, then in `_postExecute` reads it back via `getOutAmount`, computes the delta, and overwrites with the final value. This is functional but fragile -- if anything between `_preExecute` and `_postExecute` calls `setOutAmount` externally (via the executor), the delta calculation breaks.

**Comparison with Morpho**: MorphoLendHook does the same pattern:
```solidity
function _preExecute(...) { _setOutAmount(_getSupplyShares(account, data), account); }
function _postExecute(...) { _setOutAmount(_getSupplyShares(account, data) - getOutAmount(account), account); }
```

So this is a known accepted pattern in the codebase. The Lotus version additionally tracks `_preAssetBalance` for slippage checking, which is a good enhancement.

### Finding 5.2: Lotus adds slippage protection via sharePriceLimitE27 -- Morpho does not have this

**Severity**: INFORMATIONAL (positive finding)

Lotus hooks implement `_checkMaxSharePrice` and `_checkMinSharePrice` in their `_postExecute` functions. This provides on-chain slippage protection that Morpho hooks lack. The Morpho hooks rely purely on off-chain bundler validation.

The implementation is correct:
- `_checkMaxSharePrice`: Used for operations where user spends assets to get shares (Lend, Repay). Ensures user does not overpay per share.
- `_checkMinSharePrice`: Used for operations where user burns shares to get assets (Withdraw, Borrow). Ensures user receives enough per share.
- `sharePriceLimitE27 == 0` disables the check (opt-out).

This is a genuine security improvement over the Morpho pattern.

### Finding 5.3: LotusBorrowHook _preExecute stores loanToken balance in outAmount, not borrow shares

**Severity**: LOW (correct pattern, different from LotusLendHook)
**Affected File**: LotusBorrowHook.sol, lines 49-64

```solidity
function _preExecute(...) {
    _setAsset(vars.marketParams.loanToken);
    _setPreShareBalance(account, _getPosition(vars.id, account, vars.trancheIndex).borrowShares);
    _setOutAmount(getLoanTokenBalance(account, data), account);
    // ^^ outAmount temporarily holds pre-borrow loanToken balance
}

function _postExecute(...) {
    uint256 assetsReceived = getLoanTokenBalance(account, data) - getOutAmount(account);
    uint256 sharesMinted = _getPosition(...).borrowShares - _getPreShareBalance(account);
    _checkMinSharePrice(assetsReceived, sharesMinted, vars.sharePriceLimitE27);
    _setOutAmount(assetsReceived, account);
    // ^^ Final outAmount = loan tokens received (ERC-20 assets)
}
```

This is correct. The final outAmount for borrow is the loan tokens received, which makes sense as downstream hooks would need to know how many tokens the account got.

### Finding 5.4: LotusSupplyAndBorrowHook outAmount is collateralConsumed, NOT loanTokensReceived

**Severity**: MEDIUM (semantic concern for hook chaining)
**Affected File**: LotusSupplyAndBorrowHook.sol, lines 77-86

```solidity
function _postExecute(...) {
    // Validates borrow share price
    _checkMinSharePrice(assetsReceived, sharesMinted, vars.sharePriceLimitE27);

    uint256 collateralConsumed = _getPreCollateralBalance(account) - getCollateralTokenBalance(account, data);
    _setOutAmount(collateralConsumed, account);  // outAmount = collateral consumed
}
```

The NatSpec says: "outAmount is collateral tokens consumed, matching Morpho's composite hook convention." And indeed MorphoSupplyAndBorrowHook does the same:
```solidity
function _postExecute(...) {
    _setOutAmount(getOutAmount(account) - getCollateralTokenBalance(account, data), account);
}
```

This is consistent but counterintuitive. A downstream hook chained with `usePrevHookAmount=true` after a SupplyAndBorrow would receive the collateral consumed, not the loan amount borrowed. The Morpho NatSpec explicitly warns about this, and so does Lotus. This is acceptable as long as the off-chain bundler is aware.

### Finding 5.5: LotusRepayAndWithdrawHook outAmount is collateralReceived

**Severity**: LOW (consistent with Morpho)
**Affected File**: LotusRepayAndWithdrawHook.sol, lines 103-112

```solidity
function _postExecute(...) {
    _checkMaxSharePrice(assetsSpent, sharesBurned, vars.sharePriceLimitE27);
    uint256 collateralReceived = getCollateralTokenBalance(account, data) - _getPreCollateralBalance(account);
    _setOutAmount(collateralReceived, account);
}
```

Morpho's `MorphoRepayAndWithdrawHook` does the same:
```solidity
function _postExecute(...) {
    _setOutAmount(getCollateralTokenBalance(account, data) - getOutAmount(account), account);
}
```

Consistent. The collateral received is the more useful output for downstream hooks.

---

## CATEGORY 6: LOW -- Execution Ordering and Approval Patterns

### Finding 6.1: Approval reset pattern is correct and follows Morpho convention

**Severity**: INFORMATIONAL (positive finding)

All hooks that transfer tokens to Lotus correctly implement:
1. Reset approval to 0 (handles USDT-style tokens)
2. Set approval to exact amount
3. Execute the Lotus call
4. Reset approval to 0 (clean up dangling allowance)

Example from LotusLendHook:
```solidity
executions[0] = _approvalExecution(vars.marketParams.loanToken, 0);
executions[1] = _approvalExecution(vars.marketParams.loanToken, vars.assets);
executions[2] = /* Lotus supply call */;
executions[3] = _approvalExecution(vars.marketParams.loanToken, 0);
```

This matches exactly what Morpho hooks do. Correct.

### Finding 6.2: LotusRepayHook full-repayment approval uses type(uint256).max

**Severity**: LOW (acceptable pattern)
**Affected File**: LotusRepayHook.sol, line 36

For full repayment, the hook approves `type(uint256).max` because the exact assets needed for the share-denominated repayment may exceed a pre-calculated amount due to interest accrual between `build()` and execution.

Morpho's MorphoRepayHook does the same (approves a pre-computed amount via `sharesToAssets`), but Lotus takes the simpler approach of max approval since it always resets to 0 afterwards. This is acceptable and arguably safer (avoids under-approval edge cases).

### Finding 6.3: LotusRepayAndWithdrawHook repay-then-withdraw ordering is correct

**Severity**: INFORMATIONAL

The composite RepayAndWithdraw hook correctly orders: repay first, then withdrawCollateral. This is critical because withdrawing collateral before repaying could violate health factor constraints, causing the withdraw to revert.

Similarly, SupplyAndBorrow correctly orders: supplyCollateral first, then borrow.

Both match Morpho's composite hook ordering.

---

## CATEGORY 7: DATA LAYOUT AND ENCODING

### Finding 7.1: Byte offsets are arithmetically correct

**Severity**: INFORMATIONAL (positive finding)

Loan-token layout verification:
| Field | Type | Size | Offset | Correct? |
|-------|------|------|--------|----------|
| loanToken | address | 20 | 0 | YES |
| riskEngine | address | 20 | 20 | YES |
| liquidationModule | address | 20 | 40 | YES |
| trancheConfigsHash | bytes32 | 32 | 60 | YES |
| trancheIndex | uint256 | 32 | 92 | YES |
| assets | uint256 | 32 | 124 | YES |
| shares | uint256 | 32 | 156 | YES |
| sharePriceLimitE27 | uint256 | 32 | 188 | YES |
| usePrevHookAmount | bool | 1 | 220 | YES |
| isFullRepayment | bool | 1 | 221 | YES |
| riskEngineData | bytes | dynamic | 222+ | YES |

Min data length = 222 bytes (LOAN_HOOK_MIN_DATA_LENGTH). Correct.

Collateral-supply layout verification:
| Field | Type | Size | Offset | Correct? |
|-------|------|------|--------|----------|
| loanToken | address | 20 | 0 | YES |
| riskEngine | address | 20 | 20 | YES |
| liquidationModule | address | 20 | 40 | YES |
| trancheConfigsHash | bytes32 | 32 | 60 | YES |
| trancheIndex | uint256 | 32 | 92 | YES |
| amount | uint256 | 32 | 124 | YES |
| usePrevHookAmount | bool | 1 | 156 | YES |

Fixed length = 157 bytes (COLLATERAL_SUPPLY_DATA_LENGTH). Correct.

Composite layout verification:
| Field | Type | Size | Offset | Correct? |
|-------|------|------|--------|----------|
| loanToken | address | 20 | 0 | YES |
| riskEngine | address | 20 | 20 | YES |
| liquidationModule | address | 20 | 40 | YES |
| trancheConfigsHash | bytes32 | 32 | 60 | YES |
| trancheIndex | uint256 | 32 | 92 | YES |
| collateralAmount | uint256 | 32 | 124 | YES |
| loanAssets | uint256 | 32 | 156 | YES |
| loanShares | uint256 | 32 | 188 | YES |
| collateralWithdrawAmount | uint256 | 32 | 220 | YES |
| sharePriceLimitE27 | uint256 | 32 | 252 | YES |
| usePrevHookAmount | bool | 1 | 284 | YES |
| isFullRepayment | bool | 1 | 285 | YES |
| riskEngineData | bytes | dynamic | 286+ | YES |

Min data length = 286 bytes (COMPOSITE_HOOK_MIN_DATA_LENGTH). Correct.

### Finding 7.2: Collateral-withdraw layout shares same base offsets with collateral-supply

**Severity**: INFORMATIONAL

`LotusWithdrawCollateralHook` uses the same offset constants as `LotusSupplyCollateralHook` for the fixed portion (up to and including `usePrevHookAmount` at offset 156), then appends `riskEngineData` from offset 157. This makes sense because `withdrawCollateral` takes `riskEngineData` while `supplyCollateral` does not.

The validation differs accordingly:
- Supply: `data.length != COLLATERAL_SUPPLY_DATA_LENGTH` (exact match, 157 bytes, no trailing data)
- Withdraw: `data.length < COLLATERAL_WITHDRAW_MIN_DATA_LENGTH` (minimum 157, accepts trailing riskEngineData)

This is correct.

### Finding 7.3: MarketParams structure differs from Morpho -- no collateralToken field

**Severity**: INFORMATIONAL (design difference, not a bug)

Lotus `MarketParams` has 4 fields: `loanToken`, `riskEngine`, `liquidationModule`, `trancheConfigsHash`.
Morpho `MarketParams` has 5 fields: `loanToken`, `collateralToken`, `oracle`, `irm`, `lltv`.

In Lotus, the collateral token is per-tranche (stored in `TrancheConfig`), not per-market. This means the hooks must look up the collateral token via `LOTUS.getTrancheConfig(id, trancheIndex)` at runtime, which is why `getCollateralTokenAddress` is `view` (not `pure` like in Morpho).

This architectural difference is handled correctly. The hooks properly fetch the collateral token dynamically.

---

## CATEGORY 8: MISSING FUNCTIONALITY vs MORPHO

### Finding 8.1: Lotus has no equivalent to MorphoRepayHook.accrueInterest() in _preExecute

**Severity**: MEDIUM
**Affected Files**: LotusRepayHook.sol, LotusRepayAndWithdrawHook.sol

Morpho's `MorphoRepayHook._preExecute` explicitly calls `IMorpho(morpho).accrueInterest(marketParams)` before capturing the pre-balance. This ensures the share-to-asset conversion is fresh when full repayment is executed.

```solidity
// MorphoRepayHook._preExecute:
IMorpho(morpho).accrueInterest(marketParams);
_setOutAmount(getLoanTokenBalance(account, data), account);
```

The Lotus hooks do NOT call any equivalent interest accrual function in `_preExecute`:
```solidity
// LotusRepayHook._preExecute:
_setAsset(vars.marketParams.loanToken);
_setPreShareBalance(account, _getPosition(...).borrowShares);
_setOutAmount(getLoanTokenBalance(account, data), account);
// No interest accrual!
```

**Risk Assessment**: If Lotus has an `accrueInterest`-equivalent function, it should be called before full repayment operations to ensure accurate share-to-asset conversion. If Lotus handles interest accrual internally within the `repay` function (which is common), then this is not a bug -- but it should be explicitly documented. If Lotus has stale interest, the `type(uint256).max` approval in the repay hook may not cover the actual amount, though the approval reset at the end mitigates residual allowance risk.

**Recommendation**: Verify whether Lotus requires explicit interest accrual before repay operations. If yes, add it to `_preExecute` for LotusRepayHook and LotusRepayAndWithdrawHook. If no (auto-accrual in repay), add a comment documenting this.

### Finding 8.2: Lotus lacks MorphoSupplyAndBorrow's deriveLoanAmount oracle-based calculation

**Severity**: INFORMATIONAL (design choice, not a bug)

Morpho's `MorphoSupplyAndBorrowHook` uses an oracle to compute the borrow amount from the collateral amount and a user-specified LTV ratio:
```solidity
uint256 loanAmount = deriveLoanAmount(vars.amount, vars.ltvRatio, vars.lltv, vars.oracle);
```

Lotus's `LotusSupplyAndBorrowHook` takes the borrow amount as an explicit user parameter (`vars.loanAssets`):
```solidity
if (vars.collateralAmount == 0 || vars.loanAssets == 0) revert AMOUNT_NOT_VALID();
```

This is a valid design choice. The Lotus approach is simpler and avoids oracle dependency in the hook, delegating the LTV calculation to the off-chain bundler. The downside is less on-chain safety (no LTV ratio enforcement), but the risk engine data handles this.

### Finding 8.3: No separate MorphoSupplyHook equivalent -- LotusSupplyCollateralHook covers it

**Severity**: INFORMATIONAL

In Morpho, `MorphoSupplyHook` supplies collateral to a market (calls `supplyCollateral`). In Lotus, `LotusSupplyCollateralHook` does the same. `LotusLendHook` is the equivalent of `MorphoLendHook` (supplying loan tokens to earn interest). The naming is clearer in Lotus -- "Supply" means collateral, "Lend" means loan tokens.

Morpho's naming: `MorphoSupplyHook` = supply collateral, `MorphoLendHook` = supply loan tokens (lend).
Lotus's naming: `LotusSupplyCollateralHook` = supply collateral, `LotusLendHook` = supply loan tokens (lend).

The Lotus naming is more explicit and less confusing. No missing hooks.

---

## CATEGORY 9: COMPOSITE HOOK PATTERNS

### Finding 9.1: LotusSupplyAndBorrowHook correctly prevents unused fields

**Severity**: INFORMATIONAL (positive finding)
**Affected File**: LotusSupplyAndBorrowHook.sol, line 34

```solidity
if (vars.loanShares != 0 || vars.collateralWithdrawAmount != 0 || vars.isFullRepayment) {
    revert INCONSISTENT_ASSETS_AND_SHARES();
}
```

This correctly rejects:
- `loanShares != 0` (borrow must be asset-denominated)
- `collateralWithdrawAmount != 0` (not withdrawing collateral in supply-and-borrow)
- `isFullRepayment` (not repaying in supply-and-borrow)

### Finding 9.2: LotusRepayAndWithdrawHook full-repayment validation

**Severity**: LOW (minor edge case)
**Affected File**: LotusRepayAndWithdrawHook.sol, lines 36-49

For full repayment:
```solidity
if (vars.collateralAmount != 0 || vars.loanAssets != 0 || vars.loanShares != 0 || vars.usePrevHookAmount) {
    revert INCONSISTENT_ASSETS_AND_SHARES();
}
vars.loanShares = _getPosition(vars.id, account, vars.trancheIndex).borrowShares;
if (vars.loanShares == 0 || vars.collateralWithdrawAmount == 0) revert AMOUNT_NOT_VALID();
```

For partial repayment:
```solidity
if (vars.collateralAmount != 0 || vars.collateralWithdrawAmount == 0) revert AMOUNT_NOT_VALID();
```

**Observation**: In partial repayment, `collateralWithdrawAmount` must be user-specified (non-zero). This means the user must specify both the repay amount AND the collateral to withdraw. Unlike Morpho's `MorphoRepayAndWithdrawHook` which auto-calculates proportional collateral withdrawal:
```solidity
ctx.collateralForWithdraw = deriveCollateralForPartialRepayment(ctx.id, account, vars.amount, ctx.fullCollateral);
```

Lotus delegates collateral withdrawal amount to the user. This is a simpler design but places more responsibility on the off-chain bundler to compute the correct withdrawal amount. Not a bug, but a design difference worth noting.

### Finding 9.3: LotusRepayAndWithdrawHook _setAsset uses collateralToken

**Severity**: LOW (semantic question)
**Affected File**: LotusRepayAndWithdrawHook.sol, line 96

```solidity
_setAsset(vars.collateralToken);
```

The `asset` transient variable is set to the collateral token. Combined with `outAmount = collateralReceived`, this means downstream hooks see this as a "collateral token flow" hook. This is consistent with the outAmount semantics. Morpho does the same via `getCollateralTokenBalance`. Consistent.

---

## CATEGORY 10: HOOK SIZING

### Finding 10.1: Estimated contract sizes

**Severity**: LOW

The hooks are lean single-purpose contracts. Estimated sizing:

| Hook | Approx Logic Complexity | Risk of 24KB? |
|------|------------------------|---------------|
| BaseLotusLoanHook | Moderate (base + transient storage helpers) | N/A (abstract) |
| LotusLendHook | Low (4 executions + slippage) | NO |
| LotusBorrowHook | Very Low (1 execution + slippage) | NO |
| LotusRepayHook | Low (4 executions, branching) | NO |
| LotusWithdrawHook | Very Low (1 execution + slippage) | NO |
| LotusSupplyCollateralHook | Low (4 executions) | NO |
| LotusWithdrawCollateralHook | Very Low (1 execution) | NO |
| LotusSupplyAndBorrowHook | Moderate (5 executions + slippage) | NO |
| LotusRepayAndWithdrawHook | Moderate (5 executions, branching + slippage) | NO |

None of these hooks are anywhere near the 24KB limit. They follow the same lean patterns as Morpho hooks. No sizing concerns.

---

## CATEGORY 11: ADDITIONAL OBSERVATIONS

### Finding 11.1: Position.borrowShares is uint128, stored in uint256 transient storage -- safe

The `Position` struct uses `uint128 borrowShares`, but the transient storage helpers store/load `uint256`. The implicit upcast from `uint128` to `uint256` is safe. The delta calculations (`pre - post`) also work correctly since both values are consistently widened.

### Finding 11.2: _decodeMarketVars makes external calls in a view context -- acceptable

`_decodeMarketVars` calls `LOTUS.getNumMarketTranches(id)` and `_getCollateralToken` calls `LOTUS.getTrancheConfig(id, trancheIndex)`. These are `view` calls to the Lotus contract, which is acceptable in `_buildHookExecutions` (also `view`). However, this means `_buildHookExecutions` will revert if the Lotus contract is not deployed or the market does not exist, which is the intended behavior.

### Finding 11.3: _resolveAssets has a subtle behavior when usePrevHookAmount=true

**Severity**: LOW
**Affected File**: BaseLotusLoanHook.sol, lines 289-303

```solidity
function _resolveAssets(...) internal view returns (uint256 resolvedAssets, uint256 resolvedShares) {
    if (!usePrevHookAmount) return (assets, shares);
    if (shares != 0) revert INCONSISTENT_ASSETS_AND_SHARES();
    resolvedAssets = _resolveAmount(prevHook, account, assets, true);
    // resolvedShares stays 0 (default)
}
```

When `usePrevHookAmount=true`, shares MUST be 0 and the resolved amount goes into assets. This means chaining only works for asset-denominated operations. If a downstream hook wanted to specify shares via chaining, it cannot. This is the correct restriction given that `getOutAmount` from a previous hook returns a single number that represents assets or shares ambiguously.

### Finding 11.4: Constructor validates lotus_ != address(0) -- good

```solidity
constructor(address lotus_, bytes32 hookSubtype_) BaseHook(ISuperHook.HookType.NONACCOUNTING, hookSubtype_) {
    if (lotus_ == address(0)) revert ADDRESS_NOT_VALID();
    LOTUS = ILotus(lotus_);
}
```

This is correct and matches the Morpho pattern.

### Finding 11.5: LotusSupplyCollateralHook enforces exact data length while others use minimum

**Severity**: LOW (intentional design)
**Affected File**: BaseLotusLoanHook.sol, line 193

```solidity
function _decodeCollateralSupplyHookData(bytes memory data) internal view returns (CollateralHookVars memory vars) {
    if (data.length != COLLATERAL_SUPPLY_DATA_LENGTH) revert INVALID_DATA_LENGTH();
    // ^^ EXACT length check, not minimum
```

This is because `supplyCollateral` takes no `riskEngineData` -- there is nothing beyond the fixed fields. The exact check prevents trailing garbage bytes. This is good defensive coding.

---

## SUMMARY TABLE

| # | Finding | Severity | Action Required |
|---|---------|----------|-----------------|
| 1.1 | inspect() returns non-address data (trancheIndex, keccak256 hashes) | CRITICAL | YES -- restructure to only return addresses |
| 2.1 | decodeAmount/replaceCalldataAmount offset wrong for RepayAndWithdrawHook | HIGH | YES -- composite hooks must override |
| 3.1 | LotusWithdrawHook uses LOAN_REPAY (matches Morpho convention) | MEDIUM | NO -- matches convention |
| 4.1 | Missing NatSpec data layout documentation on contracts | MEDIUM | YES -- add inline NatSpec |
| 5.4 | SupplyAndBorrow outAmount is collateralConsumed (documented) | MEDIUM | NO -- matches convention, documented |
| 8.1 | No accrueInterest call in repay _preExecute | MEDIUM | VERIFY -- depends on Lotus protocol behavior |
| 5.1 | outAmount used as temporary storage in _preExecute | LOW | NO -- accepted pattern |
| 5.3 | BorrowHook tracks loanToken balance correctly | LOW | NO -- correct |
| 6.2 | Full-repayment uses max approval (cleaned up) | LOW | NO -- acceptable |
| 9.2 | RepayAndWithdraw requires user-specified withdrawal amount | LOW | NO -- design choice |
| 11.3 | _resolveAssets restricts chaining to asset-denominated | LOW | NO -- correct restriction |
| 11.5 | SupplyCollateral enforces exact length | LOW | NO -- good defensive coding |
| All others | Positive findings or informational | INFO | NO |

## RECOMMENDED PRIORITY ORDER

1. **Fix inspect() functions** -- CRITICAL protocol requirement violation
2. **Override decodeAmount/replaceCalldataAmount in composite hooks** -- HIGH bundler compatibility
3. **Verify accrueInterest requirement** with Lotus protocol team -- MEDIUM
4. **Add NatSpec data layouts** to all hook contracts -- MEDIUM (convention compliance)
