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
and the shipped V2 OPEN/REPAY/CLOSE are not renamed, not modified, and their bytecode is proven unchanged. The idle
MONEY_MARKET pair (SUP-21142) is a separate sibling; RELEASE is NOT the idle redeem.

**Deployment wiring is in place** (2026-09-28, on request; §8) — the hooks are not yet deployed.

## 2. Problem statement

OMS already composes LOAN aux around any vault-main (OPEN/BORROW/RELEASE before a deposit main; CLOSE/REPAY/PLEDGE after
a withdrawal-like main), and borrower-only Equities Hub plans need the six ops independently. Without V2 standalone
pledge/borrow/release those hops resolve to V1 hooks (placeholder header, `inspect` = spoke only, no V2 sizing contract),
which new position roots must not select.

## 3. Design

### 3.1 Inheritance

```
BaseHook -> BaseLoanHook -> BaseLoanHookV2 -> BaseAaveV4LoanHookV2 (locked) -> BaseAaveV4StandaloneLoanHookV2 (new)
                                                                                  -> AaveV4SupplyHookV2 / AaveV4BorrowHookV2 / AaveV4WithdrawHookV2
```

The standalone helpers live in a NEW abstract inherited only by the three leaves. Adding internals to
`BaseAaveV4LoanHookV2` / `BaseLoanHookV2` would change the compiled bytecode of the deployed OPEN/REPAY/CLOSE (legacy
codegen embeds inherited internals even when unreferenced); since those never import the new file, their creation code is
untouched by construction. `AaveV4LoanBytecodeUnchanged.t.sol` proves it for all nine LOAN artifacts.

### 3.2 Calldata (exact 241 bytes, canonical Aave V4 V2 layout)

| offset | field | rule |
|---|---|---|
| 0 / 32 | strategy header | placeholders on this base (reserve-key bind is SUP-21143/21148, layout-preserving) |
| 52 | `loanToken` | nonzero; ≠ collateralToken (`IDENTICAL_TOKENS`) |
| 72 | `collateralToken` | nonzero |
| 92 | `spoke` | nonzero; the only call target / approve spender |
| 112 | `supplyReserveId` | `getReserve(id).underlying == collateralToken` (`TOKEN_RESERVE_MISMATCH`), bound on all three hooks |
| 144 | `borrowReserveId` | `getReserve(id).underlying == loanToken`, bound on all three hooks (identity only for PLEDGE/RELEASE) |
| 176 | primary | PLEDGE: exact collateral; BORROW: exact loan assets; RELEASE: exact collateral or `max` = all supplied |
| 208 | secondary | RESERVED, must be zero (`RESERVED_FIELD_NOT_ZERO`) — one advertised leg |
| 240 | `usePrevHookAmount` | strict `0x00`/`0x01`; applies to the primary only |

Any other length → `INVALID_DATA_LENGTH` on build, inspect, `decodeAmounts`, `replaceCalldataAmounts`,
`decodeUsePrevHookAmount`. The sizing views run the full strict decode (the locked base's one-slot readers only check
length), so no payload the builder rejects can be sized or rewritten.

`inspect()` = `spoke ‖ loanToken ‖ collateralToken ‖ supplyReserveId ‖ borrowReserveId` — identical to the composite V2 hooks.

### 3.3 Amount semantics ("before any Spoke call")

- **Exact primary (PLEDGE, BORROW):** usePrev ? previous hook's output (must be denominated in collateralToken /
  loanToken respectively, else `PREV_TOKEN_MISMATCH`; missing prev → `ADDRESS_NOT_VALID`) : calldata word. Zero and
  `type(uint256).max` → `AMOUNT_NOT_VALID` on both paths. No cap, no sentinel, no LTV/ratio/oracle.
- **RELEASE:** the account's `getUserSuppliedAssets(supplyReserveId)` is read first; zero → `AMOUNT_NOT_VALID` on every
  path. usePrev → previous output in collateralToken (the word, max or not, is ignored — the sentinel is reachable only
  with usePrev = false). Calldata `max` → expected receipt = pre-read position, and `max` is passed through so the Spoke
  withdraws everything natively (CLOSE-hook convention; exactness proven on the live Spoke incl. after a 30-day warp).
  Any exact or previous-hook amount above the position → `AMOUNT_NOT_VALID`: unlike Morpho, Aave does not underflow-
  revert an over-withdrawal but silently converts it into a full withdrawal, which would only fail later as
  `DELTA_MISMATCH`.

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

**Residual (final security pass, P3-A):** the partition is enforced on-chain only at the PLEDGE and RELEASE entry points. The
Spoke flag can still be set over an idle position by the composite `AaveV4SupplyAndBorrowHookV2`, the V1 supply hooks (both
bytecode-locked, no idle guard) or a manual `setUsingAsCollateral(true)`; after that RELEASE(max) pays the merged position out
without a ledger outflow. All of these are the account's own signed intents, so the remaining guard is the OMS rule already
stated by the idle spec: never route OPEN / V1 supply / PLEDGE onto an (account, spoke, reserveId) carrying an idle position.
Pinned as documented behaviour by fork `test_AaveV4V2_Release_ManualFlagOverIdlePosition_PaysOut_Residual`. Follow-up (§9):
encode the rule in the manifest / OMS classifier so it is machine-checked.

## 5. Rounding observed on the live Spoke (block 24_884_274)

