# Aave V4 Idle MONEY_MARKET Lend/Redeem Hooks — Technical Specification

> **SUPERSEDED IN PART BY SUP-21254 AND THEN SUP-21263.** The header identity and the calldata length in
> this document describe the original SUP-21142 design. As implemented today:
>
> - offset 32 is the MARKET key `AaveV4ReserveKey.computeMarketKey(spoke, supplyReserveId, borrowReserveId)`,
>   NOT `computeReserveKey(spoke, reserveId)`, and it must be a REGISTERED market;
> - the body is **157 bytes** (SUP-21254 appended `borrowReserveId` to make it 189; SUP-21263 deleted that
>   word again), and offset 92 is now **`targetReserveId`** — the one reserve the op moves, which may be
>   EITHER leg of the header market;
> - membership of `targetReserveId` in the market is a **registry read** (`getMarketInfo`) performed in
>   `build` and `preExecute`, so the hooks take the registry as a constructor argument and an unregistered
>   market reverts `MARKET_NOT_REGISTERED` before any Spoke call;
> - **`inspect()` is `pure` and no longer authenticates the header** — it is a transformation API like the
>   three sizing views;
> - the market key is the SuperLedger key, and `AaveV4ReserveOracle` resolves it to the market's COLLATERAL
>   leg — which since SUP-21263 is NOT necessarily the reserve the op moved. See SECURITY.md §16.
>
> Everything else below — the one-mode-per-(account, reserve) guard, the reserve/underlying binding, the
> inspector's 92-byte shape and field order, and the fail-closed accounting allowlist (now market-granular
> and enforced at build) — still holds.

Ticket: SUP-21142. Branch: `cosmin-sup-21142-feature-add-aave-v4-idle-money_market-lendredeem-hooks`.
Planning notes: `.claude/sessions/context_session_sup21142.md` (local, git-ignored; not part of the PR).

## Overview & scope

Two new hooks, the Aave V4 twin of `MorphoLendHook` / `MorphoWithdrawHook` (SUP-21004 / SUP-21024):

| Hook | Spoke call | HookType | amountRoles | outAmount | outToken |
|---|---|---|---|---|---|
| `AaveV4LendHook` | `supply` only — never `setUsingAsCollateral` | INFLOW | `[IN / ASSETS]` | supplied-assets credited (1:1 identity) | the MOVED LEG's reserve key, `computeReserveKey(spoke, targetReserveId)` — SUP-21263; it is deliberately NOT the market key, which covers both legs and would let a cross-leg chain pass `expectedPrevToken` |
| `AaveV4RedeemHook` | `withdraw` only | OUTFLOW | `[IN / SHARES]` (1:1 identity) | underlying received | underlying |

Family `MONEY_MARKET`, protocol tag `aave_v4` (no new plan family; on-chain subtype stays `LOAN` like the Morpho
idle hooks — there is no `MONEY_MARKET` subtype constant and the family is the off-chain classification carried by
`hookType` + `amountRoles`).

NOT reused, by design: `AaveV4SupplyHook` / `AaveV4WithdrawHook` (LOAN PLEDGE / RELEASE — supply enables collateral),
`BaseAaveV4LoanHook` (209-byte LOAN layout), `BaseAaveV4LoanHookV2` (`_validateReserves` requires a borrow reserve).
Not modified: SuperExecutor / SuperDestinationExecutor / SuperExecutorBase, every LOAN base and leaf (bytecode proof
below). `src/vendor/aave-v4/IAaveV4Spoke.sol` gained one view (`getUserReserveStatus`) for the collateral-mode guard;
unused interface members do not reach LOAN bytecode (proven by the same test).

