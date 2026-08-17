# EVM & DeFi Security Research for Euler V2 Lending Hooks

## Document Purpose

This document catalogs security vulnerabilities, exploit precedents, and recommended mitigations specifically relevant to implementing Euler V2 lending hooks in Superform v2-core. All findings are contextualized against the Superform hook execution model (ERC-7579 smart account modules, transient storage, build-then-execute pattern).

---

## 1. RELEVANT VULNERABILITY PATTERNS

### 1.1 Reentrancy Vectors in Lending Protocol Interactions

#### 1.1.1 EVC Callback Reentrancy

Euler V2's Ethereum Vault Connector (EVC) introduces a unique callback mechanism that differs from Morpho's and Aave's models. Key differences:

- **Morpho**: Has explicit callback data parameter (`onMorphoSupply`, `onMorphoRepay`, etc.). Superform's Morpho hooks explicitly pass empty callback data (`""`) to prevent reentrancy (see `BaseMorphoLoanHook.sol` line 17: "SECURITY INVARIANT: All Morpho calls MUST use empty callback data").
- **Euler V2 EVC**: Uses a different model. The EVC has `call()`, `batch()`, and `controlCollateral()` functions that can trigger callbacks. EVault operations (`deposit`, `borrow`, `repay`, `withdraw`) go through the EVC's `checkAccountStatus` and `checkVaultStatus` hooks after state changes.
- **Critical distinction**: EVault operations are NOT direct calls to the vault in all cases. The EVC wraps operations and enforces account/vault status checks AFTER the operation completes. This means:
  - During a `borrow()` call, the borrowed tokens are transferred BEFORE the account liquidity check
  - A malicious token transfer callback could theoretically re-enter before the liquidity check completes
  - However, the EVC uses a re-entrancy lock per account prefix (first 19 bytes of address), which prevents cross-vault reentrancy within the same account family

**Superform-specific mitigation**: The hook execution model provides strong reentrancy protection:
1. `BaseHook` uses pre/post execute mutexes (transient storage) that revert on double-entry
2. `SuperExecutorBase` inherits OpenZeppelin's `ReentrancyGuard`
3. Hook build functions are `view` -- they cannot modify state
4. The `validateHookCompliance` function ensures no in-between execution targets the hook itself (line 142 of `SuperExecutorBase.sol`)

**Risk assessment**: LOW for the Euler hooks, because:
- Hooks emit an execution array that runs linearly (no control-flow branching)
- The EVC's own reentrancy lock covers the EVault operations
- Superform's transient storage mutexes prevent hook re-entrance
- No callback data is passed to EVault operations (deposit/borrow/repay/withdraw take only asset amounts and addresses)

#### 1.1.2 Cross-Contract Reentrancy via ERC-4626 Callbacks

EVaults extend ERC-4626, which means `deposit()` and `withdraw()` call `transferFrom()` and `transfer()` on the underlying asset. If the underlying asset implements transfer hooks (e.g., ERC-777, ERC-1363), these could trigger reentrant calls.

**Attack scenario**:
1. Euler hook calls `collateralVault.deposit(primaryAmount, account)`
2. The collateral EVault calls `collateralAsset.transferFrom(account, vault, amount)`
3. If `collateralAsset` is an ERC-777 token, the `tokensReceived` hook fires
4. Attacker callback re-enters the smart account

**Mitigation**:
- Euler V2 EVaults internally use reentrancy protection
- Superform's `ReentrancyGuard` on `SuperExecutorBase` prevents re-entrance to the executor
- The EVC's account-level locks prevent re-entering vault operations for the same account
- **Recommendation**: Document that hooks assume non-reentrant underlying tokens (standard ERC-20). Fee-on-transfer and rebasing tokens are handled by the EVault wrapping layer, not the hook.

#### 1.1.3 Read-Only Reentrancy in View Functions

The `_buildHookExecutions` function is `view` and makes external calls to EVault view functions (`oracle()`, `unitOfAccount()`, `interestRateModel()`, `getControllers()`, `debtOf()`). Read-only reentrancy occurs when a protocol's view function returns stale/manipulated data during an in-progress state change.

**Specific risks for Euler hooks**:
- `IEVault(controllerVault).debtOf(account)` could return a stale value if called mid-operation
- `IEVault(controllerVault).accountLiquidity(account, true)` depends on oracle prices AND current debt state

**Mitigation**:
- `_buildHookExecutions` is called BEFORE execution begins (build phase), so there is no concurrent state mutation
- The actual validation happens in `_postExecute`, which runs AFTER all EVault operations complete
- **Recommendation**: Perform all critical state checks (debt verification, liquidity checks) in `_postExecute`, not in `_buildHookExecutions`. The build function should only validate static config (oracle/IRM addresses) and construct the execution array.

### 1.2 Token Approval Patterns and Front-Running Risks

#### 1.2.1 Approval Reset Pattern (approve-0-approve-N-action-approve-0)

