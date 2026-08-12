# Repo analysis — Pendle PT record hooks + `IPendlePTHookResult`

Grounding research for a feature that adds two hooks (`RecordPurchasePendlePTHook`,
`RecordRedemptionPendlePTHook`) recording into `PendlePTAmortizedOracleV2`, and extends
`PendlePTHook` with an `IPendlePTHookResult` interface (an `Operation` enum
`BUY_PT`/`SELL_PT`/`REDEEM_PT` and a `TradeResult` struct
`market/inputToken/outputToken/inputAmount/outputAmount`) populated from real execution
balance deltas.

Repo: `/Users/cosming/1.Coding/Superform/v2-core` (Solidity 0.8.30, Foundry). All paths absolute.

---

## 1. Hook result / context mechanism

### Interfaces (`src/interfaces/ISuperHook.sol`)
- `ISuperHookResult` — every hook exposes it via `BaseHook`. Methods:
  `hookType()`, `spToken()`, `asset()`, `getOutAmount(address caller)` (line 81),
  `getOutToken(address caller)` (line 89). `getOutAmount`/`getOutToken` are **per-caller
  context** reads. This is the interface the next hook calls to chain amounts.
- `ISuperHookSetter.setOutAmount(uint256,address)` — `src/interfaces/ISuperHook.sol:34-40`.
- `ISuperHookContextAware.decodeUsePrevHookAmount(bytes)` — lines 96-102. Marks a hook that
  can read the previous hook's output.
- `ISuperHookInflowOutflow` (lines 108-151) — the "sizing" interface: `Direction{IN,OUT}`,
  `Denomination{TOKEN,ASSETS,SHARES}`, `struct AmountMeta{dir,denom}`, `decodeAmounts(bytes)`,
  `amountRoles(bytes)`. `ISuperHookOutflow.replaceCalldataAmounts` at 157-169.
- Note: there is **no existing `ISuperHookResult`-style struct carrier**. The new
  `IPendlePTHookResult` (Operation enum + TradeResult struct + a getter) is a *new sibling
  interface* — it should live in `src/interfaces/` (e.g. new file or appended to
  `ISuperHookSwap.sol`), mirroring how `ISuperHookSwap` is a standalone swap-family interface
  (`src/interfaces/ISuperHookSwap.sol`).

### `BaseHook` context machinery (`src/hooks/BaseHook.sol`)
- Storage is **transient** (EIP-1153 `tstore`/`tload`). Base transient vars: `usedShares`,
  `spToken`, `asset`, `executionNonce`, `lastCaller` (lines 35-49).
- Per-account context key: `_makeAccountContextKey(account) = keccak256(ACCOUNT_CONTEXT_STORAGE, account)`
  (line 362-364). `setExecutionContext(caller)` → `_createExecutionContext` **increments
  `executionNonce`** and stores it under the account key (lines 142-145, 366-378). So the
  "context" is a monotonically increasing nonce, one per execution, keyed by account.
- Value slots keyed by `_makeKey(context, offset) = keccak256(HOOK_EXECUTION_STORAGE, context, offset)`
  (line 387-389). Offsets: `OUT_AMOUNT_OFFSET=1`, `PRE_EXECUTE_MUTEX_OFFSET=2`,
  `POST_EXECUTE_MUTEX_OFFSET=3`, `OUT_TOKEN_OFFSET=4` (lines 52-55). **A TradeResult needs
  new offsets (5,6,7,...) or a packed encoding under one offset** — this is the extension
  point for storing `operation/inputToken/inputAmount/outputAmount` alongside the existing
  outAmount/outToken.
- `getOutAmount(caller)` → `_getOutAmount(_getCurrentExecutionContext(caller))` (lines 216-218);
  `getOutToken` likewise (220-222). `_setOutAmount`/`_setOutToken` write via `tstore`
  (lines 354-360, 405-411).
- Lifecycle: `build()` (lines 149-183) wraps hook executions as `[preExecute, ...hookExecutions, postExecute]`.
  `preExecute`/`postExecute` (lines 186-201) gate on `msg.sender == account`, set the
  pre/post mutexes, then call the virtual `_preExecute`/`_postExecute`.
- `setOutAmount` external setter is **blocked once pre or post mutex is set** (lines 204-214,
  `CANNOT_SET_OUT_AMOUNT`).
