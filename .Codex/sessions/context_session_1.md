# Context Session 1

## Current request
- User asked to read the whole Oenocean/OneOcean implementation including hooks scaler.

## Notes
- `.Codex/sessions` did not exist at the start of this request, so this session context file was created before repository analysis.

## OpenOcean / SparkDex implementation read-through
- Relevant source files:
  - `src/hooks/swappers/openocean/SwapOpenOceanSparkDexHook.sol`
  - `src/hooks/swappers/openocean/ApproveAndSwapOpenOceanSparkDexHook.sol`
  - `src/libraries/OpenOceanSparkDexScaler.sol`
  - `src/vendor/openocean/IOpenOceanCaller.sol`
  - `src/vendor/openocean/IOpenOceanExchange.sol`
- Related support files read:
  - `src/hooks/BaseHook.sol`
  - `src/interfaces/ISuperHook.sol`
  - `src/libraries/HookDataUpdater.sol`
  - `src/libraries/HookSubTypes.sol`
  - `test/unit/hooks/swappers/openocean/OpenOceanSparkDexHook.t.sol`
  - `test/integration/openocean/OpenOceanSparkDexAPIScale.t.sol`
  - `test/utils/parsers/OpenOceanAPIParser.sol`
  - OpenOcean deployment/config references in `script/utils/Constants.sol`, `script/utils/ConfigBase.sol`, `script/utils/ConfigCore.sol`, `script/DeployV2Core.s.sol`, `script/run/verify_v2_staging_prod.sh`, and `script/run/regenerate_bytecode.sh`.
- The implementation is named `OpenOceanSparkDex`, not `Oenocean`, and is constrained to OpenOcean V4 SparkDexV4 routes.
- Two hooks exist:
  - `SwapOpenOceanSparkDexHook` builds a single OpenOcean router swap execution between BaseHook pre/post executions.
  - `ApproveAndSwapOpenOceanSparkDexHook` builds approve-zero, approve-amount, router swap, approve-zero executions for ERC20 inputs; for native input it builds only the router swap between BaseHook pre/post executions.
- Both hooks:
  - Are `HookType.NONACCOUNTING` with `HookSubTypes.SWAP`.
  - Store immutable `OPENOCEAN_ROUTER`, `OPENOCEAN_CALLER`, and `NATIVE`.
  - Reject zero router/caller constructor args via `ADDRESS_NOT_VALID`.
  - Decode packed hook data with fixed offsets.
  - Support `usePrevHookAmount` by reading `ISuperHookResult(prevHook).getOutAmount(account)`.
  - Use `OpenOceanSparkDexScaler.updateTxDataAmounts` to rewrite OpenOcean swap calldata when the execution amount differs from the original quote amount.
  - Reject same input/output token pairs, treating `address(0)` and configured native token as equivalent native values.
  - Set out amount as the delta in output-token/native balance between pre and post execution.
  - `inspect` returns packed OpenOcean caller, source token, destination token, source receiver, and destination receiver.
- Hook data formats:
  - `SwapOpenOceanSparkDexHook`: outputToken at 0, value at 20, inputAmount at 52, outputMin at 84, usePrevHookAmount at 116, txDataLength at 117, txData at 149.
  - `ApproveAndSwapOpenOceanSparkDexHook`: inputToken at 0, outputToken at 20, inputAmount at 40, outputMin at 72, usePrevHookAmount at 104, txDataLength at 105, txData at 137.
- `OpenOceanSparkDexScaler` behavior:
  - Requires nonzero new/original amounts.
  - Requires top-level selector to be `IOpenOceanExchange.swap`.
  - Decodes `(IOpenOceanCaller, SwapDescription, CallDescription[])`.
  - Requires decoded caller to match the expected immutable caller.
  - Rejects partial fill routes by checking flag bit `0x01`.
  - Updates `desc.amount`, `desc.minReturnAmount`, and `desc.guaranteedAmount` proportionally through `HookDataUpdater.getUpdatedOutputAmount`.
  - For native input (`address(0)` or `0xEeee...EEeE`), requires the sum of call values to equal original amount and rescales values so the final value consumes the remainder.
  - For ERC20 input, requires all call values to be zero.
  - Detects direct input amounts from supported direct call selectors, allowing exact-input scaling when direct input sum equals original amount, with last input consuming the remainder.
  - Supports selector-specific updates/validation for:
    - Uniswap V3 style SparkDex swap selector `0xe5b07cdb`
    - single distribution call `0x9f865422`
    - multi distribution call `0x51a74316`
    - collect slippage `0x8a6a1e85`
    - WETH deposit `0xd0e30db0`
    - WETH withdraw `0x2e1a7d4d`
    - nested makeCall `0x0c7e1209`
    - nested makeCalls `0xa8920d2b`
  - Explicitly rejects direct safeTransfer selector `0xd1660f99` unless it appears inside a validated distribution wrapper with sentinel amount.
  - Distribution validation checks packed numerator/denominator, nonzero fraction, numerator <= denominator, zero nested value, exact expected amount bias, and sentinel amount `1` at the patch target.
  - Collect slippage preserves high bits and rescales only the low 240-bit amount.
  - Nested makeCall/makeCalls traversal is capped at depth 10.
- Tests:
  - `test/unit/hooks/swappers/openocean/OpenOceanSparkDexHook.t.sol` covers scaler proportional updates, native value/input splitting, hook build outputs, same-token reverts, caller mismatch, partial-fill rejection, invalid distribution cases, direct safeTransfer rejection, unknown selectors, and nested makeCall depth limits.
  - `test/integration/openocean/OpenOceanSparkDexAPIScale.t.sol` uses Surl/FFI against OpenOcean V4 Flare API with `enabledDexIds=6` and validates real txData scales up/down.
  - `test/utils/parsers/OpenOceanAPIParser.sol` builds the OpenOcean API URL for chain 14 Flare and parses `data`, `to`, `value`, `inAmount`, and `minOutAmount`.
- Deployment/config:
  - OpenOcean constants are Flare-only: router `0x6352a56caadC4F1E25CD6c75970Fa768A3304e64`, caller `0x6dd434082EAB5Cd134B33719ec1FF05fE985B97b`.
  - `ConfigCore` sets OpenOcean router/caller only for `FLARE_CHAIN_ID`.
  - `DeployV2Core` deploys hook slots 68 and 69 only when both router and caller are configured and deployed; otherwise both hooks are skipped.
  - `verify_v2_staging_prod.sh` encodes constructor args as `(router, caller, nativeToken)` and maps hook names to the source paths.
- Verification run:
  - `forge test --match-contract OpenOceanSparkDexHookTest` under default profile failed because `script/DeployV2Core.s.sol` has an existing unresolved merge-conflict marker at line 336.
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest` passed: 24 tests passed, 0 failed, 0 skipped.

## superform-hook-master plan: OpenOcean dynamic amount adjustment validation

Date: 2026-06-04.

### Triggering review from OpenOcean
- OpenOcean team warned that their caller contract changes from time to time. Our current scaler is coupled to a fixed caller address plus known internal selectors and `enabledDexIds=6`, so a caller or route-shape change can silently create audit/config drift.
- OpenOcean recommended their dynamic amount adjustment solution. It is configured by OpenOcean, tied to our `desc.referrer`, and they say integrators only need to update `desc.amount`; their router/caller handles route-internal amount adjustment.
- Official OpenOcean V4 docs currently show `referrer`, `referrerFee`, `sender`, `minOutput`, `enabledDexIds/disabledDexIds`, `amountDecimals`, and `gasPriceDecimals` swap params, and provide a `decodeInputData` endpoint that returns `caller`, `desc`, and `calls`: https://docs.openocean.finance/docs/swap-api/v4. The docs do not publicly document the referrer-gated dynamic amount feature, so OpenOcean confirmation is required before implementation.

### MVP goal
- Do not implement a broad new scaler.
- First validate that a quote generated with our configured OpenOcean referrer can be executed after only patching the top-level `IOpenOceanExchange.SwapDescription.amount` to a new execution amount.
- If validation succeeds, replace the current selector-aware scaler dependency with a top-level swap description updater and referrer validation. This removes caller immutability and route-internal selector assumptions from Superform code.
- Keep the current hook UX and `usePrevHookAmount` behavior: previous-hook out amount becomes the execution amount, ERC20 approval uses that amount, native `msg.value` uses that amount, and output accounting remains balance-delta based.

### Questions/blockers for OpenOcean or product owner
1. What exact referrer address should be used for staging and production on Flare? Should they be separate addresses? Is it required to be an EOA as docs say, or can it be a Superform-controlled contract/multisig?
2. Has OpenOcean already enabled dynamic amount adjustment for that referrer on Flare chain ID 14? If not, what environment can we use to test it?
3. Which API endpoint and params should we use for dynamic routes: public `https://open-api.openocean.finance`, pro `https://open-api-pro.openocean.finance`, or another endpoint? Should requests use `amountDecimals`/`gasPriceDecimals` instead of the currently used deprecated `amount`/`gasPrice`?
4. Must every swap request include `referrer=<Superform referrer>`? Should we also set `sender`, `referrerFee`, `minOutput`, `disabledDexIds`, `enabledDexIds`, or `disableRfq`?
5. Can we remove `enabledDexIds=6` and allow all OpenOcean routes once the referrer is configured, or does dynamic adjustment only support specific DEX integrations on Flare?
6. OpenOcean says "only requires updating `desc.amount`". Does that literally mean `desc.minReturnAmount` and `desc.guaranteedAmount` must remain unchanged? Or should we scale either field ourselves, or obtain fresh min-output semantics through `minOutput`/API params?
7. If `desc.minReturnAmount` stays unchanged, what is the intended behavior when execution amount is lower than quoted amount? A lower input with the original min return may revert. If execution amount is higher, original min return may become too weak.
8. For native FLR input, should Superform set top-level `msg.value` to the new execution amount while leaving every nested `CallDescription.value` unchanged? Does the OpenOcean router/caller redistribute `msg.value` internally based on `desc.amount`?
9. For ERC20 input, should Superform approve the new execution amount even though nested route calldata remains quoted at the original amount?
10. Is the `caller` argument in `swap(caller, desc, calls)` intentionally mutable for dynamic routes? Should Superform stop validating a fixed caller entirely, or should we validate only that the caller has code and is the value returned by OpenOcean API?
11. Does the dynamic solution support partial-fill flags? If not, we should keep rejecting `desc.flags & 0x01 != 0`.
12. Does dynamic adjustment support permits in `desc.permit`, RFQ routes, multi-hop routes, distribution calls, wrapped-native deposit/withdraw routes, and all Flare OpenOcean sources?
13. What failure mode should we expect if the referrer is missing or dynamic adjustment is not enabled: revert, use original nested amounts, partial fill, or something else?
14. Are there maximum safe deltas between quoted `desc.amount` and execution `desc.amount`? For Superform previous-hook amounts, should we cap scaling to a tolerance, for example +/- 5%, to avoid stale route or price-impact surprises?

### Validation path before Solidity changes
1. Ask OpenOcean to enable dynamic amount adjustment for a Superform test referrer on Flare and provide at least one known-good token pair.
2. Add a local validation helper or Foundry integration test branch that fetches OpenOcean V4 swap calldata using the configured referrer. This can reuse `test/utils/parsers/OpenOceanAPIParser.sol` but should add a referrer param and use `amountDecimals`/`gasPriceDecimals`.
3. Decode the returned `txData` as `IOpenOceanExchange.swap(caller, desc, calls)`.
4. Patch only `desc.amount` to `quote.inAmount * 95 / 100` and re-encode the same `caller` and exact same `calls` bytes. Do not traverse or rewrite route-internal selectors.
5. Execute the patched calldata on a Flare fork against the returned router address for a native-input route. Send `msg.value = patched desc.amount`. Assert it either succeeds with expected output and balance deltas, or document the exact revert.
6. Repeat with `desc.amount = quote.inAmount * 105 / 100` for native input.
7. Repeat down/up tests for an ERC20-input route. Approve `patched desc.amount` to the OpenOcean router. Assert the router pulls the patched amount, not the quoted original amount.
8. During all validation, compare decoded original and patched data:
   - `caller` unchanged.
   - `desc.referrer` equals the Superform referrer.
   - `desc.srcToken`, `desc.dstToken`, `srcReceiver`, and `dstReceiver` unchanged.
   - `calls.length`, every call target/value/data hash, and top-level selector unchanged.
   - Only `desc.amount` changes unless OpenOcean explicitly tells us to also change slippage fields.
9. Run a negative control with the same calldata but without the configured referrer or with a wrong referrer. Confirm whether it reverts or incorrectly uses original nested amounts. This determines whether on-chain referrer validation is mandatory. Expected MVP answer: validate exact referrer on-chain.
10. If OpenOcean says `desc.minReturnAmount` should be unchanged, run lowered-amount validation with an intentionally low-slippage quote to see whether the original min return causes expected reverts. If it does, decide whether Superform can accept this or needs an off-chain quote policy.

### Proposed code change if validation succeeds
- Replace `OpenOceanSparkDexScaler.updateTxDataAmounts` usage in both hooks with a much smaller updater that:
  - validates top-level selector is `IOpenOceanExchange.swap.selector`;
  - ABI-decodes `(IOpenOceanCaller caller, SwapDescription desc, CallDescription[] calls)`;
  - validates nonzero original/new amounts;
  - validates `desc.referrer == OPENOCEAN_REFERRER`;
  - keeps rejecting partial fills unless OpenOcean confirms support;
  - patches `desc.amount = executionAmount`;
  - optionally patches `desc.minReturnAmount` and/or `desc.guaranteedAmount` only if OpenOcean explicitly requires it;
  - re-encodes without inspecting `calls[i].data` selectors.
- Remove `OPENOCEAN_CALLER` immutables from `SwapOpenOceanSparkDexHook` and `ApproveAndSwapOpenOceanSparkDexHook`, or replace them with `OPENOCEAN_REFERRER`.
- Constructors likely become `(address router_, address referrer_, address nativeToken_)`. If product wants to preserve constructor shape temporarily, `caller_` could be repurposed only with clear naming in a follow-up, but that is not recommended for audited code.
- Update `_getInputToken` and `inspect` to decode only top-level swap data. `inspect` should continue returning caller, src token, dst token, src receiver, dst receiver, and may include referrer if the inspector contract expects that extra dependency to be visible.
- Keep same-token validation based on hook data input/output and decoded `desc.srcToken`/`desc.dstToken`.
- Keep `ApproveAndSwap` approval behavior:
  - If `usePrevHookAmount`, approve exactly `executionAmount`.
  - If ERC20 input, reset -> approve execution amount -> swap -> reset.
  - If native input, use a single swap execution with `value = executionAmount`.
- Rename decision:
  - MVP can keep current hook keys and filenames to reduce registry churn, but the `SparkDex` name becomes inaccurate if OpenOcean dynamic routes are no longer SparkDex-only.
  - Cleaner version is to add new `SwapOpenOceanHook` and `ApproveAndSwapOpenOceanHook` contracts and deprecate the SparkDex-specific hooks. Master Codex/product should choose before implementation because deployment slots, bytecode locks, and downstream clients are affected.

### Code areas that would change after approval
- `src/hooks/swappers/openocean/SwapOpenOceanSparkDexHook.sol`
- `src/hooks/swappers/openocean/ApproveAndSwapOpenOceanSparkDexHook.sol`
- `src/libraries/OpenOceanSparkDexScaler.sol`: either replace with top-level updater, rename to an OpenOcean dynamic updater, or leave old scaler unused for backwards compatibility.
- `src/vendor/openocean/IOpenOceanExchange.sol`: likely unchanged, but comments may mention dynamic referrer behavior.
- `test/unit/hooks/swappers/openocean/OpenOceanSparkDexHook.t.sol`: replace selector-scaler tests with top-level patch/referrer tests.
- `test/integration/openocean/OpenOceanSparkDexAPIScale.t.sol`: repurpose into fork/API dynamic amount validation instead of internal calldata scaling validation.
- `test/utils/parsers/OpenOceanAPIParser.sol`: add `referrer`, optional `enabledDexIds`, optional `sender`, and `minOutput` support; migrate to `amountDecimals` and `gasPriceDecimals`.
- `script/utils/Constants.sol`, `script/utils/ConfigCore.sol`, `script/DeployV2Core.s.sol`, `script/run/verify_v2_staging_prod.sh`, `script/run/regenerate_bytecode.sh`: replace caller config/constructor args with referrer config/constructor args if hooks are updated in place.
- Generated and locked bytecode files after implementation: regenerate only after tests pass and Master Codex confirms the deployment naming choice.

### Tests to add or update after approval
- Unit: top-level updater changes `desc.amount` and leaves `caller` plus every `CallDescription` byte-for-byte unchanged.
- Unit: wrong referrer reverts.
- Unit: zero original/new amount reverts.
- Unit: partial-fill flag reverts unless OpenOcean confirms dynamic partial fills are supported.
- Unit: hooks using `usePrevHookAmount` patch only `desc.amount`; ERC20 approval and native `msg.value` use the previous-hook amount.
- Unit: hooks without `usePrevHookAmount` keep original `desc.amount` and use hook input amount.
- Unit: caller mismatch no longer reverts if referrer is valid, proving caller drift does not break us.
- Unit: same input/output token validation still catches both direct hook-data mismatch and decoded `desc.srcToken`/output cases.
- Integration/fork with OpenOcean API and configured referrer:
  - Native input, amount scaled down.
  - Native input, amount scaled up.
  - ERC20 input, amount scaled down.
  - ERC20 input, amount scaled up.
  - At least one route without `enabledDexIds=6` if OpenOcean confirms broad route support.
  - Wrong/missing referrer negative control.
- Regression: `forge test --match-contract OpenOceanSparkDexHookTest` or renamed equivalent.
- Regression: OpenOcean API/fork test should be isolated because it requires network/FFI/RPC and may be non-deterministic.

### Risks and constraints
- The dynamic behavior is controlled by OpenOcean off-chain/referrer configuration and is not discoverable from the router interface. Missing or changed config can break execution unless we validate `desc.referrer` and maintain operational checks with OpenOcean.
- If `desc.minReturnAmount` remains unchanged, lower previous-hook amounts can revert and higher previous-hook amounts can have weaker output protection than proportional slippage. Scaling these fields ourselves may conflict with OpenOcean's recommendation. This must be confirmed.
- Removing caller validation intentionally shifts trust from a fixed caller allowlist to the OpenOcean router plus referrer-gated API behavior. This reduces selector-drift risk but increases reliance on OpenOcean route generation and router/caller correctness.
- Native swaps are the highest-risk validation item because current scaler rewrites nested `CallDescription.value`; the dynamic solution must prove the router/caller can safely redistribute the new `msg.value`.
- ERC20 approvals must match actual router pull behavior. If the route still pulls the original quoted amount internally, the swap may leave approved/input dust or fail.
- Current parser uses deprecated `amount` and `gasPrice`; OpenOcean docs recommend decimal-denominated params. Updating the parser changes integration-test behavior and should be done explicitly.
- If the hook remains named `SparkDex`, downstream users may assume routes are still SparkDex-only. If renamed, registry keys, deployment slots, bytecode lock files, and client integration need coordination.
- Dynamic route support may vary by token pair, RFQ inclusion, native wrapping, or route composition. The MVP should start with constrained token pairs but should not ship until at least native and ERC20 paths pass on fork.

### superform-hook-master recommendation
- Do not implement Solidity changes yet.
- First get OpenOcean answers to the questions above and run the fork/API validation with a configured referrer.
- If validation passes, implement the smallest on-chain change: a top-level `desc.amount` updater with exact referrer validation, no route-internal selector traversal, partial-fill rejection by default, and unchanged accounting/approval behavior.
- Master Codex should review this plan and decide whether to keep current `OpenOceanSparkDex` hook names or introduce new generic OpenOcean hook names before implementation starts.

Status: plan appended by `superform-hook-master`; awaiting Master Codex review. Do not continue to implementation until Master Codex approves.

## Master Codex review of OpenOcean feedback
- User shared OpenOcean team's review:
  - OpenOcean caller contract changes over time, making our fixed-caller + selector-aware route scaler fragile and requiring missed-change audits/config updates.
  - OpenOcean recommends a referrer-configured dynamic amount adjustment where Superform only updates top-level `desc.amount` and the OpenOcean router handles route-internal amount adjustment.
- Master Codex assessment:
  - This is a strong reason to stop expanding the selector-aware `OpenOceanSparkDexScaler` approach.
  - Do not ship a Solidity refactor until OpenOcean enables/provides a Superform referrer for testing and confirms exact semantics.
  - Public OpenOcean V4 docs expose `referrer`, `enabledDexIds/disabledDexIds`, `minOutput`, `sender`, and the move to `amountDecimals`/`gasPriceDecimals`, but the referrer-gated dynamic amount feature is not publicly specified; rely on direct OpenOcean confirmation.
  - The key unresolved question is whether literally only `desc.amount` changes. In particular, lowered execution amounts with unchanged `desc.minReturnAmount` may revert, while raised amounts may have weaker slippage protection unless OpenOcean's dynamic path accounts for this.
  - Native input must be tested explicitly because the current scaler rewrites nested `CallDescription.value`; OpenOcean's dynamic solution must prove that top-level `msg.value = newAmount` plus unchanged nested calls works.
- Recommended next action:
  - Ask OpenOcean for the test/staging referrer and confirmation answers before implementation.
  - Once available, add a fork/API validation test that re-encodes only `desc.amount`, leaves `caller` and `calls` byte-for-byte unchanged, and executes both native and ERC20 routes scaled down/up.
  - If validation passes, replace the scaler with a top-level OpenOcean swap updater plus exact `desc.referrer` validation and partial-fill rejection by default.

## OpenOcean dynamic referrer
- User reported OpenOcean enabled dynamic amount adjustment for referrer `0x0E24b0F342F034446Ec814281AD1a7653cBd85e9`.
- Next work item is to validate live/API calldata by re-encoding only top-level `desc.amount` and checking native/ERC20 execution behavior on a Flare fork.

## Dynamic amount validation attempt
- Added `surlCallOpenOceanDynamicSwap` to `test/utils/parsers/OpenOceanAPIParser.sol` to request OpenOcean Flare swap calldata with:
  - `amountDecimals`
  - `gasPriceDecimals=100000000000`
  - configurable `slippage`
  - `account`
  - enabled referrer `0x0E24b0F342F034446Ec814281AD1a7653cBd85e9`
- Added opt-in validation test `test/integration/openocean/OpenOceanDynamicAmountValidation.t.sol`.
  - It is gated by `RUN_OPENOCEAN_DYNAMIC_VALIDATION=true` so normal test runs skip it.
  - It fetches live OpenOcean API calldata, decodes `swap(caller, desc, calls)`, patches only `desc.amount`, asserts `caller` and `calls` are byte-for-byte unchanged, then executes on public Flare fork `https://flare-api.flare.network/ext/C/rpc`.
  - It validates native FLR -> SPRK and ERC20 WFLR -> SPRK for 95% and 105% of quoted amount.
- Result with `RUN_OPENOCEAN_DYNAMIC_VALIDATION=true FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanDynamicAmountValidationTest -vvv`:
  - Native input scaled down to 95% failed: nested `CallDescription.value` remained `1e18` while top-level `msg.value` was `0.95e18`, reverting with `OpenOcean: Insufficient balance for external call`.
  - ERC20 input scaled down to 95% failed: router pulled `0.95e18` WFLR into OpenOcean caller, but nested swap calldata still attempted to spend `1e18`, reverting with `ERC20: transfer amount exceeds balance`.
  - Native input scaled up to 105% executed, but the extra `0.05e18` native value remained in the OpenOcean caller, failing the added dust check.
  - ERC20 input scaled up to 105% executed, but the extra `0.05e18` WFLR remained in the OpenOcean caller, failing the added dust check.
- Conclusion:
  - With the currently returned calldata from OpenOcean API for this referrer, changing only top-level `desc.amount` is not safe and does not activate dynamic route-internal amount adjustment.
  - The returned route still embeds the original input amount in nested calls. This is exactly what the existing scaler had been compensating for.
  - Before changing production hooks, ask OpenOcean whether the feature is actually enabled for the pro/public Flare swap API, whether a different endpoint/query param/caller is required, or whether their side needs to return a different dynamic route shape.
- Verification after gating:
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanDynamicAmountValidationTest` passes by skipping all 4 opt-in validation tests.
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest` passes: 24 passed, 0 failed.

## superform-hook-master plan update: OpenOcean referrer + nested scaling MVP

Date: 2026-06-04.

### New OpenOcean guidance
- OpenOcean clarified that `desc.minReturnAmount` should be scaled to reduce slippage-related failures. `desc.guaranteedAmount` may also be adjusted if Superform needs it.
- OpenOcean clarified that native-token routes still require nested `CallDescription.value` scaling.
- Earlier live validation with referrer `0x0E24b0F342F034446Ec814281AD1a7653cBd85e9` showed that changing only top-level `desc.amount` is insufficient:
  - Native downscale reverted because nested values remained at the quoted amount.
  - ERC20 WFLR downscale reverted because nested SparkDex swap calldata still attempted to spend the quoted amount.
  - Upscales executed but left extra native/ERC20 input dust in the OpenOcean caller.

### Revised MVP conclusion
- Do not replace the current scaler with a top-level-only updater.
- The current `OpenOceanSparkDexScaler` already implements most of OpenOcean's latest guidance:
  - updates `desc.amount`;
  - proportionally scales `desc.minReturnAmount`;
  - proportionally scales `desc.guaranteedAmount`;
  - scales native nested `CallDescription.value` and validates the original value sum equals the quoted input amount;
  - scales supported exact-input ERC20/native route amounts inside known SparkDex/OpenOcean selectors;
  - validates distribution wrappers, slippage collection, WETH withdraw amounts, nested `makeCall`/`makeCalls`, and rejects partial fills.
- The main MVP change is therefore not a rewrite. It is to keep the nested scaling path, but replace the brittle fixed-caller configuration check with an exact referrer validation.

### Caller validation vs referrer validation
- Fixed caller validation should be removed or relaxed because OpenOcean explicitly says caller contracts change over time.
- Add an immutable `OPENOCEAN_REFERRER` to both hooks, configured to `0x0E24b0F342F034446Ec814281AD1a7653cBd85e9` for Flare.
- Update the scaler entry point from `expectedCaller_` to `expectedReferrer_` and validate `desc.referrer == expectedReferrer_`.
- Keep decoding and returning the `caller` value, but do not require it to equal the old Flare caller constant.
- Referrer validation is a config/route-intent guard, not a full substitute for calldata safety. Because anyone can encode a referrer field, the MVP should keep the current selector-aware route validation and nested amount rewriting instead of accepting arbitrary `calls` just because the referrer matches.
- Keep partial-fill rejection unless OpenOcean provides explicit confirmation and test vectors for dynamic partial-fill routes.

### ERC20 nested amount handling
- ERC20 nested amount handling is still required for the MVP.
- Reason: the prior WFLR downscale failed after the router/caller received the scaled amount because a nested swap still tried to spend the original quoted amount.
- Even though OpenOcean's latest note only explicitly mentions nested native values, empirical fork behavior shows ERC20 route calldata can also embed the original exact input.
- Keep the current `_directInputAmount` / exact-input scaling logic for supported selectors. Do not ship a referrer-only ERC20 path unless a new fork validation proves nested ERC20 amounts no longer need patching.

