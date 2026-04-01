# MorphoLendHook Technical Specification

## Overview

Create a `MorphoLendHook` that calls Morpho Blue's `supply()` function, enabling SuperVault strategies to lend assets directly to Morpho Blue markets and earn interest from borrowers.

This is the **lender side** of Morpho Blue, distinct from the existing borrower-side hooks:
- `MorphoSupplyHook` calls `supplyCollateral()` (borrower deposits collateral, no yield)
- `MorphoLendHook` calls `supply()` (lender deposits loanToken, earns yield)

## Problem Statement

SuperVault strategies currently interact with Morpho Blue only as borrowers (collateral + borrow). To earn yield from Morpho Blue markets directly (without MetaMorpho vaults as intermediaries), we need a lender-side hook. This enables strategies to supply liquidity to specific markets and earn interest paid by borrowers.

## Proposed Solution

### Scope
1. **MorphoLendHook** (new) - calls `IMorphoBase.supply()`
2. **MorphoLendWithdrawHook** (new) - calls `IMorphoBase.withdraw()` with correct loanToken balance tracking
3. **E2E test** - fork test using real deployed SuperVaultStrategy

### Why a New Withdrawal Hook?

The existing `MorphoWithdrawHook` has a bug for lending positions: its `_preExecute`/`_postExecute` tracks `collateralToken` balance (via `getCollateralTokenBalance`), but `withdraw()` returns `loanToken` to the receiver. For lending withdrawals, `outAmount` would be **zero**, breaking any downstream hook chain using `usePrevHookAmount`.

The user explicitly said "Create a new hook if we need so. Don't modify the existing one."

## Technical Considerations

### HookType: NONACCOUNTING
- `BaseLoanHook` forces `HookType.NONACCOUNTING` — all Morpho hooks inherit this
- Oracle/accounting integration deferred to a separate spec
- When oracle is added later, may need to change to INFLOW with redesigned data layout

### Data Layout
```
loanToken(20)|collateralToken(20)|oracle(20)|irm(20)|amount(32)|lltv(32)|usePrevHookAmount(1)
```
- Offsets: loanToken=0, collateralToken=20, oracle=40, irm=60, amount=80, lltv=112, usePrevHookAmount=144
- Same as MorphoSupplyHook — all 5 MarketParams fields needed for market identification
- `collateralToken` and `lltv` are market identifiers, not lending parameters

### MorphoLendWithdrawHook Data Layout
```
loanToken(20)|collateralToken(20)|oracle(20)|irm(20)|onBehalf(20)|recipient(20)|lltv(32)|assets(32)|shares(32)
```
- Same as existing MorphoWithdrawHook layout
- Difference: `_preExecute`/`_postExecute` tracks `loanToken` balance (not collateralToken)

### Execution Sequence (MorphoLendHook)
```solidity
executions = new Execution[](3);
// 1. Reset approval (handles USDT)
executions[0] = Execution(loanToken, 0, IERC20.approve(morpho, 0));
// 2. Set exact approval
executions[1] = Execution(loanToken, 0, IERC20.approve(morpho, amount));
// 3. Supply to Morpho Blue market
executions[2] = Execution(morpho, 0, IMorphoBase.supply(marketParams, amount, 0, account, ""));
```

### Execution Sequence (MorphoLendWithdrawHook)
```solidity
executions = new Execution[](1);
// Withdraw from Morpho Blue market (assets or shares)
executions[0] = Execution(morpho, 0, IMorphoBase.withdraw(marketParams, assets, shares, onBehalf, receiver));
```

### outAmount Tracking
- **MorphoLendHook**: tracks `loanToken` balance decrease (amount spent)
  - `_preExecute`: store `getLoanTokenBalance(account, data)`
  - `_postExecute`: `outAmount = preBalance - postBalance`
- **MorphoLendWithdrawHook**: tracks `loanToken` balance increase (amount received)
  - `_preExecute`: store `getLoanTokenBalance(recipient, data)`
  - `_postExecute`: `outAmount = postBalance - preBalance`

### Key Differences: supply() vs supplyCollateral()
| Aspect | `supplyCollateral()` (existing) | `supply()` (new) |
|--------|--------------------------------|------------------|
| Token approved | collateralToken | loanToken |
| Yield | None | Interest from borrowers |
| Position tracked | collateral (uint128) | supplyShares (uint256) |
| Function sig | `(marketParams, assets, onBehalf, data)` | `(marketParams, assets, shares, onBehalf, data)` |

