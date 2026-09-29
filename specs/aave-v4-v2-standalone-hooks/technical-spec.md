# Aave V4 V2 Standalone PLEDGE / BORROW / RELEASE Hooks — Technical Specification

Ticket: SUP-21141. Branch `cosmin-sup-21141-feature-add-aave-v4-v2-standalone-pledge-borrow-and-release`, stacked on
PR #1018 (SUP-21142). Plan of record: `.claude/sessions/context_session_sup21141.md`.

## 1. Overview & scope

Three V2 standalone borrower hooks completing the Aave V4 LOAN op set that SUP-20796 left to V1:

| Op | Contract | Spoke calls | Subtype / HookType | amountRoles | outAmount / outToken |
|---|---|---|---|---|---|
| PLEDGE | `AaveV4SupplyHookV2` | `supply` + `setUsingAsCollateral(true)` | LOAN / NONACCOUNTING | `[IN/TOKEN]` | 0 / collateralToken (terminal) |
| BORROW | `AaveV4BorrowHookV2` | `borrow` | LOAN / NONACCOUNTING | `[OUT/TOKEN]` | loan-token wallet delta / loanToken |
| RELEASE | `AaveV4WithdrawHookV2` | `withdraw` only | LOAN / NONACCOUNTING | `[OUT/TOKEN]` | collateral wallet delta / collateralToken |

Twins of `MorphoSupplyHookV2` / `MorphoBorrowHookV2` / `MorphoWithdrawCollateralHookV2` (SUP-21021). Erebor family LOAN,
schema 2, `compatible_protocols: [aave_v4]` (registration after deploy). V1 `AaveV4SupplyHook/BorrowHook/WithdrawHook`
and the shipped V2 OPEN/REPAY/CLOSE are not renamed, not modified, and their bytecode was proven unchanged by SUP-21141 (later re-pinned by SUP-21143, §8.1). The idle
MONEY_MARKET pair (SUP-21142) is a separate sibling; RELEASE is NOT the idle redeem.

**Deployment wiring is in place** (2026-09-28, on request; §8) — the hooks are not yet deployed.

## 2. Problem statement

OMS already composes LOAN aux around any vault-main (OPEN/BORROW/RELEASE before a deposit main; CLOSE/REPAY/PLEDGE after
a withdrawal-like main), and borrower-only Equities Hub plans need the six ops independently. Without V2 standalone
pledge/borrow/release those hops resolve to V1 hooks (at the time: placeholder header and `inspect` = spoke only — both fixed by SUP-21143 — and still no V2 sizing contract),
which new position roots must not select.

## 3. Design

### 3.1 Inheritance

```
BaseHook -> BaseLoanHook -> BaseLoanHookV2 -> BaseAaveV4LoanHookV2 (locked at the time; re-pinned by SUP-21143, §8.1) -> BaseAaveV4StandaloneLoanHookV2 (new)
                                                                                  -> AaveV4SupplyHookV2 / AaveV4BorrowHookV2 / AaveV4WithdrawHookV2
```

The standalone helpers live in a NEW abstract inherited only by the three leaves. Adding internals to
`BaseAaveV4LoanHookV2` / `BaseLoanHookV2` would change the compiled bytecode of the deployed OPEN/REPAY/CLOSE (legacy
codegen embeds inherited internals even when unreferenced); since those never import the new file, their creation code is
untouched by construction at the time of SUP-21141 (`AaveV4LoanBytecodeUnchanged.t.sol` proved it for all nine LOAN artifacts). SUP-21143 then deliberately re-pinned all 12 LOAN hooks and, through the shared `AaveV4ReserveKey` library, the idle pair and the registry (§8.1).

### 3.2 Calldata (exact 241 bytes, canonical Aave V4 V2 layout)

