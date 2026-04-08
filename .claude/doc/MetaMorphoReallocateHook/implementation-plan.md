# MetaMorpho Reallocate Hook - Implementation Plan

## Overview

Create `MetaMorphoReallocateHook`, a NONACCOUNTING hook that calls MetaMorpho's `reallocate(MarketAllocation[] calldata allocations)` to redistribute funds between Morpho Blue markets within a single MetaMorpho vault.

## Validation Results from Research

### BytesLib.toUint8 - CONFIRMED EXISTS
- Located at `src/vendor/BytesLib.sol` line 286
- Signature: `function toUint8(bytes memory _bytes, uint256 _start) internal pure returns (uint8)`
- Already used in production by `DeBridgeSendOrderAndExecuteOnDstHook` (line 219)
- Safe to use in the spec as-is

### abi.decode on calldata slice for dynamic arrays - CONFIRMED WORKS
- Pattern `abi.decode(data[OFFSET:], (SomeType))` is established in the codebase
- Used by `PendleRouterRedeemHook` (line 158): `abi.decode(data[TOKEN_OUTPUT_OFFSET:], (TokenOutput))`
- Used by `SpectraExchangeDepositHook` (line 71): `abi.decode(data[53:TX_DATA_POSITION], (uint256))`
- Solidity handles calldata-to-memory conversion automatically when calling abi.decode on a calldata slice
- `MarketAllocation[]` with nested `MarketParams` struct will decode correctly since abi.encode/decode handles nested structs natively

### abi.encodeCall with dynamic arrays - CONFIRMED WORKS
- `MarkRootAsUsedHook` already uses `abi.encodeCall(ISuperDestinationExecutor.markRootsAsUsed, (merkleRoots))` where `merkleRoots` is `bytes32[]`
- `abi.encodeCall(IMetaMorpho.reallocate, (allocations))` follows the same pattern with `MarketAllocation[]`

### calldata-to-memory implicit conversion - CONFIRMED PATTERN
- `_decodeBool(data, offset)` is used extensively with `bytes calldata data` parameter in `_buildHookExecutions`
- `data.extractYieldSource()` (from HookDataDecoder) is used with `bytes calldata data` throughout the codebase
- `BytesLib.toUint8(data, offset)` is used in DeBridgeSendOrderAndExecuteOnDstHook with calldata data
- Solidity auto-copies calldata to memory when passing to functions expecting `bytes memory`

## Files to Create (3 files)

### File 1: `src/vendor/morpho/IMetaMorpho.sol`

**Purpose**: Minimal vendor interface for MetaMorpho vault's reallocate function.

**Content**:
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

**Notes**:
- Uses `pragma solidity >=0.5.0;` to match existing `IMorpho.sol` convention (line 1 of IMorpho.sol)
- Imports `MarketParams` from the already existing `IMorpho.sol` at `src/vendor/morpho/IMorpho.sol`
- `MarketAllocation` struct is declared at file scope (outside the interface), following the same pattern as `MarketParams`, `Position`, `Market`, `Authorization`, and `Signature` in `IMorpho.sol`
- License is `GPL-2.0-or-later` to match `IMorpho.sol`

### File 2: `src/hooks/vaults/metamorpho/MetaMorphoReallocateHook.sol`

**Purpose**: The main hook contract.

**Content** (exact implementation):
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

**Key Design Decisions Validated**:

1. **`_buildHookExecutions` is `view` not `pure`**: Because when `usePrevHookAmount` is true, it calls `ISuperHookResult(prevHook).getOutAmount(account)` which is an external view call. This matches the `TransferHook` pattern (line 46 of TransferHook.sol).

2. **Implements `ISuperHookContextAware`** (not just `ISuperHookInspector`): Because the hook supports `usePrevHookAmount` chaining. All hooks with `usePrevHookAmount` implement `ISuperHookContextAware` (verified: TransferHook, DeBridgeSendOrderAndExecuteOnDstHook, ApproveAndSwapOdosV2Hook, etc.)