### Interest Accrual
- `supply()` auto-calls `_accrueInterest()` internally — no explicit call needed
- Supply shares don't change — value per share increases as `totalSupplyAssets` grows
- For withdrawal: call `accrueInterest()` before reading position state in `_preExecute`

### Security
- Empty callback data `""` prevents `onMorphoSupply` callback
- No reentrancy risk
- No front-running vulnerability on `supply()`
- Flash loans don't affect supply shares
- USDT compatibility via approve(0) reset pattern

## Acceptance Criteria

### Functional
- [ ] MorphoLendHook calls `supply(marketParams, amount, 0, account, "")` with correct loanToken approval
- [ ] MorphoLendWithdrawHook calls `withdraw()` and tracks loanToken balance for outAmount
- [ ] Both hooks extend BaseMorphoLoanHook, use HookSubTypes.LOAN
- [ ] usePrevHookAmount works correctly when chained
- [ ] Data encoding matches existing Morpho hook patterns

### Testing
- [ ] E2E test: Lend USDC to a Morpho Blue market via real SuperVaultStrategy
- [ ] E2E test: Withdraw lent USDC + accrued interest via MorphoLendWithdrawHook
- [ ] E2E test: Full cycle (lend → time passes → withdraw with interest)
- [ ] E2E test: Chained hooks (swap → lend)

## Implementation

### File: `src/hooks/loan/morpho/MorphoLendHook.sol`

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IMorphoBase, MarketParams } from "../../../vendor/morpho/IMorpho.sol";

import { BaseMorphoLoanHook } from "./BaseMorphoLoanHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookResult } from "../../../interfaces/ISuperHook.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

contract MorphoLendHook is BaseMorphoLoanHook {
    using HookDataDecoder for bytes;

    address public morpho;
    IMorphoBase public morphoBase;

    struct LendHookLocalVars {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 amount;
        uint256 lltv;
        bool usePrevHookAmount;
    }

    constructor(address morpho_) BaseMorphoLoanHook(morpho_, HookSubTypes.LOAN) {
        morpho = morpho_;
        morphoBase = IMorphoBase(morpho_);
    }

    function _buildHookExecutions(
        address prevHook,
        address account,
        bytes calldata data
    ) internal view override returns (Execution[] memory executions) {
        LendHookLocalVars memory vars = _decodeLendHookData(data);

        if (vars.usePrevHookAmount) {
            vars.amount = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (vars.amount == 0) revert AMOUNT_NOT_VALID();
        if (vars.loanToken == address(0) || vars.collateralToken == address(0)
            || vars.oracle == address(0) || vars.irm == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        MarketParams memory marketParams = _generateMarketParams(
            vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv
        );

        executions = new Execution[](3);
        // 1. Reset approval (handles USDT)
        executions[0] = Execution({
            target: vars.loanToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (morpho, 0))
        });
        // 2. Set approval for supply amount
        executions[1] = Execution({
            target: vars.loanToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (morpho, vars.amount))
        });
        // 3. Supply to Morpho Blue as lender
        executions[2] = Execution({
            target: morpho,
            value: 0,
            callData: abi.encodeCall(
                IMorphoBase.supply,
                (marketParams, vars.amount, 0, account, "")
            )
        });
    }

    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        LendHookLocalVars memory vars = _decodeLendHookData(data);
        MarketParams memory marketParams = _generateMarketParams(
            vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv
        );
        return abi.encodePacked(
            marketParams.loanToken, marketParams.collateralToken,
            marketParams.oracle, marketParams.irm
        );
    }

    function _decodeLendHookData(bytes memory data) internal pure returns (LendHookLocalVars memory vars) {
        vars = LendHookLocalVars({
            loanToken: BytesLib.toAddress(data, 0),
            collateralToken: BytesLib.toAddress(data, 20),
            oracle: BytesLib.toAddress(data, 40),
            irm: BytesLib.toAddress(data, 60),
            amount: _decodeAmount(data),
            lltv: BytesLib.toUint256(data, 112),
            usePrevHookAmount: _decodeBool(data, 144)
        });
    }

    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getLoanTokenBalance(account, data), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getOutAmount(account) - getLoanTokenBalance(account, data), account);
    }
}
```

### File: `src/hooks/loan/morpho/MorphoLendWithdrawHook.sol`

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MarketParamsLib } from "../../../vendor/morpho/MarketParamsLib.sol";
import { IMorphoBase, MarketParams } from "../../../vendor/morpho/IMorpho.sol";

import { BaseMorphoLoanHook } from "./BaseMorphoLoanHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

contract MorphoLendWithdrawHook is BaseMorphoLoanHook {
    using MarketParamsLib for MarketParams;
    using HookDataDecoder for bytes;

    address public morpho;
    IMorphoBase public morphoBase;

    struct WithdrawHookVars {
        MarketParams marketParams;
        address onBehalf;
        address receiver;
        uint256 assets;
        uint256 shares;
    }

    constructor(address morpho_) BaseMorphoLoanHook(morpho_, HookSubTypes.LOAN_REPAY) {
        morpho = morpho_;
        morphoBase = IMorphoBase(morpho_);
    }

    function _buildHookExecutions(
        address,
        address,
        bytes calldata data
    ) internal view override returns (Execution[] memory executions) {
        WithdrawHookVars memory vars = _decodeWithdrawData(data);
        if (vars.assets == 0 && vars.shares == 0) revert AMOUNT_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: morpho,
            value: 0,
            callData: abi.encodeCall(
                IMorphoBase.withdraw,
                (vars.marketParams, vars.assets, vars.shares, vars.onBehalf, vars.receiver)
            )
        });
    }

    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        WithdrawHookVars memory vars = _decodeWithdrawData(data);
        return abi.encodePacked(
            vars.marketParams.loanToken, vars.marketParams.collateralToken,
            vars.marketParams.oracle, vars.marketParams.irm
        );
    }

    // Tracks LOANTOKEN balance (unlike MorphoWithdrawHook which tracks collateralToken)
    function _preExecute(address, address, bytes calldata data) internal override {
        address recipient = BytesLib.toAddress(data, 100);
        _setOutAmount(getLoanTokenBalance(recipient, data), recipient);
    }

    function _postExecute(address, address, bytes calldata data) internal override {
        address recipient = BytesLib.toAddress(data, 100);
        _setOutAmount(getLoanTokenBalance(recipient, data) - getOutAmount(recipient), recipient);
    }

    function _decodeWithdrawData(bytes calldata data) internal pure returns (WithdrawHookVars memory vars) {
        address loanToken = BytesLib.toAddress(data, 0);
        address collateralToken = BytesLib.toAddress(data, 20);
        address oracle = BytesLib.toAddress(data, 40);
        address irm = BytesLib.toAddress(data, 60);
        address onBehalf = BytesLib.toAddress(data, 80);
        address recipient = BytesLib.toAddress(data, 100);
        uint256 lltv = BytesLib.toUint256(data, 120);
        uint256 assets = BytesLib.toUint256(data, 152);
        uint256 shares = BytesLib.toUint256(data, 184);

        if (loanToken == address(0) || collateralToken == address(0)
            || oracle == address(0) || irm == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        vars = WithdrawHookVars({
            marketParams: _generateMarketParams(loanToken, collateralToken, oracle, irm, lltv),
            onBehalf: onBehalf,
            receiver: recipient,
            assets: assets,
            shares: shares
        });
    }
}
```

