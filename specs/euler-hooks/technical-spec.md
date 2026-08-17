# Euler V2 Lending Hooks Technical Specification

## Overview

Build a complete set of Euler V2 lending hooks for Superform v2-core that mirror the existing Morpho hook architecture. This includes 4 individual hooks, 2 composite hooks, 2 vendor interfaces, and 2 corrected Morpho V2 composite hooks. All hooks follow the Aave V3 deployment pattern (no constructor args) with protocol addresses sourced from calldata.

## Problem Statement

Superform v2-core currently supports lending protocol interactions via Morpho and Aave V3 hooks. Euler V2 (EVK/EVC architecture) is a growing lending protocol deployed across multiple chains. To support Euler-based yield strategies (e.g., SuperStocks with NVDAc/SPCXc/TSLAc collateral and USDC borrowing), the system needs hooks that:

1. Deposit collateral into Euler EVaults and borrow debt assets via the EVC controller model
2. Repay debt and withdraw collateral with full-repayment and cleanup support
3. Validate position health via `accountLiquidity` and enforce liquidation capacity caps
4. Provide individual hooks for granular strategy composition

Additionally, the existing Morpho composite hooks have known issues with amount derivation (LTV-based instead of independent) and repayment handling that need correction.

## Proposed Solution

Create 8 new Solidity contracts and 2 vendor interfaces following established patterns:

**Euler Hooks** (inherit `BaseLoanHook` directly, no constructor args):
1. `EulerDepositCollateralHook` - Individual collateral deposit
2. `EulerBorrowHook` - Individual borrow
3. `EulerRepayHook` - Individual repay
4. `EulerWithdrawCollateralHook` - Individual collateral withdrawal
5. `EulerDepositCollateralAndBorrowHook` - Composite open/increase position
6. `EulerRepayAndWithdrawHook` - Composite repay/release position

**Morpho V2 Corrections**:
7. `MorphoSupplyAndBorrowHookV2` - Independent exact amounts (not LTV-derived)
8. `MorphoRepayAndWithdrawHookV2` - Post-accrual full repayment, capped repay-only

**Vendor Interfaces**:
9. `src/vendor/euler/IEVC.sol` - Minimal EVC interface
10. `src/vendor/euler/IEVault.sol` - Minimal EVault interface

## Technical Approach

### Architecture

All Euler hooks inherit `BaseLoanHook` directly (no `BaseEulerLoanHook` abstract base) following the rationale that both composite hooks share offset constants but decode differently, making an abstraction layer unnecessary.

**Deployment pattern**: Aave V3 style - no constructor arguments. EVC and vault addresses come from calldata, enabling a single deployment per chain to work with any Euler market.

**Amount model**: Composite hooks use dual amounts (`primaryAmount` + `secondaryAmount`), matching `AaveV3SupplyAndBorrowHook` pattern. Individual hooks use the default single amount from `BaseLoanHook`.

### Data Layout

#### Shared Prefix (All Euler Hooks - 197 bytes minimum)

| Offset | Type | Field | BaseLoanHook Mapping |
|--------|------|-------|---------------------|
| 0 | bytes32 | configId | placeholder0 |
| 32 | address | collateralVault | placeholder1/yieldSource |
| 52 | address | debtAsset | loanToken (AMOUNT_POSITION parent) |
| 72 | address | collateralAsset | collateralToken (parent) |
| 92 | address | evc | - |
| 112 | address | controllerVault | - |
| 132 | uint256 | primaryAmount | AMOUNT_POSITION (132) |
| 164 | uint256 | secondaryAmount | - |
| 196 | bool | usePrevHookAmount | USE_PREV_HOOK_AMOUNT_POSITION (196) |

#### Individual Hook Layout Variations

**EulerDepositCollateralHook** (single amount):
- Uses only `primaryAmount` at offset 132 = collateral deposit amount
- `secondaryAmount` field present but unused (set to 0)
- No tail data needed beyond shared prefix

**EulerBorrowHook** (single amount):
- Uses only `primaryAmount` at offset 132 = borrow amount
- No tail data needed beyond shared prefix

**EulerRepayHook** (single amount):
- Uses only `primaryAmount` at offset 132 = repay amount
- Tail at offset 197: `bool isFullRepayment`
- Total: 198 bytes minimum

**EulerWithdrawCollateralHook** (single amount):
- Uses only `primaryAmount` at offset 132 = withdraw amount
- No tail data needed beyond shared prefix

