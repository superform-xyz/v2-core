# Aave V3 Lending Hook Suite — Repo Analysis & V4→V3 Mapping

Repo root: `/Users/cosming/1.Coding/Superform/v2-core`
Goal: build an Aave **V3** loan-hook suite by mirroring the existing Aave **V4** suite.

Key V3 semantic differences already established:
- V3 keys reserves on the **asset token address** (not a numeric `reserveId`).
- V3 borrow/repay take an **`interestRateMode`** (1 = stable, 2 = variable).
- Pool address is encoded **in the hook data** (argless constructor, like V4's spoke-in-data).
- `interestRateMode` is a **configurable byte** in the data.
- All hooks are **NONACCOUNTING**.
- Ship all 6 V4-mirrored hooks **plus a 7th** `AaveV3RepayWithATokensHook`.

## 0. Existing Aave V3 references in the repo

There are **none** in `src/`, `test/`, or `script/` (grep for `aave.v3 / aavev3 / AAVE_V3` returns nothing). `src/vendor/aave-v3/` does **not** exist. Everything is greenfield except the V4 template to mirror. There are unrelated V3-*aToken vault* references (`CHAIN_1_AAVE_VAULT`, `CHAIN_8453_AAVE_BASE_WETH`) but those are ERC4626-wrapped Aave vaults, not the lending pool.

---

## 1. Aave V4 hook suite — file-by-file

Directory: `src/hooks/loan/aave-v4/` (7 files: 1 base + 6 hooks).

### 1.1 `BaseAaveV4LoanHook.sol`
Abstract base; extends `BaseLoanHook`. All V4 hooks inherit it.

**Data byte-layout offsets** (`BaseAaveV4LoanHook.sol:23-36`). The 52-byte "strategy header" (`bytes32` oracleId @0, `address` yieldSource @32) is unused by the hook but always present:
```
LOAN_TOKEN_OFFSET                     = 52   // address (20)
COLLATERAL_TOKEN_OFFSET               = 72   // address (20)
SPOKE_OFFSET                          = 92   // address (20)
SUPPLY_RESERVE_ID_OFFSET              = 112  // uint256 (32)
BORROW_RESERVE_ID_OFFSET              = 144  // uint256 (32)
AAVE_V4_AMOUNT_OFFSET                 = 176  // uint256 (32)
AAVE_V4_USE_PREV_HOOK_AMOUNT_POSITION = 208  // bool (1)
IS_FULL_REPAYMENT_OFFSET              = 209  // bool (1)  [repay variants]
BORROW_AMOUNT_OFFSET                  = 209  // uint256    [supplyAndBorrow]  (reuses byte 209)
WITHDRAW_AMOUNT_OFFSET                = 210  // uint256    [repayAndWithdraw]
```
Byte 209 is shared by two mutually-exclusive layouts (comment at `:31-34`).

**Min data lengths** (`:39-44`): supply/withdraw/borrow `209`, repay `210`, supplyAndBorrow `241`, repayAndWithdraw `242`.

**LocalVars structs** (`:50-108`): one per hook. Common fields `loanToken, collateralToken, spoke, {supply|borrow}ReserveId, amount, usePrevHookAmount`; repay adds `isFullRepayment`; supplyAndBorrow adds both reserveIds + `borrowAmount`; repayAndWithdraw adds both reserveIds + `isFullRepayment` + `withdrawAmount`.

**Constructor** (`:123`): `constructor(bytes32 hookSubtype_) BaseLoanHook(hookSubtype_) {}` — **no** args for spoke/pool (comes from calldata).

**Overrides** (`:131-166`):
- `decodeUsePrevHookAmount` → `_decodeBool(data, 208)` (overrides parent's 196).
- `decodeAmounts` → `[BytesLib.toUint256(data, 176)]`.
- `amountRoles` → 1 meta `(IN, TOKEN)`.
- `replaceCalldataAmounts` → replaces at offset 176, requires `amounts.length == 1`.

**Decoders** (`:173-286`): one `_decode*HookData` per hook. Each validates `data.length >= MIN`, reads the addresses, reverts `ADDRESS_NOT_VALID()` if any of loanToken/collateralToken/spoke is zero, then reads ids/amount/flags.

Custom error: `INVALID_DATA_LENGTH()` (`:115`).

### 1.2 `AaveV4SupplyHook.sol` (subtype `LOAN`)
- Constructor `BaseAaveV4LoanHook(HookSubTypes.LOAN)` (`:32`).
- `name()="Aave V4 Supply"`, `description()` (`:35-42`).
- `_buildHookExecutions` (`:50-98`): `usePrevHookAmount`→pull `getOutAmount(prevHook)`; revert `AMOUNT_NOT_VALID` if 0. Builds **5** executions:
  1. `collateralToken.approve(spoke, 0)`
  2. `collateralToken.approve(spoke, amount)`
  3. `spoke.supply(supplyReserveId, amount, account)`
  4. `spoke.setUsingAsCollateral(supplyReserveId, true, account)` — V4 does NOT auto-enable collateral (no-op if already enabled)
  5. `collateralToken.approve(spoke, 0)` (reset dangling allowance)
- `inspect` → `abi.encodePacked(vars.spoke)` (`:101-104`).
- `_preExecute` (`:111`): `_setOutAmount(getCollateralTokenBalance(account,data), account)` (pre-balance).
- `_postExecute` (`:116-119`): `_setOutAmount(pre - post, account)` (collateral spent) + `_setOutToken(collateralToken)`.

### 1.3 `AaveV4WithdrawHook.sol` (subtype `LOAN_REPAY`)
- `_buildHookExecutions` (`:49-73`): **1** execution `spoke.withdraw(supplyReserveId, amount, account)`. `usePrevHookAmount` supported; revert if 0.
- `inspect` → spoke.
- `_preExecute`: pre collateral balance. `_postExecute`: `post - pre` (collateral received) + outToken=collateral.

### 1.4 `AaveV4BorrowHook.sol` (subtype `LOAN`)
- `_buildHookExecutions` (`:49-73`): **1** execution `spoke.borrow(borrowReserveId, amount, account)`.
- `_preExecute`: pre **loan** token balance. `_postExecute`: `post - pre` (loan received) + outToken=loanToken.

### 1.5 `AaveV4RepayHook.sol` (subtype `LOAN_REPAY`)
- `_buildHookExecutions` (`:57-110`): **4** executions. `approve(spoke,0)` then branch on `isFullRepayment`:
  - full: `approve(spoke, type(uint256).max)` + `spoke.repay(borrowReserveId, type(uint256).max, account)`
  - partial: resolve `usePrevHookAmount`, revert if 0; `approve(spoke, amount)` + `spoke.repay(borrowReserveId, amount, account)`
  - always: trailing `approve(spoke, 0)`.
- `_preExecute`: pre loan balance. `_postExecute`: `pre - post` (loan spent) + outToken=loanToken.
- Documents front-run (P1-2) and interest-accrual staleness (P1-3) limitations (`:28-33`).

### 1.6 `AaveV4SupplyAndBorrowHook.sol` (subtype `LOAN`)
- Decodes `SupplyAndBorrowHookLocalVars` (both reserveIds + `borrowAmount@209`).
- `_buildHookExecutions` (`:62-116`): resolves supply amount via prevHook; reverts if `amount==0` or `borrowAmount==0`. **6** executions:
  1. `collateral.approve(spoke,0)` 2. `collateral.approve(spoke,amount)` 3. `spoke.supply(...)` 4. `spoke.setUsingAsCollateral(...)` 5. `spoke.borrow(borrowReserveId, borrowAmount, account)` 6. `collateral.approve(spoke,0)`.
- Overrides `decodeAmounts` → `[amount@176, borrowAmount@209]`; `replaceCalldataAmounts` (2 amounts, offsets 176 & 209); `amountRoles` → `[(IN,TOKEN),(OUT,TOKEN)]` (`:119-150`).
- `_preExecute`/`_postExecute`: track **collateral** spent (out is collateral, NOT the borrowed amount — noted at `:33`).
- borrowAmount computed off-chain by bundler (Aave risk pricing makes on-chain derivation impractical, `:36`).

### 1.7 `AaveV4RepayAndWithdrawHook.sol` (subtype `LOAN_REPAY`)
- Decodes `RepayAndWithdrawHookLocalVars` (both reserveIds + `isFullRepayment@209` + `withdrawAmount@210`).
- `_buildHookExecutions` (`:63-133`): **5** executions. `approve(loan,spoke,0)` then branch:
  - full: `approve(max)`, `repay(max)`, `approve(0)`, `withdraw(supplyReserveId, type(uint256).max, account)`.
  - partial: resolve prevHook; revert if `amount==0` or `withdrawAmount==0`; `approve(amount)`, `repay(amount)`, `approve(0)`, `withdraw(supplyReserveId, withdrawAmount, account)`.
- Overrides `decodeAmounts` → `[amount@176, withdrawAmount@210]`; `replaceCalldataAmounts` (offsets 176 & 210); `amountRoles` → `[(IN,TOKEN),(OUT,TOKEN)]`.
- `_pre`/`_postExecute`: track collateral received (`post - pre`) + outToken=collateral.

**HookType** for the whole family is `NONACCOUNTING`, set once in `BaseLoanHook` constructor (`BaseLoanHook.sol:29`). Subtypes: supply/borrow/supplyAndBorrow = `LOAN`; withdraw/repay/repayAndWithdraw = `LOAN_REPAY`.

---

## 2. `src/vendor/aave-v4/IAaveV4Spoke.sol` — interface pattern & where V3 goes

`IAaveV4Spoke.sol` is a **minimal** interface (5 functions), deliberately not the full BUSL Aave interface (`:6-8`):
- `supply(uint256 reserveId, uint256 amount, address onBehalfOf) → (uint256 shares, uint256 fee)`
- `withdraw(uint256 reserveId, uint256 amount, address onBehalfOf) → (uint256, uint256)` (max = full)
- `borrow(uint256 reserveId, uint256 amount, address onBehalfOf) → (uint256, uint256)`
- `repay(uint256 reserveId, uint256 amount, address onBehalfOf) → (uint256, uint256)` (max = full)
- `setUsingAsCollateral(uint256 reserveId, bool useAsCollateral, address onBehalfOf)`

**V3 interface should live at `src/vendor/aave-v3/IPool.sol`** (new dir). It must be an equally-minimal subset of the real Aave V3 `IPool`, keyed on **asset address**, with **interestRateMode** on borrow/repay:

```solidity
// src/vendor/aave-v3/IPool.sol
interface IPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function borrow(
        address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf
    ) external;
    function repay(
        address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf
    ) external returns (uint256);
    function repayWithATokens(address asset, uint256 amount, uint256 interestRateMode) external returns (uint256);
    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;
}
```

Signature notes vs V4:
- `supply` takes `referralCode` (pass `0`) and returns **nothing** (V4 returns 2 values).
- `withdraw(asset, amount, to)` — `to` is the receiver; hooks must pass `account`. `type(uint256).max` = full withdraw. Returns actual amount.
- `borrow(asset, amount, interestRateMode, referralCode, onBehalfOf)` — extra `interestRateMode` + `referralCode`.
- `repay(asset, amount, interestRateMode, onBehalfOf)` — `type(uint256).max` = full. Returns actual repaid.
- **`repayWithATokens(asset, amount, interestRateMode)`** — burns caller's aTokens to repay caller's own debt; **no `onBehalfOf`**, **no ERC20 approval needed** (this is the 7th hook's protocol call).
- V3 **auto-enables collateral** on first supply (unlike V4). Explicit `setUserUseReserveAsCollateral(asset, true)` is optional/idempotent — keep it in Supply for parity/safety, or drop it. Recommend keeping it to guarantee collateral is enabled (mirrors V4's step 4, but note it may not be strictly required).

---

## 3. `src/hooks/BaseHook.sol` — base API a hook overrides

- **`_buildHookExecutions(prevHook, account, data) → Execution[]`** (`:278`, abstract): the only required override; returns the protocol executions. `build()` (`:149-183`) wraps them with `preExecute` first + `postExecute` last automatically.
- **`_preExecute(prevHook, account, data)`** (`:293`, virtual): default auto-forwards prev hook's out amount/token **only** in PASSTHROUGH mode. TRANSFORM hooks override to snapshot a pre-balance. Guarded by mutex (`preExecute` external `:186`, `msg.sender == account`).
- **`_postExecute(prevHook, account, data)`** (`:308`, virtual, empty default): override to compute `outAmount` via balance diff and set `outToken`.
- **`_pipeMode() → PipeMode`** (`:347`): default `TRANSFORM`. Loan hooks use default (they do balance-diff). `PipeMode { TRANSFORM, PASSTHROUGH, SOURCE }` (`:65-69`).
- **`_decodeBool(data, offset)`** (`:316`): `data[offset] != 0`.
- **`_replaceCalldataAmount(data, amount, offset)`** (`:328`): overwrites 32 bytes in place.
- **`_setOutAmount / _setOutToken / getOutAmount / getOutToken`** — transient, context-keyed.
- Constructor `BaseHook(HookType hookType_, bytes32 subType_)` (`:128`) sets `hookType` + immutable `SUB_TYPE`.
- `supportsInterface` / `_supportsSizingInterface()` (`:251-266`): loan hooks return `true` (via `BaseLoanHook._supportsSizingInterface`).
- Note: there is **no** `_decodeUint8` helper in BaseHook. For the interestRateMode byte, use `BytesLib.toUint8(data, offset)` (confirmed present at `src/vendor/BytesLib.sol:286`).

---

## 4. `src/libraries/HookSubTypes.sol`

`LOAN = keccak256("Loan")` (`:21`), `LOAN_REPAY = keccak256("LoanRepay")` (`:22`). Subtype is passed to the hook constructor → `BaseLoanHook(subtype)` → `BaseHook(NONACCOUNTING, subtype)`. **No new subtype needed** for V3; reuse `LOAN` (supply/borrow/supplyAndBorrow/repayWithATokens) and `LOAN_REPAY` (withdraw/repay/repayAndWithdraw).

`BaseLoanHook.sol` (`src/hooks/loan/BaseLoanHook.sol`): sets `HookType.NONACCOUNTING` (`:29`); provides fixed getters `getLoanTokenAddress`=`BytesLib.toAddress(data,52)` (`:77`), `getCollateralTokenAddress`=`toAddress(data,72)` (`:82`), and the balance getters (`:86-95`). **These hardcode 52/72**, so the V3 layout MUST keep loanToken@52 and collateralToken@72.

---

## 5. Integration test harness

### `test/integration/MinimalBaseIntegrationTest.t.sol`
Abstract base (`Helpers, RhinestoneModuleKit, InternalHelpers`). `setUp()` forks Ethereum at `blockNumber` (subclass sets it before `super.setUp()`), builds `SuperLedgerConfiguration`, `SuperExecutor` (`superExecutorOnEth`), installs the executor module on `instanceOnEth`, funds `accountEth`. Exposes `accountEth`, `instanceOnEth`, `superExecutorOnEth`.

### `test/integration/AaveV4HooksIntegrationTest.t.sol` (WETH collateral / USDC borrow)
- `setUp` (`:51-67`): sets `blockNumber = AAVE_V4_BLOCK`, deploys the 6 hooks + a `SuperNativePaymaster(ENTRYPOINT_ADDR)`, funds account with WETH.
- **Local `SPOKE_ADDR = 0x94e7...485`, `WETH_RESERVE_ID=0`, `USDC_RESERVE_ID=7`** (`:44-46`).
- **Data encoders** are inline `abi.encodePacked(...)` (`:78-175`) matching the base offsets exactly, e.g. supply: `bytes32(0), address(0), CHAIN_1_USDC, CHAIN_1_WETH, SPOKE_ADDR, WETH_RESERVE_ID, USDC_RESERVE_ID, amount, usePrevHookAmount`. Repay appends `isFullRepayment`; supplyAndBorrow appends `borrowAmount_`; repayAndWithdraw appends `isFullRepayment, withdrawAmount`.
- **Execution flow** (`_executeHook`, `:181-201`): build `ISuperExecutor.ExecutorEntry{hooksAddresses, hooksData}` → `_getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry))` → `executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18)`.
- **Position assertions** via `IAaveV4SpokeQuery.getUserSuppliedAssets(reserveId,user)` / `getUserDebt(reserveId,user)` (`:24-27`). Also asserts ERC20 balance deltas. `decodeAmounts`/`replaceCalldataAmounts` round-trips (`:502-555`).

### `test/integration/AaveV4MultiReserveHooksIntegrationTest.t.sol`
Same shape, second reserve pair **WBTC(8-dec, reserve 3)/USDC(7)** to catch decimal/reserve-specific bugs; uses `AAVE_V4_MAIN_SPOKE`, `AAVE_V4_WBTC_RESERVE_ID`, `AAVE_V4_USDC_RESERVE_ID` from Constants.

For V3, the query interface changes to an **aToken/variableDebtToken balance check** (V3 has no `getUserSuppliedAssets(reserveId,...)`). Query positions via:
- collateral supplied ≈ `IERC20(aToken).balanceOf(account)` (aToken from `pool.getReserveData(asset).aTokenAddress`, or hardcode the known aToken addresses as constants);
- debt ≈ `IERC20(variableDebtToken).balanceOf(account)`.
Simplest: add `getReserveData` to the test-only query interface, or hardcode aEthWETH/aEthUSDC/variableDebtUSDC addresses as test constants.

---

## 6. `test/utils/Constants.sol` — Aave constants & where V3 goes

Existing (`:279-287`):
```solidity
// aave v4
address public constant AAVE_V4_MAIN_SPOKE          = 0x94e7A5dCbE816e498b89aB752661904E2F56c485;
address public constant AAVE_V4_CORE_HUB            = 0xCca852Bc40e560adC3b1Cc58CA5b55638ce826c9;
uint256 public constant AAVE_V4_WETH_RESERVE_ID     = 0;
uint256 public constant AAVE_V4_WSTETH_RESERVE_ID   = 1;
uint256 public constant AAVE_V4_WBTC_RESERVE_ID     = 3;
uint256 public constant AAVE_V4_USDC_RESERVE_ID     = 7;
uint256 public constant AAVE_V4_USDT_RESERVE_ID     = 8;
uint256 public constant AAVE_V4_BLOCK               = 24_884_274;
```
Token/infra constants used by tests: `CHAIN_1_WBTC` (`:163`), `CHAIN_1_USDC` (`:166`), `CHAIN_1_WETH` (`:167`), `ENTRYPOINT_ADDR` (`:41`), block constants (`:35-37`).

**Add a new block right after line 287** (V3 keys on asset, so no reserveIds — need the Pool + aToken/debtToken addresses + a fork block):
```solidity
// aave v3 (Ethereum mainnet)
address public constant AAVE_V3_POOL             = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2; // PoolProxy
uint256 public constant AAVE_V3_VARIABLE_RATE    = 2;   // interestRateMode: 1=stable, 2=variable
uint256 public constant AAVE_V3_STABLE_RATE      = 1;
address public constant CHAIN_1_AETH_WETH        = 0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8; // aEthWETH
address public constant CHAIN_1_AETH_USDC        = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c; // aEthUSDC
address public constant CHAIN_1_VDEBT_USDC       = 0x72E95b8931767C79bA4EeE721354d6E99a61D004; // variableDebtEthUSDC
uint256 public constant AAVE_V3_BLOCK            = 24_884_274; // reuse a recent block; verify V3 Pool live
```
(Verify exact aToken/debtToken addresses against the chosen fork block; the Pool proxy `0x8787...4E2` is the canonical V3 mainnet Pool.)

Deploy-side keys live in `script/utils/Constants.sol:270+` (`AAVE_V4_*_HOOK_KEY` strings). Add `AAVE_V3_SUPPLY_HOOK_KEY = "AaveV3SupplyHook"` … through `AaveV3RepayWithATokensHook` (7 keys).

---

## 7. `test/utils/InternalHelpers.sol` — encoder pattern to mirror

The V4 integration tests encode **inline** (not via InternalHelpers). Morpho encoders live here as the shared pattern (`:688-762`), e.g. `_createMorphoSupplyAndBorrowHookData(...)` returns `abi.encodePacked(loanToken, collateralToken, bytes12(0), loanToken, collateralToken, oracle, irm, amount, ltvRatio, usePrevHookAmount, lltv, false)`.

Also here: `executeOpsThroughPaymaster` (`:38-55`), `_getExecOps` (`:93-104`). `_singleAmount`/`_getTokens` live in `test/utils/Helpers.sol:69`/`:98`.

For V3, either (a) mirror V4 and inline-encode in the test file (least coupling — recommended), or (b) add `_createAaveV3*HookData(...)` helpers here. Each helper must emit the exact V3 layout below.

---

## 8. CONCRETE V3 DATA LAYOUT (design)

V3 removes the two 32-byte reserveIds (asset addresses already carry that info) and adds a 1-byte `interestRateMode`. Keep the 52-byte header and loanToken@52 / collateralToken@72 (required by `BaseLoanHook`). Proposed compact layout:

```
0   bytes32  placeholder0 (yieldSourceOracleId)   [header]
32  address  placeholder1 (yieldSource)           [header]
52  address  loanToken            (LOAN_TOKEN_OFFSET)          <-- fixed by BaseLoanHook
72  address  collateralToken      (COLLATERAL_TOKEN_OFFSET)    <-- fixed by BaseLoanHook
92  address  pool                 (POOL_OFFSET)
112 uint8    interestRateMode     (INTEREST_RATE_MODE_OFFSET)  (1 byte)
113 uint256  amount               (AAVE_V3_AMOUNT_OFFSET)
145 bool     usePrevHookAmount    (AAVE_V3_USE_PREV_HOOK_AMOUNT_POSITION)
--- variant tails ---
146 uint256  borrowAmount         [SupplyAndBorrow]  (BORROW_AMOUNT_OFFSET)
146 bool     isFullRepayment      [Repay / RepayWithATokens]  (IS_FULL_REPAYMENT_OFFSET)
146 bool     isFullRepayment      [RepayAndWithdraw]
147 uint256  withdrawAmount       [RepayAndWithdraw]  (WITHDRAW_AMOUNT_OFFSET)
```
Min lengths: supply/withdraw/borrow = `146`; repay / repayWithATokens = `147`; supplyAndBorrow = `178`; repayAndWithdraw = `179`.

Decode reads: addresses via `BytesLib.toAddress`; `interestRateMode` via `BytesLib.toUint8(data, 112)`; `amount` via `BytesLib.toUint256(data, 113)`; bools via `_decodeBool`. Override `decodeUsePrevHookAmount → _decodeBool(data, 145)`, `decodeAmounts → [toUint256(data,113)]`, `replaceCalldataAmounts → offset 113`.

> Lower-risk alternative: keep V4's exact byte layout (reuse the reserveId slots as ignored padding, put interestRateMode into one of them) so offsets/min-lengths and the base overrides stay numerically identical. Trade-off: 64 wasted bytes + confusing semantics. **Recommended: the compact layout above** — cleaner, and the base overrides are simple constant swaps.

---

## 9. FILE-BY-FILE V4 → V3 MAPPING

| V4 file | V3 file to create | Key changes |
|---|---|---|
| `src/vendor/aave-v4/IAaveV4Spoke.sol` | `src/vendor/aave-v3/IPool.sol` | New minimal `IPool` keyed on `address asset`; `supply(asset,amt,onBehalfOf,0)` returns void; `withdraw(asset,amt,to)`; `borrow(asset,amt,mode,0,onBehalfOf)`; `repay(asset,amt,mode,onBehalfOf)`; `repayWithATokens(asset,amt,mode)`; `setUserUseReserveAsCollateral(asset,bool)`. |
| `BaseAaveV4LoanHook.sol` | `src/hooks/loan/aave-v3/BaseAaveV3LoanHook.sol` | Replace SPOKE/RESERVE_ID offsets with POOL(92)+INTEREST_RATE_MODE(112)+AMOUNT(113)+USE_PREV(145) etc. (Section 8). LocalVars: drop `supplyReserveId`/`borrowReserveId`, add `address pool` + `uint256 interestRateMode`. Decoders validate `pool != 0`. Override amount/usePrev offsets. Keep `INVALID_DATA_LENGTH`, `ADDRESS_NOT_VALID` (from BaseHook). Constructor `BaseLoanHook(subtype)` unchanged. |
| `AaveV4SupplyHook.sol` (LOAN, 5 exec) | `AaveV3SupplyHook.sol` | Protocol call `IPool.supply(collateralToken, amount, account, 0)`. Collateral enable: V3 auto-enables; keep optional `setUserUseReserveAsCollateral(collateralToken, true)` for parity (idempotent) or drop to save an execution. approve0→approve→supply→[enable]→approve0. `_pre/_post` identical (collateral balance diff). `inspect → pool`. |
| `AaveV4WithdrawHook.sol` (LOAN_REPAY, 1 exec) | `AaveV3WithdrawHook.sol` | `IPool.withdraw(collateralToken, amount, account)` (`account` is `to`). max=full. `_pre/_post` unchanged. |
| `AaveV4BorrowHook.sol` (LOAN, 1 exec) | `AaveV3BorrowHook.sol` | `IPool.borrow(loanToken, amount, interestRateMode, 0, account)`. `_pre/_post` track loan token. |
| `AaveV4RepayHook.sol` (LOAN_REPAY, 4 exec) | `AaveV3RepayHook.sol` | approve0→approve(amt|max)→`IPool.repay(loanToken, amt|max, interestRateMode, account)`→approve0. Same full/partial branch + prevHook logic. Keep P1-2/P1-3 notes. |
| `AaveV4SupplyAndBorrowHook.sol` (LOAN, 6 exec) | `AaveV3SupplyAndBorrowHook.sol` | approve0→approve→`supply(collateral,...,0)`→[enable]→`borrow(loan, borrowAmount, mode, 0, account)`→approve0. Override `decodeAmounts=[amount@113, borrowAmount@146]`, `replaceCalldataAmounts` (offsets 113 & 146), `amountRoles=[(IN,TOKEN),(OUT,TOKEN)]`. `_pre/_post` = collateral diff. |
| `AaveV4RepayAndWithdrawHook.sol` (LOAN_REPAY, 5 exec) | `AaveV3RepayAndWithdrawHook.sol` | approve0→approve(amt|max)→`repay(loan,...,mode,account)`→approve0→`withdraw(collateral, withdrawAmount|max, account)`. Override `decodeAmounts=[amount@113, withdrawAmount@147]`, `replaceCalldataAmounts` (113 & 147), `amountRoles`. `_pre/_post` = collateral diff. |
| — (new) | `AaveV3RepayWithATokensHook.sol` (LOAN_REPAY) | **7th hook.** Protocol call `IPool.repayWithATokens(loanToken, amt|max, interestRateMode)` — repays caller's own debt by burning its aTokens. **No ERC20 approve needed** (no underlying transfer), so executions = just the single `repayWithATokens` call (1 exec), branch full/partial on `isFullRepayment` (max vs amount). `_pre/_post`: measure the **aToken** balance consumed, OR keep it simple and set outToken=loanToken with debt-reduction semantics; simplest is to snapshot loan-token debt via the account's aToken balance diff. Use the same layout tail as Repay (isFullRepayment@146, min length 147). Note: onBehalfOf is implicitly msg.sender=account, satisfying the "onBehalfOf == account" invariant automatically. |

**Tests to create (mirror V4):**
- `test/integration/AaveV3HooksIntegrationTest.t.sol` (WETH collateral / USDC borrow, `interestRateMode=2`). Query positions via aToken/variableDebtToken balances instead of `getUserSuppliedAssets`. Include the 7th hook's repay-with-aTokens path.
- `test/integration/AaveV3MultiReserveHooksIntegrationTest.t.sol` (WBTC/USDC).
- `test/unit/hooks/loan/AaveV3LoanHooks.t.sol` (mirror `AaveV4LoanHooks.t.sol`; add a `MockAaveV3Pool` with the V3 signatures incl. `repayWithATokens` and `setUserUseReserveAsCollateral`).
- Constants: Section 6 additions.
- Deploy: mirror `script/DeployV2OtherHooks.s.sol:367-426` (`_deployAaveV3HooksSet`, argless bytecode, 7 entries) + 7 `AAVE_V3_*_HOOK_KEY` strings in `script/utils/Constants.sol`.
- Manifest: add 7 entries to `manifests/hooks.json` mirroring the `AaveV4SupplyHook` block (`:6536-6583`): `hookType: NONACCOUNTING`, `subtype: LOAN`/`LOAN_REPAY`, `compatibleProtocols: ["aave-v3"]`, `erc165: [ISuperHookInflowOutflow, ISuperHookOutflow]`, `sized: true`. (Manifest is typically regenerated by tooling, not hand-edited.)

**Invariants to preserve:** `onBehalfOf`/`to` is always hardcoded to `account` (never arbitrary) — matches V4's SECURITY INVARIANT (`BaseAaveV4LoanHook.sol:17`). Trailing `approve(pool, 0)` after every approve to avoid dangling allowance. NONACCOUNTING throughout. loanToken@52 / collateralToken@72 fixed positions.