Supply credits round down ≤ 1 wei of the spend; a partial withdraw consumes up to 1 wei more position than paid;
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
- Mode partition is on-chain both ways (§4): the LOAN hooks cannot pay an idle, ledger-tracked position out without a
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
| Three hooks with new deterministic addresses; V1 and V2 OPEN/REPAY/CLOSE unchanged | new contracts; `AaveV4LoanBytecodeUnchanged.t.sol` (9 artifacts) green |
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
| Sizing views are strict but amount-agnostic; a rewrite can never smuggle a word build() refuses; only bytes [176, 208) change | unit `test_Standalone_Sizing_RawSentinel_And_RewriteToInvalidRejectedByBuild`, `test_Standalone_Replace_KeepsUsePrevFlag_BuildStillUsesPrev`, `test_Standalone_SizingApi_MalformedCrossProduct`, `test_Standalone_Inspect_StrictButUnbound`, fuzz `testFuzz_Standalone_Replace_PreservesEveryOtherByte`, `testFuzz_Standalone_NonCanonicalBool_Rejected`; fork `_Standalone_ReplacedPayload_ExecutesRewrittenAmount` |
| Account-authenticated pre/post; `account` parameter (not msg.sender) selects position, flag and wallet | unit `test_Standalone_AccountParameterIsAuthoritative` |
| Token-level failure (wallet short) is atomic with no allowance residue | fork `_Pledge_InsufficientWallet_StateUnchanged` (empty WETH9 revert: asserted via `UserOperationEvent.success == false`) |
| V1 hooks not renamed / no MONEY_MARKET twins here | unchanged |

Coverage after the 2026-09-29 gap pass: unit 73 (`AaveV4StandaloneLoanHooksV2.t.sol`), sizing 30 (`LoanHooksV2SizingIntegration.t.sol`,
whole file), fork 45 (`AaveV4V2HooksFork.t.sol`, whole file), bytecode lock 4. Third pass: unit 79, fork 53 incl. governance states on the live Spoke via a mocked AccessManager `canCall`
(`test_AaveV4V2_FrozenReserve_*`, `_FrozenBorrowReserve_*`, `_PausedReserve_*`, `_FrozenSecondLeg_WholeUserOpRollsBack`,
`_NonBorrowableReserve_BorrowRefused`), same-hook-twice-in-one-userOp, self-chain fail-closed (`PREV_TOKEN_MISMATCH` on the
fresh context), double release, exactness after 30 d accrual, WBTC round-down pin, identity-only `supplyReserveId`, sizing
rewrites on BORROW / RELEASE. Not covered on-chain: Hub-side `AddCapExceeded` / `DrawCapExceeded`.

## 8. Deployment (wired 2026-09-28, not yet deployed)

Keys `AAVE_V4_SUPPLY_HOOK_V2_KEY` / `AAVE_V4_BORROW_HOOK_V2_KEY` / `AAVE_V4_WITHDRAW_HOOK_V2_KEY` in
`script/utils/Constants.sol`; `AaveV4V2StandaloneHookAddresses` set, `_deployAaveV4V2StandaloneHooksSet` and the
`runAaveV4V2Standalone(uint256,uint64)` entrypoint in `DeployV2OtherHooks.s.sol`. **No chain gate** (user decision
2026-09-28): no constructor args (Spoke from calldata), so `_deployAllHooks` deploys the trio on every configured network for
uniform addresses; inert where no Aave V4 spoke exists. The composite V2 set (OPEN / REPAY / CLOSE) is deployed on every network
as well (was mainnet-only; simulated on Base at its mainnet addresses 0xd7bD…2F4D / 0xecBB…bb5F / 0xb365…D7c6), so REPAY exists
wherever BORROW does. Names in `AAVE_V4_HOOK_CONTRACTS` (`regenerate_bytecode.sh`)
and `AAVE_V4_HOOKS` (`deploy_v2_other_hooks_staging_prod.sh`); artifacts in generated / locked / locked-dev, pinned by
`test_LoanV2Standalone_BytecodePinned`; `hook-enrichment.yaml` tags `[aave-v4]` + `amountMeta` (borrow / withdraw
`[{OUT, TOKEN}]`, pledge keeps the loan default `[{IN, TOKEN}]`; deliberately NOT in `loanInterfaceHooks`);
`hook-classification.yaml` (`lend` / `borrow` / `withdraw`, instant, `[sized]`); `manifests/hooks.json` and
`hook-sizing-manifest.json` regenerated (generator now recognises `StandaloneLoanHookV2` bases as NONACCOUNTING, which also
fills the previously missing `hookType` on the three Morpho standalone entries). Fork simulation (staging salt, env 2) on
Ethereum and Base: `AaveV4SupplyHookV2` 0x5b683AC97f616eE7662Aeb7a915a5B8330afef9B, `AaveV4BorrowHookV2`
0x7Ca0020ed6f61F12103c727150B8f94ae7547F0E, `AaveV4WithdrawHookV2` 0x6cbc0c8874b0D0D34a55C17603B17135EFBb2484 (same
CREATE2 address on every chain; Optimism simulated too). Deploy: `TARGET_FAMILY=AaveV4V2Standalone
./script/run/deploy/deploy_v2_other_hooks_staging_prod.sh <staging|prod> deploy v2-supervaults` (all configured networks), then
commit the resulting `…-latest.json` keys.

## 9. Follow-ups

- Encode the one-mode-per-(account, spoke, reserveId) routing rule in `hook-classification.yaml` / the OMS classifier so the P3-A residual (flag set over an idle position by OPEN V2 / V1 / manual) is machine-checked rather than prose.

Header bind (SUP-21143/21148), Base smoke test, Erebor/OMS classification and CreateHook, the deploy itself (§8), OMS pre-flight
(dynamic-config refresh, per-Spoke caps, reserve flags — §6). Security report:
`specs/security-reports/2026-09-28-aave-v4-v2-standalone-loan-hooks.md`.