#### Composite Hook Tails

**EulerDepositCollateralAndBorrowHook Tail** (offset 197+):

| Offset | Type | Field |
|--------|------|-------|
| 197 | uint256 | maxPostDebt |
| 229 | uint256 | maxLiqCapUtilBps |
| 261 | address | expectedOracle |
| 281 | address | expectedUnitOfAccount |
| 301 | address | expectedIRM |

Total: 321 bytes minimum.

**EulerRepayAndWithdrawHook Tail** (offset 197+):

| Offset | Type | Field |
|--------|------|-------|
| 197 | bool | isFullRepayment |
| 198 | uint256 | maxRepayAssets |
| 230 | uint256 | maxCollateralReleaseAssets |
| 262 | uint256 | maxRemainingLiqCapUtilBps |
| 294 | address | expectedReleaseOracle |
| 314 | address | expectedReleaseUnitOfAccount |
| 334 | address | expectedReleaseIRM |

Total: 354 bytes minimum.

### Vendor Interfaces

#### IEVC.sol (Corrected from API Verification)

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

/// @title IEVC - Minimal Ethereum Vault Connector interface for Superform hooks
/// @notice Only the functions needed by Euler lending hooks
interface IEVC {
    function enableCollateral(address account, address vault) external;
    function enableController(address account, address vault) external;
    function disableCollateral(address account, address vault) external;
    function getControllers(address account) external view returns (address[] memory);
    function getCollaterals(address account) external view returns (address[] memory);
    function isCollateralEnabled(address account, address vault) external view returns (bool);
    function isControllerEnabled(address account, address vault) external view returns (bool);
    // NOTE: disableController(address) is NOT included.
    // It is only callable by the controller vault itself, not by accounts.
}
```

#### IEVault.sol (Corrected from API Verification)

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

/// @title IEVault - Minimal Euler V2 EVault interface for Superform hooks
interface IEVault {
    // ERC-4626 compatible
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    // Lending-specific
    function borrow(uint256 assets, address receiver) external returns (uint256 shares);
    function repay(uint256 assets, address receiver) external returns (uint256 shares);

    // Controller management
    /// @notice Release the account from being controlled by this vault.
    /// @dev Only callable by the account itself. Account must have zero debt.
    function disableController() external;

    // View functions
    function debtOf(address account) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function asset() external view returns (address);
    function oracle() external view returns (address);
    function unitOfAccount() external view returns (address);
    function interestRateModel() external view returns (address);

    /// @notice Get account's collateral and liability values
    /// @return collateralValue Total weighted collateral value in unit of account
    /// @return liabilityValue Total liability value in unit of account
    /// @dev CRITICAL: collateral is returned FIRST, liability SECOND
    function accountLiquidity(address account, bool liquidation)
        external view returns (uint256 collateralValue, uint256 liabilityValue);

    function LTVFull(address collateral) external view returns (
        uint16 borrowLTV, uint16 liquidationLTV, uint16 initialLiquidationLTV,
        uint48 targetTimestamp, uint32 rampDuration
    );
    function maxWithdraw(address owner) external view returns (uint256);
    function cash() external view returns (uint256);
    function caps() external view returns (uint16 supplyCap, uint16 borrowCap);
    function totalBorrows() external view returns (uint256);
    function debtOfExact(address account) external view returns (uint256);
}
```

### Implementation Phases

#### Phase 1: Vendor Interfaces + Individual Hooks

**Deliverables:**
1. `src/vendor/euler/IEVC.sol`
2. `src/vendor/euler/IEVault.sol`
3. `src/hooks/loan/euler/EulerDepositCollateralHook.sol`
4. `src/hooks/loan/euler/EulerBorrowHook.sol`
5. `src/hooks/loan/euler/EulerRepayHook.sol`
6. `src/hooks/loan/euler/EulerWithdrawCollateralHook.sol`

**Success criteria:**
- All hooks compile with `forge build`
- Unit tests pass for data decoding, execution array construction, and error cases

**EulerDepositCollateralHook** (mirrors MorphoSupplyHook):
```
Executions (4):
[0] approve(collateralAsset, collateralVault, 0)
[1] approve(collateralAsset, collateralVault, primaryAmount)
[2] collateralVault.deposit(primaryAmount, account)
[3] approve(collateralAsset, collateralVault, 0)

_preExecute: _setOutAmount(collateralAsset.balanceOf(account), account)
_postExecute: delta = pre - post; _setOutAmount(delta); _setOutToken(collateralAsset)
```