- **Clearing between executions:** `resetExecutionState` (lines 225-232, `onlyLastCaller`)
  only resets the pre/post mutexes via `_clearExecutionState` (lines 441-444). The
  outAmount/outToken tstore values are **not explicitly cleared**, but (a) they are transient
  and wiped at end-of-tx, and (b) each new execution increments `executionNonce`, so the
  `_makeKey(context,...)` for a new execution points at fresh (zero) slots — stale values are
  unreachable. Any new TradeResult slots inherit this same safety, so no extra clearing logic
  is required as long as they are keyed by `context`.

### `usePrevHookAmount` chaining
- Consumer side, `RecordPurchasePendlePTAmortizedOracleHookV2._buildHookExecutions`
  (`src/hooks/oracles/pendle/RecordPurchasePendlePTAmortizedOracleHookV2.sol:100-105`):
  ```solidity
  bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
  if (usePrevHookAmount) {
      ptAmount = ISuperHookResult(prevHook).getOutAmount(account);
  }
  ```
  The redemption V2 hook is identical at `RecordRedemptionPendlePTAmortizedOracleHookV2.sol:98-103`.
- Producer side, `PendlePTHook._pre/_postExecute`
  (`src/hooks/swappers/pendle/PendlePTHook.sol:347-355`):
  ```solidity
  function _preExecute(address, address account, bytes calldata data) internal override {
      _setOutAmount(_getBalance(account, data), account);
  }
  function _postExecute(address, address account, bytes calldata data) internal override {
      _setOutAmount(_getBalance(account, data) - getOutAmount(account), account);
      _setOutToken(BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET), account);
  }
  ```
  So `getOutAmount(account)` after post = **output-token balance delta**; `getOutToken` = the
  header output token. This is exactly what the two record hooks read via `usePrevHookAmount`.
- **Key design consequence for the feature:** the current producer only snapshots the
  **output** token (`_getBalance` reads `OUTPUT_TOKEN_OFFSET`, see §2). To populate
  `TradeResult.inputAmount` from an *actual* balance delta, `PendlePTHook` must also snapshot
  the **input** token in `_preExecute` and diff it in `_postExecute`. That input-delta plus the
  existing output-delta fully populate `TradeResult`.

---

## 2. `PendlePTHook` (`src/hooks/swappers/pendle/PendlePTHook.sol`)

- Contract decl / inheritance: line 76 —
  `is BaseHook, ISuperHookSwap, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow`.
  Constructed `BaseHook(HookType.NONACCOUNTING, HookSubTypes.PTYT)` (line 148).
- **Header layout** documented at lines 62-71 and enforced via `SwapCalldataLayout` (see §4):
  `inputToken@52`, `outputToken@72`, `inputAmount@92`, `outputQuote@124`, `outputMin@156`,
  `usePrevHookAmount@188`, `payloadLength@189`, `payload@221`.
- **Operation routing** in `_buildHookExecutions` (lines 167-230). It calls
  `IPendleMarket(yieldSource).readTokens()` once → `(sy, pt, yt)` (line 202), then:
  - `headerOutputToken == pt && headerInputToken != pt` → **buy** (`swapExactTokenForPt`),
    lines 208-213 → `_buildSwapTokenForPtExecutions`.
  - `headerInputToken == pt && headerOutputToken != pt`:
    - `!IPYieldToken(yt).isExpired()` → **sell** (`swapExactPtForToken`), lines 215-220 →
      `_buildSwapPtForTokenExecutions`.
    - else → **redeem** (`redeemPyToToken`), lines 221-226 → `_buildRedeemExecutions`.
  - else → `revert INVALID_PT_OPERATION()` (line 228).
  This three-way branch is the exact source of truth for the `Operation` enum
  (`BUY_PT`/`SELL_PT`/`REDEEM_PT`). Doc comments at lines 50-56 spell out the same routing,
  including the expiry edge case (at exact expiry `isExpired()` is true → redeem).
- **outAmount from balance deltas:** `_getBalance(account, data)` (lines 628-636) reads the
  **output** token at `SwapCalldataLayout.OUTPUT_TOKEN_OFFSET`; native (`address(0)` or the
  `0xEeee…` sentinel `NATIVE_TOKEN`, line 97) → `account.balance`, else `IERC20.balanceOf`.
  Pre snapshots the balance, post subtracts (lines 347-355).
