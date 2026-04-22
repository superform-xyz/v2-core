# Firelight Vault Hooks — Technical Specification

## Overview

Create 2 custom hooks in v2-core for integrating with the Firelight stXRP vault on Flare (chain ID 14). The vault uses ERC-4626 function signatures but has async withdrawal semantics — `redeem()` creates a withdrawal request instead of transferring assets, and `claimWithdraw(requestId)` claims assets after a ~2 day cooldown.

Deposits use the existing `Deposit4626VaultHook` / `ApproveAndDeposit4626VaultHook` since `deposit()` is synchronous.

## Problem Statement

The Firelight vault at `0x4C18Ff3C89632c3Dd62E796c0aFA5c07c4c1B2b3` cannot use existing hooks:
- **4626 hooks fail**: `Redeem4626VaultHook` expects `redeem()` to transfer assets atomically — Firelight's doesn't
- **7540 hooks fail**: Firelight doesn't implement ERC-7540 (`requestRedeem`, `claimableRedeemRequest`, `pendingRedeemRequest` all revert, `supportsInterface(ERC7540)` returns false)
- Custom hooks are needed following the established 2-phase pattern (like Ethena cooldown/unstake)

## On-Chain Evidence

- TX `0xe9fa9a...`: `redeem()` succeeds but only burns stXRP + emits `WithdrawRequest` — no FXRP transfer
- Trace of `withdraw()` from top holder: same behavior — shares burned, WithdrawRequest emitted, no FXRP outflow
- `claimWithdraw(0)` reverts with `NoWithdrawalAmount(uint256)` — confirms function exists
- `maxRedeem()` returns full balance (misleading — implies instant redemption)
- Vault is upgradeable proxy (delegates to `0x70CCf1bEE0c1217069FE74083Ca71AF7BCd7fb76`)
- FXRP: `0xAd552A648C74D49E10027AB8a618A3ad4901c5bE`

## Technical Approach

### Architecture

Follow the **EthenaCooldownSharesHook + EthenaUnstakeHook** pattern exactly:

| Component | Ethena Analogue | Firelight Hook |
|-----------|----------------|----------------|
| Phase 1 (request) | `EthenaCooldownSharesHook` (NONACCOUNTING) | `RedeemFirelightVaultHook` (NONACCOUNTING) |
| Phase 2 (claim) | `EthenaUnstakeHook` (OUTFLOW) | `ClaimWithdrawFirelightVaultHook` (OUTFLOW) |
| Interface | `IStakedUSDeCooldown` | `IFirelightVault` |

### New Files

| File | Action |
|------|--------|
| `src/vendor/vaults/firelight/IFirelightVault.sol` | **Create** |
| `src/hooks/vaults/firelight/RedeemFirelightVaultHook.sol` | **Create** |
| `src/hooks/vaults/firelight/ClaimWithdrawFirelightVaultHook.sol` | **Create** |
| `test/unit/hooks/vaults/firelight/FirelightHooksTests.t.sol` | **Create** |

No modifications to existing files.

---

## Implementation

### 1. IFirelightVault Interface

