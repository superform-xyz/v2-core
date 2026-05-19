# Stargate Native Fee Sponsorship — Technical Specification

## Overview

Support Stargate V2 bridge hooks that require native tokens (`msg.value`) for LayerZero messaging fees. The bundler sponsors native ETH atomically during ERC-4337 UserOp execution. The smart account does not need to hold native tokens before execution.

## Problem Statement

Stargate V2's `sendToken` requires `msg.value = lzNativeFee + amountLD`. Smart accounts using Superform's hook system cannot hold pre-funded native ETH for the `lzNativeFee` portion because the bundler builds and submits UserOps on behalf of users. A mechanism is needed for the bundler to sponsor native ETH that the smart account can withdraw atomically during execution.

## Proposed Solution

Three on-chain components:

1. **NativeFeeSponsorship** — Standalone ETH ledger keyed by `(sponsor, account)`
2. **FetchNativeFeeHook** — NONACCOUNTING hook that withdraws sponsored ETH to the smart account
3. **SuperNativePaymaster modification** — New `sponsorNativeAndHandleOps` function that deposits sponsorship + gas atomically

## Technical Considerations

### Architecture
- NativeFeeSponsorship is a standalone contract (not a hook, not a paymaster) — placed in `src/sponsorship/`
- FetchNativeFeeHook is a NONACCOUNTING hook with immutable SPONSORSHIP address
- SuperNativePaymaster gets a new function; sponsorship address passed as parameter (Option A — no constructor change)
- Deploys on ALL Superform chains (mechanism is generic, not Stargate-specific)

### Atomicity Model
- `sponsorNativeAndHandleOps` deposits to NativeFeeSponsorship BEFORE calling `entryPoint.handleOps`
- If `handleOps` fully reverts (validation failure), the entire tx reverts including the deposit — safe
- If inner execution reverts, the deposit persists as an orphan — sponsor reclaims manually via `withdrawSponsorDeposit`
- FetchNativeFeeHook withdrawal inside UserOp execution is reverted if execution fails

### Security
- ReentrancyGuard on all mutating functions in NativeFeeSponsorship
- Checks-Effects-Interactions pattern: state updated before ETH transfers
- Permissionless open balance model: `msg.sender` authorization for withdrawals
- No admin functions, no Pausable, pure ledger

### Performance
- Consider `ReentrancyGuardTransient` (EIP-1153) for ~2000 gas savings per guarded call
- Hook data is 52 bytes (address + uint256) — minimal calldata
- Single Execution output from hook — minimal overhead

## Attack Surface Analysis

### Reentrancy
- [x] CEI pattern followed in all NativeFeeSponsorship functions (1.1)
- [x] ReentrancyGuard on all mutating functions (1.2)
- [x] Cross-contract reentrancy: smart accounts (Nexus/Safe) are trusted (1.3)
- [x] No view functions used by other contracts for state decisions (1.4)

### Access Control
- [x] withdrawSponsoredNative: only account (msg.sender) can withdraw (2.1)
- [x] withdrawSponsorDeposit: only sponsor (msg.sender) can reclaim (2.1)
- [x] depositForAccount: permissionless by design (2.1)
- [x] No admin/owner functions needed (2.4)

### DeFi Interaction Risks
- [x] No oracle dependencies (4.x — N/A)
- [x] No flash loan attack vectors — pure ledger, no price logic (5.x)
- [x] No MEV/sandwich exposure — deposit+handleOps is atomic (6.x)
- [x] No vault/share accounting (22.x — N/A)

### Exploit Precedent
- [x] No known exploits for ERC-4337 native sponsorship pattern (novel)
- [x] ETH escrow patterns well-established in DeFi

## Acceptance Criteria

### Core Contracts
- [ ] NativeFeeSponsorship deployed with `mapping(sponsor => mapping(account => uint256))`
- [ ] `depositForAccount(sponsor, account)` correctly credits `sponsoredNative[sponsor][account]`
- [ ] `withdrawSponsoredNative(sponsor, amount)` correctly debits and transfers ETH to `msg.sender` (account)
- [ ] `withdrawSponsorDeposit(account, to, amount)` correctly debits and transfers ETH to specified recipient
- [ ] All mutating functions have ReentrancyGuard
- [ ] All mutating functions follow Checks-Effects-Interactions pattern
- [ ] Events emitted for all state changes: `NativeDeposited`, `NativeWithdrawnByAccount`, `NativeWithdrawnBySponsor`
- [ ] No `receive()` function — reject direct ETH sends

