# Repo Analysis — v2-core hook conventions

`CORE` = `lib/v2-core`, `PERI` = repo root.

## Shared-base precedent (use this, not the Kyber shape)

Kyber and Odos ship `Swap*` / `ApproveAndSwap*` as **fully duplicated contracts, no shared base**
(~260 lines each, differing only in `name()`, 1-vs-4 executions, and an approve-target decode).

The newest family does better — `CORE/src/hooks/swappers/aerodrome/` (added 2026-07-27, #948):
- `BaseAerodromeUniversalRouterHook.sol:31` — `abstract contract` holding all 515 lines
- `:320` — `function _includeApproval() internal pure virtual returns (bool);`
- `:163-167` 1-execution array when false; `:169-182` 4-execution array when true
- Concrete contracts are **28 lines each**, overriding only `name()`, `description()`, `_includeApproval()`

Since D10 ships a single `ApproveAndSwap` contract, the base/virtual split is not strictly needed —
but follow Aerodrome's *file* conventions (its slimmer natspec, which defers the byte-offset table
to `ISuperHookSwap`) rather than Kyber's repeated offset block.

## inspect() across the family

Most of the 24 SWAP hooks return `abi.encodePacked(outputToken)` alone. Exceptions committing a
second field: `Swap1InchHook.sol:130-136` (`outputToken, dstReceiver`), `SwapUniswapV4Hook.sol:422-429`
(same), `spark-psm/*:182-186` (`outputToken, receiver`), `PendleUnifiedHook.sol:272-276`
(`yieldSource, outputToken`).

**None commits `inputToken`.** That is the gap D11 closes. Note also that the project CLAUDE.md
claim that Odos `inspect()` commits the *executor* is **stale** — `SwapOdosV3Hook.sol:188-191`
returns `outputToken` only, despite `:38-39` documenting that the executor is delegate-called and
"must be trusted — off-chain validation via `inspect()` is recommended."

## ISuperHookSwap — required members

`CORE/src/interfaces/ISuperHookSwap.sol:33-53`: `encodeSwapData(SwapHeader, bytes payload)`,
`decodeInputToken`, `decodeOutputToken`, `decodeInputAmount`, `decodeOutputQuote`, `decodeOutputMin`,
`decodePayload` — all `external pure`.

`SwapHeader` (`:20-27`) carries no payload/payloadLength; those are the second arg. `encodeSwapData`
is **byte-for-byte identical in every implementation** — an on-chain encoder for off-chain/OMS
callers, never used by `_buildHookExecutions`. Copy `SwapKyberSwapHook.sol:183-193` verbatim.

Offsets from `CORE/src/libraries/SwapCalldataLayout.sol`: `HEADER_SIZE=52`, `INPUT_TOKEN=52`,
`OUTPUT_TOKEN=72`, `INPUT_AMOUNT=92`, `OUTPUT_QUOTE=124`, `OUTPUT_MIN=156`, `USE_PREV_HOOK=188`,
`PAYLOAD_LENGTH=189`, `PAYLOAD_DATA=221`, `MIN_DATA_LENGTH=221`, `AMOUNT_POSITION=INPUT_AMOUNT`.

## Closest template is OpenOcean, not KyberSwap

`CORE/src/hooks/swappers/openocean/SwapOpenOceanHook.sol` is the opaque-calldata aggregator with
**no ScaleHelper** — our exact situation. It:
- binds **both** tokens (`INPUT_TOKEN_MISMATCH` + `OUTPUT_TOKEN_MISMATCH`, `:120-121`)
- rejects zero amounts (`:111`)
- pins a constructor `referrer` and validates it inside the calldata
- pushes re-encoding into `CORE/src/libraries/OpenOceanDynamicAmountUpdater.sol:33`, with
  `INVALID_SELECTOR`, `INVALID_DST_RECEIVER`, `PARTIAL_FILL_NOT_ALLOWED` guards at `:44-55`

That last set is live precedent for selector + receiver + partial-fill validation on an opaque blob.
We cannot replicate it without a stable Binance ABI, which is why D2 validates the outcome instead —
but the spec should note the gap explicitly rather than implying no sibling does better.

Also: `CORE/src/vendor/okx/` + `CORE/test/mocks/unused-hooks/SwapOkxHook.sol` is an established
parking spot for a written-but-not-shipped aggregator hook.

## Existing internal guidance (read before implementing)

- **`CORE/specs/knowledge/integration-issues/adding-dex-swap-hooks.md`** — a literal checklist for
  this task: create `src/hooks/swappers/<dex>/`, `BaseHook(NONACCOUNTING, SWAP)`,
  `ISuperHookContextAware`, `inspect()` returning the output token, a `_getBalance()` helper,
  deadline + data-length validation, and **force recipient to `account`, never from data**.
  Documents three native strategies and recommends the NATIVE sentinel. Recommends
  `HookDataUpdater.getUpdatedOutputAmount()` for proportional `amountOutMin` scaling.
