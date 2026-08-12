# Relay Bridge Integration — User Flow & Gap Analysis (spec-flow-analyzer)

## User Flow Overview

### Flow 1 — Happy path, ERC20, direct-to-executor (primary path)
1. User signs full intent (merkle root, DstProof[], executorCalldata) via SuperValidator flow
2. Bundler: POST /quote (txs=[transfer to account, processBridgedExecution(...)], explicitDeposit=true) → orderId + deposit step
3. userOp executes ApproveAndRelaySendFundsAndExecuteOnDstHook(token, amount, orderId) → depositErc20(account, token, amount, orderId) → RelayErc20Deposit event (event-only, no state)
4. Solver → RelayRouterV3.multicall([transfer(account, amount), processBridgedExecution(...)], allowFailure=false) — atomic, in order
5. Executor validates signature + balances + root, executes on account

### Flow 2 — Happy path, native ETH, direct-to-executor
Same, but RelaySendFundsAndExecuteOnDstHook (no approve) calls depositNative(account, orderId){value: amount}; destination call 1 is {to: account, value: amount}.

### Flow 3 — Chained-hook amount (usePrevHookAmount)
Prior hook produces outAmount; Relay hook substitutes it at execution time — AFTER the /quote (and orderId) was generated against a static amount. → Critical Question #1.

### Flow 4 — Solver no-fill / refund
Deposit in RelayDepository, no fill. Relay's Oracle detects; solver fast-refunds on ORIGIN chain to refundTo, minus gas. No on-chain trigger or claim on Superform's side.

### Flow 5 — Solver under-fill
Delivered < intentAmounts → _validateBalances fails silently (no revert, root NOT burned); router multicall still succeeds. Funds sit at account, retriable by anyone — but nothing specifies who retries.

### Flow 6 — Wrong-token fill
Token not in signed dstTokens → same silent no-op. Wrong token sits at account; "user-recoverable" but the recovery mechanism is undefined. → Question #5.

### Flow 7 — Adapter fallback path
txs[] routes through RelayAdapter.processRelayExecution(tokenSent, amount, abi.encode(initData, sigData)). Adapter re-derives fields from DstProof, checks balance − totalEscrowed ≥ amount, forwards, try/catch executor.

### Flow 8 — Failed transfer self-claim
_tryTransfer fails → credit failedTransfers + totalEscrowed, emit TransferFailed, still attempt executor (no-ops on balance). User later calls claimFailedTransfer.

### Flow 9 — Replay attempts
(a) Same root twice → usedMerkleRoots gate, safe no-op. (b) Adapter message replay after forwarding → INSUFFICIENT_FUNDS_RECEIVED revert. (c) Bundler reuses one root across two quotes → second fill permanently un-auto-executable under that root — bundler idempotency requirement, no on-chain guard.

### Flow 10 — Counterfactual account creation
Destination-side via _validateOrCreateAccount (existing mechanism). Sub-questions: source-side deposit from not-yet-deployed account in same userOp (untested for Relay); initData is constructed entirely off-chain at quote time.

## Flow Permutations Matrix

| Dimension | Variants |
|---|---|
| Source token | ERC20 (pre-approved) · ERC20 (ApproveAnd) · native ETH |
| Amount source | Static hookData · usePrevHookAmount chained |
| Destination path | Direct-to-executor · via RelayAdapter |
| Solver outcome | Full fill · under-fill · wrong-token · no-fill (refund) · late fill |
| Account state (dst) | Deployed · counterfactual |
| Adapter delivery | Success · failure → failedTransfers |
| Root state | Unused · used (replay) · reused across 2 quotes (bundler bug) |
| Executor outcome | Succeeds · reverts (adapter try/catch swallows) |
| Solver txs[] atomicity | Router-atomic (allowFailure=false) · **non-atomic deviation (undocumented-but-possible)** |
| Chain deployment | Canonical depository 0x4Cd0…BC31 · non-canonical (Cronos/Metis/zkEVM/Mantle/Linea/Taiko/Zero) |