3. **`inspect` returns ONLY the vault address**: Complies with the PROTOCOL REQUIREMENT that inspector functions only return addresses. Uses `abi.encodePacked(data.extractYieldSource())` which is the exact same pattern as `MarkRootAsUsedHook` (line 60).

4. **`inspect` is `pure`**: No immutable variables are accessed, so `pure` is correct (matching MarkRootAsUsedHook pattern).

5. **No `_preExecute` or `_postExecute` overrides**: Reallocate is a net-zero management operation - no balance tracking or outAmount setting is needed. The base implementations in `BaseHook` (empty no-ops) are sufficient.

6. **No constructor arguments**: Unlike hooks that need chain-specific addresses (e.g., TransferHook needs NATIVE_TOKEN), this hook targets arbitrary MetaMorpho vaults specified in the hook data. No immutable dependencies needed.

7. **Uses `data.extractYieldSource()` for vault address**: This is the standard Superform convention for data[32:52] extraction, using the `HookDataDecoder` library via `using HookDataDecoder for bytes`.

8. **Error reuse from BaseHook**: Uses `ADDRESS_NOT_VALID()` for zero vault address and `AMOUNT_NOT_VALID()` for empty allocations and out-of-bounds index, matching the conventions in MarkRootAsUsedHook and SetOperator7540Hook.

### File 3: `test/unit/hooks/vaults/metamorpho/MetaMorphoReallocateHook.t.sol`

**Purpose**: Comprehensive unit tests.

