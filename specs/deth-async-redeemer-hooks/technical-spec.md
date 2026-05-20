# DETH Async Redeemer Hooks — Technical Specification

## Overview

Build 3 custom Solidity hooks for interacting with Dialectic's DETH AsyncRedeemer contract on Ethereum mainnet. DETH is a tokenized leveraged wstETH/WETH loop strategy on Aave V3. The AsyncRedeemer implements a two-phase async redemption flow with ERC-721 NFT receipts: request → finalize (by Dialectic keeper) → claim.

Since DETH has effectively zero DEX liquidity, Superform must interact directly with the AsyncRedeemer to exit positions.

## Problem Statement

SuperWETH holds DETH positions but cannot exit via spot market swaps due to absent liquidity. The only exit path is through Dialectic's AsyncRedeemer contract which:
1. Accepts DETH shares and mints an ERC-721 NFT receipt
2. Waits for Dialectic keeper to finalize (deleverage Aave position, ~12h delay)
3. Allows claiming WETH by burning the NFT

No existing Superform hooks support this interface.

## Proposed Solution

Three hooks following the Firelight two-phase pattern:

| Hook | Type | Pattern Source | Purpose |
|------|------|---------------|---------|
| `RequestRedeemDETHHook` | NONACCOUNTING | `RedeemFirelightVaultHook` | Transfer DETH to AsyncRedeemer, receive NFT |
| `ApproveAndRequestRedeemDETHHook` | NONACCOUNTING | `ApproveAndRequestDeposit7540VaultHook` | Approve DETH + request redeem |
| `ClaimAssetsDETHHook` | OUTFLOW | `ClaimWithdrawFirelightVaultHook` | Claim WETH after finalization |

## Technical Considerations

### Architecture

```
Phase 1: RequestRedeemDETHHook (NONACCOUNTING)
  approve DETH → AsyncRedeemer (if ApproveAnd... variant)
  AsyncRedeemer.requestRedeem(shares, account, minAssets)
    → safeTransferFrom(account, AsyncRedeemer, shares)
    → _safeMint(account, requestId)  // ERC-721 NFT receipt
    → returns requestId

  ~12 hour finalization delay (Dialectic keeper calls finalizeRequests)

Phase 2: ClaimAssetsDETHHook (OUTFLOW)
  AsyncRedeemer.claimAssets(requestId)
    → checks ownerOf(requestId) == msg.sender
    → burns NFT
    → transfers WETH to account
```

### Share Token Discovery

**Key difference from Firelight**: DETH share token is **separate** from the call target (AsyncRedeemer). The hooks need to discover the DETH token for balance tracking:
- `RequestRedeemDETHHook`: Discovers via `IDETHAsyncRedeemer(asyncRedeemer).machine()` → `IMachine(machine).shareToken()`
- `ApproveAndRequestRedeemDETHHook`: DETH token address encoded directly in hookData (needed for approve calls)
- `ClaimAssetsDETHHook`: Discovers WETH via `IDETHAsyncRedeemer(asyncRedeemer).machine()` → `IMachine(machine).accountingToken()`

### Security Considerations

- **Whitelist**: Both `requestRedeem()` and `claimAssets()` have `whitelistCheck()` modifier. SuperVault Strategy smart account must be whitelisted by Dialectic before bundling.
- **NFT ownership check**: `claimAssets()` checks `ownerOf(requestId) == msg.sender`. Same smart account must call both request and claim.
- **No cancel**: Once DETH is transferred, it cannot be recovered until Dialectic finalizes. Trust assumption on Dialectic.
- **Approval pattern**: Zero-exact-execute-zero (4-step) following existing codebase convention.
- **BeaconProxy**: AsyncRedeemer is upgradeable. Dialectic can change implementation, whitelist, finalization delay.
- **12-decimal token**: DETH uses 12 decimals (not 18). Hooks pass raw values; off-chain systems must handle conversion.
- **ERC-721 callback**: `_safeMint` triggers `onERC721Received` on smart account. BaseHook mutex prevents reentrancy.

## Acceptance Criteria