- **`CORE/specs/knowledge/aggregator-amount-scaling.md`** — the `usePrevHookAmount` hazard matrix for
  opaque calldata (Odos LOW, Kyber+ScaleHelper LOW, Kyber fallback MEDIUM, 1inch generic `swap`
  MEDIUM-HIGH, 0x NONE). ScaleHelper `0x2f577A41BeC1BE1152AeEA12e73b7391d15f655D` is the same on all
  chains, `getScaledInputData` is a **view** with a **±5% window**, returns `isSuccess=false` for
  non-scalable sources. Recommendation #4: re-quote when delta > 5% rather than patch calldata.
  Recommendation #5: **never set `minReturnAmount = 0`** — independent support for D6.
- **Spec convention** lives in `CORE/specs/<feature>/` — see `CORE/specs/kyberswap-hook/` and
  `CORE/specs/odos-v3-hook/`. `technical-spec.md` ends with a "Modified Files" section enumerating
  exactly the deploy/test files touched (`odos-v3-hook/technical-spec.md:245-285`).
- **Security report convention**: `CORE/specs/security-reports/YYYY-MM-DD-<feature>.md`, format
  Metadata / severity table / Verdict (P1 blocks merge) / P1-P3 findings. Precedents:
  `2026-03-13-kyberswap-hooks.md`, `2026-05-21-odos-v3-hooks.md`.

## Testing

Two tiers, no `test/fork/` dir:
- **Unit** — `CORE/test/unit/hooks/swappers/<proto>/<Proto>UnitTests.t.sol`, `is Helpers`, mock router
  in-file or in `CORE/test/mocks/`. e.g. `KyberSwapUnitTests.t.sol:18` (717 lines, both variants).
- **Integration/fork** — `CORE/test/integration/<proto>/<Name>.t.sol`. Suffixes
  `...HookIntegration.t.sol` / `...E2E.t.sol` / `...Fork.t.sol`. **No block pinned** (latest), required
  for live API routes to be executable. No `onlyEthereum`/`onlyBase` modifiers exist anywhere.

Fork setup is either direct `vm.createSelectFork(vm.envString(BASE_RPC_URL_KEY))`
(`KyberSwapBaseNativeE2E.t.sol:41-47`) or `MinimalBaseIntegrationTest.t.sol:28` with a
`blockNumber` the child sets before `super.setUp()` (Odos; all use `0` = latest).

**API parsers** in `CORE/test/utils/parsers/` — `BaseAPIParser.sol` (`toChecksumString`, `fromHex`),
`OdosAPIParser.sol:14`, `OdosV3APIParser.sol:13`, `KyberSwapAPIParser.sol:14`
(`surlCallRoutes`/`surlCallBuild`, `X-Client-Id: superform`), `OneInchAPIParser.sol`,
`OpenOceanAPIParser.sol`, `UniswapV4Parser.sol`. **A `BinanceAPIParser.sol` must be added here.**

Two resilience idioms worth copying: a retry loop with `vm.snapshotState()` per attempt
(`MAX_RETRIES=5`, `KyberSwapBaseNativeE2E.t.sol:34,85`), and `vm.skip(true)` on API failure via an
`external` getter so `try/catch` works (`OdosV3RouterSwapFork.t.sol:38-73`).

Hook-data builder: `CORE/test/utils/InternalHelpers.sol:141` `_swapHookLayer1(...)`, with per-protocol
wrappers at `:265`/`:290`. **No Kyber helper exists** — each Kyber test rolls its own
(`KyberSwapUnitTests.t.sol:579`). Add a Binance wrapper rather than repeating that.

Execution-count assertions: **3** for `Swap*` (pre + swap + post), **6** for `ApproveAndSwap*`
(pre + approve(0) + approve(amt) + swap + approve(0) + post) — `OdosV3UnitTests.t.sol:101`,
`KyberSwapBaseNativeE2E.t.sol:112`. Ours is 6.

`ffi = true` is **global** in `CORE/foundry.toml`, so surl tests run under plain `forge test`.
`CORE/Makefile:35` `ftest-ci` excludes only Flare tests — **swap fork tests run in CI**, so a live
Binance API test will too. Plan for flakiness or gate it.

## Deployment & registration

Hooks deploy from **v2-core only** — `PERI/script/DeployV2Periphery.s.sol` deploys zero hooks.

Newer path is `CORE/script/DeployV2OtherHooks.s.sol` ("hook families"): add a `_deployBinanceHooks`
alongside `:1252-1282` `_deployOdosV3Hooks`, gated data-driven in `_deployAllHooks` (`:285`,
pattern at `:363`), with a `runBinance(uint256 env, uint64 chainId)` entrypoint (cf. `:260`).
Bytecode comes from `script/locked-bytecode/` (`:375`), regenerated by
`CORE/script/run/regenerate_bytecode.sh` — the contracts array must list the new hook. Deploy via
`CORE/script/run/deploy/deploy_v2_other_hooks_staging_prod.sh` with `TARGET_FAMILY=Binance`.

Ctor args per chain: declare in `CORE/script/utils/ConfigOtherHooks.sol:75-83` +
`ConstantsOtherHooks.sol` (cf. Odos V3 at `ConfigCore.sol:232-247`).

