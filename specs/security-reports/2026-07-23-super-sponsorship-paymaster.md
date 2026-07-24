# Security Analysis Report

## Metadata
- **Target:** `/Users/cosming/1.Coding/Superform/v2-core/src/paymaster/SuperSponsorshipPaymaster.sol`
- **Mode:** review
- **Date:** 2026-07-23
- **Contract Types Detected:** General (ERC-4337 Paymaster)
- **Files Analyzed:** 2 (contract + interface)
- **Vulnerability Database:** vulnerabilities.md (36 sections, 300+ patterns, 175+ exploits)

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 1 | Yes |
| P1 High | 3 | Yes |
| P2 Medium | 5 | No |
| P3 Low | 6 | No |

## Verdict
**FAIL** - 4 blocking findings (P0/P1) must be resolved before merge.

---

## P0 Findings (Critical - Must Fix)

### [P0-1] Calldata Validation Bypass via Batch Execution Mode & ABI Offset Manipulation

- **File:** `SuperSponsorshipPaymaster.sol:324-332`
- **SWC:** N/A
- **Category:** Logic
- **Description:** The calldata validation in `_validatePaymasterUserOp` checks fixed byte offsets to verify the UserOp calls `Nexus.execute -> SuperExecutor.execute`. However, it has two independent bypass vectors:

  **1. Batch/DelegateCall Mode Bypass:** The `Nexus.execute(ExecutionMode, bytes)` function uses `ExecutionMode` (bytes32 at `cd[4:36]`) to distinguish call types: `0x00` = CALLTYPE_SINGLE, `0x01` = CALLTYPE_BATCH, `0xFF` = CALLTYPE_DELEGATECALL. The paymaster never checks this mode byte. In batch mode, the calldata layout is completely different (ABI-encoded `Execution[]` array), meaning the bytes at offsets 100-120 and 152-156 are not the target and selector. An attacker can craft a batch UserOp where data at those offsets happens to pass the checks while the actual batch contains calls to arbitrary contracts.

  **2. ABI Offset Manipulation:** The `bytes` parameter in `execute(ExecutionMode, bytes)` is a dynamic type. Its data location is controlled by an offset pointer at `cd[36:68]`. The paymaster assumes canonical ABI encoding (offset = 0x40), but a non-canonical offset can place the actual execution data elsewhere while the fixed positions 100-120 and 152-156 contain attacker-chosen values that pass validation. This is the exact technique used in the **UniswapV4Router04 exploit (March 2026, ~$42,607 loss)**.

- **Exploit Scenario:** An attacker creates a UserOp with `Nexus.execute(batchMode, abi.encode([...]))` where the ExecutionMode has callType=0x01. The ABI layout for a batch is entirely different, but bytes at offsets 100-120 and 152-156 can be crafted to contain `DEFAULT_ALLOWED_SENDER` and `EXECUTOR_EXECUTE_SELECTOR`. The paymaster approves the UserOp, debiting the strategy budget for gas spent executing the attacker's arbitrary batch operations. For delegateCall mode (0xFF), a successful bypass is catastrophic -- target code runs in the account's storage context.
- **Real-World Precedent:** UniswapV4Router04 Calldata-Offset Exploit (March 2026) used identical fixed-offset calldata parsing to bypass a `calldataload(164) == caller()` check, resulting in ~$42,607 loss.
- **Vulnerable Code:**
  ```solidity
  {
      bytes calldata cd = userOp.callData;
      if (cd.length < MIN_CALLDATA_LENGTH) revert INVALID_CALLDATA();
      if (bytes4(cd[0:4]) != NEXUS_EXECUTE_SELECTOR) revert INVALID_CALLDATA();
      address target = address(bytes20(cd[100:120]));
      if (target != DEFAULT_ALLOWED_SENDER) revert INVALID_CALLDATA();
      if (bytes4(cd[152:156]) != EXECUTOR_EXECUTE_SELECTOR) revert INVALID_CALLDATA();
  }
  ```
