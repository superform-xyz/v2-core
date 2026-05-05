# MetaMorpho Reallocate Hook - Technical Specification

## Overview
A NONACCOUNTING hook that calls MetaMorpho's `reallocate(MarketAllocation[] calldata allocations)` to redistribute funds between Morpho Blue markets within a single MetaMorpho vault. Used by SuperVault managers (who are also MetaMorpho allocators) via `executeHooks()`.

## Problem Statement
SuperVault strategies that include MetaMorpho vaults need to rebalance funds between Morpho Blue markets. Currently there's no hook to call `reallocate()` on MetaMorpho vaults through the hook system.

## Proposed Solution
Create `MetaMorphoReallocateHook` - a simple NONACCOUNTING hook following the `MarkRootAsUsedHook` pattern (variable-length array in data tail).

## Technical Considerations

### Data Layout
```
bytes32 placeholder         = data[0:32]     // oracle/yield source ID (standard header)
address metaMorphoVault     = data[32:52]    // MetaMorpho vault address (yieldSource position)
bool usePrevHookAmount      = data[52]       // use previous hook output
uint8 prevHookAmountIndex   = data[53]       // which allocation's assets to replace
bytes allocationsData       = data[54:]      // abi.encode(MarketAllocation[])
```

### Key Design Decisions
1. **Follows MarkRootAsUsedHook pattern** - standard header + `abi.decode` on tail for variable-length array
2. **No pre/post execute** - reallocate is net-zero, no balance tracking needed
3. **No native address** - reallocate operates on ERC20 supply positions only
4. **HookSubType.MISC** - management operation, same as MarkRootAsUsedHook
5. **`usePrevHookAmount`** - replaces `allocations[prevHookAmountIndex].assets` with previous hook output
6. **Uses `abi.encodeCall`** for type-safe encoding of the `reallocate()` call

### New Vendor Interface
Create minimal `IMetaMorpho.sol` at `src/vendor/morpho/IMetaMorpho.sol`:
```solidity
import { MarketParams } from "./IMorpho.sol";

struct MarketAllocation {
    MarketParams marketParams;
    uint256 assets;
}

interface IMetaMorpho {
    function reallocate(MarketAllocation[] calldata allocations) external;
}
```

## Acceptance Criteria
- [ ] Hook deploys with no constructor args
- [ ] Hook type is NONACCOUNTING, subtype is MISC
- [ ] `build()` correctly generates Execution calling `reallocate()` on the MetaMorpho vault
- [ ] Reverts on zero vault address
- [ ] Reverts on empty allocations array
- [ ] `usePrevHookAmount` correctly replaces target allocation's assets
- [ ] `inspect()` returns vault address
- [ ] `decodeUsePrevHookAmount()` works
- [ ] Unit tests pass
- [ ] `forge build` succeeds

## Implementation

### `src/vendor/morpho/IMetaMorpho.sol`
```solidity
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import { MarketParams } from "./IMorpho.sol";

/// @title IMetaMorpho
/// @notice Minimal interface for MetaMorpho vault's reallocate function
struct MarketAllocation {
    MarketParams marketParams;
    uint256 assets;
}

interface IMetaMorpho {
    /// @notice Reallocates the vault's supply across Morpho Blue markets
    /// @dev The caller must be an allocator, curator, or owner of the vault
    /// @dev totalWithdrawn must equal totalSupplied (net-zero invariant)
    /// @param allocations Array of target allocations per market
    function reallocate(MarketAllocation[] calldata allocations) external;
}
```

### `src/hooks/vaults/metamorpho/MetaMorphoReallocateHook.sol`
```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";
import { IMetaMorpho, MarketAllocation } from "../../../vendor/morpho/IMetaMorpho.sol";

/// @title MetaMorphoReallocateHook
/// @author Superform Labs
/// @notice NONACCOUNTING hook that calls MetaMorpho's reallocate() to redistribute funds between Morpho Blue markets
/// @dev data has the following structure
/// @notice         bytes32 placeholder = bytes32(BytesLib.slice(data, 0, 32));
/// @notice         address metaMorphoVault = BytesLib.toAddress(data, 32);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 52);
/// @notice         uint8 prevHookAmountIndex = BytesLib.toUint8(data, 53);
/// @notice         bytes allocationsData = BytesLib.slice(data, 54, data.length - 54);
contract MetaMorphoReallocateHook is BaseHook, ISuperHookContextAware {
    using HookDataDecoder for bytes;

    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 52;
    uint256 private constant PREV_HOOK_AMOUNT_INDEX_POSITION = 53;
    uint256 private constant ALLOCATIONS_DATA_OFFSET = 54;

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.MISC) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
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
        address metaMorphoVault = data.extractYieldSource();
        if (metaMorphoVault == address(0)) revert ADDRESS_NOT_VALID();

        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        MarketAllocation[] memory allocations =
            abi.decode(data[ALLOCATIONS_DATA_OFFSET:], (MarketAllocation[]));

        if (allocations.length == 0) revert AMOUNT_NOT_VALID();

        if (usePrevHookAmount) {
            uint8 index = BytesLib.toUint8(data, PREV_HOOK_AMOUNT_INDEX_POSITION);
            if (index >= allocations.length) revert AMOUNT_NOT_VALID();
            allocations[index].assets = ISuperHookResult(prevHook).getOutAmount(account);
        }

        executions = new Execution[](1);
        executions[0] = Execution({
            target: metaMorphoVault,
            value: 0,
            callData: abi.encodeCall(IMetaMorpho.reallocate, (allocations))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(data.extractYieldSource());
    }
}
```

## Test Plan
- [ ] Unit tests: constructor, hookType, subType, build(), inspect(), decodeUsePrevHookAmount()
- [ ] Unit tests: revert on zero vault address, empty allocations
- [ ] Unit tests: usePrevHookAmount with valid/invalid index
- [ ] Unit tests: data encoding round-trip
- [ ] Fuzz tests: random allocations arrays

## References
- `src/hooks/superform/MarkRootAsUsedHook.sol` - Variable-length array pattern
- `src/hooks/vaults/7540/SetOperator7540Hook.sol` - Simple NONACCOUNTING management hook
- `src/vendor/morpho/IMorpho.sol` - Existing MarketParams struct
- [MetaMorpho GitHub](https://github.com/morpho-org/metamorpho)