The existing Morpho and Aave hooks use a triple-approval pattern:
```
[0] approve(token, spender, 0)         // reset any lingering approval
[1] approve(token, spender, amount)    // set exact approval
[2] protocol.operation(amount)         // execute
[3] approve(token, spender, 0)         // clean up approval
```

**Why the initial reset is necessary**: Some ERC-20 tokens (notably USDT) revert if `approve()` is called with a non-zero value when the current allowance is also non-zero. The `approve(0)` call first clears any residual allowance.

**For Euler hooks specifically**:
- The **collateral deposit** approves `collateralAsset` to the `collateralVault` (EVault is ERC-4626, pulls tokens via `transferFrom`)
- The **repay** approves `debtAsset` to the `controllerVault` (EVault's `repay()` pulls tokens via `transferFrom`)
- Both MUST follow the triple-approval pattern

**Front-running risk**: Between the `approve(amount)` and the `deposit()/repay()` call, a front-runner could call `transferFrom()` on the smart account's approval. However, since the smart account is an ERC-7579 module-based account, only installed executor modules can initiate transfers. External actors cannot directly call `transferFrom` on the approval.

**Risk assessment**: NEGLIGIBLE. The smart account model prevents external exploitation of temporary approvals. The approval reset after the operation is still mandatory as defense-in-depth.

#### 1.2.2 SafeERC20 Considerations

The existing Morpho and Aave hooks use raw `IERC20.approve()` calls in their execution arrays, not `SafeERC20.safeApprove()`. This is intentional because:
- Executions are batched calldata arrays, not direct Solidity calls
- The hook builds `Execution` structs with `abi.encodeCall(IERC20.approve, ...)` -- these are raw calldata
- SafeERC20 protection happens at the call site (the executor), not in the hook builder
- If an approval fails (e.g., USDT revert), the entire UserOp reverts -- which is the desired behavior

**Recommendation**: Follow the same pattern as existing hooks. Use `abi.encodeCall(IERC20.approve, ...)` in execution arrays. Do NOT try to use SafeERC20 library calls in the execution array construction.

### 1.3 Oracle Manipulation in Lending Contexts

#### 1.3.1 Euler V2 Oracle Architecture

Euler V2 uses a pluggable oracle system where each EVault has a configured oracle and unit of account:
- `IEVault(vault).oracle()` returns the oracle address
- `IEVault(vault).unitOfAccount()` returns the unit of account (e.g., USD, ETH)
- The oracle provides price feeds used for collateral valuation and liquidation thresholds

**Attack vector: Oracle configuration drift**

Between strategy sizing (off-chain) and execution (on-chain), the vault governance could change the oracle, unit of account, or IRM. This could result in:
- A suddenly unfavorable liquidation threshold
- Incorrect debt valuation
- Unexpected interest rate changes

**Mitigation (already in spec)**:
- The hook data layout includes `expectedOracle`, `expectedUnitOfAccount`, `expectedIRM`
- `_buildHookExecutions` validates these match the current vault config
- If any mismatch is detected, the hook reverts with `ORACLE_MISMATCH()`, `UNIT_OF_ACCOUNT_MISMATCH()`, or `IRM_MISMATCH()`
- This is a CRITICAL security feature that prevents execution under unexpected market conditions

**Implementation note**: These validation calls (`oracle()`, `unitOfAccount()`, `interestRateModel()`) are made in the `view` build function. Since the build and execute happen within the same transaction (EntryPoint.handleOps), there is no TOCTOU (time-of-check-time-of-use) gap. If governance changes the oracle in the same block, the build function will catch it.

#### 1.3.2 Price Manipulation via Flash Loans

Flash loans can temporarily manipulate AMM-based oracle prices. For Euler V2:
- Euler V2 oracles are typically Chainlink-based or use TWAP mechanisms
- Direct spot price manipulation is unlikely with Chainlink oracles
- However, if a custom oracle is used (Euler V2 allows arbitrary oracles), flash loan manipulation is possible

**Superform hook mitigation**:
- The `maxLiquidationCapacityUtilizationBps` cap limits how much of the liquidation buffer can be consumed
- The `maxPostDebt` cap provides an absolute ceiling on total debt
- These caps are set by the strategy sizer and cannot be exceeded even with manipulated prices
- The config validation (expectedOracle) ensures the hook only operates with the intended oracle

**Risk assessment**: MEDIUM for hooks using non-Chainlink oracles. The hook's config validation and cap parameters provide defense-in-depth.

### 1.4 Flash Loan Attack Vectors Against Lending Positions

#### 1.4.1 Debt Front-Running (P1-2 Pattern)

This is the same pattern documented in Morpho and Aave hooks:

**Attack**: An attacker front-runs a full repayment transaction by repaying 1 wei of debt shares on behalf of the victim. This causes the victim's full repayment to either:
- Over-approve (the approval was computed for the original debt, which is now 1 wei less)
- Fail validation checks (if the hook checks for exact share counts)

**Euler V2 specifics**:
- `IEVault.repay(assets, receiver)` repays debt in asset units, not shares
- Anyone can call `repay()` on behalf of another account (the `receiver` parameter specifies whose debt to reduce)
- Unlike Morpho, Euler V2 does not expose share-level repayment in the standard interface
- Interest accrues per-block, so the debt amount changes between `build()` and execution

**Mitigation**:
- For full repayment: Read `debtOf(account)` in `_buildHookExecutions` (view) to get the current debt
- Approve for `debtOf(account)` amount (this may be slightly stale by execution time)
- In `_postExecute`, verify `debtOf(account) == 0` for full repayment
- If the approval is insufficient due to interest accrual, the repay will revert (safe failure)
- **Recommendation**: Document as KNOWN LIMITATION (P1-2) in the hook NatSpec, consistent with existing hooks

#### 1.4.2 Liquidation Capacity Manipulation

**Attack scenario**:
1. Strategy sizer computes that an account can safely borrow X at the current collateral value
2. Attacker flash-manipulates the oracle price, reducing collateral value
3. Hook executes borrow, but now the account is near liquidation
4. Attacker immediately liquidates the position for profit

**Mitigation**:
- `maxLiquidationCapacityUtilizationBps` limits how close to liquidation the position can get
- The EVC's `checkAccountStatus` (called automatically after borrow) will revert if health factor is below 1
- The `_postExecute` liquidation capacity check provides an additional safety layer
- Oracle config validation prevents unexpected oracle changes

**Risk assessment**: LOW. Multiple layers of protection prevent this attack.

### 1.5 Cross-Contract Reentrancy Through EVC Batching

The EVC supports batched operations via `batch()`. If the Euler hooks inadvertently trigger a batch through the EVC (e.g., by calling `enableCollateral` + `enableController` + `borrow` in a way that triggers deferred checks), the EVC may call back into the account to verify status.

**Key EVC behavior**:
- `enableCollateral()` and `enableController()` are simple state updates with no callbacks
- `borrow()` triggers `checkAccountStatus()` on the EVC after the operation
- `checkAccountStatus()` calls the controller vault's `checkAccountStatus(address, address[])` function
- This is a callback FROM the EVC TO the controller vault, not to the account

**Superform safety model**: Since hook executions are linear calldata arrays executed by the smart account, there is no way for the EVC's status check callback to re-enter the hook execution flow. The status check happens within the EVault/EVC context, not the smart account context.

**Risk assessment**: NEGLIGIBLE for the Superform hook architecture.

---

## 2. EXPLOIT PRECEDENTS

### 2.1 Euler Finance March 2023 Exploit ($197M)

**What happened**:
- The exploit targeted Euler V1 (NOT V2). Euler V2 was designed specifically to prevent this class of attack.
- The attacker used a flash loan to:
  1. Deposit collateral into an Euler V1 market
  2. Borrow against the collateral
  3. Use the `donateToReserves()` function to destroy their own collateral shares
  4. This created an undercollateralized position that could be self-liquidated profitably
  5. The profit came from the liquidation discount on the manipulated position

**Root cause**: The `donateToReserves()` function allowed users to reduce their own collateral without a corresponding debt reduction. This broke the invariant that positions must remain collateralized.

**Relevance to Euler V2 hooks**:
- Euler V2 removed `donateToReserves()` entirely
- Euler V2's EVC enforces account status checks after EVERY operation that could affect solvency
- The EVC's controller model ensures that only one controller vault can enforce liquidity rules, preventing conflicting rules
- **Our hooks' controller invariant check** (`getControllers(account).length <= 1`) directly prevents multi-controller attacks

**Lesson applied**: The Euler hooks should:
1. Always validate controller uniqueness before enabling a new controller
2. Never include operations that could unilaterally reduce collateral without debt reduction
3. Verify post-execution solvency via `accountLiquidity()` or `debtOf()` checks

### 2.2 Compound Oracle Manipulation (2022)

**What happened**: Compound V2 was exploited when the COMP token oracle provided manipulated prices. An attacker manipulated the price upward, borrowed against inflated collateral, and profited when the price corrected.

**Relevance**: The Euler hooks include config validation (`expectedOracle`, `expectedUnitOfAccount`, `expectedIRM`) that prevents execution with an unexpected oracle. This is a direct defense against oracle substitution attacks.

**Lesson applied**: Always validate oracle identity at execution time, not just at strategy configuration time.

### 2.3 Interest Accrual Timing Attacks (General Lending)

**Pattern**: In many lending protocols, interest accrues lazily (only when a function is called that triggers accrual). This creates a window where:
- `debtOf()` returns stale (lower) debt
- The actual debt at repayment time is higher
- Approval amounts computed from stale debt are insufficient

**Euler V2 specifics**:
- EVault has a `touch()` function that triggers interest accrual
- `debtOf()` returns the accrued debt (it computes interest on-the-fly in the view function)
- However, the accrued debt in the view function may differ slightly from the actual debt at execution time if blocks pass between build and execution

**How Morpho handles this**: The `MorphoRepayHook._preExecute()` explicitly calls `accrueInterest(marketParams)` before the repay operation to ensure the debt snapshot is current.

**Recommendation for Euler hooks**:
- For the repay hook: The `debtOf()` function already returns accrued debt, but there can still be a gap between build-time and execution-time
- For full repayment: Read `debtOf(account)` at build time, approve for that amount, and verify zero debt in `_postExecute`
- Document as KNOWN LIMITATION (P1-3) consistent with existing hooks
- The bundler should execute UserOps promptly to minimize the interest accrual gap

### 2.4 EVC-Specific: Operator and Sub-Account Attacks

**Euler V2 EVC feature**: The EVC supports operators (delegated accounts that can act on behalf of users) and sub-accounts (derived addresses sharing the same account prefix).

**Attack vector**: If the Euler hooks allowed arbitrary operators or sub-accounts, an attacker could:
1. Register as an operator for a victim's account
2. Use the operator permission to modify collateral/debt positions
3. Extract value through controlled position manipulation

**Mitigation (from spec Section 3.1)**: "Reject subaccounts, operators, alternate owners." The hooks:
- Always use `account` (the smart account address) as the identity for ALL operations
- Never accept operator parameters from calldata
- Never derive sub-accounts
- The `onBehalfOf` / `receiver` parameter is always hardcoded to `account`

### 2.5 Euler V1 Donation Attack Pattern and V2 Prevention

**Euler V1 vulnerability**: The donation attack allowed users to artificially create bad debt by "donating" their collateral shares to the protocol reserves. This bypassed the collateral adequacy check.

**How Euler V2 prevents this**:
- No `donateToReserves()` function
- All operations that modify collateral or debt trigger `checkAccountStatus()`
- The EVC enforces that accounts remain solvent after every state-changing operation
- Controller vaults define the solvency rules (LTV, liquidation threshold)

**Hook design implication**: The execution array must never include operations that could bypass the EVC's solvency checks. All operations should go through the standard EVault interfaces (`deposit`, `withdraw`, `borrow`, `repay`).

---

## 3. ATTACK SURFACE MAP FOR EULER HOOKS

### 3.1 Approval Reset Pattern Security

**Surface**: Token approvals granted during hook execution.

**Attack vector**: Dangling approvals after failed or partial execution.

**Current protection** (matching Morpho/Aave patterns):
```
[0] approve(token, vault, 0)        // Clear any lingering approval
[1] approve(token, vault, amount)   // Set exact approval for operation
... operation ...
[N] approve(token, vault, 0)        // Reset approval after operation
```

**Euler-specific consideration**: Two different approval targets exist:
- `collateralAsset -> collateralVault` (for deposit)
- `debtAsset -> controllerVault` (for repay)

If the execution array reverts mid-way (e.g., after deposit approval but before borrow), the approval persists until the next execution. However, since the smart account is the only entity that can use the approval, and the EntryPoint reverts the entire UserOp on failure, this is safe.

**Recommendation**: Follow the exact same triple-approval pattern as existing hooks. Place the final `approve(0)` AFTER the last operation using that approval.

### 3.2 Controller Invariant Violations

**Surface**: The EVC's controller model allows zero or one controller per account.

**Attack scenario**:
1. Strategy A opens position with controllerVault A
2. Before Strategy A closes, Strategy B tries to open position with controllerVault B
3. If the hook does not check for existing controllers, controllerVault B is enabled alongside A
4. Conflicting liquidation rules could allow either strategy to be exploited

**Current protection** (from spec Section 3.1):
```solidity
address[] memory controllers = IEVC(vars.evc).getControllers(account);
if (controllers.length > 0 && controllers[0] != vars.controllerVault) {
    revert CONTROLLER_ALREADY_SET();
}
```

**Implementation detail**: This check runs in `_buildHookExecutions` (view). Since `getControllers()` is a view function reading EVC state, and the build happens before execution, this correctly prevents the open hook from proceeding if a different controller is already set.

**Edge case**: What if `enableController()` is called for the SAME controller that is already enabled? This is idempotent (safe). What if it is called for a DIFFERENT controller? The EVC's `enableController()` itself may or may not prevent this (depends on the EVC implementation). The hook MUST validate this explicitly regardless.

### 3.3 Liquidation Capacity Manipulation

**Surface**: The `maxLiquidationCapacityUtilizationBps` parameter controls how close to liquidation a position can be pushed.

**Attack vector**:
1. Strategy sizes a borrow at 50% of liquidation capacity (maxLiqCapUtilBps = 5000)
2. Between sizing and execution, collateral price drops 10%
3. The borrow now consumes 55% of liquidation capacity at execution
4. The post-execution check in `_postExecute` should catch this

**Critical check**:
```solidity
// In _postExecute:
(uint256 liabilityValue, uint256 collateralValue) =
    IEVault(controllerVault).accountLiquidity(account, true);
if (liabilityValue * 10_000 > collateralValue * maxLiqCapUtilBps) {
    revert LIQUIDATION_CAPACITY_EXCEEDED();
}
```

**Important**: This check uses `liquidation = true` parameter to get the liquidation-adjusted collateral value (using liquidation LTV, not borrow LTV). This is the correct approach since we want to ensure the position is safe from liquidation.

**Potential issue**: The `accountLiquidity` function may have a different signature than assumed. It needs verification against the actual Euler V2 EVK source. If the function does not exist as expected, an alternative approach using `debtOf()` + oracle prices must be implemented.

### 3.4 Debt Accounting Drift Between Sizing and Execution

**Surface**: The gap between off-chain strategy sizing and on-chain execution.

**Drift sources**:
1. **Interest accrual**: Debt grows per-second based on the IRM
2. **Price changes**: Collateral/debt asset prices change
3. **External actions**: Other users' deposits/withdrawals affect utilization rates and interest
4. **Front-running**: MEV bots can sandwich the UserOp execution

**Mitigation hierarchy**:
1. `maxPostDebt` cap provides an absolute ceiling (primary defense)
2. `maxLiquidationCapacityUtilizationBps` provides relative safety margin
3. `expectedOracle/IRM/UnitOfAccount` validation ensures expected market conditions
4. `usePrevHookAmount = false` prevents cascading drift from chained hooks (launch constraint)
5. The bundler should minimize latency between sizing and execution

### 3.5 Config Validation Bypass Scenarios

**Surface**: The hook validates oracle/IRM/unitOfAccount configuration at build time.

**Bypass scenario 1: Same-block governance change**
- Vault governance changes the oracle in the same block as the UserOp
- The build function checks the oracle BEFORE the governance tx
- The execution runs AFTER the governance tx

**Analysis**: This cannot happen within a single `handleOps` call because `build()` and the execution array run in sequence within the same transaction. The oracle check in `_buildHookExecutions` reads the oracle address and the execution uses the same vault. If governance changes the oracle in a separate transaction within the same block but BEFORE the UserOp, the build function catches it.

**Bypass scenario 2: Malicious vault**
- A malicious vault returns the expected oracle address from `oracle()` but internally uses a different price source

**Analysis**: This is outside the hook's threat model. The hook trusts that the vault contract faithfully implements its interface. The strategy sizer is responsible for only configuring trusted vault addresses.

### 3.6 Full Repayment Race Conditions

**Surface**: Full repayment requires reading current debt, approving that amount, and repaying.

**Race condition**:
1. `_buildHookExecutions` reads `debtOf(account) = 1000 USDC`
2. Between build and execution, interest accrues to `1000.001 USDC`
3. The approval was set for `1000 USDC` (from build)
4. `repay(1000, account)` succeeds but leaves `0.001 USDC` residual debt
5. `_postExecute` check `debtOf(account) == 0` fails

**Mitigation options**:
- **Option A**: Over-approve by a buffer (e.g., 1% above current debt). Risky if the buffer is too large.
- **Option B**: Use `type(uint256).max` as repay amount (if EVault supports it). Euler V2's `repay()` with `type(uint256).max` repays the full debt (needs verification).
- **Option C**: Accept the race condition and document it as KNOWN LIMITATION (P1-3). The bundler should minimize latency.
- **Option D**: Call `repay(type(uint256).max, account)` but approve for `debtOf(account) + buffer`. This requires the EVault's `repay()` to accept `type(uint256).max` as "repay all".

**Recommendation**: Use Option B/D if the EVault supports `type(uint256).max` repayment. Otherwise, use Option C (consistent with Morpho/Aave hooks which document P1-3). The Morpho repay hook uses share-level repayment for full repay, which is the cleanest approach but requires share access.

### 3.7 Repay-Only Leaf Abuse

**Surface**: The spec requires a permanent repay-only leaf with `secondaryAmount = 0`.

**Potential abuse**: Could an attacker craft calldata with `secondaryAmount = 0` to trigger a repay-only execution when a full repay+withdraw was intended?

**Analysis**: This is not an attack vector because:
- The calldata is constructed by the bundler and signed by the user
- The Merkle root validates the exact calldata
- An attacker cannot modify the calldata without invalidating the signature
- The repay-only leaf is intentionally a safety mechanism for emergency debt repayment

---

## 4. RECOMMENDED SECURITY PATTERNS

### 4.1 SafeERC20 Usage

**Pattern**: Do NOT use SafeERC20 in execution array construction. Use raw `abi.encodeCall(IERC20.approve, ...)`.

**Rationale**: Consistent with all existing Superform hooks (Morpho, Aave V3, Aave V4). The execution array is calldata that the smart account executes -- SafeERC20 wrapping happens implicitly at the execution layer if needed. All existing hooks use raw IERC20 calls.

### 4.2 Checks-Effects-Interactions Pattern Compliance

The hook execution model inherently follows CEI:

1. **Checks**: `_buildHookExecutions` (view) validates all inputs, config, and invariants
2. **Effects**: The execution array modifies state (approvals, deposits, borrows) through the smart account
3. **Interactions**: External protocol calls happen within the execution array

Additional CEI in `_preExecute` / `_postExecute`:
- `_preExecute`: Store pre-state snapshots (balances, debt) -- this is "checks" for the post-execution validation
- Execution array: All state changes and interactions
- `_postExecute`: Verify post-state invariants (debt limits, liquidity capacity) -- this is "checks" on the effects

**Pattern to follow**:
```solidity
function _preExecute(address, address account, bytes calldata data) internal override {
    // ONLY store snapshots -- no external interactions
    _setOutAmount(IERC20(debtAsset).balanceOf(account), account);
}

function _postExecute(address, address account, bytes calldata data) internal override {
    // ONLY verify invariants and set outputs
    uint256 preBalance = getOutAmount(account);
    uint256 postBalance = IERC20(debtAsset).balanceOf(account);
    // ... validate deltas, set outAmount/outToken
}
```

### 4.3 Transient Storage Safety

**How Superform uses transient storage**:
- `BaseHook` stores execution context (outAmount, outToken, pre/post execute mutexes) in transient storage
- Keys are derived from `keccak256(HOOK_EXECUTION_STORAGE, context, offset)` where context is a per-execution nonce
- Transient storage is cleared at the end of the transaction (EIP-1153)

**Safety guarantees**:
1. **Isolation**: Each hook instance has its own transient storage keys (derived from the hook's address and execution nonce)
2. **Atomicity**: If the UserOp reverts, all transient storage changes are reverted
3. **No persistence**: Transient storage cannot leak between transactions
4. **Mutex protection**: `PRE_EXECUTE_ALREADY_CALLED` and `POST_EXECUTE_ALREADY_CALLED` errors prevent re-entrance

**Euler hook consideration**: The hooks only use the standard transient storage slots (outAmount, outToken). No custom transient storage is needed beyond what `BaseHook` provides.

**Limitation**: Only one outAmount value can be stored per execution context. For the composite hooks with two amounts (primaryAmount for collateral, secondaryAmount for borrow), the choice of what to store as outAmount must be deliberate:
- **Open hook**: Store debt asset (USDC) balance as outAmount. This tracks the borrowed amount.
- **Repay hook**: Store collateral asset balance as outAmount. This tracks the released collateral.
- This matches the pattern in `AaveV3SupplyAndBorrowHook` and `AaveV3RepayAndWithdrawHook`.

### 4.4 View Function Safety in _buildHookExecutions

`_buildHookExecutions` is marked `view` and MUST NOT:
- Modify any storage (compiler-enforced)
- Rely on transient storage values (transient storage is set during execution, not build)
- Assume mutable state between calls (the function may be called multiple times for simulation)

`_buildHookExecutions` CAN safely:
- Make external `view` calls (`debtOf`, `oracle()`, `getControllers()`, etc.)
- Perform pure computations (amount calculations, offset decoding)
- Read immutable variables

**CRITICAL**: The spec's config validation (oracle/IRM/unitOfAccount check) is safe in `_buildHookExecutions` because:
1. The build and execute happen within the same `handleOps` transaction
2. No state changes occur between build and the start of execution
3. The external view calls read current on-chain state

**EXCEPTION**: For `debtOf()` used in full repayment, the value may be stale by the time execution reaches the `repay()` call (interest accrues per-second). This is the P1-3 limitation, not a build-function safety issue.

---

## 5. TESTING RECOMMENDATIONS

### 5.1 Specific Fuzz Test Scenarios

#### 5.1.1 Amount Fuzzing

```
testFuzz_openHook_primaryAmountRange(uint256 primaryAmount)
- Bound: 1 wei to type(uint128).max (EVault may use uint128 internally)
- Verify: Execution array correctly encodes the amount
- Verify: Approval matches primaryAmount exactly
- Verify: deposit calldata contains primaryAmount

testFuzz_openHook_secondaryAmountRange(uint256 secondaryAmount)
- Bound: 1 wei to type(uint128).max
- Verify: borrow calldata contains secondaryAmount
- Verify: outAmount in postExecute matches expected borrow output

testFuzz_repayHook_repayAmount(uint256 primaryAmount, uint256 currentDebt)
- Bound: primaryAmount in [1, type(uint128).max], currentDebt in [1, type(uint128).max]
- Verify: Partial repay uses min(primaryAmount, currentDebt)
- Verify: Full repay uses currentDebt (not primaryAmount)
```

#### 5.1.2 Data Layout Fuzzing

```
testFuzz_decodeAmounts_roundtrip(uint256 amt1, uint256 amt2)
- Build data with amt1/amt2 at correct offsets
- decodeAmounts should return [amt1, amt2]
- replaceCalldataAmounts with new values should work
- Verify round-trip: build -> decode -> replace -> decode == new values

testFuzz_dataLength_boundary(uint256 extraBytes)
- Build data with length = MIN_DATA_LENGTH + extraBytes
- Should succeed for extraBytes >= 0
- Should revert for data shorter than MIN_DATA_LENGTH
```

#### 5.1.3 Config Validation Fuzzing

```
testFuzz_configMismatch(address fuzzOracle, address fuzzUnit, address fuzzIRM)
- Set expected values to specific addresses
- Fuzz the actual vault return values
- Verify: Reverts with correct error when any field mismatches
- Verify: Succeeds only when all three match
```

### 5.2 Invariants to Validate

#### 5.2.1 Execution Array Invariants

```
invariant_executionArray_startsWithApproveZero
- For all valid input data, executions[0] must be approve(token, vault, 0)

invariant_executionArray_endsWithApproveZero
- The last non-postExecute execution must be approve(token, vault, 0) (for repay path)
- OR the last operation-specific execution resets approval

invariant_approvalAmount_matchesOperationAmount
- The approval amount in executions[1] must exactly match the amount used in the operation

invariant_noSelfTargeting
- No execution in the array (excluding index 0 and last) targets the hook contract itself
- This is enforced by SuperExecutorBase.validateHookCompliance but should be verified in unit tests

invariant_receiverIsAlwaysAccount
- deposit(amount, RECEIVER) -> RECEIVER == account
- borrow(amount, RECEIVER) -> RECEIVER == account
- repay(amount, RECEIVER) -> RECEIVER == account
- withdraw(amount, RECEIVER, OWNER) -> RECEIVER == account, OWNER == account
```

#### 5.2.2 State Invariants

```
invariant_postExecute_setsOutAmount
- After postExecute, getOutAmount(account) returns a meaningful value

invariant_postExecute_setsOutToken
- After postExecute, getOutToken(account) returns a non-zero address

invariant_controllerUniqueness
- After open hook execution, getControllers(account).length <= 1
- If getControllers(account).length == 1, controllers[0] == controllerVault

invariant_fullRepay_zeroDebt
- After full repayment, debtOf(account) == 0

invariant_liquidationCapacity_respected
- After open hook: liabilityValue * 10_000 <= collateralValue * maxLiqCapUtilBps
- After repay+withdraw hook: same check with maxRemainingLiqCapUtilBps
```

### 5.3 Edge Cases for Amounts

#### 5.3.1 Zero Amount Tests

```
test_openHook_zeroPrimaryAmount_reverts
- primaryAmount = 0 should revert with AMOUNT_NOT_VALID

test_openHook_zeroSecondaryAmount_reverts
- secondaryAmount = 0 should revert with AMOUNT_NOT_VALID

test_repayHook_zeroPrimaryAmount_reverts
- primaryAmount = 0 (no repay amount) should revert

test_repayHook_zeroSecondaryAmount_repayOnly
- secondaryAmount = 0 should produce repay-only execution (4 executions, no withdraw)
- Should NOT revert -- this is the valid repay-only path
```

#### 5.3.2 Maximum Amount Tests

```
test_openHook_maxUint256_primaryAmount
- primaryAmount = type(uint256).max
- Should correctly encode in calldata (may revert at execution on insufficient balance)

test_repayHook_fullRepayment_maxDebt
- currentDebt near type(uint128).max
- Verify approval and repay amounts are correct
```

#### 5.3.3 Dust Amount Tests

```
test_openHook_dustAmount_deposit
- primaryAmount = 1 (1 wei)
- Verify: EVault may round down to 0 shares -- hook should still produce valid calldata
- The EVault's deposit function handles dust amounts

test_repayHook_dustDebt_fullRepay
- currentDebt = 1 (1 wei of debt)
- Full repayment should work correctly
```

#### 5.3.4 Mismatched Amount Tests

```
test_repayHook_primaryExceedsMaxRepay_reverts
- primaryAmount > maxRepayAssets should revert

test_repayHook_secondaryExceedsMaxRelease_reverts
- secondaryAmount > maxCollateralReleaseAssets should revert
```

### 5.4 Integration Test Scenarios (Fork Tests)

```
test_fork_openAndClose_fullCycle
1. Open position: deposit 1000 USDC as collateral, borrow 500 of some debt asset
2. Verify collateral balance, debt balance, controller enabled
3. Close position: full repay, full withdraw
4. Verify zero debt, zero collateral balance, controller disabled

test_fork_partialRepay_maintains_position
1. Open position
2. Partial repay (50% of debt)
3. Partial withdraw (proportional collateral)
4. Verify remaining debt and collateral

test_fork_multipleOpens_sameController
1. Open position with controller A
2. Open position again with controller A (should succeed -- idempotent)
3. Verify position increased correctly

test_fork_multipleOpens_differentController_reverts
1. Open position with controller A
2. Attempt to open with controller B
3. Should revert with CONTROLLER_ALREADY_SET

test_fork_configValidation_rejectsWrongOracle
1. Build calldata with expectedOracle = address(1)
2. Real vault has different oracle
3. Build should revert with ORACLE_MISMATCH

test_fork_repayOnly_noWithdraw
1. Open position
2. Repay with secondaryAmount = 0
3. Verify debt reduced, collateral unchanged
4. No controller disable (debt still exists)
```

### 5.5 Attack Simulation Tests

```
test_attack_frontRunFullRepay
1. Open position with 1000 USDC debt
2. Build full repay calldata (approval for 1000 USDC)
3. Simulate front-runner repaying 1 wei on behalf of victim
4. Execute victim's repay
5. Verify: Either succeeds (debt was 999.999... and approval covers it) or fails gracefully

test_attack_reentrantToken
1. Deploy mock ERC-20 with transfer callback
2. Use as collateral asset
3. Open position
4. Verify: Execution completes without reentrancy issues

test_attack_malformedCalldata
1. Build calldata with length < MIN_DATA_LENGTH
2. Verify: Reverts with INVALID_DATA_LENGTH

test_attack_usePrevHookAmountTrue_reverts
1. Build calldata with usePrevHookAmount = true
2. Verify: Reverts with USE_PREV_HOOK_AMOUNT_NOT_SUPPORTED

test_attack_excessiveMaxLiqCapUtilBps
1. Build calldata with maxLiqCapUtilBps = 10001 (> 100%)
2. Verify: Reverts or is handled safely
```

---

## 6. ADDITIONAL SECURITY CONSIDERATIONS

### 6.1 EVault Interface Verification

**CRITICAL**: The `accountLiquidity` function signature in the implementation plan (`accountLiquidity(address account, bool liquidation)`) has NOT been verified against the actual Euler V2 EVK source code. Before implementation:

1. Verify the exact function signature at Euler V2 EVK commit `5b98b42048ba11ae82fb62dfec06d1010c8e41e6`
2. If `accountLiquidity` does not exist as a view function on the EVault, alternative approaches:
   - Compute liquidity manually from `debtOf(account)` + oracle prices + collateral values
   - Use the EVC's `checkAccountStatus()` (but this may not be a view function)
   - Use the RiskManager or a separate lens contract if available

### 6.2 disableController Caller Semantics

The spec mentions "call the selected controller EVault wrapper's disableController()". This implies:
- The EVault has a `disableController()` function (no args, acts on msg.sender)
- This internally calls `IEVC(evc).disableController(msg.sender)`
- The msg.sender in the execution context is the smart account

Verify whether:
- `IEVault.disableController()` exists (acts on msg.sender internally)
- Or only `IEVC(evc).disableController(account)` exists (requires explicit account parameter)

### 6.3 Gas Considerations for View Calls

The `_buildHookExecutions` function makes multiple external view calls:
- `IEVC(evc).getControllers(account)` - array return, potentially expensive
- `IEVault(controllerVault).oracle()` - single address return
- `IEVault(controllerVault).unitOfAccount()` - single address return
- `IEVault(controllerVault).interestRateModel()` - single address return
- `IEVault(controllerVault).debtOf(account)` - uint256 return (for full repayment)

These view calls are gas-consuming but necessary for security. The gas cost is borne by the UserOp sender (through the paymaster). This is acceptable because:
- Security validation is non-negotiable
- The calls are all simple reads (no computation)
- Total added gas is estimated at 10-15k (5 external calls * 2-3k each)

### 6.4 ERC-7579 Module Security Model

Hooks execute as part of the smart account's module execution flow:
1. EntryPoint validates UserOp signature via SuperValidator
2. SuperValidator verifies Merkle proof of the operation
3. SuperExecutor (installed module) processes the hook chain
4. Each hook's execution array runs as delegate calls from the smart account

This means:
- The smart account IS the msg.sender for all EVault/EVC calls
- Token approvals are from the smart account to the vault
- The smart account is the collateral holder and debtor
- Only the installed executor module can trigger hook execution

**Security implication**: No external actor can trigger hook execution outside of the validated UserOp flow. This eliminates entire classes of attacks (unauthorized borrowing, unauthorized withdrawals, etc.).

---

## 7. SECURITY CHECKLIST FOR IMPLEMENTATION

- [ ] Triple-approval pattern (0-N-0) for all token approvals
- [ ] `receiver` / `onBehalfOf` hardcoded to `account` (never from calldata)
- [ ] Controller uniqueness validation before `enableController`
- [ ] Config validation (oracle/IRM/unitOfAccount) in `_buildHookExecutions`
- [ ] Post-execution debt ceiling check (`maxPostDebt`)
- [ ] Post-execution liquidation capacity check (`maxLiqCapUtilBps`)
- [ ] Full repayment zero-debt verification in `_postExecute`
- [ ] `usePrevHookAmount = false` enforcement (launch constraint)
- [ ] Data length validation (`>= MIN_DATA_LENGTH`)
- [ ] All addresses validated non-zero
- [ ] Inspector returns only addresses (no amounts/booleans)
- [ ] `decodeAmounts` and `replaceCalldataAmounts` correctly handle dual amounts
- [ ] Repay-only path (`secondaryAmount == 0`) skips withdrawal and release-config validation
- [ ] KNOWN LIMITATION (P1-2) documented: front-run full repayment
- [ ] KNOWN LIMITATION (P1-3) documented: interest accrual between build and execute
- [ ] `disableController` called only at zero debt
- [ ] No callback data passed to EVault operations
- [ ] No EVC batch/call operations used (direct vault calls only)
- [ ] Custom errors defined for each validation failure
- [ ] Events emitted for key state changes (if applicable)
