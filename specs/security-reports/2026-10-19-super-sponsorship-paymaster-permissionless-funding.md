# Security Analysis Report: Permissionless fundStrategy (addendum)

## Metadata
- **Target:** `src/paymaster/SuperSponsorshipPaymaster.sol`, `src/interfaces/ISuperSponsorshipPaymaster.sol`
- **Mode:** review (diff-scoped addendum to `2026-07-23-super-sponsorship-paymaster.md`)
- **Date:** 2026-10-19
- **Change under review:** v2-core PR #1034, `feat/paymaster-permissionless-funding`
- **Contract Types Detected:** General (ERC-4337 Paymaster)
- **Files Analyzed:** 2 (contract + interface), plus the three test suites that exercise the change

## What changed, and why it is a trust-boundary change

Before: `fundStrategy` and `setAllowedSender` were both role-gated, by FUNDING_ROLE and
MANAGER_ROLE respectively, and after role transfer those roles sit with two different governance
accounts. A new strategy could not be sponsored until both acted.

After:
1. `fundStrategy` is callable by anyone.
2. The first `fundStrategy` or `creditStrategy` of a never-configured strategy sets
   `allowedSender` to `DEFAULT_ALLOWED_SENDER` (the canonical SuperVaultExecutor) and emits
   `AllowedSenderSet`.
3. A new `senderInitialized` flag is set by any `setAllowedSender` call (whatever value it
   writes) and by the first funding or credit. Only a never-configured strategy receives the
   default.

The 2026-07-23 report's trust model stated that FUNDING_ROLE is "trusted with all funds". That
remains true: FUNDING_ROLE still gates `creditStrategy` and `withdrawStrategyFunds`, which are
the only paths that move or release value. What the role no longer gates is adding value.

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 0 | Yes |
| P2 Medium | 0 | No |
| P3 Low | 2 | No |

## Verdict
**PASS** - No P0 or P1 findings. Two P3 observations, one addressed in the same PR.

## Why permissionless funding is safe

- **A budget is spendable only by its own strategy's ops.** `_validatePaymasterUserOp` requires
  `userOp.sender == allowedSender[strategy]` and that the calldata strategy equals the
  paymaster-data strategy. The SuperVaultExecutor then validates the session key against that
  strategy's own grants. A stranger's ETH can therefore pay gas only for operations the
  strategy's legitimate keys sign.
- **A funder cannot reclaim *what they sent*.** A budget exits only via FUNDING_ROLE
  (`withdrawStrategyFunds`, to any recipient) or the strategy's PRIMARY MANAGER
  (`withdrawStrategyFundsAsManager`, to themselves — see the manager-exit section below). A
  third-party donor is never a recipient; funding is a donation to the strategy, not an escrow.
- **Funding cannot lift a pause**, per strategy or global; both are checked before any spend.
- **Funding cannot grant a role or change a manager's sender.** `setAllowedSender` marks the
  strategy configured, so later funding never overrides it. In particular a manager's reset to
  `address(0)`, which the suite relies on as a block, cannot be re-armed by a 1 wei funding.
  Verified by `test_FundStrategy_CannotReArmAManagerResetToZero` and by
  `invariant_managerBlockSurvivesFunding`.
- **Accounting is unchanged.** Deposit and allocation move together, so `unallocatedBalance`
  is untouched by funding and `reconcile` sees no drift from it.
- **No new external-call surface.** The only external call in the path is
  `entryPoint.depositTo` on the immutable canonical EntryPoint.
- **Funding a bogus address** strands only the funder's own ETH (no session keys can ever
  exist for a strategy the aggregator does not know), and FUNDING_ROLE can still withdraw it.

## Manager exit (`withdrawStrategyFundsAsManager`)

Permissionless funding is paired with a manager-gated exit so a strategy can wind down without
FUNDING_ROLE. The strategy's primary manager reclaims the remaining budget to themselves.

- **Authority** is the SuperVaultAggregator's `isMainManager(msg.sender, strategy)` — the same
  check `SuperVaultExecutor` uses. Funds go to the verified caller, never an arbitrary address, so
  a non-manager cannot redirect them, and a manager of strategy A cannot touch strategy B.
- **The manager can reclaim donor/treasury top-ups**, not only what the manager funded. This is
  intended: the manager already decides where the budget is spent (allowed sender + session keys),
  so a donor is trusting that manager when they fund. There is no per-depositor accounting and so
  no withdrawal race between depositors.
