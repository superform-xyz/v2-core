# Session 8: CCTP V2 Bridge Hook Implementation

## Overview
Implementing `ApproveAndCCTPSendHook` for cross-chain USDC transfers using Circle's CCTP V2.

## Source Spec
- Technical spec: `specs/cctp-bridge-hooks/technical-spec.md`
- Research: `specs/cctp-bridge-hooks/research/`
- Implementation plan: `.claude/doc/cctp-v2-bridge-hooks/implementation-plan.md` (has corrections needed — see tech spec)

## Key Corrections from Research
1. **Address**: `0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d` (NOT the one in impl plan)
2. **Function**: `depositForBurnWithHook` (with hookData param, NOT just `depositForBurn`)
3. **Parameter**: `maxFee` (NOT `maxBurnAmountPerMessage`)
4. **Chains**: All Superform chains have CCTP V2 deployed

## Files Created
1. `src/vendor/bridges/cctp/ITokenMessengerV2.sol` — Interface for CCTP V2 TokenMessengerV2
2. `src/hooks/bridges/cctp/ApproveAndCCTPSendHook.sol` — Main hook contract
3. `test/unit/hooks/bridges/CCTPHooks.t.sol` — 27 unit tests (all passing)

## Files Modified
4. `script/utils/Constants.sol` — Added `APPROVE_AND_CCTP_SEND_HOOK_KEY` and `CCTP_V2_TOKEN_MESSENGER` address constant
5. `script/DeployV2Core.s.sol` — Added to HookAddresses struct, baseHooks array (59 entries), deployment at index 64 (len=65), hookAddresses mapping, _checkHookContracts
6. `script/run/regenerate_bytecode.sh` — Added "ApproveAndCCTPSendHook" to HOOK_CONTRACTS array

## Bytecode Generated
- `script/generated-bytecode/ApproveAndCCTPSendHook.json`
- `script/locked-bytecode/ApproveAndCCTPSendHook.json`
- `script/locked-bytecode-dev/ApproveAndCCTPSendHook.json`

## Task Status
- [x] Create ITokenMessengerV2 interface
- [x] Create ApproveAndCCTPSendHook contract
- [x] Create CCTPHooks unit tests
- [x] Run tests and verify passing (27/27 pass)
- [x] Update Constants.sol
- [x] Update DeployV2Core.s.sol (index 64, len=65, baseHooks[59])
- [x] Update regenerate_bytecode.sh
- [x] Generate and lock bytecode

## Fork Integration Tests
- `test/integration/cctp/CCTPHooksFork.t.sol` — 25 fork tests against real Ethereum mainnet
- Tests real `depositForBurnWithHook` calls burning USDC on forked mainnet
- **Critical discovery**: Real TokenMessengerV2 requires non-empty hookData (reverts "Hook data is empty")
- **Event verification tests** (5 tests) prove cross-chain messages are correctly constructed:
  - `DepositForBurn` event: indexed burnToken, depositor; data has amount, mintRecipient, destinationDomain, destinationCaller, maxFee
  - `MessageSent` event: raw CCTP message bytes with sourceDomain (0=ETH) and destinationDomain
  - USDC burn flow: Transfer events show account→burner→address(0)
  - Arbitrum domain verification
  - PrevHookAmount reflected in event (2500 USDC, not encoded 1000)

### Updated Task Status
- [x] Fork integration tests (25/25 pass)
- [x] Event verification for cross-chain message proof

### Total Test Count: 52 (27 unit + 25 fork)

## Implementation Details

### ApproveAndCCTPSendHook
- Constructor: `(address tokenMessenger_, address validator_)` — both immutable, both validated non-zero
- HookType: NONACCOUNTING, HookSubType: BRIDGE
- Data layout: burnToken(0) → amount(20) → destinationDomain(52) → mintRecipient(56) → destinationCaller(88) → maxFee(120) → minFinalityThreshold(152) → usePrevHookAmount(156) → hookCallDataLength(157) → hookCallData(189)
- Minimum data length: 157 bytes
- 4 executions: approve(0) → approve(amount) → depositForBurnWithHook → approve(0), all value=0
- hookCallData: if present, decodes 5-tuple from validator, appends signature, re-encodes as 6-tuple
- inspect(): returns abi.encodePacked(burnToken, address(mintRecipient))

### Deployment Integration
- Hook key: `"ApproveAndCCTPSendHook"`
- Token Messenger address: `0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d` (same on all chains, constant in Constants.sol)
- Deployment index: 64 (array length 65)
- Constructor args: `abi.encode(CCTP_V2_TOKEN_MESSENGER, superValidator)`
- No conditional deployment — CCTP V2 is on all Superform chains

## Pigeon CCTP V2 Helper (external repo)

### Overview
Created a CCTP V2 relay test helper in the pigeon repo (`/Users/cosming/1.Coding/Superform/pigeon`).
This enables fork tests to simulate full end-to-end cross-chain USDC transfers via CCTP V2:
burn USDC on source → relay MessageSent → mint USDC on destination.

### Files Created (in pigeon repo)
1. `src/cctp/interfaces/IMessageTransmitterV2.sol` — Minimal interface for destination MessageTransmitterV2
2. `src/cctp/CctpV2Helper.sol` — Main helper contract (follows pigeon conventions)
3. `test/CctpV2.t.sol` — 3 fork tests (ETH→Arbitrum)

