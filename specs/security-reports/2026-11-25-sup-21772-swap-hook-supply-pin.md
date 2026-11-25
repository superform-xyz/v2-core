# Security Analysis Report

## Metadata
- **Target:** SUP-21772 change set on branch `cosmin-sup-21772-swap-hook-supply-pin`: `src/hooks/swappers/SuperVaultSupplyPin.sol`
  (new mixin) wired into `ApproveAndSwapKyberSwapHook`, `SwapKyberSwapHook`, `ApproveAndSwapOpenOceanHook`,
  `SwapOpenOceanHook`, `Swap1InchHook`, `ApproveAndSwapOdosV2Hook`, `SwapOdosV2Hook`, `ApproveAndSwapOdosV3Hook`,
  `SwapOdosV3Hook`; Kyber `approveTarget` handling; nine relocked artefacts.
- **Mode:** review (3 parallel agents: adversarial security, correctness/scope, test quality; one final whole-diff pass)
  plus a reproduction in v2-periphery and two mainnet-fork attack suites against the real Kyber and OpenOcean routers.
- **Date:** 2026-11-25
- **Contract Types Detected:** hooks (NONACCOUNTING / SWAP), transient-storage mixin, no admin, no upgradeability.
- **Live verification:** verified sources of KyberSwap `MetaAggregationRouterV2` (Base) and `OpenOceanExchange`
  (Base implementation); mainnet forks of both routers at block 26,400,000.

## Finding being fixed
On a SuperVault strategy, the aggregator swap hooks measure their output as the strategy's balance delta of the output
token. `SuperVault.deposit` / `mint` forward the depositor's asset to the strategy and pay the depositor in shares, and
`handleOperations4626Deposit` only checks that the vault is calling, so the strategy's `executeHooks` lock does not
cover it. Any contract a route reaches (a poisoned `callTarget`, a hooked pool on an honest route) can deposit into the
traded vault mid-swap: the hook delta, the router's own `minReturnAmount` (Kyber and OpenOcean measure the receiver's
delta) and the strategy's `expectedAssetsOrSharesOut` floor all pass, the attacker holds shares, the input leg is gone.
Loss is the whole leg, not the slippage budget. Reproduced in v2-periphery
(`test/unit/security/SuperVaultSwapReentrantDeposit.t.sol`) against the real strategy and hook.

Verified on real router bytecode: Kyber `swap()` has no whitelist on `callTarget` or the source receivers and returns the
`dstReceiver` balance delta; OpenOcean `swap()` runs `caller.makeCalls` and measures `dstReceiver`; Odos measures the
router's own balance and is not fakeable by this trick.

## Fix
`SuperVaultSupplyPin`: in `_preExecute`, if the executing account answers `getVaultInfo()` (a SuperVault strategy),
record `keccak(vault, totalSupply)` in transient storage keyed by account; in `_postExecute`, recompute and revert
`SUPERVAULT_SUPPLY_CHANGED_DURING_SWAP` on any difference. Deposits and mints are the only flows that put asset on the
strategy with a claim attached and both move `totalSupply`; redeems are asynchronous and manager-fulfilled, so a route
cannot undo a mint in the same frame. Plain ERC-7579 accounts commit to zero on both sides: the 4337 path is untouched.
Detection is a raw staticcall with a 96-byte length check, so a revert, empty or short return data all read as "not a
strategy". Flow, data layouts, `inspect()` output and Merkle leaves are unchanged.

`ApproveAndSwapKyberSwapHook` additionally ignores the payload's `approveTarget` and always approves the router: Kyber's
`swap()` never reads the field and `swapGeneric()` uses it only router-side, so honouring it only handed a third party an
allowance on the account's tokens for the batch.

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 0 | Yes |
| P2 Medium | 1 (residual, out of scope) | No |
| P3 Low | 4 (follow-ups) | No |

## Verdict
**PASS** for the nine aggregator hooks. Residual exposure remains in other balance-delta swap hooks (below).

## Findings
### P2 (residual, out of scope of this change)
- The same vector exists in every other balance-delta swap hook whose route a manager controls: Uniswap V4 hooked pools,
  Sushi route bytes, Everlong, Pancake, Aerodrome, Algebra, attacker-created Uniswap V2/V3 pools. The complete closure is
  periphery-side: refuse `handleOperations4626Deposit` / `Mint` while the strategy's execute guard is entered, in the next
  strategy implementation. Core-side interim: apply the mixin to the remaining swap hooks or pin pool keys in leaves.

### P3 (follow-ups)
- The Kyber hooks do not pin the router selector; a payload may name `swapGeneric` or the simple-mode path. Reject
  anything but `swap`.
- `IMetaAggregationRouterV2.SwapExecutionParams` names the two `bytes` fields the other way round from the real router
  (`targetData` is third, `clientData` fifth). Same ABI, positional decode is correct; rename.
- Two edge cases fail a leg rather than skip the check, by design: 96 return bytes that do not decode as
  `(address, address, uint8)`, and a named vault that cannot answer `totalSupply()`. Only the account can cause either.
- Documented false positive: an honest route that also deposits or mints into the traded vault is refused.

## Invariant relied upon
Every flow that moves asset into the strategy with a claim attached mints shares synchronously. An asynchronous deposit
that forwarded assets before minting would be invisible to the pin.

## Tests
- `test/unit/hooks/swappers/SuperVaultSupplyPin.t.sol`: all nine hooks; unchanged / mint / burn / plain account / EOA /
  no-vault / short-return fallback / codeless vault; context bump; two legs in one batch; post without pre; native leg;
  end-to-end through `executeHooks` for Kyber, Odos V2, Odos V3, OpenOcean and 1inch with mid-swap mints; callback input
  token; `usePrevHookAmount` chain; fuzzed supply deltas; fuzzed `approveTarget`; `inspect()` and ERC165 unchanged.
- `test/integration/kyberswap/KyberSwapSupplyPinAttack.t.sol` (mainnet fork, real router): honest and pay-nothing
  controls; deposit, mint, deposit-then-park, half-honest-half-deposit, other vault, context bump variants, deposit for the
  strategy, shares transferred to the strategy, partial-fill and fee-on-destination flags, receiver set to the route,
  poisoned `approveTarget`, `swapGeneric`, two-hook batches, the documented false positive; a direct-leg proof that the
  real router accepts the poisoned route and the pin refuses it.
- `test/integration/openocean/OpenOceanSupplyPinAttack.t.sol` (mainnet fork, real exchange): same shape, including the
  direct-leg proof.
- `test/integration/kyberswap/KyberSwapSupplyPinAccountPath.t.sol`, `test/integration/openocean/OpenOceanSupplyPinAccountPath.t.sol`:
  a Nexus smart account through `SuperExecutor` keeps swapping while a vault mints mid-swap.

## Deployment notes
- Post-audit relock of nine hooks: new CREATE2 addresses. Deploy, register, add leaves, then retire the old swap leaves;
  strategies keep the exposure until their roots drop the old leaves.
- Behaviour change: Kyber `approveTarget` is ignored (previously honoured). Live API payloads use zero or the router.
- Gas: strategies pay two staticcalls, one `totalSupply` read and two transient stores per leg; plain accounts one staticcall.
