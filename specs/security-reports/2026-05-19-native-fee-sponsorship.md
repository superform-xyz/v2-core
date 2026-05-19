# Security Analysis Report

## Metadata
- **Target:** `NativeFeeSponsorship.sol`, `FetchNativeFeeHook.sol`, `SuperNativePaymaster.sol`
- **Mode:** review (3 parallel agents: vulnerability scanner, best practices, EVM security research)
- **Date:** 2026-05-19
- **Contract Types Detected:** ETH escrow/ledger, execution hook, ERC-4337 paymaster
- **Files Analyzed:** 3 source + 2 interfaces

## Summary

| Severity | Count | New Code | Pre-existing | Blocks Merge |
|----------|-------|----------|-------------|-------------|
| P0 Critical | 0 | 0 | 0 | Yes |
| P1 High | 1 | 1 | 0 | Yes |
| P2 Medium | 5 | 3 | 2 | No |
| P3 Low | 7 | 5 | 2 | No |

> **Note:** Pre-existing findings are in `handleOps` / `_postOp` / `_validatePaymasterUserOp` which were NOT part of the sponsorship feature. They are listed separately for awareness.

## Verdict

**FAIL** - 1 blocking finding (P1) in new sponsorship code should be reviewed before merge.

---

## P1 Findings (High - Must Fix)

### [P1-1] Unrestricted `sponsor` Parameter in `depositForAccount` Enables Deposit Spoofing

- **File:** `src/sponsorship/NativeFeeSponsorship.sol:25`
- **SWC:** N/A
- **Severity:** P1 High
- **Category:** Access Control / Logic Error
- **Description:** `depositForAccount` accepts an arbitrary `sponsor` address. Anyone can deposit ETH and attribute it to any sponsor. The named sponsor can then call `withdrawSponsorDeposit` to claim ETH they never deposited. While `SuperNativePaymaster.sponsorNativeAndHandleOps` correctly passes `msg.sender` as sponsor, the `NativeFeeSponsorship` contract is standalone and publicly callable.
- **Exploit Scenario:** Alice calls `depositForAccount(bob, charlie)` with 1 ETH. Bob calls `withdrawSponsorDeposit(charlie, bob, 1 ether)` and steals Alice's ETH. Additionally, anyone can create misleading on-chain events suggesting arbitrary sponsors have funded accounts.
- **Vulnerable Code:**
```solidity
function depositForAccount(address sponsor, address account) external payable nonReentrant {
    if (sponsor == address(0)) revert ZERO_ADDRESS();
    if (account == address(0)) revert ZERO_ADDRESS();
    if (msg.value == 0) revert ZERO_AMOUNT();
    sponsoredNative[sponsor][account] += msg.value;
    emit NativeDeposited(sponsor, account, msg.value);
}
```
- **Secure Pattern (Option A - enforce msg.sender):**
```solidity
function depositForAccount(address account) external payable nonReentrant {
    if (account == address(0)) revert ZERO_ADDRESS();
    if (msg.value == 0) revert ZERO_AMOUNT();
    sponsoredNative[msg.sender][account] += msg.value;
    emit NativeDeposited(msg.sender, account, msg.value);
}
```
- **Secure Pattern (Option B - keep param, validate caller):**
```solidity
function depositForAccount(address sponsor, address account) external payable nonReentrant {
    if (sponsor == address(0)) revert ZERO_ADDRESS();
    if (account == address(0)) revert ZERO_ADDRESS();
    if (msg.value == 0) revert ZERO_AMOUNT();
    if (msg.sender != sponsor) revert UNAUTHORIZED_DEPOSITOR();
    sponsoredNative[sponsor][account] += msg.value;
    emit NativeDeposited(sponsor, account, msg.value);
}
```

> **Decision needed:** Option A breaks the `SuperNativePaymaster.sponsorNativeAndHandleOps` call pattern (paymaster deposits on behalf of bundler). Option B requires the paymaster to set `msg.sender == sponsor`, but the paymaster IS `msg.sender` when it calls depositForAccount, not the bundler. The current design where the paymaster passes the bundler's address as `sponsor` would break. A third option is to add an allowlist of trusted depositors (e.g., paymaster address) that can deposit on behalf of other sponsors.

