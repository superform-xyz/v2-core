# Session 17: Hook Sizing Dispatch Table Generator (Phase 2a)

## Status: COMPLETE
- Date: 2026-06-08

## Overview
Implemented a build-time manifest (`hook-sizing-manifest.json`) that declares each hook's sizing mode so the OMS can generically read/replace amounts without per-hook custom logic.

Three modes:
- **`offset`**: OMS does byte splice at `amountPosition`
- **`replaceCalldata`**: OMS calls hook's on-chain `decodeAmount`/`replaceCalldataAmount`
- **`sizeless`**: hook has no scalar amount concept

## Files Created

| File | Purpose |
|------|---------|
| `hook-sizing-manifest.json` | 116-entry JSON dispatch table |
| `scripts/generate-hook-sizing-manifest.ts` | Hybrid generator: auto-detects AMOUNT_POSITION + manual overrides |
| `scripts/validate-hook-sizing-manifest.ts` | CI conformance validator |
| `package.json` | npm scripts + tsx dependency |

## Key Corrections from Original Plan

During implementation, I verified the plan's offset values against actual Solidity source code and found several corrections needed:

1. **APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY**: Plan said 52, actual source AMOUNT_POSITION = 72
2. **GEARBOX_APPROVE_AND_STAKE_HOOK_KEY**: Plan said 52, actual source AMOUNT_POSITION = 72
3. **APPROVE_AND_FLUID_STAKE_HOOK_KEY**: Plan said 52, actual source AMOUNT_POSITION = 72
4. **MORPHO_SUPPLY_AND_BORROW_HOOK_KEY**: Plan said secondary borrowAmount at 112, but byte 112 is actually `ltvRatio` (not an amount) → no secondary
5. **MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY**: Plan said secondary withdrawAmount at 112, but byte 112 is actually `lltv` (not an amount) → no secondary
6. **ClaimFailedTransferHook**: Auto-detected as `replaceCalldata` (has both methods), but should be `offset` at 40

## Statistics

- 69 offset hooks
- 6 replaceCalldata hooks
- 41 sizeless hooks
- 116 total (117 constants, 1 duplicate: MORPHO_BORROW_ONLY_HOOK_KEY = MORPHO_BORROW_HOOK_KEY)

## Hooks not in Constants (excluded from manifest)

These hooks exist in test/utils/Constants.sol or codebase but not in the deployment script/utils/Constants.sol:
- DEPOSIT_WETH_HOOK_KEY, WITHDRAW_WETH_HOOK_KEY (WETH hooks)
- SPECTRA_EXCHANGE_DEPOSIT_HOOK_KEY, SPECTRA_EXCHANGE_REDEEM_HOOK_KEY
- NATIVE_TRANSFER_HOOK_KEY

## Verification

```
npm run generate:hook-sizing  # generates manifest
npm run validate:hook-sizing  # CI conformance - 0 errors, 0 warnings
```

---

# E2: Expose `replaceCalldataAmount` on All Offset Hooks

## Status: CODE CHANGES COMPLETE
- Date: 2026-06-08
- `forge build` passes — all contracts compile

## What Was Done

Added `decodeAmount()` + `replaceCalldataAmount()` on-chain methods to all 68 former-offset hooks, organized by 4 patterns:

### Pattern C: Base loan classes (3 files, covers 13 hooks)
- **BaseLoanHook.sol** — Added `ISuperHookInflowOutflow`, `ISuperHookOutflow` interfaces + virtual `decodeAmount()` (uses `AMOUNT_POSITION = 80`) + virtual `replaceCalldataAmount()`
  - Inherited by: MorphoSupplyHook, MorphoLendHook, MorphoBorrowHook, MorphoRepayHook, MorphoSupplyAndBorrowHook, MorphoRepayAndWithdrawHook (6 hooks)
- **BaseAaveV4LoanHook.sol** — Override both methods using `AAVE_V4_AMOUNT_OFFSET = 124`
  - Covers: AaveV4SupplyHook, AaveV4WithdrawHook, AaveV4BorrowHook, AaveV4RepayHook, AaveV4SupplyAndBorrowHook, AaveV4RepayAndWithdrawHook (6 hooks)
- **MorphoWithdrawHook.sol** — Override both methods using `ASSETS_OFFSET = 112` (1 hook)