- **No timelock, send-to-caller, no cancel-on-handover** — deliberately unlike the aggregator's
  upkeep withdrawal. Consequence: an outgoing/removed manager can front-run a `changePrimaryManager`
  (or act during the secondary-route 7-day timelock) and drain the budget, so a gas budget does NOT
  transition cleanly to a new manager. Accepted because the budget is gas-only and draining on exit
  is economically equivalent to the manager's pre-existing power to burn it through legitimate
  UserOps while in office.
- **Respects `globalPaused`.** The function reverts `GLOBAL_PAUSED`, so a `reconcile()` desync
  freeze halts this untrusted exit too (it must not let a manager realize an inflated recorded
  balance before the admin corrects budgets, which the trusted FUNDING_ROLE path coordinates).
- **Accounting and reentrancy** match `withdrawStrategyFunds`: `balance` and `totalAllocated` are
  decremented before `entryPoint.withdrawTo` (CEI), bounded by `balance` and the real deposit, and
  the `isMainManager` call is a `STATICCALL` (cannot reenter with effect).
- **Expanded trust boundary.** Fund egress now also depends on the periphery aggregator's access
  logic. `SUPER_VAULT_AGGREGATOR` is an immutable constructor arg, environment-specific (prod and
  staging differ), verified at deploy (`AGGREGATOR_MISMATCH`). A wrong, zero, migrated, or codeless
  address fails this path closed (liveness only) and never affects funding, sponsorship, or the
  FUNDING_ROLE withdrawal. The assumption to uphold operationally: the configured aggregator must be
  governed at least as tightly as FUNDING_ROLE, since a compromised/upgradeable aggregator that
  returns `isMainManager == true` could authorize draining budgets (bounded per call by balance and
  deposit). Mirrors the tracked `DEFAULT_ALLOWED_SENDER` hardcode concern.

## Relation to prior findings

- **P2-4 (2026-07-23), "Permissive default when allowedSender not set".** That finding led to
  default-deny. This change does not reintroduce a permissive default: an unconfigured strategy
  still denies everything (`invariant_uninitializedMeansDeny`); the default is applied only on
  an explicit funding or credit event, and only to the canonical executor, never to an
  arbitrary sender; and the manager's explicit choice always wins.
- **P2-2 (2026-07-23), "Hardcoded DEFAULT_ALLOWED_SENDER prevents executor upgrades".** The
  hardcode now matters more, since it is applied automatically. If the executor is ever
  redeployed at a new address, newly funded strategies would default to the old one until a
  manager overrides. The address is the same on all seven chains today (CREATE2), and the
  manager override path is unchanged. Tracked, not changed here.

## P3 Findings (Low - Consider Fixing)

### [P3-1] `AllowedSenderSet` no longer implies a manager acted
- **File:** `SuperSponsorshipPaymaster.sol`, `_applyDefaultSenderIfNeverConfigured`
- **Category:** Monitoring / provenance
- **Description:** Funding and crediting now emit `AllowedSenderSet`, and a stranger can emit it
  at will by dust-funding arbitrary addresses. No current monitor parses this event. Any future
  alert on it must filter to known strategies and must not read the event as a governance
  action. A distinct event for the default-applied case would make provenance explicit.
- **Status:** Open; follow-up. Documented in the interface NatSpec.

### [P3-2] Deploy verification did not check the contract version
- **File:** `DeploySuperSponsorshipPaymaster.s.sol`, `_deploy`
- **Category:** Deployment
- **Description:** A deployment from stale locked artifacts verified roles and EntryPoint and
  passed. The script now requires `VERSION() == EXPECTED_VERSION`.
- **Status:** Fixed in this PR.

## Migration note
The deployed instances keep the old behaviour. Every Base strategy with a budget already has the
executor as its sender, so first funding on a new instance yields the identical configuration.
The Base instance's roles were never transferred to governance; the deploy EOA still holds all
three, so a migration signed by it is possible without the transfer script, but the transfer
should happen first.

## Test evidence
- Unit: 205 (40 new for this change), including three model-based fuzz tests.
- Invariant: 8 in a new handler suite, with adversarial role-write attempts, zero-sender
  denial probes that check the exact revert selector, and a per-campaign coverage floor.
- Fork: 27 (7 new) against Ethereum mainnet through the real EntryPoint.
