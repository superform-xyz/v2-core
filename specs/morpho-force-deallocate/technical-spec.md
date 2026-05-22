# Morpho Force Deallocate Hook — Technical Specification

## Overview

Create `ForceDeallocateMorphoHook` and `ApproveAndForceDeallocateMorphoHook` for Morpho Vault V2. These NONACCOUNTING hooks call `forceDeallocate()` to permissionlessly extract assets from an adapter back to the vault's idle balance, with penalty and deadline protection.

## Problem Statement / Motivation

Morpho Vault V2 uses an adapter-based architecture where assets are allocated to external adapters (e.g., Morpho Blue markets). When an adapter is compromised, underperforming, or needs emergency extraction, `forceDeallocate` provides a permissionless exit mechanism. Superform smart accounts holding Vault V2 shares need a hook to trigger this operation.

## Proposed Solution

Two NONACCOUNTING hooks following the `MetaMorphoReallocateHook` pattern:

1. **ForceDeallocateMorphoHook** — Base hook, 1 execution (forceDeallocate call)
2. **ApproveAndForceDeallocateMorphoHook** — Approve variant, 4 executions (zero-approve-action-zero)

### Vault V2 Function Called

```solidity
function forceDeallocate(
    address adapter,
    bytes memory data,
    uint256 assets,
    address onBehalf
) external returns (uint256 penaltyShares);
```

- **adapter**: Registered adapter to deallocate from
- **data**: Protocol-specific encoded data for the adapter
- **assets**: Amount of underlying assets to deallocate
- **onBehalf**: Always `msg.sender` (smart account) — shares burned for penalty
- **Returns**: `penaltyShares` burned from `onBehalf`

### Penalty Mechanism

- Static per-adapter value set by curator (NOT time-based)
- Formula: `penaltyAssets = assets * forceDeallocatePenalty[adapter] / WAD` (rounded up)
- Max: `0.02e18` (2%)
- Penalty burns vault shares from `onBehalf`, redistributing value to remaining shareholders

## Technical Considerations

### Penalty Enforcement Strategy

The hook **pre-checks** the penalty in `_buildHookExecutions` via a static call:

```solidity
uint256 penaltyWad = IMorphoVaultV2(vault).forceDeallocatePenalty(adapter);
uint256 penaltyBps = penaltyWad / 1e14; // WAD to BPS conversion
if (penaltyBps > maxPenaltyBps) revert PENALTY_TOO_HIGH(penaltyBps, maxPenaltyBps);
```

**Why pre-check**: NONACCOUNTING hooks don't use `_preExecute`/`_postExecute`. The penalty is deterministic within a transaction (can't change between build and execute in the same tx). The `forceDeallocatePenalty(adapter)` view function is cheap.

### ApproveAndForce Variant

`forceDeallocate` does NOT pull tokens from the caller — it moves assets internally within the vault. The penalty is enforced by burning vault shares from `onBehalf`. If the vault's internal `withdraw` requires share allowance from `onBehalf`, the approve variant handles this by approving vault shares (the vault contract is an ERC-20) to the vault itself.

**Verify during fork testing**: If the vault's penalty `withdraw` call preserves `msg.sender` (internal call), no approval is needed and the approve variant's approvals are no-ops. Include both variants per requirements.

### outAmount

Set to `assets` (the requested extraction amount). Enables chaining to subsequent hooks via `usePrevHookAmount`.

## Attack Surface Analysis

### Token Risks
- [x] N/A — Hook does not handle raw token transfers; vault manages all token movements internally

### Reentrancy
- [x] CEI pattern followed — no state updates in hook
- [x] Read-only reentrancy: N/A (NONACCOUNTING, no post-call reads for accounting)
- [x] Cross-contract: BaseHook transient storage mutex prevents re-entry
- [x] ERC callbacks: Adapter may trigger callbacks, but Morpho V2 has own guards

### Oracle & Price
- [x] N/A — No oracle dependencies in the hook itself
- [ ] Vault share price could be manipulated to affect penalty share cost — mitigated by 2% cap + maxPenaltyBps

### Access Control
- [x] Smart account owner only (via UserOp signature validation)
- [x] onBehalf hardcoded to msg.sender (never configurable)

### DeFi Interaction Risks
- [x] Flash loan: Cannot force hook execution (requires UserOp signature)
- [x] MEV: Deadline + maxPenaltyBps protect against sandwich
- [ ] Vault share price manipulation: Limited impact (2% max penalty, maxPenaltyBps bound)

### Exploit Precedent
| Similar Protocol | Exploit | Loss | Our Mitigation |
|-----------------|---------|------|----------------|
| Morpho Blue | Oracle misconfiguration (Oct 2024) | $230K | No oracle dependency in hook |
| Morpho V2 | Atomic share price manipulation (Sherlock audit) | Caught pre-deploy | maxPenaltyBps + 2% cap |
| BakerFi | Vault sandwich (Code4rena) | Finding | deadline + maxPenaltyBps |

