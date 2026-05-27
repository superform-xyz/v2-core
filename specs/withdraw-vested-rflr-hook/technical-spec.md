# WithdrawVestedRFLRHook Technical Specification

## Overview

A new Solidity hook that withdraws only the vested (unlocked) rFLR from Flare's RNat contract as WFLR, avoiding the 50% penalty on locked tokens. Deployed alongside the existing `WithdrawRFLRHook` which withdraws everything (with penalty on locked portion).

## Problem Statement

The existing `WithdrawRFLRHook` calls `IRNat.withdrawAll(true)` which burns 50% of unvested/locked rFLR. Curators managing SuperVaults on Flare need an option to withdraw only the penalty-free vested portion. The RNat contract exposes `withdraw(uint128 _amount, bool _wrap)` for exactly this purpose.

## Proposed Solution

1. Add `withdraw(uint128, bool)` to `IRNat.sol` interface
2. New `WithdrawVestedRFLRHook` that:
   - Calls `getBalancesOf(account)` to get `(wNatBalance, rNatBalance, lockedBalance)`
   - Computes `vestedAmount = rNatBalance - lockedBalance` (with underflow guard)
   - Safe-casts to `uint128` via OpenZeppelin SafeCast
   - Calls `withdraw(vestedAmount, true)` for penalty-free WFLR output
   - Reverts if nothing is vested
   - Optional minOut slippage protection

## Technical Considerations

- **`lockedBalance >= rNatBalance` is possible** after partial vested withdrawals — must guard against underflow
- **uint256 → uint128 safe cast required** — `getBalancesOf` returns uint256, `withdraw` takes uint128
- **`_buildHookExecutions` is `view`** — can call `getBalancesOf(account)` at build time to compute withdrawal amount
- **Vesting is time-based** (rolling 12-month linear per monthly allocation) — not MEV-manipulable
- **RNat has no reentrancy guard on `withdraw`** — mitigated by BaseHook transient storage mutexes and atomic execution

## Attack Surface Analysis

### Safe Cast
- [x] SafeCast.toUint128() for uint256 → uint128 downcast (Cetus exploit precedent — $223M)

### Reentrancy
- [x] CEI pattern followed — balance snapshot before, delta after
- [x] BaseHook transient storage mutexes prevent double pre/post execute
- [x] RNat is trusted Flare system contract, WFLR is WETH9-pattern (no callbacks)

### Edge Cases
- [x] `lockedBalance >= rNatBalance` — revert with `NOTHING_TO_WITHDRAW()`
- [x] Zero vested amount — same revert
- [x] View function staleness — accepted trade-off; vesting only unlocks, never re-locks

## Acceptance Criteria

- [ ] `IRNat.sol` updated with `withdraw(uint128, bool)` function
- [ ] `WithdrawVestedRFLRHook.sol` created at `src/hooks/claim/flare/`
- [ ] Reverts with `NOTHING_TO_WITHDRAW()` when vested amount is 0
- [ ] SafeCast.toUint128() used for downcast
- [ ] minOut slippage check in `_postExecute` via hook data
- [ ] NatSpec documents: no-penalty guarantee, MEV assumption, view call timing
- [ ] Unit tests cover: normal withdrawal, zero vested revert, slippage pass/fail, uint128 overflow
- [ ] Added to deploy pipeline (ConstantsOtherHooks, DeployV2OtherHooks, regenerate_bytecode.sh)
- [ ] Bytecode in locked-bytecode and locked-bytecode-dev

## Implementation

### 1. `src/vendor/flare/IRNat.sol` — Add withdraw function

```solidity
/// @notice Withdraws a specific amount of unlocked funds from the caller's RNat account
/// @dev Only withdraws from vested (unlocked) balance. Reverts if amount > unlocked balance.
///      No penalty applied (unlike withdrawAll which penalizes locked portion).
/// @param _amount Amount of tokens to transfer (in wei)
/// @param _wrap If true returns WFLR (ERC-20); if false returns native FLR
function withdraw(uint128 _amount, bool _wrap) external;
```

### 2. `src/hooks/claim/flare/WithdrawVestedRFLRHook.sol`

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IRNat } from "../../../vendor/flare/IRNat.sol";
import { BaseHook } from "../../BaseHook.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";

