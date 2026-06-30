# ClaimRFLV2Hook Implementation Plan

## Overview

A new **parameterless** claim hook that discovers claimable rFLR rewards entirely on-chain by enumerating projects via the RNat contract. Unlike the existing `ClaimRFLRHook` which requires offchain-packed `(month, projectIds[])` data, this hook calls `getProjectsCount()`, iterates to find projects with `getClaimableRewards(i, account) > 0`, and calls `claimRewards(projectIds, month)` with the discovered IDs.

**Key difference from ClaimRFLRHook**: No offchain data packing needed. The `data` parameter to `_buildHookExecutions` is empty (or ignored).

---

## Files to Create

### 1. `src/hooks/claim/flare/ClaimRFLV2Hook.sol`

**Contract**: `ClaimRFLV2Hook is BaseHook`

**HookType**: `NONACCOUNTING` (rFLR is non-transferable, no fee collection at claim stage -- same as ClaimRFLRHook)

**HookSubtype**: `HookSubTypes.CLAIM`

**Constructor**:
```
constructor(address rNat_)
```
- Single immutable: `address public immutable RNAT`
- Validate `rNat_ != address(0)`, revert with `ADDRESS_NOT_VALID()` if zero

**Constants**:
```
uint256 private constant MAX_PROJECT_IDS = 50;
```

**Custom Errors**:
```
error NO_CLAIMABLE_REWARDS();
error TOO_MANY_PROJECTS();
```

**NatSpec Data Layout** (parameterless -- document that data is empty/ignored):
```solidity
/// @title ClaimRFLV2Hook
/// @author Superform Labs
/// @notice Claims rFLR rewards from Flare's RNat contract using fully on-chain enumeration.
///         No offchain data packing needed -- the hook discovers claimable projects automatically.
/// @dev rFLR tokens are non-transferable, so fee collection is not supported at the claim stage.
///      Fees should be collected at the WFLR withdrawal stage via WithdrawRFLRHook.
/// @dev data has the following structure
/// @notice         (empty -- this hook is parameterless and ignores calldata)
```

**`_buildHookExecutions(address, address account, bytes calldata)`**:
- Visibility: `internal view override`
- Logic:
  1. Call `IRNat(RNAT).getProjectsCount()` to get total project count
  2. Validate: `if (projectCount > MAX_PROJECT_IDS) revert TOO_MANY_PROJECTS();`
  3. Call `IRNat(RNAT).getCurrentMonth()` to get the current month
  4. First pass: count how many projects have claimable rewards by looping `i = 0..projectCount-1` and checking `IRNat(RNAT).getClaimableRewards(i, account) > 0`
  5. If count is 0, revert with `NO_CLAIMABLE_REWARDS()`
  6. Second pass: build `uint256[] memory projectIds` array of the exact size, filling in the project IDs that have claimable rewards
  7. Build single `Execution`:
     ```
     executions = new Execution[](1);
     executions[0] = Execution({
         target: RNAT,
         value: 0,
         callData: abi.encodeCall(IRNat.claimRewards, (projectIds, month))
     });
     ```

**IMPORTANT IMPLEMENTATION NOTE**: The two-pass approach (count first, then fill) is necessary because Solidity requires knowing the array length at creation time for `memory` arrays. An alternative single-pass approach would be to allocate `projectIds` with `MAX_PROJECT_IDS` or `projectCount` length and then use assembly to shrink it, but the two-pass approach is cleaner and gas is negligible on Flare.

**`inspect(bytes calldata)`**:
- Returns `abi.encodePacked(RNAT)` (addresses only -- protocol requirement)
- Visibility: `external view override`

**`_preExecute(address, address account, bytes calldata)`**:
- Set `asset = RNAT;`
- Snapshot pre-balance: `_setOutAmount(IERC20(RNAT).balanceOf(account), account);`
- Identical to ClaimRFLRHook._preExecute

**`_postExecute(address, address account, bytes calldata)`**:
- Get current balance, compute delta (currentBalance - preBalance), set as outAmount
- Handle edge case where balance decreases: delta = 0
- Identical to ClaimRFLRHook._postExecute