### CctpV2Helper Design
- **Constructor**: `CctpV2Helper(uint256 attesterPK)` — pass 0 for default key (0x1)
- **Public API**: `help(uint32 destDomain, uint256 forkId, Vm.Log[] logs)` and multi-destination overload
- **Key addresses**: MessageTransmitterV2 = `0x81D40F21F12A8F0E3252Bccb954D722d4c464B64` (same on all chains)

### Helper Flow
1. Filter logs for `MessageSent(bytes)` events matching the target destination domain
2. Switch to destination fork
3. Replace production attesters with test key via `attesterManager` prank
4. Set `finalityThresholdExecuted = minFinalityThreshold` in message (simulates attestation service)
5. Sign modified message with test key → attestation
6. Clear `usedNonces` storage (slot 29) so nonce isn't rejected on forked state
7. If `destinationCaller != 0`, prank as that address
8. Call `receiveMessage(message, attestation)` on destination MessageTransmitterV2
9. Switch back to source fork

### Key Technical Discoveries
- **USDC `deal` breaks proxies**: `forge deal()` corrupts USDC proxy storage. Fix: use `vm.store` with slot 9 (FiatTokenV2 balance mapping)
- **Finality threshold**: Source chain sets `finalityThresholdExecuted = 0`. Destination rejects if < `minFinalityThreshold`. Helper must set it before signing.
- **Nonce reuse on forks**: Forked chains have `usedNonces` from real transactions. Helper clears the entry via `vm.store` at slot 29.
- **TokenMessengerV2 return type**: Proxy returns no data despite interface declaring `returns (bytes memory)`. Test interface must omit return type.

### Tests (3/3 passing)
1. `testSimpleCctpV2` — Burns 1000 USDC on ETH, relays to Arbitrum, verifies 1000 USDC minted
2. `testCctpV2WithDestinationCaller` — Tests restricted relay (destinationCaller = 0xBEEF)
3. `testCctpV2SkipsNonMatchingDomain` — Verifies non-matching domain logs are ignored

## E2E Cross-Chain Tests (v2-core)

### Overview
Added `CCTPHooksForkE2E` contract to `test/integration/cctp/CCTPHooksFork.t.sol` that uses the pigeon `CctpV2Helper` to test full cross-chain flows: burn USDC on ETH via `ApproveAndCCTPSendHook` → relay → verify mint on Base.

### Submodule Update
- Updated `lib/pigeon` to `feat/cctp-helper` branch (commit `0bdd2f7`)
- Import: `import { CctpV2Helper } from "@pigeon/cctp/CctpV2Helper.sol";`

### E2E Tests (7/7 passing)
1. `test_Fork_E2E_BurnAndRelay_EthToBase` — 1000 USDC full round-trip (burn ETH → mint Base)
2. `test_Fork_E2E_WithMaxFee_EthToBase` — Verify fee deduction (minted >= amount - maxFee)
3. `test_Fork_E2E_WithDestinationCaller_EthToBase` — Restricted relay (helper pranks as destinationCaller)
4. `test_Fork_E2E_WithPrevHookAmount_EthToBase` — prevHook override (2500 USDC minted, not encoded 1000)
5. `test_Fork_E2E_LargeAmount_EthToBase` — 1M USDC burn+relay
6. `test_Fork_E2E_FastFinality_EthToBase` — minFinalityThreshold=1000
7. `test_Fork_E2E_VerifyBothSides` — Assert source burn AND destination mint in one flow

### Total Test Count: 81 (49 unit + 25 fork + 7 E2E)

## CCTPSendHook (no-approve variant)

### Overview
Created `CCTPSendHook` — same logic as `ApproveAndCCTPSendHook` but without the approval pattern (1 execution instead of 4). For use when the burn token is already approved.

### Files Created
- `src/hooks/bridges/cctp/CCTPSendHook.sol` — No-approve CCTP V2 send hook (1 execution: depositForBurnWithHook)

### Files Modified
- `script/utils/Constants.sol` — Added `CCTP_SEND_HOOK_KEY = "CCTPSendHook"`
- `script/DeployV2Core.s.sol` — Added struct field, baseHooks[60], len=66, hooks[64] (CCTPSendHook), hooks[65] (ApproveAndCCTPSendHook shifted), hookAddresses mapping, _checkHookContracts
- `script/run/regenerate_bytecode.sh` — Added "CCTPSendHook" to HOOK_CONTRACTS array
- `test/unit/hooks/bridges/CCTPHooks.t.sol` — Added 22 unit tests for CCTPSendHookTests

### Bytecode Generated
- `script/generated-bytecode/CCTPSendHook.json`
- `script/locked-bytecode/CCTPSendHook.json`
- `script/locked-bytecode-dev/CCTPSendHook.json`

### Deployment Integration
- Hook key: `"CCTPSendHook"`
- Deployment index: 64 (ApproveAndCCTPSendHook shifted to 65)
- Array length: 66
- Constructor args: `abi.encode(CCTP_V2_TOKEN_MESSENGER, superValidator)`

### Updated Task Status
- [x] Pigeon CctpV2Helper (3/3 tests passing in pigeon repo)
- [x] Submodule updated to feat/cctp-helper
- [x] E2E cross-chain tests (7/7 passing)
- [x] All 32 fork tests passing (25 original + 7 E2E)
