<<<<<<< HEAD
# Session 14: ClaimFailedTransferHook for StargateAdapter

## Summary
Create a hook that allows smart accounts to call `claimFailedTransfer(address token, uint256 amount)` on the StargateAdapter contract via the SuperExecutor hook system.

## Context
- The `StargateAdapter` stores failed transfers in a `failedTransfers` mapping when `_tryTransfer` fails during `lzCompose`
- Users can recover via `claimFailedTransfer(address token, uint256 amount)` which requires `msg.sender` to be the account that had the failed transfer
- Smart accounts need a hook to call this function through the SuperExecutor

## Target Function
```solidity
// In StargateAdapter.sol
function claimFailedTransfer(address token, uint256 amount) external nonReentrant {
    if (amount == 0) revert ZERO_AMOUNT();
    uint256 available = failedTransfers[msg.sender][token];
    if (available < amount) revert INSUFFICIENT_FAILED_BALANCE();
    failedTransfers[msg.sender][token] = available - amount;
    if (token == address(0)) {
        (bool success,) = msg.sender.call{ value: amount }("");
        if (!success) revert ETH_TRANSFER_FAILED();
    } else {
        IERC20(token).safeTransfer(msg.sender, amount);
    }
    emit FailedTransferClaimed(msg.sender, token, amount);
}
```

## Status
- [x] Hook master research and planning
- [x] Implementation (`src/hooks/claim/stargate/ClaimFailedTransferHook.sol`)
- [x] Unit tests (13 passing) (`test/unit/hooks/claim/stargate/ClaimFailedTransferHook.t.sol`)
- [x] Integration tests (5 passing, including full Pigeon bridge flow) (`test/integration/stargate/StargateAdapterE2EFork.t.sol`)
- [x] Bytecode regeneration for ClaimFailedTransferHook (added to `regenerate_bytecode.sh`)
- [x] Deployment scripts (Constants.sol, DeployV2Core.s.sol)
- [x] Bytecode regeneration for StargateAdapter (after L-1/L-2 comment fixes)
- [x] Security fix: Compose sender trust — TokenMessaging pool registration validation
- [x] Security fix: Returnbomb — bare catch {} blocks (already done prior session)
- [x] Security fix: Unbacked failedTransfers credits — preBalance guard
- [x] All tests passing: 82 total (27 unit + 28 fork + 27 E2E)
- [x] Security review: PASS (0 P0, 0 P1, 3 P2, 7 P3) — report at specs/security-reports/2026-06-03-stargate-adapter-claim-hook.md
- [x] P2-3 fix: Added NatSpec @param to handleCompose external function
- [x] P3 fixes: abi.encodeCall, NatSpec corrections, data length validation, @dev on inspect
- [x] Added decodeAmount and replaceCalldataAmount to ClaimFailedTransferHook (ISuperHookInflowOutflow + ISuperHookOutflow)
- [x] Updated hook master skill with mandatory decodeAmount/replaceCalldataAmount rule
- [x] Bytecode regenerated for both ClaimFailedTransferHook and StargateAdapter
- [x] All tests passing: 26 hook unit tests + 27 adapter unit tests
- [x] Added 4 new E2E integration tests (total 9 E2E hook tests):
  - test_Fork_E2E_ClaimFailedTransferHook_DecodeAndReplaceAmount (bundler roundtrip flow)
  - test_Fork_E2E_ClaimFailedTransferHook_MultipleTokens (USDC + native ETH for same user)
  - test_Fork_E2E_ClaimFailedTransferHook_Inspect (inspect verification in fork context)
  - test_Fork_E2E_ClaimFailedTransferHook_RevertIf_DataTooShort (data validation in E2E)

## Security Fix: Compose Sender Trust (P0 Critical)

### Problem
LZ V2's `sendCompose()` is permissionless — anyone can register a compose targeting the adapter with a fabricated `_from`. Old code trusted any `_from` that implemented `token()`, allowing attackers to spoof composes and drain adapter funds.

### Fix
Added `ITokenMessaging` on-chain registry verification:
- Constructor now takes 3 args: `(lzEndpoint, tokenMessaging, superDestinationExecutor)`
- Step 3 in `lzCompose`: `if (TOKEN_MESSAGING.assetIds(_from) == 0)` → emit `UnregisteredPool`, return
- Only registered Stargate pools (USDC, USDT, ETH, etc.) pass validation
- OFT adapters are NOT registered in TokenMessaging — they need a separate adapter if supported