**Interfaces NOT implemented** (by design):
- `ISuperHookInflowOutflow` / `ISuperHookOutflow` -- not needed for NONACCOUNTING hooks with no user-specified amount
- `ISuperHookContextAware` -- no hook chaining support needed (parameterless, no `usePrevHookAmount`)
- This matches the existing ClaimRFLRHook pattern

**Imports needed**:
```solidity
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IRNat } from "../../../vendor/flare/IRNat.sol";
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
```

Note: No `BytesLib` import needed (no data decoding).

---

## Files to Modify

### 2. `src/vendor/flare/IRNat.sol`

**Change**: Add a single function to the existing interface.

**Add after the existing `getClaimableRewards` function**:

```solidity
/// @notice Returns the total number of registered projects
/// @return The number of projects
function getProjectsCount() external view returns (uint256);
```

**Why**: This is a real function on the deployed Flare RNat contract (address `0x26d460c3Cf931Fb2014FA436a49e3Af08619810e` on Flare mainnet). The existing IRNat interface simply didn't include it because the original ClaimRFLRHook didn't need it.

**Verification**: The function signature `getProjectsCount()` returns `uint256` and is a `view` function on the RNat contract. This can be verified by calling `cast call 0x26d460c3Cf931Fb2014FA436a49e3Af08619810e "getProjectsCount()(uint256)" --rpc-url <FLARE_RPC>`.

### 3. `script/utils/ConstantsOtherHooks.sol`

**Change**: Add the new hook key constant.

**Add after line 24** (after the existing rFLR hook keys):
```solidity
string internal constant CLAIM_RFLV2_HOOK_KEY = "ClaimRFLV2Hook";
```

### 4. `script/DeployV2OtherHooks.s.sol`

**Changes**:

**(a) Update `RFLRHookAddresses` struct** (line 53-57):
Add a new field:
```solidity
struct RFLRHookAddresses {
    address claimRFLRHook;
    address claimRFLV2Hook;       // <-- NEW
    address withdrawRFLRHook;
    address withdrawVestedRFLRHook;
}
```

