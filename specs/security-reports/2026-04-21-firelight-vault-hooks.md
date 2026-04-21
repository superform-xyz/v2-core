# Security Analysis Report: Firelight Vault Hooks

## Metadata
- **Target:** `ClaimWithdrawFirelightVaultHook.sol`, `RedeemFirelightVaultHook.sol`
- **Mode:** review
- **Date:** 2026-04-21
- **Contract Types Detected:** Vault/ERC4626 hooks (async withdrawal pattern)
- **Files Analyzed:** 4 (2 hooks + BaseHook + IFirelightVault interface)

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | - |
| P1 High | 1 | Yes |
| P2 Medium | 3 | No |
| P3 Low | 5 | No |

## Verdict
**FAIL** -- 1 blocking finding (P1) should be reviewed before merge.

---

## P0 Findings (Critical)

None found.

---

## P1 Findings (High - Must Fix)

### [1] ClaimWithdrawFirelightVaultHook missing `spToken` for OUTFLOW accounting

- **File:** `ClaimWithdrawFirelightVaultHook.sol:67-75`
- **SWC:** N/A
- **Severity:** P1 High
- **Category:** Share Accounting
- **Description:** The claim hook is typed `HookType.OUTFLOW`, but `_preExecute` never sets `spToken`. Every other OUTFLOW hook in the codebase (`Redeem4626VaultHook`, `Redeem5115VaultHook`, `Redeem7540VaultHook`, `EthenaUnstakeHook`) sets `spToken = yieldSource` so the SuperLedger can identify which SuperPosition token is being withdrawn from. Without this, `ISuperHookResultOutflow(hook).spToken()` returns `address(0)`, which will cause the executor's `_updateAccounting` to fail or misidentify the position.

  Additionally, `usedShares` is never set (defaults to 0). While this may be intentional for the claim step (shares were already burned in the redeem step), the pattern deviates from all other OUTFLOW hooks and should at minimum be documented. The Ethena equivalent (`EthenaUnstakeHook`) DOES set `usedShares` via `previewWithdraw`.

- **Exploit Scenario:** A user completes a redeem+claim flow. The claim hook reports `outAmount = X` FXRP but `spToken = address(0)` and `usedShares = 0` to the SuperLedger. The ledger cannot correctly attribute the outflow to a position, potentially breaking fee calculations and cost-basis tracking.

- **Vulnerable Code:**
  ```solidity
  function _preExecute(address, address account, bytes calldata data) internal override {
      address yieldSource = data.extractYieldSource();
      asset = IFirelightVault(yieldSource).asset();
      _setOutAmount(_getBalance(account), account);
      // Missing: spToken = yieldSource;
  }
  ```

- **Secure Pattern:**
  ```solidity
  function _preExecute(address, address account, bytes calldata data) internal override {
      address yieldSource = data.extractYieldSource();
      asset = IFirelightVault(yieldSource).asset();
      spToken = yieldSource;
      _setOutAmount(_getBalance(account), account);
      // NOTE: usedShares intentionally not set -- shares were burned in the prior RedeemFirelightVaultHook step
  }
  ```

---

## P2 Findings (Medium - Should Fix)

### [2] No minimum output check on claim -- silent zero-asset claims accepted

- **File:** `ClaimWithdrawFirelightVaultHook.sol:73-75`
- **SWC:** N/A
- **Severity:** P2 Medium
- **Category:** Input Validation
- **Description:** `_postExecute` computes the FXRP delta but does not revert if zero assets were received. If `claimWithdraw` succeeds without transferring assets (e.g., request not yet claimable, vault paused, or invalid requestId), `outAmount = 0` propagates to the SuperLedger as a successful zero-value outflow. The test `test_ClaimWithdrawFirelightVaultHook_PostExecute_NoDelta` explicitly allows this.

- **Secure Pattern:** Consider adding a minimum output parameter or a post-condition check. At minimum, document that zero-outAmount claims are expected behavior.

### [3] Potential underflow in `_postExecute` if balance decreased

- **File:** `ClaimWithdrawFirelightVaultHook.sol:74`
- **SWC:** SWC-101
- **Severity:** P2 Medium
- **Category:** Arithmetic
- **Description:** `_getBalance(account) - getOutAmount(account)` will revert with an arithmetic underflow panic if the account's FXRP balance decreased between `_preExecute` and `_postExecute`. Solidity 0.8.30's checked arithmetic makes this a safe failure (revert, not silent corruption), but it's a denial-of-service vector if another hook in the batch spends FXRP.

  This pattern is consistent with all other hooks in the codebase (Redeem4626, Deposit4626, etc.).