| offset | field | rule |
|---|---|---|
| 0 / 32 | strategy header | **bound (SUP-21143)**: `yieldSourceOracleId` @0 = Superform Aave V4 YS oracle id (must be nonzero → `ORACLE_ID_NOT_VALID`; otherwise identity only — LOAN is NONACCOUNTING, the executor never reads it); `yieldSource` @32 = `AaveV4ReserveKey.computeReserveKey(spoke, primaryReserveId)` (supply reserve for PLEDGE / RELEASE, borrow reserve for BORROW), zero → `ADDRESS_NOT_VALID`, anything else → `RESERVE_KEY_MISMATCH` — pinned inside the pure decoder, so build, preExecute, inspect, `decodeAmounts` and `replaceCalldataAmounts` all fail closed (`decodeUsePrevHookAmount` checks length + canonical bool only); checked after every format check |
| 52 | `loanToken` | nonzero; ≠ collateralToken (`IDENTICAL_TOKENS`) |
| 72 | `collateralToken` | nonzero |
| 92 | `spoke` | nonzero; the only call target / approve spender |
| 112 | `supplyReserveId` | `getReserve(id).underlying == collateralToken` (`TOKEN_RESERVE_MISMATCH`), bound on all three hooks |
| 144 | `borrowReserveId` | `getReserve(id).underlying == loanToken`, bound on all three hooks (identity only for PLEDGE/RELEASE) |
| 176 | primary | PLEDGE: exact collateral; BORROW: exact loan assets; RELEASE: exact collateral or `max` = all supplied |
| 208 | secondary | RESERVED, must be zero (`RESERVED_FIELD_NOT_ZERO`) — one advertised leg |
| 240 | `usePrevHookAmount` | strict `0x00`/`0x01`; applies to the primary only |

Any other length → `INVALID_DATA_LENGTH` on build, inspect, `decodeAmounts`, `replaceCalldataAmounts`,
`decodeUsePrevHookAmount`. The sizing views run the full strict decode (since SUP-21143 every V2 sizing view — base one-slot defaults and composite two-slot overrides — runs the
strict decoder), so no payload the builder rejects can be sized or rewritten.

`inspect()` = `reserveKey ‖ spoke ‖ loanToken ‖ collateralToken ‖ supplyReserveId ‖ borrowReserveId` (144 bytes, key first — the oracle / indexing key, same rule as Morpho and the idle Aave hooks) — identical shape to the composite V2 hooks and, since SUP-21143, to the V1 hooks. The Spoke @92 remains the only call target and approve spender; the key is never called.

### 3.3 Amount semantics ("before any Spoke call")

- **Exact primary (PLEDGE, BORROW):** usePrev ? previous hook's output (must be denominated in collateralToken /
  loanToken respectively, else `PREV_TOKEN_MISMATCH`; missing prev → `ADDRESS_NOT_VALID`) : calldata word. Zero and
  `type(uint256).max` → `AMOUNT_NOT_VALID` on both paths. No cap, no sentinel, no LTV/ratio/oracle.
- **RELEASE:** the live position is gated first, in this order: `getUserSuppliedAssets(supplyReserveId)` zero →
  `AMOUNT_NOT_VALID`; `getUserReserveStatus` flag false → `RESERVE_NOT_COLLATERAL` (§4); then the amount word: zero →
  `AMOUNT_NOT_VALID`. usePrev → previous output in collateralToken (the word, max or not, is ignored — the sentinel is reachable only
  with usePrev = false). Calldata `max` → expected receipt = pre-read position, and `max` is passed through so the Spoke
  withdraws everything natively (CLOSE-hook convention; exactness proven on the live Spoke incl. after a 30-day warp).
  Any exact or previous-hook amount above the position → `WITHDRAW_EXCEEDS_SUPPLIED(requested, supplied)`: unlike Morpho, Aave
  does not underflow-revert an over-withdrawal but silently converts it into a full withdrawal, which would only fail later as
  `DELTA_MISMATCH`.
- **CLOSE's withdraw leg (composite, same helper):** the repay leg (and so the prev-hook pipe) is resolved first, then the
  withdraw leg runs the identical gate and order — empty → `AMOUNT_NOT_VALID`, un-flagged → `RESERVE_NOT_COLLATERAL`, zero word →
  `AMOUNT_NOT_VALID`, `max` → full position, above → `WITHDRAW_EXCEEDS_SUPPLIED` (unit `test_CloseHook_WithdrawLeg_OrderMatchesRelease`,
  `test_CloseHook_RepayPipe_ResolvedBeforeWithdrawGate`).
- **V1 Withdraw / RepayAndWithdraw:** same live gate (`_requireCollateralPosition(spoke, supplyReserveId, account)` in
  `BaseAaveV4LoanHook`: empty → `AMOUNT_NOT_VALID`, un-flagged → `RESERVE_NOT_COLLATERAL`) on build and preExecute; no typed
  over-position error (V1 amounts are exact words passed straight to the Spoke).

### 3.4 Execution sequences (plus BaseHook's pre/post wrapper)