`src/vendor/vaults/firelight/IFirelightVault.sol`

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IFirelightVault
/// @notice Minimal interface for Firelight stXRP vault on Flare
/// @dev The vault uses ERC-4626 function signatures but with async withdrawal semantics.
///      redeem() burns shares and creates a WithdrawRequest instead of transferring assets.
///      claimWithdraw() claims assets after the cooldown period.
interface IFirelightVault {
    /// @notice Burns shares and creates a withdrawal request (does NOT transfer assets)
    /// @param shares Amount of stXRP shares to redeem
    /// @param receiver Address to receive assets when claimed
    /// @param owner Owner of the shares being redeemed
    /// @return assets Nominal asset value (NOT actually transferred)
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);

    /// @notice Claims assets from a completed withdrawal request
    /// @param requestId The withdrawal request ID from the WithdrawRequest event
    function claimWithdraw(uint256 requestId) external;

    /// @notice Returns the underlying asset address (FXRP)
    function asset() external view returns (address);
}
```

### 2. RedeemFirelightVaultHook

`src/hooks/vaults/firelight/RedeemFirelightVaultHook.sol`

Pattern: **EthenaCooldownSharesHook** (NONACCOUNTING, tracks share burn)

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { BaseHook } from "../../BaseHook.sol";
import {
    ISuperHookInflowOutflow,
    ISuperHookAsyncCancelations,
    ISuperHookContextAware,
    ISuperHookInspector
} from "../../../interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { IFirelightVault } from "../../../vendor/vaults/firelight/IFirelightVault.sol";

/// @title RedeemFirelightVaultHook
/// @author Superform Labs
/// @notice Burns stXRP shares via redeem() to create a withdrawal request on the Firelight vault.
///         Assets are NOT transferred in this step — use ClaimWithdrawFirelightVaultHook after cooldown.
/// @dev data layout:
///      bytes32 placeholder     = bytes32(BytesLib.slice(data, 0, 32));
///      address yieldSource     = BytesLib.toAddress(data, 32);
///      uint256 shares          = BytesLib.toUint256(data, 52);
///      bool usePrevHookAmount  = _decodeBool(data, 84);
contract RedeemFirelightVaultHook is
    BaseHook,
    ISuperHookInflowOutflow,
    ISuperHookAsyncCancelations,
    ISuperHookContextAware
{
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 52;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 84;

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.ERC4626) { }

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        address yieldSource = data.extractYieldSource();
        uint256 shares = _decodeAmount(data);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            shares = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (shares == 0) revert AMOUNT_NOT_VALID();
        if (yieldSource == address(0) || account == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IFirelightVault.redeem, (shares, account, account))
        });
    }

    /// @inheritdoc ISuperHookAsyncCancelations
    function isAsyncCancelHook() external pure returns (CancelationType) {
        return CancelationType.NONE;
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmount(bytes memory data) external pure returns (uint256) {
        return _decodeAmount(data);
    }

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(data.extractYieldSource());
    }

    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getOutAmount(account) - _getBalance(account, data), account);
    }

    function _decodeAmount(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        return IERC20(data.extractYieldSource()).balanceOf(account);
    }
}
```

### 3. ClaimWithdrawFirelightVaultHook

`src/hooks/vaults/firelight/ClaimWithdrawFirelightVaultHook.sol`