**EulerBorrowHook** (mirrors MorphoBorrowHook):
```
Pre-checks in _buildHookExecutions:
- Validate controller: getControllers(account).length must be 0 or [controllerVault]
- enableCollateral + enableController calls included (idempotent)

Executions (3):
[0] evc.enableCollateral(account, collateralVault)
[1] evc.enableController(account, controllerVault)
[2] controllerVault.borrow(primaryAmount, account)

_preExecute: _setOutAmount(debtAsset.balanceOf(account), account)
_postExecute: delta = post - pre; _setOutAmount(delta); _setOutToken(debtAsset)
```

**EulerRepayHook** (mirrors MorphoRepayHook):
```
Executions - Partial repay (4):
[0] approve(debtAsset, controllerVault, 0)
[1] approve(debtAsset, controllerVault, primaryAmount)
[2] controllerVault.repay(primaryAmount, account)
[3] approve(debtAsset, controllerVault, 0)

Executions - Full repay (5):
[0] approve(debtAsset, controllerVault, 0)
[1] approve(debtAsset, controllerVault, currentDebt)
[2] controllerVault.repay(currentDebt, account)
[3] approve(debtAsset, controllerVault, 0)
[4] controllerVault.disableController()  // NO ARGS

_preExecute: _setOutAmount(debtAsset.balanceOf(account), account)
_postExecute: delta = pre - post; _setOutAmount(delta); _setOutToken(debtAsset)
  For full repay: verify debtOf(account) == 0
```

**EulerWithdrawCollateralHook** (mirrors MorphoWithdrawHook for collateral):
```
Executions (1):
[0] collateralVault.withdraw(primaryAmount, account, account)

_preExecute: _setOutAmount(collateralAsset.balanceOf(account), account)
_postExecute: delta = post - pre; _setOutAmount(delta); _setOutToken(collateralAsset)
```

#### Phase 2: Composite Hooks

**Deliverables:**
1. `src/hooks/loan/euler/EulerDepositCollateralAndBorrowHook.sol`
2. `src/hooks/loan/euler/EulerRepayAndWithdrawHook.sol`

**Success criteria:**
- Dual-amount decoding/replacing works correctly
- Config validation (oracle/IRM/unitOfAccount) reverts on mismatch
- Liquidation capacity checks enforce caps
- Repay-only path (secondaryAmount=0) produces correct execution array
- Full repayment includes controller disable

**EulerDepositCollateralAndBorrowHook** (composite open/increase):
```
Pre-checks in _buildHookExecutions:
- Validate usePrevHookAmount == false (launch constraint)
- Validate data length >= 321
- Validate controller invariant: getControllers(account).length == 0 || [controllerVault]
- Config validation: oracle(), unitOfAccount(), interestRateModel() match expected values

Executions (7):
[0] approve(collateralAsset, collateralVault, 0)
[1] approve(collateralAsset, collateralVault, primaryAmount)
[2] collateralVault.deposit(primaryAmount, account)
[3] evc.enableCollateral(account, collateralVault)
[4] evc.enableController(account, controllerVault)
[5] controllerVault.borrow(secondaryAmount, account)
[6] approve(collateralAsset, collateralVault, 0)

_preExecute: _setOutAmount(debtAsset.balanceOf(account), account)
_postExecute:
  - delta = debtAsset.balanceOf(account) - pre
  - _setOutAmount(delta, account)
  - _setOutToken(debtAsset, account)
  - Validate: maxPostDebt check via debtOf(account)
  - Validate: liquidation capacity via accountLiquidity(account, true)
    (collateralValue, liabilityValue) -- collateral FIRST
    liabilityValue * 10_000 <= collateralValue * maxLiqCapUtilBps
```

