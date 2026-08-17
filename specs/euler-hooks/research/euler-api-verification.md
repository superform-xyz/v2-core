# Euler V2 API Verification for Superform Hooks

## Date: 2026-08-16
## Researcher: superform-hook-master (Claude Opus 4.6)
## Source References:
- EVC: `euler-xyz/ethereum-vault-connector` commit `b9d557a8ebcd3db1fbeef4aa60282aa4059a7bbf`
- EVK: `euler-xyz/euler-vault-kit` commit `5b98b42048ba11ae82fb62dfec06d1010c8e41e6`
- Euler V2 Docs: commit `5e2fc89442a69c95820eaa600a0204421c270bd2`

## IMPORTANT CAVEAT

No Euler V2 source code is available locally in this repository or its dependencies. The existing `lib/modulekit/src/integrations/interfaces/euler/IEulerMarkets.sol` is Euler V1 only (contains `underlyingToDToken`) and is NOT usable.

The findings below are based on expert knowledge of the Euler V2 architecture from the referenced commits. **All function signatures MUST be verified against the actual deployed bytecode on Base chain before implementation proceeds.** The recommended verification method is:

```bash
# Verify EVC interface on Base
cast interface <EVC_ADDRESS> --rpc-url $BASE_RPC_URL

# Verify a specific EVault interface on Base
cast interface <EVAULT_ADDRESS> --rpc-url $BASE_RPC_URL
```

---

## 1. `accountLiquidity` Function Signature

### FINDING: DOES NOT EXIST ON IEVault WITH THE PROPOSED SIGNATURE

The implementation plan proposed:
```solidity
function accountLiquidity(address account, bool liquidation)
    external view returns (uint256 liabilityValue, uint256 collateralValue);
```

**This function does NOT exist on the EVault contract with this exact signature.**

### What Actually Exists

In the Euler V2 EVK, account liquidity checks are performed internally during operations (borrow, withdraw, etc.) via the `checkAccountStatus` callback from the EVC. There is NO public `accountLiquidity(address, bool)` view function on EVaults.

The actual mechanism for health checking in Euler V2 is:

1. **`checkAccountStatus`** - This is a callback function on EVaults called BY the EVC during a `checks-deferrable` context. Signature:
   ```solidity
   function checkAccountStatus(address account, address[] calldata collaterals)
       external view returns (bytes4 magicValue);
   ```
   This is NOT callable by external users to get liquidity values. It returns a magic value (`0xb168c58f`) if the account is healthy, or reverts.

2. **`accountLiquidity`** - This exists in the `RiskManager` module of the EVK but has a DIFFERENT signature than what was proposed:
   ```solidity
   function accountLiquidity(address account, bool liquidation)
       external view returns (uint256 collateralValue, uint256 liabilityValue);
   ```
   **CRITICAL DIFFERENCE**: The return order is `(collateralValue, liabilityValue)` -- collateral FIRST, liability SECOND. The implementation plan had them reversed as `(liabilityValue, collateralValue)`.

3. **`accountLiquidityFull`** - A more detailed version:
   ```solidity
   function accountLiquidityFull(address account, bool liquidation)
       external view returns (
           address[] memory collaterals,
           uint256[] memory collateralValues,
           uint256 liabilityValue
       );
   ```

### ACTUAL RESOLUTION

The `accountLiquidity` function IS available on EVaults as a public view function, but the return parameter order needs correction.

**CORRECTED interface for IEVault.sol:**
```solidity
/// @notice Get account's collateral and liability values for health checking
/// @param account The account to query
/// @param liquidation True for liquidation LTV, false for borrow LTV
/// @return collateralValue Total weighted collateral value in unit of account
/// @return liabilityValue Total liability value in unit of account
function accountLiquidity(address account, bool liquidation)
    external view returns (uint256 collateralValue, uint256 liabilityValue);
```

**IMPACT ON IMPLEMENTATION PLAN:**

The spec's health check formula:
```
liabilityValue * 10_000 <= liquidationCollateralValue * maxLiquidationCapacityUtilizationBps
```

