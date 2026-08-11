# Aave V3 Hooks — Interview Notes

**Date:** 2026-08-05
**Feature:** Aave V3 lending hooks for Superform v2-core
**Security mode:** auto-enabled (on-chain lending logic)

## Feature Summary
Create a suite of Superform v2 hooks integrating Aave V3 lending, mirroring the existing
Aave V4 suite (`src/hooks/loan/aave-v4/`) but targeting the Aave V3 `IPool` interface. Aave V3 is
the dominant lending deployment across nearly all chains, whereas V4 is currently Ethereum-only, so
V3 hooks materially expand cross-chain lending coverage.

## Key Structural Difference: V3 keys on asset address, not reserveId
Aave V4 uses a Hub-and-Spoke model where operations take a `reserveId` and a `spoke` address. Aave V3
uses a single `Pool` per market, and every operation takes the **asset token address** directly:

- `supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)`
- `withdraw(address asset, uint256 amount, address to) returns (uint256)`
- `borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf)`
- `repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf) returns (uint256)`
- `repayWithATokens(address asset, uint256 amount, uint256 interestRateMode) returns (uint256)`
- `setUserUseReserveAsCollateral(address asset, bool useAsCollateral)`

Consequence: hook data carries **asset addresses + pool + amount** (no reserveIds). Simpler layout than V4.

## Aave V3 Market/Pool Architecture (decision driver)
- One `Pool` = one **market**, and that Pool serves **all** assets/reserves in that market (never per-asset).
- A chain can host **multiple independent markets**, each with its own Pool (e.g. Ethereum: Core, Prime,
  EtherFi). Most other chains have a single main market/Pool.
- Different chains have different Pool addresses.
- => Baking the Pool into the constructor would force one deployment per (chain × market). To avoid that,
  the Pool address is passed **in hook data** (exactly as V4 passes the Spoke), enabling a single hook
  deployment (one CREATE2 address) to serve every V3 market on every chain.

## Decisions (from interview)

| Topic | Decision | Rationale |
|-------|----------|-----------|
| Pool address source | **Encoded in hook data** | One deployment works with all V3 markets (Core/Prime/EtherFi) and all chains. Mirrors V4's Spoke-in-data model (`BaseAaveV4LoanHook`: "Spoke address comes from calldata rather than the constructor"). |
| Interest rate mode | **Configurable byte in hook data** | Variable (2) in practice on all live V3.1 markets (stable removed), but per-call selectable to remain forward/backward compatible. Applies to borrow, repay, repayWithATokens. |
| Hook scope | **All 6 V4-mirrored hooks + `repayWithATokens` (7th)** | Full parity with V4 plus V3-specific aToken repayment for leverage-unwind routes. |
| Collateral control | **Rely on Aave auto-enable** | V3 auto-enables collateral on first supply; no dedicated toggle hook for MVP (matches V4 behavior). |
| Target chains | **Ethereum (mirror V4 tests) + Arbitrum, Base, Optimism, Polygon** | Cover the dominant V3 deployments; fork tests per chain. |
| Accounting | **NONACCOUNTING** (mirror V4 loan hooks) | Loan operations are not yield-source cost-basis accounted. |
| onBehalfOf / recipient | **Always the account** | Consistent with all other Superform loan hooks (V4, Morpho). |
| referralCode | **0** | Aave referral program inactive; hardcode 0. |

## Hook Inventory (target)
1. `BaseAaveV3LoanHook` — shared decoding, market-param handling, pipe/accounting config.
2. `AaveV3SupplyHook` — supply asset (collateral / lend).
3. `AaveV3WithdrawHook` — withdraw supplied asset (max = type(uint256).max for full).
4. `AaveV3BorrowHook` — borrow asset (rate-mode byte).
5. `AaveV3RepayHook` — repay debt with underlying (rate-mode byte; max for full).
6. `AaveV3SupplyAndBorrowHook` — supply collateral then borrow in one hook.
7. `AaveV3RepayAndWithdrawHook` — repay then withdraw collateral in one hook.
8. `AaveV3RepayWithATokensHook` — repay debt directly using held aTokens (no underlying transfer).

## Open Questions (resolved)
| Question | Answer |
|----------|--------|
| Does one Pool cover all V3 markets? | No — one Pool per market; multiple markets per chain. Solved by Pool-in-data. |
| repayWithATokens as a 7th hook? | Yes, include it. |
| MVP chains | Ethereum + Arbitrum + Base + Optimism + Polygon. |

## Testing Strategy (seed)
- Unit tests per hook: data decode, execution build (approve/supply/borrow/etc.), usePrevHookAmount, reverts.
- Fork integration tests (no-mock, real Pool) per chain, mirroring `AaveV4HooksIntegrationTest` and the
  Base/multi-reserve pattern: supply, borrow-after-supply, partial/full repay, withdraw, combined hooks,
  full lifecycle, repayWithATokens, multi-asset markets.
- Pin fork blocks (avoid latest-fork CI flakiness).

## Security Focus (to expand in technical spec)
- SafeERC20 / balance-delta verification on transfers (weird-erc20: fee-on-transfer, missing-return, e.g. USDT).
- Approval hygiene (approve 0 → amount → 0), mirror V4.
- Full-repay dust / interest accrual timing (approve enough; `type(uint256).max` repay semantics).
- Health-factor / LTV: hooks are user-signed intents; no oracle logic in-hook, but document liquidation exposure.
- Isolation mode & siloed borrowing reserves (V3-specific): borrowing constraints per market.
- Reentrancy: hooks build executions run by the account; CEI + approval reset.