The test plan covers most Solver-outcome × Destination-path cells but has **no test for the non-atomic deviation** cell — the one place the design explicitly declines to guarantee.

## Missing Elements & Gaps

1. **Amount/quote consistency (design-level):** usePrevHookAmount vs orderId generated off-chain against a fixed amount. Amount drift could strand funds in the depository with no fill and unclear refund. Across avoids this structurally (deposit call IS the quote); Relay does not.
2. **Adapter fund-authentication:** security research recommended balance-delta measurement; the plan uses a static balance check (balance − totalEscrowed ≥ amount) because funds arrive in a separate prior call. Residual exposure: funds parked between two NON-ATOMIC solver txs are claimable by anyone with a validly-signed own-account message. "Document, don't fix" — needs explicit risk acceptance, not a code comment.
3. **Recovery / manual-intervention ownership:** under-fill, wrong-token, and refund flows all need *someone* to act (retry, sweep, notice refund). No component owns this.
4. **Token sweep mechanism from smart account:** undefined ("user-recoverable" asserted without mechanism — presumably owner's raw ERC-7579 module call).
5. **Deposit id correlation integrity:** deposits are event-only; orderId→quote correlation is 100% off-chain trust. Bundler bugs (mismatched/reused orderId) undetectable on-chain.
6. **Signature/quote ordering:** intent must be fully signed before /quote; orderId must exist before hookData is built. RESOLVED IN SPEC: orderId sits in hookData inside the signed userOp calldata, so the user's signature commits to it; bundler cannot substitute post-signature.
7. **Cancellation parity:** deBridge has DeBridgeCancelOrderHook; Relay has NO on-chain cancel/withdraw at all. Call out explicitly in the spec limitations.
8. **Fee/min-output encoding:** intentAmounts is the only min-output surrogate and must net out Relay fees; no test targets "fee estimation error causes permanent under-fill no-op."
9. **Chain-address drift:** non-canonical depository addresses exist; deploy plan relies on manual verification, no CI check against addresses.prod.json.
10. **Testing coverage gaps:** non-atomic-solver race regression test; amount-drift-on-chaining test; root-reuse-across-quotes documentation assertion.

## Critical Questions

1. **(Critical)** Does usePrevHookAmount chaining make sense for Relay hooks, given the amount is fixed at off-chain quote time? Affects data layout and whether chaining should be exposed/gated/documented.
2. **(Critical — RESOLVED)** Is orderId bound into the user's signed intent? YES — hookData containing depositId is part of the signed userOp calldata (SuperValidator merkle leaf). Pre-signature bundler trust is inherent (bundler constructs what the user signs), same as all existing bridge hooks.
3. **(Critical)** Adapter residual-exposure (non-atomic solver window): accept as documented trust assumption or redesign? Needs formal risk acceptance from SECURITY.md owner.
4. **(Critical)** Who retries under-filled/wrong-token intents? Needs explicit backend handoff in acceptance criteria.
5. **(Important)** Concrete recovery mechanism for stranded wrong tokens at the account.
6. **(Important)** Validate the destination txs[] contract against a real Relay quote before backend implementation (fork tests use synthetic solver calls; recommend one manual quote+fill dry run pre-GA).
7. **(Important)** Ongoing sync plan for depository addresses vs Relay's addresses.prod.json (fund-loss severity if stale).
8. **(Important)** Operational story if bundler reuses one root across two quotes (backend idempotency requirement — state explicitly in spec).
9. (Nice) On-chain sanity bound on chained amounts? Default: no, off-chain concern.
10. (Nice) Explicitly state "no cancellation flow" in spec limitations. Default: yes, one sentence.

## Recommended Next Steps
1. Resolve amount-chaining question before hook code (affects layout).
2. Formal sign-off on adapter residual-exposure trust assumption.
3. ~~Clarify orderId signature binding~~ — resolved (bound via hookData in signed userOp).
4. Acceptance criteria for backend handoff items (retry ownership, orderId uniqueness, root idempotency).
5. Add missing test cases (non-atomic race regression, amount-drift once #1 resolved).
6. Re-confirm hook-master layout if decisions change it.