- **`readTokens()` usage:** single call at line 202; `sy==0` reverts `SY_NOT_VALID` (line 203);
  `pt`/`yt` reused across the three builders. Trust note lines 72-75: market is trusted from the
  signed intent, `readTokens()` could return attacker addresses if a bad market is signed.
- **Where to add input-token snapshotting:** add a sibling of `_getBalance` that reads
  `SwapCalldataLayout.INPUT_TOKEN_OFFSET` (normalizing the native sentinel the same way the buy
  path does at lines 392-394). Snapshot input balance in `_preExecute` (store under a new
  transient offset) and compute `inputDelta = preInput - postInput` in `_postExecute`, then
  persist the full `TradeResult{operation, market(=yieldSource), inputToken, outputToken,
  inputAmount=inputDelta, outputAmount=outputDelta}`. `market` = `HookDataDecoder.extractYieldSource(data)`
  (used at line 177, and re-exposed by `inspect()` line 284). Note the buy path spends the input
  and the sell/redeem path spends PT — in all three cases the **input token decreases**, so a
  simple `pre - post` delta on the header input token is correct.
- Existing decode/`ISuperHookSwap` accessors (lines 289-341) and the `AMOUNT_POSITION` alias
  (line 102 = `SwapCalldataLayout.AMOUNT_POSITION` = 92) can be reused by the record hooks if
  they read from the same header, but see §5 — the record hooks use their **own** compact layout.

---

## 3. `PendlePTAmortizedOracleV2` (`src/accounting/oracles/PendlePTAmortizedOracleV2.sol`)

- `recordPurchase(address market, uint256 ptBought, uint32 twapDuration)` — lines 165-208.
  - Guards: `market!=0`, `ptBought!=0`, and **`twapDuration >= getMinTwapDuration(market)`**
    else `TWAP_DURATION_TOO_SHORT` (line 169).
  - Reads `(, pt,) = IPMarket(market).readTokens()`, `maturity = pt.expiry()`, reverts
    `MARKET_EXPIRED` if `block.timestamp >= maturity` (lines 172-174).
  - **On-chain PT→SY cost calc** (lines 176-181):
    ```solidity
    uint256 ptToSyRate = IPMarket(market).getPtToSyRate(twapDuration);
    uint256 sySpent   = ptBought.mulDiv(ptToSyRate, 1e18);
    ```
    Uses `getPtToSyRate` (NOT `getPtToAssetRate`) because book value is in SY terms
    (1 PT = 1 SY at maturity) — explained lines 158-160, 177-179.
  - Derives `previousPtBalance = currentPtBalance - ptBought` from live PT balance
    (lines 184-185); amortizes existing book value and adds `sySpent`, or sets it for first
    purchase (lines 187-198); sanity `newBookValue <= currentPtBalance` else
    `BOOK_VALUE_EXCEEDS_FACE_VALUE` (line 201); writes packed `BookValueState` (lines 203-204);
    emits `PurchaseRecorded` + `BookValueUpdated` (lines 206-207).
  - `msg.sender` is recorded as `strategy` (line 166) — i.e. the **caller of the hook execution
    (the account)**, so the record hook's oracle call must be a direct execution to the oracle
    (it is — see §5 pattern).
- `recordRedemption(address market, uint256 ptSold)` — lines 214-242. Guards `market!=0`,
  `ptSold!=0`; requires an existing position (`state.lastUpdateTime==0` → `NO_POSITION`,
  line 220). Derives `previousPtBalance = currentPtBalance + ptSold` (line 228), amortizes,
  reduces book value proportionally: `costBasis = currentBookValue.mulDiv(ptSold, previousPtBalance)`,
  `newBookValue = currentBookValue - costBasis` (lines 234-235). **No `twapDuration` param.**
- **TWAP minimum enforcement:** `DEFAULT_MIN_TWAP_DURATION = 300` (line 45),
  `DEFAULT_TWAP_DURATION = 900` (line 40). `marketMinTwapDuration[market]` per-market override
  (line 71); `getMinTwapDuration(market)` returns the override if `>0` else the 300s default
  (lines 336-339). `setMinTwapDuration` is `MANAGER_ROLE` gated (lines 325-331). This is the
  floor that the new `RecordPurchasePendlePTHook` must satisfy when it passes `twapDuration`.