- PLEDGE (5): `approve(spoke, 0)`, `approve(spoke, amount)`, `supply(supplyReserveId, amount, account)`,
  `setUsingAsCollateral(supplyReserveId, true, account)`, `approve(spoke, 0)`. The enable is a no-op when already set
  (fork-proven, no event emitted on the second pledge).
- BORROW (1): `borrow(borrowReserveId, amount, account)`.
- RELEASE (1): `withdraw(supplyReserveId, fullWithdraw ? max : amount, account)`. No repay leg, no flag toggle.

`onBehalfOf` / receiver is always the executing account.

### 3.5 Settlement and published outputs

`_preExecute` resolves the expected amount and snapshots both wallet balances; `_postExecute` measures the delta and
reverts `DELTA_MISMATCH` on any deviation (`NEGATIVE_BALANCE_DELTA` on the wrong direction).

- PLEDGE: collateral spend `== amount` enforced; publishes `outAmount = 0`, `outToken = collateralToken`. Terminal, like
  `_settleRepay`: publishing the spend would let a downstream `usePrevHookAmount` consumer denominated in the collateral
  token spend an equal amount of unrelated wallet balance; zero makes such chaining fail closed. Erebor classifies
  "produces NONE". ("Measured, enforced, not published.")
- BORROW: publishes the loan-token wallet delta (== amount) with `outToken = loanToken`.
- RELEASE: publishes the collateral wallet delta (== expected) with `outToken = collateralToken`.

## 4. Collateral-flag semantics

- PLEDGE flips the per-(account, reserve) collateral flag. RELEASE never toggles it; after a full release the flag
  **stays true** on the live Spoke (observed in `test_AaveV4V2_Release_MaxSentinel_FullCollateral`).
- Interaction with the idle MONEY_MARKET hooks: `AaveV4LendHook` / `AaveV4RedeemHook` refuse a collateral-flagged
  reserve (`RESERVE_IS_COLLATERAL`), so after a PLEDGE the idle pair refuses that (account, reserve) by design
  (`test_AaveV4V2_Pledge_FlipsFlag_IdleRedeemRefuses`). The other direction is guarded on-chain too (security review):
  PLEDGE refuses a reserve that carries an un-flagged position (`RESERVE_HAS_IDLE_POSITION`) and RELEASE refuses a
  reserve that is not flagged (`RESERVE_NOT_COLLATERAL`), both read via `getUserReserveStatus` before any Spoke call
  (`test_AaveV4V2_Standalone_UnflaggedPosition_RefusedByPledgeAndRelease`). So every (account, reserve) is in exactly
  one mode: **flag false = idle MONEY_MARKET (ledger-tracked), flag true = LOAN**. Returning a released reserve to idle
  mode needs a direct `setUsingAsCollateral(false)` self-call (the flag stays true after a full release).
- Live evidence (planner probes): `setUsingAsCollateral(id, true, self)` succeeds even with zero supply (Ethereum
  reserves 0/7, Base MAG7 reserve 7); `getDynamicReserveConfig` collateral factors — Ethereum WETH 8300, WBTC 7800,
  USDC 7800; Base MAG7 USDC **0** (a USDC pledge on MAG7 backs no borrowing), AAPLc 7800. Base fork coverage is
  therefore skipped for this ticket (MAG7 equities are node-native tokens, not fork-executable); Ethereum covers the AC.

**Residual (final security pass, P3-A; narrowed by the SUP-21143 review):** the partition is now enforced on-chain at every
recompiled flag-setting entry point — PLEDGE, composite OPEN V2 and the V1 Supply / SupplyAndBorrow hooks all refuse an un-flagged
idle position (`RESERVE_HAS_IDLE_POSITION`, shared `_requireNoIdlePosition` in `BaseAaveV4LoanHookV2` / `BaseAaveV4LoanHook`), and
RELEASE, CLOSE and the V1 Withdraw / RepayAndWithdraw refuse an un-flagged reserve (`RESERVE_NOT_COLLATERAL`), so no recompiled
LOAN hook can pay an idle, ledger-tracked position out. The Spoke flag can still be set over an idle position by a manual `setUsingAsCollateral(true)`
self-call or by the pre-SUP-21143 deployed OPEN V2 / V1 addresses (no guard); after that RELEASE(max) pays the merged position out
without a ledger outflow. All of these are the account's own signed intents, so the remaining guard is the OMS rule already stated by
the idle spec: never route a flag-setting supply onto an (account, spoke, reserveId) carrying an idle position, and evict the old
addresses. Pinned by fork `test_AaveV4V2_Release_ManualFlagOverIdlePosition_PaysOut_Residual` (manual path) and
`test_AaveV4V2_Open_OverIdlePosition_Refused_FlaggedPasses` (OPEN guard), `test_AaveV4V2_Close_ManualFlagOff_Refused_UntilReenabled`
(CLOSE gate) and V1 fork `test_AaveV4_V1_WithdrawLegs_OverIdlePosition_Refused`. Follow-up (§9): encode the rule in the manifest / OMS
classifier so it is machine-checked.