### Minimal implementation plan after Master Codex approval
1. Update `src/libraries/OpenOceanSparkDexScaler.sol`.
   - Rename `INVALID_OPENOCEAN_CALLER` to `INVALID_OPENOCEAN_REFERRER`.
   - Change `updateTxDataAmounts(bytes,address,uint256,uint256)` semantics so the second argument is `expectedReferrer_`.
   - Remove `address(caller) == expectedCaller_` validation.
   - Add `if (desc.referrer != expectedReferrer_) revert INVALID_OPENOCEAN_REFERRER();`.
   - Keep scaling `desc.amount`, `desc.minReturnAmount`, and `desc.guaranteedAmount` as currently implemented.
   - Keep `_updateCalls` unchanged for native nested values and supported ERC20 exact-input amounts.
2. Update `SwapOpenOceanSparkDexHook.sol`.
   - Replace immutable `OPENOCEAN_CALLER` with `OPENOCEAN_REFERRER`.
   - Constructor remains three addresses for minimal deployment-script churn, but parameter/name becomes `(router_, referrer_, nativeToken_)`.
   - Validate `router_ != address(0)` and `referrer_ != address(0)`.
   - Pass `address(OPENOCEAN_REFERRER)` to the scaler.
   - Keep `inspect` return shape unchanged for MVP: caller, src token, dst token, src receiver, dst receiver. This avoids downstream dependency churn.
3. Update `ApproveAndSwapOpenOceanSparkDexHook.sol` the same way.
   - Replace caller immutable with referrer immutable.
   - Pass referrer into the scaler.
   - Keep approval behavior exactly as-is: approve/reset the scaled execution amount for ERC20; send scaled `msg.value` for native.
4. Update Flare config/deployment scripts.
   - Replace `OPENOCEAN_CALLER_FLARE` / `openOceanCallers` usage with `OPENOCEAN_REFERRER_FLARE` / `openOceanReferrers`, or minimally keep the map shape only if Master Codex wants smallest script churn.
   - Update constructor arg labels in verify/regeneration scripts from caller to referrer.
   - Regenerate locked bytecode only after tests pass.

### Minimal test plan after approval
- Unit tests in `test/unit/hooks/swappers/openocean/OpenOceanSparkDexHook.t.sol`:
  - Replace caller-mismatch revert test with wrong-referrer revert test.
  - Add caller-drift success test: calldata with a different caller but correct referrer still scales and builds executions.
  - Assert `desc.minReturnAmount` scales proportionally.
  - Assert `desc.guaranteedAmount` continues to scale proportionally.
  - Keep native nested value scaling tests.
  - Keep ERC20 exact-input nested amount scaling tests, including the WFLR/SparkDex style selector path.
  - Keep unknown selector, direct safeTransfer rejection, distribution validation, partial-fill rejection, same-token validation, zero-amount validation, and nested depth tests.
- Integration/API tests:
  - Update OpenOcean API parser calls to include the enabled referrer.
  - Update current API scaler test to assert referrer validation and caller drift tolerance.
  - Keep opt-in dynamic validation tests, but change expected assertions to match the new MVP: scaled native nested values and scaled ERC20 nested exact-input calldata should execute without dust.
  - Include negative controls for wrong referrer.
- Regression commands:
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest`
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexAPIScaleTest`
  - Opt-in fork/API validation only with `RUN_OPENOCEAN_DYNAMIC_VALIDATION=true`.

### Naming decision
- Keep the current names for the MVP: `SwapOpenOceanSparkDexHook`, `ApproveAndSwapOpenOceanSparkDexHook`, and `OpenOceanSparkDexScaler`.
- Reason: the scaler is still selector-aware and currently only supports the SparkDex/OpenOcean route shapes already audited in this repo. Renaming to generic `OpenOceanHook` would imply broader route support than the code actually provides.
- Revisit names only if OpenOcean provides a genuinely generic dynamic route shape that removes selector-specific nested rewrites and passes native/ERC20 fork validation across non-SparkDex routes.

### Risks and follow-ups
- This plan still carries selector-maintenance risk for nested route data, but it materially reduces the caller-address drift risk OpenOcean flagged.
- The MVP does not yet support arbitrary OpenOcean routes. `enabledDexIds=6` should remain unless OpenOcean provides passing test vectors for other route selectors and Master Codex approves expanding the selector surface.
- Scaling `guaranteedAmount` is acceptable for MVP because current code already does it and OpenOcean said it can be adjusted if needed. If OpenOcean later says to leave it unchanged, make that a small targeted change with tests.
- Referrer validation alone should not be treated as an authenticity proof. The route-safety posture remains: immutable OpenOcean router, exact referrer, no partial fills, and strict selector-aware calldata validation.

Status: plan update appended by `superform-hook-master`; awaiting Master Codex review. Do not continue to Solidity/test implementation until Master Codex approves.

## OpenOcean referrer + scaler MVP implementation
- Master Codex approved the revised plan and implemented the MVP.
- Production hook/scaler changes:
  - `src/libraries/OpenOceanSparkDexScaler.sol`
    - Replaced fixed caller validation with exact `desc.referrer` validation.
    - Renamed `INVALID_OPENOCEAN_CALLER` to `INVALID_OPENOCEAN_REFERRER`.
    - Kept existing proportional scaling for:
      - `desc.amount`
      - `desc.minReturnAmount`
      - `desc.guaranteedAmount`
      - native nested `CallDescription.value`
      - supported direct exact-input SparkDex/OpenOcean selectors.
    - Kept partial-fill rejection and strict selector/distribution validation.
  - `src/hooks/swappers/openocean/SwapOpenOceanSparkDexHook.sol`
    - Replaced immutable `OPENOCEAN_CALLER` with `OPENOCEAN_REFERRER`.
    - Constructor remains `(address,address,address)` but second param is now `referrer_`.
    - Passes `OPENOCEAN_REFERRER` into the scaler.
  - `src/hooks/swappers/openocean/ApproveAndSwapOpenOceanSparkDexHook.sol`
    - Same referrer change as swap hook.
    - Approval/native execution behavior unchanged.
- Config/script changes:
  - `script/utils/Constants.sol`
    - Replaced Flare OpenOcean caller constant with `OPENOCEAN_REFERRER_FLARE = 0x0E24b0F342F034446Ec814281AD1a7653cBd85e9`.
  - `script/utils/ConfigBase.sol`
    - Renamed `openOceanCallers` mapping to `openOceanReferrers`.
  - `script/utils/ConfigCore.sol`
    - Sets `configuration.openOceanReferrers[FLARE_CHAIN_ID]`.
  - `script/DeployV2Core.s.sol`
    - Updated OpenOcean hook availability/deployment args to use `openOceanReferrers`.
    - Removed referrer `.code.length` requirements because referrer can be an EOA.
    - Note: this file still contains unrelated pre-existing merge-conflict markers and cannot compile until those are resolved.
  - `script/run/verify_v2_staging_prod.sh`
    - Encodes OpenOcean hook constructor args as `(openocean_router, openocean_referrer, native_token)`.
- Test changes:
  - `test/unit/hooks/swappers/openocean/OpenOceanSparkDexHook.t.sol`
    - Updated fixtures so txData uses a referrer and hooks are constructed with that referrer.
    - Added caller-drift success test: different OpenOcean caller is accepted when `desc.referrer` matches.
    - Replaced caller-mismatch revert with wrong-referrer revert.
    - Existing nested native/ERC20 scaling, minReturn/guaranteed scaling, distribution, direct safeTransfer rejection, unknown selector, partial-fill, same-token, and nested-depth tests remain.
  - `test/integration/openocean/OpenOceanSparkDexAPIScale.t.sol`
    - Fetches live OpenOcean calldata with referrer `0x0E24b0F342F034446Ec814281AD1a7653cBd85e9`.
    - Verifies caller is preserved but not used as the scaler guard.
    - Verifies referrer is preserved and desc/calls are scaled.
  - `test/utils/parsers/OpenOceanAPIParser.sol`
    - Added `surlCallOpenOceanDynamicSwap` with `amountDecimals`, `gasPriceDecimals`, configurable referrer/slippage, and `enabledDexIds=6`.
  - `test/integration/openocean/OpenOceanDynamicAmountValidation.t.sol`
    - New opt-in Flare fork validation gated by `RUN_OPENOCEAN_DYNAMIC_VALIDATION=true`.
    - Uses the scaler path, not top-level-only patching.
    - Validates native FLR -> SPRK and ERC20 WFLR -> SPRK scaled down/up with no caller dust.
- Verification:
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest`
    - Passed: 25 passed, 0 failed.

## superform-hook-master plan: OpenOcean pro API proportional output validation

Date: 2026-06-04.

### Incremental request
- User is satisfied with the current actual SPRK output checks:
  - actual SPRK balance delta is greater than zero;
  - hook `getOutAmount(account)` equals the actual SPRK received;
  - actual SPRK received is greater than or equal to scaled `desc.minReturnAmount`.
- User now wants the pro API hook simulation to additionally verify that reducing input by 10% also reduces actual output by roughly 10%.
- Do not implement code in this planning pass.

### MVP implementation plan
1. Update `test/integration/openocean/OpenOceanProAPIHookSimulation.t.sol`.
   - For each route already covered by the pro simulation, compare two executions from the same API quote:
     - baseline execution at 100% of `quote.inAmount`;
     - scaled execution at 90% of `quote.inAmount`.
   - Apply this to both native FLR -> SPRK and ERC20 WFLR -> SPRK hook paths.
2. Keep quote and fork state comparable.
   - Fetch one pro API quote per route.
   - Create the Flare fork after the quote is fetched, or reset to the same fork block before each execution.
   - Use `vm.snapshotState()` / `vm.revertToState()` around the 100% and 90% simulations if available in this Foundry version.
   - If snapshot helpers are awkward with the current simulation account, use two fresh simulation accounts funded from the same fork block and execute both runs against the same returned `txData`.
3. Factor simulation into a helper.
   - Add a route-specific helper that accepts `executionAmount`.
   - The helper should build the hook with `usePrevHookAmount = true`, execute the full hook lifecycle, and return:
     - actual SPRK balance delta;
     - hook recorded out amount;
     - scaled decoded `desc.minReturnAmount`;
     - any existing dust/allowance/input-consumption data needed by current assertions.
   - Reuse the helper for `quote.inAmount` and `quote.inAmount * 90 / 100`.
4. Preserve existing assertions for each run.
   - `actualOut > 0`.
   - `hook.getOutAmount(account) == actualOut`.
   - `actualOut >= scaledDesc.minReturnAmount`.
   - Native: router value and nested native values match `executionAmount`, with no caller dust.
   - ERC20: approval and consumed WFLR match `executionAmount`, allowance resets to zero, with no caller WFLR dust.
5. Add proportional-output assertion.
   - Compute `expected90Out = fullOut * 90 / 100`.
   - Assert `scaledOut` is approximately `expected90Out`.
   - Use a pragmatic tolerance because AMM price impact, fee rounding, route rounding, and live fork/API state can make output non-linear even with the same quote.
   - Recommended tolerance: 2% relative tolerance against `expected90Out`, plus a tiny absolute floor for low-output routes if needed.
   - Implement as bounds:
     - `lower = expected90Out * 98 / 100`;
     - `upper = expected90Out * 102 / 100`;
     - assert `scaledOut >= lower && scaledOut <= upper`.
6. Verification after Master Codex approval.
   - Gated/default: `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest`
   - Live opt-in: `RUN_OPENOCEAN_PRO_HOOK_SIMULATION=true OPENOCEAN_PRO_API_KEY=<runtime key> FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest -vv`
   - Regression: `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest`

### Risks
- AMM output is not perfectly linear. A 10% lower input can produce slightly more or less than exactly 90% output due to price impact and route rounding. The assertion should be approximate, not exact.
- Comparing two executions without resetting fork state would invalidate the result because the 100% swap changes pool reserves. Use snapshots or independent accounts on the same pre-swap fork state.
- Live pro API quotes can drift from the fork state. Keep the test opt-in and log baseline/scaled output values on failure if practical.
- If the 100% baseline itself fails due to slippage or stale fork/API state, the proportional check should fail clearly as an integration/environmental issue, not be hidden by skips.

Status: plan appended by `superform-hook-master`; Master Codex should review/approve before implementation continues.
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanDynamicAmountValidationTest`
    - Passed by default with 4 skipped opt-in tests.
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexAPIScaleTest -vvv`
    - Passed: 2 passed, 0 failed.
  - `RUN_OPENOCEAN_DYNAMIC_VALIDATION=true FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanDynamicAmountValidationTest -vv`
    - Passed: 4 passed, 0 failed.
    - This confirms native/ERC20 downscale/upscale work on the live Flare fork when the selector-aware scaler adjusts nested route amounts.
- Remaining caveat:
  - Default `forge test` / `forge build` with the default profile is still blocked by unrelated conflict markers in `script/DeployV2Core.s.sol`.

## superform-hook-master plan: OpenOcean pro API hook simulation

Date: 2026-06-04.

### New request
- User confirmed OpenOcean says dynamic amount adjustment is enabled for referrer `0x0E24b0F342F034446Ec814281AD1a7653cBd85e9`.
- User wants the hook updated around that referrer and a proper integration test that:
  - fetches a live quote from OpenOcean pro API with the enabled referrer;
  - uses a runtime API key rather than a hardcoded test key;
  - feeds the returned `txData` into the OpenOcean hook;
  - simulates the hook on a Flare fork.
- Do not implement Solidity/test changes in this planning pass.
- Do not write the user-provided API key into repository files or this context file. Use an env var such as `OPENOCEAN_PRO_API_KEY`.

### Current repo state relevant to the plan
- The hook/scaler referrer MVP is already implemented:
  - `SwapOpenOceanSparkDexHook` and `ApproveAndSwapOpenOceanSparkDexHook` use immutable `OPENOCEAN_REFERRER`.
  - `OpenOceanSparkDexScaler.updateTxDataAmounts` validates `desc.referrer` instead of a fixed OpenOcean caller.
  - The scaler still adjusts `desc.amount`, `desc.minReturnAmount`, `desc.guaranteedAmount`, native nested values, and supported ERC20 exact-input nested calldata.
- Existing API/fork tests do not yet satisfy this new request fully:
  - `OpenOceanSparkDexAPIScaleTest` fetches live calldata and validates the scaler, but does not execute the hook.
  - `OpenOceanDynamicAmountValidationTest` executes scaled calldata directly against the OpenOcean router, but does not execute through `SwapOpenOceanSparkDexHook.build` or `ApproveAndSwapOpenOceanSparkDexHook.build`.
  - `OpenOceanAPIParser` points at `https://open-api-pro.openocean.finance/v4/14/swap`, includes `referrer`, `amountDecimals`, `gasPriceDecimals`, and `enabledDexIds=6`, but currently does not pass an API key header.
- OpenOcean public/enterprise docs confirm the V4 swap params we need: `amountDecimals`, `gasPriceDecimals`, `slippage`, `account`, `referrer`, `enabledDexIds/disabledDexIds`, `sender`, and `minOutput`. They do not clearly document pro API authentication headers, so the implementation should keep header handling isolated and easy to change.
  - Public V4 docs: https://docs.openocean.finance/docs/swap-api/v4
  - Enterprise V4 docs: https://docs.openocean.finance/docs/swap-api/enterprise

### MVP goal
- Keep the existing hook/scaler implementation shape. No new generic OpenOcean hook and no top-level-only scaler rewrite.
- Add a pro-API-backed integration test that proves returned OpenOcean `txData` can be used by the deployed-style hook path on a Flare fork.
- Exercise the dynamic execution amount path by using a mock previous hook amount different from the quoted input amount, so the hook calls the scaler through its normal `build` flow.
- Cover both input-token classes:
  - native FLR input through `SwapOpenOceanSparkDexHook`;
  - ERC20 WFLR input through `ApproveAndSwapOpenOceanSparkDexHook`.
- Keep the integration opt-in, because it requires FFI/Surl network access, a live pro API key, and a Flare fork.

### Implementation plan for Master Codex
1. Update `test/utils/parsers/OpenOceanAPIParser.sol`.
   - Add a pro-auth helper, for example `_openOceanProHeaders(string memory apiKey_) returns (string[] memory)`.
   - Read the API key in tests with `vm.envString("OPENOCEAN_PRO_API_KEY")`; never hardcode the key.
   - Use Surl's `url.get(headers)` variant.
   - Start with a conventional bearer header, e.g. `Authorization: Bearer <OPENOCEAN_PRO_API_KEY>`, unless OpenOcean confirms a different header name. Keep this in one helper so changing to `X-API-Key`, `apikey`, or another header is a one-line update.
   - Keep query params:
     - `inTokenAddress`
     - `outTokenAddress`
     - `amountDecimals`
     - `gasPriceDecimals=100000000000`
     - `slippage`
     - `account`
     - `referrer=0x0E24b0F342F034446Ec814281AD1a7653cBd85e9`
     - `enabledDexIds=6`
   - Add an API-keyed wrapper such as `surlCallOpenOceanProDynamicSwap(...)`.
   - If the pro endpoint returns non-200 or a JSON `code` other than 200, emit/log enough response data to debug but not the API key.
2. Add a new opt-in integration test, recommended filename:
   - `test/integration/openocean/OpenOceanProAPIHookSimulation.t.sol`
3. Test setup.
   - Gate all tests with both:
     - `RUN_OPENOCEAN_PRO_HOOK_SIMULATION=true`
     - non-empty `OPENOCEAN_PRO_API_KEY`
   - Use Flare fork RPC `https://flare-api.flare.network/ext/C/rpc`.
   - Use current constants:
     - OpenOcean router `0x6352a56caadC4F1E25CD6c75970Fa768A3304e64`
     - referrer `0x0E24b0F342F034446Ec814281AD1a7653cBd85e9`
     - WFLR `0x1D80c49BbBCd1C0911346656B529DF9E5c2F783d`
     - SPRK `0x657097cC15fdEc9e383dB8628B57eA4a763F2ba0`
   - Use wide slippage for stability, likely `50`, because this test is validating hook simulation rather than tight price behavior.
4. Native hook simulation test.
   - Fetch pro API quote for FLR -> SPRK with:
     - amount `1e18`
     - `account = address(this)`
     - enabled referrer
   - Assert `quote.to == OPENOCEAN_ROUTER`.
   - Decode returned `txData` and assert:
     - top-level selector is `IOpenOceanExchange.swap.selector`;
     - `desc.referrer` equals enabled referrer;
     - `desc.srcToken` is native/zero and `desc.dstToken` is SPRK.
   - Instantiate `SwapOpenOceanSparkDexHook(OPENOCEAN_ROUTER, OPENOCEAN_REFERRER, NATIVE)`.
   - Build hook data with original quoted `inputAmount = quote.inAmount`, returned `txData`, and `usePrevHookAmount = true`.
   - Use `MockHook` or the existing test mock to return a scaled previous amount, e.g. `quote.inAmount * 95 / 100` and optionally another test with `105 / 100`.
   - Call `hook.build(prevHook, address(this), hookData)`.
   - Execute every returned `Execution` in order, just like unit tests do, with the test contract as `msg.sender`.
   - Assert the router execution has:
     - target `OPENOCEAN_ROUTER`;
     - value equal to the scaled previous amount;
     - decoded `desc.amount`, `desc.minReturnAmount`, and nested native values scaled by the hook/scaler.
   - On the fork, deal native FLR to the test contract, execute, and assert:
     - SPRK balance increased;
     - OpenOcean caller retained no native/WFLR dust for the tested route;
     - hook `getOutAmount(address(this))` equals the output balance delta after post-execute.
5. ERC20 hook simulation test.
   - Fetch pro API quote for WFLR -> SPRK with:
     - amount `1e18`
     - `account = address(this)`
     - enabled referrer
   - Instantiate `ApproveAndSwapOpenOceanSparkDexHook(OPENOCEAN_ROUTER, OPENOCEAN_REFERRER, NATIVE)`.
   - Deposit scaled FLR into WFLR on the fork.
   - Build approve-and-swap hook data with original quote input amount, returned `txData`, and `usePrevHookAmount = true`.
   - Use previous amount `quote.inAmount * 95 / 100` and optionally `105 / 100`.
   - Execute all hook executions in order.
   - Assert:
     - approve amount equals scaled previous amount;
     - router swap calldata has scaled `desc.amount`, scaled min/guaranteed amounts, and supported nested direct-input amounts scaled;
     - WFLR input consumed equals scaled previous amount;
     - WFLR allowance is reset to zero;
     - OpenOcean caller retains no WFLR dust for the route;
     - SPRK output increased and hook out amount matches the output delta.
6. Negative/referrer checks.
   - MVP can rely on existing unit wrong-referrer tests for revert behavior.
   - If time permits, add one opt-in pro integration negative where the returned `txData` referrer is deliberately expected against a wrong hook referrer and `build` reverts with `INVALID_OPENOCEAN_REFERRER`.
   - Do not add wrong-referrer live quote execution as a required MVP case; the unit test is deterministic and cheaper.
7. Keep existing tests.
   - Do not remove `OpenOceanDynamicAmountValidationTest`; it is still useful direct-router validation.
   - Consider renaming its comments so it is clear it validates the scaler/direct router path, while the new test validates hook build/execution.
   - Keep `OpenOceanSparkDexAPIScaleTest` as a fast live calldata/scaler shape check, or consolidate only after the new hook simulation passes.

### Verification plan
- Deterministic/unit:
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest`
- Existing API scaler:
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexAPIScaleTest -vvv`
- Existing opt-in direct-router validation:
  - `RUN_OPENOCEAN_DYNAMIC_VALIDATION=true FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanDynamicAmountValidationTest -vv`
- New opt-in pro hook simulation:
  - `RUN_OPENOCEAN_PRO_HOOK_SIMULATION=true OPENOCEAN_PRO_API_KEY=<runtime key> FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest -vv`
- Do not rely on default-profile full `forge build` or `forge test` until unrelated conflict markers in `script/DeployV2Core.s.sol` are resolved.

### Risks and decisions
- The pro API auth header is not clearly documented in the public OpenOcean docs. If `Authorization: Bearer` fails, confirm the exact header with OpenOcean and only change the parser helper.
- Live API quotes can drift from the forked state. Use wide slippage and fetch quote immediately before fork execution; failures should log decoded route metadata and revert bytes.
- The hook still supports only the selector-aware SparkDex/OpenOcean route shapes accepted by `OpenOceanSparkDexScaler`. Keep `enabledDexIds=6` for this MVP.
- Do not commit the API key. Treat the user-supplied key as runtime-only.
- The test should prove the hook path, not just router execution. It must execute pre-execute, approvals where applicable, router swap, approval reset, and post-execute in order.

Status: plan appended by `superform-hook-master`; Master Codex should review/approve this plan before Solidity or test implementation continues.

## Master Codex approval: OpenOcean pro API hook simulation plan
- Reviewed and approved the `superform-hook-master` MVP plan.
- Implementation will keep the current referrer-based hook/scaler and add an opt-in pro API hook simulation test.
- The OpenOcean API key will be runtime-only via `OPENOCEAN_PRO_API_KEY`; it will not be committed.

## OpenOcean pro API hook simulation implementation
- Implemented the pro API simulation requested by the user.
- Parser changes:
  - `test/utils/parsers/OpenOceanAPIParser.sol`
    - Added `surlCallOpenOceanProDynamicSwap`.
    - Adds `accept: application/json` and `Authorization: Bearer <OPENOCEAN_PRO_API_KEY>` headers through `_openOceanProHeaders`.
    - Keeps the pro endpoint at `https://open-api-pro.openocean.finance/v4/14/swap`.
    - Keeps Flare params `amountDecimals`, `gasPriceDecimals=100000000000`, `account`, exact referrer `0x0E24b0F342F034446Ec814281AD1a7653cBd85e9`, and `enabledDexIds=6`.
    - API key is read only at runtime by tests and was not written to repo files.
- New integration test:
  - `test/integration/openocean/OpenOceanProAPIHookSimulation.t.sol`
    - Gated by `RUN_OPENOCEAN_PRO_HOOK_SIMULATION=true` and non-empty `OPENOCEAN_PRO_API_KEY`.
    - Creates a Flare fork using `https://flare-api.flare.network/ext/C/rpc`.
    - Fetches live pro API quotes with the enabled referrer and `account = address(OpenOceanHookSimulationAccount)`.
    - Simulates the full hook lifecycle through a local account contract:
      - `setExecutionContext`
      - `build`
      - execute every `Execution` in order
      - `resetExecutionState`
      - read `getOutAmount`
    - Native test:
      - Uses `SwapOpenOceanSparkDexHook`.
      - Fetches FLR -> SPRK txData.
      - Sets previous-hook amount to 95% of quoted input.
      - Asserts router target, scaled native execution value, scaled `desc.amount`, scaled `desc.minReturnAmount`, scaled `desc.guaranteedAmount`, scaled nested native values, scaled direct swap amount, no caller native/WFLR dust, SPRK output increased, and hook out amount equals output delta.
    - ERC20 test:
      - Uses `ApproveAndSwapOpenOceanSparkDexHook`.
      - Fetches WFLR -> SPRK txData.
      - Wraps FLR into WFLR inside the simulation account.
      - Sets previous-hook amount to 95% of quoted input.
      - Asserts approval amount, router target, scaled desc/min/guaranteed/direct swap amount, zero native call values, WFLR input consumed equals scaled amount, allowance reset to zero, no caller WFLR dust, SPRK output increased, and hook out amount equals output delta.
- Verification:
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest`
    - Passed by skipping both opt-in tests when env is disabled.
  - `RUN_OPENOCEAN_PRO_HOOK_SIMULATION=true OPENOCEAN_PRO_API_KEY=<runtime key> FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest -vv`
    - Passed: 2 passed, 0 failed.
    - Confirms the pro API auth header works and the returned txData simulates successfully through both OpenOcean hooks on a Flare fork.
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest`
    - Passed: 25 passed, 0 failed.
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexAPIScaleTest -vvv`
    - Passed: 2 passed, 0 failed.
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanDynamicAmountValidationTest`
    - Passed by skipping all 4 opt-in tests when env is disabled.
- Remaining caveat:
  - Full default-profile build/test remains blocked by unrelated conflict markers in `script/DeployV2Core.s.sol`.

## superform-hook-master plan: OpenOcean pro API hook simulation at 90%

Date: 2026-06-04.

### Incremental request
- User wants the existing OpenOcean pro API hook simulation to run at 90% of the quoted input amount instead of 95%.
- User also wants the actual output token received validated more explicitly.
- Do not implement code in this planning pass.

### MVP implementation plan
1. Update `test/integration/openocean/OpenOceanProAPIHookSimulation.t.sol`.
   - Replace the previous-hook scaled amount calculation from `quote.inAmount * 95 / 100` to `quote.inAmount * 90 / 100` in both native FLR -> SPRK and ERC20 WFLR -> SPRK tests.
   - If the test uses a shared helper/constant for the scale percentage, change that helper/constant to `90`; otherwise update both call sites directly.
2. Validate output-token accounting more directly.
   - Capture the simulation account's SPRK balance before execution and after the full hook lifecycle.
   - Compute `actualOut = sprkAfter - sprkBefore`.
   - Assert `actualOut > 0`.
   - Assert `hook.getOutAmount(account) == actualOut` after `postExecute`.
