# Best Practices: Flare rFLR (RNat) Reward System Integration

## Research Date: 2026-05-14

## Table of Contents

1. [Flare rFLR / RNat System Overview](#1-flare-rflr--rnat-system-overview)
2. [IRNat Contract Interface Analysis](#2-irnat-contract-interface-analysis)
3. [ClaimRFLRHook Design Recommendations](#3-claimrflrhook-design-recommendations)
4. [WithdrawRFLRHook Design Recommendations](#4-withdrawrflrhook-design-recommendations)
5. [Security Considerations](#5-security-considerations)
6. [Gas Optimization](#6-gas-optimization)
7. [Superform Hook Pattern Compliance](#7-superform-hook-pattern-compliance)
8. [Known Issues and Edge Cases](#8-known-issues-and-edge-cases)
9. [Contract Addresses and Resolution](#9-contract-addresses-and-resolution)
10. [Sources](#10-sources)

---

## 1. Flare rFLR / RNat System Overview

### What is rFLR?

rFLR is Flare's reward token used to incentivize participation in governance and ecosystem
activity. It is distributed monthly to participating dApps, which then distribute it to eligible
users. rFLR tokens represent vested rewards backed by wrapped FLR (WFLR) in dedicated RNat
accounts.

Source: [Flare official guide to rFLR rewards](https://flare.network/news/a-guide-to-rflr-rewards)

### Architecture

The rFLR system has three core components:

1. **RNat Contract** -- The main entry point. Manages project registration, reward distribution,
   claiming, and withdrawal. Each user gets a unique RNat account (a separate contract) created
   on first interaction.

2. **RNat Account** -- A per-user contract that holds the user's WFLR (vested rewards). Created
   by the RNat contract. Tracks `receivedRewards` and `withdrawnRewards`.

3. **WNat (WFLR)** -- The wrapped native token on Flare. Standard ERC-20 wrapper with
   `deposit()` (payable), `withdraw(uint256)`, `depositTo(address)`, and
   `withdrawFrom(address, uint256)`.

### Reward Lifecycle

```
1. Rewards are assigned to projects by Flare governance
2. Project distributors allocate rewards to recipients for specific months
3. Users call claimRewards() on the RNat contract
   - Claimed rewards are deposited as WFLR into the user's RNat account
   - rFLR tokens are minted to the user (1:1 with claimed WFLR)
4. Rewards vest linearly over 12 months (1/12 per month)
5. Users can withdraw:
   a. Vested (unlocked) portion: full amount as WFLR or native FLR
   b. Locked (unvested) portion: 50% penalty -- half is burned
6. withdrawAll(wrap=true) returns WFLR; withdrawAll(wrap=false) returns native FLR
```

### Vesting Mechanics

- Each monthly allocation vests linearly over 12 months from the month it was claimed.
- At any point, the user's balance has a **locked** and **unlocked** portion.
- `getBalancesOf(owner)` returns `(wNatBalance, rNatBalance, lockedBalance)`.
- Unlocked = wNatBalance - lockedBalance.
- The locked amount may include compounded FlareDrop rewards earned by the vested WFLR.

Source: [Flare on X -- Understanding rFLR](https://x.com/FlareNetworks/status/1832012890905211168)

---

## 2. IRNat Contract Interface Analysis

The IRNat interface is available in the
[flare-foundry-periphery-package](https://github.com/flare-foundation/flare-foundry-periphery-package)
under `src/flare/IRNat.sol`.

### Key Functions for Hook Integration

#### `claimRewards(uint256[] calldata _projectIds, uint256 _month) returns (uint256)`

- Claims rewards across multiple projects up to the specified month (inclusive).
- Returns the total amount of WFLR claimed.
- Deposits claimed WFLR into the caller's RNat account.
- Mints rFLR tokens to the caller.
- Calling with an empty `_projectIds` array or a month with no unclaimed rewards is safe
  (returns 0).
- The `_month` parameter is inclusive -- it claims all unclaimed rewards up to and including
  that month.

#### `withdrawAll(bool _wrap) returns (uint256)`

- Withdraws ALL funds from the caller's RNat account.
- **Critical**: If any tokens are still locked (unvested), only 50% of the locked portion
  is withdrawn; the other 50% is burned as a penalty.
- When `_wrap = true`: Returns WFLR (ERC-20) to the caller.
- When `_wrap = false`: Returns native FLR to the caller.
- Returns the total amount withdrawn (after any penalty deduction).

#### `withdraw(uint128 _amount, bool _wrap)`

- Withdraws a specific amount of WFLR from the caller's RNat account.
- Same wrapping semantics as `withdrawAll`.
- If `_amount` exceeds the unlocked balance, the excess comes from the locked portion
  with the 50% penalty.

#### `getBalancesOf(address _owner) returns (uint256 wNatBalance, uint256 rNatBalance, uint256 lockedBalance)`

- Returns the WNat (WFLR) balance, rNat token balance, and locked (still-vesting) balance
  for the given owner.
- `unlockedBalance = wNatBalance - lockedBalance`
- `wNatBalance` can exceed `rNatBalance` if FlareDrop rewards have been claimed into the
  RNat account.

#### `getClaimableRewards(uint256[] _projectIds, address _owner, uint256 _month) returns (uint256)`

- View function to check how much can be claimed before actually claiming.
- Useful for off-chain pre-flight checks but not strictly needed in the hook itself.

#### `setClaimExecutors(address[] _executors) payable`

- Sets addresses authorized to claim on behalf of the caller.
- **Important for Superform**: If the smart account (user) needs to allow the Superform
  executor to claim on its behalf, this function must be called first.
- However, in the Superform hook model, the smart account itself executes the claim
  via delegatecall/call, so this may not be needed if the hook execution happens
  from the smart account context.

### IRNatAccount Interface

Each user has a dedicated RNat account contract with the following view functions:
- `owner()` -- Returns the account owner address
- `rNat()` -- Returns the RNat contract address
- `receivedRewards()` -- Total rewards received ever (historical)
- `withdrawnRewards()` -- Total rewards withdrawn ever (historical)

Events emitted by the account:
- `FundsWithdrawn(uint256 amount, bool wrap)`
- `LockedAmountBurned(uint256 amount)`

### IWNat (WFLR) Interface

```solidity
interface IWNat {
    function deposit() external payable;            // FLR -> WFLR
    function withdraw(uint256 _amount) external;    // WFLR -> FLR
    function depositTo(address _recipient) external payable;
    function withdrawFrom(address _owner, uint256 _amount) external;
}
```

WFLR contract address on Flare mainnet: `0x1D80c49BbBCd1C0911346656B529DF9E5c2F783d`

Source: [Flare Developer Hub FAQ](https://dev.flare.network/support/faqs),
[flare-foundry-periphery-package](https://github.com/flare-foundation/flare-foundry-periphery-package)

---

## 3. ClaimRFLRHook Design Recommendations

### Hook Type

- **HookType**: `NONACCOUNTING` or `OUTFLOW` with subtype `CLAIM`
- Rationale: Claiming rFLR rewards does not involve the smart account spending existing assets.
  The reward tokens (rFLR) are minted to the caller, and WFLR is deposited into the RNat
  account. The rFLR tokens end up in the smart account's balance.
- If the downstream flow needs to track rFLR as an outflow amount (e.g., for further operations),
  use `OUTFLOW`. If it is purely a side-effect operation, use `NONACCOUNTING`.
- **Recommendation**: Use `OUTFLOW` with subtype `CLAIM` to match the existing pattern from
  FluidClaimRewardHook, YearnClaimOneRewardHook, and GearboxClaimRewardHook.

### Data Layout

Following the Superform hook data convention (consistent with existing claim hooks):

```
Offset  Size    Field
0       32      bytes32 yieldSourceOracleId (placeholder / oracle ID)
32      20      address rNatContract (the RNat contract address)
52      20      address rewardToken (rFLR token address, i.e., the RNat contract itself since rFLR is the RNat token)
72      20      address account (the smart account address)
92      32      uint256 month (the month up to which to claim)
124     32      uint256 projectIdsLength (number of project IDs)
156     32*N    uint256[] projectIds (packed array of project IDs)
```

**Alternative simpler layout** (if rFLR token address is always the RNat contract):

```
Offset  Size    Field
0       32      bytes32 yieldSourceOracleId (placeholder)
32      20      address rNatContract
52      20      address rewardToken (rFLR / WFLR depending on what we track)
72      32      uint256 month
104     32      uint256 projectIdsLength
136     32*N    uint256[] projectIds
```

### Implementation Pattern

```solidity
function _buildHookExecutions(
    address,
    address,
    bytes calldata data
) internal pure override returns (Execution[] memory executions) {
    address rNatContract = data.extractYieldSource();
    if (rNatContract == address(0)) revert ADDRESS_NOT_VALID();

    // Decode month and project IDs from data
    uint256 month = BytesLib.toUint256(data, 72);
    uint256 projectIdsLength = BytesLib.toUint256(data, 104);
    uint256[] memory projectIds = new uint256[](projectIdsLength);
    for (uint256 i; i < projectIdsLength; ++i) {
        projectIds[i] = BytesLib.toUint256(data, 136 + i * 32);
    }

    executions = new Execution[](1);
    executions[0] = Execution({
        target: rNatContract,
        value: 0,
        callData: abi.encodeCall(IRNat.claimRewards, (projectIds, month))
    });
}
```

### Balance Tracking

- **preExecute**: Record the rFLR (RNat token) balance of the smart account before claim.
- **postExecute**: Record the new balance and compute the difference as `outAmount`.
- The `claimRewards` function returns the claimed amount, but since the hook executes via
  the smart account (not directly), we cannot capture the return value. Instead, use the
  balance-difference pattern (same as Fluid/Yearn/Gearbox hooks).

### Important Considerations

1. **rFLR token address**: rFLR IS the RNat token itself (the RNat contract is an ERC-20).
   Verify this assumption against the deployed contract.

2. **Month parameter**: Must be a valid month number. Use current month or allow the off-chain
   bundler to compute the optimal month.

3. **Project IDs**: Must correspond to active projects. Invalid project IDs will cause the
   claim to return 0 for those projects but not revert (based on SDK behavior).

4. **First-time claiming**: The first claim for an address creates an RNat account. This is
   a one-time extra gas cost.

---

## 4. WithdrawRFLRHook Design Recommendations

### Hook Type

- **HookType**: `OUTFLOW` with subtype `CLAIM` (or a new subtype if needed)
- Rationale: The withdrawal converts rFLR position into WFLR, which is a concrete outflow
  of value from the RNat system into the smart account.

### Data Layout

```
Offset  Size    Field
0       32      bytes32 yieldSourceOracleId (placeholder)
32      20      address rNatContract
52      20      address rewardToken (WFLR address -- the token received after withdrawal)
72      1       bool wrap (true = receive WFLR, false = receive native FLR)
```

### Implementation Pattern

```solidity
function _buildHookExecutions(
    address,
    address,
    bytes calldata data
) internal pure override returns (Execution[] memory executions) {
    address rNatContract = data.extractYieldSource();
    if (rNatContract == address(0)) revert ADDRESS_NOT_VALID();

    bool wrap = _decodeBool(data, 72);

    executions = new Execution[](1);
    executions[0] = Execution({
        target: rNatContract,
        value: 0,
        callData: abi.encodeCall(IRNat.withdrawAll, (wrap))
    });
}
```

### Balance Tracking

- **preExecute**: Record WFLR balance (if `wrap=true`) or native FLR balance of the smart
  account.
- **postExecute**: Compute difference as `outAmount`.
- **Critical**: If `wrap=false`, the hook receives native FLR. Tracking native FLR balance
  changes is more complex. **Strongly recommend always using `wrap=true`** to receive WFLR,
  which is a standard ERC-20 and easier to track and compose with.

### Penalty Awareness

- `withdrawAll(true)` will withdraw ALL funds including locked ones with a 50% penalty.
- There is no way to withdraw "only unlocked" via `withdrawAll`. Use `withdraw(amount, true)`
  with the unlocked amount instead.
- **Recommendation**: Consider offering two modes:
  1. `withdrawAll(wrap)` -- Withdraws everything, accepting the penalty on locked tokens.
  2. `withdraw(unlockedAmount, wrap)` -- Withdraws only the unlocked portion (no penalty).
- The off-chain bundler should compute the unlocked amount via `getBalancesOf()` and choose
  the appropriate function.

### Alternative: Withdraw Only Unlocked

If you want a safe withdrawal hook that never incurs penalties:

```solidity
function _buildHookExecutions(...) internal view override returns (Execution[] memory) {
    address rNatContract = data.extractYieldSource();
    (uint256 wNatBalance, , uint256 lockedBalance) = IRNat(rNatContract).getBalancesOf(account);
    uint256 unlocked = wNatBalance - lockedBalance;

    // Use withdraw(uint128, bool) instead of withdrawAll
    executions[0] = Execution({
        target: rNatContract,
        value: 0,
        callData: abi.encodeCall(IRNat.withdraw, (uint128(unlocked), true))
    });
}
```

**Caveat**: This makes `_buildHookExecutions` a `view` function (reads on-chain state), which
deviates from the `pure` pattern used in some hooks. This is acceptable and some existing hooks
(like MerklClaimRewardHook) already use `view`.

---

## 5. Security Considerations

### Must Have

1. **Reentrancy Protection**: The Superform BaseHook already provides mutex-based reentrancy
   protection via `preExecute`/`postExecute` mutexes. No additional reentrancy guard is needed
   in the hooks themselves.

   Source: BaseHook.sol uses `PRE_EXECUTE_ALREADY_CALLED` and `POST_EXECUTE_ALREADY_CALLED`
   error-based mutex checks.

2. **Balance-Difference Pattern**: Always use pre/post balance snapshots rather than trusting
   return values from external calls. This protects against:
   - Fee-on-transfer scenarios (unlikely for WFLR but defensive)
   - Unexpected contract behavior
   - Composability issues with other hooks

   This pattern is already established in FluidClaimRewardHook, YearnClaimOneRewardHook, and
   GearboxClaimRewardHook.

3. **Input Validation**:
   - Validate that `rNatContract != address(0)`
   - Validate that `rewardToken != address(0)`
   - Validate the reward token matches expected token (rFLR for claim, WFLR for withdraw)
   - Validate `projectIds` array is non-empty for claim operations

4. **Penalty Risk Documentation**: The `withdrawAll` function can destroy up to 50% of locked
   tokens. The hook should clearly document this risk. Consider adding a flag or separate hook
   to distinguish between "withdraw all with penalty" and "withdraw only unlocked".

### Recommended

5. **Claim Executor Authorization**: If the Superform executor needs to claim on behalf of the
   smart account, ensure `setClaimExecutors` has been called to authorize it. However, in the
   standard Superform execution model, the smart account itself makes the call, so this is
   likely unnecessary.

6. **Project ID Validation**: While the RNat contract handles invalid project IDs gracefully
   (returns 0 for those), consider validating project IDs off-chain before encoding hook data.

7. **Month Parameter Bounds**: Ensure the month parameter does not exceed the current reward
   period. The contract may handle this, but off-chain validation is advisable.

### Awareness

8. **First-Time RNat Account Creation**: The first claim by any address creates a new RNat
   account (a separate contract deployment). This incurs significantly higher gas costs
   (~200-400k gas extra). The off-chain system should account for this.

9. **FlareDrop Compounding**: WFLR held in RNat accounts earns FlareDrop rewards. These
   rewards increase the `wNatBalance` beyond the `rNatBalance`. The hooks should not assume
   these values are equal.

10. **Cross-Hook Composability**: If ClaimRFLRHook is followed by WithdrawRFLRHook in the
    same transaction, the claim deposits WFLR into the RNat account, and the withdrawal
    extracts it. The newly claimed WFLR will be fully locked (0/12 months vested), so
    `withdrawAll` would apply the 50% penalty to ALL of it.

Source: [Code4rena reentrancy findings](https://github.com/code-423n4/2022-02-concur-findings/issues/118),
[Alchemy smart contract security best practices](https://www.alchemy.com/overviews/smart-contract-security-best-practices)

---

## 6. Gas Optimization

### Batch Claiming

- `claimRewards` accepts an array of project IDs, allowing batch claiming in a single
  transaction. This is significantly more gas-efficient than making separate claims per
  project.
- Gas cost scales linearly with the number of project IDs. For typical usage (1-5 projects),
  gas overhead is minimal.

### Encoding Efficiency

- Use tight packing (BytesLib) for hook data rather than ABI encoding to minimize calldata
  costs.
- The existing Superform pattern of `BytesLib.toUint256(data, offset)` is optimal.

### Avoid Unnecessary State Reads

- `getClaimableRewards` is a view function useful for off-chain checks but should NOT be
  called in the hook execution path. The balance-difference pattern in
  `_preExecute`/`_postExecute` is sufficient.
- `getBalancesOf` should only be called if the hook needs to compute unlocked amounts
  (for the safe withdrawal variant).

### First-Time Account Creation

- The first `claimRewards` call for a new address creates an RNat account contract.
  Estimated gas overhead: 200,000-400,000 gas.
- Subsequent claims are significantly cheaper.
- Off-chain gas estimation should account for this by checking if the user has an existing
  RNat account.

---

## 7. Superform Hook Pattern Compliance

### Required Interfaces

Based on analysis of existing claim hooks (FluidClaimRewardHook, YearnClaimOneRewardHook,
GearboxClaimRewardHook), the rFLR hooks should implement:

**For ClaimRFLRHook (OUTFLOW):**
```solidity
contract ClaimRFLRHook is
    BaseHook,
    BaseClaimRewardHook,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware
{
    constructor() BaseHook(HookType.OUTFLOW, HookSubTypes.CLAIM) {}
    // ...
}
```

**For WithdrawRFLRHook (OUTFLOW):**
```solidity
contract WithdrawRFLRHook is
    BaseHook,
    BaseClaimRewardHook,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware
{
    constructor() BaseHook(HookType.OUTFLOW, HookSubTypes.CLAIM) {}
    // ...
}
```

### Required Method Implementations

1. **`_buildHookExecutions`** -- Build the Execution array for the claim/withdraw call.
2. **`_preExecute`** -- Record pre-execution balance snapshot.
3. **`_postExecute`** -- Compute and set outAmount from balance difference.
4. **`decodeAmount`** -- Return 0 (claim amount is not pre-determined).
5. **`decodeUsePrevHookAmount`** -- Return false (claim does not depend on previous hook).
6. **`replaceCalldataAmount`** -- Return data unchanged (claim amount is not replaceable).
7. **`inspect`** -- Return encoded target addresses for the inspection system.

### Existing Patterns to Follow

From FluidClaimRewardHook (the simplest claim hook pattern):

```solidity
function _preExecute(address, address account, bytes calldata data) internal override {
    asset = BytesLib.toAddress(data, 52); // rewardToken address
    if (asset == address(0)) revert ASSET_ZERO_ADDRESS();
    _setOutAmount(_getBalance(data, account), account); // snapshot balance before
}

function _postExecute(address, address account, bytes calldata data) internal override {
    _setOutAmount(_getBalance(data, account) - getOutAmount(account), account); // delta
}
```

### Vendor Interface Location

The IRNat interface should be placed at:
```
src/vendor/flare/IRNat.sol
```

Following the convention of other vendor interfaces (e.g., `src/vendor/fluid/`,
`src/vendor/yearn/`, `src/vendor/gearbox/`, `src/vendor/vaults/deth/`).

---

## 8. Known Issues and Edge Cases

### 8.1 Claim Returns Zero

If `claimRewards` is called with project IDs that have no unclaimed rewards for the
specified month, it returns 0 and does not revert. The hook should handle this gracefully
(the balance-difference pattern naturally handles this -- outAmount will be 0).

### 8.2 WithdrawAll Penalty on Recently Claimed Rewards

Calling `claimRewards` followed by `withdrawAll` in the same transaction will apply the
50% penalty to the just-claimed rewards (which are fully locked at 0/12 months vested).
This is a significant economic risk.

**Mitigation**: Never chain ClaimRFLRHook and WithdrawRFLRHook in the same execution
unless the user explicitly accepts the penalty. The off-chain bundler should prevent
this by default.

### 8.3 Month Parameter Semantics

The `_month` parameter in `claimRewards` is cumulative -- it claims all unclaimed rewards
from the earliest unclaimed month up to `_month`. Passing an older month is safe (claims
only up to that month). Passing a future month is likely a no-op for those future periods.

### 8.4 Locked Balance Can Exceed RNat Balance

Due to FlareDrop compounding, the WFLR balance in the RNat account can exceed the rFLR
(RNat token) balance. The hook should not assume `wNatBalance == rNatBalance`.

### 8.5 Wrap Parameter for Withdrawal

- `wrap = true`: Returns WFLR (ERC-20). **Recommended for Superform integration** because
  ERC-20 tokens are composable with subsequent hooks (swaps, deposits, etc.).
- `wrap = false`: Returns native FLR. This requires the smart account to handle native FLR,
  which adds complexity and limits composability.

### 8.6 RNat Account Not Yet Created

If the user has never claimed rFLR before, their RNat account does not exist. Calling
`withdrawAll` or `withdraw` before any claim would likely revert or return 0. The off-chain
system should check for account existence before encoding withdrawal hook data.

### 8.7 Gas on Flare Network

Flare uses EVM-compatible gas mechanics but has its own gas pricing. The hooks themselves
do not need special gas handling, but the off-chain gas estimation should use Flare RPC
endpoints for accurate estimation.

---

## 9. Contract Addresses and Resolution

### FlareContractRegistry

All Flare system contracts can be resolved dynamically via the FlareContractRegistry:

**Address (same on all Flare networks):** `0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019`

```solidity
IFlareContractRegistry registry = IFlareContractRegistry(0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019);
address rNat = registry.getContractAddressByName("RNat");
address wNat = registry.getContractAddressByName("WNat");
```

### Known Contract Addresses (Flare Mainnet)

| Contract | Address | Source |
|----------|---------|--------|
| WFLR (WNat) | `0x1D80c49BbBCd1C0911346656B529DF9E5c2F783d` | Flare Developer Hub |
| FlareContractRegistry | `0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019` | Flare Developer Hub |
| RNat | Resolve via registry `getContractAddressByName("RNat")` | Flare Developer Hub |

**Note**: The RNat contract address was not directly found in public documentation during
this research. It should be resolved on-chain via the FlareContractRegistry or found in
the [Flare contract addresses reference](https://docs.flare.network/dev/reference/contracts/).

### Foundry Periphery Package

For Solidity interface imports, install the Flare periphery package:

```bash
forge install flare-foundation/flare-foundry-periphery-package
```

Import interfaces:
```solidity
import { IRNat } from "flare-foundry-periphery-package/src/flare/IRNat.sol";
import { IRNatAccount } from "flare-foundry-periphery-package/src/flare/IRNatAccount.sol";
import { IWNat } from "flare-foundry-periphery-package/src/flare/IWNat.sol";
```

**Alternative**: Define minimal vendor interfaces inline in the Superform codebase
(consistent with existing pattern of minimal interfaces in `src/vendor/`).

---

## 10. Sources

### Official Documentation

- [Flare Developer Hub -- Cookbook (rFLR Rewards)](https://dev.flare.network/network/flare-tx-sdk/cookbook#rflr-rewards)
- [Flare Developer Hub -- FAQ](https://dev.flare.network/support/faqs)
- [A Guide to rFLR Rewards -- Flare Network](https://flare.network/news/a-guide-to-rflr-rewards)
- [Flare Developer Hub -- Overview](https://dev.flare.network/network/overview)

### Code Repositories

- [flare-foundry-periphery-package (IRNat.sol, IWNat.sol)](https://github.com/flare-foundation/flare-foundry-periphery-package)
- [flare-solidity-periphery-package-mirror](https://github.com/flare-foundation/flare-solidity-periphery-package-mirror)
- [flare-smart-contracts-v2](https://github.com/flare-foundation/flare-smart-contracts-v2)
- [flare-tx-sdk (JavaScript SDK)](https://github.com/flare-foundation/flare-tx-sdk)

### Security References

- [Code4rena -- ClaimRewards reentrancy vulnerability](https://github.com/code-423n4/2022-02-concur-findings/issues/118)
- [Code4rena -- MergingPool claimRewards reentrancy](https://github.com/code-423n4/2024-02-ai-arena-findings/issues/830)
- [Code4rena -- ERC777 reentrancy in claimRewards](https://github.com/code-423n4/2023-01-popcorn-findings/issues/392)
- [Alchemy -- 12 Solidity Security Best Practices](https://www.alchemy.com/overviews/smart-contract-security-best-practices)
- [QuickNode -- Reentrancy Attacks Overview](https://www.quicknode.com/guides/ethereum-development/smart-contracts/a-broad-overview-of-reentrancy-attacks-in-solidity-contracts)

### Flare Community & Announcements

- [Flare on X -- Understanding rFLR (claim vs withdraw)](https://x.com/FlareNetworks/status/1832012890905211168)
- [Flare Automatic Claiming Documentation](https://docs.flare.network/user/automatic-claiming/)
- [ClaimSetupManager API Reference](https://docs.flare.network/apis/smart-contracts/ClaimSetupManager/)
- [Flare Block Explorer](https://flare-explorer.flare.network/)
- [Flarescan Explorer](https://mainnet.flarescan.com/)

### Superform Codebase References (Existing Hook Patterns)

- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/BaseHook.sol` -- Base hook with transient storage, mutex, and execution lifecycle
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/claim/BaseClaimRewardHook.sol` -- Base claim hook with `_build()` and `_getBalance()` helpers
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/claim/fluid/FluidClaimRewardHook.sol` -- Simplest claim hook reference implementation
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/claim/yearn/YearnClaimOneRewardHook.sol` -- Claim hook with reward token validation
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/claim/gearbox/GearboxClaimRewardHook.sol` -- Claim hook with external token verification
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/claim/merkl/MerklClaimRewardHook.sol` -- Complex claim hook with fee handling and multi-token support
- `/Users/cosming/1.Coding/Superform/v2-core/src/libraries/HookSubTypes.sol` -- Hook subtype constants (`CLAIM`)
- `/Users/cosming/1.Coding/Superform/v2-core/src/libraries/HookDataDecoder.sol` -- Standard data decoding helpers

---

## Appendix A: Recommended Minimal IRNat Interface for Superform

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IRNat
/// @notice Minimal interface for Flare's RNat (rFLR) reward contract
/// @dev The RNat contract manages rFLR reward claiming, vesting, and withdrawal.
///      Each user gets a dedicated RNat account on first claim.
///      Rewards vest linearly over 12 months; early withdrawal of locked tokens
///      incurs a 50% penalty (burned).
interface IRNat {
    /// @notice Claims rFLR rewards for the caller across specified projects
    /// @param _projectIds Array of project IDs to claim rewards from
    /// @param _month The month up to which to claim (inclusive, cumulative)
    /// @return _claimedAmount Total WFLR amount claimed and deposited to RNat account
    function claimRewards(
        uint256[] calldata _projectIds,
        uint256 _month
    ) external returns (uint256 _claimedAmount);

    /// @notice Withdraws all funds from the caller's RNat account
    /// @dev If locked tokens exist, only 50% of the locked portion is withdrawn;
    ///      the other 50% is burned as a penalty.
    /// @param _wrap If true, returns WFLR (ERC-20); if false, returns native FLR
    /// @return _withdrawnAmount Total amount withdrawn (after penalty deduction)
    function withdrawAll(bool _wrap) external returns (uint256 _withdrawnAmount);

    /// @notice Withdraws a specific amount from the caller's RNat account
    /// @dev If amount exceeds unlocked balance, excess is taken from locked portion
    ///      with a 50% penalty on the locked portion.
    /// @param _amount Amount of WFLR to withdraw
    /// @param _wrap If true, returns WFLR (ERC-20); if false, returns native FLR
    function withdraw(uint128 _amount, bool _wrap) external;

    /// @notice Returns balance information for a given owner
    /// @param _owner The address to query
    /// @return _wNatBalance WFLR balance in the RNat account
    /// @return _rNatBalance rFLR (RNat token) balance
    /// @return _lockedBalance Still-vesting (locked) WFLR amount
    function getBalancesOf(address _owner)
        external
        view
        returns (uint256 _wNatBalance, uint256 _rNatBalance, uint256 _lockedBalance);

    /// @notice Returns the claimable reward amount for given projects and month
    /// @param _projectIds Array of project IDs
    /// @param _owner The address to query
    /// @param _month The month to check
    /// @return _claimableAmount Total claimable WFLR
    function getClaimableRewards(
        uint256[] calldata _projectIds,
        address _owner,
        uint256 _month
    ) external view returns (uint256 _claimableAmount);
}
```

## Appendix B: Implementation Checklist

- [ ] Create `src/vendor/flare/IRNat.sol` with minimal interface
- [ ] Create `src/hooks/claim/flare/ClaimRFLRHook.sol`
  - [ ] Extends BaseHook, BaseClaimRewardHook
  - [ ] HookType.OUTFLOW, HookSubTypes.CLAIM
  - [ ] Data layout: oracleId (32) + rNatContract (20) + rewardToken (20) + month (32) + projectIdsLength (32) + projectIds (32*N)
  - [ ] _buildHookExecutions: encode claimRewards call
  - [ ] _preExecute: snapshot rFLR balance
  - [ ] _postExecute: compute balance delta
  - [ ] decodeAmount returns 0
  - [ ] decodeUsePrevHookAmount returns false
  - [ ] replaceCalldataAmount returns data unchanged
  - [ ] inspect returns rNatContract + rewardToken
- [ ] Create `src/hooks/claim/flare/WithdrawRFLRHook.sol`
  - [ ] Extends BaseHook, BaseClaimRewardHook
  - [ ] HookType.OUTFLOW, HookSubTypes.CLAIM
  - [ ] Data layout: oracleId (32) + rNatContract (20) + rewardToken (20) + bool wrap (1 byte at offset 72)
  - [ ] _buildHookExecutions: encode withdrawAll(wrap=true) call
  - [ ] _preExecute: snapshot WFLR balance
  - [ ] _postExecute: compute WFLR balance delta
  - [ ] Always use wrap=true for ERC-20 composability
  - [ ] Document penalty risk clearly in NatSpec
- [ ] Create unit tests in `test/unit/hooks/claim/flare/`
  - [ ] Test claiming with single project ID
  - [ ] Test claiming with multiple project IDs
  - [ ] Test claiming with empty/invalid project IDs (should not revert, outAmount = 0)
  - [ ] Test withdrawAll with fully vested balance (no penalty)
  - [ ] Test withdrawAll with partially vested balance (50% penalty on locked)
  - [ ] Test withdrawAll with fully locked balance (worst case penalty)
  - [ ] Test balance tracking accuracy in pre/post execute
  - [ ] Test zero-balance scenarios
- [ ] Create fork tests against Flare mainnet (if RPC available)
- [ ] Add inspect() tests for both hooks