### Files Changed
- `src/adapters/StargateAdapter.sol` — added TOKEN_MESSAGING immutable, pool validation step
- `src/vendor/bridges/stargate/ITokenMessaging.sol` — new minimal interface
- `test/unit/adapters/AdaptersUnitTests.sol` — MockTokenMessaging, pool validation tests
- `test/integration/stargate/StargateAdapterFork.t.sol` — real TokenMessaging validation tests
- `test/integration/stargate/StargateAdapterE2EFork.t.sol` — updated constructors, mock assetIds for native ETH tests

### Real TokenMessaging Addresses
- Ethereum: `0x6d6620eFa72948C5f68A3C8646d58C00d3f4A980`
- Base: `0x5634c4a5FEd09819E3c46D86A965Dd9447d86e47`

### Deployment Note
`script/DeployV2Core.s.sol` needs updating to pass tokenMessaging address (lines 966-970). Configuration needs `stargateTokenMessagings` mapping added to `ConfigBase.sol`.

## Security Fix: Unbacked failedTransfers Credits (P0 Critical)

### Problem
When `sendParam.to = account` (not adapter), tokens go directly to the account during lzReceive. The adapter has 0 balance but lzCompose still fires on the adapter, which creates `failedTransfers` credits without verifying the adapter held the funds. These unbacked credits can drain other users' legitimate funds via `claimFailedTransfer`.

### Fix
Added `preBalance` snapshot in `handleCompose()` before any transfer attempt:
```solidity
uint256 preBalance = tokenSent == address(0) ? address(this).balance : IERC20(tokenSent).balanceOf(address(this));
```

Both `failedTransfers` credit paths (account == address(0) and transfer failure) are now guarded by `if (preBalance >= amountLD)`. If the adapter doesn't hold the funds, no credit is created.

### Files Changed
- `src/adapters/StargateAdapter.sol` — added preBalance snapshot and guard in handleCompose()
- `test/unit/adapters/AdaptersUnitTests.sol` — updated 3 claim tests to fund adapter + mock transfer revert; added 3 new preBalance guard tests
- `test/integration/stargate/StargateAdapterFork.t.sol` — updated 8 failed transfer tests to fund adapter + mock transfer revert; added 1 new preBalance guard test

### Test Changes
Tests that previously simulated failed transfers by NOT funding the adapter now:
1. Fund the adapter with the correct amount (so preBalance guard passes)
2. Use `vm.mockCallRevert` on the token's `transfer` call to simulate a blacklisted account
3. Clear mocks before claim step so the claim succeeds

New tests verify the preBalance guard:
- `test_StargateAdapter_lzCompose_NoPreBalance_NoFailedCredit` — ERC20 path
- `test_StargateAdapter_lzCompose_NoPreBalance_ZeroAccount_NoFailedCredit` — zero account path
- `test_StargateAdapter_lzCompose_NoPreBalance_NativeETH_NoFailedCredit` — native ETH path
- `test_Fork_StargateAdapter_lzCompose_NoPreBalance_NoUnbackedCredit` — fork test with real USDC

## Implementation Plan

Full plan saved at: `.claude/doc/ClaimFailedTransferHook/implementation-plan.md`

### Key Decisions
1. **Adapter address in hook data (NOT constructor)**: Multiple StargateAdapter instances may exist per chain; the bundler targets whichever adapter holds the user's failed transfer balance.
2. **NONACCOUNTING HookType with CLAIM subtype**: Utility hook for recovery, not vault accounting.
3. **No ISuperHookContextAware**: No chaining support needed; the claim amount is always explicit.
4. **Supports native ETH**: token = address(0) is valid, matching StargateAdapter's convention.
5. **Minimal IStargateAdapterClaim interface**: Uses `abi.encodeCall` with type-safe minimal interface for `claimFailedTransfer`.
6. **decodeAmount + replaceCalldataAmount**: Implements ISuperHookInflowOutflow and ISuperHookOutflow for bundler compatibility. Amount at offset 40.