**EulerRepayAndWithdrawHook** (composite repay/release):
```
Pre-checks in _buildHookExecutions:
- Validate usePrevHookAmount == false
- Validate data length >= 354
- If secondaryAmount > 0: validate release config (oracle/IRM/unitOfAccount)
- Determine repay amount:
  - If isFullRepayment: repayAmount = debtOf(account) via controllerVault
  - Else: repayAmount = min(primaryAmount, maxRepayAssets)
- Validate primaryAmount <= maxRepayAssets (unless full repay)

Executions - Partial repay + withdraw (5):
[0] approve(debtAsset, controllerVault, 0)
[1] approve(debtAsset, controllerVault, repayAmount)
[2] controllerVault.repay(repayAmount, account)
[3] approve(debtAsset, controllerVault, 0)
[4] collateralVault.withdraw(secondaryAmount, account, account)

Executions - Full repay + withdraw + cleanup (6):
[0] approve(debtAsset, controllerVault, 0)
[1] approve(debtAsset, controllerVault, currentDebt)
[2] controllerVault.repay(currentDebt, account)
[3] approve(debtAsset, controllerVault, 0)
[4] collateralVault.withdraw(secondaryAmount, account, account)
[5] controllerVault.disableController()  // NO ARGS

Executions - Repay only (secondaryAmount=0) (4):
[0] approve(debtAsset, controllerVault, 0)
[1] approve(debtAsset, controllerVault, repayAmount)
[2] controllerVault.repay(repayAmount, account)
[3] approve(debtAsset, controllerVault, 0)

_preExecute: _setOutAmount(collateralAsset.balanceOf(account), account)
_postExecute:
  - delta = collateralAsset.balanceOf(account) - pre
  - _setOutAmount(delta, account)
  - _setOutToken(collateralAsset, account)
  - If isFullRepayment: verify debtOf(account) == 0
  - If secondaryAmount > 0: validate remaining liquidation capacity
    (collateralValue, liabilityValue) = accountLiquidity(account, true)
    liabilityValue * 10_000 <= collateralValue * maxRemainingLiqCapUtilBps
```

#### Phase 3: Morpho V2 Corrections

**Deliverables:**
1. `src/hooks/loan/morpho/MorphoSupplyAndBorrowHookV2.sol`
2. `src/hooks/loan/morpho/MorphoRepayAndWithdrawHookV2.sol`

**Success criteria:**
- MorphoSupplyAndBorrowHookV2: Independent exact collateral input + exact borrow output (not LTV-derived)
- MorphoRepayAndWithdrawHookV2: Post-accrual full repayment, capped repay-only under drift
- Unit tests demonstrate corrected behavior vs V1

**Key differences from V1:**
- `MorphoSupplyAndBorrowHookV2`: Both `primaryAmount` (collateral) and `secondaryAmount` (borrow) are independent exact values from calldata. No `deriveLoanAmount()` oracle/LTV calculation. The OMS sizes both amounts independently.
- `MorphoRepayAndWithdrawHookV2`: Full repayment uses post-accrual debt amount. Under interest drift, repay amount is capped to available balance rather than reverting.

#### Phase 4: Tests

**Deliverables:**
1. `test/unit/hooks/loan/EulerLoanHooks.t.sol` - Unit tests with mocks
2. `test/integration/euler/EulerLoanHooksFork.t.sol` - Fork tests against real Euler V2

**Unit tests** (inherit `Helpers`, use MockEVC/MockEVault):
- Data encoding/decoding roundtrip for all 6 hooks
- Execution array length and content for each hook variant
- `decodeAmounts()` and `replaceCalldataAmounts()` for dual-amount hooks
- Config validation error cases (oracle/IRM/unitOfAccount mismatch)
- Controller invariant enforcement
- `usePrevHookAmount = true` rejection
- Data length boundary tests
- `inspect()` return values
- Repay-only path (secondaryAmount=0) for RepayAndWithdrawHook
- Full repay includes disableController execution
- Zero amount reverts

**Fork tests** (inherit `Helpers`, use `vm.createSelectFork`):
- Full lifecycle: open position -> partial repay -> full close
- Config validation against real vault configuration
- Controller uniqueness enforcement
- Liquidation capacity cap validation
- Interest accrual behavior verification

#### Phase 5: Deployment Integration

**Files to modify:**
1. `script/utils/Constants.sol` - Add 8 hook key constants (6 Euler + 2 Morpho V2)
2. `script/DeployV2OtherHooks.s.sol` - Add Euler hooks section (no constructor args)
3. `script/run/regenerate_bytecode.sh` - Add 8 contract names
4. `script/utils/ConstantsOtherHooks.sol` - Add EVC addresses per chain (if needed)

**Success criteria:**
- `forge build` succeeds with new deployment script
- Bytecode regeneration includes all new hooks

## Alternative Approaches Considered