- Access control: `AccessControl`, `MANAGER_ROLE` (line 37); admin corrections
  `correctBookValue`/`deletePosition` (lines 275-318). Constructor takes `(admin, superLedgerConfiguration_)`
  (lines 139-150).
- Vendor interfaces:
  - `src/vendor/pendle/IPendlePTAmortizedOracleV2.sol` declares
    `recordPurchase(address,uint256,uint32)` and `recordRedemption(address,uint256)` — the
    exact selectors the record hooks encode against.
  - `src/vendor/pendle/IPendlePTAmortizedOracle.sol` (V1) has a different purchase signature:
    `recordPurchase(address market, uint256 sySpent, uint256 ptAmount)` (line 14) — do **not**
    use for V2.

---

## 4. Hook conventions (52-byte header, inspect, S2 sizeless, PipeMode)

- **52-byte strategy header + Layer1/Layer2:** `src/libraries/SwapCalldataLayout.sol`.
  `HEADER_SIZE=52` (line 10). Layer-1 offsets 52…221 (lines 14-35). `MIN_DATA_LENGTH=221`
  (line 40), `AMOUNT_POSITION = INPUT_AMOUNT_OFFSET = 92` (line 43). The generic
  (non-swap) 52-byte header convention is also documented inline in each record hook, e.g.
  `RecordPurchasePendlePTAmortizedOracleHookV2.sol:29-35`
  (`placeholder0@0`, `placeholder1@32`, `market@52`, `ptAmount@72`, `twapDuration@104`,
  `usePrevHookAmount@108`).
- **`inspect()` market-only commitment:** `PendlePTHook.inspect` returns just the yieldSource
  (`abi.encodePacked(HookDataDecoder.extractYieldSource(data))`, lines 283-285, comment
  "market lock is direction-agnostic"). The record V2 hooks return only `market@52`
  (`RecordPurchasePendlePTAmortizedOracleHookV2.sol:150-154`). New record hooks should commit
  the same single field.
- **S2 "sizeless" metadata pattern (exemplar):**
  `src/hooks/oracles/pendle/RecordPurchasePendlePTAmortizedOracleHookV2.sol` is the canonical
  S2 hook to copy:
  - `decodeAmounts` returns length-0 (lines 156-159); `amountRoles` returns length-0 (161-164).
  - `supportsInterface` (lines 166-174): returns **true** for `ISuperHookInflowOutflow` but
    **false** for `ISuperHookOutflow`, plus the base four (`IERC165`, `ISuperHook`,
    `ISuperHookResult`, `ISuperHookInspector`). This is the "S2 authoritatively sizeless"
    state described in `BaseHook.supportsInterface` docs (`BaseHook.sol:246-261`): S1 = has
    sizing iface; S2 = S1 but `amountRoles(data).length == 0`; S3 = legacy no sizing iface.
  - It does **not** override `_supportsSizingInterface()` — it overrides `supportsInterface`
    directly. (Contrast `PendlePTHook` which is a *sized* hook: it returns real
    `decodeAmounts`/`amountRoles` of length 1 and sets `_supportsSizingInterface()=>true`,
    `PendlePTHook.sol:241-255,272-278`.)
- **`PipeMode.PASSTHROUGH`:** enum in `BaseHook.sol:65-69` (`TRANSFORM` default, `PASSTHROUGH`,
  `SOURCE`). Side-effect-only hooks override `_pipeMode()` to `PASSTHROUGH`
  (`RecordPurchasePendlePTAmortizedOracleHookV2.sol:177-179`). The base `_preExecute`
  auto-forwards the prev hook's `outAmount`+`outToken` when `PASSTHROUGH` and `prevHook!=0`
  (`BaseHook.sol:293-298`). The new record hooks should be `PASSTHROUGH` too, so they don't
  clobber the chain's outAmount for any downstream hook.
- Both record hooks use `HookSubTypes.PTYT` as subtype (`...HookV2.sol:66`).

---

## 5. Hook-registry / OMS normalization

Two manifests + tooling drive registry/OMS:

### `manifests/hooks.json` (generated)
- Header: `"$schema":"hook-manifest-v1"`, `generatedAt`, and a `vocabulary` of `intents`/`stages`
  (`manifests/hooks.json:1-40`). Each hook entry has `name`, `description`, `hookType`,
  `subtype`, `actionTypes[{intent,stage}]`, `legSizing`, and per-env `addresses`/`availableChains`.