3. Validate slippage minimum against the scaled calldata.
   - Decode the router execution calldata produced by `hook.build`.
   - Read the scaled `desc.minReturnAmount` from the decoded OpenOcean swap description.
   - Assert `actualOut >= scaledDesc.minReturnAmount`.
   - Keep any existing assertions that `desc.amount`, `desc.minReturnAmount`, `desc.guaranteedAmount`, native nested values, and direct exact-input nested calldata are scaled consistently.
4. Keep existing safety assertions.
   - Native route: router execution value equals the 90% previous-hook amount and the OpenOcean caller retains no native/WFLR dust.
   - ERC20 route: approval equals the 90% previous-hook amount, WFLR consumed equals that amount, allowance resets to zero, and the OpenOcean caller retains no WFLR dust.
5. Verification after Master Codex approval.
   - Default gated check: `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest`
   - Live opt-in check: `RUN_OPENOCEAN_PRO_HOOK_SIMULATION=true OPENOCEAN_PRO_API_KEY=<runtime key> FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest -vv`
   - Regression if touched helper code affects shared parsing/scaling: `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest`

### Risks
- 90% is a larger deviation from the quote than the current 95%, so live fork/API state drift can expose more slippage failures. The explicit `actualOut >= scaledDesc.minReturnAmount` assertion will make the failure mode clear.
- If OpenOcean returns a route with a high minimum output relative to the 90% input, the test may revert before output assertions. In that case, keep the API slippage wide enough for this validation test while still asserting against the scaled on-chain min return.
- Because the test uses live pro API data and a public Flare fork, failures may be environmental. Keep the opt-in gate and avoid making this part of deterministic CI.

Status: plan appended by `superform-hook-master`; Master Codex should review/approve before implementation continues.

## Master Codex approval: 90 percent OpenOcean pro simulation
- Reviewed and approved the `superform-hook-master` incremental plan.
- Implementation will change the pro hook simulation previous-hook amount from 95% to 90% and assert the actual SPRK output balance delta is at least the scaled `desc.minReturnAmount`.

## OpenOcean pro API hook simulation 90 percent update
- Updated `test/integration/openocean/OpenOceanProAPIHookSimulation.t.sol`.
- Added `SCALE_PERCENT = 90` and changed both pro hook simulations to use `quote.inAmount * SCALE_PERCENT / 100` as the previous-hook execution amount.
- Tightened actual output validation for both native FLR -> SPRK and ERC20 WFLR -> SPRK paths:
  - actual SPRK balance delta must be greater than zero;
  - hook `getOutAmount(account)` must equal the actual SPRK balance delta;
  - actual SPRK balance delta must be greater than or equal to the scaled `desc.minReturnAmount` decoded from the hook-built router calldata.
- Verification:
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest`
    - Passed by skipping both opt-in tests when env is disabled.
  - `RUN_OPENOCEAN_PRO_HOOK_SIMULATION=true OPENOCEAN_PRO_API_KEY=<runtime key> FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest -vv`
    - Passed: 2 passed, 0 failed.
    - Confirms 90% scaled execution succeeds through both OpenOcean hooks on a Flare fork and actual SPRK output clears scaled min return.
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest`
    - Passed: 25 passed, 0 failed.

## Master Codex approval: OpenOcean output proportionality check
- Reviewed and approved the `superform-hook-master` plan.
- Implementation will compare 100% and 90% hook executions from the same pro API quote and fork state, then assert 90% actual SPRK output is approximately `fullOutput * 90 / 100` with a small tolerance and less than full output.

## OpenOcean pro API output proportionality implementation
- Updated `test/integration/openocean/OpenOceanProAPIHookSimulation.t.sol`.
- Each pro hook simulation now:
  - fetches one live quote;
  - snapshots the Flare fork state;
  - executes the hook once at 100% of `quote.inAmount` and records actual SPRK balance delta;
  - reverts to the snapshot;
  - executes the hook again at 90% of `quote.inAmount` and records actual SPRK balance delta;
  - asserts the 90% output is lower than the 100% output;
  - asserts the 90% output is approximately `fullOutput * 90 / 100` using `assertApproxEqRel` with `MAX_OUTPUT_SCALE_DEVIATION = 2e16` (2% relative tolerance).
- Existing output assertions remain:
  - actual SPRK delta > 0;
  - hook out amount equals actual SPRK delta;
  - actual SPRK delta >= scaled `desc.minReturnAmount`;
  - native/erc20 caller dust and approval reset checks.
- Verification:
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest`
    - Passed by skipping both opt-in tests when env is disabled.
  - `RUN_OPENOCEAN_PRO_HOOK_SIMULATION=true OPENOCEAN_PRO_API_KEY=<runtime key> FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest -vv`
    - Passed: 2 passed, 0 failed.
    - Confirms the 90% actual SPRK output is approximately 90% of the 100% actual SPRK output for both native FLR -> SPRK and ERC20 WFLR -> SPRK pro API hook simulations on a Flare fork.
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest`
    - Passed: 25 passed, 0 failed.

## superform-hook-master plan: OpenOcean pro API quote slippage at 2%

Date: 2026-06-04.

### Incremental request
- User asked to reduce the OpenOcean pro API hook simulation quote slippage from `50` to `2%`.
- No Solidity behavior change is intended. This is an integration-test quote-parameter change plus validation rerun.
- Do not implement code in this planning pass.

### MVP implementation plan
1. Update `test/integration/openocean/OpenOceanProAPIHookSimulation.t.sol`.
   - Change the pro simulation quote slippage constant from `"50"` to `"2"`.
   - Keep the existing scale behavior: one pro API quote per test, then 100% execution, fork-state revert, and 90% execution from the same returned `txData`.
   - Keep `enabledDexIds=6`, the enabled referrer `0x0E24b0F342F034446Ec814281AD1a7653cBd85e9`, and runtime-only `OPENOCEAN_PRO_API_KEY`.
2. Keep all existing assertions.
   - Actual SPRK balance delta must be greater than zero.
   - Hook `getOutAmount(account)` must equal the actual SPRK received.
   - Actual SPRK received must be at least the scaled `desc.minReturnAmount`.
   - 90% actual output must be lower than 100% actual output and approximately `fullOutput * 90 / 100` within the current tolerance.
   - Native nested values, ERC20 exact-input nested amounts, caller dust, and allowance reset checks remain unchanged.
3. Rerun validation after Master Codex approval.
   - Gated deterministic check: `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest`
   - Live pro API/fork check: `RUN_OPENOCEAN_PRO_HOOK_SIMULATION=true OPENOCEAN_PRO_API_KEY=<runtime key> FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest -vv`
   - If parser/shared scaling code is touched unexpectedly, also rerun `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest`.

### Expected risks
- Tighter API slippage means the returned `desc.minReturnAmount` has less buffer. A live fork run can fail if the pro quote and fork state diverge or price moves between quote generation and execution.
- The scaler proportionally updates `desc.minReturnAmount`, so the 90% execution should still work if the route output is proportional and the fork state matches the quote closely enough.
- If the 2% quote fails while 50% passes, that does not necessarily indicate hook/scaler failure; it may indicate live API/fork state drift or insufficient slippage buffer for a non-deterministic integration test.

Status: plan appended by `superform-hook-master`; Master Codex should review/approve before implementation continues.

## Master Codex approval: OpenOcean pro simulation slippage 2
- Reviewed and approved the `superform-hook-master` plan.
- Implementation will reduce the OpenOcean pro API simulation quote slippage from `50` to `2`, keep one quote per route test, and rerun live pro API/fork validation.

## OpenOcean pro API slippage 2 implementation
- Updated `test/integration/openocean/OpenOceanProAPIHookSimulation.t.sol`.
- Renamed the simulation quote slippage constant to `QUOTE_SLIPPAGE` and set it to `"2"`.
- Both pro API quote calls now pass `slippage=2` while preserving:
  - one API quote per route test;
  - 100% execution from that quote;
  - fork revert;
  - 90% execution from the same quote;
  - actual SPRK output proportionality check;
  - actual SPRK output >= scaled `desc.minReturnAmount`.
- Verification:
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest`
    - Passed by skipping both opt-in tests when env is disabled.
  - `RUN_OPENOCEAN_PRO_HOOK_SIMULATION=true OPENOCEAN_PRO_API_KEY=<runtime key> FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest -vv`
    - Passed: 2 passed, 0 failed.
    - Confirms live pro API/fork validation passes with `slippage=2` for both native FLR -> SPRK and ERC20 WFLR -> SPRK.
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest`
    - Passed: 25 passed, 0 failed.

## superform-hook-master plan: OpenOcean dynamic updater replacing selector-aware scaler

Date: 2026-06-04.

### Correction from user / OpenOcean
- User clarified that OpenOcean is asking Superform to stop using the selector-aware scaler path.
- OpenOcean's intended integration is referrer-gated dynamic amount adjustment:
  - Superform should update top-level `desc.amount`.
  - Superform should scale top-level `desc.minReturnAmount` to reduce slippage failures.
  - Superform may also scale top-level `desc.guaranteedAmount`.
  - For native input, Superform should scale nested top-level `CallDescription.value` fields.
  - Superform should not decode or rewrite nested ERC20 route calldata; OpenOcean router/caller should handle the rest when the enabled referrer is present.
- Enabled referrer remains `0x0E24b0F342F034446Ec814281AD1a7653cBd85e9`.

### MVP goal
- Replace hook usage of `OpenOceanSparkDexScaler` with a small dynamic amount updater.
- The updater should only inspect the top-level OpenOcean `swap(caller, desc, calls)` ABI shape.
- Do not inspect, decode, validate, or patch `calls[i].data` selectors or nested ERC20 exact-input amounts.
- Keep exact `desc.referrer` validation and partial-fill rejection.
- Use the pro API Flare fork test as the acceptance proof that OpenOcean's referrer-enabled dynamic behavior works, especially for ERC20 routes where nested calldata remains unchanged.

### Proposed implementation plan after Master Codex approval
1. Add or replace with a narrow updater library.
   - Preferred name: `OpenOceanDynamicAmountUpdater`.
   - If file churn must be minimized, `OpenOceanSparkDexScaler.sol` can be replaced in-place, but the hook should no longer conceptually use a selector-aware scaler.
   - Entry point should accept `(bytes txData_, address expectedReferrer_, uint256 newAmount_, uint256 originalAmount_)`.
2. Updater behavior.
   - Validate `newAmount_ != 0` and `originalAmount_ != 0`.
   - Validate top-level selector is `IOpenOceanExchange.swap.selector`.
   - ABI-decode `(IOpenOceanCaller caller, SwapDescription desc, CallDescription[] calls)`.
   - Validate `desc.referrer == expectedReferrer_`.
   - Reject partial-fill routes with `desc.flags & 0x01 != 0`.
   - Set `desc.amount = newAmount_`.
   - Scale `desc.minReturnAmount` proportionally from `originalAmount_` to `newAmount_`.
   - Scale `desc.guaranteedAmount` proportionally for continuity with current behavior, unless Master Codex decides to leave it unchanged despite OpenOcean saying it can be adjusted.
   - For native input only, scale top-level `calls[i].value` proportionally.
     - Detect native using existing OpenOcean native token conventions for `desc.srcToken`.
     - Require the original sum of `calls[i].value` equals `originalAmount_`.
     - Use last nonzero/native call value to absorb rounding remainder so the new sum equals `newAmount_`.
     - Leave every `calls[i].data` byte-for-byte unchanged.
   - For ERC20 input, require all `calls[i].value == 0` and leave every `calls[i].data` byte-for-byte unchanged.
   - Re-encode `swap(caller, desc, calls)`.
3. Update both OpenOcean hooks.
   - `SwapOpenOceanSparkDexHook` should call the new dynamic updater in the `usePrevHookAmount` path instead of `OpenOceanSparkDexScaler.updateTxDataAmounts`.
   - `ApproveAndSwapOpenOceanSparkDexHook` should do the same.
   - Keep constructor/config behavior around `OPENOCEAN_REFERRER`.
   - Keep approval behavior unchanged: approve/reset exactly the execution amount for ERC20; send exactly the execution amount for native.
   - Keep same-token checks and output balance-delta accounting unchanged.
4. Remove or deprecate selector-aware scaler usage.
   - Ensure no production hook references `OpenOceanSparkDexScaler`.
   - If the old scaler file remains, mark it unused or delete it only if no tests/scripts import it.
   - Remove tests that assert selector-specific nested ERC20 scaling, distribution validation, SparkDex selector patching, nested `makeCall` traversal, or direct `safeTransfer` rejection, because those are no longer part of the intended integration.
5. Update deterministic unit tests.
   - Add/update tests proving:
     - only top-level `desc.amount`, `desc.minReturnAmount`, and chosen `desc.guaranteedAmount` change for ERC20 routes;
     - ERC20 `calls[i].data` is byte-for-byte unchanged;
     - ERC20 top-level `calls[i].value` must be zero;
     - native `calls[i].value` scales and `calls[i].data` is byte-for-byte unchanged;
     - wrong referrer reverts;
     - partial-fill flag reverts;
     - zero original/new amount reverts;
     - caller drift is allowed when referrer matches;
     - hook `usePrevHookAmount` changes execution value/approval and patched top-level fields only.
6. Update pro API hook simulation.
   - Keep the pro API quote with runtime `OPENOCEAN_PRO_API_KEY`, exact referrer, `enabledDexIds=6`, and `slippage=2`.
   - Keep one API quote per route test:
     - execute 100%;
     - revert fork state;
     - execute 90% from the same returned `txData`.
   - Native assertions should expect scaled top-level `CallDescription.value` fields and unchanged `calls[i].data`.
   - ERC20 assertions should expect unchanged `calls[i].data` and zero top-level call values; do not assert nested direct-input amount scaling.
   - Keep actual SPRK output checks:
     - actual SPRK delta > 0;
     - hook out amount equals actual SPRK delta;
     - actual SPRK delta >= scaled `desc.minReturnAmount`;
     - 90% actual output is approximately 90% of 100% output with the existing tolerance.
   - Keep dust/allowance checks because they reveal whether OpenOcean dynamic adjustment actually consumed the scaled amount.
7. Update or retire old integration tests.
   - `OpenOceanSparkDexAPIScaleTest` should become a top-level dynamic updater shape test, asserting ERC20 nested calldata is unchanged.
   - `OpenOceanDynamicAmountValidationTest` should either be updated to use the new updater or renamed/removed if it only validates the obsolete selector-aware scaler.
   - The pro API hook simulation should be the primary acceptance test for the OpenOcean-enabled referrer behavior.

### Verification plan after implementation
- Deterministic:
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest`
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest`
- Live pro API/fork acceptance:
  - `RUN_OPENOCEAN_PRO_HOOK_SIMULATION=true OPENOCEAN_PRO_API_KEY=<runtime key> FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest -vv`
- Optional updated API shape test:
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexAPIScaleTest -vvv`
- Do not treat full default-profile `forge build` / `forge test` as a signal until the unrelated merge conflicts in `script/DeployV2Core.s.sol` are resolved.

### Risks
- Prior top-level-only validation failed for both native and ERC20 routes. Native failure is addressed by also scaling top-level `CallDescription.value`; ERC20 will now rely on OpenOcean's referrer-enabled dynamic adjustment rather than Superform rewriting nested calldata.
- ERC20 pro API simulation may fail if OpenOcean dynamic adjustment is not actually active for this referrer, endpoint, route, or `enabledDexIds=6`. That failure is useful and should block shipping this correction.
- Referrer validation is not proof that calldata is authentic. This approach intentionally trusts the OpenOcean router/pro API/referrer configuration more than the previous selector-aware scaler did.
- Removing selector validation reduces Superform-side route-shape enforcement. The safety model becomes: immutable router, exact enabled referrer, no partial fills, top-level amount/min updates, native value scaling, and balance-delta output accounting.
- Scaling `desc.guaranteedAmount` is optional per OpenOcean. Keeping proportional scaling is the least disruptive continuation of current behavior, but Master Codex should confirm whether to preserve or remove it.
- Live pro API/fork tests can fail due to quote/fork drift, but an ERC20 failure caused by unchanged nested calldata trying to spend the original amount should be treated as evidence that OpenOcean dynamic adjustment is not active or not compatible.

Status: plan appended by `superform-hook-master`; Master Codex should review and approve before implementation continues.

## Master Codex approval: replace OpenOcean selector-aware scaler
- Reviewed and approved the `superform-hook-master` plan.
- Implementation will stop using `OpenOceanSparkDexScaler` in hooks and switch to a narrow dynamic amount updater that only changes top-level OpenOcean swap fields plus native `CallDescription.value`.
- ERC20 nested route calldata will intentionally remain untouched so OpenOcean referrer-side dynamic adjustment handles it.

## OpenOcean dynamic updater finalization
- User clarified that a live pro/fork failure is expected until OpenOcean enables the referrer-side behavior for
  `0x0E24b0F342F034446Ec814281AD1a7653cBd85e9`.
- Final implementation keeps the OpenOcean-team requested model:
  - production hooks no longer import or call `OpenOceanSparkDexScaler`;
  - `src/libraries/OpenOceanSparkDexScaler.sol` was deleted;
  - `src/libraries/OpenOceanDynamicAmountUpdater.sol` is now the active updater;
  - both OpenOcean hooks call `OpenOceanDynamicAmountUpdater.updateTxDataAmounts(...)` whenever building txData;
  - updater validates the top-level `IOpenOceanExchange.swap` selector;
  - updater validates exact `desc.referrer`;
  - updater rejects partial-fill routes;
  - updater scales `desc.amount`;
  - updater scales `desc.minReturnAmount`;
  - updater scales `desc.guaranteedAmount`;
  - for native input, updater scales the top-level OpenOcean `CallDescription.value` fields and leaves each call's target,
    gas limit, and data unchanged;
  - for ERC20 input, updater requires top-level call values to remain zero and leaves route calldata byte-for-byte unchanged.
- Strengthened `test/unit/hooks/swappers/openocean/OpenOceanSparkDexHook.t.sol` so `usePrevHookAmount=true` proves the
  full behavior through both hooks:
  - ERC20 swap hook: previous amount drives `desc.amount`; `desc.minReturnAmount` and `desc.guaranteedAmount` scale;
    top-level call values remain zero; call targets/gas/data are unchanged.
  - Native swap hook: previous amount drives router execution value and `desc.amount`; min return and guaranteed amount
    scale; native top-level call values sum to the previous amount with rounding remainder; call data is unchanged.
  - ERC20 approve-and-swap hook: approval amount equals previous amount; scaled desc fields are present in router calldata;
    ERC20 route calldata is unchanged.
  - Native approve-and-swap hook: native router value, scaled desc fields, and scaled top-level call values are all asserted.
- Strengthened opt-in pro simulation tests in `test/integration/openocean/OpenOceanProAPIHookSimulation.t.sol`:
  - default run still skips without env/API key;
  - native pro simulation now asserts returned route calldata is unchanged while top-level call values scale;
  - ERC20 pro simulation now asserts call descriptions remain unchanged and top-level call values stay zero;
  - output assertions remain: actual SPRK delta > 0, hook out amount equals actual SPRK received, output is at least scaled
    `desc.minReturnAmount`, and 90% input produces approximately 90% output.
- Strengthened `test/integration/openocean/OpenOceanSparkDexAPIScale.t.sol` so live API calldata scaling verifies route
  target/gas/data preservation while native top-level values scale.
- Active source/test/script scan:
  - no remaining `OpenOceanSparkDexScaler` references in `src`, `test`, or deployment scripts outside generated/locked bytecode.
- Verification:
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest`
    - Passed: 17 passed, 0 failed.
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest`
    - Passed in default disabled mode: 0 passed, 0 failed, 2 skipped.
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanDynamicAmountValidationTest`
    - Passed in default disabled mode: 0 passed, 0 failed, 4 skipped.
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexAPIScaleTest -vvv`
    - Passed: 2 passed, 0 failed.
  - `git diff --check`
    - Passed.
- Not rerun as final verification:
  - live pro API/fork test with env enabled, because user clarified failure is expected while the referrer is not enabled.
- Remaining caveat:
  - full default-profile `forge build` / `forge test` remains blocked by unrelated pre-existing conflict markers in
    `script/DeployV2Core.s.sol`.

## Deploy script merge-conflict resolution
- User asked to fix the full default `forge build/test` blocker in `script/DeployV2Core.s.sol` without losing functionality.
- Resolved all conflict markers in `script/DeployV2Core.s.sol`.
- Functional merge decision:
  - preserved `ClaimFailedTransferHook`;
  - preserved `SwapUniswapV3Router02Hook`;
  - preserved `ApproveAndSwapUniswapV3Router02Hook`;
  - kept OpenOcean hook constructor/config args on `openOceanReferrers` rather than the old `openOceanCallers`;
  - kept referrer validation as EOA-compatible by not requiring code on the referrer.
- Slot/count changes:
  - `baseHooks` now includes all three conflicted hook names and is sized to `string[67]`;
  - hook deployment array length is now `73`;
  - `SwapUniswapV3Router02Hook` remains at slot `70`;
  - `ApproveAndSwapUniswapV3Router02Hook` remains at slot `71`;
  - `ClaimFailedTransferHook` moved to slot `72`;
  - `hookAddresses.claimFailedTransferHook` lookup now reads slot `72`.
- Also resolved conflict markers in generated output JSON files:
  - `script/output/staging/latest.json`;
  - `script/output/prod/latest.json`;
  - kept the newer `2026-06-03` `updated_at` timestamps.
- Verification:
  - exact conflict-marker scan passed: no `<<<<<<<`, `>>>>>>>`, or standalone `=======` markers remain;
  - `jq empty script/output/staging/latest.json script/output/prod/latest.json` passed;
  - `git diff --check` passed;
  - default `forge build` passed.
- Default `forge test` status:
  - ran the full default command;
  - compilation was skipped because build artifacts were current;
  - aggregate result: 2644 passed, 84 failed, 7 skipped;
  - every failure in the final Foundry summary was caused by missing RPC environment variables
    (`ETHEREUM_RPC_URL`, `BASE_RPC_URL`, or `FLARE_RPC_URL`) in fork/integration test setup/constructors, not by Solidity
    compilation or the deploy-script merge resolution.

## Test run after OpenOcean referrer set
- User asked to run the branch-added tests now that the referrer has been set.
- Branch context:
  - current branch is `feat/openocean_hook_referrer_support`;
  - compared against `origin/dev`, added OpenOcean tests are:
    - `test/integration/openocean/OpenOceanDynamicAmountValidation.t.sol`;
    - `test/integration/openocean/OpenOceanProAPIHookSimulation.t.sol`;
  - relevant modified tests also include:
    - `test/integration/openocean/OpenOceanSparkDexAPIScale.t.sol`;
    - `test/unit/hooks/swappers/openocean/OpenOceanSparkDexHook.t.sol`.
- Environment context:
  - no `.env` file is present;
  - `OPENOCEAN_PRO_API_KEY` is not exported in the shell, so pro API simulation tests cannot execute live and skip even with `RUN_OPENOCEAN_PRO_HOOK_SIMULATION=true`.
- Commands/results:
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest`
    - Passed: 17 passed, 0 failed, 0 skipped.
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest`
    - Compiled successfully, but skipped both tests because opt-in/env was disabled.
  - `RUN_OPENOCEAN_PRO_HOOK_SIMULATION=true FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest -vv`
    - Skipped both tests because `OPENOCEAN_PRO_API_KEY` is not available.
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexAPIScaleTest -vvv`
    - Failed: 0 passed, 2 failed.
    - Both `test_OpenOceanAPI_SparkDexCalldataScalesDown` and `test_OpenOceanAPI_SparkDexCalldataScalesUp` reverted with `INVALID_CALL_VALUE()`.
  - `RUN_OPENOCEAN_DYNAMIC_VALIDATION=true FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanDynamicAmountValidationTest -vvv`
    - Failed overall: 2 passed, 2 failed, 0 skipped.
    - Passed:
      - `test_OpenOceanDynamicAmount_Erc20Input_ScalesDown`;
      - `test_OpenOceanDynamicAmount_Erc20Input_ScalesUp`.
    - Failed:
      - `test_OpenOceanDynamicAmount_NativeInput_ScalesDown`;
      - `test_OpenOceanDynamicAmount_NativeInput_ScalesUp`.
    - Both native failures reverted with `INVALID_CALL_VALUE()` before router execution.
- Failure diagnosis:
  - `OpenOceanDynamicAmountUpdater._scaleNativeCallValues` requires the sum of top-level OpenOcean `CallDescription.value`
    fields to equal the original input amount for native input.
  - The live native FLR -> SPRK OpenOcean quote now contains the expected referrer
    `0x0E24b0F342F034446Ec814281AD1a7653cBd85e9`, but the quote shape violates that native call-value invariant.
  - Live ERC20 WFLR -> SPRK dynamic validation succeeds with the referrer enabled, showing the referrer-side dynamic path works for ERC20 in this test.

## superform-hook-master plan and implementation: OpenOcean zero-value native routes
- User asked to fix native token handling now that OpenOcean referrer-side scaling is enabled.
- Per repo instructions, `superform-hook-master` planned the hook-feature change before implementation.
- Plan summary:
  - support OpenOcean's live native dynamic quote shape where router `msg.value` and `desc.amount` carry the input amount,
    while every top-level `CallDescription.value` is zero;
  - preserve existing legacy behavior for native routes whose top-level call values sum exactly to the original amount;
  - keep reverting for partial nonzero native call-value sums that do not equal the original amount;
  - keep ERC20 behavior unchanged.
- Implementation:
  - Updated `src/libraries/OpenOceanDynamicAmountUpdater.sol`.
  - `_scaleNativeCallValues` now returns without mutating calls when the original top-level native call-value sum is zero.
  - It still scales top-level native call values when their sum equals `originalAmount_`.
  - It still reverts with `INVALID_CALL_VALUE()` when native call-value sum is nonzero but not equal to `originalAmount_`.
  - No hook constructors, deployment config, public interfaces, or bytecode/deployment artifacts were changed.
- Unit test updates:
  - Added zero-value native route coverage in `test/unit/hooks/swappers/openocean/OpenOceanSparkDexHook.t.sol`.
  - Added updater coverage proving desc fields scale while all top-level native call target/gas/value/data remain unchanged.
  - Added swap hook and approve-and-swap hook coverage proving router execution value uses the previous-hook amount while
    zero-value native OpenOcean calls remain unchanged.
  - Added `INVALID_CALL_VALUE()` coverage for a partial nonzero native call-value sum.
- Integration/test assertion updates:
  - Updated `OpenOceanSparkDexAPIScaleTest`, `OpenOceanDynamicAmountValidationTest`, and
    `OpenOceanProAPIHookSimulationTest` native assertions to accept both:
    - zero-value dynamic native route shape with unchanged call values;
    - legacy exact-sum native route shape with scaled call values.
- Verification:
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest`
    - Passed: 21 passed, 0 failed, 0 skipped.
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexAPIScaleTest -vvv`
    - Passed: 2 passed, 0 failed, 0 skipped.
  - `RUN_OPENOCEAN_DYNAMIC_VALIDATION=true FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanDynamicAmountValidationTest -vvv`
    - Passed: 4 passed, 0 failed, 0 skipped.
    - Confirms live native FLR -> SPRK scale down/up now executes successfully on a Flare fork.
    - Confirms live ERC20 WFLR -> SPRK scale down/up still passes.
  - `RUN_OPENOCEAN_PRO_HOOK_SIMULATION=true FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest -vv`
    - Compiled successfully but skipped both tests because `OPENOCEAN_PRO_API_KEY` is not exported.
  - `forge fmt --check` on all touched source/test files passed.
  - `git diff --check` passed.

