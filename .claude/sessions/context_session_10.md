# Session 10: DETH Oracle — Spec + Implementation + E2E + Security Review

## Status: Security Review Complete — F-04 and F-07 fixes applied, deployment scripts updated, config simplified

## Security Review (2026-05-13)

Full security report: `specs/security-reports/2026-05-13-deth-yield-source-oracle.md`

**Verdict:** PASS (0 P0, 0 P1, 5 P2, 5 P3)

### Fixes Applied:
1. **F-07 (Constructor Validation):** Added `ZERO_ADDRESS()` custom error and `if (foundation_ == address(0)) revert ZERO_ADDRESS()` in constructor. Tests updated to use `address(1)` instead of `address(0)` where FOUNDATION is not needed.
2. **F-04 (Single-Pass Loop):** Replaced double `_getPendingRedemptionValue` call in `getTVLByOwnerOfShares` with a single `_getPendingRedemptionValueForTwo` that checks both `ownerOfShares` and `FOUNDATION` in one loop iteration. This halves external calls (from ~800 to ~400 worst case).

### Outstanding P2 Items (Not Fixed — Need Verification):
- **F-01:** FOUNDATION TVL attributed to all queried owners (documented, not enforced)
- **F-02:** Silent TVL truncation at 200 requests (consider newest-first scan)
- **F-03:** Machine.convertToAssets() donation attack vector — **VERIFY Machine uses internal accounting**
- **F-05:** Pending share valuation mismatch — **VERIFIED CORRECT**: AsyncRedeemer stores an asset amount at request time, but the actual fulfillment recalculates at current PPS via `Machine.redeem` → `Machine._convertToAssets`. Our `convertToAssets(pendingShares)` at current PPS is the accurate valuation.

## Overview
Created and implemented a DETHYieldSourceOracle — a custom yield source oracle for Dialectic's DETH/Machine vault. The oracle extends AbstractYieldSourceOracle, receives AsyncRedeemer as `yieldSourceAddress`, and routes pricing to Machine's convertToAssets/convertToShares. TVL includes pending async redemption value via NFT request scanning.

## Architecture: Fully Dynamic Resolution

All address resolution is **dynamic** — the oracle has no immutable state beyond `SUPER_LEDGER_CONFIGURATION` (from base class). A single oracle instance can serve multiple AsyncRedeemers.

Discovery chain at each call:
```
yieldSourceAddress (AsyncRedeemer) → .machine() → Machine → .shareToken() → DETH token
```

Internal helper `_resolve(yieldSourceAddress)` returns `(machineAddr, shareToken)` to avoid redundant calls within a single function.

**Tradeoff:** Higher gas per call (~2-3 external calls for resolution) vs flexibility to serve any AsyncRedeemer without redeployment.

## On-Chain Verification Findings

Key discoveries from mainnet fork testing that changed the spec:

| Function | Contract | Available? | Notes |
|----------|----------|-----------|-------|
| `convertToAssets(uint256)` | Machine | YES | ~1.009 WETH/DETH |
| `convertToShares(uint256)` | Machine | YES | ~0.991 DETH/WETH |
| `shareToken()` | Machine | YES | Returns DETH address |
| `accountingToken()` | Machine | YES | Returns WETH address |
| `lastTotalAum()` | Machine | YES | ~2970 WETH (replaces totalAssets) |
| `decimals()` | Machine | **NO** | Not exposed — use DETH token |
| `totalAssets()` | Machine | **NO** | Not exposed — use lastTotalAum() |
| `getShares(uint256)` | AsyncRedeemer | YES | Returns locked DETH for request |
| `nextRequestId()` | AsyncRedeemer | YES | Upper bound of request range |
| `lastFinalizedRequestId()` | AsyncRedeemer | YES | Lower bound of pending range |
| `ownerOf(uint256)` | AsyncRedeemer | YES | ERC-721 NFT owner |
| ERC721Enumerable | AsyncRedeemer | **NO** | Must scan by ID range |

