# Spark PSM Integration Best Practices

## 1. Overview

The Spark PSM (Peg Stability Module) is the primary venue for USDS, USDC, and sUSDS swaps on L2 chains (Base, Arbitrum).

**Key properties:**
- **Zero fees** -- no swap fee beyond gas
- **Zero slippage** -- deterministic pricing, NOT an AMM
- Supports: USDC (6 dec), USDS (18 dec), sUSDS (18 dec)
- USDC/USDS: always 1:1
- sUSDS: oracle-based rate from `rateProvider` (1e27 precision)
- Audited by ChainSecurity (Oct 2024) -- "high level of security"

## 2. PSM Interface

### swapExactIn
- Swaps precise `amountIn` for variable `amountOut`
- Reverts if `amountOut < minAmountOut`
- Pulls tokens via `transferFrom(msg.sender, ...)`
- Sends output to `receiver`

### swapExactOut
- Swaps variable `amountIn` for precise `amountOut`
- Reverts if `amountIn > maxAmountIn`
- Returns actual `amountIn` consumed

### Preview Functions
- `previewSwapExactIn` / `previewSwapExactOut` for quoting
- **CRITICAL:** Preview functions do NOT round the same way as actual swaps. Add a small buffer.

## 3. Rate Handling

- **USDC <-> USDS:** Fixed 1:1, only decimal adjustment (6 vs 18)
- **sUSDS:** Uses `rateProvider` returning rate in 1e27 precision. Rate increases over time (yield accrual). Not manipulable via flash loans.
- **No price impact:** PSM is NOT an AMM. Output is deterministic.

## 4. Rounding

- **swapExactIn:** Rounds DOWN output (user gets slightly less)
- **swapExactOut:** Rounds UP input (user pays slightly more)
- Difference: typically 1 wei in lowest-precision token
- Set `minAmountOut`/`maxAmountIn` with small buffer beyond preview

## 5. Referral Code

- `uint256 referralCode` -- emitted in `Swap` event for attribution
- Does NOT affect pricing or execution
- Pass directly from hook data

## 6. Approval Pattern

PSM uses `transferFrom(msg.sender, ...)`. Smart account must approve PSM for input amount.

Pattern for ApproveAnd* hooks:
1. `approve(PSM, 0)` -- reset
2. `approve(PSM, amountIn)` -- set exact
3. `PSM.swapExactIn/Out(...)` -- execute
4. `approve(PSM, 0)` -- revoke

## 7. Gas Costs

- Swap-only: ~80k-120k gas
- ApproveAndSwap: ~155k-195k gas
- Cheaper than Uniswap V3 (~150k+) or aggregators (200k-500k+)
- On Base L2, gas cost is negligible

## 8. Known Gotchas

1. **Temporary DoS via drainage:** Attacker can drain PSM output assets causing reverts. Temporary, PSM replenished by Spark Liquidity Layer.
2. **Preview vs actual rounding mismatch:** Don't use preview results as exact slippage params.
3. **Decimal precision:** USDC 6 dec vs USDS/sUSDS 18 dec -- HookDataUpdater handles via percentage scaling.
4. **sUSDS rate changes:** Rate may change between signing and execution. Set appropriate slippage.
5. **No token validation:** Per interview decision, let PSM revert on invalid tokens.

## 9. Audit

ChainSecurity (Oct 2024):
- No critical findings
- Pocket DoS (medium) -- owner-managed
- Rounding griefing (low) -- 1 wei per attack
- Rate provider sandwich (info) -- governance-controlled rate

## Sources

- [Spark PSM Docs](https://docs.spark.fi/dev/savings/spark-psm)
- [GitHub: sparkdotfi/spark-psm](https://github.com/sparkdotfi/spark-psm)
- [ChainSecurity Audit](https://www.chainsecurity.com/security-audit/spark-psm)
- [BaseScan PSM3](https://basescan.org/address/0x1601843c5E9bC251A3272907010AFa41Fa18347E)