---

## P2 Findings (Medium - Should Fix)

### [P2-1] Events Emitted After External Calls (CEI Violation)

- **File:** `src/sponsorship/NativeFeeSponsorship.sol:44-45,61-64`
- **SWC:** N/A
- **Severity:** P2 Medium
- **Category:** Best Practice / Defense-in-Depth
- **Description:** In `withdrawSponsoredNative` and `withdrawSponsorDeposit`, events are emitted AFTER the external ETH transfer. While `nonReentrant` prevents reentrancy, CEI best practice requires events before external calls.
- **Vulnerable Code (withdrawSponsoredNative):**
```solidity
sponsoredNative[sponsor][msg.sender] = available - amount;
(bool success,) = payable(msg.sender).call{ value: amount }("");
if (!success) revert ETH_TRANSFER_FAILED();
emit NativeWithdrawnByAccount(sponsor, msg.sender, amount); // after external call
```
- **Secure Pattern:**
```solidity
sponsoredNative[sponsor][msg.sender] = available - amount;
emit NativeWithdrawnByAccount(sponsor, msg.sender, amount); // before external call
(bool success,) = payable(msg.sender).call{ value: amount }("");
if (!success) revert ETH_TRANSFER_FAILED();
```

### [P2-2] `sponsorNativeAndHandleOps` Sends ETH Before Validating Total

- **File:** `src/paymaster/SuperNativePaymaster.sol:86-93`
- **SWC:** N/A
- **Severity:** P2 Medium
- **Category:** Logic Error / Defense-in-Depth
- **Description:** The function loops through deposits, sending ETH to the sponsorship contract, then checks `totalNative > msg.value` AFTER the loop. If the contract has pre-existing balance (via selfdestruct force-send), more ETH than `msg.value` could be deposited. While the EVM will revert on insufficient balance for individual calls, the check is a post-condition when it should be a pre-condition.
- **Secure Pattern:** Validate total before sending:
```solidity
uint256 totalNative;
for (uint256 i; i < deposits.length; ++i) {
    totalNative += deposits[i].amount;
}
if (totalNative > msg.value) revert NATIVE_AMOUNT_EXCEEDS_VALUE();
for (uint256 i; i < deposits.length; ++i) {
    INativeFeeSponsorship(sponsorship).depositForAccount{ value: deposits[i].amount }(
        msg.sender, deposits[i].account
    );
}
```

### [P2-3] Race Condition Between Sponsor Deposit and Account Withdrawal (Non-Atomic Path)

- **File:** `src/sponsorship/NativeFeeSponsorship.sol` (system-level)
- **SWC:** N/A
- **Severity:** P2 Medium
- **Category:** Logic Error / Front-running
- **Description:** If `depositForAccount` and the UserOp that withdraws happen in separate transactions (not via `sponsorNativeAndHandleOps`), the sponsor can front-run the withdrawal with `withdrawSponsorDeposit`, causing the UserOp to fail. The atomic `sponsorNativeAndHandleOps` flow eliminates this for the primary use case.
- **Mitigation:** Document that the non-atomic deposit path carries race condition risk. The atomic `sponsorNativeAndHandleOps` is the intended primary flow.

### [P2-4] `handleOps` Uses `address(this).balance` (Pre-existing)

- **File:** `src/paymaster/SuperNativePaymaster.sol:61`
- **Severity:** P2 Medium (pre-existing, not new code)
- **Description:** `handleOps` sends `address(this).balance` to EntryPoint, which includes force-sent ETH. The next caller of `handleOps` captures any ETH sitting in the contract. Consider using `msg.value` instead.

### [P2-5] `handleOps` Is `public` Without Access Control (Pre-existing)