1. **BaseEulerLoanHook abstract base**: Rejected per interview. Both composite hooks share offset constants but decode differently. An abstraction layer adds complexity without benefit since individual hooks have simple enough layouts.

2. **Constructor args (Morpho pattern)**: Rejected. The Aave V3 pattern (protocol address from calldata) is preferred for Euler because it enables single deployment per chain for any EVC/EVault pair.

3. **EVC `call()` routing**: Rejected. The implementation plan initially considered routing all EVault calls through `IEVC.call()` for deferred status checks. Direct EVault calls from the smart account are simpler, more gas-efficient, and provide stronger safety (immediate health checks after each operation).

4. **Share-based repayment**: Euler V2 `repay()` accepts assets (not shares). Unlike Morpho which supports both, Euler always uses asset amounts. For full repayment, `debtOf(account)` returns accrued debt in assets.

## Attack Surface Analysis

### Token Compatibility

| Token Type | Risk | Mitigation | Vuln DB Ref |
|------------|------|------------|-------------|
| Fee-on-transfer | Balance mismatch | Not applicable -- EVault handles internally | 10.1 |
| Rebasing | Share accounting drift | Not applicable -- EVault wrapping handles | 10.2 |
| Missing return values | Silent transfer failure | SafeERC20 via BaseHook; raw encodeCall in exec array is safe | 10.3 |
| USDT (non-standard approve) | approve() reverts | Triple-approval pattern (0-N-0) | 10.3 |
| Pausable/blocklist | DoS on withdrawals | Known risk, outside hook scope | 10.5 |

### Reentrancy Vectors

| Vector | Applies? | Pattern | Mitigation |
|--------|----------|---------|------------|
| Single-function (1.1) | No | CEI violation | BaseHook pre/post mutexes |
| Cross-function (1.2) | No | Shared state | Transient storage isolation per context |
| Cross-contract (1.3) | Low | EVC callback | EVC reentrancy lock + SuperExecutor ReentrancyGuard |
| Read-only (1.4) | No | View during callback | Build is view, executes before mutations |
| ERC callback (1.5) | Low | Token transfer hooks | EVC lock + transient storage mutexes |

### Oracle & Price Risks
- [x] Oracle manipulation resistance: Config validation (`expectedOracle`) prevents oracle substitution
- [x] Price manipulation via flash loans: `maxLiqCapUtilBps` caps exposure; Chainlink-based oracles resist flash manipulation
- [x] Stale price handling: Euler EVault's oracle handles staleness internally
- [x] Configuration drift: `expectedOracle`, `expectedUnitOfAccount`, `expectedIRM` validated at build time (same transaction)

### Flash Loan & MEV
- [x] Single-transaction exploitation: `maxPostDebt` + `maxLiqCapUtilBps` provide absolute/relative caps
- [x] Debt front-running (P1-2): Documented known limitation -- attacker can front-run full repayment by repaying 1 wei
- [x] Interest accrual drift (P1-3): Documented known limitation -- debt changes between build and execute
- [x] Sandwich attacks: Strategy sizer parameters cap exposure; config validation prevents stale execution

### Exploit Precedent Check

| Similar Protocol | Exploit | Loss | Relevance | Our Mitigation |
|-----------------|---------|------|-----------|----------------|
| Euler V1 | donateToReserves() self-liquidation | $197M | Euler V2 removes donateToReserves; EVC enforces solvency checks | Controller uniqueness + post-exec liquidity validation |
| Compound V2 | Oracle price manipulation | ~$100M | Oracle substitution attack | expectedOracle config validation at build time |
| General lending | Interest accrual timing | Various | Stale debt values | debtOf() returns accrued values; P1-3 documented |

## Acceptance Criteria

### Functional Requirements
- [ ] All 6 Euler hooks compile and deploy (no constructor args)
- [ ] Individual hooks: deposit, borrow, repay, withdraw execute correctly against Euler V2
- [ ] Composite hooks: deposit+borrow and repay+withdraw execute correctly
- [ ] Config validation rejects oracle/IRM/unitOfAccount mismatches
- [ ] Controller uniqueness enforced (revert if different controller already set)
- [ ] Full repayment includes `disableController()` cleanup
- [ ] Repay-only path (secondaryAmount=0) works for emergency repayment
- [ ] `usePrevHookAmount = true` reverts for all hooks (launch constraint)
- [ ] `decodeAmounts()` returns correct 1-element (individual) or 2-element (composite) arrays
- [ ] `replaceCalldataAmounts()` correctly replaces amounts at expected offsets
- [ ] `inspect()` returns packed address data for config identification
- [ ] Both Morpho V2 corrected hooks work with independent exact amounts