- **Secure Pattern:**
  ```solidity
  {
      bytes calldata cd = userOp.callData;
      if (cd.length < MIN_CALLDATA_LENGTH) revert INVALID_CALLDATA();
      if (bytes4(cd[0:4]) != NEXUS_EXECUTE_SELECTOR) revert INVALID_CALLDATA();

      // 1. Verify execution mode is SINGLE (0x00). Reject batch/delegatecall.
      if (uint8(cd[4]) != 0x00) revert INVALID_CALLDATA();

      // 2. Verify canonical ABI encoding offset for the dynamic bytes parameter.
      //    The offset at cd[36:68] must be 0x40 (64) for canonical single-execution layout.
      if (bytes32(cd[36:68]) != bytes32(uint256(0x40))) revert INVALID_CALLDATA();

      // Now safe to read fixed offsets
      address target = address(bytes20(cd[100:120]));
      if (target != DEFAULT_ALLOWED_SENDER) revert INVALID_CALLDATA();
      if (bytes4(cd[152:156]) != EXECUTOR_EXECUTE_SELECTOR) revert INVALID_CALLDATA();
  }
  ```
- **Reference:** vulnerabilities.md Section 14.3, Section 40.2; UniswapV4Router04 exploit (Verichains blog)

---

## P1 Findings (High - Must Fix)

### [P1-1] DEFAULT_MAX_GAS Only Checks callGasLimit, Not Total Gas

- **File:** `SuperSponsorshipPaymaster.sol:340-345`
- **SWC:** N/A
- **Category:** Logic
- **Description:** When `maxSingleOpCost` is not set (zero), the gas cap only checks `callGasLimit` (lower 128 bits of `accountGasLimits`) against `DEFAULT_MAX_GAS` (4,000,000). The contract's own NatSpec (lines 36-39) states it should check "the total gas allocated in the UserOp." An attacker can set `callGasLimit = 4_000_000` (passes check) while inflating `verificationGasLimit`, `paymasterVerificationGasLimit`, `paymasterPostOpGasLimit`, and `preVerificationGas`. These inflated fields are factored into `maxCost` by the EntryPoint but are not checked by the paymaster. Additionally, ERC-4337 v0.7 imposes a 10% penalty on unused gas (when unused >= 40,000 units), which is charged from the paymaster deposit but NOT included in `actualGasCost`.
- **Exploit Scenario:** Attacker submits UserOps with `callGasLimit=4M` but `verificationGasLimit=100M`. The EntryPoint computes a very large `maxCost`, the paymaster pre-charges it from the strategy budget, and the 10% penalty on unused gas drains the deposit faster than internal accounting tracks. This is a griefing/DoS vector that can lock up a strategy's entire balance within a single bundle.
- **Vulnerable Code:**
  ```solidity
  } else {
      uint128 callGasLimit = uint128(uint256(userOp.accountGasLimits));
      if (callGasLimit > DEFAULT_MAX_GAS) revert EXCEEDS_SINGLE_OP_CAP();
  }
  ```
- **Secure Pattern:**
  ```solidity
  } else {
      // Check maxCost directly against a wei-denominated cap, or check total gas units.
      // maxCost already aggregates all gas fields * fee, so it's the most comprehensive check.
      if (maxCost > DEFAULT_MAX_COST_WEI) revert EXCEEDS_SINGLE_OP_CAP();
      // Or check total gas units:
      uint128 vgl = uint128(uint256(userOp.accountGasLimits) >> 128);
      uint128 cgl = uint128(uint256(userOp.accountGasLimits));
      if (uint256(vgl) + uint256(cgl) > DEFAULT_MAX_GAS) revert EXCEEDS_SINGLE_OP_CAP();
  }
  ```
- **Reference:** vulnerabilities.md Section 40.2; OtterSec ERC-4337 Paymaster research

### [P1-2] sweepETH Returnbomb via Low-Level Call

- **File:** `SuperSponsorshipPaymaster.sol:212`
- **SWC:** SWC-126
- **Category:** Gas / DoS
- **Description:** The `sweepETH` function uses `(bool success,) = to.call{value: bal}("")`. While the `(bool success,)` pattern in Solidity does still involve RETURNDATACOPY for the success value, a malicious `to` contract could return extremely large data (returnbomb), consuming memory expansion gas and potentially causing OOG. This is an admin-only function, which limits practical exploitability, but if the admin sweeps to a compromised or malicious contract, the sweep becomes permanently DoS'd. The coding rules also require using OpenZeppelin's `Address.sendValue` for ETH transfers.
- **Exploit Scenario:** Admin calls `sweepETH(compromisedContract)` where the compromised contract's `receive()` uses assembly to return 1MB of data. The memory expansion gas exhausts the transaction, causing revert. The sweep function becomes unusable for that address.
- **Vulnerable Code:**
  ```solidity
  (bool success,) = to.call{ value: bal }("");
  if (!success) revert ETH_TRANSFER_FAILED();
  ```