## 5. Rounding observed on the live Spoke (block 24_884_274)

Supply credits sit below the spend by the Hub's share round-trip rounding (`SharesMath`: assets → shares rounds down, shares →
assets rounds down again), so the gap is exchange-rate dependent and NOT a fixed 1 wei: 1 wei for a 1 WETH pledge and **2 wei**
for a 1_000_000_000_000_001_857 wei pledge on the same reserve and block (PR #1019 review P3-1, pinned by fork
`test_AaveV4V2_Pledge_CreditRoundDown_CanExceedOneWei_Regression`). Never infer a universal loss bound from fixed-amount
tests; always size an exact RELEASE from the live `getUserSuppliedAssets` or use the sentinel. A partial withdraw consumes up to
1 share-rounding unit more position than paid;
wallet receipts/spends are always exact. Over a pledge → partial release → full release lifecycle the wallet ends within
2 wei of its start. Tests assert exact wallet deltas and ≤ 2 wei on positions.

## 6. Security / attack surface

- Third-party donations cannot touch the position (Spoke `onlyPositionManager`, live-probed in the SUP-21142 report);
  wallet donations mid-batch force `DELTA_MISMATCH` (fail closed).
- Health-factor reverts (BORROW, RELEASE) are the Spoke's; the whole userOp reverts with no partial state
  (`test_AaveV4V2_Borrow_NoCollateral_SpokeReverts`, `_Release_Undercollateralized_SpokeHealthCheckReverts`,
  `_TwoCollaterals_ReleaseLast_WithDebt_Reverts`). The hooks add no LTV logic.
- BORROW / RELEASE are fail-open prev-pipe consumers (Morpho review P2-1 acceptance carried over): a poisoned
  predecessor output sizes a provider-minted leg that settles clean. Same acceptance: no callback-bearing tokens in
  Superform chains; the bundler never pipes a hook into itself (`PREV_TOKEN_MISMATCH` anyway).
- Supply/borrow caps, pause, freeze, Hub liquidity shortfall: whole-userOp reverts; RELEASE(max) is not liquidity-safe
  under stress (OMS reads Hub liquidity first).
- Transient slots are plain (base trade-off); using one hook twice in a userOp (pledge WETH, pledge WBTC) is sequential
  with a fresh context per hook.
- Fee-on-transfer / rebasing tokens fail the strict deltas (base policy).
- Hub/Spoke are governance-upgradeable; an added withdraw fee would fail loudly via `DELTA_MISMATCH`.
- Mode partition is on-chain at every recompiled flag-setting entry point (PLEDGE, OPEN V2, V1 supplies) and at RELEASE (§4;
  residual via manual flag toggle / pre-SUP-21143 addresses documented there): the LOAN hooks cannot pay an idle, ledger-tracked
  position out without a
  ledger outflow, and cannot flip one into LOAN mode.
- Off-chain pre-flight caveats (security review, no hook change): BORROW and flagged RELEASE refresh the account's
  dynamic-config keys for **all** flagged reserves before the health check, while `getUserAccountData` uses the stale
  keys — the OMS must size with `getDynamicReserveConfig(id, getReserve(id).dynamicConfigKey)` or `eth_call` the real
  action; `DrawCapExceeded` / `AddCapExceeded` are per-Spoke caps on top of Hub liquidity; a frozen reserve still
  allows RELEASE but not PLEDGE/BORROW; `MAX_USER_RESERVES_LIMIT` is per Spoke (65535 on Ethereum Core = disabled);
  a `collateralFactor == 0` reserve (Base MAG7 USDC) can be flagged but backs nothing.
- Never route these hooks through an Aave position manager: the Hub pays `msg.sender`, so only the account's own
  self-call keeps receiver == onBehalfOf (the strict deltas would fail closed anyway).
