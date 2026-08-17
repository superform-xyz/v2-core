# Euler Hooks - Interview Notes

## Date: 2026-08-16

## Feature Summary
Build a complete set of Euler V2 lending hooks for Superform v2-core, mirroring the existing Morpho hook architecture. Additionally, create corrected Morpho V2 composite hooks with improved amount handling.

## Scope

### Euler Hooks (6 hooks total)

**Individual Hooks (4):**
1. `EulerDepositCollateralHook` - Deposit collateral into EVault (mirrors Morpho SupplyCollateralHook)
2. `EulerBorrowHook` - Borrow from controller EVault (mirrors Morpho BorrowHook)
3. `EulerRepayHook` - Repay debt to controller EVault (mirrors Morpho RepayHook)
4. `EulerWithdrawCollateralHook` - Withdraw collateral from EVault (mirrors Morpho WithdrawCollateralHook)

**Composite Hooks (2):**
5. `EulerDepositCollateralAndBorrowHook` - Deposit collateral + borrow in one hook
6. `EulerRepayAndWithdrawHook` - Repay debt + withdraw collateral in one hook

**Vendor Interfaces (2):**
- `src/vendor/euler/IEVC.sol` - Minimal EVC interface
- `src/vendor/euler/IEVault.sol` - Minimal EVault interface

### Morpho V2 Corrected Hooks (2)
7. `MorphoSupplyAndBorrowHookV2` - Independent exact collateral input + exact borrow output (not derived from LTV)
8. `MorphoRepayAndWithdrawHookV2` - Post-accrual full repayment, capped repay-only under drift

## Technical Decisions

### Architecture
- **No constructor args** (Aave V3 pattern): EVC and vault addresses come from calldata, allowing single deployment per chain
- **No BaseEulerLoanHook abstract base**: Both hooks share offset constants but decode differently; avoid unnecessary abstraction
- **Two mutable amounts**: primaryAmount + secondaryAmount, matching AaveV3SupplyAndBorrowHook pattern
- **Direct BaseLoanHook inheritance**: AMOUNT_POSITION=132 and USE_PREV_HOOK_AMOUNT_POSITION=196 match spec layout
- **usePrevHookAmount = false enforced**: Launch constraint from spec

### Data Layout (Shared Prefix)
- Offset 0: bytes32 configId
- Offset 32: address collateralVault
- Offset 52: address debtAsset (= loanToken position)
- Offset 72: address collateralAsset (= collateralToken position)
- Offset 92: address evc
- Offset 112: address controllerVault
- Offset 132: uint256 primaryAmount
- Offset 164: uint256 secondaryAmount
- Offset 196: bool usePrevHookAmount

### Deployment Chains
- All chains where Euler V2 is available (from networks-prod and networks-staging configs)

### Testing Strategy
- Unit tests with mock contracts (MockEVC, MockEVault)
- Fork integration tests against real Euler V2 deployments (search for addresses on-chain)
- Inherits Helpers (not BaseTest) for unit tests

## Security Decisions

### Reentrancy
- Transient storage isolation between hooks handles cross-contract reentrancy concerns
- Euler EVaults use callbacks during operations, but the ERC-7579 execution model + transient storage provides sufficient protection

### MEV / Oracle Manipulation
- Strategy sizer + maxPostDebt + maxLiqCapUtilBps caps provide sufficient MEV protection
- expectedOracle/expectedUnitOfAccount/expectedIRM validation at execution time guards against configuration drift
- No additional slippage parameters needed for V1

### Critical Implementation Warnings
1. EVault `repay` approval target = controllerVault (not EVC)
2. EVault `deposit` approval target = collateralVault
3. EVC enable calls are idempotent (safe to always include)
4. Zero-or-one controller invariant must be enforced
5. `accountLiquidity` function signature NOT YET VERIFIED against Euler V2 EVK source
6. `disableController` caller pattern needs verification (EVault wrapper vs EVC direct)

### Token Compatibility
- Standard ERC-20 tokens handled via SafeERC20 (inherited from base hooks)
- Fee-on-transfer tokens: Not applicable (Euler vaults handle this internally)
- Rebasing tokens: Not applicable (EVault wrapping handles this)

### Access Control
- Hooks execute through smart account (ERC-7579 executor module)
- No admin functions on hooks themselves
- Config validation (oracle/unit/IRM) provides defense against misconfiguration

## Morpho V2 Corrections
- Session 26 notes are the complete scope for Morpho V2 corrections
- Independent exact collateral input + exact borrow output (not derived from LTV)
- Post-accrual full repayment, capped repay-only under drift

## Open Questions (Resolved)
| Question | Answer |
|----------|--------|
| Scope of hooks | Full Morpho mirror (6 Euler hooks) + 2 Morpho V2 corrections |
| Deployment chains | All chains where Euler is available |
| accountLiquidity API | Needs verification against Euler V2 EVK source |
| Reentrancy protection | Transient storage isolation (existing pattern) |
| MEV protection | Sizing + cap parameters sufficient |
| Testing approach | Unit tests + fork tests with discovered addresses |