### Pattern A: Vault hooks with existing `decodeAmount` (15 files)
Added `ISuperHookOutflow` import/declaration + `replaceCalldataAmount()` method:
- Deposit4626VaultHook, ApproveAndDeposit4626VaultHook
- Deposit5115VaultHook, ApproveAndDeposit5115VaultHook
- RequestDeposit7540VaultHook, ApproveAndRequestDeposit7540VaultHook, Deposit7540VaultHook, RequestRedeem7540VaultHook
- EthenaCooldownSharesHook, RedeemFirelightVaultHook
- RequestRedeemDETHHook, ApproveAndRequestRedeemDETHHook
- MintSuperPositionsHook, BurnSuperPositionsHook
- CircleGatewayWalletHook (also added ISuperHookInflowOutflow to declaration)

### Pattern B: Staking hooks (6 files)
Added `ISuperHookInflowOutflow` + `ISuperHookOutflow` interfaces + public `decodeAmount()` + `replaceCalldataAmount()`:
- GearboxStakeHook, GearboxUnstakeHook, ApproveAndGearboxStakeHook
- FluidStakeHook, FluidUnstakeHook, ApproveAndFluidStakeHook

### Pattern D: Swappers/Bridges/Tokens with no existing methods (37 files)
Added `AMOUNT_POSITION` constant + `ISuperHookInflowOutflow` + `ISuperHookOutflow` interfaces + both methods:

**Swappers (21 hooks):**
- Odos V2/V3 (4) — offset 20
- KyberSwap (2) — offset 52
- OpenOcean SparkDex (2) — offset 52
- Uniswap V3 (4) — offset 128
- Uniswap V4 (1) — offset 120
- Uniswap V2 (2) — offset 72
- Algebra Integral (2) — offset 144
- Spark PSM (4) — offset 40

**Bridges (10 hooks):**
- CCTP (2) — offset 20
- Across V1/V2 (4) — offset 92
- Stargate V1/V2 (4) — offset 108

**Tokens (5 hooks):**
- ApproveERC20, TransferERC20, TransferHook — offset 40
- DepositWETH, WithdrawWETH — offset 0

**Other (1 hook):**
- FetchNativeFeeHook (at src/hooks/sponsorship/) — offset 20

## Counts
- 71 files now have `replaceCalldataAmount` (including 10 pre-existing E1 hooks)
- 73 files now have `decodeAmount` (71 + ClaimWithdrawFirelightVaultHook + ClaimAssetsDETHHook)

## Remaining Steps
- Regenerate manifest: `npm run generate:hook-sizing` → all 68 former-offset hooks should auto-detect as `replaceCalldata`
- Validate: `npm run validate:hook-sizing` → 0 errors
- Run full tests: `make ftest` → existing tests still pass (additive changes only)

---

# E2 Tests: Unit Tests for `decodeAmount` and `replaceCalldataAmount`

## Status: COMPLETE
- Date: 2026-06-08
- All 236 tests pass: `forge test --match-test "DecodeAmount|ReplaceCalldataAmount"` → 0 failures

## What Was Done

Added 3 tests per hook (DecodeAmount, ReplaceCalldataAmount, Fuzz_ReplaceCalldataAmount) across all categories:

### Modified test files (~35 files):
- **Vault hooks** (10 files): ERC4626, 5115, 7540, 7540-WithId, ethena, firelight, deth, vault-bank
- **Loan hooks** (2 files): MorphoLoanHooks, AaveV4LoanHooks
- **Staking hooks** (6 files): Gearbox (3), Fluid (3)
- **Swapper hooks** (9 existing files): Odos V2/V3, KyberSwap, OpenOcean, UniswapV3, UniswapV3Router02, Algebra, SparkPSM ExactIn/ExactOut
- **Bridge hooks** (5 files): CCTP, BridgeHooks (Across), AcrossV2, Stargate, StargateV2
- **Token/Other hooks** (6 files): TransferHook, TransferERC20, ApproveERC20, DepositWETH, WithdrawWETH, FetchNativeFee
- **CircleGateway** (1 file): Added ReplaceCalldataAmount tests (DecodeAmount already existed)

### New test files created (2 files):
- `test/unit/hooks/swappers/uniswap-v2/UniswapV2UnitTests.t.sol` — SwapUniswapV2Hook + ApproveAndSwapUniswapV2Hook
- `test/unit/hooks/swappers/uniswap-v4/UniswapV4UnitTests.t.sol` — SwapUniswapV4Hook

## Bugs Found and Fixed in Source Code

Tests revealed 4 incorrect `AMOUNT_POSITION` values that were copy-pasted from sibling hooks:

| Hook | Wrong Value | Correct Value | Root Cause |
|------|-------------|---------------|------------|
| ApproveAndSwapKyberSwapHook | 52 | 40 | Copied from SwapKyberSwap (which has extra swapValue field) |
| ApproveAndSwapOpenOceanSparkDexHook | 52 | 40 | Same issue |
| SwapUniswapV3Router02Hook | 128 | 76 | Copied from regular UniswapV3 (which has recipient+deadline fields) |
| ApproveAndSwapUniswapV3Router02Hook | 128 | 76 | Same issue |