### Hook
- [ ] FetchNativeFeeHook is NONACCOUNTING with `HookSubTypes.TOKEN`
- [ ] Immutable `SPONSORSHIP` address set in constructor
- [ ] Hook data: `(address sponsor, uint256 amount)` = 52 bytes packed
- [ ] `_buildHookExecutions` returns single Execution calling `withdrawSponsoredNative`
- [ ] Validates: `sponsor != address(0)`, `amount > 0`, `data.length >= 52`
- [ ] `inspect()` returns `abi.encodePacked(SPONSORSHIP)`

### Paymaster
- [ ] `NativeFeeDeposit` struct: `{ address account; uint256 amount; }` defined in interface
- [ ] `sponsorNativeAndHandleOps(PackedUserOperation[] ops, NativeFeeDeposit[] deposits, address sponsorship)` added
- [ ] Validates `sponsorship != address(0)`
- [ ] For each deposit: deposits `amount` into NativeFeeSponsorship for `deposit.account`
- [ ] Deposits array is independent of ops array — one entry per unique sender that needs sponsorship
- [ ] `sum(deposits[].amount) <= msg.value`
- [ ] Remaining `msg.value` deposited to EntryPoint for gas
- [ ] Calls `entryPoint.handleOps`, withdraws remaining deposit back to `msg.sender`
- [ ] Emits `SponsorNativeAndHandleOps` event
- [ ] Existing `handleOps` function unchanged and still works
- [ ] No constructor change (Option A)

### Security
- [ ] No reentrancy vulnerabilities in NativeFeeSponsorship
- [ ] Sponsor can only withdraw own deposits
- [ ] Account can only withdraw deposits made for it
- [ ] ETH transfer failures revert with `ETH_TRANSFER_FAILED`
- [ ] Zero-address and zero-amount checks on all functions

### Testing
- [ ] Unit tests for NativeFeeSponsorship (deposit, withdraw, reclaim, edge cases)
- [ ] Unit tests for FetchNativeFeeHook (constructor, build, data validation, inspect)
- [ ] Unit tests for paymaster `sponsorNativeAndHandleOps`
- [ ] Fork integration test: full flow with Stargate V2 on Ethereum mainnet
- [ ] Invariant: `sum(all deposits) - sum(all withdrawals) == contract.balance`

## Implementation

### Phase 1: Core Contracts

#### `src/interfaces/INativeFeeSponsorship.sol` (NEW)

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

interface INativeFeeSponsorship {
    error ZERO_ADDRESS();
    error ZERO_AMOUNT();
    error INSUFFICIENT_SPONSORED_BALANCE();
    error ETH_TRANSFER_FAILED();

    event NativeDeposited(address indexed sponsor, address indexed account, uint256 amount);
    event NativeWithdrawnByAccount(address indexed sponsor, address indexed account, uint256 amount);
    event NativeWithdrawnBySponsor(address indexed sponsor, address indexed account, address indexed to, uint256 amount);

    function depositForAccount(address sponsor, address account) external payable;
    function withdrawSponsoredNative(address sponsor, uint256 amount) external;
    function withdrawSponsorDeposit(address account, address payable to, uint256 amount) external;
    function sponsoredAmount(address sponsor, address account) external view returns (uint256);
}
```

#### `src/sponsorship/NativeFeeSponsorship.sol` (NEW)

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { INativeFeeSponsorship } from "../interfaces/INativeFeeSponsorship.sol";

contract NativeFeeSponsorship is INativeFeeSponsorship, ReentrancyGuard {
    mapping(address sponsor => mapping(address account => uint256 amount)) public sponsoredNative;

    function depositForAccount(address sponsor, address account) external payable nonReentrant {
        if (sponsor == address(0)) revert ZERO_ADDRESS();
        if (account == address(0)) revert ZERO_ADDRESS();
        if (msg.value == 0) revert ZERO_AMOUNT();
        sponsoredNative[sponsor][account] += msg.value;
        emit NativeDeposited(sponsor, account, msg.value);
    }

    function withdrawSponsoredNative(address sponsor, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZERO_AMOUNT();
        uint256 available = sponsoredNative[sponsor][msg.sender];
        if (available < amount) revert INSUFFICIENT_SPONSORED_BALANCE();
        sponsoredNative[sponsor][msg.sender] = available - amount;
        (bool success,) = payable(msg.sender).call{ value: amount }("");
        if (!success) revert ETH_TRANSFER_FAILED();
        emit NativeWithdrawnByAccount(sponsor, msg.sender, amount);
    }

    function withdrawSponsorDeposit(address account, address payable to, uint256 amount) external nonReentrant {
        if (account == address(0)) revert ZERO_ADDRESS();
        if (to == address(0)) revert ZERO_ADDRESS();
        if (amount == 0) revert ZERO_AMOUNT();
        uint256 available = sponsoredNative[msg.sender][account];
        if (available < amount) revert INSUFFICIENT_SPONSORED_BALANCE();
        sponsoredNative[msg.sender][account] = available - amount;
        (bool success,) = to.call{ value: amount }("");
        if (!success) revert ETH_TRANSFER_FAILED();
        emit NativeWithdrawnBySponsor(msg.sender, account, to, amount);
    }

    function sponsoredAmount(address sponsor, address account) external view returns (uint256) {
        return sponsoredNative[sponsor][account];
    }
}
```