- **Secure Pattern:**
  ```solidity
  // Option A: Assembly call that ignores return data
  assembly {
      let s := call(gas(), to, bal, 0, 0, 0, 0)
      if iszero(s) {
          mstore(0x00, 0x<ETH_TRANSFER_FAILED_selector>)
          revert(0x00, 0x04)
      }
  }
  // Option B: Use OpenZeppelin Address library
  Address.sendValue(payable(to), bal);
  ```
- **Reference:** vulnerabilities.md Section 51 (Returnbomb), Appendix H.1

### [P1-3] emergencyWithdrawFromEntryPoint Should Auto-Pause

- **File:** `SuperSponsorshipPaymaster.sol:259-271`
- **SWC:** N/A
- **Category:** Logic
- **Description:** `emergencyWithdrawFromEntryPoint` reduces `totalAllocated` by the withdrawn amount but does NOT reduce individual strategy balances or pause the paymaster. After this call, strategy balances show funds backed by nothing. If UserOps arrive before manual reconciliation, `_validatePaymasterUserOp` will pre-charge from strategy balances that reduce `totalAllocated` further (potentially causing underflow revert on `totalAllocated -= maxCost`), or the EntryPoint deposit won't cover actual gas costs, causing silent accounting drift. The function is designed for emergencies but creates a dangerous window where the paymaster is in an inconsistent state.
- **Vulnerable Code:**
  ```solidity
  function emergencyWithdrawFromEntryPoint(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
      // ... reduces totalAllocated but does NOT pause
      entryPoint.withdrawTo(payable(to), amount);
  }
  ```
- **Secure Pattern:**
  ```solidity
  function emergencyWithdrawFromEntryPoint(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
      if (to == address(0)) revert ZERO_ADDRESS();
      if (amount == 0) revert ZERO_AMOUNT();

      // Auto-pause to prevent UserOps against stale budgets
      globalPaused = true;
      emit GlobalPauseSet(true);

      if (amount >= totalAllocated) {
          totalAllocated = 0;
      } else {
          totalAllocated -= amount;
      }
      entryPoint.withdrawTo(payable(to), amount);
      emit EmergencyWithdrawn(to, amount);
  }
  ```
- **Reference:** vulnerabilities.md Section 22.5

---

## P2 Findings (Medium - Should Fix)

### [P2-1] reconcile() Desynchronizes totalAllocated from Strategy Balance Sum

- **File:** `SuperSponsorshipPaymaster.sol:244-251`
- **Category:** Logic
- **Description:** After `reconcile()`, sum of strategy balances can exceed `totalAllocated`. Subsequent UserOp validations may revert with arithmetic underflow on `totalAllocated -= maxCost` even though the strategy's balance shows sufficient funds. Consider pausing during reconciliation or implementing proportional reduction.
- **Reference:** vulnerabilities.md Section 25.1

### [P2-2] Hardcoded DEFAULT_ALLOWED_SENDER Prevents Executor Upgrades

- **File:** `SuperSponsorshipPaymaster.sol:46`
- **Category:** Logic
- **Description:** `DEFAULT_ALLOWED_SENDER` is a `constant` address. If the SuperVaultExecutor is redeployed to a new address (or differs across chains), the paymaster becomes permanently unusable and must be redeployed. The NatSpec also misleadingly states "Strategies can override via setAllowedSender() which also overrides the expected execution target" -- but the calldata target check always uses the hardcoded constant. Consider making it an `immutable` set in the constructor or a mutable state variable with admin setter.
- **Reference:** coding-rules.md: "Use immutable variables for values set once at construction time"

### [P2-3] Missing Event on receive()

- **File:** `SuperSponsorshipPaymaster.sol:420`
- **Category:** Other
- **Description:** The `receive()` function accepts ETH without emitting an event. ETH sent directly to the contract goes unnoticed by off-chain monitoring unless specifically polled. Should emit an event per coding-rules.md: "Implement comprehensive events for all significant state changes."
- **Reference:** coding-rules.md

### [P2-4] Permissive Default When allowedSender Not Set

- **File:** `SuperSponsorshipPaymaster.sol:317-318`
- **Category:** Access Control
- **Description:** When `allowedSender[strategy]` is `address(0)` (default), the sender check is skipped entirely. ANY smart account can submit sponsored UserOps for that strategy (assuming calldata checks pass). Combined with any calldata validation bypass, this means strategies without explicit sender restriction are fully open. Consider default-deny: require `allowedSender` to be set before a strategy can be funded.
- **Reference:** ERC-4337 paymaster security best practices

### [P2-5] postOp Cap Silently Masks Accounting Errors