**Registry** — `PERI/src/SuperGovernor.sol:37` `_registeredHooks`; `:366` `registerHook(address)`
`onlyRole(_GOVERNOR_ROLE)`. Enforced by SuperVault (`SuperVaultStrategy.sol:286`) and SuperBank
(`SuperGovernor.sol:599,612`) but **not** by SuperExecutor (`SuperExecutorBase.sol:115` does
structural validation only). Register via `PERI/script/ConfigureV2Periphery.s.sol:637`; the allowlist
is a hardcoded array at `:512-573` — append the JSON key, "nothing else needs to change" (`:511`).
Note `SwapOdosV3Hook` is currently **absent** from that list.

### BSC / chain 56 needs no new plumbing
- `BNB_CHAIN_ID = 56` in both repos; chain-name map `ConfigBase.sol:219`
- Routers already configured for 56: Odos V2/V3, Kyber router + scale helper, 1inch, UniV3 Router02
- **Swap hooks already deployed on BSC prod** (`CORE/script/output/prod/56/BNB-latest.json`):
  `SwapKyberSwapHook 0x05c49e05bb8575afdf1142cC95dA6747b069174A`, both Odos V2/V3 pairs,
  `Swap1InchHook`, `SwapUniswapV3Router02Hook`. 9 of 24 SWAP hooks carry a prod address on 56.
- Gaps: `PERI/script/run/networks-production.sh:13` has the BSC line **commented out** (only Arc 5042
  active), though `get_rpc_var` case 56 at `:98-100` is live; and
  `PERI/script/superbank-roots/generated/prod/` has `1/`, `8453/`, `999/` but **no `56/`** — SuperBank
  roots have never been generated for BSC. Neither `.env.example` mentions BSC.

### Two CI-enforced manifests
- **`CORE/hook-sizing-manifest.json`** — `{hookKey, mode, pipeMode, ...}`. Modern swap hooks are
  `replaceCalldata` + `transform`. **D12 is the open question here**: `replaceCalldata` would let the
  OMS rewrite Layer-1 `inputAmount` and desync it from the opaque blob. `sizeless` is the candidate.
  Generator `CORE/tooling/generate-hook-sizing-manifest.ts`; validator asserts every `*HOOK*KEY` in
  `Constants.sol`/`ConstantsOtherHooks.sol` has an entry.
- **`CORE/manifests/hooks.json`** — built by `CORE/tooling/generate_hook_manifest.py` from
  `tooling/hook-classification.yaml` (`:293-299` for swap: `actionTypes: [{intent: swap, stage: instant}]`,
  `legSizing: [sized]`) + `tooling/hook-enrichment.yaml` (`:88-89` `compatibleProtocols`, `:209` the
  `Swap→ApproveAndSwap` pairing map) + deploy output JSONs.

**CI gate**: `CORE/.github/workflows/contracts-ci.yml:333-350` regenerates both, validates, then
`git diff --quiet` and fails if stale.

Also hand-maintained: `CORE/CHANGELOG-hook-descriptions.md`, `CORE/CHANGELOG-hook-sizing.md`, and
`PERI/script/superbank-roots/config/deployments.json` (a separate hook-name→address snapshot).

## Conventions

- **Errors** — SCREAMING_SNAKE, no `Error` suffix, under an `ERRORS` banner, each with
  `/// @notice Thrown when ...`. From `BaseHook.sol:90-122`: `ADDRESS_NOT_VALID`, `AMOUNT_NOT_VALID`,
  `INVALID_AMOUNTS_LENGTH`, etc. Family vocabulary: `OUTPUT_TOKEN_MISMATCH`, `SAME_INPUT_OUTPUT_TOKEN`,
  `INPUT_TOKEN_MISMATCH`, `ZERO_EXECUTION_AMOUNT`, `INVALID_HOOK_DATA`, `EXPIRED_DEADLINE`,
  `NATIVE_ETH_NOT_SUPPORTED`, `EXCESSIVE_SLIPPAGE_DEVIATION`.
- **Types** — every swap hook is `BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP)`.
  `_pipeMode()` defaults to `TRANSFORM` (`BaseHook.sol:347`); no swapper overrides it.
  `_supportsSizingInterface()` returns `true`. `amountRoles` returns a single
  `AmountMeta(Direction.IN, Denomination.TOKEN)`.
- **Balance delta** — universal: `_preExecute` sets `balanceBefore`; `_postExecute` sets
  `balanceAfter - before` and `_setOutToken`. Aerodrome adds the underflow guard
  `if (finalBalance < initialBalance) revert AMOUNT_NOT_VALID();` — we use a named error instead.
- `CORE/CLAUDE.md` (= `AGENTS.md`) opens with a non-negotiable instruction to have the
  `superform-hook-master` subagent plan hook features before creating them, and to keep
  `.claude/sessions/context_session_x.md` updated. Style: solc 0.8.30, explicit visibility, NatSpec on
  all public/external, **custom errors not revert strings**, events for state changes, CEI.