## Test Bug Fixed
- `ERC7540HookTests.t..sol`: Redeem fuzz test included extra `token` field in data encoding, causing offset mismatch

## Other Fix
- `MorphoLoanHooks.t.sol`: SupplyAndBorrow tests used `supplyAndBorrowHook` (undeclared) instead of `borrowHook`

---

# E2 Integration Tests: `decodeAmount` and `replaceCalldataAmount` on Forked Mainnet

## Status: COMPLETE
- Date: 2026-06-08
- All 28 integration tests pass: `forge test --match-test "DecodeAmount|ReplaceCalldataAmount" --match-path "test/integration/*"` → 0 failures

## What Was Done

Added integration tests that verify `decodeAmount()` and `replaceCalldataAmount()` work correctly with **real on-chain execution** on forked mainnet. These complement the unit tests by proving replaced calldata actually executes successfully.

### Priority 1: Bugfixed hooks (validates AMOUNT_POSITION fixes)

**UniswapV3Router02** (`test/integration/uniswap-v3/UniswapV3Router02HookIntegrationTest.t.sol`):
- `test_SwapRouter02_DecodeAmount_ReplaceCalldataAmount()` — roundtrip for both SwapHook and ApproveAndSwapHook
- `test_ApproveAndSwapRouter02_ReplaceCalldataAmount_ExecutesCorrectly()` — build 1000 USDC, replace to 500, execute, verify only 500 spent
- `test_SwapRouter02_ReplaceCalldataAmount_ExecutesCorrectly()` — same pattern with SwapHook using approve + swap chain

**KyberSwap** (`test/integration/kyberswap/KyberSwapHookIntegration.t.sol`):
- `test_ApproveAndSwap_DecodeAmount_ReplaceCalldataAmount()` — roundtrip for ApproveAndSwapKyberSwapHook
- `test_Swap_DecodeAmount_ReplaceCalldataAmount()` — roundtrip for SwapKyberSwapHook (different layout: outputToken|value|inputAmount)

**OpenOcean** (`test/integration/openocean/OpenOceanSparkDexAPIScale.t.sol`):
- `test_ApproveAndSwapOpenOcean_DecodeAmount_ReplaceCalldataAmount()` — roundtrip for ApproveAndSwapOpenOceanSparkDexHook
- `test_SwapOpenOcean_DecodeAmount_ReplaceCalldataAmount()` — roundtrip for SwapOpenOceanSparkDexHook

### Priority 2: Other swapper hooks

**UniswapV3** (`test/integration/uniswap-v3/UniswapV3HookIntegrationTest.t.sol`):
- `test_UniswapV3_DecodeAmount_ReplaceCalldataAmount()` — roundtrip for both hooks
- `test_UniswapV3_ApproveAndSwap_ReplaceCalldataAmount_ExecutesCorrectly()` — execution with replaced amount

**UniswapV2** (`test/integration/uniswap-v2/UniswapV2HookIntegrationTest.t.sol`):
- `test_UniswapV2_DecodeAmount_ReplaceCalldataAmount()` — roundtrip
- `test_UniswapV2_ApproveAndSwap_ReplaceCalldataAmount_ExecutesCorrectly()` — execution test

**UniswapV4** (`test/integration/uniswap-v4/UniswapV4HookIntegrationTest.t.sol`):
- `test_UniswapV4_DecodeAmount_ReplaceCalldataAmount()` — roundtrip
- `test_UniswapV4_ReplaceCalldataAmount_PreservesAllFields()` — verifies data structure preservation (no execution test — V4 has ratio-based slippage guard that rejects amount replacement without corresponding minAmountOut adjustment)

**SparkPSM** (`test/integration/spark-psm/SparkPSMHookIntegrationTest.t.sol`):
- `test_SparkPSM_DecodeAmount_ReplaceCalldataAmount()` — roundtrip for all 4 PSM hooks
- `test_SparkPSM_ApproveAndSwapExactIn_ReplaceCalldataAmount_ExecutesCorrectly()` — execution: 1000 USDC → replace to 500 → verify 500 USDS out
- `test_SparkPSM_ApproveAndSwapExactOut_ReplaceCalldataAmount_ExecutesCorrectly()` — execution: replace amountOut to 500e18

### Priority 3: Non-swapper hooks

