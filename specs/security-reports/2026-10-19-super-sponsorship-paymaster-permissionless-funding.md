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
- **A funder cannot reclaim.** Withdrawal stays with FUNDING_ROLE. Funding is a donation.
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