### Phase 2: Hook

#### `src/hooks/sponsorship/FetchNativeFeeHook.sol` (NEW)

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { BytesLib } from "../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BaseHook } from "../BaseHook.sol";
import { HookSubTypes } from "../../libraries/HookSubTypes.sol";
import { INativeFeeSponsorship } from "../../interfaces/INativeFeeSponsorship.sol";

/// @title FetchNativeFeeHook
/// @author Superform Labs
/// @notice Withdraws sponsored native ETH from NativeFeeSponsorship before bridge operations
/// @dev data: address sponsor (20 bytes) + uint256 amount (32 bytes) = 52 bytes
contract FetchNativeFeeHook is BaseHook {
    error INVALID_DATA_LENGTH();

    address public immutable SPONSORSHIP;

    uint256 private constant SPONSOR_POSITION = 0;
    uint256 private constant AMOUNT_POSITION = 20;
    uint256 private constant MIN_DATA_LENGTH = 52;

    constructor(address sponsorship_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.TOKEN) {
        if (sponsorship_ == address(0)) revert ADDRESS_NOT_VALID();
        SPONSORSHIP = sponsorship_;
    }

    function _buildHookExecutions(
        address,
        address,
        bytes calldata data
    ) internal view override returns (Execution[] memory executions) {
        if (data.length < MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();
        address sponsor = BytesLib.toAddress(data, SPONSOR_POSITION);
        uint256 amount = BytesLib.toUint256(data, AMOUNT_POSITION);
        if (sponsor == address(0)) revert ADDRESS_NOT_VALID();
        if (amount == 0) revert AMOUNT_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: SPONSORSHIP,
            value: 0,
            callData: abi.encodeCall(INativeFeeSponsorship.withdrawSponsoredNative, (sponsor, amount))
        });
    }

    function inspect(bytes calldata data) external view override returns (bytes memory) {
        return abi.encodePacked(SPONSORSHIP);
    }
}
```

### Phase 3: Paymaster Modification

#### `src/paymaster/SuperNativePaymaster.sol` (MODIFY)

Add to ISuperNativePaymaster interface:
```solidity
/// @notice Deposit info for native fee sponsorship per account
struct NativeFeeDeposit {
    address account;
    uint256 amount;
}

error NATIVE_AMOUNT_EXCEEDS_VALUE();
error INVALID_SPONSORSHIP();

event SponsorNativeAndHandleOps(
    address indexed sponsor, uint256 totalNativeAmount, uint256 opsCount
);

