# EVM & DeFi Security Research: rFLR Claiming and Withdrawal Hooks

**Date:** 2026-05-14
**Scope:** ClaimRFLRHook and WithdrawRFLRHook for Superform V2 on Flare mainnet (chain 14)
**Target contracts:** IRNat at `0x26d460c3Cf931Fb2014FA436a49e3Af08619810e`

---

## 1. RELEVANT VULNERABILITY PATTERNS

### 1.1 Reentrancy via External Calls to IRNat

**Risk Level:** MEDIUM (mitigated by architecture, but requires defense-in-depth)

The hooks make external calls to the IRNat contract (`claimRewards`, `withdrawAll`) and potentially to
WFLR/rFLR token contracts (`balanceOf`, `transfer`). Reentrancy is a concern when:

- **ClaimRFLRHook** calls `IRNat.claimRewards(projectIds, month)` which internally mints/transfers rFLR
  to the caller. If the IRNat contract or the rFLR token uses callbacks (e.g., ERC-777 hooks, receive
  hooks), the caller's fallback could re-enter the hook or executor.

- **WithdrawRFLRHook** calls `IRNat.withdrawAll(wrap=true)` which converts rFLR to WFLR. This involves
  burning rFLR and minting/transferring WFLR. The `wrap=true` path triggers a WFLR deposit, which is a
  native token transfer that could trigger a `receive()` fallback on the smart account.

- **Fee transfer** in ClaimRFLRHook calls `IERC20(rFLR).transfer(feeReceiver, fee)` which is an external
  call to an ERC20 token. If rFLR implements any callback mechanism, this could be a reentrancy vector.

**Superform-specific mitigation already in place:**
- BaseHook uses transient storage mutexes (`PRE_EXECUTE_ALREADY_CALLED`, `POST_EXECUTE_ALREADY_CALLED`)
  that prevent `preExecute` and `postExecute` from being called more than once per execution context.
- The execution flow is: `preExecute -> hook operations -> postExecute`, enforced by the BaseHook's
  `build()` function which constructs the execution array with pre/post guards.
- `msg.sender` checks in `preExecute`/`postExecute` require the caller to be the account itself.

**Residual risk:**
- The mutexes protect against re-entering pre/post execute, but do NOT prevent reentrancy between
  the hook operations themselves (the middle executions in the build array). If `claimRewards` or
  `withdrawAll` re-enters the smart account's executor, the hook operations could be replayed.
- However, since the execution is performed via the smart account's `execute()` which processes the
  Execution array sequentially, and transient storage is scoped to the transaction, this risk is low.

**Recommendation:**
- Treat IRNat as a semi-trusted external contract (Flare system contract, but still external).
- Use the Checks-Effects-Interactions pattern: record balances in `_preExecute` BEFORE external calls.
- Validate balance deltas in `_postExecute` AFTER external calls complete.
- This is already the pattern used by FluidClaimRewardHook, GearboxClaimRewardHook, and
  MerklClaimRewardHook.

### 1.2 Fee Handling Arithmetic

**Risk Level:** MEDIUM

The ClaimRFLRHook must compute fees as `fee = (claimedAmount * feeBPS) / BPS` where BPS = 10,000.

**Precision loss patterns:**
- **Rounding down to zero:** If `claimedAmount * feeBPS < 10,000`, the fee rounds to zero. For
  feeBPS=1 (0.01%), any claim under 10,000 wei produces zero fee. This is acceptable behavior
  (rounding favors the user), but should be documented.

- **Overflow risk:** `claimedAmount * feeBPS` could overflow if claimedAmount is near `type(uint256).max`.
  However, IRNat uses `uint128` for reward amounts, and `uint128.max * 10,000` is well within
  `uint256` range. No overflow risk with uint128 reward amounts.

- **Division before multiplication:** The MerklClaimRewardHook computes
  `fee = ((params.amounts[i] - amount) * feePercent) / BPS` which is correct (multiply first,
  divide last). The rFLR hook MUST follow this same pattern.

- **Fee on gross vs net:** The fee should be computed on the NET claimed amount (what the user actually
  receives), not on some stale or pre-existing balance. The MerklClaimRewardHook queries
  `IDistributor.claimed()` to compute the delta. For rFLR, the hook should compute the fee on the
  actual balance delta between `_preExecute` and `_postExecute`.

**Critical pattern from Balancer V2 exploit (November 2025):**
- Balancer lost $128M due to precision loss in small-value operations where integer division caused
  significant truncation. The rFLR hook should ensure that fee calculations do not create exploitable
  rounding boundaries. With BPS-based fees and uint128 reward amounts, this risk is minimal.