### File: `test/integration/morpho/MorphoLendE2E.t.sol`

E2E test following MorphoSuperVaultE2E.t.sol pattern:
- Fork mainnet at block 23_930_000
- Deploy MorphoLendHook and MorphoLendWithdrawHook
- Use real SuperVaultStrategy (0x41A9Eb398518D2487301c61D2b33E4e966A9F1DD)
- vm.mockCall for isHookRegistered, validateHook, isAnyManager
- vm.prank(MANAGER) for execution

Test cases:
1. **test_Lend_SupplyUSDC**: Lend USDC to WBTC/USDC market, verify supplyShares > 0
2. **test_LendAndWithdraw_FullCycle**: Lend → warp time → withdraw all via shares
3. **test_LendAndWithdraw_Partial**: Lend → withdraw partial amount via assets
4. **test_Lend_WithPrevHookAmount**: Chain with a swap hook using usePrevHookAmount

## References
- MorphoSupplyHook: src/hooks/loan/morpho/MorphoSupplyHook.sol (closest analog)
- MorphoWithdrawHook: src/hooks/loan/morpho/MorphoWithdrawHook.sol (outAmount bug for lending)
- BaseMorphoLoanHook: src/hooks/loan/morpho/BaseMorphoLoanHook.sol:73-91 (_generateMarketParams)
- BaseLoanHook: src/hooks/loan/BaseLoanHook.sol:55-58 (getLoanTokenBalance)
- IMorphoBase.supply(): src/vendor/morpho/IMorpho.sol:145-153
- Morpho Blue docs: https://docs.morpho.org/build/borrow/tutorials/assets-flow/