- **File:** `SuperSponsorshipPaymaster.sol:383-385`
- **Category:** Logic
- **Description:** When `totalCost > maxCost`, the cap silently absorbs the difference. The EntryPoint charges the real cost (potentially higher) from the deposit while the paymaster only debits `maxCost` internally. This is necessary to prevent postOp reverts but should emit a distinct event to enable off-chain monitoring of cap activations (which indicate misconfigured overhead or attack patterns).
- **Reference:** OtterSec ERC-4337 Paymaster research

---

## P3 Findings (Low - Consider Fixing)

### [P3-1] Unnamed Function Parameters
- **File:** `SuperSponsorshipPaymaster.sol:302,369`
- **Description:** `bytes32` in `_validatePaymasterUserOp` and `PostOpMode` in `_postOp` are unnamed. Use `/* userOpHash */` and `/* mode */` inline comments for clarity.

### [P3-2] Missing Constructor NatSpec
- **File:** `SuperSponsorshipPaymaster.sol:103`
- **Description:** Constructor lacks `@param` NatSpec annotations for `entryPoint_` and `admin_`.

### [P3-3] Pause Functions Missing Idempotency Check
- **File:** `SuperSponsorshipPaymaster.sol:169-179,202-204`
- **Description:** `pauseStrategy`, `unpauseStrategy`, and `setGlobalPause` don't check if the value is already in the desired state, emitting misleading events on no-op calls.

### [P3-4] StrategyBudget Storage Packing Opportunity
- **File:** `ISuperSponsorshipPaymaster.sol:16-21`
- **Description:** `bool paused` occupies a full slot. If `maxSingleOpCost` were `uint128`, the bool could pack with it. Minor gas optimization.

### [P3-5] Constructor Payable Without Balance Handling
- **File:** `SuperSponsorshipPaymaster.sol:103`
- **Description:** Constructor is `payable` for gas optimization. Any ETH sent during construction sits on the contract and must be swept. Ensure deployment scripts don't send ETH.

### [P3-6] Centralization Risk via DEFAULT_ADMIN_ROLE
- **File:** `SuperSponsorshipPaymaster.sol:105-107`
- **Description:** A compromised admin can set max overhead (500k), emergency withdraw all deposits, and reconcile to mask it. Consider multisig or timelock for DEFAULT_ADMIN_ROLE.

---

## Attack Surface Summary

- **External Entry Points:** `fundStrategy`, `creditStrategy`, `withdrawStrategyFunds`, `setMaxSingleOpCost`, `pauseStrategy`, `unpauseStrategy`, `setAllowedSender`, `setPostOpGasOverhead`, `setGlobalPause`, `sweepETH`, `reconcile`, `emergencyWithdrawFromEntryPoint`
- **Value Transfer Points:** `fundStrategy` (ETH -> EntryPoint), `withdrawStrategyFunds` (EntryPoint -> recipient), `sweepETH` (contract balance -> recipient), `emergencyWithdrawFromEntryPoint` (EntryPoint -> recipient)
- **Oracle Dependencies:** None
- **Cross-Contract Interactions:** `IEntryPoint.depositTo`, `IEntryPoint.withdrawTo`, `IEntryPoint.balanceOf` (trusted EntryPoint)
- **Upgrade Mechanisms:** None (not upgradeable). `DEFAULT_ALLOWED_SENDER` is a hardcoded constant with no upgrade path.

## Coding Standards Findings Summary
- 3 P2 Medium violations (raw low-level call, hardcoded constant, missing event)
- 9 P3 Low violations (naming, NatSpec, idempotency, storage packing)
- All state-changing functions emit events (except `receive()`)
- Custom errors used throughout (SCREAMING_SNAKE_CASE - project convention)
- Checks-Effects-Interactions pattern followed correctly
- No `require` strings, no `tx.origin`, no floating pragma

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1, 2, 3, 7, 8, 9, 13, 14, 15, 21, 22, 25, 36, 40, 50, 51
- **External research:** OtterSec ERC-4337 Paymasters, Trail of Bits ERC-4337 Smart Accounts, Verichains ABI Offset Exploitation, UniswapV4Router04 Exploit, Project Eleven EntryPoint v0.9, OWASP Smart Contract Top 10 2025, ERC-7579 Specification, Biconomy Nexus CodeHawks Audit
- **Coding rules validated:** 19 rules checked from coding-rules.md
- **Historical exploits cross-referenced:** UniswapV4Router04 (March 2026), ERC-4337 v0.7 penalty mechanics
