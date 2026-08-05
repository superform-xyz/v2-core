# Aave V3 Hook Suite — Implementation Plan (MVP)

Author: superform-hook-master
Status: Ready for Master Claude review → implementation
Branch requirement: hook code on the feature branch `feat/aave-v3-hooks`; **deployment wiring
(Constants/deploy script/bytecode/manifest) requires `pre-dev`** — alert the user if not on it when
doing Phase 4. Phases 1–3 (vendor, hooks, tests) are branch-agnostic.

This plan mirrors `src/hooks/loan/aave-v4/*` almost 1:1, substituting the V3 `IPool` (asset-keyed)
for the V4 Spoke (reserveId-keyed), dropping the two reserveId slots, and adding a `pool` address +
a single `interestRateMode` byte. Every spec-flow gap is resolved inline (see §11).

---

## 1. File List (exact paths)

### Create — vendor
- `src/vendor/aave-v3/IPool.sol` (MIT, `pragma solidity 0.8.30;`)
- `src/vendor/aave-v3/DataTypes.sol` (MIT, `pragma solidity 0.8.30;`) — only `ReserveDataLegacy`,
  `ReserveConfigurationMap`, `UserConfigurationMap`.

### Create — hooks (`src/hooks/loan/aave-v3/`)
- `BaseAaveV3LoanHook.sol`
- `AaveV3SupplyHook.sol`
- `AaveV3WithdrawHook.sol`
- `AaveV3BorrowHook.sol`
- `AaveV3RepayHook.sol`
- `AaveV3SupplyAndBorrowHook.sol`
- `AaveV3RepayAndWithdrawHook.sol`
- `AaveV3RepayWithATokensHook.sol`

### Create — tests
- `test/unit/hooks/loan/AaveV3LoanHooks.t.sol` (mirror `AaveV4LoanHooks.t.sol`, `Helpers` + mock Pool)
- `test/integration/AaveV3HooksIntegrationTest.t.sol` (Ethereum Core, `MinimalBaseIntegrationTest`)
- `test/integration/AaveV3MultiReserveHooksIntegrationTest.t.sol` (Ethereum Core multi-asset + Prime
  market = the multi-market proof)
- `test/integration/AaveV3ArbitrumHooksIntegrationTest.t.sol`
- `test/integration/AaveV3BaseHooksIntegrationTest.t.sol`
- `test/integration/AaveV3OptimismHooksIntegrationTest.t.sol`
- `test/integration/AaveV3PolygonHooksIntegrationTest.t.sol`

  (File-per-chain is the MVP choice — resolves spec-flow §4 item 20. A shared internal
  `_AaveV3IntegrationBase` abstract with `pool()`/asset getters overridden per chain keeps each file
  small; put it inside `AaveV3HooksIntegrationTest.t.sol` or a small shared helper.)

### Modify — deployment wiring (Phase 4, `pre-dev`)
- `script/utils/Constants.sol` — 7 `AAVE_V3_*_HOOK_KEY` string constants.
- `script/DeployV2OtherHooks.s.sol` — `AaveV3HookAddresses` struct, `_deployAaveV3Hooks`,
  `_deployAaveV3HooksSet`, call from the same place `_deployAaveV4Hooks` is invoked (~line 189).
- `script/run/deploy/deploy_v2_other_hooks_staging_prod.sh` — add 7 names to the compile list +
  a `missing_aavev3` guard block mirroring the `missing_aavev4` block (~lines 178–197).
- `tooling/hook-classification.yaml` — 7 entries (see §9).
- `tooling/hook-enrichment.yaml` — `compatibleProtocols` + `amountMeta` entries (see §9).
- `test/utils/Constants.sol` — pool addresses, fork blocks, asset addresses per chain (see §8).
- `manifests/hooks.json` — regenerated via `make manifest` (do not hand-edit).

Do **not** touch `DeployV2Core.s.sol` — Aave hooks live in the "OtherHooks" deployer, matching V4.

---

## 2. Vendored `IPool` subset — exact signatures

`src/vendor/aave-v3/IPool.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { DataTypes } from "./DataTypes.sol";

/// @title IPool (Aave V3 minimal subset)
/// @notice Verbatim signatures from aave-dao/aave-v3-origin src/contracts/interfaces/IPool.sol.
///         Only the functions the Superform V3 loan hooks + their fork tests use are vendored.
interface IPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;
    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) external returns (uint256);
    function repayWithATokens(address asset, uint256 amount, uint256 interestRateMode)
        external
        returns (uint256);

    // Used only by fork tests to resolve aToken / variableDebtToken and assert positions.
    function getReserveData(address asset) external view returns (DataTypes.ReserveDataLegacy memory);
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
}
```