**WETH** (`test/integration/WETHHooksIntegrationTest.t.sol`):
- `test_DepositWETH_DecodeAmount_ReplaceCalldataAmount()` — roundtrip (AMOUNT_POSITION = 0)
- `test_WithdrawWETH_DecodeAmount_ReplaceCalldataAmount()` — roundtrip
- `test_DepositWETH_ReplaceCalldataAmount_ExecutesCorrectly()` — execution: replace to 0.5 ETH, verify exactly 0.5 WETH minted

**Morpho** (`test/integration/MorphoHooksIntegrationTest.t.sol`):
- `test_MorphoSupplyAndBorrow_DecodeAmount_ReplaceCalldataAmount()` — roundtrip (AMOUNT_POSITION = 80)
- `test_MorphoRepayAndWithdraw_DecodeAmount_ReplaceCalldataAmount()` — roundtrip

**AaveV4** (`test/integration/AaveV4HooksIntegrationTest.t.sol`):
- `test_AaveV4_Supply_DecodeAmount_ReplaceCalldataAmount()` — roundtrip (AMOUNT_POSITION = 124)
- `test_AaveV4_Withdraw_DecodeAmount_ReplaceCalldataAmount()` — roundtrip
- `test_AaveV4_Borrow_DecodeAmount_ReplaceCalldataAmount()` — roundtrip
- `test_AaveV4_Supply_ReplaceCalldataAmount_ExecutesCorrectly()` — execution: replace to 0.5 WETH, verify correct supply position

## Test Counts by File
| File | Roundtrip Tests | Execution Tests | Total |
|------|----------------|-----------------|-------|
| UniswapV3Router02 | 1 | 2 | 3 |
| KyberSwap | 2 | 0 | 2 |
| OpenOcean | 2 | 0 | 2 |
| UniswapV3 | 1 | 1 | 2 |
| UniswapV2 | 1 | 1 | 2 |
| UniswapV4 | 2 | 0 | 2 |
| SparkPSM | 1 | 2 | 3 |
| WETH | 2 | 1 | 3 |
| Morpho | 2 | 0 | 2 |
| AaveV4 | 3 | 1 | 4 |
| ERC7540 (pre-existing) | 1 | 2 | 3 |
| **Total** | **18** | **10** | **28** |

## Skipped (as planned)
- CCTP, Stargate, Across bridge hooks (require cross-chain messaging infra)
- Firelight/DETH vault hooks (require specific vault state)
- Gearbox/Fluid staking (no existing integration test files)
- Stargate adapter (already has decode/replace tests at lines 1205-1324)

---

# E2 Roundtrip Build + Field Preservation Tests

## Status: COMPLETE
- Date: 2026-06-09
- All 97 roundtrip/field-preservation tests pass
- Full regression: all 3,311 unit tests pass (0 failures)

## What Was Done

Added "replace + build roundtrip" tests and "field preservation" tests to ~35 unit test files. These tests verify:
1. **Roundtrip**: `replaceCalldataAmount()` → `build()` succeeds with correct execution count + `decodeAmount()` reads back the new amount
2. **Field preservation**: `replaceCalldataAmount()` only modifies the 32 bytes at AMOUNT_POSITION, leaving all other bytes unchanged

### Test Pattern
```solidity
// Roundtrip: replace amount → build → verify
function test_Hook_ReplaceCalldataAmount_ThenBuild() public view {
    bytes memory data = _encodeData(false);
    uint256 newAmount = 500;
    bytes memory replaced = hook.replaceCalldataAmount(data, newAmount);
    Execution[] memory executions = hook.build(address(0), address(this), replaced);
    assertEq(executions.length, expectedCount);
    assertEq(hook.decodeAmount(replaced), newAmount);
}

// Field preservation: verify bytes before/after AMOUNT_POSITION unchanged
function test_Hook_ReplaceCalldataAmount_PreservesOtherFields() public view {
    bytes memory data = _encodeData(false);
    bytes memory replaced = hook.replaceCalldataAmount(data, 999);
    assertEq(replaced.length, data.length);
    for (uint256 i = 0; i < AMOUNT_POSITION; i++) { assertEq(replaced[i], data[i]); }
    for (uint256 i = AMOUNT_POSITION + 32; i < data.length; i++) { assertEq(replaced[i], data[i]); }
}
```

### Files Modified (by category)

**Stake hooks (6 files):**
- FluidStakeHook.t.sol (OFFSET=52, 3 exec)
- FluidUnstakeHook.t.sol (OFFSET=52, 3 exec)
- ApproveAndFluidStakeHook.t.sol (OFFSET=72, 6 exec)
- GearboxStakeHook.t.sol (OFFSET=52, 3 exec)
- GearboxUnstakeHook.t.sol (OFFSET=52, 3 exec)
- ApproveAndGearboxStakeHook.t.sol (OFFSET=72, 6 exec)

