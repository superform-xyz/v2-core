# rFLR Claiming Hook -- Repository Analysis

## Date: 2026-05-14

## 1. Existing Claim Hook Implementations

### 1.1 BaseClaimRewardHook (`/src/hooks/claim/BaseClaimRewardHook.sol`)

An abstract helper used by Fluid, Gearbox, and Yearn claim hooks. Provides two utilities:

```solidity
function _build(address yieldSource, bytes memory encoded) internal pure returns (Execution[] memory executions) {
    executions = new Execution[](1);
    executions[0] = Execution({ target: yieldSource, value: 0, callData: encoded });
}

function _getBalance(bytes memory data, address account) internal view returns (uint256) {
    address rewardToken = BytesLib.toAddress(data, 52);
    if (rewardToken == address(0)) revert REWARD_TOKEN_ZERO_ADDRESS();
    return IERC20(rewardToken).balanceOf(account);
}
```

Key detail: `_getBalance` assumes the reward token address is at byte offset 52 in the hook data (after 32-byte placeholder + 20-byte yield source). This is specific to the Fluid/Gearbox/Yearn data layout and is NOT universally usable. The rFLR hooks should NOT inherit from BaseClaimRewardHook because their data layout differs.

### 1.2 MerklClaimRewardHook (`/src/hooks/claim/merkl/MerklClaimRewardHook.sol`)

**Most relevant reference** -- the only NONACCOUNTING claim hook in the codebase.

**Key characteristics:**
- HookType: `NONACCOUNTING`
- HookSubType: `HookSubTypes.CLAIM`
- Has constructor arg: `address distributor_` (stored as immutable `DISTRIBUTOR`)
- Does NOT inherit BaseClaimRewardHook (it has its own data layout)
- Handles fee deduction natively (feeReceiver, feeBPS parameters in data)
- Builds multiple Execution objects: 1 claim + N fee transfers

**Constructor pattern:**
```solidity
constructor(address distributor_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.CLAIM) {
    if (distributor_ == address(0)) revert ADDRESS_NOT_VALID();
    DISTRIBUTOR = distributor_;
}
```

**_preExecute / _postExecute for NONACCOUNTING:**
```solidity
function _preExecute(address, address account, bytes calldata) internal override {
    _setOutAmount(0, account);
}

function _postExecute(address, address account, bytes calldata) internal override {
    _setOutAmount(0, account);
}
```

This is the simplest pattern -- for a pure NONACCOUNTING hook that has NO downstream chaining, both pre and post set outAmount to 0.

**Data encoding (variable-length arrays via BytesLib):**
```
offset 0:  address feeReceiver        (20 bytes)
offset 20: uint256 feePercent         (32 bytes)
offset 52: uint256 arraysLength       (32 bytes)
offset 84: address[] tokens           (arraysLength * 20 bytes, tightly packed)
           uint256[] amounts          (arraysLength * 32 bytes, tightly packed)
           bytes32[][] proofs         (variable length, each inner array prefixed with its length)
```

**Fee handling pattern:**
- BPS = 10_000 (basis points)
- MAX_FEE_PERCENT = 5000 (50% cap)
- Fee calculated as: `fee = (claimableAmount * feePercent) / BPS`
- Fee transfers built as separate Execution objects via `IERC20.transfer(feeReceiver, fee)`

**inspect() pattern:**
```solidity
function inspect(bytes calldata data) external pure override returns (bytes memory) {
    (address feeReceiver,) = _decodeFeeParams(data);
    return abi.encodePacked(feeReceiver);
}
```

### 1.3 FluidClaimRewardHook / GearboxClaimRewardHook / YearnClaimOneRewardHook

These are OUTFLOW hooks (not NONACCOUNTING) that inherit BaseClaimRewardHook. They use a different pattern with balance snapshots:

**Data layout (all three share the same):**
```
offset 0:  bytes32 placeholder (yieldSourceOracleId)
offset 32: address yieldSource/stakingRewards/farmingPool
offset 52: address rewardToken
offset 72: address account
```