## Design Decisions (Updated from Spec)

1. **Fully dynamic resolution** → No constructor params beyond superLedgerConfiguration. All addresses derived from yieldSourceAddress at call time.
2. **decimals()** → resolves via `_resolve(yieldSourceAddress)` → `IERC20Metadata(shareToken).decimals()`
3. **getTVL()** → uses `Machine.lastTotalAum()` (not totalAssets which doesn't exist)
4. **Pending redemption tracking** → scan `lastFinalizedRequestId+1` to `nextRequestId-1`, use `getShares()` + `ownerOf()`, convert via `convertToAssets()`
5. **MAX_PENDING_REQUESTS = 200** → bounds iteration to prevent DoS
6. **R2 try/catch** wraps all pending enumeration calls AND final convertToAssets for graceful degradation
7. **`_getPendingRedemptionValue`** takes pre-resolved `machineAddr` param to avoid double-resolution

## Security Fixes Applied

- **F-04**: Added staleness warning NatSpec to `getTVL()`
- **F-07**: Eliminated redundant `shareToken()` call (now dynamic, resolved once per call via `_resolve`)
- **F-08**: Wrapped final `convertToAssets(totalPendingShares)` in try/catch for R2 graceful degradation
- **F-11**: Fixed import path to `@openzeppelin/contracts/interfaces/IERC20Metadata.sol`
- **F-01**: Resolved by design — no immutable asyncRedeemer to bypass; yieldSourceAddress IS the asyncRedeemer, used consistently throughout

## Deployment Scripts (Added)

DETH oracle and hooks have been added to the deployment pipeline:

### Oracle (via DeployV2Core)
- `DETHYieldSourceOracle` added to `ORACLE_CONTRACTS` in `regenerate_bytecode.sh`
- Oracle array in `DeployV2Core._deployOracles` expanded from 11 to 12
- Constructor takes `(superLedgerConfig, foundation)` — foundation from `configuration.dethFoundation`
- Conditional deployment: only deployed when `configuration.dethFoundation != address(0)`
- Added to `_checkOracleContracts` and `_verifySingleContract` verification

### Hooks (via DeployV2OtherHooks)
- 3 DETH hooks added: `RequestRedeemDETHHook`, `ApproveAndRequestRedeemDETHHook`, `ClaimAssetsDETHHook`
- `DETH_HOOK_CONTRACTS` array in `regenerate_bytecode.sh` → copies to `generated-bytecode-other/`
- `DETHHookAddresses` struct and `_deployDETHHooks` function in `DeployV2OtherHooks.s.sol`
- `runDETH(uint256,uint64)` entry point for standalone deployment
- Auto-deployed on mainnet only (`chainId == MAINNET_CHAIN_ID`) via `_deployAllHooks`
- DETH section added to `deploy_v2_other_hooks_staging_prod.sh` bash script
- No constructor args (all DETH hooks are parameterless)

### Configuration
- `address dethFoundation` field added to `ConfigBase.EnvironmentData` (single variable, same for all chains)
- Foundation set to `0x97b5e4a707A4D5AB4A58b2c93bc8d249a63Ff153` in `ConfigCore._setCoreConfiguration()`
- Hook key constants added to `ConstantsOtherHooks.sol`
- Oracle key constant added to `Constants.sol`

### Files Modified
- `script/run/regenerate_bytecode.sh` — Added DETH oracle + hooks
- `script/utils/Constants.sol` — Added `DETH_YIELD_SOURCE_ORACLE_KEY`
- `script/utils/ConstantsOtherHooks.sol` — Added DETH hook keys
- `script/utils/ConfigBase.sol` — Added `address dethFoundation` field
- `script/utils/ConfigCore.sol` — Set DETH foundation to `0x97b5e4a707A4D5AB4A58b2c93bc8d249a63Ff153`
- `script/DeployV2Core.s.sol` — Added DETH oracle deployment, check, verification
- `script/DeployV2OtherHooks.s.sol` — Added DETH hooks deployment
- `script/run/deploy_v2_other_hooks_staging_prod.sh` — Added DETH deployment section

### Pre-deployment TODO
- ~~Set FOUNDATION address in ConfigCore.sol~~ ✅ Set to `0x97b5e4a707A4D5AB4A58b2c93bc8d249a63Ff153`

## Files Created/Modified

### Implementation
- `src/accounting/oracles/DETHYieldSourceOracle.sol` — Oracle contract (NEW, refactored to fully dynamic)
- `src/vendor/vaults/deth/IMachine.sol` — Extended with `convertToAssets`, `convertToShares`, `lastTotalAum` (MODIFIED)
- `src/vendor/vaults/deth/IDETHAsyncRedeemer.sol` — Extended with `getShares`, `nextRequestId`, `lastFinalizedRequestId` (MODIFIED)

### Tests
- `test/unit/accounting/DETHYieldSourceOracle.t.sol` — 61 unit tests (44 base + 3 multi-redeemer + 14 fuzz) + 8 invariant tests with inline mocks
- `test/unit/accounting/DETHYieldSourceOracle.fork.t.sol` — 24 fork integration tests
- `test/integration/deth/DETHOracleAndHooksE2E.t.sol` — 16 E2E tests combining oracle + hooks on mainnet fork (NEW)

### Specs & Reports
- `specs/deth-oracle/spec.md` — Pod leader spec
- `specs/deth-oracle/technical-spec.md` — Detailed technical spec
- `specs/deth-oracle/interview-notes.md` — Interview transcript
- `specs/deth-oracle/research/` — Research outputs (repo-analysis, best-practices, evm-security)
- `specs/security-reports/2026-05-12-deth-yield-source-oracle.md` — Security analysis report

## Test Coverage Summary

### Unit Tests (61 tests)
- Dynamic resolution through AsyncRedeemer → Machine → tokens
- `decimals()` — returns 18, uses yieldSourceAddress
- `getShareOutput()` — 1:1, non-1:1, zero, fuzz
- `getWithdrawalShareOutput()` — 1:1, ceil rounding, zero PPS, zero input, ceil vs floor fuzz
- `getAssetOutput()` — 1:1, non-1:1, zero
- `getPricePerShare()` — 1:1, non-1:1, reflects changes
- `getBalanceOfOwner()` — positive, zero, uses yieldSourceAddress
- `getTVL()` — returns lastTotalAum, reflects changes
- `getTVLByOwnerOfShares()` — held only, includes pending, multiple pending, filters owner, excludes finalized, only pending, zero position, PPS stability on request, non-1:1 rate, no pending range, skips burned NFTs, bounded iteration, capped at MAX_PENDING_REQUESTS (210 → 200), graceful when lastFinalizedRequestId reverts, graceful when nextRequestId reverts, skips request with broken getShares, **graceful when convertToAssets reverts on pending (F-08)**
- Multi-redeemer tests: different PPS, TVL isolation, different decimals (one oracle serving 2 AsyncRedeemers)
- Fuzz tests: varying PPS, TVL decomposition, PPS stability, owner isolation, round-trip shares→assets→shares, assets→shares→assets, withdrawal shares cover assets

### Invariant Tests (8 tests, 256 runs × 500 calls)
- TVL >= held value
- Balance matches DETH
- PPS always positive
- Withdrawal shares cover 1 ETH
- Ghost held matches balance
- Round-trip preservation
- Zero address TVL = 0
- TVL matches Machine AUM

### Fork Integration Tests (24 tests)
- Dynamic resolution against mainnet
- Decimals verification (18)
- PPS sanity check (0.9–2.0 range, matches Machine)
- Share/asset conversion matches Machine directly
- Round-trip preservation
- TVL matches Machine.lastTotalAum()
- TVL by owner with real pending requests
- Zero address TVL
- Withdrawal shares cover assets (ceil rounding)
- Batch methods consistency
- PPS derived from getAssetOutput consistency
- Fuzz tests against mainnet Machine

### E2E Integration Tests (16 tests) — NEW
Combined oracle + hooks on Ethereum mainnet fork:
- **Oracle sanity**: decimals, PPS matches Machine, TVL matches Machine, strategy balance, held-only TVL, zero address, round-trip, conversion consistency
- **Pending TVL tracking**: after requestRedeem TVL includes pending, multiple requests accumulate, filtered by owner (other account's pending excluded)
- **Full lifecycle**: hold → request via ApproveAndRequestRedeemDETHHook → verify pending TVL → simulated claim via ClaimAssetsDETHHook → verify final TVL
- **Real claim**: real claimAssets on finalized request #30 + hook WETH delta tracking
- **RequestRedeemHook variant**: oracle tracking with the simpler hook
- **Strategy rebalance**: 2 sequential partial redeems with oracle TVL verification at each step
- **Withdrawal share rounding**: ceil rounding verification against mainnet

Key E2E findings:
- Oracle TVL preserves value through request → pending transition (within 0.01% tolerance)
- Finalized requests (requestId <= lastFinalizedRequestId) are correctly excluded from pending scan
- Machine's `convertToAssets(N)` differs slightly from `mulDiv(N, convertToAssets(1e18), 1e18)` due to internal rounding — tests use `convertToAssets()` directly for exact assertions
- Real claim of request #30 yielded ~101.67 WETH for ~100.79 DETH of pending shares

## Production Issue: SuperVaultStrategy Missing onERC721Received

**Status: CONFIRMED — requires fix in v2-periphery**

The `SuperVaultStrategy` contract does NOT implement `onERC721Received()` and has no fallback function.
The DETH `AsyncRedeemer` uses `_safeMint` (confirmed by `0x150b7a02` selector in bytecode), which checks for `onERC721Received` when the recipient is a contract.

**Impact:** In production, when `RequestRedeemDETHHook` calls `requestRedeem(shares, strategy, minAssets)`, the AsyncRedeemer tries to `_safeMint` the NFT receipt to the strategy, which reverts because the strategy doesn't implement `IERC721Receiver`.

**Root cause:** The `SuperVaultStrategy` in v2-periphery (`src/SuperVault/SuperVaultStrategy.sol`) was not designed to receive ERC-721 NFTs. It has `receive() external payable {}` for ETH but no ERC-721 support.

**Fix needed in v2-periphery** (NOT v2-core):
```solidity
function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
    return IERC721Receiver.onERC721Received.selector;
}
```

**E2E test workaround:** Uses `vm.mockCall` to simulate the fix:
```solidity
vm.mockCall(
    strategy,
    abi.encodeWithSelector(bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))),
    abi.encode(bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")))
);
```

**Investigation details:**
- Strategy: `0x1199a6B2587Ed96446E76Dee3FB660bb8fCfd0b2` (EIP-1167 minimal proxy)
- Implementation: `0x770abd170404b8ed8182c04f380e567e647b457d` (42KB, SuperVaultStrategy)
- Storage layout: slot0=1e18 (PRECISION), slot1=SuperWETH vault, slot2=WETH, slot3=1500 (15% fee bps)
- NOT a Nexus/ERC-7579 smart account — it's a regular upgradeable contract
- All calls to `onERC721Received`, `supportsInterface(0x150b7a02)`, `accountId()`, `supportsModule(1)` revert with empty data

## Key Addresses
- DETH: `0x871aB8E36CaE9AF35c6A3488B049965233DeB7ed` (18 decimals)
- Machine: `0x0447D0aD7FD6a3409B48Ecbb9DDB075C1e11D735` (BeaconProxy → impl `0xa7F0A8Cc`)
- AsyncRedeemer: `0xE44b62dD3F6379D6d14c38081fe1499D1a56250F` (BeaconProxy → impl `0x9cfE91dA`)
- WETH: `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2`
- Risk Manager: `0x36BA7c92Cd68051fB304Bd4580C4A51c1d376532`
- SuperWETH Vault: `0xa036823b9A24F63c32553367bf181Ee04229c3AC` ("Flagship WETH SuperVault")
- SuperWETH Strategy: `0x1199a6B2587Ed96446E76Dee3FB660bb8fCfd0b2` (EIP-1167 → `0x770abd...`)
- Strategy Escrow: `0x41941100b24765ea0f31Bcc95094c5874D27c93d`
- FOUNDATION: `0x97b5e4a707A4D5AB4A58b2c93bc8d249a63Ff153` (same for all chains)

## E2E Test Fixes (Continued Session)

### Fix 1: Pre-existing WETH balance in `test_e2e_routedRedeem_viaSafeAddress`
**Problem:** Phase 4 assertion `WETH.balanceOf(strategy) == expectedWeth` failed because strategy already held ~364 WETH on mainnet.
**Fix:** Added `wethBefore = IERC20(WETH).balanceOf(strategy)` tracking before the claim, changed assertion to `wethBefore + expectedWeth`.

### Fix 2: Finalization simulation missing
**Problem:** Phase 5 assertion `oracleTVL == expectedWeth` failed (got ~100.9 instead of ~50.4) because oracle still counted pending NFT as unfinalised.
**Fix:** Added `vm.mockCall` to mock `lastFinalizedRequestId` returning `requestId` after simulated claim, so oracle's pending scan excludes the finalized request.

```solidity
vm.mockCall(
    ASYNC_REDEEMER,
    abi.encodeWithSelector(IDETHAsyncRedeemer.lastFinalizedRequestId.selector),
    abi.encode(requestId)
);
```

### Config Simplification
**Change:** Replaced `mapping(uint64 chainId => address dethFoundation) dethFoundations` with `address dethFoundation` in `ConfigBase.EnvironmentData`.
**Reason:** FOUNDATION address is the same across all chains — no need for per-chain mapping.
**Files changed:** `ConfigBase.sol`, `ConfigCore.sol`, `DeployV2Core.s.sol` (5 references updated)

---

## rFLR Claiming Hooks — Implementation Plan (2026-05-14)

**Full plan:** `.claude/doc/rflr-claiming-hooks/implementation-plan.md`

### Summary

Two NONACCOUNTING hooks for Flare mainnet (chain 14) to claim and withdraw rFLR rewards.

### Files to Create (5)

1. `src/vendor/flare/IRNat.sol` — Minimal interface (claimRewards, withdrawAll)
2. `src/hooks/claim/flare/ClaimRFLRHook.sol` — Claims rFLR rewards with fee handling (feeBPS/feeReceiver pattern from MerklClaimRewardHook)
3. `src/hooks/claim/flare/WithdrawRFLRHook.sol` — Converts rFLR to WFLR via withdrawAll(true)
4. `test/unit/hooks/claim/rflr/ClaimRFLRHookTest.t.sol` — Unit tests (Helpers base, vm.mockCall)
5. `test/unit/hooks/claim/rflr/WithdrawRFLRHookTest.t.sol` — Unit tests

### Files to Modify (4)

6. `script/utils/ConstantsOtherHooks.sol` — Add CLAIM_RFLR_HOOK_KEY, WITHDRAW_RFLR_HOOK_KEY, RNAT_FLARE, WFLR_FLARE
7. `script/DeployV2OtherHooks.s.sol` — Add RFLRHookAddresses struct, runRFLR(), _deployRFLRHooks(), add to _deployAllHooks
8. `script/run/regenerate_bytecode.sh` — Add RFLR_HOOK_CONTRACTS array + copy block
9. `script/run/deploy_v2_other_hooks_staging_prod.sh` — Add rFLR section (RFLR_SUPPORTED_CHAINS, bytecode check, deployment block)

### Key Deviations from Technical Spec

- ClaimRFLRHook does NOT implement ISuperHookInflowOutflow or ISuperHookContextAware (follows MerklClaimRewardHook pattern -- claim hooks don't have usePrevHookAmount)
- ClaimRFLRHook DOES set `asset = RNAT` in _preExecute and does balance tracking (unlike MerklClaimRewardHook which sets 0/0, because we need accurate outAmount for chaining)
- WithdrawRFLRHook does NOT implement ISuperHookContextAware (no usePrevHookAmount since it withdraws ALL)

### Key Addresses

- RNat (rFLR): `0x26d460c3Cf931Fb2014FA436a49e3Af08619810e` (Flare mainnet)
- WFLR (WNat): `0x1D80c49BbBCd1C0911346656B529DF9E5c2F783d` (Flare mainnet)

### Implementation Status: COMPLETE

All 9 files created/modified. `forge build` succeeds. 25/25 unit tests pass.

**Files Created:**
1. `src/vendor/flare/IRNat.sol` — Minimal IRNat interface (claimRewards, withdrawAll)
2. `src/hooks/claim/flare/ClaimRFLRHook.sol` — NONACCOUNTING + CLAIM, fee handling, balance snapshots
3. `src/hooks/claim/flare/WithdrawRFLRHook.sol` — NONACCOUNTING + CLAIM, WFLR balance tracking
4. `test/unit/hooks/claim/rflr/ClaimRFLRHookTest.t.sol` — 16 tests (constructor, build, fee, pre/post, inspect)
5. `test/unit/hooks/claim/rflr/WithdrawRFLRHookTest.t.sol` — 9 tests (constructor, build, pre/post, inspect)

**Files Modified:**
6. `script/utils/ConstantsOtherHooks.sol` — Added hook keys + contract addresses
7. `script/DeployV2OtherHooks.s.sol` — Added RFLRHookAddresses, runRFLR(), _deployRFLRHooks(), _deployAllHooks gate
8. `script/run/regenerate_bytecode.sh` — Added RFLR_HOOK_CONTRACTS array + copy block + summary
9. `script/run/deploy_v2_other_hooks_staging_prod.sh` — Added RFLR support (chain check, bytecode check, deployment block)

**Remaining:** Regenerate bytecode, copy to locked folders, simulate staging deployment (requires Flare RPC)

### SuperVault Strategy Integration Test (2026-05-15)

**Status: COMPLETE — 4/4 tests pass**

Created `test/integration/flare/FlareRFLRSuperVaultE2E.t.sol` to verify RFLR hooks work when executed through a SuperVault strategy's `executeHooks()` flow.

**Approach:** MockSuperVaultStrategy replicates `_processSingleHookExecution()` from `SuperVaultStrategy.sol`:
```
setExecutionContext(address(this)) → build(prevHook, address(this), data) →
execute each Execution via .call() → resetExecutionState(address(this)) →
getOutAmount(address(this)) → slippage check
```

Key design: The strategy IS the account — it holds tokens and is `msg.sender` for all calls. This satisfies `preExecute`/`postExecute`'s `msg.sender == account` check and `resetExecutionState`'s `onlyLastCaller` modifier.

**Test cases:**
1. `test_claimRFLR_throughStrategy` — Strategy executes ClaimRFLRHook, verifies rFLR minted to strategy, outAmount correct
2. `test_withdrawRFLR_throughStrategy` — Strategy has rFLR, executes WithdrawRFLRHook, verifies WFLR received
3. `test_claimThenWithdraw_throughStrategy` — Two hooks chained: claim rFLR → withdraw to WFLR, full lifecycle
4. `test_slippageCheck_reverts` — Strategy reverts when outAmount < minExpected

**Files created:**
- `test/integration/flare/FlareRFLRSuperVaultE2E.t.sol` — MockSuperVaultStrategy + MockRNat + 4 tests

No fork needed — tests use mock tokens, fast and deterministic (5.39ms total).