/// @title WithdrawVestedRFLRHook
/// @author Superform Labs
/// @notice Withdraws only the vested (unlocked) rFLR from RNat as WFLR. No penalty applied.
/// @dev Uses IRNat.withdraw(amount, true) instead of withdrawAll to avoid the 50% burn on locked tokens.
///      The vested amount is computed as rNatBalance - lockedBalance via getBalancesOf().
///      Vesting is time-based (rolling 12-month linear per monthly allocation) and is not
///      manipulable by third parties.
///      data layout:
///        [0:32]  uint256 minOut — minimum WFLR delta the caller will accept.
///                If omitted (data.length < 32) or zero, no slippage check is enforced.
contract WithdrawVestedRFLRHook is BaseHook {
    using SafeCast for uint256;

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when there is no vested rFLR to withdraw (rNatBalance <= lockedBalance)
    error NOTHING_TO_WITHDRAW();

    /// @notice Thrown when the WFLR delta is below the caller-specified minOut
    error SLIPPAGE_EXCEEDED();

    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The IRNat contract
    address public immutable RNAT;

    /// @notice The WFLR (wrapped FLR) ERC-20 token
    address public immutable WFLR;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Minimum data length required for the minOut field (32 bytes uint256)
    uint256 private constant MIN_DATA_LENGTH_WITH_MIN_OUT = 32;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address rNat_, address wflr_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.CLAIM) {
        if (rNat_ == address(0) || wflr_ == address(0)) revert ADDRESS_NOT_VALID();
        RNAT = rNat_;
        WFLR = wflr_;
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address account,
        bytes calldata
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        (, uint256 rNatBalance, uint256 lockedBalance) = IRNat(RNAT).getBalancesOf(account);

        if (rNatBalance <= lockedBalance) revert NOTHING_TO_WITHDRAW();

        uint256 vestedAmount = rNatBalance - lockedBalance;
        uint128 withdrawAmount = vestedAmount.toUint128();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: RNAT,
            value: 0,
            callData: abi.encodeCall(IRNat.withdraw, (withdrawAmount, true))
        });
    }

    /// @inheritdoc BaseHook
    function inspect(bytes calldata) external view override returns (bytes memory) {
        return abi.encodePacked(RNAT);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    /// @dev Snapshots the WFLR balance before withdrawal execution.
    function _preExecute(address, address account, bytes calldata) internal override {
        asset = WFLR;
        _setOutAmount(IERC20(WFLR).balanceOf(account), account);
    }

    /// @inheritdoc BaseHook
    /// @dev outAmount is the WFLR delta (balance after minus balance before).
    ///      Enforces minOut slippage check if provided in hook data.
    function _postExecute(address, address account, bytes calldata data) internal override {
        uint256 currentBalance = IERC20(WFLR).balanceOf(account);
        uint256 preBalance = getOutAmount(account);
        uint256 delta = currentBalance > preBalance ? currentBalance - preBalance : 0;

        if (data.length >= MIN_DATA_LENGTH_WITH_MIN_OUT) {
            uint256 minOut = BytesLib.toUint256(data, 0);
            if (minOut > 0 && delta < minOut) revert SLIPPAGE_EXCEEDED();
        }

        _setOutAmount(delta, account);
    }
}
```

### 3. Deploy Pipeline Changes

**`script/utils/ConstantsOtherHooks.sol`** — Add:
```solidity
string internal constant WITHDRAW_VESTED_RFLR_HOOK_KEY = "WithdrawVestedRFLRHook";
```

**`script/run/regenerate_bytecode.sh`** — Add to `RFLR_HOOK_CONTRACTS`:
```bash
RFLR_HOOK_CONTRACTS=(
    "ClaimRFLRHook"
    "WithdrawRFLRHook"
    "WithdrawVestedRFLRHook"
)
```

**`script/DeployV2OtherHooks.s.sol`** — Add to `RFLRHookAddresses` struct and `_deployRFLRHooks` function with constructor args `abi.encode(RNAT_FLARE, WFLR_FLARE)`.

**`script/run/deploy_v2_other_hooks_staging_prod.sh`** — Add `"WithdrawVestedRFLRHook"` to `RFLR_HOOKS` array.

### 4. Test File: `test/unit/hooks/claim/rflr/WithdrawVestedRFLRHookTest.t.sol`

Test cases:
- **Constructor:** validates immutables, reverts on zero addresses
- **Build:** verify execution array with correct `withdraw(amount, true)` calldata
- **Build revert:** `NOTHING_TO_WITHDRAW` when rNatBalance == 0, when lockedBalance >= rNatBalance
- **Pre/Post execute:** verify WFLR delta tracking
- **Slippage pass:** delta >= minOut succeeds
- **Slippage fail:** delta < minOut reverts with `SLIPPAGE_EXCEEDED`
- **No slippage data:** succeeds when data.length < 32
- **SafeCast overflow:** verify revert when vested amount > uint128.max (mock extreme values)
- **Inspect:** returns abi.encodePacked(RNAT)

## References

- Existing hook: `src/hooks/claim/flare/WithdrawRFLRHook.sol`
- RNat interface: `src/vendor/flare/IRNat.sol`
- Full RNat interface: https://github.com/flare-foundation/flare-foundry-periphery-package/blob/main/src/flare/IRNat.sol
- SafeCast usage: `src/hooks/tokens/permit2/BatchTransferFromHook.sol`, `src/hooks/swappers/1inch/Swap1InchHook.sol`