**Token hooks (6 files):**
- TransferHook.t.sol (OFFSET=40, 3 exec)
- TransferERC20Hook.t.sol (OFFSET=40, 3 exec)
- ApproveERC20Hook.t.sol (OFFSET=40, 4 exec)
- DepositWETHHook.t.sol (OFFSET=0, 3 exec)
- WithdrawWETHHook.t.sol (OFFSET=0, 3 exec, needs vm.mockCall for balanceOf)
- NativeTransferHook.t.sol (OFFSET=20, 3 exec, also verifies executions[1].value == newAmount)

**Swapper hooks (8 files):**
- AlgebraIntegralUnitTests.t.sol (OFFSET=144, swap=3/approve=6)
- OdosUnitTests.t.sol (OFFSET=20, swap=3/approve=6)
- OdosV3UnitTests.t.sol (OFFSET=20, swap=3/approve=6)
- SparkPSMExactInUnitTests.t.sol (OFFSET=40, swap=3/approve=6)
- SparkPSMExactOutUnitTests.t.sol (OFFSET=40, swap=3/approve=6)
- UniswapV2UnitTests.t.sol (OFFSET=72, swap=3/approve=6)
- UniswapV3UnitTests.t.sol (OFFSET=128, swap=3/approve=6)
- UniswapV4UnitTests.t.sol (OFFSET=120, swap=3 only)
- UniswapV3Router02UnitTests.t.sol (OFFSET=76, swap=3/approve=6) — fixed BytesLib issue

**Bridge hooks (6 files):**
- AcrossHooksV2.t.sol (OFFSET=92, base=3/approve=6)
- CCTPHooks.t.sol (OFFSET=20, ApproveAndCCTP=6/CCTPSend=3)
- StargateHooks.t.sol (OFFSET=108, base=3/approve=6)
- StargateHooksV2.t.sol (OFFSET=108, base=3/approve=6)
- CircleGatewayUnitTests.sol (OFFSET=20, wallet=6)
- BridgeHooks.t.sol (DeBridge, OFFSET=53, 3 exec)

**Vault hooks (8 files):**
- ERC4626VaultHooksTest.t.sol (ApproveAndDeposit=6, Deposit=3, Redeem=3)
- Deposit5115VaultHook.t.sol (3 exec)
- ApproveAndDeposit5115VaultHook.t.sol (6 exec)
- EthenaHooksTests.t.sol (CooldownShares, 3 exec)
- FirelightHooksTests.t.sol (Redeem, 3 exec)
- DETHHooksTests.t.sol (RequestRedeem=3, ApproveAndRequest=6)
- ERC7540HookTests.t..sol (4 tests: ApproveAndRequest=6, RequestDeposit=3, Deposit=3, RequestRedeem=3)
- ERC7540WithIdHookTests.t.sol (RedeemWithId, 3 exec)

**Loan hooks (2 files):**
- AaveV4LoanHooks.t.sol (Supply=7, Withdraw=3)
- MorphoLoanHooks.t.sol (Supply=6, Lend=6, Withdraw=3)

**Other hooks (4 files):**
- FetchNativeFeeHookTest.t.sol (3 exec)
- BurnSuperPositionsHook.t.sol (6 exec)
- MintSuperPositionsHook.t.sol (6 exec)
- PendleRouterRedeemHook.t.sol (5 exec)
- SpectraExchangeHooks.t.sol (3 exec)

## Bugs Found and Fixed During Testing

1. **CCTPHooks.t.sol**: ApproveAndCCTP tests were placed in `CCTPSendHookTests` contract (which doesn't have `cctpHook`) — moved to `CCTPHooks` contract
2. **MorphoLoanHooks.t.sol**: Withdraw test used `_encodeWithdrawData(false, false)` but function takes 7 params — fixed to `_encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, amount, 0)`
3. **PendleRouterRedeemHook.t.sol**: Used `_encodeData(...)` but helper is `_createRedeemData(...)` — fixed
4. **WithdrawWETHHook.t.sol**: Build test needs `vm.mockCall` for WETH balanceOf — added
5. **Multiple ApproveAnd* hooks**: Used execution count 3 instead of 6 — fixed (AcrossV2, Stargate, StargateV2, CircleGateway, MorphoLend)
6. **UniswapV3Router02UnitTests.t.sol**: Field preservation tests used BytesLib (not imported) — rewrote with byte-level comparison loops

## Final Test Counts
- **97 new roundtrip/field-preservation tests** — all pass
- **3,311 total unit tests** — all pass (0 failures, 0 skipped)