**_preExecute (balance snapshot before):**
```solidity
function _preExecute(address, address account, bytes calldata data) internal override {
    asset = BytesLib.toAddress(data, 52);
    if (asset == address(0)) revert ASSET_ZERO_ADDRESS();
    _setOutAmount(_getBalance(data, account), account);
}
```

**_postExecute (delta = new balance - old balance):**
```solidity
function _postExecute(address, address account, bytes calldata data) internal override {
    _setOutAmount(_getBalance(data, account) - getOutAmount(account), account);
}
```

These set outAmount to the actual claimed amount (newBalance - oldBalance). This is important for downstream hooks that chain amounts.

## 2. NONACCOUNTING Hook Patterns

### 2.1 Overview of NONACCOUNTING _preExecute/_postExecute Patterns

| Hook | _preExecute | _postExecute |
|------|-------------|--------------|
| MerklClaimRewardHook | `_setOutAmount(0, account)` | `_setOutAmount(0, account)` |
| TransferERC20Hook | `_setOutAmount(tokenBalance, account)` | `_setOutAmount(newBalance - oldBalance, account)` |
| ApproveERC20Hook | (no-op) | `_setOutAmount(allowance, account)` |
| MarkRootAsUsedHook | (no-op, uses base default) | (no-op, uses base default) |
| DepositWETHHook | `_setOutAmount(ethBalance, account)` | `_setOutAmount(prevBalance - currentBalance, account)` |
| WithdrawWETHHook | `_setOutAmount(wethBalance, account)` | `_setOutAmount(prevWethBalance - currentWethBalance, account)` |
| RedeemFirelightVaultHook | `usedShares = shareBalance` | `usedShares = prevShares - newShares` |

**Decision for rFLR hooks:** Since ClaimRFLRHook should report the actual claimed amount (for potential downstream fee transfer or chaining), use the balance snapshot pattern:
- _preExecute: snapshot the reward token balance
- _postExecute: set outAmount to delta (newBalance - oldBalance)

For WithdrawRFLRHook, same pattern but tracking WFLR balance.

### 2.2 Hooks that Handle Fee Deduction Inline

MerklClaimRewardHook handles fees inline -- building ERC20.transfer executions for fee deduction. This is the reference pattern for ClaimRFLRHook's fee handling.

**Fee parameters at the start of data:**
```
offset 0:  address feeReceiver   (20 bytes)
offset 20: uint256 feeBPS        (32 bytes)
```

This is a well-established pattern. The rFLR ClaimRFLRHook should follow the same approach.

## 3. Hook Data Encoding Patterns

### 3.1 Standard Layout (Fluid/Gearbox/Yearn -- OUTFLOW hooks)

```
bytes32 yieldSourceOracleId | address yieldSource | address rewardToken | address account
offset: 0                    | 32                   | 52                   | 72
```

Extracted via `HookDataDecoder.extractYieldSource()` at offset 32.

### 3.2 MerklClaimRewardHook Layout (NONACCOUNTING with fees)

```
address feeReceiver | uint256 feePercent | uint256 arraysLength | address[] tokens | uint256[] amounts | proofs
offset: 0            | 20                  | 52                    | 84               | 84 + N*20          | variable
```

Does NOT use the standard HookDataDecoder prefix (no bytes32 placeholder at offset 0).

### 3.3 Encoding Variable-Length Arrays

The codebase uses BytesLib for tightly-packed encoding (NOT abi.encode):

**Encoding (from test/utils/InternalHelpers.sol):**
```solidity
// Tightly packed addresses (20 bytes each, no padding)
for (uint256 i = 0; i < tokens.length; i++) {
    data = bytes.concat(data, bytes20(tokens[i]));
}

// Tightly packed uint256 (32 bytes each)
for (uint256 i = 0; i < amounts.length; i++) {
    data = bytes.concat(data, abi.encodePacked(amounts[i]));
}
```

**Decoding (from MerklClaimRewardHook):**
```solidity
uint256 arrayLength = BytesLib.toUint256(data, 52);
cursor = 84;

tokens = new address[](arrayLength);
for (uint256 i; i < arrayLength; i++) {
    address token = BytesLib.toAddress(data, cursor);
    cursor += 20;
    tokens[i] = token;
}
```

