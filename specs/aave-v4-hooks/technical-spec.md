# Aave V4 Hooks Technical Specification

## Overview

Build 6 lending protocol hooks for Aave V4's Hub-and-Spoke architecture on Ethereum mainnet, following the established Morpho loan hook patterns in `src/hooks/loan/morpho/`.

## Problem Statement

Aave V4 launched on Ethereum mainnet (March 30, 2026) with a new architecture that replaces the monolithic Pool.sol with modular Hub-and-Spoke design. stataTokens (V3 ERC-4626 wrappers) are not needed since V4 uses native share-based accounting. We need dedicated hooks to interact with V4's Spoke interface.

## Proposed Solution

Create a `BaseAaveV4LoanHook` extending `BaseLoanHook`, plus 6 concrete hooks mirroring the Morpho pattern. All hooks are `HookType.NONACCOUNTING` (per `BaseLoanHook` convention).

## Technical Considerations

### BLOCKER: Position Manager Requirement

Aave V4 Spoke functions are protected by `onlyPositionManager(onBehalfOf)`. Before implementation:

1. **Verify** whether Superform smart accounts (Nexus/Safe via ERC-7579) can call Spoke functions directly, or if they need Position Manager registration
2. **Option A**: The smart account IS the `msg.sender` and is also the `onBehalfOf` — Aave may allow self-calls
3. **Option B**: Need governance proposal to register Superform's executor as a Position Manager
4. **Option C**: Route through Aave's existing SignatureGateway Position Manager

**This must be resolved before implementation begins.** Run `forge install aave/aave-v4` and read `ISpoke.sol` to verify the exact access control logic.

### Architecture

```
BaseLoanHook (NONACCOUNTING, ISuperHookLoans)
  └── BaseAaveV4LoanHook (stores spoke address, data layout, decode functions)
        ├── AaveV4SupplyHook          (LOAN)
        ├── AaveV4WithdrawHook        (LOAN_REPAY)
        ├── AaveV4BorrowHook          (LOAN)
        ├── AaveV4RepayHook           (LOAN_REPAY)
        ├── AaveV4SupplyAndBorrowHook (LOAN)
        └── AaveV4RepayAndWithdrawHook (LOAN_REPAY)
```

### Data Layout

Following BaseLoanHook convention (loanToken at offset 0, collateralToken at offset 20):

```
address loanToken            (position 0)   -- borrowed asset address
address collateralToken      (position 20)  -- collateral asset address
address spoke                (position 40)  -- Aave V4 Spoke address
uint256 supplyReserveId      (position 60)  -- collateral reserve ID in the Spoke
uint256 borrowReserveId      (position 92)  -- loan reserve ID in the Spoke
uint256 amount               (position 124) -- operation amount
bool    usePrevHookAmount    (position 156)
bool    isFullRepayment      (position 157) -- repay hooks only
```

**Note**: Unlike Morpho (single market with 4 addresses), Aave V4 uses a Spoke address + two reserveIds (one for supply/collateral, one for borrow). Single-operation hooks (Supply, Withdraw, Borrow, Repay) only use one reserveId; combined hooks (SupplyAndBorrow, RepayAndWithdraw) use both.

### Approval Target

Tokens must be approved to the **Spoke** address (the Spoke calls `safeTransferFrom` internally). This differs from Morpho where tokens are approved to the Morpho contract directly.

## Acceptance Criteria

### Functional Requirements
- [ ] All 6 hooks compile and pass unit tests
- [ ] Each hook follows the zero-approve-set-approve-zero pattern (P1-1)
- [ ] `onBehalfOf` is always hardcoded to `account` (prevent operating on behalf of others)
- [ ] `usePrevHookAmount` support for hook chaining
- [ ] `isFullRepayment` support for RepayHook and RepayAndWithdrawHook
- [ ] Balance-diff tracking in `_preExecute`/`_postExecute` for all hooks
- [ ] `inspect()` returns encoded Spoke address for each hook
- [ ] `decodeAmount()` and `decodeUsePrevHookAmount()` exposed via ISuperHookInflowOutflow/ISuperHookContextAware

### Non-Functional Requirements
- [ ] Position Manager requirement resolved and documented
- [ ] Integration tests pass against Ethereum mainnet fork
- [ ] All hooks registered in Constants.sol, deployment scripts, and bytecode regeneration

### Security Requirements
- [ ] reserveId validation: include expected token address in calldata, validate on-chain
- [ ] No dangling approvals after hook execution
- [ ] Interest accrual handling for full repayment (stale approval buffer)

## Implementation

### Phase 0: Setup & Verify (Pre-Implementation)
- [ ] `forge install aave/aave-v4` — get exact interface files
- [ ] Read `ISpoke.sol`, `ISpokeBase.sol` — verify function signatures
- [ ] Test Position Manager access control — can smart account call Spoke directly?
- [ ] Get deployed Spoke addresses from aave-address-book
- [ ] Create `src/vendor/aave-v4/IAaveV4Spoke.sol` with minimal interface

### Phase 1: Base Hook
- [ ] Create `src/hooks/loan/aave-v4/BaseAaveV4LoanHook.sol`
  - Extend `BaseLoanHook`
  - No constructor args (Spoke address comes from calldata, not constructor — unlike Morpho)
  - Define data layout constants (offsets for spoke, reserveIds, amount, flags)
  - Implement `_decodeHookData()`, `_decodeBorrowHookData()`
  - Implement `_decodeSpoke()`, `_decodeSupplyReserveId()`, `_decodeBorrowReserveId()`
  - Address validation: spoke != address(0), validate reserveId maps to expected token