### Non-Functional Requirements
- [ ] Gas cost comparable to Aave V3 hooks (5 external calls in build, ~10-15k additional gas)
- [ ] No storage slots used (transient storage only via BaseHook)

### Security Requirements
- [ ] Triple-approval pattern (0-N-0) for all token approvals
- [ ] `receiver`/`onBehalfOf` hardcoded to `account` (never from calldata)
- [ ] Post-execution debt ceiling check (`maxPostDebt`)
- [ ] Post-execution liquidation capacity check (`maxLiqCapUtilBps`)
- [ ] Full repayment zero-debt verification in `_postExecute`
- [ ] Data length validation
- [ ] All addresses validated non-zero
- [ ] `accountLiquidity` return order: `(collateralValue, liabilityValue)` -- collateral FIRST
- [ ] `disableController()` called on EVault with NO params (not EVC)

### Quality Gates
- [ ] `forge build` succeeds with no warnings
- [ ] Unit tests pass (data decoding, execution arrays, error cases)
- [ ] Fork tests pass against real Euler V2 deployment
- [ ] NatSpec documentation on all public/external functions
- [ ] Known limitations (P1-2, P1-3) documented in NatSpec

## Success Metrics
- All 6 Euler hooks deploy and function on chains where Euler V2 is available
- Fork tests demonstrate full lifecycle (open -> partial operations -> full close)
- Both Morpho V2 corrected hooks pass regression tests against V1 behavior

## Dependencies & Prerequisites
- Euler V2 EVK deployed on target chains (Base confirmed, others per networks-prod/networks-staging)
- EVC address: `0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383` (same on all chains via CREATE2)
- EVault addresses for fork tests (discoverable on-chain via EVC queries)
- `accountLiquidity(address, bool)` function signature must be verified via `cast interface` against live deployment before finalizing

## Risk Analysis & Mitigation

| Risk | Category | Likelihood | Impact | Mitigation |
|------|----------|------------|--------|------------|
| `accountLiquidity` signature differs from expected | API | Low | High | Verify via `cast interface` before implementation; fallback to manual debt/collateral calculation |
| Interest accrual between build and execute | Business Logic | Medium | Low | Documented P1-3; bundler minimizes latency |
| Front-run full repayment | MEV | Low | Low | Documented P1-2; residual debt is tiny |
| Controller conflict (multiple strategies) | Access Control | Medium | Medium | Controller uniqueness check in `_buildHookExecutions` |
| Oracle/IRM governance change between signing and execution | Operational | Low | High | Config validation reverts on mismatch |

## Implementation

### File Structure

```
src/
├── vendor/euler/
│   ├── IEVC.sol
│   └── IEVault.sol
├── hooks/loan/euler/
│   ├── EulerDepositCollateralHook.sol
│   ├── EulerBorrowHook.sol
│   ├── EulerRepayHook.sol
│   ├── EulerWithdrawCollateralHook.sol
│   ├── EulerDepositCollateralAndBorrowHook.sol
│   └── EulerRepayAndWithdrawHook.sol
├── hooks/loan/morpho/
│   ├── MorphoSupplyAndBorrowHookV2.sol
│   └── MorphoRepayAndWithdrawHookV2.sol
test/
├── unit/hooks/loan/
│   ├── EulerLoanHooks.t.sol
│   └── MorphoV2LoanHooks.t.sol
├── integration/euler/
│   └── EulerLoanHooksFork.t.sol
├── mocks/
│   ├── MockEVC.sol
│   └── MockEVault.sol
script/
├── utils/Constants.sol (modify)
├── utils/ConstantsOtherHooks.sol (modify)
├── DeployV2OtherHooks.s.sol (modify)
└── run/regenerate_bytecode.sh (modify)
```

### Key Implementation Patterns