**Recommendation:**
- Use `MAX_FEE_BPS = 5000` (50% cap) consistent with MerklClaimRewardHook.
- Validate `feeBPS <= MAX_FEE_BPS` in `_buildHookExecutions`, not just in `_preExecute`.
- Validate `feeReceiver != address(0)` when `feeBPS > 0`.
- Fee calculation: `fee = (delta * feeBPS) / BPS` where delta is the post-claim balance increase.
- If fee rounds to zero, skip the transfer (avoid zero-value transfer reverts on some tokens).

### 1.3 Token Transfer Edge Cases (rFLR/WFLR)

**Risk Level:** LOW-MEDIUM

**rFLR token characteristics:**
- rFLR is an ERC20 token representing vested rewards backed by WFLR.
- It uses `uint128` for reward amounts internally in the IRNat contract.
- The `claimRewards` function returns `uint128`, not `uint256`.

**WFLR token characteristics:**
- WFLR is the wrapped native FLR token on Flare mainnet (equivalent to WETH on Ethereum).
- `withdrawAll(wrap=true)` causes IRNat to convert rFLR to WFLR and transfer it to the caller.
- The WFLR deposit involves a native FLR transfer to the WFLR contract.

**Edge cases to consider:**
1. **Zero balance claims:** `claimRewards` may return 0 if rewards were already claimed or project IDs
   are invalid. The hook must handle zero deltas gracefully.

2. **Zero-value ERC20 transfers:** Some ERC20 tokens revert on `transfer(to, 0)`. If the fee
   calculation produces zero, the fee transfer should be skipped entirely. Reference: Code4rena
   finding on Concur's `claimRewards` (2022-02, issue #90).

3. **Return value handling:** IRNat's `claimRewards` returns `uint128`. The hook should NOT rely on
   this return value for balance tracking (since the execution is built at `build()` time and the
   return value is not accessible). Instead, use balance snapshots.

4. **rFLR as fee token:** The fee transfer uses `IERC20(rFLR).transfer(feeReceiver, fee)`. If rFLR
   has any transfer restrictions (e.g., cannot transfer locked rFLR), this could fail. The hook
   should document this assumption: fee is taken from the user's rFLR balance post-claim, which
   should be unlocked/claimable rFLR.

5. **Type truncation:** IRNat uses `uint128` internally. If balanceOf returns a value that was
   previously stored as uint128, casting between uint128 and uint256 is safe (uint128 fits in
   uint256). But ensure no implicit truncation occurs in fee math.

### 1.4 Access Control on Claim Operations

**Risk Level:** LOW

**IRNat access control:**
- `claimRewards` can be called by the reward owner OR by authorized claim executors set via
  `setClaimExecutors()`.
- The hook executes as the smart account (the account IS the caller via `Execution`), so the
  smart account must be the reward owner or an authorized executor.

**Hook-level access control (inherited from BaseHook):**
- `preExecute` and `postExecute` require `msg.sender == account`.
- `setExecutionContext` sets the `lastCaller` for later verification.
- `resetExecutionState` requires `msg.sender == lastCaller`.

**Potential issues:**
- If the smart account has not been set up as a participant in the rFLR reward program, `claimRewards`
  will return 0 or revert. The hook should handle this gracefully.
- If `setClaimExecutors` has been configured for the smart account to allow a different executor, the
  hook still works because the smart account itself calls `claimRewards`.

---

## 2. EXPLOIT PRECEDENTS

### 2.1 PenPie Finance - Reentrancy in Reward Harvesting ($27M, September 2024)

**What happened:** An attacker created a fake Pendle Market with a malicious SY (Standardized Yield)
token contract. During `batchHarvestMarketRewards()`, the malicious SY contract re-entered
`depositMarket()` to inflate reward calculations. The `batchHarvestMarketRewards` function lacked
a `nonReentrant` modifier, while `depositMarket` had one (but it was on a different contract).

**Relevance to rFLR hooks:**
- The rFLR hooks make external calls to IRNat which is a Flare system contract (not attacker-controlled).
- However, the fee transfer calls `transfer()` on the rFLR token, which IS an external call to a
  token contract. If rFLR ever implements callbacks, this is a potential vector.
- The `_buildHookExecutions` pattern places the claim BEFORE fee transfers, which is the correct
  order (claim first, then transfer fees from claimed balance).

**Key lesson:** Always protect reward-claiming functions with reentrancy guards, even when individual
sub-functions appear safe.