### Data Layout (72 bytes total)
```
Offset 0:  address adapter  (20 bytes) -- StargateAdapter to claim from
Offset 20: address token    (20 bytes) -- Token to claim, address(0) for native ETH
Offset 40: uint256 amount   (32 bytes) -- Amount to claim
```

### Files to Create
1. `src/hooks/claim/stargate/ClaimFailedTransferHook.sol`
2. `test/unit/hooks/claim/stargate/ClaimFailedTransferHook.t.sol`

### Files to Modify
3. `script/utils/Constants.sol` -- add `CLAIM_FAILED_TRANSFER_HOOK_KEY`
4. `script/DeployV2Core.s.sol` -- add to HookAddresses struct, hook array (increment len from 70 to 71), deployment entry (next available index after 65), address assignment, and __checkContract validation
5. `script/run/regenerate_bytecode.sh` -- add `"ClaimFailedTransferHook"` to HOOK_CONTRACTS

### Important Notes for Implementation
- Token address(0) is VALID (native ETH) -- do NOT revert on zero token address
- Execution.value is always 0 -- the StargateAdapter sends ETH back via msg.sender.call
- Use `pure` visibility for `inspect()` since no immutable variables are accessed
- The `_getBalance` helper uses `account.balance` for native ETH, `IERC20.balanceOf` for ERC20
- Must be on `pre-dev` branch
- Check exact hook index in DeployV2Core.s.sol before adding -- indices may have changed
=======
# Session 14: SpectraMetaVaultOracle — Custom Oracle for Spectra MetaVaultWrapper

## Context
The generic `ERC7540YieldSourceOracle` has two bugs when used with Spectra MetaVaultWrapper (0x6420A613e936602Ca3f1AD5680b3F4d47D473bf1 on Base):
1. `getTVL()` returns 0 — MetaVaultWrapper inherits OZ `totalAssets()` which returns `asset.balanceOf(vault)` (idle USDC = 0) instead of vault NAV
2. Component 3 (claimable redeem) uses `maxWithdraw()` which calls OZ `_convertToAssets` (totalAssets/totalSupply = 0/totalSupply = 0) instead of the overridden `convertToAssets()` (epoch snapshot rate)

## Status: COMPLETE

## Workflow
- `/superform:spec` completed (all 5 phases: interview, research, technical spec, pod leader spec)
- `/superform:work` completed (all 4 implementation tasks)

## Files Created

### src/accounting/oracles/SpectraMetaVaultOracle.sol
- Custom oracle extending `AbstractYieldSourceOracle` directly
- Constructor: `(address superLedgerConfiguration_, uint256 requestId_)`
- **Bug fix #1**: `getTVL()` uses `convertToAssets(IERC20(shareToken).totalSupply())` instead of `totalAssets()`
- **Bug fix #2**: Component 3 uses `claimableRedeemRequest(requestId, owner) -> convertToAssets(claimableShares)` instead of `maxWithdraw(owner)`
- All other methods identical to ERC7540YieldSourceOracle
- R1 error handling for PPS (hard revert), R2 for async components (try/catch)
- Share token discovery: `try share() catch { return vault }` fallback

### test/unit/accounting/SpectraMetaVaultOracle.t.sol
- `MockSpectraMetaVault` simulating MetaVaultWrapper behavior (totalAssets=0, no share(), epoch pricing)
- 39 unit tests covering: constructor, decimals, share token fallback, PPS, both bug fixes, all 5 TVL components, R1/R2 error handling, fuzz tests, batch methods

### test/integration/spectra/SpectraMetaVaultOracleFork.t.sol
- 9 fork tests against live Base MetaVault
- Confirms: Spectra oracle getTVL = 443,715 (correct), Generic oracle getTVL = 0 (the bug)

### Spec files (in specs/spectra-metavault-oracle/)
- spec.md, technical-spec.md, interview-notes.md
- research/: repo-analysis.md, evm-security.md, specflow-analysis.md

## Files Modified

### script/run/regenerate_bytecode.sh
- Added `"SpectraMetaVaultOracle"` to `ORACLE_CONTRACTS` array (line 189)

### script/generated-bytecode/SpectraMetaVaultOracle.json
- Generated bytecode artifact (93KB)

## Test Results
- Unit tests: 39/39 pass
- Fork tests: 9/9 pass (requires BASE_RPC_URL)
>>>>>>> 5eecd2831eee048ae9cecc7de114fec91d5513d9