### Functional
- [ ] `RequestRedeemDETHHook` calls `requestRedeem(shares, account, minAssets)` on AsyncRedeemer
- [ ] `ApproveAndRequestRedeemDETHHook` approves DETH to AsyncRedeemer (zero-set-execute-zero), then calls `requestRedeem`
- [ ] `ClaimAssetsDETHHook` calls `claimAssets(requestId)` on AsyncRedeemer
- [ ] All hooks support `usePrevHookAmount` and `inspect()`
- [ ] `RequestRedeemDETHHook` tracks `usedShares` via DETH balance delta
- [ ] `ClaimAssetsDETHHook` tracks `outAmount` via WETH balance delta
- [ ] `ClaimAssetsDETHHook` does NOT set `usedShares` (Firelight precedent)
- [ ] All hooks validate addresses and amounts (revert on zero)
- [ ] `CancelationType.NONE` for all hooks (no cancel support)

### Non-Functional
- [ ] No modifications to existing files
- [ ] Pragma locked to `0.8.30`
- [ ] NatSpec comments on all public/external functions
- [ ] Follow existing hook patterns exactly

## Implementation

### New Files

| File | Type |
|------|------|
| `src/vendor/vaults/deth/IDETHAsyncRedeemer.sol` | Interface |
| `src/vendor/vaults/deth/IMachine.sol` | Interface |
| `src/hooks/vaults/deth/RequestRedeemDETHHook.sol` | Hook (NONACCOUNTING) |
| `src/hooks/vaults/deth/ApproveAndRequestRedeemDETHHook.sol` | Hook (NONACCOUNTING) |
| `src/hooks/vaults/deth/ClaimAssetsDETHHook.sol` | Hook (OUTFLOW) |
| `test/integration/deth/DETHAsyncRedeemerHooksE2E.t.sol` | Mainnet fork tests |

### IDETHAsyncRedeemer.sol

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IDETHAsyncRedeemer
/// @notice Minimal interface for Dialectic's AsyncRedeemer contract
interface IDETHAsyncRedeemer {
    /// @notice Requests redemption of DETH shares for WETH
    /// @param shares Amount of DETH shares to redeem
    /// @param receiver Address to receive the ERC-721 NFT receipt
    /// @param minAssets Minimum WETH expected (slippage protection)
    /// @return requestId The minted NFT request ID
    function requestRedeem(uint256 shares, address receiver, uint256 minAssets) external returns (uint256 requestId);

    /// @notice Claims WETH for a finalized redemption request
    /// @param requestId The NFT request ID to claim
    /// @return assets Amount of WETH received
    function claimAssets(uint256 requestId) external returns (uint256 assets);

    /// @notice Returns the Machine vault address
    function machine() external view returns (address);
}
```

### IMachine.sol

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IMachine
/// @notice Minimal interface for Dialectic's Machine vault
interface IMachine {
    /// @notice Returns the share token address (DETH)
    function shareToken() external view returns (address);

    /// @notice Returns the accounting token address (WETH)
    function accountingToken() external view returns (address);
}
```

### hookData Layouts

**RequestRedeemDETHHook**:
```
bytes32 yieldSourceOracleId  [0:32]
address asyncRedeemer         [32:52]
uint256 shares                [52:84]
uint256 minAssets             [84:116]
bool    usePrevHookAmount     [116:117]
```
Constants: `AMOUNT_POSITION = 52`, `MIN_ASSETS_POSITION = 84`, `USE_PREV_HOOK_AMOUNT_POSITION = 116`

**ApproveAndRequestRedeemDETHHook**:
```
bytes32 yieldSourceOracleId  [0:32]
address asyncRedeemer         [32:52]
address dethToken             [52:72]
uint256 shares                [72:104]
uint256 minAssets             [104:136]
bool    usePrevHookAmount     [136:137]
```
Constants: `AMOUNT_POSITION = 72`, `MIN_ASSETS_POSITION = 104`, `USE_PREV_HOOK_AMOUNT_POSITION = 136`