**For rFLR ClaimRFLRHook (uint256[] projectIds + uint256 month):**

Proposed data layout:
```
address feeReceiver     (20 bytes, offset 0)
uint256 feeBPS          (32 bytes, offset 20)
address rNat            (20 bytes, offset 52)
address rewardToken     (20 bytes, offset 72)
uint256 month           (32 bytes, offset 92)
uint256 projectIdsLen   (32 bytes, offset 124)
uint256[] projectIds    (projectIdsLen * 32 bytes, offset 156)
```

This follows the same tightly-packed pattern as Merkl but simpler (no nested arrays like proofs).

## 4. Deployment Patterns for Chain-Specific Hooks

### 4.1 DeployV2OtherHooks Architecture

File: `/script/DeployV2OtherHooks.s.sol`

All non-core hooks (Morpho, Aave V4, Firelight, Algebra Integral, DETH) are deployed via this script. Each hook family has:

1. **A struct for addresses:** e.g., `struct FirelightHookAddresses { address redeemFirelightVaultHook; ... }`
2. **A deploy function:** e.g., `_deployFirelightHooks(uint64 chainId, uint256 env)`
3. **An entry point:** e.g., `function runFirelight(uint256 env, uint64 chainId)`
4. **Chain-gating in _deployAllHooks:** e.g., `if (chainId == FLARE_CHAIN_ID) { _deployFirelightHooks(...); }`

### 4.2 Firelight Hooks (Flare chain 14) -- Closest Precedent

Firelight hooks are the only existing Flare-specific hooks. They have NO constructor args:

```solidity
hooks[0] = HookDeployment(
    REDEEM_FIRELIGHT_VAULT_HOOK_KEY,
    "",
    __getOtherHooksBytecode("RedeemFirelightVaultHook", env)
);
```

Since rFLR hooks need an `rNat` immutable address, they will need constructor args similar to MerklClaimRewardHook's `distributor_` or AlgebraIntegral's `swapRouter`:

```solidity
bytes memory rNatArg = abi.encode(RNAT_ADDRESS_FLARE);
hooks[0] = HookDeployment(
    CLAIM_RFLR_HOOK_KEY,
    "",
    abi.encodePacked(__getOtherHooksBytecode("ClaimRFLRHook", env), rNatArg)
);
```

### 4.3 Files to Modify for Deployment

Based on precedent from DETH hooks deployment:

| File | Change |
|------|--------|
| `script/utils/Constants.sol` | Add `CLAIM_RFLR_HOOK_KEY`, `WITHDRAW_RFLR_HOOK_KEY` |
| `script/utils/ConstantsOtherHooks.sol` | Add rFLR hook keys and rNat address constant |
| `script/utils/ConfigOtherHooks.sol` | Add rNat address to `OtherHooksData` if needed |
| `script/DeployV2OtherHooks.s.sol` | Add `RFLRHookAddresses` struct, `_deployRFLRHooks()`, `runRFLR()`, chain-gate on `FLARE_CHAIN_ID` |
| `script/run/regenerate_bytecode.sh` | Add `RFLR_HOOK_CONTRACTS` array |
| `script/run/deploy_v2_other_hooks_staging_prod.sh` | Add rFLR section with `RFLR_SUPPORTED_CHAINS=("14")` |

### 4.4 Chain ID Constant

Already defined: `uint64 internal constant FLARE_CHAIN_ID = 14;` in `/script/utils/Constants.sol` line 63.

## 5. Test Patterns for Claim Hooks

### 5.1 Test File Organization

Tests live at `test/unit/hooks/claim/<protocol>/` e.g.:
- `test/unit/hooks/claim/fluid/FluidClaimRewardHook.t.sol`
- `test/unit/hooks/claim/merkl/MerklClaimRewardsHook.t.sol`
- `test/unit/hooks/claim/yearn/YearnClaimRewardHook.t.sol`