- PLEDGE settles on the wallet spend only; the position credit rounds down ≤ index wei on an established reserve. On a
  freshly listed, nearly empty reserve a donated share price would make that round-down material, so the OMS routes
  PLEDGE only to reserves with meaningful `getReserveSuppliedAssets`.

## 7. Acceptance criteria → tests

| Criterion | Proof |
|---|---|
| Three hooks with new deterministic addresses; V1 and V2 OPEN/REPAY/CLOSE unchanged by SUP-21141 (later re-pinned by SUP-21143, §8.1) | new contracts; `AaveV4LoanBytecodeUnchanged.t.sol` green (`_BytecodePinned` for the 12 LOAN hooks, `test_IdleHooks_BytecodePinned` for the idle pair) |
| Exact 241 bytes, canonical bool, reserved secondary zero | unit `test_Standalone_Build_RevertIf_WrongLength/NonCanonicalBool/SecondaryWordNotZero`; sizing `_RealSpoke_SingleSlot` |
| Decode/replace primary only, nonzero secondary rejected, wrong replace lengths revert | unit `test_Standalone_ReplaceCalldataAmounts_SingleSlot`, `_SizingApi_RejectsMalformedPayloads`; sizing tests |
| PLEDGE supplies, enables collateral, allowance zero | unit `test_Pledge_Build_Shape`; fork `test_AaveV4V2_Pledge_Exact` (flag true, 1 event, allowance 0) |
| BORROW exact, outAmount/outToken = loan-token delta | unit `test_Borrow_SettleRoundTrip`, `test_Borrow_AsPrevHook_TokenDenominationEnforced`; fork `test_AaveV4V2_Borrow_AfterPledge_Exact`, `_Borrow_Chained_UsesPrevHookOutput`, and under the real executor `_PledgeBorrowRepay_OneUserOp_BorrowOutputFeedsRepay` (BORROW's published delta sizes a REPAY(usePrev): wallet nets to zero, debt to ≤ 2 wei of index dust) |
| RELEASE withdraw only; `max` withdraws all with usePrev = false | unit `test_Release_Build_MaxSentinel_*`, `test_Release_AsPrevHook_FeedsPledgeExactly`, fuzz `testFuzz_Release_ExactBoundary`; fork `test_AaveV4V2_Release_MaxSentinel_FullCollateral`, `_AfterWarp_PaysAccrued`, `_Release_Chained_UsesPrevHookOutput_IgnoresMaxWord`, `_ReleaseThenRepledge_OneUserOp_RoundTrips`; sizing `test_Fork_AaveV4V2_Release_RealSpoke_ZeroPositionReverts` |
| `_validateReserves` before Spoke calls | unit `test_Standalone_Build_RevertIf_ReserveMismatch`; fork `test_AaveV4V2_Standalone_ReserveMismatch_StateUnchanged` |
| No LTV/oracle/ratio derivation | code; fork health-check tests typed on the Spoke's `HealthFactorBelowThreshold()` (0x851aedc1) |
| One mode per (account, reserve), both directions on-chain; all four (flag, supplied) cells | unit `test_Pledge_Build_RevertIf_IdlePositionOnReserve`, `test_Pledge_Build_FreshOrFlaggedReserve_Passes` (incl. flag-true/empty re-pledge), `test_Release_Build_RevertIf_NotCollateral`, `test_Standalone_ReadsCalldataSpokeAndSupplyReserve`, validation-order tests; fork `test_AaveV4V2_Standalone_UnflaggedPosition_RefusedByPledgeAndRelease`, `_Pledge_AfterFullRelease_RepledgeAllowed`, `_ManualFlagOff_BlocksReleaseAndPledge_UntilReenabled` (the P2-2 trade-off: hooks never repair a manually cleared flag) |
| RELEASE exact word == full position pays all | unit `test_Release_Build_UsePrev_EqualsSupplied_Passes`; fork `test_AaveV4V2_Release_ExactEqualsSupplied_PaysAll` |
| Wrong prev token, zero prev hook, identical tokens, zero/sentinel legs revert before Spoke calls; PLEDGE is terminal (zero output fails closed) | unit prev-pipe + validation-order sections, `test_Pledge_AsPrevHook_FailsClosed`, `test_Standalone_PreExecute_MirrorsBuildAmountRules`, fuzz `testFuzz_Standalone_UsePrev_IgnoresWord`; fork `_Pledge_Chained_WrongPrevToken_StateUnchanged`, `_BorrowRelease_Chained_WrongPrevToken_StateUnchanged`, `_Pledge_AsPrevHook_FailsClosed_StateUnchanged`, `_Release_Chained_PrevAboveSupplied_Reverts_StateUnchanged`, `_Borrow_ZeroAmount_Reverts`, `_PledgeRelease_ZeroAndMaxWords_Reverts_StateUnchanged`, `_Release_EmptyPosition_Reverts` |
| Manifest amount metadata parity (PLEDGE IN/TOKEN; BORROW OUT/TOKEN; RELEASE OUT/TOKEN) | on-chain `amountRoles` pinned by unit `test_Standalone_AmountRoles` + sizing `test_Fork_AaveV4V2_Standalone_AmountRoles`; `hook-enrichment.yaml` `amountMeta` + regenerated `manifests/hooks.json` checked by `tooling/lint_hook_manifest.py` (§8) |
| Fork tests on a real V4 spoke, ≥ 2 collateral reserves sharing one borrow reserve | `AaveV4V2HooksFork.t.sol`: WETH(0) + WBTC(3) → USDC(7) lifecycle and last-leg health revert |
| Strict delta equality in both directions (short, over, wrong-direction; other token ignored) | unit `test_*_Settle_RevertIf_ShortDelivery/DeltaMismatch`, `test_Standalone_Settle_RevertIf_OverDelivery`, `test_BorrowRelease_Settle_RevertIf_NegativeDelta`, `test_Standalone_Settle_IgnoresOtherToken`, `test_PledgeBorrow_Settle_UsePrev_ExpectsPrevOutput`, `test_Standalone_PreExecute_SnapshotsAndSecondaryUnused` |
| Sizing views are strict but amount-agnostic; a rewrite can never smuggle a word build() refuses; only bytes [176, 208) change | unit `test_Standalone_Sizing_RawSentinel_And_RewriteToInvalidRejectedByBuild`, `test_Standalone_Replace_KeepsUsePrevFlag_BuildStillUsesPrev`, `test_Standalone_SizingApi_MalformedCrossProduct`, `test_Standalone_Inspect_StrictAndBound`, fuzz `testFuzz_Standalone_Replace_PreservesEveryOtherByte`, `testFuzz_Standalone_NonCanonicalBool_Rejected`; fork `_Standalone_ReplacedPayload_ExecutesRewrittenAmount` |
| Account-authenticated pre/post; `account` parameter (not msg.sender) selects position, flag and wallet | unit `test_Standalone_AccountParameterIsAuthoritative` |
| Token-level failure (wallet short) is atomic with no allowance residue | fork `_Pledge_InsufficientWallet_StateUnchanged` (empty WETH9 revert: asserted via `UserOperationEvent.success == false`) |
| V1 hooks not renamed / no MONEY_MARKET twins here | unchanged |

Coverage after the 2026-09-29 gap pass: unit 73 (`AaveV4StandaloneLoanHooksV2.t.sol`), sizing 30 (`LoanHooksV2SizingIntegration.t.sol`,
whole file), fork 45 (`AaveV4V2HooksFork.t.sol`, whole file), bytecode lock 4. Third pass: unit 79, fork 53 incl. governance states on the live Spoke via a mocked AccessManager `canCall`
(`test_AaveV4V2_FrozenReserve_*`, `_FrozenBorrowReserve_*`, `_PausedReserve_*`, `_FrozenSecondLeg_WholeUserOpRollsBack`,
`_NonBorrowableReserve_BorrowRefused`), same-hook-twice-in-one-userOp, self-chain fail-closed (`PREV_TOKEN_MISMATCH` on the
fresh context), double release, exactness after 30 d accrual, WBTC round-down pin, identity-only `supplyReserveId`, sizing
rewrites on BORROW / RELEASE. Not covered on-chain: Hub-side `AddCapExceeded` / `DrawCapExceeded`.
SUP-21143 E2E (`test/integration/AaveV4HeaderIdentityE2EFork.t.sol`, real SuperExecutor + SuperLedger + registry + supply / debt
oracles on the live Main Spoke): `test_E2E_HeaderKey_ResolvesThroughRegistry_AllEightOps` (inspect()[0:20] → registry → the op's
primary (spoke, reserveId) for idle lend / redeem + six LOAN ops), `test_E2E_IdleUsdcLender_And_WethCollateralUsdcBorrower_KeyedApart`
(the ticket's motivating scenario: idle USDC and a USDC borrow share one key across the supply and debt oracles, the ledger sees only
the idle leg, redeem nets the ledger while the loan stays), `test_E2E_ModePartition_BothDirections_LiveSpoke`,
`test_E2E_OpenOverIdle_Refused_ThenRedeemAndOpen_Succeeds`. In `AaveV4V2HooksFork`: `test_E2E_PledgeBorrowRepayRelease_OneUserOp_MixedKeys`,
`test_E2E_CompositeSizingFlow_RewriteThenExecute_WrongKeyRefusedAtSizing`, `test_E2E_StaleSizing_TypedError_ThenLiveResize`,
`test_AaveV4V2_Open_OverIdlePosition_Refused_FlaggedPasses`. V1 fork: `test_AaveV4_V1_Inspect_KeyFirst_AllSixOps`,
`_V1_WrongHeaderKey_Reverts_StateUnchanged`, `_V1_Supply_OverIdlePosition_Refused`.

## 8. Deployment (wired 2026-09-28, not yet deployed)

Keys `AAVE_V4_SUPPLY_HOOK_V2_KEY` / `AAVE_V4_BORROW_HOOK_V2_KEY` / `AAVE_V4_WITHDRAW_HOOK_V2_KEY` in
`script/utils/Constants.sol`; `AaveV4V2StandaloneHookAddresses` set, `_deployAaveV4V2StandaloneHooksSet` and the
`runAaveV4V2Standalone(uint256,uint64)` entrypoint in `DeployV2OtherHooks.s.sol`. **No chain gate** (user decision
2026-09-28): no constructor args (Spoke from calldata), so `_deployAllHooks` deploys the trio on every configured network for
uniform addresses; inert where no Aave V4 spoke exists. The composite V2 set (OPEN / REPAY / CLOSE) is deployed on every network
as well (was mainnet-only; simulated on Base at its mainnet addresses 0xd7bD…2F4D / 0xecBB…bb5F / 0xb365…D7c6), so REPAY exists
wherever BORROW does. Names in `AAVE_V4_HOOK_CONTRACTS` (`regenerate_bytecode.sh`)
and `AAVE_V4_HOOKS` (`deploy_v2_other_hooks_staging_prod.sh`); artifacts in generated / locked / locked-dev, pinned by
`test_LoanV2Standalone_BytecodePinned` (re-pinned by SUP-21143); `hook-enrichment.yaml` tags `[aave-v4]` + `amountMeta` (borrow / withdraw
`[{OUT, TOKEN}]`, pledge keeps the loan default `[{IN, TOKEN}]`; deliberately NOT in `loanInterfaceHooks`);
`hook-classification.yaml` (`lend` / `borrow` / `withdraw`, instant, `[sized]`); `manifests/hooks.json` and
`hook-sizing-manifest.json` regenerated (generator now recognises `StandaloneLoanHookV2` bases as NONACCOUNTING, which also
fills the previously missing `hookType` on the three Morpho standalone entries). Fork simulation (staging salt, env 2) on
Ethereum and Base: `AaveV4SupplyHookV2` 0x5b683AC97f616eE7662Aeb7a915a5B8330afef9B, `AaveV4BorrowHookV2`
0x7Ca0020ed6f61F12103c727150B8f94ae7547F0E, `AaveV4WithdrawHookV2` 0x6cbc0c8874b0D0D34a55C17603B17135EFBb2484 (same
CREATE2 address on every chain; Optimism simulated too). Deploy: `TARGET_FAMILY=AaveV4V2Standalone
./script/run/deploy/deploy_v2_other_hooks_staging_prod.sh <staging|prod> deploy v2-supervaults` (all configured networks), then
commit the resulting `…-latest.json` keys.

### 8.1 SUP-21143 header bind — bytecode consequences

Binding the header changed the creation code of all 12 Aave V4 LOAN hooks (V1 six, composite V2 trio, standalone trio). The
final review then consolidated the reserve-key hash and `RESERVE_KEY_MISMATCH` into `src/libraries/AaveV4ReserveKey.sol`, shared
with `AaveV4ReserveRegistry.computeReserveKey` and the idle base — so the idle pair and the registry (none deployed yet) are
re-pinned too (`test_IdleHooks_BytecodePinned`). Artifacts in `generated-bytecode` / `locked-bytecode` /
`locked-bytecode-dev` were regenerated and `AaveV4LoanBytecodeUnchanged.t.sol` re-pins them (`_BytecodePinned`). New deterministic
addresses follow from the new bytecode at the next deploy run (same salts, no script change; `script/output/**` is rewritten by that
run, not by this PR). The previously deployed Ethereum addresses stay live for old roots and are superseded for new roots:
`AaveV4SupplyAndBorrowHookV2` 0x2B31f0bd1F3f9f4e9684F1Ce2F790c319d3E7140, `AaveV4RepayHookV2`
0xf28CbB9480bbA64F46D7225124E5e99E889152B2, `AaveV4RepayAndWithdrawHookV2` 0x3Ed31AB6986667B8bdea1225C1EFB0529DaFd24F, V1
`AaveV4SupplyHook` 0xaeBe021a2F2A9065f3954C74ceeCB7368E685267, `AaveV4WithdrawHook` 0xf3CA38654990a26148bc1fA2aBC5EC6E06038346,
`AaveV4BorrowHook` 0x6Fe1ddC0000Dc7A75BDD7555bcaccdFC607Eca40, `AaveV4RepayHook` 0x2d3bB312BA70f3C2Bca61Dc42dD44AA6036c35eb,
`AaveV4SupplyAndBorrowHook` 0xa6Fd16C346e1416cDDF50A8e5D529e03BbBd6194, `AaveV4RepayAndWithdrawHook`
0x69086E40D7570E8157b4f50bAf65fAF1a33E2efF. The standalone trio's simulated addresses above are superseded too (never deployed).
Bundler / Erebor / OMS allow-lists must be repointed to the new addresses after deploy (out of scope).

**Also from the final review (all approved):** composite OPEN V2 and the V1 Supply / SupplyAndBorrow hooks now carry the idle-position
guard; every V2 sizing view (composite included) runs the strict decoder, so no payload build() refuses can be sized or rewritten;
RELEASE's and CLOSE's over-position refusal is the typed `WITHDRAW_EXCEEDS_SUPPLIED(requested, supplied)`; CLOSE's withdraw leg and
the V1 Withdraw / RepayAndWithdraw share RELEASE's live-position / collateral-flag gate (`_requireCollateralPosition`, same check
order — §3.3); the V1 six are still redeployed (ticket: publish new V1 addresses).

