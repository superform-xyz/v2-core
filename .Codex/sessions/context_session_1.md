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