For rFLR: `test/unit/hooks/claim/rflr/ClaimRFLRHook.t.sol` and `test/unit/hooks/claim/rflr/WithdrawRFLRHook.t.sol`

### 5.2 Standard Test Categories

From analyzing all claim hook tests:

1. **Constructor test:** Verify hookType and subType
   ```solidity
   function test_Constructor() public view {
       assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
   }
   ```

2. **Build test:** Verify correct Execution array structure
   ```solidity
   function test_Build() public view {
       Execution[] memory executions = hook.build(address(0), account, data);
       assertEq(executions.length, 3); // preExecute + hook + postExecute
       assertEq(executions[1].target, expectedTarget);
   }
   ```

3. **Build revert tests:** Invalid addresses, zero amounts
   ```solidity
   function test_Build_RevertIf_AddressZero() public {
       vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
       hook.build(address(0), address(0), invalidData);
   }
   ```

4. **PreExecute/PostExecute tests:** Balance snapshots
   ```solidity
   function test_PreAndPostExecute() public {
       _getTokens(rewardToken, account, amount);
       vm.prank(account);
       hook.preExecute(address(0), account, data);
       assertEq(hook.getOutAmount(address(this)), amount);

       vm.prank(account);
       hook.postExecute(address(0), account, data);
       assertEq(hook.getOutAmount(address(this)), 0);
   }
   ```

5. **Inspector test:** Verify inspect() output
   ```solidity
   function test_Inspector() public view {
       bytes memory argsEncoded = hook.inspect(data);
       assertEq(BytesLib.toAddress(argsEncoded, 0), expectedAddress);
   }
   ```

6. **Calldata decoding test:** Verify BytesLib decoding
7. **Fee validation tests (MerklClaimRewardHook):** Invalid fee percent, zero fee receiver

### 5.3 Test Base Classes

- Simple hooks: Extend `Helpers` only (no BaseTest)
- Complex hooks: Extend `Helpers, InternalHelpers, BaseTest`
- Use `MockERC20` for reward tokens
- Use `makeAddr("name")` for test addresses
- Use `deal(token, to, amount)` via `_getTokens(token, to, amount)` for token minting
- Use `vm.mockCall(...)` for external contract mocking
- Use `vm.prank(account)` for preExecute/postExecute caller simulation

### 5.4 Data Encoding Helpers

Tests use internal helper functions for data encoding:

```solidity
function _encodeData() internal view returns (bytes memory) {
    return abi.encodePacked(bytes32(0), stakingRewards, rewardToken, account);
}
```

For MerklClaimRewardHook, a more complex helper in InternalHelpers.sol:

```solidity
function _createMerklClaimRewardHookData(
    address feeReceiver,
    uint256 feePercent,
    address[] memory tokens,
    uint256[] memory amounts,
    bytes32[][] memory proofs
) internal pure returns (bytes memory data) {
    data = bytes.concat(bytes20(feeReceiver), abi.encodePacked(feePercent));
    data = bytes.concat(data, abi.encodePacked(uint256(tokens.length)));
    // ... tightly packed arrays
}
```

## 6. inspect() Implementation Patterns for NONACCOUNTING Hooks

### 6.1 Purpose

`inspect()` returns a packed encoding of the "interesting" addresses/parameters for off-chain systems to parse. It is a `pure` or `view` function.

### 6.2 Patterns by Hook Type

| Hook | inspect() Returns |
|------|-------------------|
| MerklClaimRewardHook | `abi.encodePacked(feeReceiver)` -- just the fee receiver |
| FluidClaimRewardHook | `abi.encodePacked(yieldSource, rewardToken)` |
| GearboxClaimRewardHook | `abi.encodePacked(yieldSource, rewardToken)` |
| YearnClaimOneRewardHook | `abi.encodePacked(yieldSource, rewardToken)` |
| TransferERC20Hook | `abi.encodePacked(token, to)` |
| ApproveERC20Hook | `abi.encodePacked(token, spender)` |
| MarkRootAsUsedHook | `abi.encodePacked(destinationExecutor)` |
| DepositWETHHook | `abi.encodePacked(WETH)` |
| WithdrawWETHHook | `abi.encodePacked(WETH)` |
| RedeemFirelightVaultHook | `abi.encodePacked(yieldSource)` |
| ClaimWithdrawFirelightVaultHook | `abi.encodePacked(yieldSource)` |