- **File:** `src/paymaster/SuperNativePaymaster.sol:60`
- **Severity:** P2 Medium (pre-existing, not new code)
- **Description:** Any address can call `handleOps`. If there is leftover deposit on the EntryPoint, an attacker could craft operations to consume it. Should be `external` at minimum, and ideally restricted to trusted bundlers.

---

## P3 Findings (Low - Consider Fixing)

### [P3-1] Untrusted `sponsorship` Address Parameter

- **File:** `src/paymaster/SuperNativePaymaster.sol:79`
- **Description:** `sponsorship` is caller-supplied. A compromised front-end could pass a malicious contract. Since the caller provides the ETH, they'd only attack themselves. Consider storing as an immutable if the design allows.

### [P3-2] Missing Depositor (`msg.sender`) in `NativeDeposited` Event

- **File:** `src/sponsorship/NativeFeeSponsorship.sol:32`
- **Description:** The event records `sponsor` and `account` but not who actually deposited (`msg.sender`). Add `depositor` to the event for auditability.

### [P3-3] `FetchNativeFeeHook.inspect()` Returns Incomplete Address Set

- **File:** `src/hooks/sponsorship/FetchNativeFeeHook.sol:85`
- **Description:** `inspect()` only returns `SPONSORSHIP`, not the `sponsor` address from hook data. If the inspection system needs all external addresses for compliance, this is incomplete.

### [P3-4] Unbounded `deposits` Array in `sponsorNativeAndHandleOps`

- **File:** `src/paymaster/SuperNativePaymaster.sol:87`
- **SWC:** SWC-128
- **Description:** No length limit on `deposits`. Extremely large arrays could exceed block gas limits. Consider adding `MAX_DEPOSITS` cap.

### [P3-5] NatSpec / Code Style Issues

- **File:** Multiple locations
- **Description:** Missing constructor NatSpec on `FetchNativeFeeHook` and `SuperNativePaymaster`. Misplaced `ERRORS` section header (should be `CONSTRUCTOR`). `@notice` used instead of `@dev` for data layout docs. Unnamed parameters without inline comments. Duplicate NatSpec block in `ISuperNativePaymaster`. `handleOps` should be `external` not `public`.

### [P3-6] `sponsoredNative` Mapping Is `public` (Redundant Getter)

- **File:** `src/sponsorship/NativeFeeSponsorship.sol:18`
- **Description:** The `public` mapping auto-generates a getter, duplicating the explicit `sponsoredAmount` view function. Consider making the mapping `internal`.

### [P3-7] `INSUFFICIENT_BALANCE` Error Is Misleading (Pre-existing)

- **File:** `src/paymaster/SuperNativePaymaster.sol:64,99`
- **Description:** Used for ETH transfer failures which could fail for reasons other than insufficient balance. A more accurate error name like `ETH_TRANSFER_FAILED()` would be clearer.

---

## Attack Surface Summary

| Category | Details |
|----------|---------|
| **External Entry Points** | `depositForAccount` (permissionless), `withdrawSponsoredNative` (account only), `withdrawSponsorDeposit` (sponsor only), `sponsorNativeAndHandleOps` (permissionless), `handleOps` (permissionless) |
| **Value Transfer Points** | ETH: paymaster -> sponsorship, sponsorship -> account, sponsorship -> sponsor, paymaster -> EntryPoint, EntryPoint -> bundler |
| **Oracle Dependencies** | None |
| **Cross-Contract Interactions** | SuperNativePaymaster -> NativeFeeSponsorship, SuperNativePaymaster -> EntryPoint, FetchNativeFeeHook -> NativeFeeSponsorship (via execution) |
| **Upgrade Mechanisms** | None (immutable contracts) |

---

## Security Knowledge Sources
- ERC-4337 audit checklists and known paymaster vulnerabilities
- OpenZeppelin ReentrancyGuard documentation
- OWASP Smart Contract Top 10 (2025)
- EVM force-send patterns (selfdestruct)
- Hook execution security (Uniswap v4 patterns)
- EntryPoint v0.9 griefing fix research