## Acceptance Criteria

### Functional
- [ ] `ForceDeallocateMorphoHook` calls `forceDeallocate` with correct parameters
- [ ] `ApproveAndForceDeallocateMorphoHook` adds approval lifecycle around the call
- [ ] `maxPenaltyBps` pre-check reverts when penalty exceeds tolerance
- [ ] `deadline` check reverts when `block.timestamp > deadline`
- [ ] `usePrevHookAmount` correctly sources amount from previous hook
- [ ] `onBehalf` is always the executing smart account
- [ ] `inspect()` returns vault and adapter addresses
- [ ] Zero address validation for vault and adapter
- [ ] Zero amount validation for assets

### Non-Functional
- [ ] Fork tests pass against real Morpho Vault V2 on Ethereum mainnet
- [ ] Fuzz tests cover penalty boundaries, deadline, data encoding
- [ ] Gas-efficient (no unnecessary storage reads)
- [ ] Follows existing codebase conventions exactly

## Implementation

### 1. Vendor Interface: `src/vendor/morpho/IMorphoVaultV2.sol`

```solidity
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title IMorphoVaultV2
/// @notice Minimal interface for Morpho Vault V2's forceDeallocate
interface IMorphoVaultV2 {
    /// @notice Permissionlessly deallocate assets from an adapter to vault idle.
    /// @param adapter The adapter to deallocate from (must be registered)
    /// @param data Protocol-specific data for the adapter
    /// @param assets Amount of underlying assets to deallocate
    /// @param onBehalf Address whose shares are burned as penalty
    /// @return penaltyShares Number of vault shares burned
    function forceDeallocate(
        address adapter,
        bytes memory data,
        uint256 assets,
        address onBehalf
    ) external returns (uint256 penaltyShares);

    /// @notice Returns the penalty rate in WAD for forceDeallocate on an adapter
    /// @param adapter The adapter address
    /// @return Penalty rate (WAD, max 0.02e18 = 2%)
    function forceDeallocatePenalty(address adapter) external view returns (uint256);

    /// @notice Returns the vault's underlying asset
    function asset() external view returns (address);
}
```

### 2. Base Hook: `src/hooks/vaults/metamorpho/ForceDeallocateMorphoHook.sol`

**Data Layout:**
```
Offset  Type      Field               Description
------  --------  ------------------  -----------
0       bytes32   placeholder         yieldSourceOracleId (standard header)
32      address   morphoVaultV2       vault address (extractYieldSource)
52      address   adapter             adapter to deallocate from
72      uint256   assets              amount to deallocate
104     uint256   deadline            block.timestamp deadline
136     uint256   maxPenaltyBps       max penalty in BPS (0-10000)
168     bool      usePrevHookAmount   use previous hook output
169     bytes     adapterData         raw adapter-specific data (tail)
```

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";
import { IMorphoVaultV2 } from "../../../vendor/morpho/IMorphoVaultV2.sol";