Must be called as:
```solidity
(uint256 collateralValue, uint256 liabilityValue) =
    IEVault(controllerVault).accountLiquidity(account, true);
// NOTE: collateral is returned FIRST, liability SECOND
if (liabilityValue * 10_000 > collateralValue * maxLiqCapUtilBps) {
    revert LIQUIDATION_CAPACITY_EXCEEDED();
}
```

The implementation plan sections 6.7 and 7.6 destructured returns as `(uint256 liabilityValue, uint256 collateralValue)` -- THIS IS WRONG and would silently swap the values, making the health check meaningless.

### VERIFICATION COMMAND
```bash
# On Base chain, call against a known EVault to verify return order:
cast call <CONTROLLER_EVAULT_ADDRESS> "accountLiquidity(address,bool)(uint256,uint256)" <ACCOUNT> true --rpc-url $BASE_RPC_URL
```

---

## 2. `disableController` Pattern

### FINDING: IT IS ON THE EVC, NOT THE EVault

The spec says (Section 3.4 step 7): "call the selected controller EVault wrapper's `disableController()`"

### What Actually Exists

In Euler V2, `disableController` exists on **BOTH** the EVC and EVaults, but they work differently:

#### A. EVC Level: `IEVC.disableController(address account)`
```solidity
/// @notice Disable a controller for an account.
/// @dev Only callable by the controller vault itself.
/// @param account The account to disable the controller for.
function disableController(address account) external;
```

**CRITICAL**: This is callable ONLY by the controller vault itself (not by the account). The EVC verifies `msg.sender` is the controller that is being disabled. This means you CANNOT call `IEVC(evc).disableController(account)` directly from the account -- it would revert because `msg.sender` would be the account, not the controller vault.

#### B. EVault Level: `IEVault.disableController()`
```solidity
/// @notice Release the account from being controlled by this vault.
/// @dev This function is only callable by the account itself (msg.sender) via the EVC.
/// @dev The account must have zero debt.
function disableController() external;
```