- Existing Pendle entries (grep): `PendlePTHook` (line 4676), `RecordPurchasePendlePTAmortizedOracleHookV2`
  (line 8143), `RecordRedemptionPendlePTAmortizedOracleHookV2` (line 8311), plus V1 record hooks
  (8059, 8227) and `PendleUnifiedHook`/`PendleRouterRedeemHook`/`PendleRouterSwapHook`.
- **Generator:** `tooling/generate_hook_manifest.py`. It composes from
  (1) `tooling/hook-classification.yaml` (actionTypes + legSizing), (2)
  `script/output/{staging,prod}/{chainId}/*-latest.json` deployed addresses, and (3)
  `src/hooks/**/*Hook.sol` parsed fields (docstring lines 1-30). Also reads
  `tooling/hook-enrichment.yaml`. `SUBTYPE_MAP`/`HOOK_TYPE_MAP` at lines ~35-70.
- **To add a new hook here:** add an entry in `tooling/hook-classification.yaml` and regenerate.
  Pendle classification block is at `tooling/hook-classification.yaml:346-361`:
  ```yaml
  PendlePTHook:
    actionTypes: [{intent: swap, stage: instant}]
    legSizing: [sized]
  ```
  and the sizeless record hooks at 603-615 (`legSizing: []  # sizeless — oracle recording`).
  The new `RecordPurchasePendlePTHook`/`RecordRedemptionPendlePTHook` should be added there with
  `legSizing: []` (sizeless).

### `hook-sizing-manifest.json` (OMS sizing/splicing source of truth)
- Entries are `{hookKey, mode, pipeMode, [amountPosition], [reason], ...}`. Pendle section at
  `hook-sizing-manifest.json:480-519`:
  - `PENDLE_PT_HOOK_KEY` → `mode:"replaceCalldata"`, `pipeMode:"transform"` (480-483).
  - `RECORD_PURCHASE_PENDLE_PT_AMORTIZED_ORACLE_HOOK_V2_KEY` and the redemption V2 →
    `mode:"sizeless"`, `pipeMode:"passthrough"` (507-519). This is the template for the two new
    record hooks.
  - Contrast `PENDLE_ROUTER_SWAP/REDEEM` → `mode:"external"` with a `reason` (they hide the
    amount inside ABI-encoded/aggregator calldata; the OMS must not splice).
- **Generator:** `tooling/generate-hook-sizing-manifest.ts`.
  - `ManifestEntry` type: `mode: "offset"|"replaceCalldata"|"sizeless"|"external"`,
    `pipeMode: "transform"|"passthrough"|"source"` (lines 20-29).
  - Step 1 extracts hook keys from `script/utils/Constants.sol` &
    `script/utils/ConstantsOtherHooks.sol` via regex `(\w+HOOK\w*KEY)` (lines ~40-60).
  - Auto-detection: `replaceCalldataAmount` presence → outflow/replaceCalldata (line 93);
    `detectPipeMode` greps the hook source for `PipeMode.PASSTHROUGH` → `passthrough` else
    `transform` (lines 100-113).
  - Hand-curated `OVERRIDES` map (line 140+) explicitly marks the record hooks sizeless:
    ```
    RecordPurchasePendlePTAmortizedOracleHookV2: { mode: "sizeless" },   // line 175
    RecordRedemptionPendlePTAmortizedOracleHookV2: { mode: "sizeless" }, // line 176
    PendleRouterSwapHook: { mode: "external", reason: "amount inside aggregator txData" }, // 183
    PendleRouterRedeemHook: { mode: "external", reason: "TokenOutput ABI-encoded struct" }, // 184
    ```
  - **To add new schemas:** (1) add hook-key constants in `script/utils/Constants.sol`
    (Pendle block at `Constants.sol:222-232`), (2) add a `sizeless` `OVERRIDES` line in the
    `.ts`, (3) add classification/enrichment YAML, (4) regenerate both manifests. Validation:
    `tooling/validate-hook-sizing-manifest.ts` and `tooling/lint_hook_manifest.py`.
- **Automatic vs manual (usePrevHookAmount) representation:** "automatic" sized hooks carry an
  `amountPosition`/`replaceCalldata` (OMS rewrites the amount in calldata). `usePrevHookAmount`
  hooks are `sizeless` + `passthrough` — the OMS does not size them; they consume the previous
  hook's `getOutAmount` at build time. Both new record hooks are the latter.