**Pattern:** Return the key external addresses the hook will interact with. For rFLR:
- ClaimRFLRHook: `abi.encodePacked(feeReceiver, rNat)` or just `abi.encodePacked(feeReceiver)`
- WithdrawRFLRHook: `abi.encodePacked(rNat)` (the rNat is immutable)

## 7. HookSubTypes for Claim/Reward Hooks

File: `/src/libraries/HookSubTypes.sol`

```solidity
bytes32 public constant CLAIM = keccak256(bytes("Claim"));
```

Both MerklClaimRewardHook (NONACCOUNTING) and Fluid/Gearbox/Yearn (OUTFLOW) claim hooks use `HookSubTypes.CLAIM`.

**For rFLR hooks:** Use `HookSubTypes.CLAIM` for both ClaimRFLRHook and WithdrawRFLRHook, consistent with all other claim hooks.

## 8. Vendor Interface Organization

### 8.1 Directory Structure

Vendor interfaces live at `src/vendor/<protocol>/` or `src/vendor/vaults/<protocol>/`:

```
src/vendor/
  merkl/IDistributor.sol
  fluid/IFluidLendingStakingRewards.sol
  gearbox/IGearboxFarmingPool.sol
  yearn/IYearnStakingRewardsMulti.sol
  vaults/firelight/IFirelightVault.sol
  vaults/deth/IDETHAsyncRedeemer.sol
  vaults/deth/IMachine.sol
```

**For rFLR:** Create `src/vendor/flare/IRNat.sol` with the minimal interface:

```solidity
interface IRNat {
    function claimRewards(uint256[] calldata projectIds, uint256 month) external returns (uint256 claimedAmount);
    function withdrawAll(bool wrap) external returns (uint256 withdrawnAmount);
    // ... any other functions needed
}
```

### 8.2 Interface Style

All vendor interfaces follow the same style:
- SPDX license header
- Pragma solidity 0.8.30
- Minimal interface (only functions the hooks actually call)
- NatSpec comments for each function
- No implementation details

## 9. Additional Patterns and Conventions

### 9.1 Solidity Version

All contracts use: `pragma solidity 0.8.30;`

### 9.2 License

Hook contracts: `// SPDX-License-Identifier: Apache-2.0`
Vendor interfaces: `// SPDX-License-Identifier: Apache-2.0` or `// SPDX-License-Identifier: MIT`

### 9.3 Import Style

```solidity
// external
import { BytesLib } from "../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { HookSubTypes } from "../../libraries/HookSubTypes.sol";
import { ISuperHookInspector } from "../../interfaces/ISuperHook.sol";
```

### 9.4 Constructor Arg Pattern for Protocol-Specific Addresses

Two patterns exist:

**Pattern A: Immutable constructor arg** (MerklClaimRewardHook, DepositWETHHook, WithdrawWETHHook, AlgebraIntegral hooks)
```solidity
address public immutable DISTRIBUTOR;
constructor(address distributor_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.CLAIM) {
    if (distributor_ == address(0)) revert ADDRESS_NOT_VALID();
    DISTRIBUTOR = distributor_;
}
```

**Pattern B: No constructor args, address in calldata** (Fluid, Gearbox, Yearn, Firelight, DETH hooks)
```solidity
constructor() BaseHook(HookType.OUTFLOW, HookSubTypes.CLAIM) { }
// Address extracted from calldata: data.extractYieldSource()
```

**For rFLR hooks:** Pattern A is better since rNat is a fixed protocol address on Flare, similar to how DISTRIBUTOR is fixed for Merkl. This avoids requiring the bundler to pass it every time.

### 9.5 Error Conventions

Custom errors defined in BaseHook:
- `AMOUNT_NOT_VALID()`
- `ADDRESS_NOT_VALID()`
- `UNAUTHORIZED_CALLER()`