## Code review: OpenOcean zero-value native route changes
- User asked for review of current staged, unstaged, and untracked changes.
- Worktree had no staged or untracked files; unstaged changes included `.Codex/sessions/context_session_1.md`, `src/libraries/OpenOceanDynamicAmountUpdater.sol`, and OpenOcean unit/integration test updates.
- Reviewed the active code change in `OpenOceanDynamicAmountUpdater._scaleNativeCallValues`: native OpenOcean routes whose top-level `CallDescription.value` sum is zero now leave those call values untouched while scaled router `msg.value`/`desc.amount` are used by the hooks.
- Reviewed accompanying test assertions/helpers for zero-value native route shape and partial nonzero native call-value rejection.
- Ran `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest`; result: 21 passed, 0 failed, 0 skipped.
- Review conclusion: no actionable code-review findings identified for the current diff.

## Code review: current OpenOcean zero-value native route changes (repeat)
- User again asked to review staged, unstaged, and untracked files.
- Current worktree status: no staged or untracked files; unstaged files remain `.Codex/sessions/context_session_1.md`, `src/libraries/OpenOceanDynamicAmountUpdater.sol`, and OpenOcean unit/integration test updates.
- Reviewed the one production change in `OpenOceanDynamicAmountUpdater._scaleNativeCallValues`: native routes with zero aggregate top-level `CallDescription.value` now return without mutating those calls, while legacy native routes with value sum equal to the original amount continue to scale and partial nonzero sums still revert.
- Reviewed updated unit and integration assertions accepting both zero-value dynamic native routes and legacy value-split native routes.
- Verification run for this review:
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest` passed: 21 passed, 0 failed, 0 skipped.
  - `RUN_OPENOCEAN_DYNAMIC_VALIDATION=true FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanDynamicAmountValidationTest -vvv` passed: 4 passed, 0 failed, 0 skipped; live Flare fork/API validation covered native and ERC20 scale down/up.
  - `git diff --check` passed.
- Review conclusion: no actionable code-review findings identified for the current uncommitted diff.

## Code simplifier pass: OpenOcean zero-value native route changes
- User asked to run a code simplifier skill.
- No `code simplifier` skill is available in the current Codex skill list, so a manual simplification pass was used as fallback.
- Inspected current OpenOcean diff and looked for removable duplication or clearer helper structure.
- Main candidate was the duplicated `_assertNativeCallValues` helper across three OpenOcean integration tests.
- Decided not to centralize it into `OpenOceanAPIParser` because that parser utility does not directly own Foundry assertion behavior; moving assertion helpers there would make the parser heavier and less focused.
- No code changes were made during this simplification pass.
- Verification:
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest` passed: 21 passed, 0 failed, 0 skipped.
  - `forge fmt --check` on touched OpenOcean files passed.
  - `git diff --check` passed.

## Branch test run: OpenOcean referrer support
- User asked to run the tests in the current branch and see if they work.
- Current branch/status:
  - branch: `feat/openocean_hook_referrer_support`;
  - no `.env` file present;
  - `ETHEREUM_RPC_URL`, `BASE_RPC_URL`, `FLARE_RPC_URL`, and `OPENOCEAN_PRO_API_KEY` are not exported in the shell;
  - unstaged files remain the OpenOcean updater/tests and this context file.
- Branch-relevant test commands/results:
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest`
    - Passed: 21 passed, 0 failed, 0 skipped.
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexAPIScaleTest -vvv`
    - Passed: 2 passed, 0 failed, 0 skipped.
  - `RUN_OPENOCEAN_DYNAMIC_VALIDATION=true FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanDynamicAmountValidationTest -vvv`
    - Passed: 4 passed, 0 failed, 0 skipped.
    - Live validation covered native FLR -> SPRK scale down/up and ERC20 WFLR -> SPRK scale down/up.
  - `RUN_OPENOCEAN_PRO_HOOK_SIMULATION=true FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest -vv`
    - Completed successfully in disabled mode: 0 passed, 0 failed, 2 skipped.
    - Both tests skipped because `OPENOCEAN_PRO_API_KEY` is missing.
- Full default suite:
  - `forge test`
    - Compilation succeeded.
    - Aggregate result: 2648 passed, 84 failed, 7 skipped.
    - Every reported failure was caused by missing RPC environment variables in fork/integration setup or constructors:
      `ETHEREUM_RPC_URL`, `BASE_RPC_URL`, or `FLARE_RPC_URL`.
    - No OpenOcean branch test failed in this full run; `OpenOceanSparkDexAPIScaleTest` passed and
      `OpenOceanProAPIHookSimulationTest` skipped due to missing pro API key.
- Conclusion:
  - The branch-specific deterministic and live dynamic OpenOcean tests work in the current environment.
  - The full default suite cannot pass until the required RPC environment variables are provided.

## Branch test rerun with 1Password-backed RPC env
- User asked to rerun because the environment should read from 1Password.
- Checked local credential tooling:
  - `op` exists at `/opt/homebrew/bin/op`.
  - `onepass` and `direnv` are not installed.
  - The Makefile only reads `op://...` values when `ENVIRONMENT=local`, and it does not export `FLARE_RPC_URL`.
- Verified, without printing secrets, that these values can be read from 1Password:
  - `ETHEREUM_RPC_URL`
  - `BASE_RPC_URL`
  - `FLARE_RPC_URL`
  - `OPTIMISM_RPC_URL`
- `SEPOLIA_RPC_URL` was not found at `op://5ylebqljbh3x6zomdxi3qd7tsa/SEPOLIA_RPC_URL/credential`, but the only Sepolia-referencing suite was skipped in the default run.
- `OPENOCEAN_PRO_API_KEY` was not found in the expected 1Password item path, and no OpenOcean item title was found via `op item list --vault 5ylebqljbh3x6zomdxi3qd7tsa`.
- Targeted OpenOcean results:
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest`
    - Passed: 21 passed, 0 failed, 0 skipped.
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexAPIScaleTest -vvv`
    - Passed: 2 passed, 0 failed, 0 skipped.
  - `FLARE_RPC_URL="$(op read .../FLARE_RPC_URL/credential)" RUN_OPENOCEAN_DYNAMIC_VALIDATION=true FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanDynamicAmountValidationTest -vvv`
    - Passed: 4 passed, 0 failed, 0 skipped.
    - Live validation covered native FLR -> SPRK scale down/up and ERC20 WFLR -> SPRK scale down/up.
  - `RUN_OPENOCEAN_PRO_HOOK_SIMULATION=true FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest -vv`
    - Compiled and skipped both tests: 0 passed, 0 failed, 2 skipped.
    - Reason: no `OPENOCEAN_PRO_API_KEY` available.
- Full default suite command with 1Password RPC env:
  - `ETHEREUM_RPC_URL="$(op read .../ETHEREUM_RPC_URL/credential)" BASE_RPC_URL="$(op read .../BASE_RPC_URL/credential)" FLARE_RPC_URL="$(op read .../FLARE_RPC_URL/credential)" OPTIMISM_RPC_URL="$(op read .../OPTIMISM_RPC_URL/credential)" ONE_INCH_API_KEY="$(op read .../OneInch/credential 2>/dev/null || true)" forge test`
  - Aggregate result: 3912 passed, 7 failed, 20 skipped out of 3939 tests.
  - The previous missing Optimism RPC setup failures were resolved.
  - OpenOcean suites in the default run passed or skipped as expected:
    - `OpenOceanSparkDexAPIScaleTest`: 2 passed.
    - `OpenOceanSparkDexHookTest`: 21 passed.
    - `OpenOceanDynamicAmountValidationTest`: 4 skipped because `RUN_OPENOCEAN_DYNAMIC_VALIDATION` is not set by default.
    - `OpenOceanProAPIHookSimulationTest`: 2 skipped because `OPENOCEAN_PRO_API_KEY` is unavailable.
- Remaining full-suite failures are all live Flare rFLR reward-state checks in `test/integration/flare/FlareRFLRHooksE2E.t.sol:FlareRFLRHooksE2E`:
  - `test_claimRFLR_buildAndExecute_noFee`: `Should have claimable rewards: 0 <= 0`
  - `test_claimRFLR_prePostExecute_tracksBalance`: `Should have claimable rewards: 0 <= 0`
  - `test_claimRFLR_sanity`: `Second holder should have claimable rewards on Kinetic: 0 <= 0`
  - `test_e2e_claimThenVestedThenWithdrawAll`: `Should have claimed rFLR: 0 <= 0`
  - `test_e2e_claimThenWithdraw`: `Should have claimable rewards: 0 <= 0`
  - `test_e2e_claimThenWithdrawVested`: `Should have claimed rFLR: 0 <= 0`
  - `test_e2e_claimThenWithdraw_withMinOut`: `Should have claimed rFLR: 0 <= 0`
- Conclusion:
  - Rerunning with 1Password-backed RPC variables improves the full suite from env setup failures to only 7 live Flare rFLR reward-state failures.
  - The OpenOcean branch-relevant tests pass; the pro API simulation remains skipped because the pro API key is not available in the searched 1Password paths.

## Review: diff from dev for OpenOcean branch
- User asked to check the diff from `dev` and focus on branch changes and tests.
- Compared using merge-base diff (`dev...HEAD`) and also checked the current unstaged working tree.
- Current branch: `feat/openocean_hook_referrer_support`.
- Branch commit count over `dev`: one commit, `f4cd90ab feat: support openocean routes outside sparkdex`.
- Merge-base diff from `dev` changes 17 files:
  - Adds `.Codex/sessions/context_session_1.md`.
  - Changes deployment/config wiring from OpenOcean caller to OpenOcean referrer.
  - Changes both OpenOcean hooks to store/use `OPENOCEAN_REFERRER` instead of `OPENOCEAN_CALLER`.
  - Deletes `src/libraries/OpenOceanSparkDexScaler.sol`.
  - Adds `src/libraries/OpenOceanDynamicAmountUpdater.sol`.
  - Adds/updates OpenOcean unit and live integration tests.
  - Updates OpenOcean API parser helpers.
- Current unstaged working tree also has OpenOcean-related test/updater changes plus this context file:
  - `src/libraries/OpenOceanDynamicAmountUpdater.sol`
  - `test/integration/openocean/OpenOceanDynamicAmountValidation.t.sol`
  - `test/integration/openocean/OpenOceanProAPIHookSimulation.t.sol`
  - `test/integration/openocean/OpenOceanSparkDexAPIScale.t.sol`
  - `test/unit/hooks/swappers/openocean/OpenOceanSparkDexHook.t.sol`
  - `.Codex/sessions/context_session_1.md`
- Main production behavior changes reviewed:
  - New updater validates top-level `swap` selector, exact `desc.referrer`, and partial-fill rejection.
  - New updater no longer validates a fixed OpenOcean caller.
  - New updater patches `desc.amount`, `desc.minReturnAmount`, and `desc.guaranteedAmount`.
  - ERC20 routes keep all call values at zero and leave route calldata untouched.
  - Native routes leave zero-value call routes untouched; legacy nonzero call-value routes are scaled if value sum equals original amount.
  - Hooks derive router `msg.value` from decoded native input and execution amount.
- Finding:
  - Deployment/generated/locked bytecode artifacts for `SwapOpenOceanSparkDexHook` and `ApproveAndSwapOpenOceanSparkDexHook` are stale.
  - Current compiled source exposes `OPENOCEAN_REFERRER()` and `INVALID_OPENOCEAN_REFERRER()`.
  - `script/generated-bytecode`, `script/locked-bytecode`, and `script/locked-bytecode-dev` still expose `OPENOCEAN_CALLER()` and `INVALID_OPENOCEAN_CALLER()`.
  - `DeployV2Core` now passes the referrer address as the second constructor arg, while `DeployV2Base` deploys from locked bytecode artifacts.
  - If deployed as-is via locked artifacts, the old scaler bytecode would treat the referrer address as the expected caller and reject real OpenOcean quotes whose caller is not the referrer.
  - Action needed before deployment/PR finalization: regenerate and lock bytecode artifacts for both OpenOcean hooks after the source change, or intentionally exclude deployment artifact updates if this branch is source/test-only.
- Test coverage reviewed:
  - Unit test coverage is strong for referrer validation, caller drift, partial-fill rejection, ERC20 unknown selectors, native/erc20 `usePrevHookAmount`, zero-value native route shape, legacy nonzero native call values, approval reset, and out-amount accounting.
  - Live dynamic validation covers Flare native FLR -> SPRK and ERC20 WFLR -> SPRK scale down/up.
  - Pro API hook simulation tests would cover hook lifecycle with returned live txData, but remain skipped locally because `OPENOCEAN_PRO_API_KEY` is unavailable.