Notes:
- `setUserUseReserveAsCollateral` is intentionally **omitted** (gap #1 — no forced collateral toggle).
- Hooks call only the 5 mutating functions. `getReserveData` / `getUserAccountData` exist for tests.
- Aave publishes `IPool` as `pragma ^0.8.0`; re-pinning the vendored copy to `0.8.30` is fine and
  matches the repo convention.

`src/vendor/aave-v3/DataTypes.sol` — field order is ABI-critical (aToken@8, variableDebtToken@10):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

library DataTypes {
    struct ReserveConfigurationMap { uint256 data; }
    struct UserConfigurationMap    { uint256 data; }

    /// @dev ABI-stable across Aave V3.0 → V3.4. Index comments are load-bearing.
    struct ReserveDataLegacy {
        ReserveConfigurationMap configuration;  // 0
        uint128 liquidityIndex;                 // 1
        uint128 currentLiquidityRate;           // 2
        uint128 variableBorrowIndex;            // 3
        uint128 currentVariableBorrowRate;      // 4
        uint128 currentStableBorrowRate;        // 5  (V3.2+: reads 0)
        uint40  lastUpdateTimestamp;            // 6
        uint16  id;                             // 7
        address aTokenAddress;                  // 8  <-- aToken
        address stableDebtTokenAddress;         // 9  (V3.2+: address(0) — never dereference)
        address variableDebtTokenAddress;       // 10 <-- variable debt token
        address interestRateStrategyAddress;    // 11 (V3.4: deprecated)
        uint128 accruedToTreasury;              // 12
        uint128 unbacked;                       // 13
        uint128 isolationModeTotalDebt;         // 14
    }
}
```

---

## 3. Data Layouts (byte offsets — final, locked)

52-byte strategy header first (neither field used → `placeholder0`/`placeholder1`). Base mandates
`loanToken@52`, `collateralToken@72`. `pool@92` (address, 20 bytes → ends at 112).

### 3a. Supply / Withdraw (single amount, no rate byte)
```
[0]   bytes32 placeholder0
[32]  address placeholder1
[52]  address loanToken            // = supplied/withdrawn asset (== collateralToken for single-asset)
[72]  address collateralToken      // = supplied/withdrawn asset; measured for balance-delta
[92]  address pool
[112] uint256 amount               // Withdraw: type(uint256).max = full
[144] bool    usePrevHookAmount
```
min data length = **145**

### 3b. Borrow / Repay / RepayWithATokens (rate byte + single amount)
```
[52]  address loanToken            // = debt asset
[72]  address collateralToken      // Borrow/Repay: = debt asset. RepayWithATokens: = aToken address
[92]  address pool
[112] uint8   interestRateMode     // validated == 2
[113] uint256 amount               // Repay / RepayWithATokens: type(uint256).max = full
[145] bool    usePrevHookAmount
```
min data length = **146**

### 3c. SupplyAndBorrow (rate byte + two amounts)
```
[52]  address loanToken            // = borrow asset
[72]  address collateralToken      // = supplied asset
[92]  address pool
[112] uint8   interestRateMode     // validated == 2 (borrow leg)
[113] uint256 supplyAmount         // first leg; usePrevHookAmount applies to THIS leg
[145] uint256 borrowAmount         // second leg; FIXED calldata (gap #4)
[177] bool    usePrevHookAmount
```
min data length = **178**

### 3d. RepayAndWithdraw (rate byte + two amounts)
```
[52]  address loanToken            // = debt asset (repaid)
[72]  address collateralToken      // = collateral asset (withdrawn); measured for balance-delta
[92]  address pool
[112] uint8   interestRateMode     // validated == 2 (repay leg)
[113] uint256 repayAmount          // first leg; usePrevHookAmount applies to THIS leg; max = full repay
[145] uint256 withdrawAmount       // second leg; FIXED calldata; max = full withdraw
[177] bool    usePrevHookAmount
```
min data length = **178**

Full repay/withdraw is signaled by the **`type(uint256).max` sentinel in the amount field** — there
is **no `isFullRepayment` bool** (unlike V4). This is a deliberate simplification enabled by V3's
`repay(max)` / `withdraw(max)` semantics.

Decode helpers: `BytesLib.toAddress` (offsets 52/72/92), `BytesLib.toUint8(data, 112)` for the rate
byte, `BytesLib.toUint256` for amounts, `_decodeBool` for the flag.

---

## 4. `BaseAaveV3LoanHook` design

`abstract contract BaseAaveV3LoanHook is BaseLoanHook` (same parent as V4; `BaseLoanHook` already
gives NONACCOUNTING, `getLoanTokenAddress`/`getCollateralTokenAddress` at 52/72, the balance getters,
and the sizing-interface virtuals).

### 4a. Constants
```solidity
uint256 internal constant LOAN_TOKEN_OFFSET       = 52;
uint256 internal constant COLLATERAL_TOKEN_OFFSET = 72;
uint256 internal constant POOL_OFFSET             = 92;

// single-asset supply/withdraw
uint256 internal constant SW_AMOUNT_OFFSET   = 112;
uint256 internal constant SW_USE_PREV_OFFSET = 144;
uint256 internal constant SW_MIN_LEN         = 145;

// borrow / repay / repayWithATokens
uint256 internal constant RATE_MODE_OFFSET   = 112;
uint256 internal constant BR_AMOUNT_OFFSET   = 113;
uint256 internal constant BR_USE_PREV_OFFSET = 145;
uint256 internal constant BR_MIN_LEN         = 146;

// combined
uint256 internal constant CB_AMOUNT1_OFFSET  = 113;   // supply / repay leg
uint256 internal constant CB_AMOUNT2_OFFSET  = 145;   // borrow / withdraw leg
uint256 internal constant CB_USE_PREV_OFFSET = 177;
uint256 internal constant CB_MIN_LEN         = 178;

uint256 internal constant VARIABLE_RATE_MODE = 2;
```

### 4b. Unified `Vars` struct (single struct per the locked decision)
```solidity
struct Vars {
    address loanToken;
    address collateralToken;
    address pool;
    uint8   interestRateMode; // 0 for supply/withdraw (no byte); validated for borrow/repay families
    uint256 amount;           // first / only leg
    uint256 secondAmount;     // borrowAmount or withdrawAmount (combined only)
    bool    usePrevHookAmount;
}
```

### 4c. Errors
```solidity
error INVALID_DATA_LENGTH();
error INVALID_RATE_MODE();   // interestRateMode != 2
```
(`AMOUNT_NOT_VALID`, `ADDRESS_NOT_VALID`, `INVALID_AMOUNTS_LENGTH` inherited from BaseHook.)

### 4d. Constructor
```solidity
constructor(bytes32 hookSubtype_) BaseLoanHook(hookSubtype_) {}
```
Each concrete hook passes `HookSubTypes.LOAN` (inflow-ish: supply/borrow/supplyAndBorrow) or
`HookSubTypes.LOAN_REPAY` (withdraw/repay/repayAndWithdraw/repayWithATokens) — mirror V4's mapping
(supply=LOAN, withdraw=LOAN_REPAY, borrow=LOAN, repay=LOAN_REPAY, supplyAndBorrow=LOAN,
repayAndWithdraw=LOAN_REPAY, repayWithATokens=LOAN_REPAY).

### 4e. Decoders (shared, `internal pure`)
```solidity
function _decodeSW(bytes memory data) internal pure returns (Vars memory v);           // supply/withdraw
function _decodeBR(bytes memory data) internal pure returns (Vars memory v);           // borrow/repay/repayWithATokens
function _decodeSupplyAndBorrow(bytes memory data) internal pure returns (Vars memory v);
function _decodeRepayAndWithdraw(bytes memory data) internal pure returns (Vars memory v);
```
Each: length check → `INVALID_DATA_LENGTH`; decode loanToken/collateralToken/pool → all-non-zero or
`ADDRESS_NOT_VALID`; `_decodeBR*` additionally read the rate byte and **`if (mode != 2) revert
INVALID_RATE_MODE();`**. Rate validation lives in the decoders (single source, hit by both
`_buildHookExecutions` and `inspect`), resolving spec-flow §3.5/§5.2.

### 4f. Sizing-interface plumbing (bundler `decodeAmounts` / `replaceCalldataAmounts` / usePrev)
Add two virtual offset accessors so the single-amount families share one implementation:
```solidity
function _amountOffset()  internal pure virtual returns (uint256) { return SW_AMOUNT_OFFSET; }
function _usePrevOffset() internal pure virtual returns (uint256) { return SW_USE_PREV_OFFSET; }
```
Override `decodeUsePrevHookAmount`, `decodeAmounts`, `amountRoles`, `replaceCalldataAmounts` in base
to use `_amountOffset()`/`_usePrevOffset()` (single amount, role IN/TOKEN). Then:
- Supply/Withdraw: inherit defaults (112 / 144).
- Borrow/Repay/RepayWithATokens: override `_amountOffset→113`, `_usePrevOffset→145`.
- SupplyAndBorrow & RepayAndWithdraw: override the four sizing methods **directly** (2 amounts;
  offsets 113 & 145; usePrev 177; `amountRoles` = `[IN/TOKEN, OUT/TOKEN]`), exactly like the V4
  combined hooks (`AaveV4SupplyAndBorrowHook.decodeAmounts/replaceCalldataAmounts/amountRoles`).

`_supportsSizingInterface()` stays `true` (inherited from `BaseLoanHook`).

### 4g. Shared build helpers (keep bodies in the concrete hooks or as `internal pure` builders)
Prefer small `internal pure` execution builders in the base to avoid divergence:
```solidity
function _approve0(address token, address pool) private pure returns (Execution memory);
function _forceApprove(address token, address pool, uint256 amount) private pure returns (Execution memory);
```
Use `SafeERC20.forceApprove` semantics via `abi.encodeCall(IERC20.approve, ...)` — **NOTE**: V4 uses
plain `IERC20.approve` in the built `Execution` (the account executes it), not a live `forceApprove`
call. Mirror V4 exactly: emit `approve(pool, 0)` then `approve(pool, amount)` then `approve(pool, 0)`.
This is the account-executed equivalent of force-approve bracketing (USDT-safe because we always
zero first). Do **not** import SafeERC20 into the hook — the hook only builds calldata.

### 4h. pipe/accounting
NONACCOUNTING (from `BaseLoanHook`). Per-hook `_preExecute`/`_postExecute` set outAmount/outToken via
balance-delta on the base helpers (`getLoanTokenBalance` @52 / `getCollateralTokenBalance` @72) — see
§5. Default `_pipeMode()` = TRANSFORM (correct; these hooks transform, not passthrough).

---

## 5. Per-hook specification

For all: `name()`/`description()` `external pure`; `inspect()` returns **`abi.encodePacked(v.pool)`**
(address only — protocol requirement, mirror V4 which returns the spoke). `_buildHookExecutions` is
`view` and resolves `usePrevHookAmount` via `ISuperHookResult(prevHook).getOutAmount(account)`
**with no `getOutToken` guard** (gap #3 — match V4; rationale + tests in §11.3).

### 5.1 AaveV3SupplyHook  (subtype LOAN)
Decode `_decodeSW`. `if (usePrevHookAmount) amount = getOutAmount(prevHook)`. `if (amount==0) revert
AMOUNT_NOT_VALID`.
Executions (4) — **NO `setUserUseReserveAsCollateral`** (gap #1):
1. `collateralToken.approve(pool, 0)`
2. `collateralToken.approve(pool, amount)`
3. `pool.supply(collateralToken, amount, account, 0)`
4. `collateralToken.approve(pool, 0)`
`_preExecute`: `_setOutAmount(getCollateralTokenBalance(account,data))`.
`_postExecute`: `_setOutAmount(getOutAmount - getCollateralTokenBalance(...))` (collateral consumed);
`_setOutToken(getCollateralTokenAddress(data))`.
inspect → `pool`.

### 5.2 AaveV3WithdrawHook  (subtype LOAN_REPAY)
Decode `_decodeSW`. Resolve usePrev. `amount==0 → revert` (note: `type(uint256).max` is allowed for
full withdraw and is `!= 0`).
Executions (1): `pool.withdraw(collateralToken, amount, account)`.
`_preExecute`: outAmount = collateral balance. `_postExecute`: outAmount = post − pre (received);
outToken = collateralToken.
inspect → `pool`.

### 5.3 AaveV3BorrowHook  (subtype LOAN)
Decode `_decodeBR` (validates mode==2). Resolve usePrev. `amount==0 → revert`.
Executions (1): `pool.borrow(loanToken, amount, 2, 0, account)`.
`_preExecute`: outAmount = loan balance. `_postExecute`: outAmount = post − pre (borrowed);
outToken = loanToken.
inspect → `pool`.

### 5.4 AaveV3RepayHook  (subtype LOAN_REPAY)
Decode `_decodeBR`. Resolve usePrev (`amount==0 → revert`). Full repay = `amount == type(uint256).max`.
Executions (4):
1. `loanToken.approve(pool, 0)`
2. `loanToken.approve(pool, amount == max ? type(uint256).max : amount)`
3. `pool.repay(loanToken, amount, 2, account)`
4. `loanToken.approve(pool, 0)`  ← resets allowance even after `repay(max)` (gap #5)
`_preExecute`: outAmount = loan balance. `_postExecute`: outAmount = pre − post (spent);
outToken = loanToken.
inspect → `pool`.

### 5.5 AaveV3SupplyAndBorrowHook  (subtype LOAN; two amounts)
Decode `_decodeSupplyAndBorrow` (validates mode==2). `usePrevHookAmount` applies to the **supply
(first) leg only**; `borrowAmount` is fixed calldata (gap #4). `if (amount==0 || borrowAmount==0)
revert AMOUNT_NOT_VALID`.
Executions (5) — **no collateral toggle**:
1. `collateralToken.approve(pool, 0)`
2. `collateralToken.approve(pool, supplyAmount)`
3. `pool.supply(collateralToken, supplyAmount, account, 0)`
4. `pool.borrow(loanToken, borrowAmount, 2, 0, account)`
5. `collateralToken.approve(pool, 0)`
`_preExecute`: outAmount = collateral balance. `_postExecute`: outAmount = pre − post (collateral
consumed by supply leg); outToken = collateralToken.
**Doc note (gap #4):** outAmount tracks *collateral consumed*, NOT borrowed loanToken. Override the
sizing methods for 2 amounts (roles `[IN/TOKEN, OUT/TOKEN]`).
inspect → `pool`.

### 5.6 AaveV3RepayAndWithdrawHook  (subtype LOAN_REPAY; two amounts)
Decode `_decodeRepayAndWithdraw` (validates mode==2). `usePrevHookAmount` applies to the **repay
(first) leg only**; `withdrawAmount` fixed. Full repay = `repayAmount == max`; full withdraw =
`withdrawAmount == max`. `if (repayAmount==0 || withdrawAmount==0) revert`.
Executions (5):
1. `loanToken.approve(pool, 0)`
2. `loanToken.approve(pool, repayAmount == max ? type(uint256).max : repayAmount)`
3. `pool.repay(loanToken, repayAmount, 2, account)`
4. `loanToken.approve(pool, 0)`  ← reset even for `repay(max)`
5. `pool.withdraw(collateralToken, withdrawAmount, account)`
`_preExecute`: outAmount = collateral balance. `_postExecute`: outAmount = post − pre (collateral
withdrawn); outToken = collateralToken. Sizing: 2 amounts, roles `[IN/TOKEN, OUT/TOKEN]`.
inspect → `pool`.
**Doc note (gap #4):** partial-repay-then-fixed-withdraw can revert on Aave's HF check or leave the
position under-collateralized; the bundler is responsible for consistent leg sizing.

### 5.7 AaveV3RepayWithATokensHook  (subtype LOAN_REPAY)  ← V3-only 7th hook
Decode `_decodeBR` (validates mode==2). Full = `amount == type(uint256).max`. **No approval** (burns
the account's own aTokens). Resolve usePrev; `amount==0 → revert`.
Executions (1): `pool.repayWithATokens(loanToken, amount, 2)`.
**outAmount/outToken semantics (gap #2, resolves spec-flow §2.4):**
- `collateralToken@72` carries the **aToken address** for this hook (the bundler resolves it via
  `getReserveData(loanToken).aTokenAddress`). This lets the base `getCollateralTokenBalance` helper
  measure the aToken burn with no new code.
- `_preExecute`: outAmount = `getCollateralTokenBalance(account,data)` (aToken balance).
- `_postExecute`: outAmount = pre − post (aTokens burned = debt reduced); outToken =
  `getLoanTokenAddress(data)` (the **underlying**, for consistency with `AaveV3RepayHook`).
- **Doc note (gap #2, spec-flow §2.5):** Aave repays `min(currentDebt, callerATokenBalance)`. If the
  account's aToken balance < debt, `repayWithATokens(max)` **silently partial-repays and leaves
  residual debt without reverting** — unlike `repay(max)`. A chained `... → WithdrawHook(max)` may
  then hit an HF revert or withdraw only part of the collateral. This is documented, not guarded.
- Sizing: single amount at 113 (override `_amountOffset→113`, `_usePrevOffset→145`).
inspect → `pool`.

---

## 6. Reference: mirror map (V4 → V3)

| Concern | V4 | V3 |
|---|---|---|
| Market handle | `spoke` @92 + reserveIds @112/@144 | `pool` @92, asset addresses @52/@72 |
| Rate mode | n/a | `uint8` @112 (borrow/repay families), validated ==2 |
| Full repay/withdraw | `isFullRepayment` bool | `type(uint256).max` sentinel in amount |
| Supply collateral enable | `setUsingAsCollateral(...true)` | **dropped** (V3 auto-enables) |
| repayWithATokens | absent | new 7th hook |
| amount offset (single) | 176 | 112 (SW) / 113 (BR) |
| usePrev offset | 208 | 144 (SW) / 145 (BR) / 177 (combined) |

---

## 7. Unit test plan — `test/unit/hooks/loan/AaveV3LoanHooks.t.sol`

Extend `Helpers` (NOT BaseTest). Mock `IPool` (`MockAaveV3Pool` returning input amounts) + two
`MockERC20`s + `MockHookForPrevAmount` (copy from `AaveV4LoanHooks.t.sol`). Per hook assert the exact
built `Execution[]` via `abi.encodeCall` comparison. Cases:

- Constructors: all 7 `hookType == NONACCOUNTING`; correct `SUB_TYPE` (LOAN vs LOAN_REPAY).
- Supply: build (4 execs, exact calldata incl. both `approve(pool,0)` and `approve(pool,amount)` and
  `supply(asset,amount,account,0)`); **assert no `setUserUseReserveAsCollateral` selector present**
  (gap #1 regression); usePrevHookAmount path; `amount==0` revert; `INVALID_DATA_LENGTH` on short data;
  `ADDRESS_NOT_VALID` on zero pool/token; inspect == packed pool.
- Withdraw: build (1 exec); `max` amount passes; usePrev; reverts.
- Borrow: build; `INVALID_RATE_MODE` when mode byte != 2 (fuzz mode ∈ {0,1,3,255}); usePrev; reverts.
- Repay: build partial (approve==amount) AND full (`amount==max` → approve==max, repay==max, trailing
  approve(pool,0)); `INVALID_RATE_MODE`; usePrev; reverts.
- SupplyAndBorrow: build (5 execs); `decodeAmounts` returns [supply, borrow] at 113/145;
  `replaceCalldataAmounts` round-trips both; `amountRoles` = [IN,OUT]; `INVALID_RATE_MODE`;
  `borrowAmount==0` revert; usePrev applies to supply leg only.
- RepayAndWithdraw: build partial + full-repay(max) + full-withdraw(max); `decodeAmounts` [repay,
  withdraw]; roles [IN,OUT]; reverts.
- RepayWithATokens: build (1 exec, no approvals); `INVALID_RATE_MODE`; `amount==0` revert;
  collateralToken slot = aToken; inspect == pool.
- `prevHook == address(0)` + usePrevHookAmount=true → reads 0 → `AMOUNT_NOT_VALID` (per hook;
  spec-flow §2.6).
- `supportsInterface`: true for `ISuperHookInflowOutflow`/`ISuperHookOutflow`, plus IERC165/ISuperHook.
- `decodeUsePrevHookAmount` reads correct offset per family (144 vs 145 vs 177).

---

## 8. Fork/integration test plan (no mocks — real Pool, ERC-4337 flow)

Extend `MinimalBaseIntegrationTest`; **every test contract MUST declare `receive() external payable
{}`** (AA91 refund). Execute via `_getExecOps`/`executeOp` UserOps through SuperExecutor +
`SuperNativePaymaster` — never direct hook calls. Positions asserted via **aToken** balance (supply)
and **variableDebtToken** balance (borrow), resolved in `setUp` from `getReserveData(asset)`.

### 8a. `setUp` self-checks (spec-flow §4 items 18–19)
- Set `blockNumber` to the pinned per-chain block (§8d) BEFORE `super.setUp()`.
- `require(pool.getReserveData(asset).aTokenAddress != address(0))` per asset used.
- Assert the fork block **postdates each chain's V3.2 stable-rate-removal upgrade** (so the mode!=2
  path is meaningfully testable) — spec-flow §4 item 9.
- Deploy the 7 hooks; fund the account via `_getTokens`.

### 8b. Core scenarios (Ethereum Core — `AaveV3HooksIntegrationTest`)
1. Supply → assert aToken balance ↑; collateral auto-enabled (read `getUserAccountData` LTV>0) —
   proves gap #1 (no explicit toggle needed).
2. Supply → Borrow (two hooks chained) → assert vDebt ↑, loanToken received.
3. SupplyAndBorrow (single hook) → same end state, one UserOp.
4. Partial Repay → vDebt ↓ by ~amount.
5. **Full Repay via `type(uint256).max`**, with `vm.roll`/`vm.warp` forward N blocks between
   open and repay → assert vDebt == 0 (spec-flow §3.8 — the dust test that actually accrues interest).
6. RepayAndWithdraw (full repay max + full withdraw max) → vDebt==0, aToken==0.
7. Withdraw partial → aToken ↓.
8. RepayWithATokens leverage-unwind: supply→borrow(same or swapped)→`repayWithATokens(max)` →
   assert aToken burned == debt reduced, vDebt==0.
9. **RepayWithATokens with aTokenBalance < debt** → assert non-revert + residual vDebt > 0
   (gap #2 / spec-flow §2.5). Set up by withdrawing part of collateral first.
10. Swap → Supply chain via `usePrevHookAmount` (real swap hook output feeds supply).
11. `INVALID_RATE_MODE`: build hook data with mode byte = 1 → UserOp reverts with the hook's custom
    error (spec-flow §4 item 9).
12. **Negative usePrev-wrong-token** (gap #3 / spec-flow §2.1): chain a hook whose outToken is the
    *loan* token into `AaveV3SupplyHook` (expects collateral). Assert the outcome is a **safe Aave/
    transfer revert** (insufficient collateral balance) — proving the mis-chain fails loudly rather
    than silently supplying a nonsensical amount. Document that no on-chain token guard exists.

### 8c. Multi-market / multi-asset (`AaveV3MultiReserveHooksIntegrationTest`, Ethereum)
- Run the supply→borrow lifecycle against a **second Ethereum market (Prime,
  `0x4e033931ad43597d96D6bcc25c280717730B58B1`)** through the *same* hook deployment, proving the
  pool-in-calldata design (spec-flow §4 item 1).
- Multi-asset: WETH collateral + USDC borrow AND wstETH collateral + USDT borrow in one market.

### 8d. Per-chain files (Arbitrum, Base, Optimism, Polygon)
Each runs a trimmed core lifecycle (supply, borrow, repay-max, withdraw) + one chain-specific case:
- **Arbitrum & Optimism:** document `PRICE_ORACLE_SENTINEL_CHECK_FAILED (49)` as a native Aave
  borrow/withdraw revert when the L2 sequencer uptime feed is down/in grace (gap #6 / spec-flow §3.1).
  MVP test: a **mocked-sentinel unit-style fork case** — `vm.mockCall` the PriceOracleSentinel (or
  `vm.store` the sequencer feed) to force the down state, assert `borrow` reverts. Keep it as a
  documented, guarded test so it is not flaky against live sequencer state.
- **Base / Polygon:** standard lifecycle (no sequencer sentinel wired the same way).

Pool addresses (verify against `bgd-labs/aave-address-book` at implementation time):
```
Ethereum Core   Pool 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2
Ethereum Prime  Pool 0x4e033931ad43597d96D6bcc25c280717730B58B1
Ethereum EtherFi Pool 0x0AA97c284e98396202b6A04024F5E2c65026F3c0
Arbitrum        Pool 0x794a61358D6845594F94dc1DB02A252b5b4814aD
Optimism        Pool 0x794a61358D6845594F94dc1DB02A252b5b4814aD
Polygon         Pool 0x794a61358D6845594F94dc1DB02A252b5b4814aD
Base            Pool 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5
```
Pin one fork block per chain (postdating V3.2). Add `AAVE_V3_*_BLOCK` constants. Do NOT hardcode
aToken/vDebt addresses — resolve in `setUp` + assert.

### 8e. Combined-hook revert atomicity (spec-flow §3.7)
One test: force the borrow leg of `SupplyAndBorrow` to revert (e.g. borrow amount beyond LTV) and
assert the whole UserOp reverts (supply leg rolled back, no dangling approval) — atomic by
construction; make it explicit rather than assumed.

---

## 9. Manifest changes

`tooling/hook-enrichment.yaml` — `compatibleProtocols` block (after the Aave V4 group):
```yaml
  # Aave V3
  AaveV3SupplyHook: [aave-v3]
  AaveV3WithdrawHook: [aave-v3]
  AaveV3BorrowHook: [aave-v3]
  AaveV3RepayHook: [aave-v3]
  AaveV3SupplyAndBorrowHook: [aave-v3]
  AaveV3RepayAndWithdrawHook: [aave-v3]
  AaveV3RepayWithATokensHook: [aave-v3]
```
`amountMeta` block (combined hooks are dual):
```yaml
  AaveV3SupplyAndBorrowHook: [{direction: IN, denomination: TOKEN}, {direction: OUT, denomination: TOKEN}]
  AaveV3RepayAndWithdrawHook: [{direction: IN, denomination: TOKEN}, {direction: OUT, denomination: TOKEN}]
```
(single-amount hooks use the default single IN/TOKEN — no explicit entry needed, matching V4 singles.)

`tooling/hook-classification.yaml` — mirror the Morpho/AaveV4 intents:
```yaml
  AaveV3SupplyHook:            {actionTypes: [{intent: lend,     stage: instant}], legSizing: [sized]}
  AaveV3WithdrawHook:         {actionTypes: [{intent: withdraw, stage: instant}], legSizing: [sized]}
  AaveV3BorrowHook:           {actionTypes: [{intent: borrow,   stage: instant}], legSizing: [sized]}
  AaveV3RepayHook:            {actionTypes: [{intent: repay,    stage: instant}], legSizing: [sized]}
  AaveV3RepayWithATokensHook: {actionTypes: [{intent: repay,    stage: instant}], legSizing: [sized]}
  AaveV3SupplyAndBorrowHook:  {actionTypes: [{intent: lend, stage: instant}, {intent: borrow, stage: instant}],   legSizing: [sized, sized]}
  AaveV3RepayAndWithdrawHook: {actionTypes: [{intent: repay, stage: instant}, {intent: withdraw, stage: instant}], legSizing: [sized, sized]}
```
(Use the same block style as the existing V4 entries — expand to the multi-line form for the combined
hooks.) Run `make manifest` to regenerate `manifests/hooks.json`; do not hand-edit it. The
`hook-sizing-manifest.json` picks up entries only once the `*_HOOK_KEY` constants exist (Phase 4).

---

## 10. Deploy wiring (Phase 4, `pre-dev`) — concrete edits

`script/utils/Constants.sol` (after line 275):
```solidity
string internal constant AAVE_V3_SUPPLY_HOOK_KEY = "AaveV3SupplyHook";
string internal constant AAVE_V3_WITHDRAW_HOOK_KEY = "AaveV3WithdrawHook";
string internal constant AAVE_V3_BORROW_HOOK_KEY = "AaveV3BorrowHook";
string internal constant AAVE_V3_REPAY_HOOK_KEY = "AaveV3RepayHook";
string internal constant AAVE_V3_SUPPLY_AND_BORROW_HOOK_KEY = "AaveV3SupplyAndBorrowHook";
string internal constant AAVE_V3_REPAY_AND_WITHDRAW_HOOK_KEY = "AaveV3RepayAndWithdrawHook";
string internal constant AAVE_V3_REPAY_WITH_ATOKENS_HOOK_KEY = "AaveV3RepayWithATokensHook";
```
`script/DeployV2OtherHooks.s.sol`: add `AaveV3HookAddresses` struct (7 fields), `_deployAaveV3Hooks`
+ `_deployAaveV3HooksSet` cloned from `_deployAaveV4HooksSet` (line 372) with `len = 7`, all
`__getOtherHooksBytecode("AaveV3XxxHook", env)` (no constructor args — pool is in calldata), the
7 address assignments, and 7 `require(... != address(0))` guards; invoke `_deployAaveV3Hooks(chainId,
env)` next to the V4 call (~line 189). No availability gating needed (argless; deploys on every chain
— the pool address is a runtime calldata param, so there is no per-chain dependency to check, unlike
UniswapV4).
`script/run/deploy/deploy_v2_other_hooks_staging_prod.sh`: add the 7 contract names to the compile
list and a `missing_aavev3` guard mirroring `missing_aavev4` (~lines 178–197).

---

## 11. Spec-flow gap resolutions (explicit)

1. **No forced collateral toggle (§3.4).** Supply and SupplyAndBorrow do **NOT** emit
   `setUserUseReserveAsCollateral`. V3 auto-enables collateral on first supply; forcing `true`
   reverts on 0%-LTV reserves and overrides isolation-mode choices. Supply = `approve0 → approve(amt)
   → supply → approve0` (4 execs). Regression: unit test asserts the selector is absent; fork test
   asserts LTV>0 after a bare supply.
2. **`repayWithATokens` semantics (§2.4/§2.5).** Aave repays `min(debt, aTokenBalance)`; `max` can
   leave residual debt (unlike `repay(max)`). Hook sets `outToken = loanToken` (underlying),
   `outAmount = aToken burned = debt reduced`, measured via the aToken address placed in
   `collateralToken@72`. Documented in NatSpec; fork test 9 exercises aTokenBalance < debt.
3. **usePrev token-identity guard (§2.1).** **Decision: match V4 — NO on-chain `getOutToken` check.**
   Rationale: (a) intents are user/bundler-signed and validated off-chain; (b) a guard would break
   legitimate chains and diverge from the audited V4 precedent, expanding locked-bytecode surface;
   (c) a mis-chain already fails safe — Aave/transfer reverts on insufficient balance. Mitigation:
   prominent NatSpec warning on every hook that reads `getOutAmount`, plus negative fork test 12.
4. **Combined-hook desync (§2.2/§2.3).** `usePrevHookAmount` applies to the **first leg only**
   (supply/repay). The second leg (`borrowAmount`/`withdrawAmount`) is fixed calldata. No on-chain
   LTV/tolerance guard (Aave enforces the HF≥1 floor). Documented desync risk in NatSpec; the bundler
   owns consistent leg sizing. Fork tests 3, 6 and the atomicity test (§8e) cover this.
5. **Pool-address trust (§5.1).** Every supply/repay (incl. `repay(max)` and RepayAndWithdraw's repay
   leg) ends with `approve(pool, 0)` — zero dangling allowance to the calldata `pool`. **Decision: no
   on-chain allowlist for MVP** (matches V4's un-validated spoke; keeps single-deployment/multi-market
   model). Defense-in-depth allowlist noted as a possible future addition, not implemented. Non-zero
   pool check enforced in every decoder (`ADDRESS_NOT_VALID`).
6. **L2 sequencer sentinel (§3.1).** `PRICE_ORACLE_SENTINEL_CHECK_FAILED (49)` documented as a native
   Aave borrow/withdraw revert on Arbitrum/Optimism; covered by a mocked-sentinel fork test (§8d),
   not by hook code. No on-chain precheck (hook has no reserve/account state).

Additional locked decisions: rate validation lives in the shared decoders (`INVALID_RATE_MODE`);
full repay/withdraw via `type(uint256).max` sentinel (no `isFullRepayment` bool); zero pre-validation
of Aave reserve state (isolation/siloed/frozen/paused/caps surface as native Aave reverts — tests
assert Aave errors, hooks define no custom errors for them).

---

## 12. Build/verify sequence

1. `forge build` (vendor + hooks compile under 0.8.30).
2. `make forge-test-contract TEST-CONTRACT=AaveV3LoanHooksTest` (unit).
3. `make forge-test TEST=AaveV3` (fork suite; requires per-chain RPC env vars).
4. Phase 4 only: `make manifest`, then the OtherHooks deploy dry-run on a fork.

Do not run coverage until unit+fork are green. For coverage, group locals into structs in the
integration tests (already handled by the `Vars`/lifecycle pattern) to avoid stack-too-deep.
