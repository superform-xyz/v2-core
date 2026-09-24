# Circle Gateway destination adapter — implementation notes

Branch `feat/circle-gateway-adapter` (from `dev` @ `e6965ae5`, which already contains CCTPAdapter #1015 and
RelayAdapterV2 #1014). Implements `technical-spec.md` §6 in full; nothing was descoped.

## What was built

| Area | Files |
|---|---|
| Vendor interface | `src/vendor/bridges/circle/IGatewayMinter.sol` — `gatewayMint`, `domain`, `isTokenSupported`, `isAttestationSigner`, `isTransferSpecHashUsed`, `isDenylisted`, `paused` |
| Adapter | `src/adapters/CircleGatewayAdapter.sol` — 13 653 B deployed (default profile, `via_ir` off) |
| Unit | `test/unit/adapters/CircleGatewayAdapterUnitTests.t.sol` — 59 tests |
| Fork E2E (live minter) | `test/integration/circle-gateway/CircleGatewayAdapterE2EFork.t.sol` — 16 tests (Base + Ethereum domain 0) |
| Real-executor E2E | `test/integration/circle-gateway/CircleGatewayAdapterRealExecutorE2E.t.sol` — 10 tests |
| Pigeon E2E | `test/integration/circle-gateway/CircleGatewayAdapterPigeonE2E.t.sol` — 8 tests (real `CircleGatewayWalletHook` deposit on Ethereum, pigeon `CircleGatewayHelper` attests + drives the adapter on Base) |
| Shared fork helpers | `test/integration/circle-gateway/GatewayAttestationHelpers.sol` |
| Deploy wiring | `Constants.CIRCLE_GATEWAY_ADAPTER_KEY`, `ConfigBase.gatewayMinters`, `ConfigCore` gate, `DeployV2Core` (list [7]→[8], `potentialSkips` 48→49, availability / check / validation / status / deploy blocks), `regenerate_bytecode.sh` |
| Locked bytecode | `script/locked-bytecode{,-dev}/CircleGatewayAdapter.json` (== `generated-bytecode`) |
| Parity test | `test/script/DeployV2CoreCircleGatewayAdapterArgs.t.sol` — check/deploy ctor-arg parity, prod artifact, availability gate |

## Decisions that differ from CCTPAdapter (and why)

- **Fail fast pre-mint.** Gateway burns on the source only after `AttestationUsed`; an unused attestation expires
  (`maxBlockHeight`) and the depositor's balance is restored. So `UNSUPPORTED_DESTINATION_TOKEN`,
  `HOOK_PAYLOAD_INVALID` (undecodable, account 0, account == adapter), `ZERO_VALUE`, `DESTINATION_*_MISMATCH`
  and `ATTESTATION_SET_MIXED` all revert before `gatewayMint`. There is no `sourceDepositor` escrow and no
  non-USDC escrow. After the mint nothing reverts on content (escrow on failed delivery, catch on execution).
- **AttestationSets.** Parsed with the same `AttestationLib.cursor` the minter uses; every member must share
  caller/recipient/token/hookData; one delivery and one execution for the summed value; every member's spec hash
  is marked `processed` and emitted in `SpecProcessed` with its own attested value (R1-F3).
- **`recoverDirectMint(bytes payload)` — signature-free (security round 1, R1-F2, deviates from spec §6.3).**
  Specs not pinned to the adapter can be minted straight into it by anyone. Recovery requires
  `isTransferSpecHashUsed` (written by the minter only after Circle's signature was verified; binds recipient,
  token, value, salt and hookData) and `!processed` per member, forwards only `balance − totalEscrowed[USDC]`,
  never partially, and runs the same delivery + execution path as the relay. Re-checking the signer added nothing
  and would have stranded funds forever after a Circle signer rotation. Duplicate members in one payload are
  rejected in `_parse` (`ATTESTATION_SET_DUPLICATE`, R1-F1) on both entrypoints.
- **Constructor** binds `gatewayMinter.code.length > 0 && isTokenSupported(usdc)`; `domain()` is NOT required to
  be non-zero (Ethereum is domain 0 — covered by a fork test).
- **No scoped deploy entrypoint** (interview decision). `runCCTPAdapter` is the template if one is wanted later.

## Verified on-chain (2026-09-23)

`GatewayMinter` 0x2222…C205 has code and `isTokenSupported(native USDC) == true` on Ethereum (domain 0), Base (6),
Arbitrum (3), Optimism (2), Polygon (7), Avalanche (1), Unichain (10), Sonic (13), Worldchain (14). Linea has NO
code at the minter address → `gatewayMinters[LINEA] = address(0)`. Live denylister on Base:
0x082CBeca612d6Eee6130E9e07A5C044Fa48bb3F9; the denylist function is `unDenylist` (capital D).

## Gotchas hit while building

- `vm.expectRevert` placed before an internal helper that makes an external call (`minter.domain()` inside the
  spec builder) attaches to that call, not the adapter call — build payloads first.
- One `DeployV2Core` harness instance can run `_setConfiguration` only once (Stargate OFT reinit guard) — the
  availability-gate test uses a fresh harness per chain.
- `vm.etch(addr, hex"fe")` on the executor mock produces an empty-returndata revert (selector 0 in
  `ExecutionFailed`), useful to pin the OOG-shaped path.

## Open questions for Circle (unchanged from the spec)

Re-attestation after expiry (Q1), hookData size cap, AttestationSet issuance policy, denylist policy for
contracts, upgrade notice period for the UUPS minter.

## Security round 1 (2026-09-23)

`specs/security-reports/2026-09-23-circle-gateway-adapter.md` — PASS, no P0/P1; 3 P2 + 8 P3, all fixed in the same
round (duplicate-member rejection, signature-free recovery, per-member `SpecProcessed` value, NatSpec/interface/
gas cleanups). Bytecode regenerated after the fixes (13 611 B) and copied to both locked dirs.

## Security round 2 (2026-09-23)

Post-fix re-analysis: PASS, no P0/P1/P2 code findings; all three round-1 fixes independently verified (attack
compositions reproduced; witness confirmed on vendored, upstream and live minter bytecode). One documentation P2
(stranded stray mints with unusable content — accepted residual, now documented in the adapter) and P3s: new
`ATTESTATION_SET_EMPTY`, doc precision, test-coverage gaps closed (57 unit / 13 fork / 9 real). Bytecode regenerated
(13 653 B) and locked in both dirs.

## Pigeon (2026-09-24)

`exp-table/pigeon` gained `src/circle-gateway/CircleGatewayHelper.sol` (branch `feat/circle-helper`, commits
`eb4ace5` + `2196ff7`, its own security report under `pigeon/specs/security-reports/`). It hand-encodes Circle's
wire formats (byte-for-byte verified against `TransferSpecLib`/`AttestationLib`), enrolls a test attestation signer
on the real minter, and offers `help` / `helpSet` / `helpMintViaAdapter(Set)` / `helpAttest(Set)` / `helpDeposit`.
`lib/pigeon` in v2-core is bumped to `2196ff7` (on `origin/feat/circle-helper`, NOT yet on pigeon `main` — merge the
pigeon PR before merging this branch, or CI's submodule checkout still resolves because the commit is on a pushed
branch). `CircleGatewayAdapterPigeonE2E.t.sol` covers: deposit-via-hook → attest → adapter executes; set delivered
once; replay; pinned caller blocks direct mint; direct mint into the adapter recovered permissionlessly; executor
mismatch; gas floor leaves the spec unconsumed; undecodable hookData rejected pre-mint with the fork restored.

## Security round 3 (2026-09-24) — deploy wiring, tests, artifacts, submodule

PASS. Fixed: shared `_circleGatewayCtorArgs` encoder for check + deploy passes (parity now structural), the
vacuous prod-artifact test (now asserts `__checkBytecodeExists` for all envs and locked == locked-dev), a forged-signer
real-validator test, a falsifiable returnbomb test (800 KB bomb, 3.0M cap), and coverage gaps (claim event/isolation,
reentrancy via recover, two stray mints, F2 pass-through / mixed set / FiatToken blacklist of the adapter on the real
minter). Suites: unit 59, fork 16, real 10, pigeon 8, deploy 10.
