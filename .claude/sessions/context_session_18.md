# Session 18: Array-Based Multi-Amount Interface (Option C) + Amendments

## Status: COMPLETE
- Date: 2026-06-10

## Overview
Replace single-value `decodeAmount`/`replaceCalldataAmount` with array-based `decodeAmounts`/`replaceCalldataAmounts` across all hooks. This enables hooks with multiple amounts (AaveV4 compound hooks, BatchTransferFromHook, MerklClaimRewardHook) to expose all their amounts through a unified interface.

## Completed Work

### Phase 1: Core Interface Migration (decodeAmounts / replaceCalldataAmounts)
1. **ISuperHook.sol** — Changed `ISuperHookInflowOutflow.decodeAmount() → decodeAmounts()`, `ISuperHookOutflow.replaceCalldataAmount() → replaceCalldataAmounts()`
2. **BaseHook.sol** — Added `error INVALID_AMOUNTS_LENGTH()`
3. **BaseLoanHook.sol** + **BaseAaveV4LoanHook.sol** — Changed virtual methods to array-based
4. **MorphoWithdrawHook.sol** — Override with ASSETS_OFFSET=112
5. **AaveV4SupplyAndBorrowHook.sol** + **AaveV4RepayAndWithdrawHook.sol** — Dual-amount overrides (2 amounts)
6. **BatchTransferFromHook.sol** + **MerklClaimRewardHook.sol** — Variable-length implementations
7. **65 single-amount hooks** — Bulk migrated via Python scripts
8. **Decode-only hooks** (ClaimAssetsDETHHook, ClaimWithdrawFirelightVaultHook) — Migrated
9. **No-op claim hooks** (FluidClaimRewardHook, GearboxClaimRewardHook, YearnClaimOneRewardHook) — Per A1 amendment, return `[]` not `[0]`
10. **All tests** (~50 files) — Migrated with helper functions `_singleAmount()` and `_dualAmounts()`
11. **Build verified** — 0 errors, all 320+ files compile

### Phase 2: Amendment A2 (amountRoles)
Added `AmountRole` enum (`INPUT`, `OUTPUT`, `AUX`) and `amountRoles()` method to `ISuperHookInflowOutflow` interface.

Implemented on all 83 hooks:
- **Base classes** (BaseLoanHook, BaseAaveV4LoanHook) — virtual, returns `[INPUT]`
- **Compound hooks** (AaveV4SupplyAndBorrowHook, AaveV4RepayAndWithdrawHook) — returns `[INPUT, OUTPUT]`
- **MorphoWithdrawHook** — returns `[INPUT]`
- **Variable-count hooks** (BatchTransferFromHook, MerklClaimRewardHook) — returns `[]` (all AUX)
- **No-op claim hooks** (Fluid, Gearbox, Yearn) — returns `[]`
- **65 single-amount hooks** — returns `[INPUT]`
- **Decode-only hooks** (ClaimAssetsDETHHook, ClaimWithdrawFirelightVaultHook) — returns `[]`
- **Mock** (FluidStakeWithPermitHook) — returns `[INPUT]`
- **Build verified** — 0 errors

### Phase 3: ClaimRFLRHook Update
- Removed `month` parameter from hook data layout
- Now calls `IRNat(RNAT).getCurrentMonth()` on-chain instead
- Data layout changed: `projectIdsLength` at offset 0, `projectIds[]` starting at offset 32
- Updated all 12 tests — all pass