Custom errors in specific hooks:
- `FEE_NOT_VALID()` (MerklClaimRewardHook)
- `ASSET_ZERO_ADDRESS()` (BaseClaimRewardHook)
- `INVALID_REWARD_TOKEN()` (BaseClaimRewardHook)
- `ZERO_ETH_AMOUNT()` (DepositWETHHook)
- `INSUFFICIENT_WETH_BALANCE()` (WithdrawWETHHook)

### 9.6 NatSpec Documentation

All hooks document their data layout in NatSpec:
```solidity
/// @title ClaimRFLRHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address feeReceiver = BytesLib.toAddress(data, 0);
/// @notice         uint256 feeBPS = BytesLib.toUint256(data, 20);
/// ...
```

### 9.7 Section Headers

All hooks use the standard section headers:
```solidity
/*//////////////////////////////////////////////////////////////
                            STORAGE
//////////////////////////////////////////////////////////////*/

/*//////////////////////////////////////////////////////////////
                         VIEW METHODS
//////////////////////////////////////////////////////////////*/

/*//////////////////////////////////////////////////////////////
                        EXTERNAL METHODS
//////////////////////////////////////////////////////////////*/

/*//////////////////////////////////////////////////////////////
                        INTERNAL METHODS
//////////////////////////////////////////////////////////////*/

/*//////////////////////////////////////////////////////////////
                         PRIVATE METHODS
//////////////////////////////////////////////////////////////*/
```

## 10. Summary: Implementation Blueprint for rFLR Hooks

### ClaimRFLRHook

| Aspect | Value |
|--------|-------|
| HookType | `NONACCOUNTING` |
| HookSubType | `HookSubTypes.CLAIM` |
| Constructor args | `address rNat_` (immutable `RNAT`) |
| Data layout | `feeReceiver(20) + feeBPS(32) + rewardToken(20) + month(32) + projectIdsLen(32) + projectIds[](N*32)` |
| Interfaces inherited | `BaseHook` only (possibly `ISuperHookContextAware` if chaining needed) |
| _preExecute | Snapshot `IERC20(rewardToken).balanceOf(account)` |
| _postExecute | Set outAmount to delta; transfer fee via separate Execution |
| inspect() | `abi.encodePacked(feeReceiver)` |
| Fee logic | In `_buildHookExecutions`: calculate `fee = delta * feeBPS / 10000`, add `IERC20.transfer(feeReceiver, fee)` Execution |
| Reference | MerklClaimRewardHook for fee pattern + FluidClaimRewardHook for balance snapshot |

### WithdrawRFLRHook

| Aspect | Value |
|--------|-------|
| HookType | `NONACCOUNTING` |
| HookSubType | `HookSubTypes.CLAIM` |
| Constructor args | `address rNat_` (immutable `RNAT`) |
| Data layout | Minimal: just enough for the hook to call `IRNat.withdrawAll(true)` |
| Interfaces inherited | `BaseHook` only |
| _preExecute | Snapshot WFLR balance |
| _postExecute | Set outAmount to WFLR delta |
| inspect() | `abi.encodePacked(RNAT)` |
| Reference | WithdrawWETHHook for balance-tracking pattern |

### Vendor Interface

Create `/src/vendor/flare/IRNat.sol` with:
```solidity
interface IRNat {
    function claimRewards(uint256[] calldata projectIds, uint256 month) external returns (uint256);
    function withdrawAll(bool wrap) external returns (uint256);
}
```

### Test Files

- `/test/unit/hooks/claim/rflr/ClaimRFLRHook.t.sol`
- `/test/unit/hooks/claim/rflr/WithdrawRFLRHook.t.sol`

### Deployment Files