/// @title ForceDeallocateMorphoHook
/// @notice NONACCOUNTING hook that calls Morpho Vault V2's forceDeallocate
/// @dev Emergency extraction of assets from an adapter back to vault idle
contract ForceDeallocateMorphoHook is BaseHook, ISuperHookContextAware {
    using BytesLib for bytes;
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error EXPIRED_DEADLINE(uint256 deadline, uint256 currentTimestamp);
    error PENALTY_TOO_HIGH(uint256 actualPenaltyBps, uint256 maxPenaltyBps);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 private constant ADAPTER_OFFSET = 52;
    uint256 private constant ASSETS_OFFSET = 72;
    uint256 private constant DEADLINE_OFFSET = 104;
    uint256 private constant MAX_PENALTY_BPS_OFFSET = 136;
    uint256 private constant USE_PREV_HOOK_AMOUNT_OFFSET = 168;
    uint256 private constant ADAPTER_DATA_OFFSET = 169;
    uint256 private constant MIN_DATA_LENGTH = 169;

    /// @notice WAD to BPS conversion factor (1e14)
    uint256 private constant WAD_TO_BPS = 1e14;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.MISC) { }

    /*//////////////////////////////////////////////////////////////
                            HOOK LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes calldata data) external pure returns (bool, uint8) {
        return (data._decodeBool(USE_PREV_HOOK_AMOUNT_OFFSET), 0);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        address vault = data.extractYieldSource();
        address adapter = data.toAddress(ADAPTER_OFFSET);
        return abi.encodePacked(vault, adapter);
    }

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
        if (data.length < MIN_DATA_LENGTH) revert AMOUNT_NOT_VALID();

        address vault = data.extractYieldSource();
        if (vault == address(0)) revert ADDRESS_NOT_VALID();

        address adapter = data.toAddress(ADAPTER_OFFSET);
        if (adapter == address(0)) revert ADDRESS_NOT_VALID();

        uint256 assets = data.toUint256(ASSETS_OFFSET);
        uint256 deadline = data.toUint256(DEADLINE_OFFSET);
        uint256 maxPenaltyBps = data.toUint256(MAX_PENALTY_BPS_OFFSET);

        // Deadline check
        if (deadline != 0 && block.timestamp > deadline) {
            revert EXPIRED_DEADLINE(deadline, block.timestamp);
        }

        // Use previous hook amount if specified
        bool usePrevHookAmount = data._decodeBool(USE_PREV_HOOK_AMOUNT_OFFSET);
        if (usePrevHookAmount) {
            assets = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (assets == 0) revert AMOUNT_NOT_VALID();

        // Pre-check penalty against tolerance
        uint256 penaltyWad = IMorphoVaultV2(vault).forceDeallocatePenalty(adapter);
        uint256 penaltyBps = penaltyWad / WAD_TO_BPS;
        if (penaltyBps > maxPenaltyBps) {
            revert PENALTY_TOO_HIGH(penaltyBps, maxPenaltyBps);
        }

        // Extract adapter data (raw tail)
        bytes memory adapterData;
        if (data.length > ADAPTER_DATA_OFFSET) {
            adapterData = data.slice(ADAPTER_DATA_OFFSET, data.length - ADAPTER_DATA_OFFSET);
        }

        // Build execution
        executions = new Execution[](1);
        executions[0] = Execution({
            target: vault,
            value: 0,
            callData: abi.encodeCall(
                IMorphoVaultV2.forceDeallocate,
                (adapter, adapterData, assets, account)
            )
        });

        _setOutAmount(account, assets);
    }
}
```

### 3. Approve Variant: `src/hooks/vaults/metamorpho/ApproveAndForceDeallocateMorphoHook.sol`

**Data Layout (adds token field):**
```
Offset  Type      Field               Description
------  --------  ------------------  -----------
0       bytes32   placeholder         yieldSourceOracleId
32      address   morphoVaultV2       vault address
52      address   token               vault share token (for penalty approval)
72      address   adapter             adapter to deallocate from
92      uint256   assets              amount to deallocate
124     uint256   deadline            block.timestamp deadline
156     uint256   maxPenaltyBps       max penalty in BPS (0-10000)
188     bool      usePrevHookAmount   use previous hook output
189     bytes     adapterData         raw adapter-specific data (tail)
```

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";
import { IMorphoVaultV2 } from "../../../vendor/morpho/IMorphoVaultV2.sol";

/// @title ApproveAndForceDeallocateMorphoHook
/// @notice NONACCOUNTING hook with token approval before forceDeallocate
contract ApproveAndForceDeallocateMorphoHook is BaseHook, ISuperHookContextAware {
    using BytesLib for bytes;
    using HookDataDecoder for bytes;

    error EXPIRED_DEADLINE(uint256 deadline, uint256 currentTimestamp);
    error PENALTY_TOO_HIGH(uint256 actualPenaltyBps, uint256 maxPenaltyBps);

    uint256 private constant TOKEN_OFFSET = 52;
    uint256 private constant ADAPTER_OFFSET = 72;
    uint256 private constant ASSETS_OFFSET = 92;
    uint256 private constant DEADLINE_OFFSET = 124;
    uint256 private constant MAX_PENALTY_BPS_OFFSET = 156;
    uint256 private constant USE_PREV_HOOK_AMOUNT_OFFSET = 188;
    uint256 private constant ADAPTER_DATA_OFFSET = 189;
    uint256 private constant MIN_DATA_LENGTH = 189;
    uint256 private constant WAD_TO_BPS = 1e14;

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.MISC) { }

    function decodeUsePrevHookAmount(bytes calldata data) external pure returns (bool, uint8) {
        return (data._decodeBool(USE_PREV_HOOK_AMOUNT_OFFSET), 0);
    }

    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        address vault = data.extractYieldSource();
        address adapter = data.toAddress(ADAPTER_OFFSET);
        return abi.encodePacked(vault, adapter);
    }

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
        if (data.length < MIN_DATA_LENGTH) revert AMOUNT_NOT_VALID();

        address vault = data.extractYieldSource();
        if (vault == address(0)) revert ADDRESS_NOT_VALID();

        address token = data.toAddress(TOKEN_OFFSET);
        if (token == address(0)) revert ADDRESS_NOT_VALID();

        address adapter = data.toAddress(ADAPTER_OFFSET);
        if (adapter == address(0)) revert ADDRESS_NOT_VALID();

        uint256 assets = data.toUint256(ASSETS_OFFSET);
        uint256 deadline = data.toUint256(DEADLINE_OFFSET);
        uint256 maxPenaltyBps = data.toUint256(MAX_PENALTY_BPS_OFFSET);

        if (deadline != 0 && block.timestamp > deadline) {
            revert EXPIRED_DEADLINE(deadline, block.timestamp);
        }

        bool usePrevHookAmount = data._decodeBool(USE_PREV_HOOK_AMOUNT_OFFSET);
        if (usePrevHookAmount) {
            assets = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (assets == 0) revert AMOUNT_NOT_VALID();

        uint256 penaltyWad = IMorphoVaultV2(vault).forceDeallocatePenalty(adapter);
        uint256 penaltyBps = penaltyWad / WAD_TO_BPS;
        if (penaltyBps > maxPenaltyBps) {
            revert PENALTY_TOO_HIGH(penaltyBps, maxPenaltyBps);
        }

        bytes memory adapterData;
        if (data.length > ADAPTER_DATA_OFFSET) {
            adapterData = data.slice(ADAPTER_DATA_OFFSET, data.length - ADAPTER_DATA_OFFSET);
        }

        // 4 executions: zero-approve-action-zero
        executions = new Execution[](4);
        executions[0] = Execution({
            target: token,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (vault, 0))
        });
        executions[1] = Execution({
            target: token,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (vault, type(uint256).max))
        });
        executions[2] = Execution({
            target: vault,
            value: 0,
            callData: abi.encodeCall(
                IMorphoVaultV2.forceDeallocate,
                (adapter, adapterData, assets, account)
            )
        });
        executions[3] = Execution({
            target: token,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (vault, 0))
        });

        _setOutAmount(account, assets);
    }
}
```

### 4. Deployment Changes

**`script/utils/Constants.sol`** — Add hook key constants:
```solidity
string internal constant FORCE_DEALLOCATE_MORPHO_HOOK_KEY = "ForceDeallocateMorphoHook";
string internal constant APPROVE_AND_FORCE_DEALLOCATE_MORPHO_HOOK_KEY = "ApproveAndForceDeallocateMorphoHook";
```

**`script/DeployV2OtherHooks.s.sol`** — Add to `MorphoHookAddresses` struct and `_deployMorphoHooksSet()`.

**`script/run/regenerate_bytecode.sh`** — Add to `MORPHO_HOOK_CONTRACTS` array.

**`script/run/deploy_v2_other_hooks_staging_prod.sh`** — Add to `MORPHO_HOOKS` array.

### 5. Test Files

**Unit tests:** `test/unit/hooks/vaults/metamorpho/ForceDeallocateMorphoHook.t.sol`
- Constructor tests (hookType, subType)
- Build tests (valid data, reverts for invalid addresses, zero amounts)
- Deadline tests (expired, valid, zero = no check)
- maxPenaltyBps tests (exceeds tolerance, within tolerance, zero tolerance)
- usePrevHookAmount tests
- inspect() tests
- Fuzz tests (assets, deadline, maxPenaltyBps)
- Data encoding edge cases

**Integration tests:** `test/integration/metamorpho/ForceDeallocateMorphoHookE2E.t.sol`
- Fork Ethereum mainnet with real Morpho Vault V2
- Happy path extraction
- Penalty enforcement
- Zero penalty adapter
- Approve variant lifecycle

## Dependencies & Risks

| Risk | Mitigation |
|------|------------|
| Morpho Vault V2 not deployed on all target chains | Verify deployment before hook deployment |
| No real Vault V2 with assets for fork testing | Find active vault or use factory to create test vault |
| Penalty changes between build and execution | Same-tx penalty is deterministic; deadline limits staleness |
| Adapter compromise | Vault-level concern; hook cannot mitigate |
| ApproveAndForce variant may be unnecessary | Include per requirements; verify need in fork tests |

## References & Research

### Internal
- `src/hooks/vaults/metamorpho/MetaMorphoReallocateHook.sol` — Closest pattern
- `src/hooks/swappers/uniswap-v3/SwapUniswapV3Hook.sol:53` — Deadline pattern
- `src/hooks/vaults/4626/ApproveAndDeposit4626VaultHook.sol` — Approve-and-X pattern
- `src/hooks/BaseHook.sol:62-96` — Error definitions
- `src/vendor/morpho/IMetaMorpho.sol` — Existing Morpho interface

### External
- [Morpho Vault V2 GitHub](https://github.com/morpho-org/vault-v2)
- [Morpho V2 Docs](https://docs.morpho.org/learn/concepts/vault-v2/)
- [VaultV2Factory](https://etherscan.io/address/0xA1D94F746dEfa1928926b84fB2596c06926C0405)
- [ChainSecurity Audit](https://www.chainsecurity.com/security-audit/morpho-vault-v2)
- [Sherlock Morpho V2 Audit](https://sherlock.xyz/case-studies/morpho)