**Deployment wiring** was deferred during implementation (PR #1018 as opened has none) and added on 2026-09-28 on
request: `DeployV2OtherHooks` set + entrypoint, `Constants` keys, `regenerate_bytecode.sh` / deploy-script entries,
locked artifacts, `hook-enrichment.yaml` / `hook-classification.yaml` entries, regenerated manifests. See "Deployment"
below. **The hooks ARE deployed** (18 prod / 10 staging chains), and SUP-21263 re-deploys them at new
addresses — see "Deployment".

## Problem statement

The Base Equities Hub has a supply-only USDC use for vaults/aggregators, separate from the MAG-7 collateralised
borrow. Idle USDC must be a deposit/withdraw vault-main, not a borrower hop. V4 spokes have no share token, the
Superform supply oracle (now the merged `AaveV4ReserveOracle`; `AaveV4SupplyYieldSourceOracle` was its SUP-20854
predecessor) is identity PPS in asset units, and pricing fail-closes Aave `MONEY_MARKET` until idle positions are
keyed per position rather than by the spoke singleton — a **reserve key** originally, a registered **market key**
since SUP-21254.

## Design

### Inheritance

```
BaseHook -> BaseLoanHook -> BaseLoanHookV2 -> BaseAaveV4MoneyMarketHook (new, abstract) -> AaveV4LendHook
                                                                                        -> AaveV4RedeemHook
```

`BaseLoanHookV2` supplies strict decoding (`_decodeStrictBool`, `INVALID_DATA_LENGTH`, `INVALID_BOOL_VALUE`), the
exact-delta settlement helpers (`_balanceIncrease/_balanceDecrease`, `DELTA_MISMATCH`, `NEGATIVE_BALANCE_DELTA`),
the previous-hook pipe (`_resolvePrevHookOutput`, `PREV_TOKEN_MISMATCH`) and the sizing-interface plumbing.
`BaseLoanHook` fixes `HookType.NONACCOUNTING` for the loan family; `hookType` is plain storage on `BaseHook`, so
`BaseAaveV4MoneyMarketHook` reassigns it after construction (INFLOW / OUTFLOW) — the same trick as
`BaseMorphoMoneyMarketHook`, with zero effect on any LOAN sibling. **ONE constructor arg since SUP-21263: the
`AaveV4ReserveRegistryV2` address** (the Spoke still comes from calldata). It is the only constructor dependency in
the Aave V4 hook family, and `DeployV2Core` must therefore have run on a chain before these hooks can be deployed
there.

### Header identity = a REGISTERED market key (SUP-21254 / SUP-21263; reserve key originally)

Since SUP-21143 every Aave V4 LOAN hook (V1 six, composite V2, standalone V2) carries the same header rule through the shared
`src/libraries/AaveV4ReserveKey.sol` (the single definition; the idle base and `AaveV4ReserveRegistry.computeReserveKey` now delegate to it, `RESERVE_KEY_MISMATCH` is
declared there once; fuzz-pinned against the registry in the LOAN suites): `yieldSource` @32 = key of the op's primary reserve. The
idle base was touched only to delegate (its own `_computeReserveKey` copy removed) — idle artifacts re-pinned before any deployment.

**AS IMPLEMENTED (SUP-21263), superseding the paragraph that follows:** offset 32 carries
`AaveV4ReserveKey.computeMarketKey(spoke, supplyReserveId, borrowReserveId)` and must be a REGISTERED market. The
hooks resolve it through `IAaveV4MarketRegistry.getMarketInfo` in `build` and `preExecute` — NOT a pure local
recomputation, and NOT in `inspect`, which is pure and authenticates nothing. An unregistered header fails
`MARKET_NOT_REGISTERED`; a body naming a different spoke fails `MARKET_KEY_MISMATCH`; a `targetReserveId` that is
neither leg fails `RESERVE_NOT_IN_MARKET`.

_Historical (SUP-21142), kept for roots signed under the old rule:_ offset 32 carried
`AaveV4ReserveRegistry.computeReserveKey(spoke, supplyReserveId)` =
`address(uint160(uint256(keccak256(abi.encode(spoke, reserveId)))))`. The hooks recomputed it locally (pure, no
registry call) and pinned it inside the decoder, so `build`, `preExecute` **and** `inspect` failed closed with
`RESERVE_KEY_MISMATCH` on any disagreement (including the LOAN-style "spoke in the header"). SuperExecutorBase posts
INFLOW / OUTFLOW keyed by that address; the oracle resolves the same key through the registry. Keying by the Spoke
would collapse every reserve of a spoke, and every LOAN position on it, onto one accounting slot
(`group_bindings_by_position` fail-closed in pricing).

### Calldata (exact 157 bytes — SUP-21263)

| offset | field | validation |
|---|---|---|
| 0 | `yieldSourceOracleId` (bytes32) | zero → `ORACLE_ID_NOT_VALID` |
| 32 | `yieldSource` = REGISTERED market key | zero → `ADDRESS_NOT_VALID`; not a registered market → `MARKET_NOT_REGISTERED`; body spoke ≠ the market's → `MARKET_KEY_MISMATCH` (build / preExecute, view) |
| 52 | `underlying` | zero → `ADDRESS_NOT_VALID`; ≠ `getReserve(id).underlying` → `TOKEN_RESERVE_MISMATCH` (build / preExecute, view) |
| 72 | `spoke` | zero → `ADDRESS_NOT_VALID`; the only call target / approve spender; `getUserReserveStatus(id, account).isUsingAsCollateral` must be false → else `RESERVE_IS_COLLATERAL` (build / preExecute, view) |
| 92 | `targetReserveId` (uint256) | must equal the market's `supplyReserveId` or `borrowReserveId` → else `RESERVE_NOT_IN_MARKET` (build / preExecute, view) |
| 124 | `amount` (uint256) | lend: underlying wei, 0 / max → `AMOUNT_NOT_VALID`; redeem: 1:1 share wei, 0 → `AMOUNT_NOT_VALID`, > supplied (incl. max) = full withdrawal |
| 156 | `usePrevHookAmount` | strict `0x00` / `0x01`, else `INVALID_BOOL_VALUE` |

Any other length → `INVALID_DATA_LENGTH` on every entry point (build, inspect, decodeAmounts,
replaceCalldataAmounts, decodeUsePrevHookAmount). The sizing views authenticate nothing beyond exact length and canonical bool — they are transformation
APIs. Since SUP-21263 the header is authenticated at **build / preExecute only** — `inspect` is pure and
authenticates nothing (PR #1020 review P3-1,
`test_Idle_SizingApis_TransformationOnly_ExecutionAuthenticatesHeader`).

NOTE that 157 is also the pre-SUP-21254 length, so length alone no longer distinguishes this revision from
the original reserve-keyed one; the HEADER does. A stale reserve-keyed 157-byte body reverts
`MARKET_NOT_REGISTERED` here (a reserve key can never be registered as a market — the registry's
`KEY_NAMESPACE_COLLISION` guard), and a new body sent to a SUP-21254 hook reverts `INVALID_DATA_LENGTH`.

`inspect()` = `marketKey ‖ spoke ‖ underlying ‖ targetReserveId` (92 bytes, key first — leaves are hashed over
these raw bytes). Identical for lend and redeem on the same market AND leg; the target word is what keeps the
two legs of one market distinguishable, so one signed leaf cannot authorise moving the other asset.
Unchanged when only amount / flag / oracle id change.

### Execution sequences

Lend (4 provider calls, wrapped by BaseHook's pre/post): `underlying.approve(spoke, 0)`,
`underlying.approve(spoke, amount)`, `spoke.supply(reserveId, amount, account)`, `underlying.approve(spoke, 0)`.
**No `setUsingAsCollateral`.**

Redeem (1 provider call): `spoke.withdraw(reserveId, amount, account)`; `type(uint256).max` passes straight
through as a full withdrawal. No approvals, no collateral toggle, no repay.

`onBehalfOf` is always `account`. The Spoke path has no callbacks; approvals are reset before and after.

**One mode per (account, reserve).** The Spoke's collateral flag is per user and reserve, not per deposit. A reserve the account
has enabled as collateral (LOAN pledge, position manager, or direct call) is refused by BOTH idle hooks on build and preExecute
(`RESERVE_IS_COLLATERAL`, one staticcall to `getUserReserveStatus`): otherwise an idle supply would become seizable collateral,
the redeem could hit the Spoke's health-factor check, and the oracle balance would mix NONACCOUNTING LOAN supply with
ledger-tracked idle supply. Added in the security review (P2-1); `getUserReserveStatus` was added to the vendored interface
(LOAN bytecode unchanged — proven by test). **Direction:** this guard is idle-side. The reverse is guarded by the SUP-21141
standalone hooks (`AaveV4SupplyHookV2` refuses an un-flagged position, `AaveV4WithdrawHookV2` requires the flag); the frozen V1
`AaveV4SupplyHook` / `AaveV4SupplyAndBorrowHook` and the composite V2 OPEN carry the same guard since SUP-21143 (recompiled), and
every recompiled LOAN withdraw leg (RELEASE, CLOSE, V1 Withdraw / RepayAndWithdraw) requires the flag (`RESERVE_NOT_COLLATERAL`); only the pre-SUP-21143 deployed addresses and a manual `setUsingAsCollateral(true)` do not, so the OMS allow-list must never pair an idle leaf with those old addresses or a manual flag toggle
leaf for one (account, spoke, reserveId) (PR #1018 review P3-1). **Debt:** lend additionally refuses a reserve the account already
borrows (`RESERVE_IS_BORROWED`, same staticcall) — same-asset supply + debt is pointless and, under SUP-21148 keying, would put a
ledger-tracked supply and a debt on one key; redeem keeps only the collateral rule so an exit is never trapped (review P3-2).

### Accounting (identity PPS)

Let `d` = reserve decimals, `pps = 10^d`, `K` = the ledger key (the registered MARKET key since SUP-21254; a
reserve key when this section was written).

- **Lend**: wallet spend must equal the resolved `amount` exactly (`DELTA_MISMATCH` otherwise — fee-on-transfer /
  partial pulls are rejected). `outAmount = getUserSuppliedAssets(after) − (before)` — the SAME read the oracle
  performs, so ledger "shares" are in oracle units. Aave rounds the credited position DOWN by a wei-scale amount
  bounded by the Hub index (two floors; 1 wei at today's index, observed 1000e6 → 999_999_999, a few wei as the index
  grows): the credit is never equated with the spend, and a credit of 0 (1-wei supply) reverts `AMOUNT_NOT_VALID`. `asset = underlying`, `outToken = K`.
  Ledger: `shares[K] += credited; cost[K] += credited` (pps = 10^d) — the ledger position equals
  `oracle.getBalanceOfOwner(K, user)`.
- **Redeem**: wallet receipt must equal `min(amount, suppliedBefore)` exactly (`DELTA_MISMATCH`); nothing supplied →
  `AMOUNT_NOT_VALID`. `usedShares = suppliedBefore − suppliedAfter` (position consumed; partial withdraws may consume
  `amount ± 1` wei through share rounding, so it is never equated with the receipt). `outAmount = received`,
  `asset = outToken = underlying`.
  Ledger: full redeem right after a lend nets `shares[K]` and `cost[K]` to exactly 0. After accrual, `usedShares`
  exceeds the accumulator and is capped (`UsedSharesCapped`), clearing the slot.
- **feePercent = 0 is an operational invariant** for the supply oracle (specs/aave-v4-oracles/technical-spec.md).
  `BaseLedger._processOutflow` skips fee computation entirely when `feePercent == 0`, so `FEE_NOT_SET` is unreachable
  and the executor transfers nothing. Should a fee ever be configured, it would be charged in `asset` (the
  underlying), never in the codeless key. Stronger still: with identity PPS the outflow math can never observe profit
  (partial redeem: cost basis ≈ receipt; full redeem after accrual: `usedShares` capped and re-priced to the
  accumulator), so a non-zero `feePercent` would also charge nothing — enabling performance fees needs a shares-PPS
  oracle version, not a config change (review P3-2).
- The supply oracle and `AaveV4DebtOracle` must never share a ledger (accumulators are keyed `(user, yieldSource)`).

### Chaining

- Lend `outToken` is the reserve key (codeless), mirroring `MorphoLendHook`: asset-denominated downstream hooks
  that verify the previous output token fail closed (`PREV_TOKEN_MISMATCH`); legacy consumers without a token check
  would receive the supplied-assets figure (≤ 1 wei below the spend). Chain only into `AaveV4RedeemHook`.
- Redeem with `usePrevHookAmount` requires the previous output token to be the reserve key (i.e. a lend); a raw
  asset output (swap) cannot feed the share slot. The prev pipe rejects `0` / `max`, so a chained full withdrawal is
  impossible — use an explicit `max` in calldata.

## Collateral-flag evidence (live Spoke ABI, verified)

The vendored `IAaveV4Spoke` has no collateral view. The real Spoke (Base MAG7 proxy `0x17905Db0…7B8D` →
impl `0x81a73c28…3b19`; Ethereum Main Spoke `0x94e7…c485` answers the same selectors) exposes
`getUserReserveStatus(uint256 reserveId, address user) returns (bool isUsingAsCollateral, bool isBorrowing)`.
Ordering pinned by probes at Base block 51_778_000:

| account | reserve | position | status |
|---|---|---|---|
| BORROWER `0x26D5…141F` | 0 (AAPLc) | collateral, no debt | `(true, false)` |
| BORROWER | 7 (USDC) | supplied + 50.03 USDC debt, not collateral | `(false, true)` |
| WHALE `0x9e37…E647` | 7 (USDC) | 84,700 USDC idle supply, no debt | `(false, false)` |
| WHALE | 0, 6 | collateral | `(true, false)` |

`getUserAccountData(WHALE).activeCollateralCount == 7` (the equities; USDC not counted).
`eth_call --from WHALE`: `withdraw(7, 1e6)` → `(1e6, 1e6)` and `withdraw(7, max)` → `(84_699_992_300,
84_700_000_001)` — a non-collateral idle supply withdraws partially and fully with **no** `setUsingAsCollateral(false)`
call. Fork tests declare a test-local `IAaveV4SpokeStatus` and assert `(false, false)` before and after a lend,
zero `SetUsingAsCollateral` events in the userOp logs, and `vm.expectCall(spoke, setUsingAsCollateral, 0)`.

## Security / attack surface

- Reentrancy: no Spoke callbacks on supply/withdraw; hooks hold no funds; pre/post mutexes from BaseHook.
- Approvals: reset to 0 before and after the supply; exact amount approved; Spoke is the only spender.
- Token behaviour: the Hub's own balance assertion rejects fee-on-transfer tokens on supply; the hook's strict receipt
  check rejects them on redeem (the lend-leg spend check alone would pass a recipient-side fee). Registry runbook rule:
  never register a fee-on-transfer reserve (review P3-1).
- Liquidity shortfall: `Hub.remove` has no partial fill, so a redeem above available liquidity (including `max` under
  stress) reverts the whole userOp — liveness only, funds stay on Aave. Bundler/OMS sizing must read Hub liquidity before
  choosing `amount`; alert on utilisation for registered reserves (review P2-2, accepted).
- Unregistered header: **SUP-21263 moved this check INTO the hooks** — `getMarketInfo` reverts
  `MARKET_NOT_REGISTERED` at build, before any Spoke call, and the hooks are no longer registry-agnostic. The
  paragraph below describes the superseded path, where the oracle reverted `RESERVE_NOT_REGISTERED` in
  `_updateAccounting`, so the userOp reverts (fail-closed allowlist; registration is an ops precondition —
  Base staging already has all 8 MAG7-spoke reserves registered).
- Collateral-flagged reserve: refused outright by both hooks (`RESERVE_IS_COLLATERAL`, see Design); neither hook ever
  toggles the flag. Borrowed reserve: lend refused (`RESERVE_IS_BORROWED`), redeem allowed.
- Ledger shares are not NAV: once yield accrues, a redeem above the ledger principal clears the accumulator while the
  remainder stays supplied; pricing / NAV read `getUserSuppliedAssets` (oracle NatSpec, review P3-3).
- Node-native equity tokens (Base ids 0-6, `0xEF` code): asset-agnostic hooks, but tests and registration target
  USDC only.
- `ISuperHookLoans` getters (non-virtual on BaseLoanHook): `getLoanTokenAddress` (offset 52) is the underlying;
  `getCollateralTokenAddress` (offset 72) returns the SPOKE and its balance getter would revert. Never called by hooks
  or executor and never advertised via ERC-165 (asserted). Same accepted shape as `EulerRepayHook`.

## Acceptance criteria → tests

| Criterion | Where proven |
|---|---|
| Lend calls `supply`, never `setUsingAsCollateral` | unit `test_Build_Lend_FourExecutions_NeverEnablesCollateral`, `test_Lend_Cycle_*` (`collateralCalls == 0`); fork `test_Lend_SupplyOnly_CollateralFlagNotFlipped` (ETH + Base): status `(false,false)`, 0 events, `expectCall(…, 0)` |
| Redeem calls `withdraw` only; no collateral-disable needed | unit `test_Build_Redeem_SingleWithdraw_MaxPassesThrough`; fork full/partial redeems with 0 collateral events; live probes above |
| One mode per (account, reserve): collateral-flagged reserve refused | unit `test_RevertIf_ReserveIsCollateral`; fork `test_CollateralFlaggedReserve_IsRefusedByBothHooks` (ETH) |
| Exact 157-byte calldata, wrong length reverts; oracle id @0, registered market key @32, Spoke not `yieldSource` | unit `test_Decode_RevertIf_WrongLength`, `test_Build_RevertIf_MarketNotRegistered`, `test_Build_RevertIf_SpokeIsNotTheMarketSpoke`; sizing `test_*_AaveV4Idle` |
| `targetReserveId` must be one of the market's two legs; either leg is legal | unit `test_Build_Lend_BorrowLegTarget_SuppliesTheBorrowLeg`, `test_Build_RevertIf_TargetNotAMarketLeg`, `testFuzz_TargetMustBeOneOfTwoLegs`; fork `test_Base_IdleUSDC_UnderEquityCollateralMarket_DoesNotRevert` |
| `extractYieldSource()` is a REGISTERED market key naming the body's spoke, or revert (SUP-21263; was `== computeReserveKey(spoke, id)`) | unit `test_Build_RevertIf_MarketNotRegistered`, `test_Build_RevertIf_SpokeIsNotTheMarketSpoke`, `test_PreExecute_RevertIf_SpokeIsNotTheMarketSpoke`; fork `test_Lend_RevertIf_HeaderKeyMismatch` |
| `inspect()` = marketKey + spoke + underlying + targetReserveId, stable under amount changes, DIFFERENT per leg | unit `test_Inspect_ShapeAndStability`, `test_Inspect_ChangesWithReserveSpokeOrUnderlying`, `test_Inspect_IsPure_AndCommitsTheTargetLeg` |
| INFLOW / ASSETS-in lend, OUTFLOW / SHARES-in redeem; executor untouched | unit `test_HookTypes_IdleFlipsLoanStays`, `test_AmountRoles`; sizing `test_AmountRoles_*_AaveV4*`; `git diff` of `src/executors` is empty |
| LOAN V1/V2 bytecode unchanged by this ticket (SUP-21143 later re-pinned the 12 LOAN hooks and, via the shared `AaveV4ReserveKey` library, the idle pair as well) | `AaveV4LoanBytecodeUnchanged.t.sol` (`test_IdleHooks_BytecodePinned`; LOAN artifacts pinned) |
| Fork tests on a supply-only reserve + collateral bitmap proof | `AaveV4IdleHooksFork.t.sol` (Ethereum Main Spoke USDC 7, block 24_884_274, 9 tests), `AaveV4IdleHooksBaseFork.t.sol` (Base MAG7 USDC 7, block 51_778_000, 3 tests) — real SuperExecutor + SuperLedger + oracle at the reserve key; security report `specs/security-reports/2026-09-28-aave-v4-idle-hooks.md` |
| Ledger nets with identity PPS, fee 0 | fork `test_Lend_Then_RedeemFull_LedgerNets`, `_RedeemPartial_ExactAmount`, `_Warp_RedeemFull_YieldNotTaxed`, `test_Chain_Lend_Then_Redeem_UsePrev` |
| Unregistered key fails closed | fork `test_UnregisteredKey_FailsClosed` (GHO reserve 13 → `RESERVE_NOT_REGISTERED`) |
| Deploy keys for Ethereum and Base; `latest.json` after deploy | wired (see below); deploy + `latest.json` pending |

## Deployment (wired 2026-09-28; deployed; re-deployed by SUP-21263)

`AAVE_V4_LEND_HOOK_KEY` / `AAVE_V4_REDEEM_HOOK_KEY` in `script/utils/Constants.sol`; `AaveV4IdleHookAddresses` set,
`_deployAaveV4IdleHooksSet` and the `runAaveV4Idle(uint256,uint64)` entrypoint in `DeployV2OtherHooks.s.sol`. **CHAIN-GATED SINCE SUP-21263** (it superseded the no-gate decision of 2026-09-28): the hooks now take the
`AaveV4ReserveRegistryV2` address as a constructor argument, derived in `_deployAaveV4IdleHooksSet` via
`__computeContractAddress`, so they can only be deployed where `DeployV2Core` has already run. The targeted
`runAaveV4Idle` REVERTS on a missing registry (`AAVE_V4_REGISTRY_NOT_DEPLOYED`); `_deployAllHooks` skips the pair
with a log instead, so a new-chain bring-up does not lose every other hook family. Addresses stay uniform per
environment because the registry address is identical on every chain within an env. The Aave V4 V2 composite set (OPEN / REPAY / CLOSE) is now deployed on every network too (was mainnet-only), so
REPAY exists wherever BORROW does; the V1 set stays mainnet-only (legacy). Both names in `AAVE_V4_HOOK_CONTRACTS` (`regenerate_bytecode.sh`) and `AAVE_V4_HOOKS`
(`deploy_v2_other_hooks_staging_prod.sh`); artifacts in `script/generated-bytecode/`, `script/locked-bytecode/` (read for
every env by `__getOtherHooksBytecode`) and `script/locked-bytecode-dev/`, pinned by `test_IdleHooks_BytecodePinned`;
`tooling/hook-enrichment.yaml` tags `[aave-v4]` + `amountMeta` (`Lend: [{IN, ASSETS}]`, `Redeem: [{IN, SHARES}]`);
`tooling/hook-classification.yaml` (`lend` / `withdraw`, instant, `[sized]`); `manifests/hooks.json` and
`hook-sizing-manifest.json` regenerated (generator now defaults subtype LOAN for `BaseAaveV4MoneyMarketHook` leaves).
Addresses have moved TWICE since this was written (SUP-21254, then SUP-21263's constructor arg + layout). The
superseded addresses stay valid for roots signed under the old rules, so treat any address in this document as
historical and read the committed `script/output/**/…-latest.json` records for the live ones.
Deploy: `TARGET_FAMILY=AaveV4Idle ./script/run/deploy/deploy_v2_other_hooks_staging_prod.sh <staging|prod> deploy v2-supervaults`
(all configured networks), then commit the resulting `…-latest.json` keys. Per-chain prerequisites, as of SUP-21263:
`AaveV4ReserveRegistryV2` deployed (the constructor argument) with the MARKET — not merely the reserve legs —
registered; `AaveV4ReserveOracle` registered in `SuperLedgerConfiguration` with **feePercent 0** on its own ledger
(load-bearing, see SECURITY.md §16 item 4); exactly ONE market key per `(spoke, reserveId)` designated as that
reserve's idle settlement key, with the OMS allow-list never signing an idle leaf naming another; and the header
oracle id is the derived config id `keccak256(abi.encodePacked(salt, configSetter))`.

## Follow-ups (not this ticket)

Erebor YS type `aave_v4`, CreateHook, Superbundler natspec/S3, snapshotd kind, pricing idle PPS / lifting the
fail-closed gate, the deploy itself (see Deployment).