- Constants: `CLAIM_RFLR_HOOK_KEY`, `WITHDRAW_RFLR_HOOK_KEY` in Constants.sol or ConstantsOtherHooks.sol
- Add `RNAT_ADDRESS_FLARE` constant to ConstantsOtherHooks.sol
- Add `RFLRHookAddresses` struct and `_deployRFLRHooks()` to DeployV2OtherHooks.s.sol
- Chain-gate on `FLARE_CHAIN_ID` in `_deployAllHooks()`
- Add `runRFLR(uint256 env, uint64 chainId)` entry point
- Add to `regenerate_bytecode.sh` and `deploy_v2_other_hooks_staging_prod.sh`

## 11. Key File Paths Referenced

### Hook Implementations
- `/src/hooks/BaseHook.sol` -- Base hook contract with transient storage, mutex, lifecycle
- `/src/hooks/claim/BaseClaimRewardHook.sol` -- Abstract helper for Fluid/Gearbox/Yearn (do NOT use for rFLR)
- `/src/hooks/claim/merkl/MerklClaimRewardHook.sol` -- Primary reference: NONACCOUNTING + fees + variable arrays
- `/src/hooks/claim/fluid/FluidClaimRewardHook.sol` -- OUTFLOW claim with balance snapshot
- `/src/hooks/claim/gearbox/GearboxClaimRewardHook.sol` -- OUTFLOW claim with balance snapshot
- `/src/hooks/claim/yearn/YearnClaimOneRewardHook.sol` -- OUTFLOW claim with balance snapshot
- `/src/hooks/tokens/weth/WithdrawWETHHook.sol` -- NONACCOUNTING with balance tracking
- `/src/hooks/tokens/weth/DepositWETHHook.sol` -- NONACCOUNTING with balance tracking
- `/src/hooks/tokens/erc20/TransferERC20Hook.sol` -- NONACCOUNTING with balance delta
- `/src/hooks/vaults/firelight/RedeemFirelightVaultHook.sol` -- Flare-specific NONACCOUNTING hook
- `/src/hooks/vaults/firelight/ClaimWithdrawFirelightVaultHook.sol` -- Flare-specific OUTFLOW hook

### Interfaces and Libraries
- `/src/interfaces/ISuperHook.sol` -- All hook interfaces (ISuperHook, ISuperHookResult, etc.)
- `/src/libraries/HookSubTypes.sol` -- Hook subtype constants (CLAIM, TOKEN, etc.)
- `/src/libraries/HookDataDecoder.sol` -- Standard data decoding (extractYieldSource at offset 32)
- `/src/vendor/BytesLib.sol` -- Byte manipulation library

### Vendor Interfaces (Examples)
- `/src/vendor/merkl/IDistributor.sol` -- Merkl distributor interface
- `/src/vendor/fluid/IFluidLendingStakingRewards.sol` -- Fluid staking interface
- `/src/vendor/vaults/firelight/IFirelightVault.sol` -- Firelight vault interface
- `/src/vendor/vaults/deth/IMachine.sol` -- DETH Machine interface

### Deployment Scripts
- `/script/DeployV2OtherHooks.s.sol` -- Main deployment script for non-core hooks
- `/script/utils/Constants.sol` -- Chain IDs, hook keys, protocol addresses
- `/script/utils/ConstantsOtherHooks.sol` -- Protocol-specific constants for other hooks
- `/script/utils/ConfigOtherHooks.sol` -- Per-chain protocol config for other hooks
- `/script/run/regenerate_bytecode.sh` -- Bytecode generation for deterministic deploys
- `/script/run/deploy_v2_other_hooks_staging_prod.sh` -- Shell script for multi-chain deployment

### Test Files
- `/test/unit/hooks/claim/merkl/MerklClaimRewardsHook.t.sol` -- Primary test reference
- `/test/unit/hooks/claim/fluid/FluidClaimRewardHook.t.sol` -- Simple claim hook test
- `/test/unit/hooks/claim/yearn/YearnClaimRewardHook.t.sol` -- Simple claim hook test
- `/test/unit/hooks/claim/BaseClaimRewardHook.t.sol` -- Base helper test
- `/test/utils/Helpers.sol` -- Test utilities (_getTokens, approveErc20, etc.)
- `/test/utils/InternalHelpers.sol` -- Data encoding helpers for tests
- `/test/BaseTest.t.sol` -- Base test class