Pattern: **EthenaUnstakeHook** (OUTFLOW, tracks asset receipt)

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { BaseHook } from "../../BaseHook.sol";
import { ISuperHookInflowOutflow, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { IFirelightVault } from "../../../vendor/vaults/firelight/IFirelightVault.sol";

/// @title ClaimWithdrawFirelightVaultHook
/// @author Superform Labs
/// @notice Claims FXRP from a completed Firelight withdrawal request after the cooldown period.
///         Must be used after RedeemFirelightVaultHook has created the withdrawal request.
/// @dev data layout:
///      bytes32 placeholder     = bytes32(BytesLib.slice(data, 0, 32));
///      address yieldSource     = BytesLib.toAddress(data, 32);
///      uint256 requestId       = BytesLib.toUint256(data, 52);
///      bool usePrevHookAmount  = _decodeBool(data, 84);  // typically false for requestId
contract ClaimWithdrawFirelightVaultHook is BaseHook, ISuperHookInflowOutflow, ISuperHookContextAware {
    using HookDataDecoder for bytes;

    uint256 private constant REQUEST_ID_POSITION = 52;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 84;

    constructor() BaseHook(HookType.OUTFLOW, HookSubTypes.ERC4626) { }

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        address yieldSource = data.extractYieldSource();
        uint256 requestId = _decodeRequestId(data);

        if (yieldSource == address(0) || account == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IFirelightVault.claimWithdraw, (requestId))
        });
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmount(bytes memory data) external pure returns (uint256) {
        return _decodeRequestId(data);
    }

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(data.extractYieldSource());
    }

    function _preExecute(address, address account, bytes calldata data) internal override {
        address yieldSource = data.extractYieldSource();
        asset = IFirelightVault(yieldSource).asset();
        _setOutAmount(_getBalance(account), account);
    }

    function _postExecute(address, address account, bytes calldata) internal override {
        _setOutAmount(_getBalance(account) - getOutAmount(account), account);
    }

    function _decodeRequestId(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(data, REQUEST_ID_POSITION);
    }

    function _getBalance(address account) private view returns (uint256) {
        return IERC20(asset).balanceOf(account);
    }
}
```

### 4. Unit Tests

`test/unit/hooks/vaults/firelight/FirelightHooksTests.t.sol`

**Test cases:**

#### RedeemFirelightVaultHook
1. `test_constructor` — hookType == NONACCOUNTING, SUB_TYPE == ERC4626
2. `test_build_correctExecution` — returns 3 executions (pre + redeem call + post), correct target and calldata
3. `test_build_revertsZeroShares` — AMOUNT_NOT_VALID
4. `test_build_revertsZeroYieldSource` — ADDRESS_NOT_VALID
5. `test_build_withPrevHookAmount` — usePrevHookAmount = true reads from MockHook
6. `test_decodeAmount` — returns correct shares value
7. `test_decodeUsePrevHookAmount` — returns correct bool
8. `test_inspect` — returns encoded yieldSource
9. `test_isAsyncCancelHook` — returns CancelationType.NONE
10. `test_prePostExecute_tracksShareBurn` — usedShares delta matches shares burned

#### ClaimWithdrawFirelightVaultHook
11. `test_constructor` — hookType == OUTFLOW, SUB_TYPE == ERC4626
12. `test_build_correctExecution` — returns 3 executions (pre + claimWithdraw call + post), correct target and calldata with requestId
13. `test_build_revertsZeroYieldSource` — ADDRESS_NOT_VALID
14. `test_decodeAmount` — returns correct requestId
15. `test_inspect` — returns encoded yieldSource
16. `test_prePostExecute_tracksAssetReceipt` — outAmount delta matches FXRP received

---

## Security Considerations

### Token Risks
- FXRP is a bridged token (FAssets system). Verify no fee-on-transfer, rebasing, or pause mechanisms.
- Use balance-delta pattern (pre/post `balanceOf`) for all accounting — never trust return values.

### Proxy/Upgrade Risk
- Vault is upgradeable. All behavior can change via proxy upgrade.
- Monitor vault proxy admin for upgrade transactions during cooldown windows.

### Cooldown Window
- ~2 day gap between redeem() and claimWithdraw(). During this window:
  - Shares are burned (no rollback)
  - Vault could be upgraded, paused, or drained
  - Off-chain monitoring recommended

### RequestId Management
- RequestId encoded in hookData by trusted off-chain keeper.
- If vault allows third-party claims, attacker could front-run. Verify vault's access control on claimWithdraw.

### Flare Chain Compatibility
- Verify transient storage (EIP-1153) support — BaseHook depends on `tstore`/`tload`.
- Run integration tests on Flare testnet before deployment.

### maxRedeem()/maxWithdraw() Are Misleading
- Return full balance despite async semantics. Hooks and oracles MUST NOT rely on these values.

## Acceptance Criteria

- [ ] `RedeemFirelightVaultHook` compiles and follows NONACCOUNTING pattern
- [ ] `ClaimWithdrawFirelightVaultHook` compiles and follows OUTFLOW pattern
- [ ] `IFirelightVault` interface covers `redeem`, `claimWithdraw`, `asset`
- [ ] All unit tests pass
- [ ] No modifications to existing files
- [ ] Pragma locked to `0.8.30`
- [ ] NatSpec on all public/external functions
- [ ] `inspect()` returns encoded yieldSource for merkle tree compatibility

## References

- Ethena cooldown hook: `src/hooks/vaults/ethena/EthenaCooldownSharesHook.sol`
- Ethena unstake hook: `src/hooks/vaults/ethena/EthenaUnstakeHook.sol`
- ERC-7540 request redeem hook: `src/hooks/vaults/7540/RequestRedeem7540VaultHook.sol`
- BaseHook: `src/hooks/BaseHook.sol`
- HookSubTypes: `src/libraries/HookSubTypes.sol`
- Firelight vault (Flare): `0x4C18Ff3C89632c3Dd62E796c0aFA5c07c4c1B2b3`
- FXRP token (Flare): `0xAd552A648C74D49E10027AB8a618A3ad4901c5bE`