**Content**:
```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MetaMorphoReallocateHook } from
    "../../../../../src/hooks/vaults/metamorpho/MetaMorphoReallocateHook.sol";
import { ISuperHook, ISuperHookContextAware } from "../../../../../src/interfaces/ISuperHook.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";
import { BytesLib } from "../../../../../src/vendor/BytesLib.sol";
import { HookSubTypes } from "../../../../../src/libraries/HookSubTypes.sol";
import { IMetaMorpho, MarketAllocation } from "../../../../../src/vendor/morpho/IMetaMorpho.sol";
import { MarketParams } from "../../../../../src/vendor/morpho/IMorpho.sol";

contract MetaMorphoReallocateHookTest is Helpers {
    using BytesLib for bytes;

    MetaMorphoReallocateHook public hook;

    address public vault;
    MarketParams public marketA;
    MarketParams public marketB;

    function setUp() public {
        hook = new MetaMorphoReallocateHook();
        vault = makeAddr("metaMorphoVault");

        marketA = MarketParams({
            loanToken: makeAddr("loanTokenA"),
            collateralToken: makeAddr("collateralTokenA"),
            oracle: makeAddr("oracleA"),
            irm: makeAddr("irmA"),
            lltv: 0.8e18
        });

        marketB = MarketParams({
            loanToken: makeAddr("loanTokenB"),
            collateralToken: makeAddr("collateralTokenB"),
            oracle: makeAddr("oracleB"),
            irm: makeAddr("irmB"),
            lltv: 0.9e18
        });
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(hook.SUB_TYPE()), uint256(HookSubTypes.MISC));
    }

    /*//////////////////////////////////////////////////////////////
                            BUILD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build_SingleAllocation() public view {
        MarketAllocation[] memory allocations = new MarketAllocation[](1);
        allocations[0] = MarketAllocation({ marketParams: marketA, assets: 1000e6 });

        bytes memory data = _encodeData(vault, false, 0, allocations);
        Execution[] memory executions = hook.build(address(0), address(0), data);

        // preExecute + hook execution + postExecute = 3
        assertEq(executions.length, 3);
        assertEq(executions[1].target, vault);
        assertEq(executions[1].value, 0);

        bytes memory expectedCalldata = abi.encodeCall(IMetaMorpho.reallocate, (allocations));
        assertEq(executions[1].callData, expectedCalldata);
    }

    function test_Build_MultipleAllocations() public view {
        MarketAllocation[] memory allocations = new MarketAllocation[](2);
        allocations[0] = MarketAllocation({ marketParams: marketA, assets: 500e6 });
        allocations[1] = MarketAllocation({ marketParams: marketB, assets: 500e6 });

        bytes memory data = _encodeData(vault, false, 0, allocations);
        Execution[] memory executions = hook.build(address(0), address(0), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, vault);

        bytes memory expectedCalldata = abi.encodeCall(IMetaMorpho.reallocate, (allocations));
        assertEq(executions[1].callData, expectedCalldata);
    }

    function test_Build_RevertIf_ZeroVaultAddress() public {
        MarketAllocation[] memory allocations = new MarketAllocation[](1);
        allocations[0] = MarketAllocation({ marketParams: marketA, assets: 1000e6 });

        bytes memory data = _encodeData(address(0), false, 0, allocations);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    function test_Build_RevertIf_EmptyAllocations() public {
        MarketAllocation[] memory allocations = new MarketAllocation[](0);

        bytes memory data = _encodeData(vault, false, 0, allocations);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    /*//////////////////////////////////////////////////////////////
                        USE PREV HOOK AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build_UsePrevHookAmount() public {
        MarketAllocation[] memory allocations = new MarketAllocation[](2);
        allocations[0] = MarketAllocation({ marketParams: marketA, assets: 500e6 });
        allocations[1] = MarketAllocation({ marketParams: marketB, assets: 0 }); // to be replaced

        uint256 prevHookOutput = 750e6;
        address prevHook = makeAddr("prevHook");
        address account = makeAddr("account");

        // Mock the prevHook.getOutAmount(account) call
        vm.mockCall(
            prevHook,
            abi.encodeWithSelector(bytes4(keccak256("getOutAmount(address)")), account),
            abi.encode(prevHookOutput)
        );

        bytes memory data = _encodeData(vault, true, 1, allocations);
        Execution[] memory executions = hook.build(prevHook, account, data);

        // Verify the allocation at index 1 was replaced with prevHookOutput
        MarketAllocation[] memory expectedAllocations = new MarketAllocation[](2);
        expectedAllocations[0] = MarketAllocation({ marketParams: marketA, assets: 500e6 });
        expectedAllocations[1] = MarketAllocation({ marketParams: marketB, assets: prevHookOutput });

        bytes memory expectedCalldata = abi.encodeCall(IMetaMorpho.reallocate, (expectedAllocations));
        assertEq(executions[1].callData, expectedCalldata);
    }

    function test_Build_UsePrevHookAmount_IndexZero() public {
        MarketAllocation[] memory allocations = new MarketAllocation[](2);
        allocations[0] = MarketAllocation({ marketParams: marketA, assets: 0 }); // to be replaced
        allocations[1] = MarketAllocation({ marketParams: marketB, assets: 500e6 });

        uint256 prevHookOutput = 300e6;
        address prevHook = makeAddr("prevHook");
        address account = makeAddr("account");

        vm.mockCall(
            prevHook,
            abi.encodeWithSelector(bytes4(keccak256("getOutAmount(address)")), account),
            abi.encode(prevHookOutput)
        );

        bytes memory data = _encodeData(vault, true, 0, allocations);
        Execution[] memory executions = hook.build(prevHook, account, data);

        MarketAllocation[] memory expectedAllocations = new MarketAllocation[](2);
        expectedAllocations[0] = MarketAllocation({ marketParams: marketA, assets: prevHookOutput });
        expectedAllocations[1] = MarketAllocation({ marketParams: marketB, assets: 500e6 });

        bytes memory expectedCalldata = abi.encodeCall(IMetaMorpho.reallocate, (expectedAllocations));
        assertEq(executions[1].callData, expectedCalldata);
    }

    function test_Build_RevertIf_PrevHookAmountIndex_OutOfBounds() public {
        MarketAllocation[] memory allocations = new MarketAllocation[](2);
        allocations[0] = MarketAllocation({ marketParams: marketA, assets: 500e6 });
        allocations[1] = MarketAllocation({ marketParams: marketB, assets: 500e6 });

        address prevHook = makeAddr("prevHook");
        address account = makeAddr("account");

        // Index 2 is out of bounds for a 2-element array
        bytes memory data = _encodeData(vault, true, 2, allocations);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(prevHook, account, data);
    }

    /*//////////////////////////////////////////////////////////////
                            INSPECT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Inspect() public view {
        MarketAllocation[] memory allocations = new MarketAllocation[](1);
        allocations[0] = MarketAllocation({ marketParams: marketA, assets: 1000e6 });

        bytes memory data = _encodeData(vault, false, 0, allocations);
        bytes memory inspectionResult = hook.inspect(data);

        assertEq(BytesLib.toAddress(inspectionResult, 0), vault);
    }

    /*//////////////////////////////////////////////////////////////
                        DECODE USE PREV HOOK AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DecodeUsePrevHookAmount_True() public view {
        MarketAllocation[] memory allocations = new MarketAllocation[](1);
        allocations[0] = MarketAllocation({ marketParams: marketA, assets: 1000e6 });

        bytes memory data = _encodeData(vault, true, 0, allocations);
        assertTrue(hook.decodeUsePrevHookAmount(data));
    }

    function test_DecodeUsePrevHookAmount_False() public view {
        MarketAllocation[] memory allocations = new MarketAllocation[](1);
        allocations[0] = MarketAllocation({ marketParams: marketA, assets: 1000e6 });

        bytes memory data = _encodeData(vault, false, 0, allocations);
        assertFalse(hook.decodeUsePrevHookAmount(data));
    }

    /*//////////////////////////////////////////////////////////////
                            DATA ENCODING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DataEncodingDecoding() public view {
        MarketAllocation[] memory allocations = new MarketAllocation[](2);
        allocations[0] = MarketAllocation({ marketParams: marketA, assets: 500e6 });
        allocations[1] = MarketAllocation({ marketParams: marketB, assets: 500e6 });

        bytes memory data = _encodeData(vault, true, 1, allocations);

        // Verify vault address extraction
        assertEq(BytesLib.toAddress(data, 32), vault);

        // Verify usePrevHookAmount
        assertEq(data[52] != 0, true);

        // Verify prevHookAmountIndex
        assertEq(BytesLib.toUint8(data, 53), 1);

        // Verify allocations decoding
        bytes memory allocationsData = BytesLib.slice(data, 54, data.length - 54);
        MarketAllocation[] memory decoded = abi.decode(allocationsData, (MarketAllocation[]));
        assertEq(decoded.length, 2);
        assertEq(decoded[0].assets, 500e6);
        assertEq(decoded[1].assets, 500e6);
        assertEq(decoded[0].marketParams.loanToken, marketA.loanToken);
        assertEq(decoded[1].marketParams.loanToken, marketB.loanToken);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Build(address _vault, uint256 assets1, uint256 assets2) public view {
        vm.assume(_vault != address(0));
        vm.assume(assets1 > 0);
        vm.assume(assets2 > 0);

        MarketAllocation[] memory allocations = new MarketAllocation[](2);
        allocations[0] = MarketAllocation({ marketParams: marketA, assets: assets1 });
        allocations[1] = MarketAllocation({ marketParams: marketB, assets: assets2 });

        bytes memory data = _encodeData(_vault, false, 0, allocations);
        Execution[] memory executions = hook.build(address(0), address(0), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, _vault);
        assertEq(executions[1].value, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    function _encodeData(
        address _vault,
        bool _usePrevHookAmount,
        uint8 _prevHookAmountIndex,
        MarketAllocation[] memory _allocations
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory placeholder = new bytes(32);
        bytes memory allocationsData = abi.encode(_allocations);

        return bytes.concat(
            placeholder,
            abi.encodePacked(_vault),
            abi.encodePacked(_usePrevHookAmount ? uint8(1) : uint8(0)),
            abi.encodePacked(_prevHookAmountIndex),
            allocationsData
        );
    }
}
```