function sponsorNativeAndHandleOps(
    PackedUserOperation[] calldata ops,
    NativeFeeDeposit[] calldata deposits,
    address sponsorship
) external payable;
```

**Key design**: The `deposits` array is independent of the `ops` array. One entry per unique account that needs native fee sponsorship. For a batch of 5 ops from the same sender, only 1 deposit entry is needed instead of 5 (with 4 zeros). For mixed batches (some ops need Stargate, some don't), only accounts that need sponsorship appear in deposits.

Add to SuperNativePaymaster:
```solidity
function sponsorNativeAndHandleOps(
    PackedUserOperation[] calldata ops,
    NativeFeeDeposit[] calldata deposits,
    address sponsorship
) external payable {
    if (sponsorship == address(0)) revert INVALID_SPONSORSHIP();

    uint256 totalNative;
    for (uint256 i; i < deposits.length; ++i) {
        INativeFeeSponsorship(sponsorship).depositForAccount{ value: deposits[i].amount }(
            msg.sender, deposits[i].account
        );
        totalNative += deposits[i].amount;
    }
    if (totalNative > msg.value) revert NATIVE_AMOUNT_EXCEEDS_VALUE();

    // Deposit remaining ETH for gas
    uint256 gasAmount = msg.value - totalNative;
    if (gasAmount > 0) {
        (bool success,) = payable(address(entryPoint)).call{ value: gasAmount }("");
        if (!success) revert INSUFFICIENT_BALANCE();
    }

    // handleOps reverts on failure → entire tx reverts including deposits
    entryPoint.handleOps(ops, payable(msg.sender));

    // Withdraw remaining deposit back to bundler
    uint256 withdrawnAmount = entryPoint.getDepositInfo(address(this)).deposit;
    if (withdrawnAmount > 0) {
        entryPoint.withdrawTo(payable(msg.sender), withdrawnAmount);
    }

    emit SponsorNativeAndHandleOps(msg.sender, totalNative, ops.length);
}
```

### Phase 4: Deployment

#### Files to modify:
- `script/utils/ConstantsOtherHooks.sol` — Add `FETCH_NATIVE_FEE_HOOK_KEY` and `NATIVE_FEE_SPONSORSHIP_KEY`
- `script/DeployV2OtherHooks.s.sol` — Add `runNativeFeeSponsorship` deployment function
- `script/run/regenerate_bytecode.sh` — Add `NATIVE_FEE_SPONSORSHIP_CONTRACTS` array
- `script/run/deploy_v2_other_hooks_staging_prod.sh` — Add supported chains list

#### Deployment order per chain:
1. Deploy `NativeFeeSponsorship` (no constructor args)
2. Deploy `FetchNativeFeeHook` (constructor arg: NativeFeeSponsorship address)
3. Redeploy `SuperNativePaymaster` with new function (same constructor signature)

### Phase 5: Testing

#### Test files:
- `test/unit/sponsorship/NativeFeeSponsorshipTest.t.sol` — deposit, withdraw, reclaim, edge cases, events
- `test/unit/hooks/sponsorship/FetchNativeFeeHookTest.t.sol` — constructor, build, data validation, inspect
- `test/unit/paymaster/SuperNativePaymasterSponsorshipTest.t.sol` — new function, atomicity, backward compat

## Data Encoding Reference

### FetchNativeFeeHook Data (52 bytes)

```
Offset | Type    | Field   | Description
-------|---------|---------|----------------------------------
0      | address | sponsor | Sponsor (bundler) address (20 bytes)
20     | uint256 | amount  | Native ETH to withdraw (32 bytes)
```

Encoding: `abi.encodePacked(address(sponsor), uint256(amount))`

## Execution Flow

```
Bundler (off-chain)
  │
  ├── quoteSend() → gets lzNativeFee
  │
  └── sponsorNativeAndHandleOps{value: lzNativeFee + gasDeposit}(ops, [lzNativeFee], sponsorship)
        │
        ├── NativeFeeSponsorship.depositForAccount(bundler, smartAccount) {value: lzNativeFee}
        ├── EntryPoint.deposit {value: gasDeposit}
        ├── EntryPoint.handleOps(ops, bundler)
        │     │
        │     └── UserOp execution:
        │           ├── FetchNativeFeeHook → withdrawSponsoredNative(bundler, lzNativeFee) → ETH to smart account
        │           └── StargateSendHook → sendToken{value: lzNativeFee + amountLD}
        │
        └── EntryPoint.withdrawTo(bundler, remainingDeposit)
```

## References

### Internal
- `src/paymaster/SuperNativePaymaster.sol` — existing paymaster
- `src/hooks/tokens/NativeTransferHook.sol` — closest hook pattern
- `src/hooks/BaseHook.sol` — hook base class
- `src/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol` — immutable constructor pattern

### External
- StargateSendHook on PR #885 (`feat/cctp-bridge-hook`)
- ERC-4337 EntryPoint specification
- LayerZero V2 messaging fee model

### Research
- [repo-analysis.md](./research/repo-analysis.md)
- [best-practices.md](./research/best-practices.md)
- [evm-security.md](./research/evm-security.md)
- [specflow-analysis.md](./research/specflow-analysis.md)