Source: [AuditOne - PenPie Hack Analysis](https://www.auditone.io/blog-posts/the-penpie-hack-understanding-the-september-2024-reentrancy-exploit-and-the-role-of-auditing-in-defi-security)

### 2.2 Concur Finance - ERC777 Reentrancy in claimRewards ($0, 2022, found in audit)

**What happened:** Code4rena audit finding. `ConcurRewardPool.claimRewards()` called `safeTransfer`
on reward tokens BEFORE zeroing the reward balance. If a reward token was ERC777 (which supports
transfer hooks), an attacker could re-enter `claimRewards()` and drain the pool.

**Relevance to rFLR hooks:**
- rFLR is a standard ERC20 on Flare, not ERC777. However, this pattern illustrates why the
  Checks-Effects-Interactions pattern matters.
- The rFLR hook should update state (outAmount) in `_postExecute` AFTER all transfers complete.
- The BaseHook's mutex system (`PRE_EXECUTE_ALREADY_CALLED`) provides protection against re-entering
  the pre/post lifecycle, but does not prevent re-entering the middle execution steps.

Source: [Code4rena - Concur claimRewards reentrancy](https://github.com/code-423n4/2022-02-concur-findings/issues/118)

### 2.3 Popcorn Finance - ERC777 Reentrancy in MultiRewardStaking ($0, 2023, found in audit)

**What happened:** Code4rena audit finding. `MultiRewardStaking.claimRewards()` transferred reward
tokens before zeroing `accruedRewards`. For ERC777 tokens with `onERC20Received` callbacks, an
attacker could re-enter and claim rewards multiple times.

**Relevance to rFLR hooks:**
- Same pattern as Concur. The rFLR hook computes fees from balance deltas (snapshot pattern), which
  is safer than tracking rewards in contract storage.
- The balance snapshot pattern (used by FluidClaimRewardHook, GearboxClaimRewardHook) is inherently
  resistant to this attack because `_postExecute` reads the actual on-chain balance, not an internal
  accounting variable.

Source: [Code4rena - Popcorn claimRewards reentrancy](https://github.com/code-423n4/2023-01-popcorn-findings/issues/392)

### 2.4 AI Arena - Reentrancy via ERC721 Callback in claimRewards (2024, found in audit)

**What happened:** Code4rena audit finding. `MergingPool.claimRewards()` minted ERC721 NFTs as
rewards. The `onERC721Received` callback allowed re-entering `claimRewards()` before the reward
tracking state was updated, enabling exponential reward multiplication.

**Relevance to rFLR hooks:**
- rFLR claims produce ERC20 tokens, not ERC721, so the specific callback vector differs.
- However, this illustrates that ANY external call during reward claiming can be a reentrancy vector
  if state updates are not atomic.

Source: [Code4rena - AI Arena claimRewards reentrancy](https://github.com/code-423n4/2024-02-ai-arena-findings/issues/37)

### 2.5 Sonne Finance - Share/Exchange Rate Manipulation ($20M, May 2024)

**What happened:** Compound V2 fork exploited via exchange rate manipulation in an empty market.
The attacker donated tokens to inflate the exchange rate, then exploited rounding in
`redeemUnderlying` to redeem more tokens than deposited.

**Relevance to rFLR hooks:**
- Not directly applicable since rFLR hooks don't interact with vault share/exchange rate mechanisms.
- However, the principle applies: if IRNat's `getBalancesOf` or balance calculations are susceptible
  to donation attacks or exchange rate manipulation, the balance snapshot pattern could produce
  incorrect deltas.
- Since rFLR is a reward token (not a vault share), donation attacks are less relevant.

Source: [Halborn - Sonne Finance Hack Explained](https://www.halborn.com/blog/post/explained-the-sonne-finance-hack-may-2024)

### 2.6 Balancer V2 - Precision Loss Exploitation ($128M, November 2025)

**What happened:** Attacker exploited arithmetic precision loss in Balancer's ComposableStablePool
invariant calculations. Small-value swaps at specific rounding boundaries caused integer division
truncation, which the attacker weaponized through batched swap sequences.

**Relevance to rFLR hooks:**
- The fee calculation `(delta * feeBPS) / BPS` involves integer division. For very small deltas or
  very small feeBPS values, the fee can round to zero.
- This is acceptable (rounding favors the user/protocol) but should be tested.
- The rFLR hook operates with uint128 reward amounts and uint256 fee math, which provides sufficient
  precision for BPS calculations.

Source: [Check Point Research - Balancer V2 Exploit](https://research.checkpoint.com/2025/how-an-attacker-drained-128m-from-balancer-through-rounding-error-exploitation/)

---

## 3. ATTACK SURFACE MAP

### 3.1 Fee Manipulation (feeBPS Encoding)

**Attack vector:** Malicious or misconfigured hook data could encode an excessively high feeBPS,
diverting user rewards to the feeReceiver.

**Specific scenarios:**

| Scenario | Vector | Mitigation |
|----------|--------|------------|
| feeBPS > MAX_FEE_BPS | Encode feeBPS as 10001 (>100%) | Validate `feeBPS <= MAX_FEE_BPS` in `_buildHookExecutions` |
| feeBPS = MAX_FEE_BPS | Encode feeBPS as 5000 (50%) | Acceptable -- 50% is the documented maximum |
| feeReceiver = attacker | Set feeReceiver to attacker address | This is by design -- the bundler/off-chain system sets this |
| feeReceiver = address(0) with feeBPS > 0 | Fees would be burned | Validate `feeReceiver != address(0)` when `feeBPS > 0` |
| Integer overflow in fee calc | `delta * feeBPS` overflows | Not possible: uint128 * uint256(5000) < uint256.max |

**Key insight:** The feeBPS and feeReceiver are encoded in the hook data, which is signed by the user
as part of the Merkle tree intent. The user explicitly consents to these fee parameters when signing.
The hook's role is to enforce the MAX_FEE_BPS cap and validate the feeReceiver address.

### 3.2 Claim Front-Running / Sandwich Attacks

**Attack vector:** An attacker observes a pending `claimRewards` transaction and attempts to
front-run or sandwich it.

**Analysis:**
- **Front-running the claim itself:** Not viable. `claimRewards` claims rewards for a specific owner
  (the smart account). An attacker cannot claim someone else's rewards.
- **Sandwich via token price manipulation:** Not directly applicable. rFLR is not traded on a DEX
  within the claim transaction. The claim simply transfers accumulated rewards.
- **Front-running to manipulate project rewards:** If an attacker can influence the reward distribution
  for a project before the claim transaction is mined, they could reduce the claimable amount. This
  is an IRNat-level concern, not a hook-level concern.
- **MEV extraction:** Validators on Flare could reorder transactions, but since reward claims are
  deterministic (fixed amount for a given project/month/owner), reordering does not benefit an attacker.

**Recommendation:** Front-running is not a significant risk for reward claiming hooks because the
claim amount is deterministic and specific to the owner. No slippage protection is needed.

### 3.3 Locked vs Unlocked rFLR Withdrawal Penalty Bypass

**Attack vector:** A user or attacker attempts to bypass the 50% penalty on locked (unvested) rFLR
by manipulating the withdrawal flow.

**rFLR vesting mechanics:**
- rFLR vests linearly over 12 months
- `withdrawAll(wrap=true)` withdraws BOTH locked and unlocked rFLR
- Withdrawing locked rFLR incurs a 50% penalty (only half the locked amount is returned as WFLR)
- The penalty is enforced by the IRNat contract, NOT by the hook

**Specific scenarios:**

| Scenario | Risk | Assessment |
|----------|------|------------|
| User calls withdrawAll with locked balance | 50% penalty applied by IRNat | By design -- user consents via signed intent |
| Hook attempts to withdraw only unlocked | Not supported -- hook uses `withdrawAll` | Could implement via `withdraw(amount, true)` for partial |
| Attacker manipulates locked/unlocked ratio | Would require manipulating IRNat state | Not feasible -- IRNat is a Flare system contract |
| Penalty bypass via reentrancy | Re-enter during withdrawal to claim again | Prevented by IRNat's internal state management |

**Key insight:** The withdrawal penalty is entirely enforced by the IRNat contract. The hook's
responsibility is to:
1. Accurately track the WFLR balance delta (which reflects the post-penalty amount).
2. Not make assumptions about the expected withdrawal amount.
3. Document that `withdrawAll` includes both locked and unlocked balance.

**Recommendation:**
- The `_postExecute` balance delta will correctly capture the post-penalty WFLR amount.
- Consider adding a `getBalancesOf` query in `_preExecute` to log or validate the locked vs unlocked
  breakdown for off-chain monitoring.
- Do NOT try to enforce or predict the penalty in the hook -- defer to IRNat.

### 3.4 Balance Snapshot Manipulation Between _preExecute and _postExecute

**Attack vector (TOCTOU):** An attacker manipulates the token balance between the `_preExecute`
snapshot and the `_postExecute` measurement, causing the delta calculation to produce an incorrect
result.

**How the balance snapshot works in existing hooks:**
```
_preExecute:  balanceBefore = IERC20(token).balanceOf(account)
              _setOutAmount(balanceBefore, account)

[hook operations execute here -- claim/withdraw]

_postExecute: balanceAfter = IERC20(token).balanceOf(account)
              delta = balanceAfter - balanceBefore
              _setOutAmount(delta, account)
```

**Specific manipulation scenarios:**

| Scenario | Vector | Likelihood | Impact |
|----------|--------|------------|--------|
| Direct transfer to account between pre/post | Someone sends rFLR/WFLR to the account | Very low (requires same-tx coordination) | Inflated delta, incorrect outAmount |
| Rebasing token | rFLR rebases between pre/post | None (rFLR is not rebasing) | N/A |
| Flash loan deposit | Flash loan WFLR to account before _postExecute | Very low (execution is atomic via smart account) | Inflated delta |
| Multiple hooks in same tx modify same balance | Another hook transfers WFLR to account | Low (but possible in multi-hook chains) | Incorrect attribution of balance changes |

**Key insight:** The Superform execution model runs all hook operations as a single atomic batch via
the smart account's `execute()` function. The execution array is:
`[setContext, preExecute, claimRewards, (feeTransfer), postExecute, resetState]`

This means:
- No external actor can inject transactions between pre and post execute.
- The ONLY way to manipulate the balance is if the claim/withdraw operation itself has unexpected
  side effects (e.g., transferring additional tokens beyond the claimed amount).
- If other hooks in the same Merkle leaf modify the same token balance, the delta could be incorrect.

**Recommendation:**
- Track the specific token balance relevant to each hook (rFLR for ClaimRFLRHook, WFLR for
  WithdrawRFLRHook).
- Be aware that if ClaimRFLRHook and WithdrawRFLRHook are chained in the same leaf, the WFLR balance
  manipulation from withdraw could affect the claim hook's delta if they share a token.
- Since ClaimRFLRHook tracks rFLR and WithdrawRFLRHook tracks WFLR, they operate on different tokens
  and should not interfere.

### 3.5 Underflow in Balance Delta Calculation

**Attack vector:** If the token balance DECREASES between `_preExecute` and `_postExecute`, the
subtraction `balanceAfter - balanceBefore` will underflow and revert (Solidity 0.8.30 has checked
arithmetic by default).

**Scenarios where balance could decrease:**
1. **Fee transfer reduces rFLR balance:** In ClaimRFLRHook, the execution order is:
   `claim -> feeTransfer`. The fee transfer REDUCES the rFLR balance. If `_postExecute` measures
   the rFLR balance AFTER the fee transfer, the delta would be `claimedAmount - fee`, which is
   correct (net amount to user). But if `_preExecute` captures balance before claim and `_postExecute`
   captures balance after fee transfer, the delta is the net amount.

2. **Withdrawal penalty reduces expected amount:** In WithdrawRFLRHook, `withdrawAll` may return
   less than the full rFLR balance due to the 50% locked penalty. The WFLR received will be less
   than the rFLR burned. This is correct behavior -- the hook tracks WFLR balance, not rFLR balance.

3. **Failed claim returns 0:** If `claimRewards` claims nothing (already claimed, invalid project),
   the balance delta is 0. The fee calculation on 0 produces 0 fee. No underflow.

**Recommendation:**
- For ClaimRFLRHook: Track rFLR balance. The delta after claim + fee transfer = net rFLR to user.
  The fee is computed separately in `_buildHookExecutions`.
- For WithdrawRFLRHook: Track WFLR balance. The delta = WFLR received from withdrawal.
- Add explicit checks: `require(balanceAfter >= balanceBefore)` or handle the case where delta is
  zero/negative gracefully.

---

## 4. RECOMMENDED SECURITY PATTERNS

### 4.1 Follow the MerklClaimRewardHook Pattern (Audited)

The MerklClaimRewardHook is the most relevant reference implementation. It:
- Uses `NONACCOUNTING` hook type
- Encodes `feeReceiver` and `feePercent` in hook data
- Validates `feePercent <= MAX_FEE_PERCENT` (5000 = 50%)
- Validates `feeReceiver != address(0)` when `feePercent > 0`
- Sets `outAmount = 0` in both `_preExecute` and `_postExecute` (since it's NONACCOUNTING)

**For ClaimRFLRHook:** Adapt this pattern but track rFLR balance deltas (unlike Merkl which
uses cumulative claim amounts from the distributor).

**For WithdrawRFLRHook:** Adapt the WithdrawWETHHook pattern but with WFLR balance tracking.

### 4.2 Immutable External Contract Addresses

Following the pattern in MerklClaimRewardHook:
```solidity
address public immutable RNAT; // Set in constructor, validated non-zero
```

This prevents:
- Admin key compromise changing the target contract
- Proxy upgrade attacks on the hook itself
- Storage slot manipulation

### 4.3 Balance Snapshot Pattern (Checks-Effects-Interactions)

```solidity
function _preExecute(address, address account, bytes calldata data) internal override {
    // CHECKS: Validate parameters
    // EFFECTS: Record pre-state
    _setOutAmount(IERC20(rFLR).balanceOf(account), account);
}

function _postExecute(address, address account, bytes calldata data) internal override {
    // EFFECTS: Compute and record post-state
    uint256 balanceAfter = IERC20(rFLR).balanceOf(account);
    uint256 balanceBefore = getOutAmount(account);
    // Net amount after fee transfer
    _setOutAmount(balanceAfter >= balanceBefore ? balanceAfter - balanceBefore : 0, account);
}
```

### 4.4 Fee Validation at Build Time

Validate fee parameters in `_buildHookExecutions` (which runs at build time) rather than only at
execution time. This catches invalid parameters before the transaction is submitted:

```solidity
if (feeBPS > MAX_FEE_BPS) revert FEE_NOT_VALID();
if (feeBPS > 0 && feeReceiver == address(0)) revert ADDRESS_NOT_VALID();
```

### 4.5 Skip Zero-Value Transfers

Some ERC20 tokens revert on `transfer(to, 0)`. The hook should skip fee transfers when the
calculated fee is zero:

```solidity
if (fee > 0) {
    executions[claimIndex + 1] = Execution({
        target: rFLR,
        value: 0,
        callData: abi.encodeCall(IERC20.transfer, (feeReceiver, fee))
    });
}
```

### 4.6 Validate Input Arrays

For ClaimRFLRHook, the `projectIds` array is user-provided:
- Validate `projectIds.length > 0` (empty array wastes gas)
- Validate `month` is a reasonable value (not zero, not in the far future)
- Consider a maximum length for `projectIds` to prevent gas griefing

### 4.7 Use uint128 Awareness

IRNat uses `uint128` for reward amounts. The hook should be aware of this:
- `claimRewards` returns `uint128`
- `getBalancesOf` returns `uint256` values
- `balanceOf` (ERC20) returns `uint256`
- No truncation issues when storing uint128 in uint256 fields
- Fee calculation in uint256 is safe: `uint128.max * 5000 < uint256.max`

### 4.8 Document the 50% Penalty Explicitly

The WithdrawRFLRHook should clearly document in NatSpec that:
- `withdrawAll` includes BOTH locked and unlocked rFLR
- Locked rFLR is subject to a 50% withdrawal penalty enforced by IRNat
- The hook's outAmount reflects the post-penalty WFLR received
- The user has explicitly consented to this via their signed intent

---

## 5. TESTING RECOMMENDATIONS

### 5.1 Unit Test Scenarios

#### ClaimRFLRHook

| Test | Description | Expected Behavior |
|------|-------------|-------------------|
| `test_Build_NoFee` | Build with feeBPS=0 | Execution array: [preExec, claim, postExec] |
| `test_Build_WithFee` | Build with feeBPS=1000 (10%) | Execution array: [preExec, claim, feeTransfer, postExec] |
| `test_Build_MaxFee` | Build with feeBPS=5000 (50%) | Should succeed |
| `test_Build_RevertIf_FeeExceedsMax` | Build with feeBPS=5001 | Revert with FEE_NOT_VALID |
| `test_Build_RevertIf_FeeReceiverZero` | feeBPS > 0, feeReceiver = address(0) | Revert with ADDRESS_NOT_VALID |
| `test_Build_RevertIf_EmptyProjectIds` | Empty projectIds array | Revert with AMOUNT_NOT_VALID or custom error |
| `test_Build_RevertIf_RNatZeroAddress` | Constructor with address(0) | Revert with ADDRESS_NOT_VALID |
| `test_PrePostExecute_ZeroClaim` | Claim returns 0 rewards | outAmount = 0, no fee transfer |
| `test_PrePostExecute_NormalClaim` | Claim returns 1000 rFLR with 10% fee | outAmount = 900 (net), fee = 100 |
| `test_PrePostExecute_SmallClaim` | Claim returns 1 wei with feeBPS=1 | fee = 0 (rounds down), outAmount = 1 |
| `test_Constructor` | Verify hook type is NONACCOUNTING | hookType = NONACCOUNTING |
| `test_Inspect` | Verify inspect returns correct addresses | Returns RNAT address |
| `test_CalldataDecoding` | Verify projectIds and month are correctly decoded | Parameters match encoded values |
| `test_PreExecute_UnauthorizedCaller` | Call preExecute from non-account | Revert with UNAUTHORIZED_CALLER |

#### WithdrawRFLRHook

| Test | Description | Expected Behavior |
|------|-------------|-------------------|
| `test_Build_Normal` | Build with valid parameters | Execution array: [preExec, withdrawAll, postExec] |
| `test_Build_RevertIf_RNatZeroAddress` | Constructor with address(0) | Revert with ADDRESS_NOT_VALID |
| `test_PrePostExecute_FullyUnlocked` | Withdraw fully vested rFLR | outAmount = full WFLR amount |
| `test_PrePostExecute_PartiallyLocked` | Withdraw with 50% locked | outAmount = unlocked + (locked/2) |
| `test_PrePostExecute_FullyLocked` | Withdraw fully locked rFLR | outAmount = locked/2 (50% penalty) |
| `test_PrePostExecute_ZeroBalance` | Withdraw with zero rFLR balance | outAmount = 0 |
| `test_Constructor` | Verify hook type is NONACCOUNTING | hookType = NONACCOUNTING |
| `test_WrapAlwaysTrue` | Verify withdrawAll is called with wrap=true | callData encodes wrap=true |

### 5.2 Fuzz Test Scenarios

```solidity
/// @dev Fuzz feeBPS to verify fee calculation never overflows and is always <= claimed amount
function testFuzz_FeeCalculation(uint128 claimedAmount, uint16 feeBPS) public {
    vm.assume(feeBPS <= MAX_FEE_BPS);
    uint256 fee = (uint256(claimedAmount) * uint256(feeBPS)) / BPS;
    assertLe(fee, claimedAmount, "Fee exceeds claimed amount");
    assertLe(fee, (uint256(claimedAmount) * MAX_FEE_BPS) / BPS, "Fee exceeds max fee");
}

/// @dev Fuzz projectIds length to verify gas consumption is bounded
function testFuzz_ProjectIdsLength(uint8 numProjects) public {
    vm.assume(numProjects > 0 && numProjects <= 50);
    uint256[] memory projectIds = new uint256[](numProjects);
    for (uint256 i; i < numProjects; i++) {
        projectIds[i] = i + 1;
    }
    // Build should succeed without excessive gas
    // Measure gas and assert < reasonable limit
}

/// @dev Fuzz the month parameter
function testFuzz_MonthParameter(uint256 month) public {
    vm.assume(month > 0 && month <= 120); // 10 years of months
    // Build and verify month is correctly encoded and decoded
}

/// @dev Fuzz withdrawal with varying locked/unlocked ratios
function testFuzz_WithdrawalPenalty(uint128 lockedAmount, uint128 unlockedAmount) public {
    vm.assume(lockedAmount > 0 || unlockedAmount > 0);
    // Mock IRNat to return specified locked/unlocked amounts
    // Verify outAmount = unlockedAmount + (lockedAmount / 2)
}
```

### 5.3 Invariant Tests

```solidity
/// INVARIANT: Fee must never exceed MAX_FEE_BPS percentage of the claimed amount
/// fee <= (claimedAmount * MAX_FEE_BPS) / BPS

/// INVARIANT: outAmount + fee == total balance delta (for ClaimRFLRHook)
/// getOutAmount(account) + feeTransferred == balanceAfter - balanceBefore

/// INVARIANT: withdrawAll outAmount must be <= total rFLR balance (for WithdrawRFLRHook)
/// getOutAmount(account) <= rFLR.balanceOf(account) [pre-withdrawal]

/// INVARIANT: preExecute and postExecute are called exactly once per execution context
/// (enforced by BaseHook mutexes)

/// INVARIANT: feeBPS encoding is never silently truncated
/// decoded feeBPS == encoded feeBPS

/// INVARIANT: outAmount is never negative (no underflow)
/// balanceAfter >= balanceBefore OR outAmount == 0
```

### 5.4 Fork Test Scenarios (Flare Mainnet Fork)

These tests should run against a Flare mainnet fork to validate real contract interactions:

```solidity
/// @dev Fork test: Claim real rFLR rewards from a known project
function test_Fork_ClaimRewards() public {
    vm.createSelectFork("flare_mainnet");
    // Setup: Find an account with claimable rFLR rewards
    // Execute: ClaimRFLRHook.build() -> smart account execute
    // Verify: rFLR balance increased by expected amount
}

/// @dev Fork test: Withdraw rFLR to WFLR
function test_Fork_WithdrawAll() public {
    vm.createSelectFork("flare_mainnet");
    // Setup: Fund account with rFLR (via claim or transfer)
    // Execute: WithdrawRFLRHook.build() -> smart account execute
    // Verify: WFLR balance increased, rFLR balance decreased
}

/// @dev Fork test: Verify 50% penalty on locked withdrawal
function test_Fork_WithdrawLockedPenalty() public {
    vm.createSelectFork("flare_mainnet");
    // Setup: Account with known locked rFLR amount
    // Execute: withdrawAll
    // Verify: WFLR received = unlocked + (locked / 2)
}

/// @dev Fork test: Full claim + withdraw + fee pipeline
function test_Fork_ClaimAndWithdrawPipeline() public {
    vm.createSelectFork("flare_mainnet");
    // Execute: ClaimRFLRHook (with 10% fee) -> WithdrawRFLRHook
    // Verify: Fee correctly deducted, WFLR received matches expected
}
```

### 5.5 Edge Case Tests

```solidity
/// @dev Test that zero-value fee transfer is skipped (not attempted)
function test_ZeroFeeSkipped() public { }

/// @dev Test claiming from non-existent project ID
function test_InvalidProjectId() public { }

/// @dev Test claiming for a month that has no rewards
function test_NoRewardsForMonth() public { }

/// @dev Test multiple claims in same transaction (should work due to transient storage)
function test_MultipleClaims() public { }

/// @dev Test that hook works correctly when chained with other hooks
function test_HookChaining() public { }

/// @dev Test maximum uint128 reward amount (boundary)
function test_MaxUint128RewardAmount() public { }

/// @dev Test that preExecute cannot be called twice
function test_PreExecuteDoubleCall() public { }

/// @dev Test that postExecute cannot be called without preExecute
function test_PostExecuteWithoutPreExecute() public { }
```

---

## 6. SUMMARY OF KEY RISKS AND MITIGATIONS

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| Reentrancy via IRNat external calls | Medium | Low | BaseHook mutexes, CEI pattern, balance snapshots |
| Fee calculation precision loss | Low | Low | Multiply before divide, uint256 math, skip zero fees |
| feeBPS exceeds maximum | Medium | Low | Validate `feeBPS <= MAX_FEE_BPS` in build |
| Zero-value ERC20 transfer revert | Low | Medium | Skip fee transfer when fee rounds to zero |
| Locked rFLR withdrawal penalty bypass | Low | Very Low | Penalty enforced by IRNat, not hook |
| Balance snapshot TOCTOU | Low | Very Low | Atomic execution via smart account |
| Front-running/sandwich on claims | Low | Very Low | Claims are deterministic, not price-dependent |
| Underflow in delta calculation | Medium | Low | Checked arithmetic (Solidity 0.8.30), handle zero delta |
| Invalid projectIds cause revert | Low | Medium | Validate non-empty array, handle gracefully |

---

## 7. REFERENCES

### Superform Codebase References
- Base hook: `src/hooks/BaseHook.sol`
- Merkl claim hook (closest pattern): `src/hooks/claim/merkl/MerklClaimRewardHook.sol`
- Fluid claim hook: `src/hooks/claim/fluid/FluidClaimRewardHook.sol`
- Gearbox claim hook: `src/hooks/claim/gearbox/GearboxClaimRewardHook.sol`
- WETH withdraw hook: `src/hooks/tokens/weth/WithdrawWETHHook.sol`
- DETH claim hook: `src/hooks/vaults/deth/ClaimAssetsDETHHook.sol`
- Merkl claim test: `test/unit/hooks/claim/merkl/MerklClaimRewardsHook.t.sol`

### External Security References
- [PenPie Reentrancy Exploit Analysis (AuditOne, Sep 2024)](https://www.auditone.io/blog-posts/the-penpie-hack-understanding-the-september-2024-reentrancy-exploit-and-the-role-of-auditing-in-defi-security)
- [PenPie Detailed Analysis (Three Sigma)](https://threesigma.xyz/blog/exploit/penpie-reentrancy-exploit-analysis)
- [Concur claimRewards Reentrancy (Code4rena, 2022)](https://github.com/code-423n4/2022-02-concur-findings/issues/118)
- [Popcorn claimRewards ERC777 Reentrancy (Code4rena, 2023)](https://github.com/code-423n4/2023-01-popcorn-findings/issues/392)
- [AI Arena claimRewards ERC721 Reentrancy (Code4rena, 2024)](https://github.com/code-423n4/2024-02-ai-arena-findings/issues/37)
- [Sonne Finance Exchange Rate Manipulation (Halborn, May 2024)](https://www.halborn.com/blog/post/explained-the-sonne-finance-hack-may-2024)
- [Balancer V2 Precision Loss Exploit (Check Point Research, Nov 2025)](https://research.checkpoint.com/2025/how-an-attacker-drained-128m-from-balancer-through-rounding-error-exploitation/)
- [Concur Zero-Value Transfer Revert (Code4rena, 2022)](https://github.com/code-423n4/2022-02-concur-findings/issues/90)
- [2024 Most Exploited DeFi Vulnerabilities (Three Sigma)](https://threesigma.xyz/blog/exploit/2024-defi-exploits-top-vulnerabilities)
- [Halborn Top 100 DeFi Hacks Report 2025](https://www.halborn.com/reports/top-100-defi-hacks-2025)

### Flare Protocol References
- [Flare rFLR Rewards Guide](https://flare.network/news/a-guide-to-rflr-rewards)
- [Flare Smart Contracts V2 (GitHub)](https://github.com/flare-foundation/flare-smart-contracts-v2)
- [Flare Foundry Periphery Package (GitHub)](https://github.com/flare-foundation/flare-foundry-periphery-package)
- [Flare TX SDK (npm)](https://www.npmjs.com/package/@flarenetwork/flare-tx-sdk)
- [Flare Developer Hub](https://dev.flare.network/network/getting-started)
- IRNat interface: `src/flare/IRNat.sol` in flare-foundry-periphery-package
- IRNatAccount interface: `src/flare/IRNatAccount.sol` in flare-foundry-periphery-package

### Superform Security Documentation
- `SECURITY.md` -- Known issues and accepted trade-offs
- Hook safety assumptions (SECURITY.md, item 4)
- Fee skipping edge cases (SECURITY.md, item 8)
