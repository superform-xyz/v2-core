# Repository Analysis — Stargate Native Fee Sponsorship

## Hook Patterns

### NONACCOUNTING Hooks
- `NativeTransferHook` (`src/hooks/tokens/NativeTransferHook.sol`) — Closest pattern. 52 bytes data (address + uint256), single Execution output, `HookSubTypes.TOKEN`.
- `AcrossSendFundsAndExecuteOnDstHook` (`src/hooks/bridges/across/`) — NONACCOUNTING with immutable constructor params (`SPOKE_POOL_V3`, `VALIDATOR`). Pattern for immutable `SPONSORSHIP` address.
- `ClaimRFLRHook` (`src/hooks/claim/flare/ClaimRFLRHook.sol`) — Uses immutable `RNAT` address in constructor, `HookSubTypes.TOKEN`.

### Data Encoding
- All hooks use `BytesLib` for packed encoding (`BytesLib.toAddress`, `BytesLib.toUint256`)
- Data positions are defined as constants (e.g., `SPONSOR_POSITION = 0`, `AMOUNT_POSITION = 20`)
- Minimum data length validated before decoding

### Hook Lifecycle
- `BaseHook.build()` wraps `_buildHookExecutions()` with preExecute/postExecute
- NONACCOUNTING hooks typically don't override preExecute/postExecute
- `inspect()` must return only addresses (PROTOCOL REQUIREMENT)

## Paymaster Patterns

### SuperNativePaymaster (`src/paymaster/SuperNativePaymaster.sol`)
- Constructor: `constructor(IEntryPoint _entryPoint) payable BasePaymaster(_entryPoint)`
- `handleOps`: deposits entire balance to EntryPoint, calls `entryPoint.handleOps`, withdraws remaining deposit back to `msg.sender`
- No access control on `handleOps` — permissionless
- Uses `UserOperationLib` for `PackedUserOperation` field access

### SuperSponsorshipPaymaster (`src/paymaster/SuperSponsorshipPaymaster.sol`)
- Per-strategy gas budgets (separate concern from native fee sponsorship)
- Already deployed on Base at `0x8C71Eb1817a2707E8e40aC978B1993b98F1366aa`
- Pattern reference only — different purpose

## Deployment Patterns

### DeployV2OtherHooks.s.sol
- Uses `HookDeployment[]` arrays with `_deployHookBatch()`
- Two-step deployment for hooks with dependencies (deploy dependency first, then hook)
- Uses CREATE2 deterministic deployment via factory
- Constants defined in `ConstantsOtherHooks.sol`

### Bytecode Regeneration
- `script/run/regenerate_bytecode.sh` — contracts grouped by category arrays
- Pattern: define array, iterate with copy/verification logic
- Follow RFLR_HOOK_CONTRACTS pattern for new arrays

## Test Patterns

### Unit Tests
- Inherit from `Helpers` base class
- `setUp()` creates fresh contract instances
- `makeAddr()` for test addresses, `vm.deal()` for ETH funding
- `vm.prank()` for impersonation, `vm.expectRevert()` for error testing
- `vm.expectEmit()` for event assertions
- Test contracts need `receive() external payable {}` for ETH reception

### Naming Convention
- `test_FunctionName()` for happy path
- `test_FunctionName_Variant()` for variants
- `test_FunctionName_RevertIf_Condition()` for revert cases

## Directory Structure

### Existing
- `src/hooks/tokens/` — Token-related hooks
- `src/hooks/bridges/` — Bridge hooks (Across, deBridge)
- `src/hooks/claim/` — Reward claiming hooks
- `src/paymaster/` — Paymaster contracts

### New (Proposed)
- `src/sponsorship/` — NativeFeeSponsorship ledger (standalone, not a hook or paymaster)
- `src/hooks/sponsorship/` — FetchNativeFeeHook
- `test/unit/sponsorship/` — Sponsorship unit tests
- `test/unit/hooks/sponsorship/` — Hook unit tests