**ClaimAssetsDETHHook**:
```
bytes32 yieldSourceOracleId  [0:32]
address asyncRedeemer         [32:52]
uint256 requestId             [52:84]
bool    usePrevHookAmount     [84:85]
```
Constants: `REQUEST_ID_POSITION = 52`, `USE_PREV_HOOK_AMOUNT_POSITION = 84`

### RequestRedeemDETHHook.sol

```solidity
contract RequestRedeemDETHHook is BaseHook, ISuperHookInflowOutflow, ISuperHookContextAware {
    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.ERC4626) { }

    function _buildHookExecutions(address prevHook, address account, bytes calldata data)
        internal view override returns (Execution[] memory executions)
    {
        address asyncRedeemer = data.extractYieldSource();
        uint256 shares = _decodeAmount(data);
        uint256 minAssets = BytesLib.toUint256(data, MIN_ASSETS_POSITION);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) shares = ISuperHookResult(prevHook).getOutAmount(account);
        if (shares == 0) revert AMOUNT_NOT_VALID();
        if (asyncRedeemer == address(0) || account == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: asyncRedeemer,
            value: 0,
            callData: abi.encodeCall(IDETHAsyncRedeemer.requestRedeem, (shares, account, minAssets))
        });
    }

    function _preExecute(address, address account, bytes calldata data) internal override {
        usedShares = _getSharesBalance(account, data);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        usedShares = usedShares - _getSharesBalance(account, data);
    }

    // _getSharesBalance discovers DETH via asyncRedeemer.machine().shareToken()
    function _getSharesBalance(address account, bytes memory data) private view returns (uint256) {
        address asyncRedeemer = data.extractYieldSource();
        address machine = IDETHAsyncRedeemer(asyncRedeemer).machine();
        address shareToken = IMachine(machine).shareToken();
        return IERC20(shareToken).balanceOf(account);
    }
}
```

### ApproveAndRequestRedeemDETHHook.sol

```solidity
contract ApproveAndRequestRedeemDETHHook is BaseHook, ISuperHookInflowOutflow, ISuperHookContextAware {
    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.ERC4626) { }

    function _buildHookExecutions(address prevHook, address account, bytes calldata data)
        internal view override returns (Execution[] memory executions)
    {
        address asyncRedeemer = data.extractYieldSource();
        address dethToken = BytesLib.toAddress(data, 52);
        uint256 shares = _decodeAmount(data);
        uint256 minAssets = BytesLib.toUint256(data, MIN_ASSETS_POSITION);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) shares = ISuperHookResult(prevHook).getOutAmount(account);
        if (shares == 0) revert AMOUNT_NOT_VALID();
        if (asyncRedeemer == address(0) || account == address(0) || dethToken == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](4);
        executions[0] = Execution(dethToken, 0, abi.encodeCall(IERC20.approve, (asyncRedeemer, 0)));
        executions[1] = Execution(dethToken, 0, abi.encodeCall(IERC20.approve, (asyncRedeemer, shares)));
        executions[2] = Execution({
            target: asyncRedeemer,
            value: 0,
            callData: abi.encodeCall(IDETHAsyncRedeemer.requestRedeem, (shares, account, minAssets))
        });
        executions[3] = Execution(dethToken, 0, abi.encodeCall(IERC20.approve, (asyncRedeemer, 0)));
    }

    // pre/post track DETH (token) balance delta via usedShares
    function _preExecute(address, address account, bytes calldata data) internal override {
        address dethToken = BytesLib.toAddress(data, 52);
        _setOutAmount(IERC20(dethToken).balanceOf(account), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        address dethToken = BytesLib.toAddress(data, 52);
        _setOutAmount(getOutAmount(account) - IERC20(dethToken).balanceOf(account), account);
    }

    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(data.extractYieldSource(), BytesLib.toAddress(data, 52));
    }
}
```

### ClaimAssetsDETHHook.sol