**Offset constants** (shared across all Euler hooks):
```solidity
uint256 internal constant COLLATERAL_VAULT_OFFSET = 32;
uint256 internal constant DEBT_ASSET_OFFSET = 52;        // = BaseLoanHook LOAN_TOKEN
uint256 internal constant COLLATERAL_ASSET_OFFSET = 72;  // = BaseLoanHook COLLATERAL_TOKEN
uint256 internal constant EVC_OFFSET = 92;
uint256 internal constant CONTROLLER_VAULT_OFFSET = 112;
uint256 internal constant PRIMARY_AMOUNT_OFFSET = 132;    // = BaseLoanHook AMOUNT_POSITION
uint256 internal constant SECONDARY_AMOUNT_OFFSET = 164;
uint256 internal constant USE_PREV_OFFSET = 196;          // = BaseLoanHook USE_PREV_HOOK_AMOUNT_POSITION
```

**Dual-amount sizing interface** (composite hooks):
```solidity
function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
    amounts = new uint256[](2);
    amounts[0] = BytesLib.toUint256(data, PRIMARY_AMOUNT_OFFSET);
    amounts[1] = BytesLib.toUint256(data, SECONDARY_AMOUNT_OFFSET);
}

function amountRoles(bytes memory) external pure override
    returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
    meta = new ISuperHookInflowOutflow.AmountMeta[](2);
    meta[0] = ISuperHookInflowOutflow.AmountMeta(Direction.IN, Denomination.TOKEN);
    meta[1] = ISuperHookInflowOutflow.AmountMeta(Direction.OUT, Denomination.TOKEN);
}

function replaceCalldataAmounts(bytes memory data, uint256[] memory amounts)
    external pure override returns (bytes memory) {
    if (amounts.length != 2) revert INVALID_AMOUNTS_LENGTH();
    BytesLib.replaceUint256(data, PRIMARY_AMOUNT_OFFSET, amounts[0]);
    BytesLib.replaceUint256(data, SECONDARY_AMOUNT_OFFSET, amounts[1]);
    return data;
}
```

## Critical API Corrections (from Research)

These corrections were identified during API verification research and MUST be applied:

1. **`accountLiquidity` return order**: Returns `(collateralValue, liabilityValue)` -- collateral FIRST, liability SECOND. The initial implementation plan had them reversed.

2. **`disableController` pattern**: Called on the EVault with NO parameters (`IEVault(controllerVault).disableController()`). The EVC's `disableController(address)` is only callable by the controller vault itself. The account calls the EVault's parameterless version.

3. **IEVC should NOT include `disableController(address)`**: We never call it directly.

4. **IEVC should include `disableCollateral(address, address)`**: For full cleanup after position close.

5. **No EVC `call()` routing needed**: Direct EVault calls work correctly in the ERC-7579 execution model.

6. **Interest accrual is automatic**: Euler V2 accrues interest in every state-changing operation. No explicit `accrueInterest()` step needed (unlike Morpho).

## Future Considerations

- `usePrevHookAmount = true` support may be enabled post-launch for chained hook scenarios
- Additional individual hooks (e.g., EulerLendHook for supply-side interest) may follow the same pattern as MorphoLendHook
- Collateral cleanup (`disableCollateral`) could be added as a post-close optimization
- If `accountLiquidity` is unavailable, a manual health calculation using `debtOf` + oracle prices is the fallback

## References & Research

### Internal References
- Morpho hooks architecture: `src/hooks/loan/morpho/BaseMorphoLoanHook.sol`
- Aave V3 no-constructor pattern: `src/hooks/loan/aave-v3/BaseAaveV3LoanHook.sol`
- Dual-amount pattern: `src/hooks/loan/aave-v3/AaveV3SupplyAndBorrowHook.sol`
- Base hook lifecycle: `src/hooks/BaseHook.sol`
- Deployment script: `script/DeployV2OtherHooks.s.sol`
- Hook constants: `script/utils/Constants.sol`

### External References
- Euler V2 EVK: `euler-xyz/euler-vault-kit` commit `5b98b42048ba11ae82fb62dfec06d1010c8e41e6`
- Euler V2 EVC: `euler-xyz/ethereum-vault-connector` commit `b9d557a8ebcd3db1fbeef4aa60282aa4059a7bbf`
- EVC deterministic address: `0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383`

### Research Files
- API verification: `specs/euler-hooks/research/euler-api-verification.md`
- Security analysis: `specs/euler-hooks/research/evm-security.md`
- Repo architecture: `specs/euler-hooks/research/repo-analysis.md`
- Implementation plan: `.claude/doc/euler-hooks/implementation-plan.md`
- Session context: `.claude/sessions/context_session_26.md`