---

## 6. Deployment scripts

### Where these hooks deploy
`PendlePTHook` and the record-oracle hooks are **core** hooks, deployed by
`script/DeployV2Core.s.sol` (NOT `DeployV2OtherHooks.s.sol`, which handles Morpho/Aave/DETH/etc.).

- Hook-key constants: `script/utils/Constants.sol:222-232`
  (`PENDLE_PT_HOOK_KEY="PendlePTHook"`, `RECORD_PURCHASE_PENDLE_PT_AMORTIZED_ORACLE_HOOK_V2_KEY`,
  `RECORD_REDEMPTION_PENDLE_PT_AMORTIZED_ORACLE_HOOK_V2_KEY`).
- `PendlePTHook` deploy (gated on Pendle router availability):
  `DeployV2Core.s.sol:3782-3789`:
  ```solidity
  hooks[80] = _createSafeHookDeploymentWithArgs(
      PENDLE_PT_HOOK_KEY, "PendlePTHook", env, abi.encode(configuration.pendleRouters[chainId]));
  ```
- Record V2 hooks deploy (gated on oracle V2 existing), passing the **oracle address** as the
  ctor arg: `DeployV2Core.s.sol:3614-3636`:
  ```solidity
  hooks[46] = _createSafeHookDeploymentWithArgs(
      RECORD_PURCHASE_PENDLE_PT_AMORTIZED_ORACLE_HOOK_V2_KEY,
      "RecordPurchasePendlePTAmortizedOracleHookV2", env,
      abi.encode(configuration.pendlePTAmortizedOraclesV2[chainId]));
  hooks[47] = _createSafeHookDeploymentWithArgs(
      RECORD_REDEMPTION_PENDLE_PT_AMORTIZED_ORACLE_HOOK_V2_KEY, ... );
  ```
  The oracle address comes from `_deployOracles` populating
  `configuration.pendlePTAmortizedOraclesV2[chainId]` (`DeployV2Core.s.sol:4593`,
  oracle deployed at 4494 via `PENDLE_PT_AMORTIZED_ORACLE_V2_KEY`, index 9 asserted 4586-4592).
  There is also a temporary fixed-scope Pendle upgrade entrypoint at 1081-1200
  (`require(env==0, "TEMPORARY_PENDLE_HOOK_UPGRADE_INVALID_ENV")`).
- The `DeployV2OtherHooks.s.sol` pattern (for reference) mirrors the same helpers:
  `__getOtherHooksBytecode(name, env)` reads from `script/locked-bytecode/` (lines 252-261),
  `HookDeployment{name, saltOverride, creationCode}` (lines 90-94), constructor args appended
  via `abi.encodePacked(bytecode, abi.encode(arg))` (e.g. Algebra 557-568), and each hook is
  CREATE2-deployed via `__deployContract(name, chainId, __getSalt(saltName), creationCode)`
  (lines 333-337). Its `run(env, chainId, saltNamespace)` overloads at 104-114 map
  `env 0/2 = production, 1 = test` (comment lines 96-98).

### STAGING vs PROD separation (critical)
- **`env` param semantics** (`DeployV2Core.s.sol:324-325`, and `DeployV2Base.s.sol` docs):
  `0 = prod`, `1 = vnet/dev`, `2 = staging`. Repeated in `_setConfiguration(env_, saltNamespace_)`
  (`DeployV2Core.s.sol:326-332`) and `runLedgerConfigurations` logging
  (`env==0?"Production":env==1?"VNET":"Staging"`, line 1477/1515).