**Guards carried by the header bind (final security pass):** (1) `yieldSourceOracleId` must be nonzero on every Aave V4 hook (`ORACLE_ID_NOT_VALID`,
ticket "revert on zero") but is not otherwise validated on LOAN hooks because the executor reads the header only for INFLOW / OUTFLOW;
any LOAN hook re-typed to INFLOW / OUTFLOW MUST also pin the oracle id — `test_HookTypes_LoanNonAccounting_IdleAccounting` makes a
re-type visible.
(2) Off-chain consumers (Erebor / OMS / pricing) must treat `inspect()[0:20]` as an opaque key resolved through
`AaveV4ReserveRegistry.getReserveInfo` (never probe it as an ERC-20 / vault) and reject unregistered keys: an attacker-controlled
spoke yields a self-consistent `key(attackerSpoke, id)` that passes the hook's pin. (3) V1 hooks now re-run the strict decode in `preExecute()` too (key pin + idle guard on the execution path), like V2.
(4) Aave V3 LOAN hooks still carry placeholder headers — out of scope (Aave V3 is not used). (5) `inspect()` changed shape one-directionally
(composite V2 124 → 144 bytes, key prepended; V1 20 → 144 bytes) while the pre-SUP-21143 deployments stay live under the same
manifest names: consumers must evict / version the old addresses BEFORE adopting the key-first parsing rule, because on the old
addresses `inspect()[0:20]` is the Spoke, not a reserve key.

## 9. Follow-ups

- Encode the one-mode-per-(account, spoke, reserveId) routing rule in `hook-classification.yaml` / the OMS classifier so the P3-A residual (flag set over an idle position by a manual toggle or the pre-SUP-21143 deployed addresses) is machine-checked rather than prose.

Base smoke test, Erebor/OMS classification and CreateHook, the deploy itself (§8), OMS pre-flight
(dynamic-config refresh, per-Spoke caps, reserve flags — §6). Security report:
`specs/security-reports/2026-09-28-aave-v4-v2-standalone-loan-hooks.md`.