**Test Design Decisions**:

1. **Inherits `Helpers`** (not `BaseTest`): For simple unit tests, following the `SetOperator7540Hook.t.sol` and `MarkRootAsUsedHook.t.sol` patterns.

2. **Uses `vm.mockCall`** for prevHook interaction: Instead of complex state setup, mocks the `getOutAmount` call. This follows the "Mock external calls with `vm.mockCall()` instead of complex state setup" guideline.

3. **Tests `executions.length == 3`**: Because `BaseHook.build()` wraps `_buildHookExecutions` output with preExecute (index 0) and postExecute (index last). The actual hook execution is at index 1. This is consistent with all existing tests.

4. **`_encodeData` helper**: Follows the exact encoding pattern from `MarkRootAsUsedHook.t.sol._encodeData` - uses `bytes.concat` with `placeholder + abi.encodePacked(address) + ...` then `abi.encode(array)` for the dynamic tail.

5. **Encoding pattern for bool**: Uses `abi.encodePacked(_usePrevHookAmount ? uint8(1) : uint8(0))` matching the pattern in `SetOperator7540Hook.t.sol._encodeData` (line 130).

## Critical Notes for Implementation

### Note 1: The `_decodeBool` calldata/memory conversion
`_decodeBool` in `BaseHook` accepts `bytes memory`. When called inside `_buildHookExecutions` which receives `bytes calldata data`, Solidity performs an automatic copy from calldata to memory. This is the established pattern used by every hook in the codebase. No special handling needed.