- Verification during review:
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest`
    - Passed: 21 passed, 0 failed, 0 skipped.
  - Previous targeted runs in this session:
    - `OpenOceanSparkDexAPIScaleTest`: 2 passed.
    - `OpenOceanDynamicAmountValidationTest` with enable flag: 4 passed.
    - `OpenOceanProAPIHookSimulationTest` with enable flag but no API key: 2 skipped.
  - Previous full suite with 1Password RPC env: 3912 passed, 7 failed, 20 skipped; remaining failures are Flare rFLR reward-state failures unrelated to OpenOcean.

## OpenOcean hook inventory
- User asked whether the repo contains both OpenOcean SparkDex hooks and a general OpenOcean hook.
- Searched production hook/source paths for OpenOcean names.
- Current production hooks are only:
  - `src/hooks/swappers/openocean/SwapOpenOceanSparkDexHook.sol`
  - `src/hooks/swappers/openocean/ApproveAndSwapOpenOceanSparkDexHook.sol`
- There is no separately named generic production hook such as `SwapOpenOceanHook` or `ApproveAndSwapOpenOceanHook`.
- This branch generalizes behavior inside the existing SparkDex-named hooks by using `src/libraries/OpenOceanDynamicAmountUpdater.sol`.
- Test/helper files contain generic OpenOcean naming (`OpenOceanDynamicAmountValidation`, `OpenOceanProAPIHookSimulation`, `OpenOceanAPIParser`), but those are not production hooks.

## Tests in branch that are not in dev
- User asked for tests written in this branch that are not present in `dev`.
- Compared test functions in current working tree against `dev`.
- New test files added by the branch:
  - `test/integration/openocean/OpenOceanDynamicAmountValidation.t.sol`
  - `test/integration/openocean/OpenOceanProAPIHookSimulation.t.sol`
- New test functions in committed branch diff (`dev...HEAD`):
  - `OpenOceanDynamicAmountValidationTest.test_OpenOceanDynamicAmount_NativeInput_ScalesDown`
  - `OpenOceanDynamicAmountValidationTest.test_OpenOceanDynamicAmount_NativeInput_ScalesUp`
  - `OpenOceanDynamicAmountValidationTest.test_OpenOceanDynamicAmount_Erc20Input_ScalesDown`
  - `OpenOceanDynamicAmountValidationTest.test_OpenOceanDynamicAmount_Erc20Input_ScalesUp`
  - `OpenOceanProAPIHookSimulationTest.test_OpenOceanProAPI_SimulatesNativeSwapHookWithReturnedTxData`
  - `OpenOceanProAPIHookSimulationTest.test_OpenOceanProAPI_SimulatesApproveAndSwapHookWithReturnedTxData`
  - `OpenOceanSparkDexHookTest.test_Updater_ScalesDescFieldsAndLeavesErc20CallsUntouched`
  - `OpenOceanSparkDexHookTest.test_Updater_ScalesNativeValuesAndLeavesNativeCallDataUntouched`
  - `OpenOceanSparkDexHookTest.test_Updater_AllowsCallerDriftWhenReferrerMatches`
  - `OpenOceanSparkDexHookTest.test_RevertWhenReferrerDoesNotMatch`
  - `OpenOceanSparkDexHookTest.test_Updater_AllowsUnknownErc20RouteSelectors`
- Additional new test functions currently unstaged in the working tree:
  - `OpenOceanSparkDexHookTest.test_Updater_LeavesZeroValueNativeCallsUntouched`
  - `OpenOceanSparkDexHookTest.test_SwapHook_UsesPrevAmountWithZeroValueNativeCalls`
  - `OpenOceanSparkDexHookTest.test_ApproveAndSwapHook_UsesPrevAmountWithZeroValueNativeCalls`
  - `OpenOceanSparkDexHookTest.test_RevertWhenNativeCallValueSumIsPartial`
- Existing tests modified, not new by name:
  - `OpenOceanSparkDexAPIScaleTest.test_OpenOceanAPI_SparkDexCalldataScalesUp`
  - `OpenOceanSparkDexAPIScaleTest.test_OpenOceanAPI_SparkDexCalldataScalesDown`
  - Several existing `OpenOceanSparkDexHookTest` hook behavior tests now assert dynamic updater/referrer behavior instead of selector-aware SparkDex scaler behavior.

## Run branch-added OpenOcean tests
- User asked to run all tests listed as added/changed by this branch.
- Commands/results:
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest`
    - Passed: 21 passed, 0 failed, 0 skipped.
    - Covers all new unit tests from the committed branch and the additional unstaged zero-value native/partial call-value tests.
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexAPIScaleTest -vvv`
    - Passed: 2 passed, 0 failed, 0 skipped.
    - These tests existed on `dev` but are modified in this branch to validate the dynamic updater/referrer behavior.
  - `RUN_OPENOCEAN_DYNAMIC_VALIDATION=true FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanDynamicAmountValidationTest -vvv`
    - Passed: 4 passed, 0 failed, 0 skipped.
    - Live validation covered native and ERC20 scale down/up.
  - `RUN_OPENOCEAN_PRO_HOOK_SIMULATION=true FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest -vv`
    - Compiled and skipped both tests: 0 passed, 0 failed, 2 skipped.
    - Reason: `OPENOCEAN_PRO_API_KEY` is unavailable.
- Aggregate for these branch-relevant commands:
  - 27 passed, 0 failed, 2 skipped.

## Commit and push request
- User asked to commit and push everything currently in the working tree.
- Current branch before commit: `feat/openocean_hook_referrer_support`.
- Current tracked modifications to include:
  - `.Codex/sessions/context_session_1.md`
  - `src/libraries/OpenOceanDynamicAmountUpdater.sol`
  - `test/integration/openocean/OpenOceanDynamicAmountValidation.t.sol`
  - `test/integration/openocean/OpenOceanProAPIHookSimulation.t.sol`
  - `test/integration/openocean/OpenOceanSparkDexAPIScale.t.sol`
  - `test/unit/hooks/swappers/openocean/OpenOceanSparkDexHook.t.sol`
- Pre-commit `git diff --check` passed.
- Latest branch-relevant verification before commit:
  - `OpenOceanSparkDexHookTest`: 21 passed.
  - `OpenOceanSparkDexAPIScaleTest`: 2 passed.
  - `OpenOceanDynamicAmountValidationTest`: 4 passed.
  - `OpenOceanProAPIHookSimulationTest`: 2 skipped because `OPENOCEAN_PRO_API_KEY` is unavailable.

## superform-hook-master plan for PR 919 conflict resolution
- Role/request: acting as `superform-hook-master` sub-agent in planning/research mode only. No implementation code changes were made.
- PR: https://github.com/superform-xyz/v2-core/pull/919
- Branch/base from GitHub/`gh pr view`:
  - head: `feat/openocean_hook_referrer_support`
  - base: `dev`
  - title: `feat: openocean referrer hook support`
  - current body:
    - `feat: support openocean routes outside sparkdex`
    - `test: cover OpenOcean zero-value native routes`
  - merge state: `DIRTY`
  - commits:
    - `f4cd90ab` `feat: support openocean routes outside sparkdex`
    - `96e6ee7e` `test: cover OpenOcean zero-value native routes`
- Fresh refs inspected:
  - `origin/dev`: `c18b9401` (`feat: lower data length for stargate adapter (#918)`)
  - `origin/feat/openocean_hook_referrer_support`: `96e6ee7e`
  - merge base: `4aa84bd3a286926dfba26cd3ef6c5bbaa909499a`
- `git merge-tree --write-tree origin/dev origin/feat/openocean_hook_referrer_support` reports textual conflicts in:
  - `script/DeployV2Core.s.sol`
  - `script/output/prod/latest.json`
  - `script/output/staging/latest.json`
  - auto-merge touched `script/utils/Constants.sol` but did not report it as a textual conflict.
- Real conflict cause:
  - Current `dev` includes #917/#918 deployment/script/output changes for `Withdraw7540VaultHook`, `AcrossV3AdapterV2`, `StargateAdapterV2`, V2 bridge hooks, generated/locked bytecode, and deployment output timestamps/addresses.
  - PR 919 also modified deployment/config paths to replace OpenOcean caller-based constructor/config with referrer-based constructor/config.
  - The deployment output conflict should not be resolved by taking the PR side wholesale, because that would drop current `dev` deployment metadata.
- OpenOcean production behavior to preserve:
  - Existing hook names remain `SwapOpenOceanSparkDexHook` and `ApproveAndSwapOpenOceanSparkDexHook`; there is no separate generic OpenOcean production hook.
  - Hooks should store `OPENOCEAN_REFERRER` as an `address`, not `OPENOCEAN_CALLER` as `IOpenOceanCaller`.
  - Hook constructors should validate nonzero router and referrer, but should not require referrer code because the referrer is an identifier/address, not the OpenOcean caller contract.
  - Hooks should call `OpenOceanDynamicAmountUpdater.updateTxDataAmounts(txData_, OPENOCEAN_REFERRER, executionAmount, originalInputAmount)`.
  - Dynamic updater should validate `desc.referrer == expectedReferrer_`, allow caller drift, reject partial fill, update only `desc.amount`, `desc.minReturnAmount`, `desc.guaranteedAmount`, and avoid decoding/rewriting route internals.
  - ERC20 input routes should reject nonzero nested call values.
  - Native input routes should scale nested positive call values only when their sum equals original amount.
  - Native input routes with zero nested call values must remain valid and keep nested values at zero while the hook sends top-level `Execution.value = executionAmount`.
- Conflict-resolution MVP plan for Master implementation:
  1. Start from a clean `feat/openocean_hook_referrer_support` worktree and merge or rebase onto fresh `origin/dev`.
     - Recommended: merge `origin/dev` into the feature branch unless the project explicitly wants a linear rebase. A merge is lower risk for preserving the two PR commits and current PR discussion.
  2. For `script/output/prod/latest.json` and `script/output/staging/latest.json`, keep the `origin/dev` versions.
     - Reason: PR 919 does not deploy a new address set; its only meaningful output-file delta was stale conflict/timestamp cleanup. Current `dev` owns newer deployment metadata from #917/#918.
  3. For `script/DeployV2Core.s.sol`, keep current `dev` structure/indexing and manually reapply only the OpenOcean referrer changes.
     - Preserve #917/#918 additions: V2 adapters, V2 bridge hooks, `Withdraw7540VaultHook`, hook array length/indexing, assignment indexes, and availability logic.
     - Apply PR 919 OpenOcean changes at the current `dev` locations:
       - availability should require `configuration.openOceanRouters[chainId] != address(0)` and `configuration.openOceanReferrers[chainId] != address(0)`.
       - constructor/check args for both OpenOcean hooks should use `configuration.openOceanReferrers[chainId]`.
       - validation should require nonzero referrer and log `OpenOcean Referrer`; do not check `.code.length` on referrer.
       - deployment creation should require nonzero referrer and ABI-encode router, referrer, native token.
       - update skip messages from router/caller wording to router/referrer where relevant.
  4. For `script/utils/ConfigBase.sol`, `script/utils/ConfigCore.sol`, `script/utils/Constants.sol`, and `script/run/verify_v2_staging_prod.sh`, apply the PR's caller-to-referrer rename on top of `dev`.
     - `openOceanCallers` mapping becomes `openOceanReferrers`.
     - `OPENOCEAN_CALLER_FLARE` becomes `OPENOCEAN_REFERRER_FLARE = 0x0E24b0F342F034446Ec814281AD1a7653cBd85e9`.
     - Verification script should pass router/referrer/native to both OpenOcean hook constructors.
     - Preserve all #917/#918 constants and script changes from `dev`.
  5. For OpenOcean hooks/libraries/tests, keep PR 919 behavior unless a compile conflict appears after the merge.
     - Keep `src/libraries/OpenOceanDynamicAmountUpdater.sol`.
     - Keep removal of `src/libraries/OpenOceanSparkDexScaler.sol`.
     - Keep hook imports switched to `OpenOceanDynamicAmountUpdater`.
     - Keep tests covering caller drift, referrer mismatch, unknown ERC20 selectors, native value scaling, and zero-value native routes.
  6. Remove `.Codex/sessions/context_session_1.md` from the PR commit set before final push unless the Master explicitly wants internal session context committed.
     - Reason: `gh pr view` shows this file in the PR diff with large additions. It is useful local/session documentation, but it is not part of the OpenOcean feature surface.
  7. After resolution, verify:
     - `rg -n "^(<<<<<<<|=======|>>>>>>>)" script/DeployV2Core.s.sol script/output/prod/latest.json script/output/staging/latest.json src test script/utils script/run`
     - `git diff --check`
     - `forge build`
     - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest`
     - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexAPIScaleTest -vvv`
     - Optional/network-gated:
       - `RUN_OPENOCEAN_DYNAMIC_VALIDATION=true FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanDynamicAmountValidationTest -vvv`
       - `RUN_OPENOCEAN_PRO_HOOK_SIMULATION=true OPENOCEAN_PRO_API_KEY=... FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest -vv`
  8. Update PR description after implementation to describe:
     - referrer-gated OpenOcean dynamic amount support;
     - route-agnostic handling that no longer depends on SparkDex-only internal calldata rewriting;
     - zero-value native route coverage;
     - verification commands/results.
- PR description draft for after implementation:
  ```md
  ## Summary
  - Replace OpenOcean caller-gated SparkDex-only amount scaling with referrer-gated dynamic amount updates.
  - Preserve OpenOcean route calldata internals so routes outside SparkDex can be used when the expected referrer is present.
  - Support native OpenOcean routes whose nested calls carry zero value while the hook sends the scaled top-level native value.

  ## Tests
  - `forge build`
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest`
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexAPIScaleTest -vvv`
  - `RUN_OPENOCEAN_DYNAMIC_VALIDATION=true FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanDynamicAmountValidationTest -vvv`
  - `RUN_OPENOCEAN_PRO_HOOK_SIMULATION=true FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest -vv` (skips without `OPENOCEAN_PRO_API_KEY`)
  ```
- Approval gate: sub-agent should stop here and ask Master Codex to review/approve this plan before implementation.

## Master Codex approval for PR 919 conflict-resolution plan
- Reviewed the `superform-hook-master` plan.
- Approved the MVP conflict-resolution approach:
  - merge fresh `origin/dev` into `feat/openocean_hook_referrer_support`;
  - keep current `dev` deployment output metadata for `script/output/prod/latest.json` and `script/output/staging/latest.json`;
  - resolve `script/DeployV2Core.s.sol` by preserving current `dev` deployment structure while applying PR 919 OpenOcean router/referrer wiring;
  - preserve PR 919 OpenOcean hook/library/test behavior;
  - verify with build and focused OpenOcean tests;
  - update the PR description with the resolved behavior and verification results.

## PR 919 merge-conflict resolution
- Merged fresh `origin/dev` into `feat/openocean_hook_referrer_support`.
- Resolved textual conflicts in:
  - `script/DeployV2Core.s.sol`
  - `script/output/prod/latest.json`
  - `script/output/staging/latest.json`
- Resolution details:
  - Preserved current `dev` deployment output metadata/timestamps for `prod/latest.json` and `staging/latest.json`.
  - Preserved current `dev` hook slot layout in `DeployV2Core`:
    - `len = 78`
    - `ClaimFailedTransferHook` at index 70
    - `Withdraw7540VaultHook` at index 73
    - Stargate V2 hooks at indices 74 and 75
    - Across V2 hooks at indices 76 and 77
  - Kept PR 919 OpenOcean referrer wiring:
    - availability uses `configuration.openOceanRouters[chainId]` and `configuration.openOceanReferrers[chainId]`;
    - OpenOcean hook constructor args encode router, referrer, native token;
    - validation requires nonzero referrer but does not require referrer code;
    - stale router/caller skip copy was changed to router/referrer.
- Formatting/checks:
  - Ran `forge fmt` on `script/DeployV2Core.s.sol` and `script/utils/Constants.sol`.
  - `rg` found no conflict markers or stale OpenOcean caller deployment/config references in the resolved paths.
  - `git diff --cached --check` passed.
- Verification:
  - `forge build` passed with existing warnings.
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexHookTest` passed: 21 passed, 0 failed, 0 skipped.
  - `FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanSparkDexAPIScaleTest -vvv` passed: 2 passed, 0 failed, 0 skipped.
  - `RUN_OPENOCEAN_DYNAMIC_VALIDATION=true FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanDynamicAmountValidationTest -vvv` passed: 4 passed, 0 failed, 0 skipped.
  - `RUN_OPENOCEAN_PRO_HOOK_SIMULATION=true FOUNDRY_PROFILE=coverage forge test --match-contract OpenOceanProAPIHookSimulationTest -vv` completed with 0 passed, 0 failed, 2 skipped because `OPENOCEAN_PRO_API_KEY` is unavailable.
- PR description:
  - Updated https://github.com/superform-xyz/v2-core/pull/919 with the merge-resolution summary and verification results.

## SparkDEX hook inventory on current dev
- User asked what SparkDEX hooks are currently available.
- Current branch is clean `dev`; there are no production contracts or source files literally named `*SparkDex*`.
- Direct SparkDEX V2 support on Flare uses the generic Uniswap V2 pair:
  - `src/hooks/swappers/uniswap-v2/SwapUniswapV2Hook.sol` performs one exact-input router swap and assumes ERC20 allowance is already present; it supports native-to-token, token-to-native, and token-to-token paths.
  - `src/hooks/swappers/uniswap-v2/ApproveAndSwapUniswapV2Hook.sol` adds `approve(0) -> approve(amount) -> swap -> approve(0)` for ERC20 inputs and skips approvals for native input.
  - `script/utils/ConfigCore.sol` maps Flare to `SPARKDEX_V2_ROUTER_FLARE` (`0x4a1E5A90e9943467FAd1acea1E7F0e5e88472a1e`).
- Direct SparkDEX V4 support on Flare uses the generic Algebra Integral pair:
  - `src/hooks/swappers/algebra-integral/SwapAlgebraIntegralHook.sol` performs one `exactInputSingle` and assumes ERC20 allowance is already present.
  - `src/hooks/swappers/algebra-integral/ApproveAndSwapAlgebraIntegralHook.sol` adds the reset/approve/swap/reset sequence.
  - Both Algebra hooks reject native input, so FLR must be wrapped; `ConfigOtherHooks` maps Flare to router `0x69D57B9D705eaD73a5d2f2476C30c55bD755cc2F`.
- Indirect/aggregated SparkDEX routing is available through the current generic OpenOcean pair:
  - `src/hooks/swappers/openocean/SwapOpenOceanHook.sol` performs a single OpenOcean router execution and assumes ERC20 allowance is already present.
  - `src/hooks/swappers/openocean/ApproveAndSwapOpenOceanHook.sol` handles ERC20 reset/approval and skips approvals for native input.
  - These are generalized replacements for the former `SwapOpenOceanSparkDexHook` and `ApproveAndSwapOpenOceanSparkDexHook`; there is no additional separate OpenOcean pair.
- All six hooks are `HookType.NONACCOUNTING` / `HookSubTypes.SWAP` and support previous-hook amount chaining and output balance-delta accounting.
- `SwapSparkPSM*` hooks are Spark Protocol PSM hooks and are unrelated to SparkDEX.

## SwapAlgebraIntegralHook prod address history
- User asked when the `SwapAlgebraIntegralHook` address changed in `script/output/prod/latest.json`.
- On current `dev` (`65901ebf`), the Flare entry is still the original address `0xdbA7A6586b3Bf1C9763B5aaAEe860Bd6505dED1C`.
- That original address was first added on 2026-04-23 in commit `47c25cf9af9d518baf5ab998334de264ccbd8ec6` (`feat: added sparkdex v4 + deployment of paymaster [SUP-19592] (#877)`).
- A later feature-branch commit `d987590bc07e7cf6cf60e9deb56e28851216a4fe` (`feat: more standardized hooks deployment`) changed the Flare prod entry:
  - old: `0xdbA7A6586b3Bf1C9763B5aaAEe860Bd6505dED1C`
  - new: `0xF7291FD5Ef4c59bc81314BCf2A1546008edF8F41`
- Commit timestamp: 2026-07-09 10:47:24 +03:00 (07:47:24 UTC); the JSON `updated_at` was changed from `2026-07-08T09:12:17Z` to `2026-07-09T07:38:25Z`.
- The commit is contained in `origin/feat/deployments-hooks-standardization`; it is not contained in `dev`/`origin/dev` as of this check. The feature branch tip retains the new `0xF729...` address.
- The same commit changed `ApproveAndSwapAlgebraIntegralHook` from `0xc59Ee68B274ecA9F64484e25ffeA50Bf32D4Ba01` to `0x87E8958d0a2Bd030060fa63852770d5bdA303153`.

## superform-hook-master plan: align five hook NatSpec layouts with bundler local config

Date: 2026-07-13.

### Scope and evidence
- Request is a NatSpec-only PR against `dev`; do not change Solidity execution logic, tests, generated artifacts, deployment files, or bundler config.
- Source of truth compared: `/Users/subhasishgoswami/Documents/superform/bundler/hooks_config.local.json` only.
- Bundler parser semantics were confirmed in `services/hooks-registry-svc/domain/hook_build_encoding/build_path_natspec.go`:
  - `_paramLength` produces a computed length field;
  - `_skipParam` retains backend metadata but emits no calldata bytes;
  - `_optional` makes a fixed-width caller value optional and strips the suffix from the resolved parameter name.

### Minimal comment-only implementation plan
1. Update `src/hooks/tokens/permit2/BatchTransferFromHook.sol`.
   - Change only the `signature` NatSpec offset from `data.length - 65` to the canonical contiguous encoder expression:
     `136 + 20 * tokensLength + 32 * tokensLength + 6 * tokensLength`.
   - Keep the actual implementation reading the final 65 bytes unchanged.
2. Update `src/hooks/claim/flare/WithdrawRFLRHookV2.sol`.
   - Rename only the documented field from `minOut` to `minOut_optional`; retain `uint256`, offset `52`, and all code unchanged.
3. Update `src/hooks/claim/flare/WithdrawVestedRFLRHookV2.sol`.
   - Apply the same comment-only `minOut` to `minOut_optional` directive change.
4. Update `src/hooks/bridges/stargate/StargateSendHookV2.sol`.
   - Rename the documented length fields and all comment references to `extraOptions_paramLength` and `composeMsg_paramLength`.
   - Append the three bundler sideband metadata directives after `composeMsg`:
     - `address recipient_skipParam = BytesLib.toAddress(data, 0);`
     - `address outputToken_skipParam = BytesLib.toAddress(data, 0);`
     - `uint256 destinationChainId_skipParam = BytesLib.toUint256(data, 0);`
   - Do not add fields to `StargateSendData` or decode these metadata values on chain.
5. Update `src/hooks/bridges/debridge/DeBridgeSendOrderAndExecuteOnDstHook.sol`.
   - Correct the documented input name from `requireSuccessfullExecution` to `requireSuccessfulExecution`.
   - Correct the final packed field from `uint256 referralCode = BytesLib.toUint256(...)` to `uint32 referralCode = BytesLib.toUint32(...)`.
   - Do not rename the external deBridge vendor struct member `requireSuccessfullExecution`; that upstream ABI field remains misspelled, while the hook's packed input/local variable is correctly named `requireSuccessfulExecution`.
6. Create a focused branch from current `dev`, commit only the five Solidity files, push, and open a PR to `dev` with a NatSpec/config-alignment title and body. Explicitly stage file paths rather than using `git add -A`, so this required session-context update is not included in the NatSpec-only PR.

### Questionable-but-intentional documentation details
- `BatchTransferFromHook`: the proposed formula describes canonical bundler encoding and is equivalent to `data.length - 65` only for a contiguous payload with no ignored bytes before the signature. The Solidity decoder deliberately reads the final 65 bytes. Apply the requested formula in NatSpec, but do not alter decoder behavior.
- `StargateSendHookV2`: the three `_skipParam` lines are not actual calldata fields, despite appearing under the data-layout NatSpec. They are intentional bundler parser directives for sideband fee/routing metadata and must not trigger Solidity changes.
- The `_optional`, `_paramLength`, and `_skipParam` suffixes are encoder grammar, not Solidity variable names. This PR intentionally makes contract NatSpec double as the bundler's build-path schema.

### Verification
1. Inspect the PR diff and confirm every changed line begins with `///`; exactly the five hook source files should be in the committed diff.
2. Run `git diff --check` before committing.
3. Run `forge fmt --check` and `forge build` in `v2-core` to prove the comment edits do not disturb formatting or compilation.
4. Recheck the desired directive strings with `rg` and compare the five NatSpec blocks to `hooks_config.local.json`; no update to the non-local hooks config is in scope.
5. In the PR description, state that runtime bytecode behavior is unchanged and list the build/format verification results.

Status: plan appended by `superform-hook-master`; awaiting Master Codex review. Do not edit the five Solidity files until Master Codex approves this plan.

## Master Codex approval: align five hook NatSpec layouts with bundler local config
- Reviewed and approved the `superform-hook-master` NatSpec-only plan.
- Implementation is limited to the five identified Solidity documentation blocks; runtime Solidity, tests, generated artifacts,
  deployment files, and bundler configs remain unchanged.
- The branch commit will explicitly stage only the five Solidity files so this required session-context update stays out of the PR.

## `forge b` failure reproduction on dev
- User reported that `forge b` fails and asked to run it.
- Current branch at diagnosis time: clean `dev` relative to `origin/dev`, except for the required session context file.
- `forge b` reproduced the failure with Foundry `1.4.3-stable` and Solc `0.8.30`.
- Compilation fails on exactly three test helper functions declared `view` even though they call the non-view Forge cheatcode `vm.getRecordedLogs()`:
  - `test/integration/MinimalBaseNexusIntegrationTest.t.sol:_checkUserOperationResults`
  - `test/integration/MinimalBaseNexusIntegrationTest.t.sol:_checkValidateUserOperationResults`
  - `test/integration/stargate/StargateAdapterE2EFork.t.sol:_assertExecutionFailedEmitted`
- The checked-in `lib/forge-std/src/Vm.sol` declares `getRecordedLogs()` without `view`, so Solidity correctly emits error 8961 for each helper.
- `git blame` shows the three invalid `view` annotations were introduced by commit `8e79ce1f0` on 2026-07-08; the `getRecordedLogs()` calls predate those annotations.
- `forge b --skip test` passed, confirming production contracts and scripts compile and that the blocker is test-only.
- No source fix was applied because the user asked to reproduce/run the failure, not explicitly to modify code. The minimal fix is to remove `view` from those three internal helper declarations and rerun `forge b`.

## Forge bytecode artifact location
- Repository Forge configuration uses `out = "out"` and `cache_path = "cache"`; build-info output is disabled.
- `forge b --skip test` writes contract artifact JSON files under `out/<SourceFile>.sol/<ContractName>.json`.
- Creation bytecode is stored in `.bytecode.object`; deployed/runtime bytecode is stored in `.deployedBytecode.object`.
- Example: `out/SwapOpenOceanHook.sol/SwapOpenOceanHook.json`.
- The `out` directory is shared across builds. `--skip test` does not remove test artifacts left by earlier builds, so `forge clean` before rebuilding is needed if an artifact directory containing only the current invocation is required.

## NatSpec alignment PR for five bundler hook layouts
- Implemented the approved NatSpec-only alignment on branch `docs/sync-hook-natspec-config`.
- Updated only documentation comments in:
  - `src/hooks/tokens/permit2/BatchTransferFromHook.sol`
  - `src/hooks/claim/flare/WithdrawRFLRHookV2.sol`
  - `src/hooks/claim/flare/WithdrawVestedRFLRHookV2.sol`
  - `src/hooks/bridges/stargate/StargateSendHookV2.sol`
  - `src/hooks/bridges/debridge/DeBridgeSendOrderAndExecuteOnDstHook.sol`
- Confirmed every committed changed line is a `///` NatSpec comment.
- Confirmed normalized layouts for all five hooks exactly match
  `/Users/subhasishgoswami/Documents/superform/bundler/hooks_config.local.json`.
- Verification:
  - `git diff --check` passed.
  - `forge build --skip test` passed with an existing warning.
  - Full `forge build` reproduced the existing `dev` failures in three test helpers declared `view` while calling
    `vm.getRecordedLogs()`; this PR does not touch those tests.
  - Target files contain pre-existing formatter drift, but no formatter diff touches the newly changed NatSpec lines.
- Commit: `a1cbe073` (`docs: align hook natspec with bundler config`).
- Pull request: https://github.com/superform-xyz/v2-core/pull/947
- The required `.Codex/sessions/context_session_1.md` updates remain unstaged and were intentionally excluded from the
  NatSpec-only commit and PR.

## Prod deployed bytecode comparison tooling audit
- User asked whether a repository script compares deployed production-address bytecode with freshly compiled local artifacts.
- No existing script performs an exact all-contract comparison of RPC-fetched runtime bytecode against `out/<Source>.sol/<Contract>.json:.deployedBytecode.object`.
- Closest existing tooling:
  - `script/run/verify/verify_v2_staging_prod.sh prod` maps production addresses, contract sources, and constructor args, then invokes `forge verify-contract` through Blockscout/Etherscan. It verifies current source/compiler output through explorers, but is not a direct local-artifact-vs-RPC bytecode sweep.
  - `script/run/deploy/deploy_v2_staging_prod.sh` check mode computes deterministic CREATE2 addresses from `script/locked-bytecode/` and checks whether code exists at those addresses. It uses locked artifacts rather than fresh `out/` artifacts and does not compare runtime code hashes.
  - `script/run/utils/lib_deploy.sh:verify_deployments` only calls `cast codesize`; it verifies code presence, not equality.
  - `script/run/tooling/compare_contract_deployments.py` compares addresses between aggregate and per-network JSON manifests, not bytecode. It also currently resolves the prod path incorrectly as `script/script/output/prod/latest.json` when run from the repo root.
- Installed Foundry `1.4.3-stable` provides `forge verify-bytecode <address> <path>:<contract>`, which is the appropriate single-contract primitive and supports RPC, chain, constructor args, and creation/runtime selection.
- A robust repository-wide comparer should reuse the source/constructor mappings from `verify_v2_staging_prod.sh`, iterate `script/output/prod/<chain>/<Network>-latest.json`, and invoke `forge verify-bytecode` (or compare normalized runtime code while accounting for immutables/link references). A raw hash comparison against `.deployedBytecode.object` is unsafe for contracts with immutable values, such as `SwapOpenOceanHook`.

## `verify_v2_staging_prod.sh` behavior
- User asked what `script/run/verify/verify_v2_staging_prod.sh` does.
- It is a block-explorer source-verification orchestrator, not a direct fresh-`out/` versus on-chain runtime-bytecode comparison.
- Usage is `./script/run/verify/verify_v2_staging_prod.sh staging|prod`.
- It sources `lib_deploy.sh`, loads the selected environment's network configuration, RPC credentials, and explorer API credentials.
- Its current default chain filter is Ethereum (1), Base (8453), BSC (56), Arbitrum (42161), Avalanche (43114), and Flare (14); an empty `CHAINS_TO_VERIFY` array would select every configured network.
- It reads contract addresses from per-chain files at `script/output/<environment>/<chainId>/<Network>-latest.json`.
- For every selected deployed contract it:
  - maps the contract name to a local Solidity source path;
  - reconstructs ABI-encoded constructor arguments using chain-specific constants and addresses from the deployment JSON;
  - skips selected external Nexus library contracts;
  - invokes `forge verify-contract` against Etherscan V2 for most networks or Flare Blockscout for chain 14;
  - waits `VERIFY_DELAY=5` seconds between submissions.
- After submissions, it queries explorer `getsourcecode` APIs for every selected address, with a one-second delay, and reports whether each address has verified source published.
- It exits nonzero if a network verification run fails, any contract verification command fails, or the final explorer sweep finds unverified contracts.
- It does not deploy or change contracts on-chain, but it does submit/publish verification metadata and source code to external explorers.
- It does not read `out/*.json` directly, does not call `cast code`, does not call `forge verify-bytecode`, and does not hash-compare runtime bytecode.
- Important limitation for the user's goal: for an address already verified on Etherscan, `forge verify-contract` can treat it as already verified and the final sweep only confirms that some source is published. That does not guarantee the already-published source/bytecode matches the current checkout's freshly built artifacts. Flare uses `--skip-is-verified-check`, but the overall script is still explorer-oriented rather than an explicit local bytecode comparison.

## superform-hook-master research: Aerodrome current swap surfaces and hook readiness

Date: 2026-07-16.

### Scope and status
- Planning/research only. No production or test code was changed.
- Primary sources inspected at their current heads:
  - Aerodrome protocol contracts, commit `1ba30815bba620f7e9faa34769ffd00c214c9b82`:
    https://github.com/aerodrome-finance/contracts
  - Aerodrome Slipstream contracts, commit `f8717faaae6e6717db3c8e3850149c01a79c0603`:
    https://github.com/aerodrome-finance/slipstream
  - Aerodrome docs, commit `7c0df032b58ee08b621ace19753d8abc260dd321`:
    https://github.com/aerodrome-finance/docs
  - Velodrome/Dromos Universal Router, commit `540899c395004a50179bcce2774882995b3f381c`:
    https://github.com/velodrome-finance/universal-router
- As of this research date, public Aerodrome is still described as **MetaDEX02**, with both classic stable/volatile pools and Slipstream concentrated-liquidity pools. The docs call Aero/MetaDEX03 forthcoming; no canonical MetaDEX03 replacement deployment/interface is publicly exposed in these repositories yet:
  https://github.com/aerodrome-finance/docs/blob/main/content/about.mdx

### Classic stable/volatile router
- Canonical Base contracts from Aerodrome's official contracts repo/security page:
  - Router: `0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43`
  - PoolFactory: `0x420DD381b31aEf6683db6B902084cB0FFECe40Da`
  - FactoryRegistry: `0x5C3F18F06CC09CA1910767A34a20F771039E37C0`
  - Base WETH: `0x4200000000000000000000000000000000000006`
  - Sources/deployments:
    https://github.com/aerodrome-finance/contracts/blob/main/contracts/interfaces/IRouter.sol
    https://github.com/aerodrome-finance/contracts/blob/main/contracts/Router.sol
    https://github.com/aerodrome-finance/contracts#deployment
- `IRouter.Route` is `(address from, address to, bool stable, address factory)`. `factory == address(0)` resolves to the default factory; nonzero factories must be approved by `FactoryRegistry`.
- Exact-input surfaces are:
  - `swapExactTokensForTokens(amountIn, amountOutMin, routes, to, deadline)`;
  - `swapExactETHForTokens(amountOutMin, routes, to, deadline)` with `msg.value` as input;
  - `swapExactTokensForETH(amountIn, amountOutMin, routes, to, deadline)`;
  - fee-on-transfer variants also exist, but should not be included in an initial Superform hook without explicit product need and dedicated accounting tests.
- `getAmountsOut(amountIn, routes)` is the router quote helper. It supplies an expected amount, not slippage protection; the caller must derive a nonzero `amountOutMin` and a finite `deadline`.
- ERC20 routes use ordinary approval to the classic Router. Native routes represent the pool endpoint as WETH; the Router wraps/unwraps ETH and validates the first/last route token.

### Slipstream generations and latest deployment
- Slipstream preserves the Uniswap V3 callback/periphery model but addresses pools by `int24 tickSpacing`, not a fixed fee tier. Swap fees can be dynamic through factory fee modules.
- Aerodrome's official Slipstream README records three Base factory generations. It explicitly says the **Gauges V3** deployment is the current latest deployment, while existing older gauges remain in use and all new gauges are created from the latest generation:
  https://github.com/aerodrome-finance/slipstream/blob/main/README.md
- Original Slipstream deployment:
  - CLFactory: `0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A`
  - SwapRouter: `0xBE6D8f0d05cC4be24d5167a3eF062215bE6D18a5`
  - QuoterV2: `0x254cF9E1E6e233aa1AC962CB9B05b2cfeAaE15b0`
- Gauge-caps/second factory deployment:
  - CLFactory: `0xaDe65c38CD4849aDBA595a4323a8C7DdfE89716a`
  - SwapRouter: `0xcbBb8035cAc7D4B3Ca7aBb74cF7BdF900215Ce0D`
  - Quoter: `0x3d4C22254F86f64B7eC90ab8F7aeC1FBFD271c6C`
- Current Gauges V3/latest factory deployment:
  - CLFactory: `0xf8f2eB4940CFE7d13603DDDD87f123820Fc061Ef`
  - Pool implementation: `0xc770898522D2A9c8Da7A10D63989b6b58305B665`
  - SwapRouter: `0x698Cb2b6dd822994581fEa6eA4Fc755d1363A92F`
  - Quoter: `0x514c8B5f54112481E28028F1166Bd78501089259`
  - MixedRouteQuoterV3: `0xCd2A7D98e82D6107eac1828ce8DeAA6acB65b555`
- Each direct Slipstream `SwapRouter` is bound to one factory. The on-chain `factory()` getters for the three routers above resolve to the three factories in the same order.
- Direct exact-input ABI:
  - `exactInputSingle({tokenIn, tokenOut, tickSpacing, recipient, deadline, amountIn, amountOutMinimum, sqrtPriceLimitX96})`;
  - `exactInput({path, recipient, deadline, amountIn, amountOutMinimum})` for multihop routes, where each hop is packed as token / 3-byte tick spacing / token.
  - Interface/source:
    https://github.com/aerodrome-finance/slipstream/blob/main/contracts/periphery/interfaces/ISwapRouter.sol
    https://github.com/aerodrome-finance/slipstream/blob/main/contracts/periphery/SwapRouter.sol
- ERC20 payment is ordinary `transferFrom` against the direct SwapRouter. Native input works only when `tokenIn` is WETH and the call carries enough ETH; native output requires routing output WETH to the router and unwrapping through a multicall. A WETH-only MVP is materially simpler.
- The direct router's callback verifies that `msg.sender` is the deterministically computed pool for its immutable factory/token/tick-spacing tuple. The hook must still validate payload endpoints, tick spacing, recipient, deadline, and selected immutable router.
- Quoters use swap-and-revert simulation and are intentionally not gas efficient for on-chain execution. Quote off chain through `eth_call`, then set `amountOutMinimum` separately. `MixedRouteQuoterV3` supports classic V2 plus all three CL factories through bitmask-encoded pool parameters:
  https://github.com/aerodrome-finance/slipstream/blob/main/contracts/periphery/lens/MixedRouteQuoterV3.sol

### Newer three-factory Universal Router
- The current official Universal Router Base deployment JSON points to:
  - UniversalRouter: `0xC5b6786D7B64767D775877b0B6A319AD946B11B5`
  - Permit2: `0x494bbD8A3302AcA833D307D11838f18DbAdA9C25`
  - Source: https://github.com/velodrome-finance/universal-router/blob/main/deployment-addresses/base.json
- This `C5b...` deployment was introduced in commit `540899c` on 2026-04-10 to support three Slipstream factories. Its Base deployment parameters bind:
  - classic Aerodrome factory `0x420DD...`;
  - raw CL factory selector to second factory `0xaDe65...`;
  - selector flag `0x100000` to original factory `0x5e7BB...`;
  - selector flag `0x080000` to latest factory `0xf8f2e...`.
  - Source: https://github.com/velodrome-finance/universal-router/blob/main/script/deployParameters/DeployBase.s.sol
- On-chain getter checks against Base confirmed all of those immutables, WETH, and Permit2. The repository also contains a fork verifier that compares immutables and metadata-stripped runtime bytecode:
  https://github.com/velodrome-finance/universal-router/blob/main/test/fork/VerifyDeployUniversalRouter.t.sol
- Aerodrome's public security page still lists older UniversalRouter `0x6Cb442acF35158D5eDa88fe602221b67B400Be3E` and only the original Slipstream deployment:
  https://aerodrome.finance/security
  That address still has code and is still used, so it should not be called deprecated without Aerodrome confirmation. It is nevertheless not the all-three-factory router recorded by the current deployment repository. This documentation mismatch must be resolved before hard-coding a production integration address.
- Current Universal Router entry point is `execute(bytes commands, bytes[] inputs, uint256 deadline)`.
- Exact-input command forms in the current `Dispatcher` are:
  - `0x08` V2 exact input with input ABI `(recipient, amountIn, amountOutMin, packedPath, payerIsUser, isUni)`; use `isUni=false` and pack Aerodrome hops as token / one-byte stable flag / token.
  - `0x00` CL exact input with the same input tuple; use `isUni=false` and pack token / 3-byte tickSpacing-plus-factory-selector / token.
  - Source: https://github.com/velodrome-finance/universal-router/blob/main/contracts/base/Dispatcher.sol
- The current router first tries ordinary ERC20 `transferFrom` and falls back to Permit2. Therefore an approve/reset Superform hook can approve the `C5b...` router directly without requiring Permit2. A Permit2 flow instead requires token approval to the Permit2 contract plus Permit2 allowance/signature state:
  https://github.com/velodrome-finance/universal-router/blob/main/contracts/modules/Permit2Payments.sol
- Native input/output uses explicit `WRAP_ETH` / `UNWRAP_WETH` commands and router custody. The exact-input amount, min output, wrap amount, `msg.value`, recipients, and final sweep/unwrap behavior must remain mutually consistent.

### Closest Superform patterns
- `SwapUniswapV2Hook` and `ApproveAndSwapUniswapV2Hook` are the closest safe pattern for the classic Aerodrome router: typed exact-input calls, native branches, finite deadline, previous-hook amount scaling, proportional min-out scaling, recipient forced to the smart account, approve-zero/approve-amount/swap/approve-zero, and output balance-delta accounting. They are not ABI-compatible as-is because Aerodrome uses `Route[]` with stable/factory fields instead of `address[] path`.
- `SwapUniswapV3Hook` and `ApproveAndSwapUniswapV3Hook` are the closest pattern for a direct Slipstream router. A dedicated implementation would replace `uint24 fee` with `int24 tickSpacing` and bind a specific factory/router generation.
- `SwapOpenOceanHook` demonstrates the risks of accepting externally generated routed calldata. A Universal Router integration should not copy the broad raw-calldata model: Universal Router command data can transfer, sweep, bridge, invoke V4, execute subplans, allow command failure, and leave custody dust.

### Security posture for a future Aerodrome hook
- Prefer constructing typed calls/commands on chain from a narrow hook payload. Do not accept arbitrary Universal Router `commands` plus `inputs` without a complete parser and allowlist.
- If Universal Router is selected, MVP command allowlist should be only one exact-input V2 command or one exact-input CL command. Reject:
  - the allow-revert flag/partial fills;
  - exact-output commands;
  - arbitrary `TRANSFER`, `TRANSFER_FROM`, `SWEEP`, Permit2 permit/transfer commands, V4, bridge, cross-chain, and `EXECUTE_SUB_PLAN` commands;
  - unexpected router custody, payer flags, or recipient sentinels.
- Force the final recipient to `account`; validate input/output endpoints against the standard swap header; cap hop count; validate classic stable flags and CL factory-selector bits; require a finite unexpired deadline and nonzero amount/min-out.
- For `usePrevHookAmount`, rebuild the exact-input command with the previous hook amount and proportionally update min-out. Do not try to patch opaque arbitrary command blobs.
- For the current Universal Router direct-approval path, use the repo pattern `approve(0) -> approve(executionAmount) -> execute -> approve(0)`. Verify this behavior on a Base fork against the exact selected deployment before shipping.
- Quote freshness matters more for Slipstream Gauges V3 because swap fees can be dynamic. Quoters determine an expected output; they do not replace explicit min-out/deadline protection.
- Always assert zero unintended router allowance after execution and no account/router input dust in fork tests. Track output through the existing pre/post balance-delta lifecycle.

### MVP plan if an Aerodrome hook is requested later
1. Product decision first: classic stable/volatile only, latest-factory Slipstream only, or the newer all-three-factory Universal Router. Recommended coverage target is the current three-factory Universal Router, but only after Aerodrome confirms `0xC5b...` as the intended production integration address despite the website still listing `0x6Cb...`.
2. Add `SwapAerodromeUniversalRouterHook` and `ApproveAndSwapAerodromeUniversalRouterHook` using the standard `ISuperHookSwap` header and a typed payload. Support exact-input ERC20/WETH routes first; no arbitrary calldata, Permit2 signatures, mixed V2/CL command chains, partial fills, V4, bridge, or cross-chain commands.
3. Encode exactly one command from a route-kind enum:
   - classic stable/volatile multihop with validated `(token, stable, token)` packed path; or
   - Slipstream multihop with validated `(token, tickSpacing|factorySelector, token)` packed path across the three known factories.
4. Force `recipient=account`, `payerIsUser=true`, `isUni=false`, and use the deadline-bearing `execute` overload. Scale `amountIn` and `amountOutMin` when previous-hook sizing is enabled.
5. Use ordinary direct approval to the selected Universal Router in the approve-and-swap variant. Defer Permit2 and native ETH wrapping/unwrapping to follow-up scope unless product requires them for MVP; WETH remains supported as ERC20.
6. Add deterministic unit tests for every validation boundary and Base fork tests for classic stable, classic volatile, original CL, second CL, and latest Gauges V3 CL routes. Verify recipient/output delta, exact input consumption, scaled previous-hook amount/min-out, allowance reset, no dust, expired deadlines, invalid selector bits, wrong endpoints, and rejection of every non-MVP command class.
7. Add deployment config only after re-reading the official deployment JSON and on-chain immutables at implementation time. Do not rely solely on the currently stale Aerodrome security table.

### Unresolved questions for Master/product/Aerodrome
1. Does Aerodrome officially designate `0xC5b6786D7B64767D775877b0B6A319AD946B11B5` as the current integration router, and is `0x6Cb442...` merely retained for legacy routes? There is no explicit public deprecation statement.
2. Must the Superform feature cover liquidity in all three Slipstream factories, or only the latest Gauges V3 factory? The official README says older gauges remain in use.
3. Is classic stable/volatile plus CL mixed routing required in one swap, or are separate route types acceptable for MVP?
4. Is native ETH input/output required at launch, or is canonical Base WETH sufficient? Native support materially expands command/custody validation.
5. Should Superform intentionally use direct router approval, which current `C5b...` supports, or adopt Permit2? Permit2 would add signature/nonce/allowance lifecycle work without being necessary for smart-account execution.
6. What routing/quote service will produce the selected paths, and will it expose the three CL factory selector bits deterministically? Official developer documentation is sparse and the Universal Router README lags its current six-field command ABI.

Status: research and prospective MVP plan appended by `superform-hook-master`; awaiting Master Codex review. Do not implement an Aerodrome hook until Master Codex approves a concrete scope and the router-address discrepancy is resolved.

## Master Codex review: Aerodrome research baseline
- Reviewed and approved the `superform-hook-master` research note as the planning baseline for any future Aerodrome swap-hook work.
- This turn was research-only. No Aerodrome production contract, test, deployment, or configuration implementation was approved or created.
- Confirmed the current repository hook model: exact-input swap hooks use the shared `ISuperHookSwap` layout, rebuild or tightly validate protocol calls, force output to the smart account, resize input/min-out for previous-hook chaining, and publish the output balance delta through the BaseHook pre/post lifecycle.
- Confirmed current public Aerodrome is MetaDEX02. The latest deployed Slipstream generation is named Gauges V3 and coexists with two older live CL factories; it is not the forthcoming Slipstream V3/MetaDEX03 product.
- Confirmed the newer Universal Router repository records Base deployment `0xC5b6786D7B64767D775877b0B6A319AD946B11B5` with classic Aerodrome plus all three Slipstream factories, while Aerodrome's public security page still lists legacy Universal Router `0x6Cb442acF35158D5eDa88fe602221b67B400Be3E`.
- Before implementation, obtain an explicit product decision on classic versus CL coverage, native ETH versus WETH-only scope, and direct routers versus Universal Router. Also confirm the intended production Universal Router address with Aerodrome; do not infer deprecation from repository recency alone.
- If implementation is later requested, ask `superform-hook-master` to refine this baseline into a concrete plan for the approved scope before editing hook code.
## superform-hook-master design: Aerodrome Universal Router swap hooks

Date: 2026-07-16.

### Status and scope
- Planning only. This design is awaiting Master Codex review; do not implement it yet.
- The intended schema is sufficient for an MVP restricted to one homogeneous exact-input route through either Aerodrome classic pools or Slipstream pools.
- It is not sufficient for mixed classic/Slipstream routing or native ETH wrapping/unwrapping. Those require multiple Universal Router commands and are intentionally excluded.

### Contracts and constructor
- Add `SwapAerodromeUniversalRouterHook` and `ApproveAndSwapAerodromeUniversalRouterHook` as `HookType.NONACCOUNTING` / `HookSubTypes.SWAP` hooks implementing the same swap, context-aware, inflow/outflow, and outflow interfaces as the existing Uniswap swap hooks.
- Recommended constructor for both hooks: `constructor(address universalRouter_)`.
- Validate `universalRouter_ != address(0)` and store it as immutable `UNIVERSAL_ROUTER`. No WETH or native-token constructor parameter is needed because MVP treats WETH as an ordinary ERC20.
- Deployment must not proceed until the production Universal Router address is confirmed. The researched latest three-factory Base deployment is `0xC5b6786D7B64767D775877b0B6A319AD946B11B5`, while Aerodrome's public security documentation still lists the older router.

### BaseHook build inputs and standard swap header
- `build(prevHook, account, hookData)` retains normal `BaseHook` semantics:
  - `prevHook` is `address(0)` when chaining is disabled; when `usePrevHookAmount` is true it must be nonzero and expose the previous result.
  - `account` is the smart account, forced swap recipient, and Universal Router payer.
  - `hookData` uses the standard `ISuperHookSwap` layout: 52-byte strategy prefix, then `inputToken`, `outputToken`, `inputAmount`, `outputQuote`, `outputMin`, `usePrevHookAmount`, `payloadLength`, and payload at offset 221.
- `inputAmount` is the signed/OMS baseline amount. `outputQuote` is the expected off-chain quote and is not sent to the router. `outputMin` is the enforced slippage floor. Require `inputAmount > 0`, `outputMin > 0`, and preferably `outputQuote >= outputMin`.
- Keep the standard `encodeSwapData`, decoder, sizing, amount replacement, and `inspect` behavior. The only replaceable amount is `inputAmount` at offset 92; `inspect` returns `outputToken`.

### Aerodrome payload
- Exact payload: `abi.encode(uint8 routeKind, uint256 deadline, bytes packedPath)`.
- Route kinds are fixed as `0 = CLASSIC` and `1 = SLIPSTREAM`; reject every other value.
- Require an unexpired deadline and canonical, fully bounded payload/path data. In particular, the outer `payloadLength` must not extend beyond `hookData`, and ignored trailing payload bytes should be rejected.
- The packed path is caller controlled but must be fully parsed by the hook before constructing router calldata:
  - Classic: `token0(20) | stable0(1) | token1(20) [| stableN(1) | tokenN+1(20)]`. Length is `20 + 21 * hopCount`; every stable byte must be exactly `0` or `1`.
  - Slipstream: `token0(20) | poolParam0(3) | token1(20) [| poolParamN(3) | tokenN+1(20)]`. Length is `20 + 23 * hopCount`; each `poolParam` is big-endian `uint24(factoryFlag | tickSpacing)` as produced by `abi.encodePacked(uint24(...))`.
- Require 1 to 9 hops, all token addresses nonzero, no equal adjacent tokens, first token equal to header `inputToken`, and last token equal to header `outputToken`.
- For Slipstream, require a nonzero low-19-bit tick spacing, no reserved high bits, and factory selector exactly one of:
  - `0x000000`: the router's primary CL factory (`0xaDe65c...` in the researched deployment).
  - `0x100000`: CL factory 2 / original Slipstream (`0x5e7BB...`).
  - `0x080000`: CL factory 3 / latest Gauges V3 (`0xf8f2e...`).
- Reject selector `0x180000` and bits above bit 20. The current router otherwise masks/handles these values in a way a hook should not accept implicitly.

### Internally constructed Universal Router call
- Construct exactly one command and one input; callers never supply commands or router inputs.
- Classic route:
  - `commands = hex"08"` (`V2_SWAP_EXACT_IN`, allow-revert flag unset).
  - `inputs[0] = abi.encode(account, effectiveAmountIn, effectiveOutputMin, packedPath, true, false)`.
- Slipstream route:
  - `commands = hex"00"` (`V3_SWAP_EXACT_IN`, allow-revert flag unset).
  - `inputs[0] = abi.encode(account, effectiveAmountIn, effectiveOutputMin, packedPath, true, false)`.
- For both, call `IUniversalRouter.execute(commands, inputs, deadline)` with target `UNIVERSAL_ROUTER` and value `0`.
- Fields fixed internally are: exact-input command, no allow-revert bit, one input, recipient `account`, `payerIsUser = true`, `isUni = false`, call target, and zero ETH value. The caller controls only route kind, deadline, validated path, header amounts, and tokens.

### Previous-hook amount and allowances
- With `usePrevHookAmount == false`, use header `inputAmount` and `outputMin` unchanged.
- With it enabled, require a nonzero `prevHook`, require its `getOutToken(account)` to equal header `inputToken`, obtain `effectiveAmountIn = getOutAmount(account)`, and require it nonzero.
- Scale `effectiveOutputMin` from the original `(inputAmount, outputMin)` using the repository's `HookDataUpdater.getUpdatedOutputAmount`; the original `inputAmount` must remain nonzero so the scaling has a valid baseline.
- `SwapAerodromeUniversalRouterHook` emits only the router execution and assumes the account already approved `UNIVERSAL_ROUTER`.
- `ApproveAndSwapAerodromeUniversalRouterHook` emits `approve(router, 0) -> approve(router, effectiveAmountIn) -> router.execute -> approve(router, 0)`.
- Approve the Universal Router directly, not Permit2. The researched router first attempts ordinary ERC20 `transferFrom` and falls back to Permit2; with `payerIsUser = true`, direct router allowance is sufficient for standard ERC20s. Permit2 commands, signatures, and persistent Permit2 allowances are outside scope.
- Snapshot the account's ERC20 output balance in `_preExecute`, set the post-swap balance delta and output token in `_postExecute`, and reject native token sentinels. Fee-on-transfer and rebasing tokens should remain explicitly unsupported for consistent behavior across route kinds.

### Native support boundary
- MVP is ERC20/WETH only. WETH appears directly in `packedPath`, approvals work like any other ERC20, and router call value is always zero.
- Native input would require `WRAP_ETH (0x0b)` followed by the swap, router custody, `payerIsUser = false`, and nonzero call value. Native output would require the swap recipient to be the router followed by `UNWRAP_WETH (0x0c)` to the account. Either case breaks the fixed one-command design and needs WETH/native configuration plus native balance-delta handling.
- Therefore native support must be a separately reviewed extension, not a permissive interpretation of this payload.

### Payload sufficiency conclusion
- `abi.encode(routeKind, deadline, packedPath)` is sufficient for the approved one-command, homogeneous-route MVP only because the hook fixes the dangerous Universal Router fields and fully validates every packed path byte.
- If the product requires mixed classic/Slipstream hops, native ETH, split routing, exact output, partial fills, arbitrary factory addresses, or future router commands, this payload and hook must be versioned or redesigned rather than accepting raw Universal Router calldata.

## Master Codex review: Aerodrome Universal Router build parameters
- Reviewed and approved the `superform-hook-master` parameter design as the recommended interface for discussion and future implementation planning.
- Approved constructor shape: immutable `universalRouter_` only for the ERC20/WETH MVP.
- Approved standard `ISuperHookSwap.SwapHeader` plus `abi.encode(uint8 routeKind, uint256 deadline, bytes packedPath)` payload.
- Approved internally fixed exact-input command, `recipient = account`, `payerIsUser = true`, `isUni = false`, no allow-revert flag, one command/input, and zero native value.
- Approved shared hook data for both variants; the approve-and-swap variant differs only by its temporary direct router allowance executions.
- This approval does not authorize implementation in this turn. Native ETH, mixed classic/Slipstream routing, split routes, exact output, Permit2 flows, and raw Universal Router calldata remain out of scope and require a new hook-master plan.
## superform-hook-master research: obtaining Aerodrome Universal Router packed paths

Date: 2026-07-16.

### Status and conclusion
- Research only; no production or test implementation was performed. Awaiting Master Codex review.
- No documented Aerodrome-owned HTTP quote/routing API was found that accepts token/amount inputs and returns a Universal Router `packedPath`.
- The supported official integration model is RPC-only and onchain: query Sugar for pools, construct candidate paths locally, quote them with `MixedRouteQuoterV3`, and pack the chosen route locally. This requires no Aerodrome API key, although a production integrator should use its own reliable/authenticated Base RPC provider.
- The official Python `sugar-sdk` implements this flow today and can produce the exact packed path. It is the best reference implementation, but Superform should pin a reviewed tag/commit and own the server-side adapter rather than depend on an undocumented frontend endpoint.

### Official sources and maturity
- Official Velodrome developer docs explicitly say the swap guide applies to Aerodrome and describe Sugar pool discovery, local graph routing, `quoteExactInput`, packed paths, and caller-selected slippage:
  https://github.com/velodrome-finance/docs/blob/main/content/sdk.mdx
- Official Superswaps docs say integrations require only a regular RPC endpoint. Sugar is described as an onchain API; routing and router planning are performed by open-source SDKs, not a hosted quote server:
  https://github.com/velodrome-finance/docs/blob/main/content/superswaps.mdx
- Sugar onchain API and Base deployment:
  - repository: https://github.com/velodrome-finance/sugar
  - Base configuration: https://github.com/velodrome-finance/sugar/blob/main/deployments/base.env
  - `forSwaps` returns compact pool records including pool address, type/tick spacing, token pair, factory, and fee. It does not return a best route or swap calldata.
- Official Python SDK:
  - repository/tag: https://github.com/velodrome-finance/sugar-sdk/tree/v0.4.2
  - route packing: https://github.com/velodrome-finance/sugar-sdk/blob/v0.4.2/sugar/quote.py
  - route search/quoting: https://github.com/velodrome-finance/sugar-sdk/blob/v0.4.2/sugar/chains.py
  - Universal Router planning/min-out: https://github.com/velodrome-finance/sugar-sdk/blob/v0.4.2/sugar/swap.py
  - Base addresses/factory mapping: https://github.com/velodrome-finance/sugar-sdk/blob/v0.4.2/sugar/config.py
- `sugar-sdk` main was tag `v0.4.2` at commit `e8f7c6a8c069aa23376837fb4eafc53b1377bfdd` during this review. Its README still shows installation from `v0.4.1`, which predates the all-three-factory synchronization, and the latest formal GitHub Release is older than the tag. PyPI `sugar-sdk` is also stale at `0.3.1`; current consumers must pin the GitHub `v0.4.2` tag/commit rather than install the registry version:
  https://pypi.org/project/sugar-sdk/
- A Dromos TypeScript package exists despite the docs saying it will be announced later, but published `@dromos-labs/sdk.js` is only `0.3.0-alpha.3` and predates the current all-three-factory Base selector/address changes:
  https://www.npmjs.com/package/@dromos-labs/sdk.js
  An official `fix/latest-contracts` repository branch contains a newer all-three-factory update, but it was unmerged and unpublished during this review and therefore is not a production dependency:
  https://github.com/velodrome-finance/sdk.js/compare/main...fix/latest-contracts
- Official swap docs still reference older `MixedRouteQuoterV1`, omit the three-factory selector mapping, and say more swap-interface information is forthcoming. Treat the Python `v0.4.2` source as a usable but evolving reference, not a versionless package/API/SLA.
- The current official Aerodrome frontend bundle also performs routing/quoting against Sugar, the mixed quoter, and RPC endpoints. No separate Aerodrome quote API host or authenticated quote endpoint was exposed. The hosted `offchain-lookup.services.hyperlane.xyz/health` and `/callCommitments/calls` URLs present in the Superswaps frontend are health/commitment relay services, not quote or path APIs. Any compiled frontend endpoint or bundle shape is undocumented and must not be treated as a stable integration contract.

### Exact official SDK flow
1. Instantiate `AsyncBaseChain`/`BaseChain`, preferably overriding `SUGAR_RPC_URI_8453` with Superform's Base RPC.
2. `get_pools_for_swaps()` calls Base Sugar `forSwaps` at `0x69dD9db6d8f8E7d83887A704f447b1a584b599A1` and obtains classic plus all three known CL factory pools.
3. `get_quote(from_token, to_token, amount, filter_quotes=...)` builds an undirected multigraph, enumerates short candidate paths through configured connector tokens, calls Base `MixedRouteQuoterV3` `0xCd2A7D98e82D6107eac1828ce8DeAA6acB65b555` through batched `eth_call`, discards failed/zero quotes, and selects the largest `amount_out`.
4. For the proposed one-command hook, filter quotes to a homogeneous route: every pool must be classic or every pool must be CL. Reject a route containing both kinds.
5. For a homogeneous selected quote `q`:
  - `q.amount_out` is the expected output and should populate `SwapHeader.outputQuote`.
  - `q.input.route_for_swap.encoded` is the exact Universal Router swap `packedPath`.
  - `routeKind` is `CLASSIC` if all `q.path` pools are basic, otherwise `SLIPSTREAM`.
  - Superform, not the quoter, computes `outputMin` from a configured slippage policy and sets a fresh deadline.
- Equivalent explicit packing is `pack_path(q.path, for_swap=True, slipstream_factory_addr=Base latest factory, old_slipstream_factory_addr=Base original factory).encoded`.
- Do not take `q.input.route.encoded` as the swap path. That property is the mixed-quoter path; classic fillers differ from Universal Router classic path bytes.

### Quote path versus swap packed path
- Mixed-quoter path, used only for `quoteExactInput`, always has token / 3-byte signed filler / token hops:
  - classic stable filler: `0x200000` (`2097152`);
  - classic volatile filler: `0x400000` (`4194304`);
  - CL filler: tick spacing OR the CL factory selector.
- Universal Router classic `packedPath` instead has token / one-byte bool / token hops, where `0x01` is stable and `0x00` is volatile. `sugar-sdk` performs this conversion only with `for_swap=True`.
- Universal Router Slipstream `packedPath` has token / 3-byte poolParam / token hops. For CL-only paths, quote and swap path bytes use the same per-hop token and poolParam encoding.
- `MixedRouteQuoterV3` returns expected `amountOut`; it does not return a safe minimum output. Superform should compute `outputMin` with integer basis-point arithmetic, not blindly reuse the SDK's floating-point `apply_slippage` helper, then ensure `0 < outputMin <= outputQuote`.

### Three-factory selector handling
- Current Base Sugar publishes pools from all three CL factories. The official SDK maps them as follows:
  - factory `0xaDe65c38CD4849aDBA595a4323a8C7DdfE89716a`: unflagged positive tick spacing, selector `0x000000`;
  - original factory `0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A`: `tickSpacing | 0x100000`;
  - latest Gauges V3 factory `0xf8f2eB4940CFE7d13603DDDD87f123820Fc061Ef`: `tickSpacing | 0x080000`.
- The SDK explicitly configures the original and latest factories; any other CL factory falls through to an unflagged tick spacing. A Superform adapter must be stricter: whitelist exactly these three factory addresses and fail closed on any unknown factory rather than silently treating it as the primary factory.
- Revalidate this mapping against the selected Universal Router's immutable factories at deployment/startup. The current official frontend and `sugar-sdk` target Universal Router `0xcAF22ce31298CF2BF1D152862F80216478ad7c67`, while the separately researched latest three-factory universal-router deployment file records `0xC5b6786D7B64767D775877b0B6A319AD946B11B5`. Thus their transaction plans/router address are not a drop-in source for the proposed hook even though the packed path convention matches. The production router discrepancy still requires Aerodrome confirmation.

### Mixed-route constraint
- `sugar-sdk` can choose a route containing alternating classic and CL segments. Its transaction planner splits such a route into multiple Universal Router commands, uses router/pool custody between segments, and applies the final min-out only to the last segment.
- The proposed hook accepts exactly one command and one homogeneous `packedPath`; it cannot consume that mixed plan.
- `QuoteInput.route_for_swap` should only be used directly after verifying homogeneity. On a mixed full path, the helper's V2/CL type conversion is not a valid one-command path; the SDK itself avoids this by grouping nodes and packing each homogeneous segment separately.
- MVP route selection must therefore filter mixed candidates out and select the best remaining all-classic or all-CL quote. Supporting the globally best mixed quote would require a separately reviewed multi-command payload/hook.

### Recommendation for Superform
- Do not consume or reverse-engineer an Aerodrome frontend HTTP endpoint. None is documented as public/stable, and the official architecture intentionally avoids centralized quote APIs.
- Run a small stateless Superform server-side route adapter in the OMS/bundler environment:
  1. fetch/paginate Sugar `forSwaps` over Superform's RPC and cache pool topology briefly;
  2. build candidate paths with an explicit token/factory allowlist and a small hop cap;
  3. quote candidates at the latest block with `MixedRouteQuoterV3` using batched `eth_call`;
  4. reject mixed routes for MVP and choose best `amountOut` among homogeneous routes;
  5. map only the three approved CL factories, produce `routeKind` plus swap `packedPath`, compute integer `outputMin`, and set a short deadline;
  6. simulate the exact hook/router execution before returning signed hook data where practical.
- Pin `sugar-sdk` `v0.4.2` as a reference/test oracle or port its small routing/packing subset into Superform's native service language. Do not make a Python Git dependency or public default RPC a consensus-critical runtime dependency without ownership, monitoring, timeouts, and fork tests.
- Keep the hook payload `abi.encode(routeKind, deadline, packedPath)` for MVP. A typed-hop payload does not remove the need for route discovery/quoting and adds onchain encoding/calldata cost; the hook's complete packed-path parser already provides the trust boundary. Internally, the Superform route service should retain typed pool/factory hops until the final packing step so mapping errors are testable and fail closed.
- Reconsider typed hops only if multiple external clients must construct hook data without the Superform adapter, or if router/factory mappings need to become an explicit versioned onchain contract rather than a server-side deployment invariant.

## Master Codex review: Aerodrome packed-path production
- Reviewed and approved the `superform-hook-master` research as the answer for the proposed one-command Aerodrome Universal Router hooks.
- No documented Aerodrome-owned HTTP quote API currently returns the required Universal Router `packedPath`. The official path is the RPC-backed Sugar pool API plus local route selection and `MixedRouteQuoterV3` quoting.
- For an all-classic or all-Slipstream quote from pinned `sugar-sdk` `v0.4.2`, `quote.input.route_for_swap.encoded` is the required swap path. `quote.input.route.encoded` is only the mixed-quoter path and is incorrect for classic Universal Router execution.
- The OMS/bundler should own a server-side quote adapter and return `routeKind`, `packedPath`, `outputQuote`, integer-derived `outputMin`, and a short deadline. End users and integrators should not manually pack route bytes.
- The adapter must filter out mixed classic/Slipstream quotes for the MVP, whitelist the three supported CL factories, fail closed for unknown factories, and retain typed hop metadata until final packing and validation.
- QuickNode's third-party Aerodrome Swap API can return quotes and ready-built transactions, but its documented response does not expose `packedPath`; decoding vendor-generated router calldata is not an approved source for this hook input.
- The `0xC5b...` versus `0xcAF22...` Universal Router discrepancy remains unresolved. Packed-path generation can be developed against the documented selector convention, but production deployment must confirm the selected router and its immutable factory mapping.
- This turn remains research/design only. No production hook or quote-adapter code was created.

## superform-hook-master implementation TODO: Aerodrome Universal Router hooks

Date: 2026-07-16.

### Status, review gate, and task split
- Plan only. No production, test, deployment, configuration, or bytecode files were changed in this planning turn.
- This plan implements the Master-approved scope only: ERC20/WETH, exact input, one homogeneous all-classic or all-Slipstream route, direct Universal Router allowance, and the standard `ISuperHookSwap` header plus `abi.encode(uint8 routeKind, uint256 deadline, bytes packedPath)` payload.
- After Master Codex approves this TODO, tasks 1-5 can proceed without selecting a production router because the constructor remains address-parameterized and unit tests use a mock.
- Tasks 6-8 are blocked until Aerodrome/product confirms the intended Base Universal Router and its immutable factory mapping. Do not put any candidate address into production config or locked bytecode before that gate is resolved.
- Out of scope remains unchanged: native ETH, Permit2 flows, mixed classic/Slipstream plans, split routing, exact output, allow-revert/partial-fill commands, arbitrary commands/calldata, V4, bridge, and cross-chain commands.

### Can proceed after Master approves this plan

1. **Add the minimal vendor ABI and one Aerodrome-specific abstract base.**
   - Add `src/vendor/aerodrome/IAerodromeUniversalRouter.sol` with only the deadline-bearing production entry point:
     `execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable`.
   - Add `src/hooks/swappers/aerodrome/BaseAerodromeUniversalRouterHook.sol` extending `BaseHook` and implementing `ISuperHookSwap`, `ISuperHookContextAware`, `ISuperHookInflowOutflow`, and `ISuperHookOutflow` once for both concrete hooks.
   - Store `IAerodromeUniversalRouter public immutable UNIVERSAL_ROUTER`; reject a zero constructor address with `BaseHook.ADDRESS_NOT_VALID`; initialize `HookType.NONACCOUNTING` and `HookSubTypes.SWAP` in the abstract base.
   - Keep the two command constants in this base, not a separate library: `V3_SWAP_EXACT_IN = 0x00` for Slipstream and `V2_SWAP_EXACT_IN = 0x08` for classic. Add one internal pure virtual `_includeApproval()` so the shared builder emits either one router execution or the four approval/swap executions.
   - Share all standard swap helpers here: `encodeSwapData`, header decoders, payload decoder, `decodeUsePrevHookAmount`, `decodeAmounts`, `amountRoles`, `replaceCalldataAmounts`, `inspect`, sizing-interface support, and ERC20 output balance-delta pre/post accounting. The only replaceable amount is offset 92 (`SwapCalldataLayout.AMOUNT_POSITION`), and `inspect` returns the packed output token.
   - Do not refactor unrelated swap hooks or introduce a protocol-general swap base. This abstraction is local because these two contracts have identical parsing, security checks, router encoding, and lifecycle behavior.

2. **Implement strict canonical payload and packed-path validation in the shared base.**
   - Before any `BytesLib` read, require at least `SwapCalldataLayout.MIN_DATA_LENGTH`, require the header bool byte to be exactly `0` or `1`, read `payloadLength`, and require `payloadLength == data.length - 221`. This rejects truncation and outer trailing bytes without an addition overflow.
   - Prevalidate the ABI head for `(uint8,uint256,bytes)`, including the canonical dynamic offset, bounded path length, expected padded payload length, and zero padding; then decode and require `keccak256(payload) == keccak256(abi.encode(routeKind, deadline, packedPath))`. Malformed offsets, dirty narrow values, or ignored payload bytes must fail closed.
   - Use these explicit errors in the abstract base: `INVALID_HOOK_DATA`, `INVALID_PAYLOAD`, `INVALID_ROUTE_KIND`, `NATIVE_TOKEN_NOT_SUPPORTED`, `SAME_INPUT_OUTPUT_TOKEN`, `INVALID_OUTPUT_AMOUNTS`, `INVALID_PREV_HOOK`, `PREV_HOOK_TOKEN_MISMATCH`, `EXPIRED_DEADLINE(uint256,uint256)`, `INVALID_PATH_LENGTH`, `INVALID_PATH`, `INVALID_STABLE_FLAG`, and `INVALID_POOL_PARAM`. Reuse `ADDRESS_NOT_VALID`, `AMOUNT_NOT_VALID`, and `INVALID_AMOUNTS_LENGTH` for their existing generic cases.
   - Require a nonzero account; nonzero distinct header tokens; neither `address(0)` nor the conventional `0xEeee...` native sentinel anywhere in the path; `inputAmount > 0`; `outputMin > 0`; and `outputQuote >= outputMin`. Permit `deadline == block.timestamp` and reject `deadline < block.timestamp`; deadline-horizon policy remains in the quote adapter.
   - Classic parsing: require `packedPath.length == 20 + 21 * hops`, `1 <= hops <= 9`, stable byte exactly `0` or `1`, all token addresses nonzero/non-native, no equal adjacent tokens, and first/last tokens equal the header endpoints.
   - Slipstream parsing: require `packedPath.length == 20 + 23 * hops`, `1 <= hops <= 9`, and parse each three-byte parameter as big-endian `uint24`. Require nonzero `param & 0x07ffff`, no `param & 0xe00000` reserved bits, and selector `param & 0x180000` equal only `0`, `0x080000`, or `0x100000`; reject combined `0x180000`. Apply the same token and endpoint checks.
   - With `usePrevHookAmount`, require a nonzero contract `prevHook`, require `getOutToken(account) == inputToken`, require a nonzero previous amount, set it as `effectiveAmountIn`, and compute `effectiveOutputMin = HookDataUpdater.getUpdatedOutputAmount(previousAmount, originalInputAmount, originalOutputMin)`. With chaining disabled, use the header values unchanged.
   - Construct, rather than accept, router calldata: one command, one input encoded as `(account, effectiveAmountIn, effectiveOutputMin, packedPath, true, false)`, deadline-bearing `execute`, target fixed to `UNIVERSAL_ROUTER`, and value fixed to zero. This fixes recipient, payer, Aerodrome mode, command class, allow-revert bit, and custody behavior on chain.
   - `_preExecute` snapshots `IERC20(outputToken).balanceOf(account)`; `_postExecute` rejects a decreased balance, stores the delta, and stores `outputToken`. Document fee-on-transfer and rebasing tokens as unsupported; no permissive fallback is added.

3. **Add the two thin concrete hooks.**
   - Add `src/hooks/swappers/aerodrome/SwapAerodromeUniversalRouterHook.sol`. It forwards `constructor(address universalRouter_)` to the base, supplies name/description, and returns `_includeApproval() == false`; total `BaseHook.build` length is three (`pre`, router call, `post`) and the account must already have direct router allowance.
   - Add `src/hooks/swappers/aerodrome/ApproveAndSwapAerodromeUniversalRouterHook.sol`. It uses the same constructor and data, supplies name/description, and returns `_includeApproval() == true`; hook executions are exactly `approve(router,0)`, `approve(router,effectiveAmountIn)`, `router.execute`, `approve(router,0)`, for a total build length of six with pre/post.
   - Use ordinary `IERC20.approve` execution calldata, matching existing approve-and-swap hooks. Do not add Permit2 configuration or approvals.

4. **Add deterministic mock-backed unit coverage for the complete trust boundary.**
   - Add `test/mocks/MockAerodromeUniversalRouter.sol`. It implements the minimal interface, records/validates the command and decoded input, can pull the configured ERC20 from `msg.sender`, and can mint a configured output to the forced recipient so approval cleanup and balance-delta behavior can be executed, not only calldata-inspected.
   - Add `test/unit/hooks/swappers/aerodrome/AerodromeUniversalRouterHook.t.sol` covering both variants. Keep a small previous-result mock local to this test because existing `test/mocks/MockHook.sol` always returns a zero output token.
   - Positive cases: constructor/metadata/type/subtype/ERC165 sizing support; standard encode/decode/inspect/amount replacement; exact `execute(bytes,bytes[],uint256)` selector `0x3593564c`; target/value/deadline; command `0x08` or `0x00`; one input; forced recipient; effective amount/minimum; exact path; `payerIsUser=true`; `isUni=false`; three- versus six-execution order; direct spender and final zero allowance; pre/post output delta/token.
   - Route cases: classic stable, classic volatile, classic multihop; Slipstream raw primary selector, `0x100000` original selector, `0x080000` latest selector, and CL multihop.
   - Chaining cases: scale up, scale down, same amount, absent/EOA previous hook, zero previous result, previous-token mismatch, and approval using the effective amount.
   - Negative boundary cases: short header; invalid header bool; outer payload overrun/underrun/trailing data; malformed/noncanonical ABI offset, length, padding, or narrow value; unsupported route kind; expired deadline; zero account/token/amount/minimum; quote below minimum; same header tokens; native sentinel; bad path formulas; zero/tenth hop; wrong endpoints; zero/equal intermediate token; stable byte greater than one; zero tick spacing; combined selector; reserved bits; and decreased post balance.
   - Fuzz standard header round trips, amount replacement preservation, and structurally valid 1-9 hop paths; mutate separator, selector, endpoint, and length bytes to prove the parser fails closed.

5. **Wire repository metadata and complete address-independent verification.**
   - Update `tooling/hook-classification.yaml` with both hooks as `{intent: swap, stage: instant}` and `legSizing: [sized]`.
   - Update `tooling/hook-enrichment.yaml` with `[aerodrome]` compatible protocol entries and the approve pair `SwapAerodromeUniversalRouterHook: ApproveAndSwapAerodromeUniversalRouterHook`.
   - Because the concrete sources inherit the implementation, update `tooling/generate-hook-sizing-manifest.ts` with explicit `replaceCalldata` overrides for both names. Its current scanner only inspects each concrete source and otherwise cannot see inherited `decodeAmounts`/`replaceCalldataAmounts`.
   - Likewise update `tooling/generate_hook_manifest.py` so a concrete hook inheriting `BaseAerodromeUniversalRouterHook` is classified as `NONACCOUNTING` / `SWAP`; its parser currently recognizes only direct `BaseHook(...)` calls and a few named abstract bases.
   - Regenerate and commit `hook-sizing-manifest.json` and `manifests/hooks.json` with `npm run generate:hook-sizing`, `npm run validate:hook-sizing`, and `make manifest`. Empty deployment-address maps are expected until task 8 and the hook manifest must be regenerated again after deployment outputs exist.
   - Run `forge fmt --check`, `forge build`, `forge test --match-contract AerodromeUniversalRouterHookTest -vvv`, the manifest lint/validation commands, and then `make ftest-ci`. No Go hook binding is expected because `generate-contract-bindings.sh` deliberately excludes `*Hook` contracts.

### Blocked on confirmed router address and immutables

6. **Resolve and verify the Base router, then freeze fork fixtures.**
   - Obtain an explicit Aerodrome/product decision among the researched all-three-factory deployment `0xC5b6786D7B64767D775877b0B6A319AD946B11B5`, the current frontend/`sugar-sdk` target `0xcAF22ce31298CF2BF1D152862F80216478ad7c67`, and the security-page legacy router `0x6Cb442acF35158D5eDa88fe602221b67B400Be3E`. Repository recency alone is not approval.
   - On a pinned Base block after the chosen deployment, assert code exists and verify the router getters against the intended MVP mapping: `WETH9 = 0x4200...0006`, `VELODROME_V2_FACTORY = 0x420DD...`, `VELODROME_CL_FACTORY = 0xaDe65...`, `VELODROME_CL_FACTORY_2 = 0x5e7BB...`, and `VELODROME_CL_FACTORY_3 = 0xf8f2e...`. Also confirm the exact runtime supports ordinary ERC20 `transferFrom` before Permit2 fallback.
   - Use pinned `sugar-sdk` `v0.4.2`/Sugar data only as a route-fixture producer. Select liquid routes at that same block and commit `route_for_swap.encoded`, never the mixed-quoter classic path. Fixtures must include classic volatile, classic stable, raw primary CL, original `0x100000` CL, and latest `0x080000` Gauges V3 CL.
   - The router choice is a hard release blocker because it changes constructor init code, deterministic CREATE2 hook addresses, fork behavior, verification args, and both locked bytecode deployment predictions.

7. **Add pinned Base fork execution tests against the confirmed router.**
   - Add `test/integration/aerodrome/AerodromeUniversalRouterHookFork.t.sol`; keep router, factory, token, path, tick-spacing, and fork-block constants scoped to this test unless another production consumer appears.
   - Execute all five route classes through the approve-and-swap hook, plus representative classic and CL routes through the swap-only hook after explicit direct router approval. Include one previous-hook resized execution and decode/assert the effective amount and minimum before executing it.
   - For every real swap assert exact input consumption, output increase at least the committed minimum, `getOutAmount` equals the observed ERC20 balance delta, `getOutToken` is correct, final direct router allowance is zero for the approve variant, and neither the account nor router gains unintended input-token dust relative to its pre-swap balance. The swap-only test may retain only the explicitly intended leftover allowance.
   - Ensure the smart-account-relevant payer behavior is exercised: the account executing the router call is `msg.sender`, `payerIsUser=true`, and it has no Permit2 approval. This proves direct approval works on the selected deployment.
   - Run with `BASE_RPC_URL=... forge test --match-contract AerodromeUniversalRouterHookForkTest -vvv`. Do not reuse the repository's older global `BASE_BLOCK` unless it is after the selected router and all fixtures exist there.

8. **Wire Base-only deployment, lock bytecode, deploy, export, and verify.**
   - After router confirmation, update `script/utils/Constants.sol` with `AERODROME_UNIVERSAL_ROUTER_BASE` and both hook keys; update `script/utils/ConfigBase.sol` with `aerodromeUniversalRouters`; and set only `configuration.aerodromeUniversalRouters[BASE_CHAIN_ID]` in `script/utils/ConfigCore.sol`. Other chains remain unset.
   - Update `script/DeployV2Core.s.sol` atomically: add both `HookAddresses` fields and an availability flag; include both hooks in availability/skips/missing-bytecode accounting; add conditional predicted-address checks with `abi.encode(router)` in `_checkHookContracts`; grow `_deployHooks` from 78 to 80 without shifting existing slots; deploy at stable slots 78/79 with router code checks; assign both addresses; and add final conditional nonzero validation.
   - While updating availability, increase `potentialSkips` from 37 to at least 40 because the Base-only pair raises the maximum skip count to 38. Reconcile `baseHooks` to 80 entries, including the six already-deployed WithId hooks currently omitted plus the two new hooks, so expected totals and missing-bytecode reporting match the actual 80 deployment slots.
   - Add both names to `HOOK_CONTRACTS` in `script/run/tooling/regenerate_bytecode.sh`. Build and generate `script/generated-bytecode/SwapAerodromeUniversalRouterHook.json` and `script/generated-bytecode/ApproveAndSwapAerodromeUniversalRouterHook.json`; after contract/fork review, promote identical artifacts to `script/locked-bytecode-dev/` for staging/vnet and, only after the production release gate, `script/locked-bytecode/` for prod. These are core hooks, not `locked-bytecode-other` hooks.
   - Update `script/run/verify/verify_v2_staging_prod.sh`: define the confirmed Base router, populate it only for chain 8453, encode `constructor(address)` for both hook names, and map both names to their exact source paths. Deployment and verification must use the same address.
   - Run core preflight/check mode before deployment, deploy to Base staging, and let `_exportContract` write the new keys to `script/output/staging/8453/Base-latest.json`; generate aggregate staging output with `script/run/tooling/generate_latest_json.sh staging`. Repeat for prod only after staging/fork/security sign-off, then regenerate `manifests/hooks.json` so its Base staging/prod address maps are current.
   - Verify both deployments with `script/run/verify/verify_v2_staging_prod.sh staging` and later `prod`, confirm explorer constructor args, and rerun `forge build`, targeted/unit/fork tests, `make ftest-ci`, manifest lint, and sizing-manifest validation against the exact locked artifacts/config.
   - Do not modify the specialized historical `script/run/others/update_hook_addresses.py` or `deploy_hooks_cast.sh`; the normal `DeployV2Core` check/deploy/export flow owns these hooks.

### Review request
- Master Codex: please review and approve or amend this eight-task implementation TODO. Per repository instructions, no hook implementation should begin until that review is recorded.

## Master Codex review: Aerodrome hook implementation TODO
- Reviewed and approved the eight-task `superform-hook-master` plan as the implementation checklist for the two Aerodrome Universal Router hooks.
- Tasks 1-5 are approved as address-independent work, but the user explicitly requested the TODO first, so no implementation begins until the user confirms this checklist.
- Amendment: add a dedicated `OUTPUT_BALANCE_DECREASED` custom error and deterministic unit case instead of relying on arithmetic panic or a generic amount error when the output balance falls between pre/post execution.
- Amendment: the Sugar/OMS packed-path quote adapter remains a separately tracked change in the relevant off-chain repository. This v2-core checklist covers hook contracts, validation, tests, manifests, and deployment wiring only.
- Tasks 6-8 remain release-blocked on an explicit production router decision and verification of its immutable classic/three-factory mapping, six-field command ABI, and direct ERC20 allowance behavior.
- Deployment changes must append slots 78/79 without shifting existing slots, increase skip-array headroom, and correct the existing base-hook accounting omission while that deployment table is being extended.
- No production or test source files were edited and no tests were run during this TODO-only turn.

## Aerodrome implementation progress (2026-07-16)
- Began approved address-independent tasks 1-5 after the user asked to implement.
- Added the minimal deadline-bearing `IAerodromeUniversalRouter.execute(bytes,bytes[],uint256)` vendor interface.
- Added `BaseAerodromeUniversalRouterHook` and the thin `SwapAerodromeUniversalRouterHook` / `ApproveAndSwapAerodromeUniversalRouterHook` concrete contracts. The shared base constructs a single exact-input command, supports classic (`0x08`) and Slipstream (`0x00`) homogeneous paths, enforces canonical payload/path validation, scales previous-hook amounts, exposes the standard sizing/swap interfaces, and records output balance deltas.
- The approved `OUTPUT_BALANCE_DECREASED` guard is implemented in post-execution accounting.
- Pinned-solc review confirmed that Solidity ABI decoding is permissive about trailing bytes, alternate offsets, and nonzero padding. The implementation therefore checks the raw route word, exact `0x60` dynamic offset, bounded path length, exact padded payload length, every padding byte, and canonical re-encoding before accepting a payload.
- Pinned-solc review also found that typed `try/catch` does not catch successful calls with malformed returndata during ABI decoding. Previous-hook result reads were changed to strict low-level `staticcall` checks: success, exactly 32 returndata bytes, and a clean 160-bit token word are required before scaling.
- Installed the documented submodule dependencies under `lib/modulekit`, `lib/safe7579`, and `lib/nexus`. pnpm 10 required the command-line `dangerously-allow-all-builds` config for the repository's git dependency scripts; no tracked package or lock file was changed.
- A full `forge build` compiled the new source without contract errors, but the repository-wide run stopped on three pre-existing test helpers whose `view` mutability is incompatible with the installed Foundry `vm.getRecordedLogs()` signature (`MinimalBaseNexusIntegrationTest.t.sol` twice and `StargateAdapterE2EFork.t.sol` once). Source-scoped compilation and Aerodrome-targeted tests will be used to verify this change without editing unrelated tests.
- Tooling review confirmed two required inheritance workarounds: hook-manifest classification must explicitly recognize `BaseAerodromeUniversalRouterHook`, and sizing overrides must name both concrete hooks. Sizing generation also requires address-independent hook-key constants in `script/utils/Constants.sol`; router/config/deployment wiring remains blocked.

## superform-hook-master implementation review: Solidity 0.8.30 and inherited-base pitfalls

Date: 2026-07-16. Review only; `superform-hook-master` did not edit production or test sources.

### Implementation-critical correction
- Do not rely on typed `try ISuperHookResult(prevHook).getOutToken/getOutAmount` to normalize every malformed previous hook to `INVALID_PREV_HOOK`. A pinned Solc 0.8.30 Forge probe showed that `try/catch` catches a call revert, but **does not catch ABI-decoding failure after a successful call** that returns empty/short data or a dirty high-order address word; the caller reverts outside the catch clause.
- Use one low-level `staticcall` per result selector instead. Require success and exactly 32 return bytes; for `getOutToken`, load the word and require it is at most `type(uint160).max` before casting; for `getOutAmount`, load the full word. Map call failure, malformed return length, and dirty address data to `INVALID_PREV_HOOK`, then apply `PREV_HOOK_TOKEN_MISMATCH` and the nonzero amount check. Read each result only once.

### Canonical `(uint8,uint256,bytes)` checklist
- Solc 0.8.30 `abi.decode` was empirically confirmed to accept outer trailing bytes, nonzero dynamic-byte padding, a relocated aligned tail, and even an unaligned dynamic offset. It rejects dirty high bits in a `uint8`, but decoding alone is not a canonicality check.
- Validate raw bytes before decoding: payload length at least 128; route word clean (`<= type(uint8).max`); dynamic offset exactly `0x60`; path length bounded; exact padded tail length; and every padding byte zero. The current 227-byte path cap makes `pathLength + 31` and total-length arithmetic safe. A re-encode/hash comparison is useful defense in depth after these checks.
- For the outer swap envelope, first require `data.length >= 221`, validate the bool byte as exactly `0` or `1`, then require `payloadLength == data.length - 221`. This subtraction form avoids attacker-controlled addition overflow and rejects both truncation and trailing bytes.
- Keep clean but unsupported route values separate from dirty narrow ABI values: a clean route word `2..255` should reach `INVALID_ROUTE_KIND`; a word with bits above the low byte should be `INVALID_PAYLOAD`.

### Byte and sizing checklist
- `BaseHook._decodeBool` treats every nonzero byte as true and panics on a short array. Validate the raw bool first; do not use it as the validator.
- `BaseHook._replaceCalldataAmount` writes 32 indexed bytes without checking length. Public amount replacement and decoding helpers must bounds-check `AMOUNT_POSITION + 32` before calling it or `BytesLib` so malformed input uses hook errors rather than panic/string reverts.
- `BytesLib` accepts `bytes memory`, has no `toUint24`, and its address parser reads a full word after only a 20-byte logical bounds check. Prevalidate bounds and parse Slipstream parameters big-endian with widened operands: `(uint24(uint8(b[o])) << 16) | (uint24(uint8(b[o+1])) << 8) | uint24(uint8(b[o+2]))`. Shifting a `uint8` before widening can truncate the result.
- Check `path.length >= 20` before subtracting. Classic hop offsets are `20 + i*21` for the flag and `21 + i*21` for the next token; Slipstream offsets are `20 + i*23` for the parameter and `23 + i*23` for the next token. Validate 1-9 hops, every token, adjacent inequality, and both endpoints.
- `HookDataUpdater` is a `1e5` precision percentage-delta helper, not exact `outputMin * newAmount / originalAmount`: very small relative changes quantize to no minimum change. Reject original and previous input amounts of zero before use, and make tests assert this repository helper's semantics. Validate `outputQuote >= originalOutputMin` before scaling; do not compare the original quote against a scaled-up effective minimum because the quote is metadata and is not sent to the router.

### Inheritance and tooling checklist
- Solidity inheritance itself is sound: initialize `BaseHook` once in `BaseAerodromeUniversalRouterHook`; concrete hooks need only constructor forwarding, metadata, and `_includeApproval`. `BaseHook.supportsInterface` advertises the two sizing interfaces when `_supportsSizingInterface()` is true, but does not automatically advertise `ISuperHookSwap` or `ISuperHookContextAware`; tests must not assume those ERC165 IDs.
- `tooling/generate_hook_manifest.py` skips `Base*` sources and parses only each concrete file. Both thin inheritors therefore need explicit inherited-base classification as `NONACCOUNTING` **and** subtype `SWAP`; recognizing only the hook type is insufficient.
- `tooling/generate-hook-sizing-manifest.ts` likewise scans only the exact concrete filename for sizing methods/constants. Add explicit `replaceCalldata` overrides for both Aerodrome concrete hooks; inherited methods will not auto-detect. The default pipe mode remains `transform`, which is correct.
- The sizing generator emits entries only for hook-key strings extracted from `script/utils/Constants.sol` / `ConstantsOtherHooks.sol`; overrides alone do not create entries. Add the two address-independent Aerodrome hook-key constants during task 5 if sizing generation is expected now, while leaving router addresses/config/bytecode blocked, or explicitly defer sizing-manifest regeneration to task 8.

### Verification status
- Both new concrete hook dependency closures compiled successfully with the repository-pinned Solc 0.8.30 using a targeted `forge build` invocation.
- A whole-repository `forge build` is currently blocked by pre-existing missing `lib/nexus/node_modules` dependencies (`solady`, `solarray`, `sentinellist`, composability, and ERC-7739 packages), not by the Aerodrome sources. Install the documented Nexus dependencies before relying on full-build/test results.

## Aerodrome unit-test implementation and verification
- Added `test/mocks/MockAerodromeUniversalRouter.sol`. It decodes the exact six-field Aerodrome input, requires user-payer/non-Uni mode, pulls the configured input ERC20 from the executing account, and can mint or burn output for lifecycle tests.
- Added `test/unit/hooks/swappers/aerodrome/AerodromeUniversalRouterHook.t.sol` with 24 tests. Coverage includes both three- and six-execution plans; exact selector/command/input/deadline construction; temporary direct approval and cleanup; actual token movement; output amount/token accounting; classic and all three Slipstream factory selector forms; multihop routes; deadline equality; previous-hook up/down/same/quantized scaling; absent, EOA, empty-returndata, dirty-address, mismatched-token, and zero-amount previous hooks; malformed outer envelopes and canonical payloads; invalid headers; route/deadline failures; classic/Slipstream path boundaries; decreased output balances; public sizing helper bounds; and three fuzz properties for standard headers and valid 1-9 hop paths.
- Targeted source build passes with Solc 0.8.30.
- Focused test command passes all 24 tests: `FOUNDRY_TEST=test/unit/hooks/swappers/aerodrome FOUNDRY_SCRIPT=.Codex/unused forge test --match-contract AerodromeUniversalRouterHookTest -vv`. The environment overrides are needed because this Foundry version compiles unrelated integration tests even with `--match-path`, and three pre-existing integration helpers currently fail mutability checking.
- Address-independent implementation plan tasks 1-4 are complete. Task 5 (tooling/manifests) is in progress; tasks 6-8 remain blocked on the production router decision.

## Aerodrome address-independent implementation completion
- Completed implementation-plan tasks 1-5. Tasks 6-8 remain deliberately pending until the production Base Universal Router and its immutable factory mapping/direct-allowance behavior are confirmed.
- Added address-independent hook-key constants for `SwapAerodromeUniversalRouterHook` and `ApproveAndSwapAerodromeUniversalRouterHook`; no router address, chain config, deployment slot, bytecode lock, output address, or verifier argument was added.
- Added both hooks to `tooling/hook-classification.yaml` as sized instant swaps, added `[aerodrome]` enrichment and the approve pair, added inherited sizing overrides, and taught `generate_hook_manifest.py` to classify the shared Aerodrome base as `NONACCOUNTING` / `SWAP` from each concrete source.
- Regenerated `hook-sizing-manifest.json`: both Aerodrome keys are `replaceCalldata` / `transform`. `npm run validate:hook-sizing` passes with zero errors and the same three pre-existing repository warnings (27 inherited/inlined offsets grouped as one warning, `APPROVE_ERC20_HOOK_KEY` pipe-mode warning, and `FETCH_NATIVE_FEE_HOOK_KEY` pipe-mode warning).
- Regenerated `manifests/hooks.json`. Both entries have empty staging/prod address maps, sized `IN/TOKEN` metadata, Aerodrome compatibility, and the correct approval relationship. `make manifest` passes using an ephemeral PyYAML environment; all 125 hooks validate.
- Expanded the focused suite to 25 passing tests by adding amount-replacement preservation fuzzing, the literal router selector assertion (`0x3593564c`), payload under-declaration, zero output token, and native-sentinel path cases.
- Final focused command: `FOUNDRY_TEST=test/unit/hooks/swappers/aerodrome FOUNDRY_SCRIPT=.Codex/unused forge test --match-contract AerodromeUniversalRouterHookTest -vv` -> 25 passed, 0 failed.
- Targeted Solc build passes for both concrete hooks and their test closure. Deployed runtime sizes are 12,462 bytes for the swap-only hook and 12,506 bytes for the approve-and-swap hook, both well below EIP-170's 24,576-byte limit.
- Targeted `forge fmt --check` for all changed Solidity files passes, and `git diff --check` passes.
- Repository-wide `make ftest-ci` was attempted and fails before running tests on three unrelated, pre-existing Solc mutability errors: `test/integration/MinimalBaseNexusIntegrationTest.t.sol:342`, the same file at line 378, and `test/integration/stargate/StargateAdapterE2EFork.t.sol:1542`; each calls the non-view `vm.getRecordedLogs()` from a function declared `view`. The Aerodrome-scoped test directory override avoids compiling those unrelated integration roots.
- Repository-wide `forge fmt --check` also fails on extensive pre-existing formatting drift throughout unrelated `src/`, `test/`, and `script/` files. All files changed for Aerodrome pass targeted formatting checks; unrelated formatting was not modified.
- Re-ran the focused Aerodrome suite on request: Solc 0.8.30 compilation succeeded and all 25 tests passed again with zero failures.
- Clarified the remaining release gate: unit tests use a mock router, but real Base fork tests and deterministic deployment artifacts require one confirmed production router address. The selected runtime must expose the expected classic and three Slipstream factory immutables and support direct ERC20 router allowance with the six-field exact-input command used by these hooks.

## Aerodrome Base Universal Router resolution (2026-07-16)

### Decision
- Use `0xcAF22ce31298CF2BF1D152862F80216478ad7c67` as the production Base Universal Router for the new Aerodrome hooks.
- `0xC5b6786D7B64767D775877b0B6A319AD946B11B5` is a valid all-three-factory deployment and remains the address recorded by `velodrome-finance/universal-router`, but the later official SDK release and the live Aerodrome application do not select it.
- Reject `0x6Cb442acF35158D5eDa88fe602221b67B400Be3E` for these hooks. It is the 2024 legacy router: its V3 exact-input command has five fields and its V2 command consumes `Route[]`, not the new six-field packed path.

### Official product/config evidence
- The live `https://aerodrome.finance/swap` application retrieved on 2026-07-16 reports version `v5.0.0+da710a` and loads `assets/index-Cj-jKC2u.js`. That bundle sets `VITE_UNIVERSAL_ROUTER_ADDRESS_8453` to `0xcAF22...` (and chain 10 to the same address). `0xC5b...` is absent. The bundle contains `0x6Cb...` only as static security-table content, demonstrating that the security table is stale relative to the application config.
- Official `velodrome-finance/sugar-sdk` commit [`0de24ae`](https://github.com/velodrome-finance/sugar-sdk/commit/0de24ae601487b13e358834f45f80a37be945982), authored/committed 2026-05-28 as `feat: sync latest contracts / chains`, changes Base `swapper_contract_addr` from `0x01D400...` to `0xcAF22...`. Latest tag [`v0.4.2`](https://github.com/velodrome-finance/sugar-sdk/blob/v0.4.2/sugar/config.py#L176-L199) contains that setting; `v0.4.1` does not. The same planner directly approves the configured swapper and emits the six-field command with `payerIsUser=true` and `isUni=false`.
- Official `velodrome-finance/universal-router` commit [`540899c`](https://github.com/velodrome-finance/universal-router/commit/540899c395004a50179bcce2774882995b3f381c), dated 2026-04-10 and titled `feat: 3 factories support (#106)`, records `0xC5b...` in [`deployment-addresses/base.json`](https://github.com/velodrome-finance/universal-router/blob/540899c395004a50179bcce2774882995b3f381c/deployment-addresses/base.json). This is real official deployment evidence, but it predates the SDK migration and differs from the live product target.
- Aerodrome's current [`security.mdx`](https://github.com/aerodrome-finance/docs/blob/7c0df032b58ee08b621ace19753d8abc260dd321/content/security.mdx#L340-L347) still lists `0x6Cb...`. Historical SDK config selected that address before replacing it in 2025, so it must be treated as legacy documentation rather than the current integration setting.

### Verified `cAF22...` contract behavior and immutables
- Base Blockscout reports an exact, fully verified `UniversalRouter`, Solc `0.8.29`, Cancun, 10,000 optimizer runs, verified 2026-04-30: `https://base.blockscout.com/api/v2/smart-contracts/0xcAF22ce31298CF2BF1D152862F80216478ad7c67`.
- Its exact verified dispatcher decodes command `0x00` and command `0x08` as `(address recipient,uint256 amountIn,uint256 amountOutMin,bytes path,bool payerIsUser,bool isUni)`. `payerIsUser=true` selects `msgSender()` and `isUni=false` selects Aerodrome/Velodrome routing.
- Its payment code first low-level-calls token `transferFrom(payer,recipient,amount)` and falls back to Permit2 only if that call reverts or returns explicit false. Direct ERC20 allowance to the router is therefore the primary supported path.
- Its exact constructor tuple is immutable and decodes to WETH `0x4200000000000000000000000000000000000006`, Permit2 `0x494bbD8A3302AcA833D307D11838f18DbAdA9C25`, Aerodrome V2 factory `0x420DD381b31aEf6683db6B902084cB0FFECe40Da`, primary CL factory `0xaDe65c38CD4849aDBA595a4323a8C7DdfE89716a`, CL factory 2 `0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A`, and CL factory 3 `0xf8f2eB4940CFE7d13603DDDD87f123820Fc061Ef`, with their corresponding init-code hashes.
- Pool selector mapping in the exact source is unflagged primary, `0x100000` factory 2, and `0x080000` factory 3, with pool parameter mask `0x07ffff`. This matches the approved hook parser and `sugar-sdk v0.4.2` packing.
- `cAF22...` exposes `WETH9()` and `PERMIT2()`, but its factory immutables are `internal` and it does not expose `VELODROME_*` getters. It is not a proxy and has no owner/admin function; `owner()` reverts.

### Live Base execution proof
- Successful Base transaction [`0xd22ee365...`](https://basescan.org/tx/0xd22ee3653372a3c84cbfa4516c9d394114e6bb32d5619ecdb9c18fc93eb1d3a6), block `48,707,812`, calls `cAF22...` with `execute(bytes,bytes[],uint256)` selector `0x3593564c`, one `0x00` exact-input command, and a six-field input.
- Its packed pool parameter is `0x0800c8`: factory-3 selector `0x080000` plus tick spacing `200`. The transaction succeeds and sends output directly to the caller.
- At block `48,707,811`, input-token allowance from caller `0xB922...` to `cAF22...` was exactly the input amount, `175000000000000000000`. The caller's ERC20 allowance to Permit2 was zero and Permit2's internal allowance for token/router was `(0,0,0)`. This is on-chain proof that the direct router `transferFrom` path, not Permit2, funded the successful swap.

### Deployment and bytecode comparison
- `cAF22...`: deployed through CreateX `deployCreate3` at Base block `45,003,754`, 2026-04-21 18:40:55 UTC, transaction [`0x3e86f7f...`](https://basescan.org/tx/0x3e86f7f785b50e78434b1324ba3fd5be5ad317b7296df94d5dd6a17eb812915b). Runtime length is 23,759 bytes; runtime keccak is `0xa11d1a13950f5b70dd0d7822e4e3b575778d8614e897c7810d7e6e9f310c017d`.
- `C5b...`: deployed through CreateX at Base block `44,402,301`, 2026-04-07 20:32:29 UTC, transaction [`0x821bf698...`](https://basescan.org/tx/0x821bf69815efb4971dc020918277148ab99cc1f2ed71d9f9f79ca7eef565affe). Runtime length is 24,282 bytes; keccak is `0x0397697643ba8b47d6b50164b6c0a54cf830860e972532f1fbd575d2fc813125`. Its public getters return the same V2/primary/factory-2/factory-3 mapping listed above.
- `6Cb...`: deployed directly at Base block `13,843,986`, 2024-04-30 11:41:59 UTC, transaction [`0x8cce9700...`](https://basescan.org/tx/0x8cce9700dc1252bebd66545063c83ec64f88f0cb15c1e36ad65ae032ba131aa4). Runtime length is 19,991 bytes; keccak is `0x2cad7bafff3766b4f54172b4e628e1bbe8af3f064a4294502b29cfdfeffe9f1c`. Exact verified source is the legacy five-field/`Route[]` generation with only the original CL factory.
- All three addresses still have recent transactions. Historical transaction count is not a canonicality signal; current official app/SDK selection and exact runtime behavior are the decisive evidence.

### Release verification amendment
- The router-address release blocker is resolved in favor of `cAF22...`; implementation tasks 6-8 may use that address.
- Because `cAF22...` has no public factory getters, replace the earlier getter-only preflight with: exact chain/address check; nonempty code; pinned runtime hash `0xa11d...`; callable `WETH9()`/`PERMIT2()` checks; archived exact verified constructor/source evidence; and successful fork execution for classic plus primary, factory-2, and factory-3 CL routes using direct allowance.
- Pin the bytecode hash/config in deployment review. A future Aerodrome frontend or SDK address change is a new release decision; do not follow it automatically without repeating source, constructor, runtime, and fork checks.

## Aerodrome tasks 7-8 final implementation plan (2026-07-16)

### Task 7: pinned Base fork coverage
- Add a dedicated fork suite, suggested path `test/integration/aerodrome/AerodromeUniversalRouterHookFork.t.sol`, pinned to Base block `48_707_812`. Do not reuse `test/utils/Constants.sol` `BASE_BLOCK = 26_885_730`; it predates the selected router's deployment at block `45_003_754`.
- Preflight router `0xcAF22ce31298CF2BF1D152862F80216478ad7c67`: nonempty code, `codehash == 0xa11d1a13950f5b70dd0d7822e4e3b575778d8614e897c7810d7e6e9f310c017d`, `WETH9() == 0x4200000000000000000000000000000000000006`, and `PERMIT2() == 0x494bbD8A3302AcA833D307D11838f18DbAdA9C25`.
- Use `deal` for deterministic account funding, small exact inputs, `outputMin = 1`, and a current fork deadline. Execute through the real hook build/pre/router/post sequence, not a direct router-only call. Assert positive output delta, correct output token/result, direct router allowance behavior, zero token allowance to Permit2, zero Permit2 internal allowance, and final zero router allowance for the approve-and-swap hook. Exercise the swap-only hook separately with a pre-existing direct router approval.
- Pinned classic volatile fixture:
  - WETH -> USDC, pool `0xcDAC0d6c6C59727a65F871236188350531885C43`, `stable=false`.
  - At the pinned block reserves are `1_982_854321833867534658` WETH wei and `3_732_465208828` USDC units.
  - Packed path: `0x420000000000000000000000000000000000000600833589fcd6edb6e08f4c7c32d4f71b54bda02913`.
- Pinned classic stable fixture:
  - USDC -> USDbC, pool `0x27a8Afa3Bd49406e48a074350fB7b2020c43B2bD`, `stable=true`.
  - At the pinned block reserves are `20_460050857` USDC units and `22_891652146` USDbC units.
  - Packed path: `0x833589fcd6edb6e08f4c7c32d4f71b54bda0291301d9aaec86b65d86f6a7b5b1b0c42ffa531710b6ca`.
- Pinned primary CL fixture:
  - WETH -> USDC, pool `0xc758d81B9b81A6FCDAd075bD471874A2c46B54e0`, factory `0xaDe65c38CD4849aDBA595a4323a8C7DdfE89716a`, tick spacing `50`, liquidity `728_814_007_420_443`.
  - Pool balances are `152_404850796501638042` WETH wei and `1_406740523` USDC units.
  - Pool param `0x000032`; packed path: `0x4200000000000000000000000000000000000006000032833589fcd6edb6e08f4c7c32d4f71b54bda02913`.
- Pinned factory-2 CL fixture:
  - WETH -> USDC, pool `0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59`, factory `0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A`, tick spacing `100`, liquidity `1_740_890_871_991_593_982`.
  - Pool balances are `2_716_581015139305324646` WETH wei and `3_502_348618495` USDC units.
  - Pool param `0x100064`; packed path: `0x4200000000000000000000000000000000000006100064833589fcd6edb6e08f4c7c32d4f71b54bda02913`.
- Pinned factory-3 CL fixture:
  - WETH -> USDC, pool `0x3FE04A59Ebd38cF06080a6F60a98D124eb59392A`, factory `0xf8f2eB4940CFE7d13603DDDD87f123820Fc061Ef`, tick spacing `50`, liquidity `4_763_723_036_323_917_193`.
  - Pool balances are `946_751678200819549919` WETH wei and `1_904_162954581` USDC units.
  - Pool param `0x080032`; packed path: `0x4200000000000000000000000000000000000006080032833589fcd6edb6e08f4c7c32d4f71b54bda02913`.
- Suggested exact inputs are `1e15` WETH wei for each WETH/USDC fixture and `1e6` USDC units for the stable fixture. Keep minimum output at one unit so the fork test validates routing/factory selection without turning a historical fixture into a price assertion.

### Task 8: deployment, artifacts, and verification wiring
- `script/utils/Constants.sol`: add the Base router address and pinned runtime hash. The two hook-key strings already exist at lines 225-227.
- `script/utils/ConfigBase.sol`: add `aerodromeUniversalRouters`; in `script/utils/ConfigCore.sol::_setCoreConfiguration`, set it only for `BASE_CHAIN_ID` and leave every other chain zero.
- `script/DeployV2Core.s.sol`:
  - append two fields to `HookAddresses` and add `swapAerodromeUniversalRouterHooks` to `ContractAvailability`;
  - correct `baseHooks` from 72 to 80 by adding the six currently omitted WithId hooks plus both Aerodrome hooks;
  - make Aerodrome availability conditional on the router mapping, subtract/add two skips when absent, size `potentialSkips` to at least 42, and size `potentialMissing` to 110 (`9 core + 5 adapters + 80 hooks + 16 oracles`);
  - when checking adapter bytecode, do not count a configuration-skipped adapter again as missing bytecode;
  - add conditional `_checkHookContracts` calls with `abi.encode(router)` and dependency preflight for the exact Base address, nonempty code, and pinned codehash;
  - change `_deployHooks` length from 78 to 80 without shifting slots `0..77`; deploy swap-only at slot 78 and approve-and-swap at slot 79, leave both empty off Base, assign both returned fields, and conditionally require them nonzero.
- With complete bytecode, corrected Base accounting is 74 deployed hooks (`80 - 6` unavailable OpenOcean/Uniswap V2/Uniswap V3 hooks), and total Base core deployment count is 104 (`9 + 5 + 74 + 16`). Treat any different preflight count as an error to reconcile before broadcast.
- `script/run/tooling/regenerate_bytecode.sh`: add both names to `HOOK_CONTRACTS` (82 -> 84), generate the two artifacts, and promote byte-for-byte identical artifacts to `script/locked-bytecode-dev/` for staging and later `script/locked-bytecode/` for production. Do not use `locked-bytecode-other`.
- `script/run/verify/verify_v2_staging_prod.sh`: define a router variable, populate it only in chain `8453`, encode `constructor(address)` for both names, and add exact source mappings under `src/hooks/swappers/aerodrome/`. Its verifier already enumerates deployment-output keys, so no separate contract list is required.
- Deploy/check Base staging first. Confirm constructor args and runtime, update `script/output/staging/8453/Base-latest.json`, regenerate staging aggregate output and `manifests/hooks.json`, and verify both contracts. Promote the reviewed identical bytecode to production only after fork/staging/security sign-off; then repeat for prod output, aggregate output, manifest, and explorer verification.
- Leave `script/run/others/update_hook_addresses.py` and `deploy_hooks_cast.sh` unchanged. Export is automatic through `DeployV2Base`; no explicit export list needs editing.

### Review gate
- Master Codex: please review and approve or amend this task 7/8 implementation plan before implementation resumes. This turn changed only the shared session context; no production, test, deployment, configuration, artifact, or manifest file was edited.

## Master Codex review: Base router resolution
- Reviewed and approved the `superform-hook-master` router research and independent on-chain checks.
- Production Base router for both Aerodrome hooks is fixed to `0xcAF22ce31298CF2BF1D152862F80216478ad7c67` for this release. The live Aerodrome v5 application and official `sugar-sdk v0.4.2` agree on this address, and it was deployed after the repository-recorded `0xC5b...` router.
- The release gate is satisfied for command compatibility, immutable constructor mapping, and direct allowance behavior: the verified runtime uses commands `0x00`/`0x08`, the six-field packed-path input, all three CL selector mappings, and ordinary ERC20 `transferFrom` before Permit2 fallback. Live Base executions independently demonstrate both classic/direct-allowance and latest-factory/direct-allowance paths with Permit2 allowances at zero.
- `0xC5b...` remains a compatible three-factory deployment but is not the selected current product router. `0x6Cb...` is rejected as ABI-incompatible legacy infrastructure.
- Task 6 is resolved. Tasks 7-8 can proceed against `0xcAF22...`; fork fixtures must cover classic and all three CL factory classes, and deployment preflight must pin runtime hash `0xa11d1a13950f5b70dd0d7822e4e3b575778d8614e897c7810d7e6e9f310c017d` because the factory immutables are internal.

## Aerodrome pinned Base fork verification (2026-07-16)
- Added `test/integration/aerodrome/AerodromeUniversalRouterHookFork.t.sol` at pinned Base block `48,707,812`, after the selected router deployment.
- The suite pins router `0xcAF22ce31298CF2BF1D152862F80216478ad7c67`, runtime hash `0xa11d1a13950f5b70dd0d7822e4e3b575778d8614e897c7810d7e6e9f310c017d`, WETH getter `0x4200...0006`, and router Permit2 getter `0x494bbD8A3302AcA833D307D11838f18DbAdA9C25`.
- Real swaps cover classic volatile WETH/USDC, classic stable DAI/USDC, primary CL WETH/USDC tick 50, factory-2 CL WETH/USDC selector `0x100000` plus tick 10, and factory-3 CL WETH/USDC selector `0x080000` plus tick 10.
- All five route classes execute through `ApproveAndSwapAerodromeUniversalRouterHook`; representative classic and factory-3 CL routes also execute through `SwapAerodromeUniversalRouterHook` after explicit direct router approval. A previous-result fixture proves amount/minimum resizing before a real primary-CL swap.
- Every execution asserts exact input consumption, minimum output, recorded hook output delta/token, unchanged router input-token balance, cleaned direct allowance, and zero ERC20 allowance to the router's Permit2 address.
- Command passed: `FOUNDRY_TEST=test/integration/aerodrome FOUNDRY_SCRIPT=.Codex/unused BASE_RPC_URL=https://base-mainnet.public.blastapi.io forge test --match-contract AerodromeUniversalRouterHookForkTest -vv` -> 9 passed, 0 failed.
- Approved implementation task 7 is complete. Task 8 deployment/config/bytecode/verifier wiring is in progress.

## Aerodrome tasks 7-8 implementation review (2026-07-16)

### Findings
- No blocking correctness defect was found in the Base deployment/count wiring, verifier mappings, or generated/dev-locked artifacts. The implementation is ready for a Base staging deploy/check, subject to the readiness items below.
- Non-blocking check-path gap: `run(check=true, ...)` calls `_checkV2CoreAddresses` and `_checkHookContracts` (`script/DeployV2Core.s.sol:711-716`, `:877-929`, `:1291-1303`) but never runs the Aerodrome dependency preflight. The exact Base address, nonempty code, pinned runtime hash, `WETH9()`, and `PERMIT2()` checks exist only in `_deployCoreContracts` (`:1989-2014`). Therefore a check-only invocation can report the deterministic hook deployments while the external router is missing or mismatched; an actual deployment still fails safely. Consider extracting the router validation into a shared helper called by both paths before treating check mode as a full release preflight.
- Non-blocking fork-coverage gap: the approved plan required asserting Permit2's internal `allowance(owner, token, spender)` tuple is zero. The fork suite checks only the token's ERC20 allowance to the Permit2 address (`test/integration/aerodrome/AerodromeUniversalRouterHookFork.t.sol:165-166`, `:194-195`, `:224-225`) and defines no Permit2 allowance interface. Real execution plus zero ERC20 allowance already proves the direct router path for these fixtures, but the explicit internal-allowance invariant remains untested.

### Confirmed wiring
- Base config points only chain `8453` to `0xcAF22...`; deployment preflight pins the exact address, runtime hash `0xa11d...`, WETH, and router Permit2. Aerodrome is unavailable by default on every other chain.
- `baseHooks` has 80 unique entries, including all six previously omitted WithId hooks and both Aerodrome hooks. `potentialSkips` is exactly the 42-entry worst case and `potentialMissing` is 110 (`9 + 5 + 80 + 16`). Configuration-skipped adapters are no longer double-counted as missing bytecode.
- Existing deployment slots `0..77` are unchanged. Swap-only and approve-and-swap are appended at slots `78` and `79`; all `0..79` indices are populated on their relevant branches, fields are assigned from the matching keys, and Base requires both results nonzero. With current Base configuration and complete dev bytecode, the reconciled count is 74 hooks and 104 total contracts.
- The verifier defines the router only for Base, ABI-encodes `constructor(address)` for both names, and maps both exact Aerodrome source files. Its normal all-contract mode enumerates deployment JSON keys, so no additional verifier list is needed. Both edited shell scripts pass `bash -n`.
- `script/generated-bytecode/` and `script/locked-bytecode-dev/` Aerodrome JSON files are byte-for-byte identical. Their creation and deployed bytecode also exactly match the current `out/` artifacts. Every one of the 80 `baseHooks`, nine core contracts, five adapters, and sixteen oracles has a dev-locked artifact.

### Verification and remaining release gates
- Re-run: pinned Base fork suite compiled with Solc 0.8.30 and passed `9/9` against block `48,707,812` using the public Base RPC.
- Re-run: `FOUNDRY_TEST=.Codex/unused forge build script/DeployV2Core.s.sol` passed; only the pre-existing unused `env` warning in `ConfigCore.sol` was emitted. Slot coverage/uniqueness checks, artifact comparisons, verifier constructor encoding, `git diff --check`, and shell syntax checks passed.
- Production promotion is intentionally incomplete: neither Aerodrome artifact is in `script/locked-bytecode/`, and current staging/prod Base output JSON files contain no Aerodrome deployment keys. Per the approved workflow, deploy and verify Base staging first, update aggregate output/manifests, obtain staging/security sign-off, and only then copy the reviewed identical artifacts into production locks and deploy/verify production.

## Aerodrome review-gap closure (2026-07-16)
- Read-only confirmation completed; both non-blocking findings from the task 7/8 implementation review are closed.
- `script/DeployV2Core.s.sol:938-973` now centralizes the exact Base chain/address, nonempty code, pinned runtime hash, `WETH9()`, and `PERMIT2()` checks in `_validateAerodromeUniversalRouter`. Check-only calls it immediately after availability resolution at `:883-885`, and deployment calls the same helper at `:1969-1971`; unsupported chains return only when Aerodrome availability is false. Both normal and salt-namespace public run variants reach one of these paths.
- `test/integration/aerodrome/AerodromeUniversalRouterHookFork.t.sol:23-32` defines the correct Permit2 `allowance(owner,token,spender)` interface. `_assertNoPermit2Allowance` at `:239-245` checks both the ERC20 allowance to Permit2 and Permit2's internal tuple for owner `address(this)`, the fixture input token, and spender `ROUTER`, asserting amount, expiration, and nonce are all zero. The helper is used by approve-and-swap, swap-only, and previous-result execution paths.
- Re-run verification passed: the pinned Base fork suite compiled with Solc 0.8.30 and passed `9/9`; `FOUNDRY_TEST=.Codex/unused forge build script/DeployV2Core.s.sol` passed with only the pre-existing unused `ConfigCore._setCoreConfiguration(env)` parameter warning. No further code-readiness issue was found in these two fixes.

## Aerodrome implementation completion and release state (2026-07-16)

### Completed implementation
- Approved plan tasks 1-8 are complete at the code and staging-package level. The two concrete hooks, shared strict decoder/path validator, vendor interface, unit mock, unit suite, pinned Base fork suite, sizing/manifest integration, Base router configuration, deployment slots, verifier mappings, generated bytecode, and development bytecode locks are present.
- Base uses router `0xcAF22ce31298CF2BF1D152862F80216478ad7c67`. Configuration and both check/deploy preflights pin chain 8453, runtime hash `0xa11d1a13950f5b70dd0d7822e4e3b575778d8614e897c7810d7e6e9f310c017d`, WETH `0x4200000000000000000000000000000000000006`, and router Permit2 `0x494bbD8A3302AcA833D307D11838f18DbAdA9C25`.
- Deployment accounting now includes all 80 hook slots without changing existing slots `0..77`; Aerodrome swap-only and approve-and-swap occupy `78` and `79`. The existing six omitted WithId hook names and configuration-skipped adapter accounting were corrected as part of the approved deployment-table extension.
- Generated artifacts are byte-for-byte identical to their `script/locked-bytecode-dev/` copies. Runtime sizes are 12,462 bytes for swap-only and 12,506 bytes for approve-and-swap, below EIP-170.
- Production bytecode locks were deliberately not added. Staging/prod output JSON and manifest address maps remain unchanged until real deployments exist.

### Final verification
- Unit: `FOUNDRY_TEST=test/unit/hooks/swappers/aerodrome FOUNDRY_SCRIPT=.Codex/unused forge test --match-contract AerodromeUniversalRouterHookTest -vv` -> 25 passed, 0 failed.
- Fork: `FOUNDRY_TEST=test/integration/aerodrome FOUNDRY_SCRIPT=.Codex/unused BASE_RPC_URL=https://base-mainnet.public.blastapi.io forge test --match-contract AerodromeUniversalRouterHookForkTest -vv` -> 9 passed, 0 failed. Tests execute classic volatile, classic stable, primary CL, factory-2 CL, and factory-3 CL swaps through the real router; both hook variants, previous-hook resizing, direct allowances, cleanup, and zero ERC20/Permit2 internal allowances are covered.
- Deployment source: `FOUNDRY_TEST=.Codex/unused FOUNDRY_SCRIPT=script/DeployV2Core.s.sol forge build script/DeployV2Core.s.sol` passed with only the pre-existing unused `env` warning in `ConfigCore.sol`.
- Live Base check-only preflight passed after shared router validation was added. It reported 104 expected contracts (`9 core + 5 adapters + 74 hooks + 16 oracles`), 99 checked deployment addresses, 97 already deployed, and exactly the two new hooks missing:
  - `SwapAerodromeUniversalRouterHook`: `0x8e6a7B8681d3215cebe68FCD920d191aF17E1897`
  - `ApproveAndSwapAerodromeUniversalRouterHook`: `0xb33582e221506abD0411d0AfA7d5bCbc422C43ca`
- `npm run generate:hook-sizing` and `npm run validate:hook-sizing` pass with zero errors and the same three pre-existing warnings. The generated hook manifest contains 125 hooks, and `uv run --with pyyaml python tooling/lint_hook_manifest.py` passes all checks.
- Both verifier/tooling shell scripts pass `bash -n`; `git diff --check` passes; generated and development-lock files pass `cmp`.
- Repository-wide `make ftest-ci` remains blocked before tests by the three unrelated pre-existing `vm.getRecordedLogs()` mutability errors already documented above. Repository-wide formatting also has unrelated pre-existing drift; changed Aerodrome sources/tests are formatted, and unrelated files were not rewritten.

### Remaining operational release work
- Code and staging inputs are ready, but neither hook is deployed yet. A credentialed release operator must broadcast the Base staging deployment, verify both contracts on the explorer, and regenerate the staging per-chain/aggregate outputs and hook manifest addresses.
- After staging/security sign-off, promote the reviewed artifact JSON files into `script/locked-bytecode/`, broadcast and verify production, then regenerate production outputs and manifest addresses. Do not claim production readiness or add deployment addresses before these on-chain steps succeed.