**(b) Update `_deployRFLRHooks` function** (line 565-606):
- Change `len` from 3 to 4
- Add the new hook deployment entry at index 1 (or 3, order doesn't matter):
```solidity
hooks[1] = HookDeployment(
    CLAIM_RFLV2_HOOK_KEY,
    "",
    abi.encodePacked(__getOtherHooksBytecode("ClaimRFLV2Hook", env), abi.encode(RNAT_FLARE))
);
```
- Update index assignments for subsequent hooks (shift by 1 if inserting at index 1)
- Add address assignment: `hookAddresses.claimRFLV2Hook = addresses[1];`
- Add require validation: `require(hookAddresses.claimRFLV2Hook != address(0), "ClaimRFLV2Hook not assigned");`

### 5. `script/run/regenerate_bytecode.sh`

**Change**: Add `ClaimRFLV2Hook` to the `RFLR_HOOK_CONTRACTS` array (line 241-245).

```bash
RFLR_HOOK_CONTRACTS=(
    "ClaimRFLRHook"
    "ClaimRFLV2Hook"         # <-- NEW
    "WithdrawRFLRHook"
    "WithdrawVestedRFLRHook"
)
```

### 6. `script/run/deploy_v2_other_hooks_staging_prod.sh`

**Change**: Add `ClaimRFLV2Hook` to the `RFLR_HOOKS` array (line 464-467).

```bash
RFLR_HOOKS=(
    "ClaimRFLRHook"
    "ClaimRFLV2Hook"         # <-- NEW
    "WithdrawRFLRHook"
    "WithdrawVestedRFLRHook"
)
```

### 7. `script/run/verify_v2_staging_prod.sh`

**Changes**: Add `ClaimRFLV2Hook` in two places:

**(a)** Around line 448, add a case for the constructor args verification:
```bash
"ClaimRFLV2Hook")
    constructor_args=$(cast abi-encode "constructor(address)" "$RNAT")
    ;;
```

**(b)** Around line 796, add the source file mapping:
```bash
"ClaimRFLV2Hook") echo "src/hooks/claim/flare/ClaimRFLV2Hook.sol" ;;
```

---

## Files to Create (Tests)

### 8. `test/unit/hooks/claim/rflr/ClaimRFLV2HookTest.t.sol`

**Test contract**: `ClaimRFLV2HookTest is Helpers`

**Setup**:
- Create `rNat = makeAddr("rNat")` and `account = makeAddr("account")`
- Deploy `hook = new ClaimRFLV2Hook(rNat)`
- No fork needed -- use `vm.mockCall()` for all external calls

**Test categories**:

#### Constructor Tests
- `test_Constructor()` -- verify hookType is NONACCOUNTING, RNAT is set correctly
- `test_Constructor_RevertIf_RNatZero()` -- revert with ADDRESS_NOT_VALID

#### Build Tests (core enumeration logic)

**`test_Build_SingleClaimableProject()`**:
- Mock `getProjectsCount()` returns 3
- Mock `getClaimableRewards(0, account)` returns 0
- Mock `getClaimableRewards(1, account)` returns 100e18
- Mock `getClaimableRewards(2, account)` returns 0
- Mock `getCurrentMonth()` returns 5
- Call `hook.build(address(0), account, "")` with EMPTY data
- Assert: executions.length == 3 (pre + claim + post)
- Assert: executions[1].target == rNat
- Assert: executions[1].callData == abi.encodeCall(IRNat.claimRewards, ([1], 5))

**`test_Build_MultipleClaimableProjects()`**:
- Mock 5 projects, 3 with claimable rewards (indices 0, 2, 4)
- Verify the claim calldata contains exactly `[0, 2, 4]` as projectIds

**`test_Build_AllProjectsClaimable()`**:
- Mock 3 projects, all with claimable rewards
- Verify all 3 project IDs are included

**`test_Build_RevertIf_NoClaimableRewards()`**:
- Mock 3 projects, all with 0 claimable rewards
- Expect revert with `NO_CLAIMABLE_REWARDS()`

**`test_Build_RevertIf_ZeroProjects()`**:
- Mock `getProjectsCount()` returns 0
- Expect revert with `NO_CLAIMABLE_REWARDS()`

**`test_Build_RevertIf_TooManyProjects()`**:
- Mock `getProjectsCount()` returns 51 (> MAX_PROJECT_IDS)
- Expect revert with `TOO_MANY_PROJECTS()`

**`test_Build_EmptyDataAccepted()`**:
- Verify the hook works when called with empty bytes `""` as data

**`test_Build_NonEmptyDataIgnored()`**:
- Verify the hook works the same when called with arbitrary non-empty data (data is ignored)

**`test_Build_ExactlyMaxProjects()`**:
- Mock exactly 50 projects with some claimable
- Verify it works (boundary condition)

#### Pre/Post Execute Tests
- `test_PreAndPostExecute()` -- same pattern as ClaimRFLRHookTest, mock balanceOf before/after
- `test_PreExecute_SetsAsset()` -- verify `asset == RNAT` after preExecute
- `test_PostExecute_ZeroDeltaWhenBalanceDecreases()` -- verify delta is 0 when balance drops

#### Inspect Tests
- `test_Inspector_ReturnsRNat()` -- verify returns `abi.encodePacked(rNat)` (addresses only)

**Mocking pattern for getProjectsCount/getClaimableRewards/getCurrentMonth**:

```solidity
function _mockProjectsCount(uint256 count) internal {
    vm.mockCall(rNat, abi.encodeCall(IRNat.getProjectsCount, ()), abi.encode(count));
}

function _mockClaimableRewards(uint256 projectId, address owner, uint128 amount) internal {
    vm.mockCall(rNat, abi.encodeCall(IRNat.getClaimableRewards, (projectId, owner)), abi.encode(amount));
}

function _mockCurrentMonth(uint256 month) internal {
    vm.mockCall(rNat, abi.encodeCall(IRNat.getCurrentMonth, ()), abi.encode(month));
}
```

---

## Security Considerations

### 1. Gas Bounds Safety
The `MAX_PROJECT_IDS = 50` constant prevents unbounded iteration. The hook reverts with `TOO_MANY_PROJECTS()` if `getProjectsCount()` exceeds this. This is a safety bound -- the real Flare RNat contract currently has far fewer projects. If projects ever exceed 50, the constant would need to be updated in a new deployment.

### 2. State Consistency Between build() and Execution
Since `build()` is a view call and the actual `claimRewards` is executed later in a UserOp, the set of claimable projects could change between discovery and execution. This is **acceptable and safe** because:
- `claimRewards` will simply claim 0 for projects that no longer have rewards (it does not revert)
- If new projects become claimable between build() and execution, they are missed but can be claimed next time
- This is the same pattern used by `WithdrawVestedRFLRHook` which reads `getBalancesOf()` in `_buildHookExecutions`

### 3. Inspector Compliance
The `inspect()` function returns ONLY addresses (`abi.encodePacked(RNAT)`) -- no amounts or other data types. This is a protocol requirement.

### 4. No Reentrancy Risk
- `_buildHookExecutions` is `view` -- no state changes
- `_preExecute` and `_postExecute` are protected by BaseHook's mutex pattern
- The single `claimRewards` execution targets only the trusted RNAT contract (immutable)

### 5. Empty Data Safety
The hook completely ignores the `data` parameter. There is no parsing, no length checks, and no validation of data content. This is intentional -- the hook is parameterless. Empty bytes `""` is the expected input but any data is safely ignored.

---

## Implementation Order

1. **Modify `src/vendor/flare/IRNat.sol`** -- add `getProjectsCount()` function
2. **Create `src/hooks/claim/flare/ClaimRFLV2Hook.sol`** -- the hook contract
3. **Create `test/unit/hooks/claim/rflr/ClaimRFLV2HookTest.t.sol`** -- unit tests
4. **Run tests**: `make forge-test TEST=ClaimRFLV2HookTest`
5. **Modify deployment scripts** (ConstantsOtherHooks.sol, DeployV2OtherHooks.s.sol, regenerate_bytecode.sh, deploy_v2_other_hooks_staging_prod.sh, verify_v2_staging_prod.sh)
6. **Run full build**: `forge build`

---

## Important Notes

### Why Not Optimize to Single Pass?
A single-pass approach could allocate `projectCount`-length array and use assembly to shrink it. However:
- Gas is negligible on Flare (extremely cheap L1)
- Two-pass is cleaner, easier to audit, and follows Solidity conventions
- The loop runs at most 50 iterations (MAX_PROJECT_IDS)

### Why NONACCOUNTING and Not OUTFLOW?
rFLR is non-transferable. Claiming it does not create a tradeable asset that needs accounting treatment. Fees are collected later when rFLR is withdrawn as WFLR (via WithdrawRFLRHook/WithdrawVestedRFLRHook which are also NONACCOUNTING). This matches the existing ClaimRFLRHook design.

### Why No decodeAmount/replaceCalldataAmount?
These interfaces are for hooks where the bundler needs to inspect/modify amount values in hook calldata. Since this hook is:
1. NONACCOUNTING (not INFLOW/OUTFLOW in the accounting sense)
2. Parameterless (no amount in calldata to inspect or replace)

...these interfaces are not applicable. This is consistent with the existing ClaimRFLRHook which also omits them.

### Branch Requirement
All work must be on the `pre-dev` branch per codebase rules. Check current branch before starting and alert if not on `pre-dev`.

### Return Type of getProjectsCount()
The RNat contract's `getProjectsCount()` returns `uint256`. This has been confirmed against the Flare RNat contract ABI. If in doubt, verify with:
```bash
cast call 0x26d460c3Cf931Fb2014FA436a49e3Af08619810e "getProjectsCount()(uint256)" --rpc-url $FLARE_RPC_URL
```