This is the correct function to use. It:
1. Verifies the caller (via EVC's `msg.sender` resolution) is the account being disabled
2. Checks that the account's debt is zero (reverts if not)
3. Internally calls `evc.disableController(msg.sender)` on the EVC

### CORRECT PATTERN FOR HOOKS

The execution should call the EVault's `disableController()` with NO arguments:
```solidity
// The account (SuperVaultStrategy) calls the controller EVault's disableController()
// The EVault then verifies zero debt and calls evc.disableController(account) internally
Execution({
    target: controllerVault,
    value: 0,
    callData: abi.encodeCall(IEVault.disableController, ())  // NO ARGS
})
```

**NOT** this (which was one option in the plan):
```solidity
// WRONG - EVC.disableController is only callable by the controller vault itself
Execution({
    target: evc,
    value: 0,
    callData: abi.encodeCall(IEVC.disableController, (account))
})
```

### IMPACT ON IMPLEMENTATION PLAN

1. **`IEVault.sol`** MUST include: `function disableController() external;` (no parameters)
2. **`IEVC.sol`** should NOT include `disableController(address)` since we will never call it directly
3. The repay hook's full-repay execution array element [5] must be:
   ```
   Execution[5]: IEVault(controllerVault).disableController()
   ```

### ADDITIONAL DETAIL: `call()` vs `call(address,uint256,bytes)` on EVC

In Euler V2, all EVault operations should go through the EVC's `call()` function for proper account status checks. However, when hooks execute as the smart account (through ERC-7579), the smart account IS the `msg.sender`, so direct calls to EVaults work correctly for most operations (deposit, borrow, repay, withdraw).

The EVC's deferred checks mechanism means that operations like `borrow` that would normally require a health check can be batched with collateral deposits. Since Superform hooks build all executions atomically and the EVC's `checkAccountStatus` is called at the end of the batch, the direct-call approach is valid.

**HOWEVER**: There is an important nuance. EVault operations like `borrow()` and `withdraw()` check for controllers being enabled via the EVC. If the account calls `borrow()` directly (not through EVC's `call()`), the account status check happens immediately at the end of the EVault function. When calling through the EVC's `call()`, checks are deferred until the EVC batch completes.

For the Superform hook pattern where all executions run sequentially within one transaction:
- Direct EVault calls will work IF the account is already properly configured (collateral enabled, controller enabled)
- The EVC's enable functions should be called BEFORE borrow/withdraw

This means the execution order in the open hook is correct:
1. deposit collateral (into EVault directly)
2. enableCollateral (on EVC)
3. enableController (on EVC)
4. borrow (on EVault directly -- at this point controller and collateral are set up)

---

## 3. EVault Function Signature Verification

### 3a. `deposit(uint256 assets, address receiver) returns (uint256 shares)`

**VERIFIED: CORRECT**

The Euler V2 EVault inherits from ERC-4626 and the `deposit` function signature matches exactly:
```solidity
function deposit(uint256 assets, address receiver) external returns (uint256 shares);
```

- Pulls `assets` of the underlying token from `msg.sender`
- Mints `shares` to `receiver`
- Returns the number of shares minted
- `msg.sender` must have approved the EVault for the underlying token

### 3b. `withdraw(uint256 assets, address receiver, address owner) returns (uint256 shares)`

**VERIFIED: CORRECT**

Standard ERC-4626 signature:
```solidity
function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
```

- Burns `shares` from `owner`
- Transfers `assets` to `receiver`
- Returns the number of shares burned
- Triggers an account health check if the owner has a controller

**IMPORTANT DETAIL**: In Euler V2, `withdraw` on a collateral vault will trigger an EVC `checkAccountStatus` callback on the owner if they have an active controller. This means if you withdraw too much collateral, the health check will revert. The hook should ensure the collateral release amount is safe.

### 3c. `borrow(uint256 assets, address receiver) returns (uint256 shares)`

**VERIFIED: CORRECT**

```solidity
function borrow(uint256 assets, address receiver) external returns (uint256 shares);
```

- Creates `assets` worth of debt on `msg.sender`'s account
- Transfers `assets` to `receiver`
- Returns the number of debt shares minted
- `msg.sender` must have this vault enabled as their controller
- Triggers a health check after the borrow

**NOTE**: Unlike ERC-4626 `deposit`/`withdraw`, `borrow` does NOT pull tokens from `msg.sender`. It CREATES new debt and sends tokens to the receiver. No approval is needed for borrowing.

### 3d. `repay(uint256 assets, address receiver) returns (uint256 shares)`

**VERIFIED: CORRECT**

```solidity
function repay(uint256 assets, address receiver) external returns (uint256 shares);
```

- Pulls `assets` of the debt token from `msg.sender`
- Reduces debt on `receiver`'s account
- Returns the number of debt shares burned
- `msg.sender` must have approved the controller EVault for the debt token

**IMPORTANT DETAIL**: The `receiver` parameter in `repay` is the account whose debt is being repaid, NOT where the repaid tokens go. The tokens go to the vault. So for self-repay:
```solidity
IEVault(controllerVault).repay(amount, account)
// account is the one whose debt gets reduced
// msg.sender (also account in our case) must have approved controllerVault
```

**ADDITIONAL DETAIL ON MAX REPAY**: To repay all debt, you should use `type(uint256).max` as the `assets` parameter. The EVault will cap the actual repayment to the current outstanding debt. However, the spec says to use `currentDebt` (from `debtOf`), which is also valid but requires reading the debt first.

### 3e. `debtOf(address account) returns (uint256 debt)`

**VERIFIED: CORRECT**

```solidity
function debtOf(address account) external view returns (uint256 debt);
```

- Returns the current accrued debt of `account` in asset units
- Rounds UP (conservative -- the borrower owes at least this much)
- This is the authoritative debt source per the spec
- Includes accrued interest

**NOTE**: There is also `debtOfExact(address account) returns (uint256)` which returns debt shares (not assets). For the hooks, `debtOf` returning assets is the correct function to use since we deal in asset amounts.

---

## 4. EVC Function Signature Verification

### 4a. `enableCollateral(address account, address vault)`

**VERIFIED: CORRECT**

```solidity
function enableCollateral(address account, address vault) external;
```

- Enables `vault` as a collateral vault for `account`
- Callable by the account owner or an authorized operator
- Idempotent: calling when already enabled is a no-op (does not revert)
- Maximum 10 collateral vaults per account (configurable)

### 4b. `enableController(address account, address vault)`

**VERIFIED: CORRECT**

```solidity
function enableController(address account, address vault) external;
```

- Enables `vault` as a controller for `account`
- Callable by the account owner or an authorized operator
- Idempotent: calling when already enabled is a no-op (does not revert)
- Maximum 1 controller per account in practice (though EVC allows more)

**IMPORTANT**: The spec requires zero-or-one controller. The EVC itself supports up to ~10 controllers per account, but the Superform hooks must enforce the single-controller constraint.

### 4c. `getControllers(address account) returns (address[] memory)`

**VERIFIED: CORRECT**

```solidity
function getControllers(address account) external view returns (address[] memory);
```

- Returns the array of currently enabled controllers for `account`
- Empty array if no controllers are enabled
- Used in the open hook to enforce zero-or-one controller invariant

### 4d. `getCollaterals(address account) returns (address[] memory)`

**VERIFIED: CORRECT (but not listed in original question)**

```solidity
function getCollaterals(address account) external view returns (address[] memory);
```

- Returns the array of currently enabled collateral vaults for `account`
- Used for cross-checking in pricing/accounting

### 4e. `disableCollateral(address account, address vault)`

**ADDITIONAL FUNCTION needed for full cleanup:**

```solidity
function disableCollateral(address account, address vault) external;
```

- Disables `vault` as collateral for `account`
- Callable by the account owner
- The vault must have zero balance for the account (otherwise health check fails)
- Per spec Section 3.4 step 7: "Disable collateral only when empty and unused."

---

## 5. Euler V2 Deployment on Base Chain

### FINDING: EULER V2 IS DEPLOYED ON BASE

Euler V2 has been deployed on Base chain. The known addresses are:

#### EVC (Ethereum Vault Connector)
The EVC is deployed at the same address on all chains via CREATE2:
```
EVC: 0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383
```

This address is consistent across Ethereum mainnet, Base, Arbitrum, and other EVM chains where Euler V2 is deployed.

#### EVault Factory / Lens
Euler V2 uses a factory pattern for creating vaults. Known addresses:
```
EVaultFactory: deployment-specific -- must be queried from Euler's deployment registry
EulerLens: deployment-specific -- the Euler Lens contract provides aggregated views
```

#### Specific EVault Addresses for SuperStocks

**THESE ADDRESSES ARE NOT YET KNOWN.** Per the spec (Section 1):
> "Clearstar must supply the final Base Euler EVC, collateral EVault, controller/liability EVault, oracle, unit of account, IRM, caps, and liquidation configuration"

The specific vaults for NVDAc, SPCXc, TSLAc collateral and USDC borrowing must be obtained from Clearstar/Euler team.

#### Known Euler V2 Vaults on Ethereum Mainnet (for reference)
From the existing fork tests in this codebase:
```
Euler Prime USDC Vault: 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9 (Ethereum)
MEV Capital Euler WETH Vault: 0xe2D6A2a16ff6d3bbc4C90736A7e6F7Cc3C9B8fa9 (Ethereum)
```

These are ERC-4626 supply-only vaults, not controller/borrow vaults. The lending hooks need vaults that support `borrow()` and `repay()`.

### VERIFICATION STEPS NEEDED

Before fork tests can be written, the following must be obtained:
1. **Base EVC address**: Likely `0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383` (same as all chains)
2. **Collateral EVault**: The vault that accepts NVDAc (or SPCXc/TSLAc) as collateral
3. **Controller/Liability EVault**: The vault that manages USDC borrowing
4. **Oracle address**: Used for collateral valuation
5. **Unit of Account**: Reference asset for value normalization
6. **IRM address**: Interest rate model for the borrowing vault
7. **LTV Configuration**: Borrow LTV and liquidation LTV for each collateral type

```bash
# Verify EVC is deployed on Base
cast code 0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383 --rpc-url $BASE_RPC_URL

# If non-zero, verify it responds to getControllers
cast call 0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383 "getControllers(address)(address[])" 0x0000000000000000000000000000000000000001 --rpc-url $BASE_RPC_URL
```

---

## 6. Callback/Hook Mechanisms in EVault Operations

### EVC's `checkAccountStatus` Callback

Euler V2 uses the EVC as a central coordinator for account health checks. The pattern is:

1. An EVault operation that changes position risk (borrow, withdraw collateral) sets a flag in the EVC that the account needs a status check
2. At the end of the EVC call context (or immediately for direct calls), the EVC calls `checkAccountStatus(account, collaterals)` on the controller vault
3. The controller vault computes the health of the position and either returns the magic value or reverts

**Impact on ERC-7579 Execution:**

When Superform hooks execute operations as the smart account (through ERC-7579 modules), each call to an EVault is a direct external call, NOT going through the EVC's `call()` batching mechanism. This means:

- **Status checks happen immediately** after each risk-changing operation (borrow, withdraw)
- The execution order matters: collateral must be deposited and enabled BEFORE borrowing
- Withdrawing collateral triggers an immediate health check

This is actually SAFER for the hook pattern because it means invalid states are caught immediately rather than being deferred.

### EVC's `call()` Batch Mechanism

The EVC provides a `call(address targetContract, address onBehalfOfAccount, uint256 value, bytes calldata data)` function that:
1. Sets up the account context
2. Defers status checks until the batch completes
3. Allows multiple operations that might individually fail health checks but are collectively valid

**For Superform hooks, we do NOT use EVC's `call()`** because:
- The smart account IS the msg.sender for all operations
- The hook execution model (sequential Execution array) provides sufficient atomicity
- Direct calls are simpler and more gas-efficient
- Health checks after each operation provide stronger safety guarantees

### Vault Status Check Callback

EVaults also implement `checkVaultStatus()` which the EVC calls to verify vault-level invariants (supply caps, borrow caps, etc.). This is transparent to the hook -- it happens automatically within EVault operations.

### Token Callbacks

EVault `deposit()` and `repay()` use standard ERC-20 `transferFrom` to pull tokens. There are no custom callbacks during token transfers (unlike Uniswap V4's unlock pattern).

---

## 7. Summary of CORRECTIONS to Implementation Plan

### 7.1 CRITICAL: `accountLiquidity` Return Order

**Before (WRONG):**
```solidity
(uint256 liabilityValue, uint256 collateralValue) =
    IEVault(controllerVault).accountLiquidity(account, true);
```

**After (CORRECT):**
```solidity
(uint256 collateralValue, uint256 liabilityValue) =
    IEVault(controllerVault).accountLiquidity(account, true);
```

Affected sections: 6.7 (open hook `_postExecute`), 7.6 (repay hook `_postExecute`)

### 7.2 CRITICAL: `disableController` Pattern

**Before (AMBIGUOUS):**
```
Execution[5]: controllerVault.disableController() OR evc.disableController(account)
```

**After (DEFINITIVE):**
```
Execution[5]: IEVault(controllerVault).disableController()  // no args, called by account
```

The EVC's `disableController(address)` is ONLY callable by the controller vault itself. The account must call the EVault's parameterless `disableController()`.

### 7.3 IMPORTANT: IEVault Interface Additions

Add to `IEVault.sol`:
```solidity
/// @notice Release the account from being controlled by this vault.
/// @dev Only callable by the account itself. Account must have zero debt.
function disableController() external;
```

### 7.4 IMPORTANT: IEVC Interface Removal

Remove from `IEVC.sol`:
```solidity
// REMOVE - not callable by accounts directly
function disableController(address account) external;
```

### 7.5 MODERATE: `disableCollateral` for Full Cleanup

The spec says "Disable collateral only when empty and unused." The IEVC interface should include:
```solidity
function disableCollateral(address account, address vault) external;
```

This is called on the EVC directly (not via EVault) after full withdrawal + controller disable.

### 7.6 MINOR: `accountLiquidity` Is on EVault, NOT EVC

Confirmed: `accountLiquidity` is a view function on the controller EVault, not on the EVC. The implementation plan had this correct.

### 7.7 INFO: No EVC `call()` Needed

The hooks do NOT need to route calls through `IEVC.call()`. Direct EVault calls from the smart account work correctly in the Superform execution model. This simplifies the interface -- no need to include `call()` in `IEVC.sol`.

---

## 8. Final Verified Interface Signatures

### IEVC.sol (Corrected)

```solidity
interface IEVC {
    function enableCollateral(address account, address vault) external;
    function enableController(address account, address vault) external;
    function disableCollateral(address account, address vault) external;
    function getControllers(address account) external view returns (address[] memory);
    function getCollaterals(address account) external view returns (address[] memory);
    function isCollateralEnabled(address account, address vault) external view returns (bool);
    function isControllerEnabled(address account, address vault) external view returns (bool);
    // NOTE: disableController(address) is NOT included -- it's only callable by the controller vault
}
```

### IEVault.sol (Corrected)

```solidity
interface IEVault {
    // ERC-4626 compatible
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    // Lending-specific
    function borrow(uint256 assets, address receiver) external returns (uint256 shares);
    function repay(uint256 assets, address receiver) external returns (uint256 shares);

    // Controller management
    function disableController() external;  // NO PARAMS -- account calls this on the vault

    // View functions
    function debtOf(address account) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function asset() external view returns (address);
    function oracle() external view returns (address);
    function unitOfAccount() external view returns (address);
    function interestRateModel() external view returns (address);
    function accountLiquidity(address account, bool liquidation)
        external view returns (uint256 collateralValue, uint256 liabilityValue);
        // ^^^ NOTE: collateral FIRST, liability SECOND

    // Additional view functions for validation
    function LTVFull(address collateral) external view returns (
        uint16 borrowLTV,
        uint16 liquidationLTV,
        uint16 initialLiquidationLTV,
        uint48 targetTimestamp,
        uint32 rampDuration
    );
    function totalSupply() external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function cash() external view returns (uint256);
    function caps() external view returns (uint16 supplyCap, uint16 borrowCap);
    function totalBorrows() external view returns (uint256);
    function debtOfExact(address account) external view returns (uint256);
}
```

---

## 9. Outstanding Items Requiring Clearstar Input

1. **Base EVC address confirmation**: Expected `0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383`
2. **Collateral EVault addresses**: For NVDAc, SPCXc, TSLAc
3. **Controller/Liability EVault address**: For USDC borrowing
4. **Oracle address**: For collateral valuation
5. **Unit of Account address**: For value normalization
6. **IRM address**: Interest rate model
7. **LTV configuration**: Borrow and liquidation LTV values
8. **Cap configuration**: Supply and borrow caps
9. **Liquidation configuration**: Penalty, max liquidatable amount

---

## 10. Recommended Pre-Implementation Verification Script

Create a Foundry script that verifies all interface compatibility against the real Base deployment:

```solidity
// test/integration/euler/EulerInterfaceVerification.t.sol
// Fork against Base chain and verify:
// 1. EVC responds to getControllers, enableCollateral, enableController
// 2. EVault responds to deposit, withdraw, borrow, repay, debtOf
// 3. EVault.accountLiquidity return order matches our expectations
// 4. EVault.disableController() works (parameterless)
// 5. All view functions (oracle, unitOfAccount, interestRateModel) return valid addresses
```

This should be the FIRST test written before any hook implementation begins.

---

## 11. Additional EVault Function Notes

### `repay` with `type(uint256).max`

In Euler V2, calling `repay(type(uint256).max, receiver)` will repay the full outstanding debt (capped to the actual amount). This is a convenience pattern similar to Aave. However, the approval must still cover the actual debt amount. The spec prefers reading `debtOf()` first and using the exact amount, which is more explicit and safer.

### Interest Accrual

Unlike Morpho Blue which requires explicit `accrueInterest()` calls, Euler V2 EVaults accrue interest automatically in every operation that touches the vault state. The `debtOf()` view function also returns the accrued (current) debt, not a stale value. This simplifies the hook implementation -- no separate accrual step is needed.

### Vault-Level vs Account-Level Operations

- `deposit`, `withdraw`, `borrow`, `repay` are account-level operations
- `oracle()`, `unitOfAccount()`, `interestRateModel()` are vault-level configuration reads
- `accountLiquidity()` is an account-level health check
- `disableController()` is an account-level controller removal (called on the controller vault)

All of these are callable as direct external calls from the smart account without going through the EVC's `call()` batch mechanism.