- **Secure Pattern (optional, for defensive coding):**
  ```solidity
  function _postExecute(address, address account, bytes calldata) internal override {
      uint256 currentBalance = _getBalance(account);
      uint256 preBalance = getOutAmount(account);
      _setOutAmount(currentBalance > preBalance ? currentBalance - preBalance : 0, account);
  }
  ```

### [4] `requestId` not validated -- depends entirely on vault's internal checks

- **File:** `ClaimWithdrawFirelightVaultHook.sol:47`
- **SWC:** N/A
- **Severity:** P2 Medium
- **Category:** Input Validation
- **Description:** `_buildHookExecutions` passes `requestId` directly to `claimWithdraw` without validation. There's no check that the request belongs to `account` or that it's claimable. Security depends entirely on the Firelight vault's internal ownership and cooldown checks. If the vault doesn't verify that `msg.sender` is the rightful claimer, another user's request could be claimed.

- **Secure Pattern:** Verify through integration testing that the Firelight vault enforces ownership on `claimWithdraw`. Document this as an external dependency assumption.

---

## P3 Findings (Low - Consider Fixing)

### [5] Unused `ISuperHookInspector` import in both hooks

- **File:** `ClaimWithdrawFirelightVaultHook.sol:11`, `RedeemFirelightVaultHook.sol:11`
- **Description:** `ISuperHookInspector` is imported but not used in the contract declarations. It's already inherited via `BaseHook`. Remove the redundant import.

### [6] Inconsistent IERC20 import paths between paired hooks

- **File:** `ClaimWithdrawFirelightVaultHook.sol:7` vs `RedeemFirelightVaultHook.sol:7`
- **Description:** Claim hook imports from `@openzeppelin/contracts/interfaces/IERC20.sol`, Redeem hook from `@openzeppelin/contracts/token/ERC20/IERC20.sol`. Both resolve to the same interface but should be consistent.

### [7] `usePrevHookAmount` documented in ClaimWithdraw NatSpec but never used

- **File:** `ClaimWithdrawFirelightVaultHook.sol:24`
- **Description:** The data layout documentation includes `bool usePrevHookAmount` at position 84, but `_buildHookExecutions` never decodes or uses this field. Since `requestId` is not an amount from a previous hook, this is intentionally unused but the NatSpec is misleading.

### [8] `HookSubTypes.ERC4626` may be misleading for async vault

- **File:** Both hooks' constructors
- **Description:** Both hooks use `HookSubTypes.ERC4626`, but the Firelight vault has async withdrawal semantics that deviate from standard ERC-4626. Consider whether a dedicated subtype would be more appropriate.

### [9] External call to untrusted `yieldSource` in `_preExecute`

- **File:** `ClaimWithdrawFirelightVaultHook.sol:69`
- **Description:** `IFirelightVault(yieldSource).asset()` calls into a user-supplied address. Mitigated by the system architecture (Merkle-proof validation ensures only approved yieldSource addresses are used, and the pre-execute mutex prevents re-entrancy).

---

## Attack Surface Summary

- **External Entry Points:** `build()`, `preExecute()`, `postExecute()` (all gated by BaseHook security)
- **Value Transfer Points:** `IFirelightVault.redeem()` (burns shares), `IFirelightVault.claimWithdraw()` (transfers FXRP)
- **Oracle Dependencies:** None (uses direct balance snapshots)
- **Cross-Contract Interactions:** `IFirelightVault` (Flare chain), `IERC20.balanceOf` for balance tracking
- **Upgrade Mechanisms:** None (hooks are immutable)

## Coding Standards Summary

| Issue | Severity |
|-------|----------|
| Missing `spToken` assignment (OUTFLOW pattern) | P2 |
| Missing `replaceCalldataAmount` / `ISuperHookOutflow` on Redeem hook | P3 (NONACCOUNTING, likely intentional) |
| Unused imports | P3 |
| Import path inconsistency | P3 |
| Unicode em dash in NatSpec | P3 |
| Missing `@return` on `IFirelightVault.asset()` | P3 |