## Files Modified
- ~83 source files (src/hooks/**, src/interfaces/ISuperHook.sol)
- ~50 test files
- 1 mock file (test/mocks/unused-hooks/FluidStakeWithPermitHook.sol)
- Total: ~134 files

### Phase 4: T1-T4 Spec Lock-in

**T1: amountRoles(bytes memory data)** — Changed signature from `amountRoles()` to `amountRoles(bytes memory data)` across all 83 hooks. Fixed-count hooks ignore the data param. Variable-count hooks (BatchTransferHook, MetaMorphoReallocate in future) would read count from data.

**Sizeless hooks correction** — MerklClaimRewardHook and BatchTransferFromHook are now properly sizeless:
- `decodeAmounts()` returns `[]`, `amountRoles()` returns `[]`, `replaceCalldataAmounts()` accepts only empty array
- Spec definition: a slot belongs in decodeAmounts/amountRoles **iff the OMS can rewrite it at execution time without invalidating any commitment (signature or proof) embedded in the same data**
- Merkl amounts are merkle-proof-bound, Permit2 amounts are signature-bound → both fail the test → sizeless

**T3: MorphoWithdrawHook XOR invariant** — `replaceCalldataAmounts` now enforces assets-XOR-shares: reverts with `AMOUNT_NOT_VALID()` if both assets and shares are nonzero or both are zero after replacement.

**T4: ERC-165 supportsInterface** — Added IERC165 to BaseHook with three-state detection:
- S1: `supportsInterface(ISuperHookInflowOutflow)` == true → hook has sizing interface (sized)
- S2: same as S1 but `amountRoles(data).length == 0` → authoritatively sizeless
- S3: `supportsInterface(ISuperHookInflowOutflow)` == false → legacy, no sizing interface
- Implementation uses virtual `_supportsSizingInterface()` override pattern (returns false in BaseHook, true in hooks that implement the interface)
- 77 hooks override `_supportsSizingInterface() → true`
- BaseLoanHook override covers all 13 loan hooks

### Phase 5: AmountMeta Struct (Denomination Typing)

**Replaced `AmountRole` enum with `AmountMeta` struct** containing `Direction` (IN/OUT) and `Denomination` (TOKEN/ASSETS/SHARES).

Interface changes in ISuperHook.sol:
```solidity
enum Direction { IN, OUT }
enum Denomination { TOKEN, ASSETS, SHARES }
struct AmountMeta { Direction dir; Denomination denom; }
function amountRoles(bytes memory data) external pure returns (AmountMeta[] memory meta);
```

Denomination classification across 77 hooks:
- **TOKEN** (IN, TOKEN): All swappers (~21), bridges (~11), token hooks (~6), stake hooks (~6), FetchNativeFeeHook, ClaimFailedTransferHook — raw ERC-20 amounts
- **ASSETS** (IN, ASSETS): Deposit4626, ApproveAndDeposit4626, Deposit5115, ApproveAndDeposit5115, Deposit7540, RequestDeposit7540, ApproveAndRequestDeposit7540, Withdraw7540, WithdrawWithId7540 — underlying asset amounts
- **SHARES** (IN, SHARES): Redeem4626, Redeem5115, Redeem7540, RedeemWithId7540, RequestRedeem7540, RequestRedeemDETH, ApproveAndRequestRedeemDETH, EthenaCooldownShares, RedeemFirelightVault, MintSuperPositions, BurnSuperPositions — vault share amounts
- **Sizeless** (empty []): FluidClaimReward, GearboxClaimReward, YearnClaimOneReward, MerklClaimReward, BatchTransferFrom, ClaimAssetsDETH, ClaimWithdrawFirelightVault
- **Mock**: FluidStakeWithPermitHook (TOKEN)

Special hooks:
- **BaseLoanHook**: returns `[(IN, TOKEN)]` — covers 7 Morpho hooks + inheritors
- **BaseAaveV4LoanHook**: returns `[(IN, TOKEN)]` — covers 4 simple Aave hooks
- **AaveV4SupplyAndBorrowHook**: `[(IN, TOKEN), (OUT, TOKEN)]` — supply + borrow
- **AaveV4RepayAndWithdrawHook**: `[(IN, TOKEN), (OUT, TOKEN)]` — repay + withdraw
- **MorphoWithdrawHook**: `[(IN, ASSETS), (IN, SHARES)]` — dual-slot with XOR invariant, OMS picks slot by denomination

Build verified — 0 errors.

### Phase 6: Comprehensive Hook Sizing Interface Tests

Added exhaustive unit tests and fork-based integration tests for the sizing interface.

#### File 1: Extended `test/unit/hooks/HookSizingInterface.t.sol`
**Previous: 1028 lines, ~30 tests → Now: ~1600 lines, 146 tests**

New test categories added:
- **Exhaustive ERC-165** (2 tests): `test_SupportsInterface_ALL_Hooks_InflowOutflow` and `test_SupportsInterface_ALL_Hooks_Outflow` — verify all 77+ hooks return true for both ISuperHookInflowOutflow and ISuperHookOutflow. Also `test_SupportsInterface_DecodeOnly_ButAmountRolesEmpty` for ClaimAssetsDETH/ClaimWithdrawFirelight.
- **Decode/Replace roundtrips** (~50 tests): Complete coverage across all hook categories:
  - Bridges: AcrossV1, AcrossV2, ApproveAcrossV1/V2, Stargate, StargateV2, ApproveStargate/V2, deBridge, CCTP, ApproveCCTP, CircleGateway
  - Swappers: UniV3, ApproveUniV3, UniV3Router02, UniV2, UniV4, OdosV2, OdosV3, KyberSwap, ApproveKyberSwap, SparkPSMExactIn, SparkPSMExactOut, AlgebraIntegral, OpenOcean, ApproveOpenOcean, SpectraRedeem, PendleRedeem
  - Tokens: ApproveERC20, TransferHook, NativeTransfer, DepositWETH, WithdrawWETH
  - Stake: FluidStake, FluidUnstake, GearboxStake, GearboxUnstake, ApproveFluidStake, ApproveGearboxStake
  - Vault 5115: Deposit5115, ApproveDeposit5115, Redeem5115
  - Vault 7540: Deposit7540, RequestDeposit7540, Redeem7540, RedeemWithId7540, RequestRedeem7540, Withdraw7540, WithdrawWithId7540, ApproveRequestDeposit7540
  - Special vaults: RequestRedeemDETH, ApproveRequestRedeemDETH, EthenaCooldown, RedeemFirelight, MintSP, BurnSP
  - Morpho single: MorphoSupply, MorphoLend, MorphoBorrow, MorphoRepay, MorphoSupplyAndBorrow, MorphoRepayAndWithdraw
  - Aave V4 single: AaveV4Supply, AaveV4Withdraw, AaveV4Borrow, AaveV4Repay
  - Special: FetchNativeFee, ClaimFailedTransfer
- **Fuzz tests** (9 new): Representative hooks from each category — MorphoSupply, SwapUniswapV3, AcrossV1, FluidStake, Deposit5115, Redeem7540, AaveV4Supply, AaveV4RepayAndWithdraw (dual-amount), MintSuperPositions
- **Field preservation** (4 tests): MorphoWithdraw (4 addresses + LLTV), AaveV4SupplyAndBorrow (3 addrs + reserveIds + usePrev), MorphoSupply (4 addrs + LLTV + usePrev), SwapUniswapV3 (prefix + suffix bytes)
- **INVALID_AMOUNTS_LENGTH** (6 tests): Bridges, Swappers, Stake, MorphoLoan, AaveV4Single, AaveV4RepayAndWithdraw
- **Edge cases** (7 tests): ZeroAmount decode, MaxUint256 decode, ZeroToNonzero replace, NonzeroToZero replace, Idempotent replace (single + dual), PreservesLength across categories

Helper functions added: `_buildBridgeData_92`, `_buildBridgeData_108`, `_buildSwapperData_128`, `_buildSwapperData_120`, `_buildSwapperData_144`, `_buildMorphoSingleData`, `_buildAaveV4SingleData`

#### File 2: New `test/unit/hooks/HookSizingInterfaceIntegration.t.sol`
Fork-based integration tests using real Ethereum mainnet addresses at pinned block 21,929,476.

Tests:
- **ERC-4626**: `test_Fork_Deposit4626_RealVault_DecodeReplace`, `test_Fork_Deposit4626_AmountMeta`, `test_Fork_Redeem4626_RealVault_DecodeReplace`
- **Morpho**: `test_Fork_MorphoSupply_RealMarket_DecodeReplace` (with real WBTC/USDC market params), `test_Fork_MorphoWithdraw_RealMarket_XOR`, `test_Fork_MorphoWithdraw_RealMarket_RevertsBothNonzero`
- **Uniswap V3**: `test_Fork_SwapUniswapV3_RealRouter_DecodeReplace`
- **Across V2**: `test_Fork_AcrossV2_RealSpokePool_DecodeReplace`
- **Build verification** (4 tests): Independent byte-offset validation for Deposit4626, MorphoSupply, AcrossV2, SwapUniswapV3
- **Fuzz** (3 tests): Fork-based fuzz with real addresses for Deposit4626, MorphoSupply, MorphoWithdraw XOR

Real addresses used: Morpho Blue (0xBBBB...), UniV3Router (0xE592...), SpokePool (0x5c7B...), ERC4626 Vault (0xdd0f...), WETH, USDC, DAI, WBTC, Morpho Oracle/IRM for WBTC/USDC market.

Requires `ETHEREUM_RPC_URL` env var to run fork tests.

#### Verification
- `forge build` — 0 errors
- `forge test --match-contract HookSizingInterfaceTest` — 146 tests passed, 0 failed
- Fork tests require RPC URL (run via `make ftest` or with ETHEREUM_RPC_URL set)

### Phase 7: Security Audit Fixes

**4 security agents audited all 83 hooks.** Fixed HIGH and MEDIUM findings:

#### Fix 1: MorphoWithdrawHook XOR check ordering (MEDIUM)
- Moved assets-XOR-shares validation **before** `_replaceCalldataAmount` calls
- Prevents partial data mutation on revert path
- File: `src/hooks/loan/morpho/MorphoWithdrawHook.sol`

#### Fix 2: BaseAaveV4LoanHook offset 157 clarity (MEDIUM)
- Added NatSpec documenting that `IS_FULL_REPAYMENT_OFFSET=157` and `BORROW_AMOUNT_OFFSET=157` are used by different data layouts (RepayAndWithdraw vs SupplyAndBorrow), never simultaneously
- File: `src/hooks/loan/aave-v4/BaseAaveV4LoanHook.sol`

#### Fix 3: AaveV4RepayAndWithdrawHook isFullRepayment docs (HIGH→documented)
- Added NatSpec warning that when `isFullRepayment=true`, `build()` uses `type(uint256).max` for both amounts — replaced values are irrelevant
- File: `src/hooks/loan/aave-v4/AaveV4RepayAndWithdrawHook.sol`

#### Fix 4 & 5: ClaimAssetsDETH + ClaimWithdrawFirelight ERC-165 fix (MEDIUM)
- Overrode `supportsInterface` to return `true` for `ISuperHookInflowOutflow` but `false` for `ISuperHookOutflow` (these hooks have no `replaceCalldataAmounts`)
- Changed `decodeAmounts` to return `[]` (requestId is not a sizable amount)
- Fixed NatSpec that incorrectly claimed ISuperHookOutflow support
- Files: `src/hooks/vaults/deth/ClaimAssetsDETHHook.sol`, `src/hooks/vaults/firelight/ClaimWithdrawFirelightVaultHook.sol`

#### Test updates for security fixes
- Updated 4 test files to match corrected behavior
- Added 18 new integration tests (total: 184 in HookSizingInterfaceTest):
  - MorphoWithdraw XOR data-unmodified-on-revert (deterministic + fuzz)
  - MorphoWithdraw valid-pairs fuzz
  - AaveV4RepayAndWithdraw flag preservation (fullRepay=true, false, fuzz)
  - DecodeOnly ERC-165 full matrix (all interface IDs)
  - DecodeOnly empty arrays with any data input
  - ERC-165 sized-vs-decode-only boundary test
  - All-denomination roundtrip test
  - All-category length preservation test
  - All-category denomination correctness test
  - Comprehensive INVALID_AMOUNTS_LENGTH across all categories
  - Double-replace idempotent + latest-wins
  - MorphoWithdraw XOR enforcement on second replace
  - MaxUint256 roundtrip across all hook types
  - Zero amount roundtrip across all hook types

#### Verification
- `forge build` — 0 errors
- `forge test --match-contract HookSizingInterfaceTest` — 184 tests passed, 0 failed
- All 7 affected test suites — 599 tests passed, 0 failed

### Phase 8: Combined usePrevHookAmount + decodeAmounts + replaceCalldataAmounts Tests

Added 16 tests to `test/unit/hooks/HookSizingInterface.t.sol` that verify `usePrevHookAmount`, `decodeAmounts`, and `replaceCalldataAmounts` work correctly together in the same test:

- **Deterministic tests (11)**:
  - `test_Combined_Deposit4626_DecodeReplaceUsePrev` — vault 4626 with usePrev=true
  - `test_Combined_Deposit4626_DecodeReplaceUsePrevFalse` — vault 4626 with usePrev=false
  - `test_Combined_SwapUniV3_DecodeReplaceUsePrev` — swapper UniV3
  - `test_Combined_AcrossV2_DecodeReplaceUsePrev` — bridge AcrossV2
  - `test_Combined_FluidStake_DecodeReplaceUsePrev` — stake Fluid
  - `test_Combined_AaveV4Supply_DecodeReplaceUsePrev` — Aave V4 single-amount
  - `test_Combined_AaveV4SupplyAndBorrow_DecodeReplaceUsePrev` — Aave V4 dual-amount
  - `test_Combined_MorphoSupply_DecodeReplaceUsePrev` — Morpho single-amount
  - `test_Combined_MultiReplace_UsePrevPreserved` — three sequential replaces
  - `test_Combined_ReplaceWithZero_UsePrevPreserved` — replace with zero
  - `test_Combined_AllCategories_UsePrevAfterReplace` — cross-category sweep (6 hook types)

- **Fuzz tests (5)**:
  - `test_Fuzz_Combined_Deposit4626` — vault 4626 fuzz
  - `test_Fuzz_Combined_SwapUniV3` — swapper fuzz
  - `test_Fuzz_Combined_AaveV4SupplyAndBorrow` — dual-amount fuzz
  - `test_Fuzz_Combined_AcrossV2` — bridge fuzz
  - `test_Fuzz_Combined_MorphoSupply` — Morpho fuzz

Each test verifies:
1. `decodeUsePrevHookAmount()` reads the correct flag
2. `decodeAmounts()` reads the original amount(s)
3. `replaceCalldataAmounts()` replaces amount(s)
4. After replace, `decodeAmounts()` reads the new amount(s)
5. After replace, `decodeUsePrevHookAmount()` flag is preserved unchanged

#### Verification
- `forge build` — 0 errors
- All 16 new tests passed, 0 failed

### Phase 9: On-Chain `name()` Property for All Hooks

Added `function name() external pure returns (string memory)` to ISuperHook interface. Every concrete hook now returns a unique, human-readable name for UI display.

#### Interface Change
- `src/interfaces/ISuperHook.sol` — Added `name()` to `ISuperHook` interface

#### Implementation (120 concrete hooks + 14 mocks)
Each hook gets a hardcoded string constant. Examples:
- `Deposit4626VaultHook` → `"Deposit ERC-4626 Vault"`
- `SwapUniswapV3Hook` → `"Swap Uniswap V3"`
- `AcrossSendFundsAndExecuteOnDstHook` → `"Across Bridge"`
- `MorphoSupplyHook` → `"Morpho Supply"`

Automated via Python script (`scripts/add_hook_names.py`) + fixer (`scripts/fix_hook_names.py`) to handle multi-line constructors.

#### NatSpec
- Source files that import ISuperHook use `@inheritdoc ISuperHook`
- Files that DON'T import ISuperHook directly (many swappers, bridges, etc.) use `@notice Human-readable name for UI display` to avoid doc tag errors

#### Test/Mock Updates
- Added `name()` to 14 mock hooks (MockDexHook, MockAcrossHook, MockClaimHook, + 10 unused-hooks, + MockPendleRouterSwapHook skipped as not a BaseHook)
- Added `name()` to 5 integration test mock contracts (TestHook, MockHook, MockPrevHookV2, MockPrevHook, MockPrevHookRouter02)

#### Tests Added (3 new in HookSizingInterface.t.sol)
- `test_Name_AllHooks_NonEmpty` — verifies all 89 deployed hooks return non-empty name
- `test_Name_AllHooks_Unique` — O(n²) uniqueness check across all 89 hook names
- `test_Name_SpotCheck` — 8 specific hooks verified against expected strings

#### Verification
- `forge build` — 0 errors
- `forge test --match-contract HookSizingInterfaceTest` — 203 tests passed, 0 failed
- All names are unique (verified by Python script + Solidity test)

### Phase 10: On-Chain `description()` Property for All Hooks

Added `function description() external pure returns (string memory)` to ISuperHook interface. Every concrete hook now returns a unique, human-readable one-sentence description for UI display.

#### Interface Change
- `src/interfaces/ISuperHook.sol` — Added `description()` to `ISuperHook` interface (right after `name()`)

#### Implementation (134 concrete hooks + 5 integration test mocks + 1 BaseHook test mock)
Each hook gets a hardcoded description string. Examples:
- `Deposit4626VaultHook` → `"Deposits assets into an ERC-4626 vault and receives shares"`
- `SwapUniswapV3Hook` → `"Swaps tokens via Uniswap V3 exact input single"`
- `AcrossSendFundsAndExecuteOnDstHook` → `"Bridges tokens via Across and executes on destination chain"`
- `MorphoSupplyHook` → `"Supplies collateral to a Morpho market"`

Automated via Python script (`scripts/add_hook_descriptions.py`) with fixed regex for contract name extraction (handles `contract` keyword appearing in NatSpec comments).

#### NatSpec
- All hooks use `@notice One-sentence description of what this hook does`
- Most hooks use `override` keyword; `MockClaimHook` omits it (matches `name()` pattern in that file)

#### Test/Mock Updates
- Added `description()` to 14 mock hooks in `test/mocks/`
- Added `description()` to 5 integration test inline contracts
- Added `description()` to 1 BaseHook.t.sol test hook
- All mocks return `"Mock hook for testing"`

#### Tests Added (3 new in HookSizingInterface.t.sol)
- `test_Description_AllHooks_NonEmpty` — verifies all 89 deployed hooks return non-empty description
- `test_Description_AllHooks_Unique` — O(n^2) uniqueness check across all 89 hook descriptions
- `test_Description_SpotCheck` — 5 specific hooks verified against expected strings

#### Verification
- `forge build` — 0 errors
- `forge test --match-contract HookSizingInterfaceTest` — 206 tests passed, 0 failed
- No deployed hook exceeds 24KB size limit
- All descriptions are unique

### Phase 11: Canonical ActionType — Composite (intent, stage) Design Decision

**Status**: DECIDED — array of composites. Not yet encoded as JSON manifest.

#### Problem
Three competing taxonomies: v2-core `hookType × subtype`, bundler ActionType proto, erebor FE classification. The doc's flat `actionType` enum can't be derived from `hookType × subtype` because `NONACCOUNTING × ERC7540` contains both deposit-like (RequestDeposit) and withdraw-like (RequestRedeem) hooks. SUP-20043 showed the cost of unnormalized enums.

#### Decision: Array of (intent, stage) composites

```
intent ∈ {deposit, withdraw, rewards, swap, bridge, stake, unstake,
          lend, borrow, repay, transfer, config, permissions}

stage  ∈ {instant, request, fulfill, claim, cancel}
```

- Each hook declares an **array** of `(intent, stage)` pairs
- Single-intent hooks: `[{intent, stage}]` (most hooks)
- Compound hooks: `[{intent1, stage1}, {intent2, stage2}]` (4 hooks)
- Flat display labels derived from composite; bundler/erebor mappings become deterministic

#### Key Properties

**P1** (sizeless alignment): truly-sizeless ≈ `intent ∈ {config, permissions}` or `stage = claim` (amount-as-output)

**P2** (CI-lintable against hookType):
- `intent ∈ {config, permissions, transfer} ⇒ hookType = NONACCOUNTING`
- `intent = deposit, stage = instant ⇒ hookType = INFLOW`
- `intent = withdraw, stage = instant ⇒ hookType = OUTFLOW`
- `intent ∈ {swap, bridge, stake, unstake} ⇒ hookType = NONACCOUNTING`
- `intent ∈ {lend, borrow, repay}, stage = instant ⇒ hookType = NONACCOUNTING` (loan hooks inherit NONACCOUNTING from BaseLoanHook)

**P3** (direction bit): denomination model (M4) sizes exits in shares and entries in assets, so manifest carries direction regardless

#### Full 120-Hook Mapping

##### deposit (11 hooks)
| Stage | Hooks |
|-------|-------|
| instant | Deposit4626VaultHook, ApproveAndDeposit4626VaultHook, Deposit5115VaultHook, ApproveAndDeposit5115VaultHook |
| request | RequestDeposit7540VaultHook, ApproveAndRequestDeposit7540VaultHook |
| fulfill | Deposit7540VaultHook |
| cancel | CancelDepositRequest7540Hook, CancelDepositRequestWithId7540Hook |
| claim | ClaimCancelDepositRequest7540Hook, ClaimCancelDepositRequestWithId7540Hook |

##### withdraw (20 hooks)
| Stage | Hooks |
|-------|-------|
| instant | Redeem4626VaultHook, Redeem5115VaultHook, Redeem7540VaultHook, RedeemWithId7540VaultHook, Withdraw7540VaultHook, WithdrawWithId7540VaultHook, MorphoWithdrawHook, AaveV4WithdrawHook |
| request | RequestRedeem7540VaultHook, RequestRedeemDETHHook, ApproveAndRequestRedeemDETHHook, RedeemFirelightVaultHook, EthenaCooldownSharesHook |
| fulfill | ClaimAssetsDETHHook, ClaimWithdrawFirelightVaultHook, EthenaUnstakeHook |
| cancel | CancelRedeemRequest7540Hook, CancelRedeemRequestWithId7540Hook |
| claim | ClaimCancelRedeemRequest7540Hook, ClaimCancelRedeemRequestWithId7540Hook |

##### rewards (7 hooks)
| Stage | Hooks |
|-------|-------|
| claim | FluidClaimRewardHook, GearboxClaimRewardHook, YearnClaimOneRewardHook, MerklClaimRewardHook, ClaimRFLRHook, WithdrawRFLRHook, WithdrawVestedRFLRHook |

##### swap (29 hooks)
| Stage | Hooks |
|-------|-------|
| instant | SwapUniswapV3Hook, ApproveAndSwapUniswapV3Hook, SwapUniswapV3Router02Hook, ApproveAndSwapUniswapV3Router02Hook, SwapUniswapV2Hook, ApproveAndSwapUniswapV2Hook, SwapUniswapV4Hook, SwapOdosV2Hook, ApproveAndSwapOdosV2Hook, SwapOdosV3Hook, ApproveAndSwapOdosV3Hook, SwapKyberSwapHook, ApproveAndSwapKyberSwapHook, SwapSparkPSMExactInHook, ApproveAndSwapSparkPSMExactInHook, SwapSparkPSMExactOutHook, ApproveAndSwapSparkPSMExactOutHook, SwapAlgebraIntegralHook, ApproveAndSwapAlgebraIntegralHook, SwapOpenOceanSparkDexHook, ApproveAndSwapOpenOceanSparkDexHook, Swap1InchHook, PendleRouterRedeemHook, PendleRouterSwapHook, PendleUnifiedHook, SpectraExchangeRedeemHook, SpectraExchangeDepositHook, DepositWETHHook, WithdrawWETHHook |

##### bridge (15 hooks)
| Stage | Hooks |
|-------|-------|
| instant | AcrossSendFundsAndExecuteOnDstHook, ApproveAndAcrossSendFundsAndExecuteOnDstHook, AcrossSendFundsAndExecuteOnDstHookV2, ApproveAndAcrossSendFundsAndExecuteOnDstHookV2, StargateSendHook, ApproveAndStargateSendHook, StargateSendHookV2, ApproveAndStargateSendHookV2, DeBridgeSendOrderAndExecuteOnDstHook, CCTPSendHook, ApproveAndCCTPSendHook, CircleGatewayWalletHook, CircleGatewayMinterHook |
| cancel | DeBridgeCancelOrderHook |
| claim | ClaimFailedTransferHook |

##### stake (4 hooks)
| Stage | Hooks |
|-------|-------|
| instant | FluidStakeHook, ApproveAndFluidStakeHook, GearboxStakeHook, ApproveAndGearboxStakeHook |

##### unstake (2 hooks)
| Stage | Hooks |
|-------|-------|
| instant | FluidUnstakeHook, GearboxUnstakeHook |

##### lend (3 hooks)
| Stage | Hooks |
|-------|-------|
| instant | MorphoSupplyHook, MorphoLendHook, AaveV4SupplyHook |

##### borrow (2 hooks)
| Stage | Hooks |
|-------|-------|
| instant | MorphoBorrowHook, AaveV4BorrowHook |

##### repay (2 hooks)
| Stage | Hooks |
|-------|-------|
| instant | MorphoRepayHook, AaveV4RepayHook |

##### transfer (6 hooks)
| Stage | Hooks |
|-------|-------|
| instant | TransferERC20Hook, TransferHook, NativeTransferHook, BatchTransferHook, OfframpTokensHook, BatchTransferFromHook |

##### config (11 hooks)
| Stage | Hooks |
|-------|-------|
| instant | MetaMorphoReallocateHook, ForceDeallocateMorphoHook, MarkRootAsUsedHook, FetchNativeFeeHook, SetSlippageHook, MintSuperPositionsHook, BurnSuperPositionsHook, RecordPurchasePendlePTAmortizedOracleHook, RecordPurchasePendlePTAmortizedOracleHookV2, RecordRedemptionPendlePTAmortizedOracleHook, RecordRedemptionPendlePTAmortizedOracleHookV2 |

##### permissions (4 hooks)
| Stage | Hooks |
|-------|-------|
| instant | ApproveERC20Hook, SetOperator7540Hook, CircleGatewayAddDelegateHook, CircleGatewayRemoveDelegateHook |

##### Compound hooks — array of composites (4 hooks)
| Hook | ActionTypes |
|------|------------|
| MorphoSupplyAndBorrowHook | [(lend, instant), (borrow, instant)] |
| AaveV4SupplyAndBorrowHook | [(lend, instant), (borrow, instant)] |
| MorphoRepayAndWithdrawHook | [(repay, instant), (withdraw, instant)] |
| AaveV4RepayAndWithdrawHook | [(repay, instant), (withdraw, instant)] |

**Total: 120 hooks = 116 single-intent + 4 dual-intent**

#### Design Rationale for Edge Cases
- **WETH wrap/unwrap** → (swap, instant): 1:1 token conversion, not a bridge
- **Pendle/Spectra** → (swap, instant): DEX-like token exchange mechanics; PTYT subtype remains on-chain for protocol identification
- **Oracle recording hooks** → (config, instant): side-effect state bookkeeping, no fund movement
- **MintSP/BurnSP** → (config, instant): cross-chain position plumbing, NONACCOUNTING hookType
- **MorphoWithdraw/AaveV4Withdraw** → (withdraw, instant): collateral retrieval is a withdrawal regardless of protocol context
- **ClaimFailedTransfer** → (bridge, claim): recovery from bridge failure carries the original operation's intent
- **Deposit7540VaultHook** → (deposit, fulfill): mints shares after async request was processed; hookType=INFLOW because it's the accounting entry point
- **Loan hooks** → all NONACCOUNTING (inherit from BaseLoanHook), so `lend/borrow/repay` intent with NONACCOUNTING hookType is the P2 rule

#### Next Steps
- [ ] Encode as `manifests/hook-action-types.json`
- [ ] Add CI lint validating P2 rules against on-chain hookType
- [ ] Ship mapping table from composite → bundler ActionType proto
- [ ] Ship mapping table from composite → erebor FE classification

### Phase 12: Hook Manifest — Unified Classification & Metadata

**Status**: PLANNED — awaiting approval

#### Decision: actionTypes OFF-chain, not in bytecode

After review, `actionTypes` belongs in the manifest JSON versioned with v2-core, CI-bound to on-chain contracts, **not gas-paid in bytecode**. Rationale:
- "On-chain source of truth" = versioned with contracts + CI-linted against them, not deployed as code
- What execution actually needs on-chain: `decodeAmounts / replaceCalldataAmounts / amountRoles` (already shipped)
- `name()` and `description()` are already on-chain (Phases 9-10) — noted as a design tension, but no reason to revert since they're shipped and within size budget
- Classification metadata (intent, stage, vocabulary, per-leg linkage) is consumed by bundler, erebor FE, and curator workspace — all off-chain consumers

**No new contract changes in Phase 12.** Pure manifest work.

---

#### Design Invariants (T1-T4)

##### T1: Ordered, not a set
`actionTypes` array position = execution order of legs. `(lend, borrow) ≠ (borrow, lend)` for simulation and health-factor math. `RepayAndWithdraw` is always `[(repay, instant), (withdraw, instant)]` because repay must precede collateral withdrawal.

##### T2: Per-leg sizing linkage
Each `amountRoles()` entry maps 1:1 to a leg by array index:
- `amountRoles[0]` ↔ `actionTypes[0]` (first leg)
- `amountRoles[1]` ↔ `actionTypes[1]` (second leg)

Per-leg sizing mode (manifest field, not on-chain):
| Mode | Meaning | Example |
|------|---------|---------|
| `sized` | OMS picks this amount directly | Supply amount in SupplyAndBorrow |
| `derived` | Computed from another leg (e.g. `borrow = f(supply, targetLTV)`) | Borrow amount in SupplyAndBorrow (when LTV-driven) |
| `output-only` | Read from `postExecute` delta, not pre-set | Future: oracle price read |
| `none` | No sizing (sizeless leg) | Claim legs |

Today's 4 compound hooks:
```
AaveV4SupplyAndBorrowHook:
  actionTypes:  [(lend, instant), (borrow, instant)]     # T1: ordered
  amountRoles:  [(IN, TOKEN),    (OUT, TOKEN)]            # existing on-chain
  sizingMode:   [sized,          sized]                   # T2: both OMS-sizable today
  # Note: OMS may choose to derive borrow from LTV instead — sizing mode is a hint, not a constraint

AaveV4RepayAndWithdrawHook:
  actionTypes:  [(repay, instant), (withdraw, instant)]
  amountRoles:  [(IN, TOKEN),      (OUT, TOKEN)]
  sizingMode:   [sized,            sized]
```

The hookType-level classification (`NONACCOUNTING` for all 4 compound hooks, inherited from `BaseLoanHook`) applies to the hook as a whole. Per-leg direction is already encoded in `amountRoles[i].dir` (`IN`/`OUT`).

##### T3: hookType lint for compound hooks (P2 extension)
Multi-leg P2 rule: "for each leg, the `(intent, stage)` must be consistent with the hook-level `hookType`."

All 4 compound hooks today are `NONACCOUNTING` with `intent ∈ {lend, borrow, repay, withdraw}` — all valid under NONACCOUNTING.

If a future compound hook mixed an `INFLOW` leg with a `NONACCOUNTING` leg, the manifest lint would flag it. The rule:
- If ANY leg has `intent=deposit, stage=instant` → hookType must be INFLOW
- If ANY leg has `intent=withdraw, stage=instant` AND hookType=OUTFLOW → valid
- Mixed INFLOW+OUTFLOW in one hook → currently impossible, lint would reject

##### T4: Canonical vocabulary (pinned)
```
intent ∈ { deposit, withdraw, rewards, swap, bridge, stake, unstake,
           lend, borrow, repay, transfer, config, permissions }

stage  ∈ { instant, request, fulfill, claim, cancel }
```

- `lend` (not `supply`) — domain verb for market operations
- `withdraw` covers both vault withdrawal and loan collateral retrieval
- Bundler ActionType proto and erebor FE classification derive from these via deterministic mapping rules (documented in manifest)
- Display labels for compound hooks: join of leg labels (e.g. "Lend + Borrow")

---

#### Compound Hooks: Security Rationale

Compound hooks (SupplyAndBorrow, RepayAndWithdraw) are **intentionally pre-composed as single hooks** rather than decomposed into atomic hook chains. This is a security feature:

- **Single Merkle leaf** = explicitly approves exactly this sequence (supply→borrow)
- If decomposed into atomic hooks, both `supply` and `borrow` would appear as separate leaves → any combination of them is approved, which is genuinely riskier (user could be tricked into supply-only without borrow, or borrow-only without supply as collateral)
- The on-chain executor already supports hook chaining, but the Merkle tree signing model makes pre-composition the safer default for leverage operations

**Implication for manifest**: compound hooks are first-class entries, not synthetic compositions. The `actionTypes` array describes what they do, but they remain single contract deployments with single Merkle leaf semantics.

---

#### Future: Callback Support Gap (noted, not in scope)

The on-chain executor currently does not support callbacks. Two known cases with business value:
1. **Flashloans** — borrow→execute→repay in a single atomic transaction (requires callback from lending protocol)
2. **`_safeMint()` / `onERC721Received`** — receiving NFTs triggers a callback to the receiver (see Dialectic DETH Redeem Research)

Not a major issue today since borrowing is not in scope and NFT receipt is rare, but these will likely become needed. When they do, the executor needs to support callback registration — a separate workstream from the manifest.

---

#### Part A: Hook Manifest JSON

Create `manifests/hooks.json` — single source of truth for all hook metadata.

##### A1. Schema (v1)

```jsonc
{
  "$schema": "hook-manifest-v1",
  "generatedAt": "2026-06-15T00:00:00Z",
  "hooks": {
    "Deposit4626VaultHook": {
      // === Mirrored from on-chain (CI-validated) ===
      "name": "Deposit ERC-4626 Vault",
      "description": "Deposits assets into an ERC-4626 vault and receives shares",
      "hookType": "INFLOW",
      "subtype": "ERC4626",
      "amountMeta": [{ "direction": "IN", "denomination": "ASSETS" }],
      "sized": true,
      "erc165": ["ISuperHookInflowOutflow", "ISuperHookOutflow"],

      // === Classification (off-chain source of truth) ===
      "actionTypes": [{ "intent": "deposit", "stage": "instant" }],
      "legSizing": ["sized"],

      // === Deployment ===
      "addresses": {
        "1":     "0x...",
        "8453":  "0xe3FFf64A14A38a5b082502779ae6f6a9a273b02C",
        "42161": "0x...",
        "10":    "0x..."
      },

      // === Relationships ===
      "requiresApproval": false,
      "approveVariant": "ApproveAndDeposit4626VaultHook",
      "asyncLifecycle": null,
      "compatibleProtocols": ["erc4626"],

      // === Parameter schema (for curator workspace / UI) ===
      "parameterSchema": {
        "fields": [
          { "name": "yieldSourceOracleId", "type": "bytes32", "offset": 0 },
          { "name": "yieldSource",         "type": "address", "offset": 32 },
          { "name": "amount",              "type": "uint256", "offset": 52, "sizable": true },
          { "name": "usePrevHookAmount",   "type": "bool",    "offset": 84 }
        ]
      },

      // === Operational ===
      "failureModes": [
        "Reverts if vault rejects deposit (paused, cap reached)",
        "Reverts if insufficient token balance or allowance"
      ]
    },

    "AaveV4SupplyAndBorrowHook": {
      "name": "Aave V4 Supply and Borrow",
      "description": "Supplies and borrows assets from an Aave V4 lending pool",
      "hookType": "NONACCOUNTING",
      "subtype": "AAVE_V4",
      "amountMeta": [
        { "direction": "IN",  "denomination": "TOKEN" },
        { "direction": "OUT", "denomination": "TOKEN" }
      ],
      "sized": true,
      "erc165": ["ISuperHookInflowOutflow", "ISuperHookOutflow"],

      "actionTypes": [
        { "intent": "lend",   "stage": "instant" },
        { "intent": "borrow", "stage": "instant" }
      ],
      "legSizing": ["sized", "sized"],

      "addresses": { "8453": "0x..." },
      "requiresApproval": false,
      "approveVariant": null,
      "asyncLifecycle": null,
      "compatibleProtocols": ["aave-v4"],

      "parameterSchema": {
        "fields": [
          { "name": "loanToken",        "type": "address", "offset": 0 },
          { "name": "collateralToken",  "type": "address", "offset": 20 },
          { "name": "spoke",            "type": "address", "offset": 40 },
          { "name": "supplyReserveId",  "type": "uint256", "offset": 60 },
          { "name": "borrowReserveId",  "type": "uint256", "offset": 92 },
          { "name": "amount",           "type": "uint256", "offset": 124, "sizable": true, "leg": 0 },
          { "name": "usePrevHookAmount","type": "bool",    "offset": 156 },
          { "name": "borrowAmount",     "type": "uint256", "offset": 157, "sizable": true, "leg": 1 }
        ]
      },

      "failureModes": [
        "Reverts if lending pool rejects supply (paused, supply cap)",
        "Reverts if borrow exceeds health factor threshold",
        "Reverts if insufficient token balance or allowance"
      ]
    },

    "RequestDeposit7540VaultHook": {
      "name": "Request Deposit ERC-7540 Vault",
      "description": "Requests a deposit into an ERC-7540 async vault",
      "hookType": "NONACCOUNTING",
      "subtype": "ERC7540",
      "amountMeta": [{ "direction": "IN", "denomination": "ASSETS" }],
      "sized": true,
      "erc165": ["ISuperHookInflowOutflow", "ISuperHookOutflow"],

      "actionTypes": [{ "intent": "deposit", "stage": "request" }],
      "legSizing": ["sized"],

      "addresses": { "1": "0x...", "8453": "0x01Af8d98DDA6310D8aE91af7439E1b5836ad3d9c" },
      "requiresApproval": true,
      "approveVariant": "ApproveAndRequestDeposit7540VaultHook",
      "asyncLifecycle": {
        "request": "RequestDeposit7540VaultHook",
        "fulfill": "Deposit7540VaultHook",
        "cancel": "CancelDepositRequest7540Hook",
        "claimCancel": "ClaimCancelDepositRequest7540Hook"
      },
      "compatibleProtocols": ["erc7540"],

      "parameterSchema": { "fields": "..." },
      "failureModes": ["Reverts if vault rejects request (paused, deposit cap)"]
    }
  }
}
```

##### A2. Field reference

**CI-validated fields** (read from deployed contracts, lint fails on mismatch):

| Field | On-chain source | Validation |
|-------|----------------|------------|
| `name` | `hook.name()` | Must match manifest |
| `description` | `hook.description()` | Must match manifest |
| `hookType` | `hook.hookType()` | Must match manifest |
| `subtype` | `hook.subtype()` | Must match manifest (as bytes32 → string) |
| `amountMeta` | `hook.amountRoles(sampleData)` | Direction + Denomination must match |
| `sized` | `hook.supportsInterface(ISuperHookInflowOutflow)` | Must match manifest |
| `erc165` | `hook.supportsInterface(...)` | Interface list must match |

**Classification fields** (off-chain source of truth, CI-linted against P2 rules):

| Field | Purpose | Lint rule |
|-------|---------|-----------|
| `actionTypes` | `[{intent, stage}]` — semantic classification | P2: intent×stage consistent with hookType |
| `legSizing` | Per-leg sizing mode — `[sized\|derived\|output-only\|none]` | Length must match amountMeta length |

**Deployment fields** (auto-generated from `script/output/`):

| Field | Source |
|-------|--------|
| `addresses` | Scraped from `script/output/{env}/{chainId}/*-latest.json` |

**Relationship fields** (manually maintained):

| Field | Purpose |
|-------|---------|
| `requiresApproval` | Whether this hook needs prior ERC-20 approval |
| `approveVariant` | Pointer to the approve-and-X variant (null if none) |
| `asyncLifecycle` | For async hooks: `{request, fulfill, cancel, claimCancel}` hook names |
| `compatibleProtocols` | Which DeFi protocols this hook integrates with |

**UI/operational fields** (manually maintained):

| Field | Purpose |
|-------|---------|
| `parameterSchema` | JSON schema for `build()` input: field names, types, byte offsets, sizable flag, leg index |
| `failureModes` | User-facing revert descriptions |

##### A3. Derived mappings (deterministic rules, documented in manifest)

**Bundler ActionType proto mapping:**
```
single-intent hook: actionTypes[0].intent → proto ActionType enum
compound hook:      COMPOSITE proto type, legs[] = actionTypes array
```

**Erebor FE classification:**
```
deposit/instant → "Deposit"
withdraw/instant → "Withdraw"
swap/instant → "Swap"
bridge/instant → "Bridge"
lend/instant → "Lend"
borrow/instant → "Borrow"
compound → join of leg labels: "Lend + Borrow"
async lifecycle → grouped by asyncLifecycle.request hook
```

**Sizeless detection:**
```
sized == false                                      → hook-level sizeless (legacy/no ISuperHookInflowOutflow)
sized == true && amountMeta.length == 0             → authoritatively sizeless (S2)
sized == true && all legSizing[i] == "none"         → all legs sizeless
actionTypes[0].intent ∈ {config, permissions}       → expected sizeless (P1)
actionTypes[0].stage == "claim"                     → expected sizeless (P1)
```

---

#### Part B: Generation Pipeline

##### B1. Manifest generator script

`scripts/generate_hook_manifest.py` (or forge script):

1. **On-chain fields**: Deploy all hooks locally (reuse HookSizingInterface.t.sol setup), call view functions, extract hookType/subtype/name/description/amountRoles/ERC165
2. **Addresses**: Parse `script/output/{staging,prod}/{chainId}/*-latest.json` files, match hook names to addresses
3. **Classification overlay**: Read `manifests/hook-classification.yaml` (manually maintained actionTypes + legSizing)
4. **Relationships overlay**: Read `manifests/hook-relationships.yaml` (approveVariant, asyncLifecycle, compatibleProtocols)
5. **Parameter schemas**: Read `manifests/hook-params.yaml` (per-hook field definitions — biggest manual lift)
6. **Failure modes**: Read `manifests/hook-failures.yaml`
7. **Merge + lint + output**: Produce `manifests/hooks.json`

##### B2. CI lint (`scripts/lint_hook_manifest.py`)

Runs on every PR that touches `src/hooks/` or `manifests/`:

1. **Completeness**: Every deployed hook has a manifest entry, no orphans
2. **On-chain consistency**: On-chain fields match what contracts return (requires local deployment or cached ABI calls)
3. **P2 rules**: Each `(intent, stage)` is consistent with `hookType`
4. **T1 ordering**: Compound hooks' `actionTypes` matches `amountRoles` array length
5. **T2 linkage**: `legSizing` array length matches `amountMeta` array length
6. **T3 mixed-direction**: No compound hook mixes INFLOW+OUTFLOW legs (currently impossible)
7. **T4 vocabulary**: All intents and stages come from the canonical enum set

---

#### Implementation Order

1. **Classification overlay** (`hook-classification.yaml`) — the Phase 11 120-hook mapping encoded as YAML
2. **Manifest generator** — on-chain fields + addresses (fully automatable) + classification overlay
3. **CI lint** — P2 + completeness + consistency checks
4. **Relationships overlay** — approveVariant, asyncLifecycle, compatibleProtocols (incremental)
5. **Parameter schemas** — biggest lift, one hook at a time, starting with most-used hooks
6. **Failure modes** — documentation pass, can be done incrementally

Steps 1-3 are the MVP. Steps 4-6 are incremental enrichment.

---

#### Verification

- `scripts/generate_hook_manifest.py` produces valid JSON
- `scripts/lint_hook_manifest.py` passes all checks
- P2 consistency validated
- No orphan/missing hooks between manifest and deployment outputs
- JSON schema validates against `hook-manifest-v1` schema

---

#### Open Questions for Future Phases

- **Strategy-level risk linting on leverage composites** (HF/LTV constraints per leg) — separate workstream, triggered by borrow legs being expressible in manifest
- **Callback support** (flashloans, `_safeMint`) — executor-level change, not manifest
- **Per-leg derived sizing formulas** (e.g. `borrow = f(supply, targetLTV)`) — currently both legs are `sized`, but when LTV-driven strategies ship, the manifest needs to encode the derivation rule

### Phase 12 Implementation: COMPLETE

**Files created:**
1. `manifests/hook-classification.yaml` — 120 hooks classified with actionTypes (intent×stage) + legSizing
2. `scripts/generate_hook_manifest.py` — Generates `manifests/hooks.json` from classification YAML + deployment JSONs + source parsing
3. `scripts/lint_hook_manifest.py` — Validates T4 vocabulary, T2 legSizing structure, P2 hookType consistency, completeness

**Generated output:**
- `manifests/hooks.json` — 120 hooks, 104 with staging addresses, 120 with name()/description(), correct subtypes

**Bugs found & fixed:**
1. **P2 lint failure**: `(rewards, claim)` rule only allowed NONACCOUNTING, but FluidClaimRewardHook/GearboxClaimRewardHook/YearnClaimOneRewardHook are OUTFLOW. Fixed: added OUTFLOW to allowed set.
2. **Subtype parsing bug**: Regex `HookSubTypes\.(\w+)` matched import path `HookSubTypes.sol` yielding `subtype=sol`. Fixed: iterate all matches, skip "sol".

**Validation:** All 120 hooks pass lint (T4, T2, P2, completeness). Spot-checked subtypes — all correct (ERC4626, SWAP, LOAN, BRIDGE, CLAIM, etc.).

### Phase 13: Deploy Script Bug Fix — Missing V2 Across Hook & Adapter Checks

**Status**: COMPLETE

**Root Cause**: In `script/DeployV2Core.s.sol`, the `_checkHookContracts()` function checked V1 Across hooks but **never called `__checkContract`** for the V2 Across hooks (`AcrossSendFundsAndExecuteOnDstHookV2`, `ApproveAndAcrossSendFundsAndExecuteOnDstHookV2`). Similarly, `_checkAdapterContracts()` checked `AcrossV3Adapter` but never checked `AcrossV3AdapterV2`.

Since `__checkContract` increments both `deployed++` and `total++`, missing contracts were never counted in the total, so the check phase reported "87/87 deployed" instead of "87/90 deployed". The bash deploy script saw "all deployed" and skipped deployment entirely.

Additionally, `StargateAdapterV2` was being checked by `_checkAdapterContracts()` but was missing from the `adapterContracts` array and `expectedAdapters` count. The `AcrossV3AdapterV2` was in the expected count but never checked — these two errors were accidentally cancelling each other out for the total adapter count.

**Fixes applied to `script/DeployV2Core.s.sol`:**

1. **`_checkAdapterContracts()`** — Added `AcrossV3AdapterV2` check block (same pattern as `AcrossV3Adapter` but using `ACROSS_V3_ADAPTER_V2_KEY`)

2. **`_checkHookContracts()`** — Added check block for `ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_V2_KEY` and `APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_V2_KEY` (guarded by `availability.acrossV3AdapterV2`)

3. **`_getContractAvailability()`** — Fixed `adapterContracts` array from `string[4]` to `string[5]` to include `StargateAdapterV2`. Fixed `expectedAdapters` to start at 5 and decrement by 2 for missing Stargate (was only decrementing by 1).

**Verification**: `forge build` — Compiler run successful

**Impact**: After this fix, the check phase will correctly count V2 Across hooks and `AcrossV3AdapterV2` in the total, causing the deploy script to detect them as "not deployed" and proceed with deployment.

### Phase 14: Deploy Script Error Handling & Status Tracking Fixes

**Status**: COMPLETE

**Problem**: After Phase 13 fixed the Solidity check logic, running `deploy_v2_staging_prod.sh` still appeared to "not deploy" V2 Across contracts. The check phase now correctly reports missing contracts, but the deploy phase had two issues:

1. **No error handling after forge deploy** (`script/run/deploy_v2_staging_prod.sh` lines 775-790): If forge failed during deployment (e.g., require check failure, RPC error, gas issue), the bash script continued silently, printed "completed successfully", and the output JSON was never updated. This masked any deployment failures.

2. **Missing `_saveContractStatus` for already-deployed contracts** (`script/DeployV2Base.s.sol` line 119-124): When `__deployContract` found a contract already deployed on-chain, it exported the address but didn't call `_saveContractStatus`, causing inconsistent status tracking between `allContractNames` and `contractAddresses`.

**Fixes applied:**

1. **`script/run/deploy_v2_staging_prod.sh`** — Added forge deploy exit code checking:
   - Captures `$?` after forge deploy command
   - On failure: prints detailed error with common causes, restores backup JSON, adds to `FAILED_DEPLOY_NETWORKS` array, continues to next network
   - Added `FAILED_DEPLOY_NETWORKS` array declaration
   - Updated deployment summary to show failed networks
   - Script now exits with code 1 if any networks failed deployment
   - On success: existing behavior preserved

2. **`script/DeployV2Base.s.sol`** — Added `_saveContractStatus(chainId, contractName, true, predictedAddr)` in `__deployContract` for the already-deployed code path (line 119-124). This ensures all processed contracts are tracked in `allContractNames` and `contractDeploymentStatus`, enabling consistent status reporting and output file generation.

**Verification**: `forge build` — 0 errors, `bash -n` — syntax OK

## Remaining Amendments (NOT YET DONE)
- **A4**: OMS lockstep — sizing from on-chain truth (OMS-side work, not hook code)