### Note 2: The `abi.decode(data[ALLOCATIONS_DATA_OFFSET:], (MarketAllocation[]))` pattern
This is a calldata slice passed to `abi.decode`. Solidity handles this correctly - the calldata slice is treated as an ABI-encoded blob. The `MarketAllocation[]` type contains nested `MarketParams` structs, which ABI encodes as a dynamic array of tuples. This is identical to how `PendleRouterRedeemHook` decodes `TokenOutput` from a calldata slice.

### Note 3: Directory creation
The directory `src/hooks/vaults/metamorpho/` does not exist yet and needs to be created. Similarly, `test/unit/hooks/vaults/metamorpho/` needs to be created.

### Note 4: No deployment script changes needed
Per the session context, this hook is used via `executeHooks()` by SuperVault managers. It has no constructor arguments and no external dependencies that vary by chain. No changes to `DeployV2Core.s.sol`, `ConfigBase.sol`, `ConfigCore.sol`, or `Constants.sol` are needed for the initial implementation. Deployment integration can be added separately if/when this hook is included in the standard deployment.

### Note 5: `using HookDataDecoder for bytes` usage
The spec correctly includes `using HookDataDecoder for bytes;` which enables `data.extractYieldSource()` syntax. This is declared at the contract level, matching all existing hooks.

## Spec Issues Found and Resolutions

### Issue 1: NONE FOUND
The spec is remarkably clean. The data layout, interface design, encoding/decoding approach, error handling, and test plan all align perfectly with established codebase conventions.

### Minor Improvement: NatSpec consistency
The spec's NatSpec uses `bytes32(BytesLib.slice(data, 0, 32))` for the placeholder, which exactly matches `MarkRootAsUsedHook` (line 18). No change needed.

## Implementation Order

1. Create `src/vendor/morpho/IMetaMorpho.sol`
2. Create `src/hooks/vaults/metamorpho/MetaMorphoReallocateHook.sol`
3. Create `test/unit/hooks/vaults/metamorpho/MetaMorphoReallocateHook.t.sol`
4. Run `forge build` to verify compilation
5. Run `make forge-test TEST=MetaMorphoReallocateHook` to verify tests pass

## Checklist

- [x] BytesLib.toUint8 exists (confirmed at BytesLib.sol line 286)
- [x] abi.decode on calldata slice works for nested structs (confirmed via PendleRouterRedeemHook pattern)
- [x] abi.encodeCall with dynamic arrays works (confirmed via MarkRootAsUsedHook pattern)
- [x] Data layout validated (32 + 20 + 1 + 1 + dynamic = correct offsets)
- [x] Hook follows NONACCOUNTING/MISC pattern (matches MarkRootAsUsedHook)
- [x] Inspector returns only addresses (protocol requirement met)
- [x] _buildHookExecutions uses `view` (correct for getOutAmount external call)
- [x] inspect uses `pure` (correct - no immutable access)
- [x] No deployment script changes needed
- [x] Test file follows Helpers inheritance pattern
- [x] Test uses vm.mockCall for external calls
- [x] All error cases tested (zero vault, empty allocations, OOB index)