- **Bytecode dir by env** — `DeployV2Base.s.sol`:
  `BYTECODE_DIRECTORY="script/locked-bytecode/"` (line 20),
  `BYTECODE_DEV_DIRECTORY="script/locked-bytecode-dev/"` (line 21).
  `__getBytecodeArtifactPath(name, env)` returns locked-bytecode for `env==0`, else
  locked-bytecode-dev (lines 401-410) — so **prod uses locked-bytecode/, staging(2)+vnet(1)
  use locked-bytecode-dev/**. `__getBytecode` wraps it with an existence check (416-425).
- **Salt namespace / CREATE2 address separation** — `DeployV2Base.s.sol:391-395`:
  ```solidity
  function __getSalt(string memory name) internal view returns (bytes32) {
      return keccak256(abi.encodePacked("SuperformV2", saltNamespace, name, "v2.0"));
  }
  ```
  `saltNamespace` is a member set by `_setBaseConfiguration(env_, saltNamespace_)`. Prod passes
  empty namespace (production default, comment at `DeployV2Core.s.sol:325`); staging/vnet pass a
  distinct namespace via the `run(env, chainId, saltNamespace)` overload
  (`DeployV2Core.s.sol:1413`, `DeployV2OtherHooks.s.sol:110`). Different namespace → different
  CREATE2 salt → **different deployed address** for the same bytecode, which is how STAGING and
  PROD addresses diverge. (Manifests reflect this: `manifests/hooks.json` stores separate
  `addresses.staging` vs `addresses.prod` maps, e.g. lines 45-78.)
- **Address constants** for external deps live in `script/utils/Constants.sol` (Pendle router
  etc.) and `script/utils/ConstantsOtherHooks.sol` (Morpho/WETH/WFLR/RNAT, lines 6-38). The new
  record hooks need **no new address constant** — they take the oracle address from
  `configuration.pendlePTAmortizedOraclesV2[chainId]` at deploy time.

### Bytecode regeneration
- `script/run/tooling/regenerate_bytecode.sh` runs `forge build` then copies
  `out/<Name>.sol/<Name>.json` → `script/generated-bytecode/<Name>.json`. The `HOOK_CONTRACTS`
  array already lists `PendlePTHook`, `RecordPurchasePendlePTAmortizedOracleHookV2`,
  `RecordRedemptionPendlePTAmortizedOracleHookV2` (and V1). **New hooks must be added to the
  `HOOK_CONTRACTS` array** in this script, and their `.json` placed under
  `script/locked-bytecode/` (prod) and `script/locked-bytecode-dev/` (staging/vnet) for the
  deploy scripts' `vm.getCode` to find them.

---

## 7. Existing Pendle tests to mirror

### Unit tests (mocked, non-fork)
- `test/unit/hooks/pendle/PendlePTHook.t.sol` — the model for extending `PendlePTHook`.
  Uses `Helpers` base, `MockPendleRouter`, `MockHook` (prevHook), `MockERC20`,
  `MockPendleMarket`, `MockYieldToken`, `MockStandardizedYield` (imports lines 4-29). Covers
  all three ops and edge cases: buy (`test_Build_BuyPt*` 107-273), sell (277-341), redeem
  (343-435), routing/expiry (`test_Build_ExpiryRouting_*` 463-493), min-out scaling
  (495-603), limit orders/fills (605-665), and `usePrevHookAmount`. New `TradeResult`/balance-delta
  behavior should add assertions here (the E2E asserts `getOutAmount` already — see below).
- `test/unit/hooks/oracles/pendle/RecordPurchasePendlePTAmortizedOracleHookV2.t.sol` — the model
  for the two **new** record hooks. Full read above; key patterns:
  - Mocks: `MockPendlePTAmortizedOracleV2` (`test/mocks/MockPendlePTAmortizedOracleV2.sol`) and
    `MockPendleRouterSwapHook` (`test/mocks/MockPendleRouterSwapHook.sol`) as prevHook with
    `setOutAmount(account, amount)`.
  - `build()` returns `[preExecute, hookExecution, postExecute]` (length 3); assert
    `executions[1].callData == abi.encodeCall(IPendlePTAmortizedOracleV2.recordPurchase, (...))`
    (lines 70-101).
  - `usePrevHookAmount` realistic flow (105-125), zero-guards (127-147), decode getters
    (153-183), `inspect` (189-193), pre/post no-op with `setExecutionContext` (199-220), fuzz
    (226-258), and `_encodeData` packing `bytes(52) + market + ptAmount + twapDuration + bool`
    (264-277).
  - Companion: `RecordRedemptionPendlePTAmortizedOracleHookV2.t.sol`,
    `RecordPurchasePendlePTAmortizedOracleHook.t.sol` (V1),
    `RecordRedemptionPendlePTAmortizedOracleHook.t.sol` (V1).
- Oracle unit tests: `test/unit/accounting/oracles/PendlePTAmortizedOracleV2.t.sol`,
  `PendlePTAmortizedOracleV1vsV2.t.sol`, using `test/unit/accounting/oracles/mocks/MockPendleContracts.sol`.

### Fork / integration tests (real Pendle Router V4 + real markets)
- `test/integration/pendle/PendlePTHookE2E.t.sol` — **the fork model.** Line 61:
  ```solidity
  vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"), 24_300_000);
  ```
  i.e. RPC from env var `ETHEREUM_RPC_URL`, **pinned block `24_300_000`**. Deploys the real
  hook against `PENDLE_ROUTER` mainnet address (line 63). Asserts post-execute
  `getOutAmount == actualReceived` for both token-out and PT-out paths (lines 508-546) — this is
  where the new `TradeResult`/inputAmount-delta assertions belong. Data builders at 700-821
  (`_buildBuyPtData`, `_buildSellPtData`, note "no selector prefix — routingParams IS the payload"
  comment line 742).
- `test/integration/hooks/oracles/pendle/PendlePTAmortizedOracleHooks.t.sol` — wires the record
  hooks to a real oracle on a fork. Line 44: `vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"))`
  (unpinned — pin a block for determinism if adding new cases).
- Other fork tests: `test/integration/pendle/PendleUnifiedHookE2E.t.sol`,
  `PendleUnifiedHookIntegration.t.sol`, `PendleRouterHookTests.t.sol`,
  `test/integration/oracles/PendlePTAmortizedOracle.t.sol`,
  `test/integration/accounting/price/PendlePriceIntegration.t.sol`.
- RPC env var is `ETHEREUM_RPC_URL` (foundry reads it from `.env`); pinned block numbers are
  hard-coded in each fork test's `setUp` (e.g. `24_300_000`).

---

## Extension-point summary for the spec

1. **`IPendlePTHookResult`** — new interface in `src/interfaces/` with
   `enum Operation{BUY_PT, SELL_PT, REDEEM_PT}`, `struct TradeResult{address market; address inputToken;
   address outputToken; uint256 inputAmount; uint256 outputAmount;}`, and a getter
   `getTradeResult(address account) returns (TradeResult, Operation)` (per-account context, mirror
   `getOutAmount`). Register its `interfaceId` in `PendlePTHook.supportsInterface`
   (`PendlePTHook.sol:272-278`).
2. **`PendlePTHook`** — add input-token snapshot in `_preExecute`, compute both input+output
   deltas in `_postExecute`, persist `TradeResult` under new transient offsets in `BaseHook`
   (extend the offset set at `BaseHook.sol:52-55`), and set `Operation` from the same
   routing branch used in `_buildHookExecutions` (`PendlePTHook.sol:208-228`). Keep existing
   `getOutAmount`=outputDelta / `getOutToken`=headerOutputToken behavior for backward compat.
3. **New record hooks** `RecordPurchasePendlePTHook` / `RecordRedemptionPendlePTHook` — copy
   `RecordPurchasePendlePTAmortizedOracleHookV2` / `...RedemptionV2` structurally (sizeless,
   PASSTHROUGH, PTYT subtype), but instead of reading `getOutAmount(prevHook)` scalar, read the
   richer `IPendlePTHookResult.getTradeResult(prevHook)` to source `ptBought`/`ptSold` (and
   `market`) from actual deltas. Purchase must pass a `twapDuration` satisfying
   `getMinTwapDuration(market)` (§3). Target the same `recordPurchase(address,uint256,uint32)` /
   `recordRedemption(address,uint256)` selectors on `PendlePTAmortizedOracleV2`.
4. **Registry/deploy plumbing** for each new hook: hook-key constant in
   `script/utils/Constants.sol`; entry in `tooling/hook-classification.yaml` (`legSizing: []`);
   `OVERRIDES` `sizeless` line in `tooling/generate-hook-sizing-manifest.ts`; add to
   `HOOK_CONTRACTS` in `regenerate_bytecode.sh` + locked-bytecode dirs; deploy block in
   `DeployV2Core.s.sol` passing the oracle address (mirror lines 3614-3636); regenerate
   `manifests/hooks.json` + `hook-sizing-manifest.json`.
5. **Tests** — unit test per new hook (mirror the V2 record-hook unit test), extend
   `PendlePTHook.t.sol` for `TradeResult`, and add fork coverage in the two Pendle integration
   files pinned to a block via `ETHEREUM_RPC_URL`.