### Phase 2: Individual Hooks (4 hooks)
- [ ] `AaveV4SupplyHook` (LOAN subtype)
  - Executions: approve(0) + approve(amount) + spoke.supply(reserveId, amount, account) + approve(0)
  - outAmount: tracks collateral token consumed (pre - post balance)

- [ ] `AaveV4WithdrawHook` (LOAN_REPAY subtype)
  - Executions: spoke.withdraw(reserveId, amount, account)
  - outAmount: tracks collateral token received (post - pre balance)

- [ ] `AaveV4BorrowHook` (LOAN subtype)
  - Executions: spoke.borrow(reserveId, amount, account)
  - outAmount: tracks loan token received (post - pre balance)

- [ ] `AaveV4RepayHook` (LOAN_REPAY subtype)
  - Executions: approve(0) + approve(amount) + spoke.repay(reserveId, amount, account) + approve(0)
  - Full repayment: use type(uint256).max or query debt and add buffer
  - outAmount: tracks loan token consumed (pre - post balance)

### Phase 3: Combined Hooks (2 hooks)
- [ ] `AaveV4SupplyAndBorrowHook` (LOAN subtype)
  - Executions: approve(0) + approve(amount) + spoke.supply(supplyReserveId, amount, account) + spoke.borrow(borrowReserveId, borrowAmount, account) + approve(0)
  - Borrow amount derivation: needs oracle price (TBD — may query Spoke's oracle or use off-chain computed amount)
  - outAmount: tracks collateral consumed

- [ ] `AaveV4RepayAndWithdrawHook` (LOAN_REPAY subtype)
  - Executions: approve(0) + approve(repayAmount) + spoke.repay(borrowReserveId, amount, account) + approve(0) + spoke.withdraw(supplyReserveId, withdrawAmount, account)
  - Full repayment: withdraw all collateral
  - Partial repayment: proportional collateral withdrawal (TBD — may need on-chain position query)
  - outAmount: tracks collateral received

### Phase 4: Deployment & Testing
- [ ] Add hook keys to `Constants.sol`
- [ ] Add Spoke addresses to `ConstantsOtherHooks.sol` (Ethereum only)
- [ ] Update `ConfigOtherHooks.sol` with chain mapping
- [ ] Add deployment function to `DeployV2OtherHooks.s.sol`
- [ ] Update `regenerate_bytecode.sh`, `verify_v2_staging_prod.sh`, `deploy_v2_other_hooks_staging_prod.sh`
- [ ] Unit tests: `test/unit/hooks/loan/AaveV4LoanHooks.t.sol`
- [ ] Integration tests: `test/integration/AaveV4IntegrationTest.t.sol`

## Attack Surface Analysis

### Token Risks
- [x] Fee-on-transfer: handled by balance-diff pattern in pre/post execute
- [x] USDT non-standard approval: handled by zero-approve-set-approve-zero pattern
- [ ] Rebasing tokens: if Aave V4 lists rebasing tokens, balance can change between pre/post execute
- [x] Pausable/blocklist tokens: handled by Aave V4 internally (reserve paused flag)

### Reentrancy
- [x] CEI pattern followed via BaseHook pre/post execute
- [x] SuperExecutorBase nonReentrant guard
- [x] No callback mechanism in Aave V4 Spoke (unlike Morpho's onMorphoSupply)
- [ ] ERC-777 callback risk on safeTransferFrom — mitigated by Aave's token whitelist

### Access Control
- [x] `onBehalfOf` hardcoded to `account` — prevent operating on others' behalf
- [ ] Position Manager requirement — BLOCKER, must verify
- [ ] reserveId validation — include token address in calldata, validate on-chain

### Exploit Precedents
| Protocol | Date | Loss | Relevance |
|----------|------|------|-----------|
| Euler Finance | Mar 2023 | $197M | Self-collateralization + donation attack |
| Radiant Capital | Jan 2024 | $4.5M | Rounding in thin Aave-fork markets |
| Aave rsETH | Apr 2026 | $196M | Underlying collateral compromised externally |

## Dependencies & Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Position Manager access denied | HIGH | BLOCKER | Verify before implementation; may need Aave governance proposal |
| Aave V4 BUSL license conflict | MEDIUM | HIGH | Use minimal interface (IAaveV4Spoke), don't import V4 source |
| Spoke function signatures differ from research | MEDIUM | MEDIUM | Verify via `forge install aave/aave-v4` before coding |
| Ethereum-only limits deployment | LOW | LOW | Design chain-agnostic, deploy ETH-only initially |

## Open Questions (To Resolve in Phase 0)

| # | Question | Status |
|---|----------|--------|
| 1 | Can Superform smart accounts call Spoke directly, or is Position Manager registration needed? | OPEN |
| 2 | What is the exact approval target (Spoke or Hub)? | OPEN — likely Spoke |
| 3 | How to derive borrow amount in SupplyAndBorrow? Oracle query? Off-chain computed? | OPEN |
| 4 | Full repayment: does Aave V4 support `type(uint256).max` like V3? | OPEN |
| 5 | What are the exact deployed Spoke/Hub addresses on mainnet? | OPEN — check aave-address-book |

## References

- [Aave V4 GitHub](https://github.com/aave/aave-v4) (BUSL)
- [Aave V4 Docs](https://aave.com/docs/aave-v4)
- [Aave V4 Solidity Integration Guide](https://aave.com/docs/aave-v4/getting-started/solidity)
- [Aave Address Book](https://github.com/aave-dao/aave-address-book)
- Morpho hooks: `src/hooks/loan/morpho/` (reference implementation)
- Security research: `specs/aave-v4-hooks/research/evm-security.md`
- Repo analysis: `specs/aave-v4-hooks/research/repo-analysis.md`