```solidity
contract ClaimAssetsDETHHook is BaseHook, ISuperHookInflowOutflow, ISuperHookContextAware {
    constructor() BaseHook(HookType.OUTFLOW, HookSubTypes.ERC4626) { }

    function _buildHookExecutions(address prevHook, address account, bytes calldata data)
        internal view override returns (Execution[] memory executions)
    {
        address asyncRedeemer = data.extractYieldSource();
        uint256 requestId = _decodeRequestId(data);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) requestId = ISuperHookResult(prevHook).getOutAmount(account);
        if (asyncRedeemer == address(0) || account == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: asyncRedeemer,
            value: 0,
            callData: abi.encodeCall(IDETHAsyncRedeemer.claimAssets, (requestId))
        });
    }

    function _preExecute(address, address account, bytes calldata data) internal override {
        address asyncRedeemer = data.extractYieldSource();
        address machine = IDETHAsyncRedeemer(asyncRedeemer).machine();
        asset = IMachine(machine).accountingToken();
        spToken = asyncRedeemer;
        _setOutAmount(_getBalance(account), account);
        // NOTE: usedShares intentionally not set — shares were consumed in the prior RequestRedeem step
    }

    function _postExecute(address, address account, bytes calldata) internal override {
        _setOutAmount(_getBalance(account) - getOutAmount(account), account);
    }

    function _getBalance(address account) private view returns (uint256) {
        return IERC20(asset).balanceOf(account);
    }
}
```

## Test Plan

### Mainnet Fork Integration Tests

Using `vm.createSelectFork(ETHEREUM_RPC_URL)` against real contracts.

**Setup**:
1. Fork Ethereum mainnet
2. Read AsyncRedeemer `owner()`, use `vm.prank(owner)` to whitelist test account
3. Acquire DETH via `deal()` or impersonating a DETH holder
4. Deploy all 3 hooks

**Test Cases**:

| Test | Description |
|------|-------------|
| `test_requestRedeem_basic` | Successful requestRedeem, verify NFT minted |
| `test_requestRedeem_usedShares` | usedShares == DETH balance delta |
| `test_requestRedeem_zeroShares` | Revert on shares=0 |
| `test_requestRedeem_zeroAddress` | Revert on asyncRedeemer=address(0) |
| `test_approveAndRequestRedeem_basic` | Successful approve + requestRedeem |
| `test_approveAndRequestRedeem_zeroAllowanceAfter` | DETH allowance is 0 after |
| `test_approveAndRequestRedeem_usePrevHookAmount` | Uses outAmount from previous hook |
| `test_claimAssets_basic` | Successful claim after finalization |
| `test_claimAssets_outAmount` | outAmount == WETH balance delta |
| `test_claimAssets_nftBurned` | NFT burned after claim |
| `test_claimAssets_notFinalized` | Revert before finalization |
| `test_claimAssets_usedSharesNotSet` | usedShares == 0 on claim |
| `test_fullFlow_e2e` | approve → request → warp → finalize → claim |
| `test_inspect_requestRedeem` | inspect() returns asyncRedeemer |
| `test_inspect_approveAndRequest` | inspect() returns asyncRedeemer + dethToken |
| `test_inspect_claimAssets` | inspect() returns asyncRedeemer |

## Contract Addresses (Ethereum Mainnet)

| Contract | Address | Decimals |
|----------|---------|----------|
| DETH share token | `0x871aB8E36CaE9AF35c6A3488B049965233DeB7ed` | 12 |
| Machine vault | `0x0447D0aD7FD6a3409B48Ecbb9DDB075C1e11D735` | — |
| AsyncRedeemer | `0xE44b62dD3F6379D6d14c38081fe1499D1a56250F` | — |
| WETH | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` | 18 |

## References

- AsyncRedeemer source: https://github.com/MakinaHQ/makina-periphery/blob/main/src/redeemers/AsyncRedeemer.sol
- Whitelist: https://github.com/MakinaHQ/makina-periphery/blob/main/src/utils/Whitelist.sol
- Firelight hooks: `src/hooks/vaults/firelight/` (closest pattern)
- 7540 approve hooks: `src/hooks/vaults/7540/ApproveAndRequestDeposit7540VaultHook.sol`
- Ethena hooks: `src/hooks/vaults/ethena/` (two-phase reference)
