# EVM Security Research — Stargate Native Fee Sponsorship

## Vulnerability Assessment Summary

| # | Category | Severity | Status |
|---|----------|----------|--------|
| 1 | Reentrancy — Single-function | LOW | Mitigated by CEI + ReentrancyGuard |
| 2 | Reentrancy — Cross-function | LOW | Mitigated by ReentrancyGuard on all mutating functions |
| 3 | Reentrancy — Cross-contract | LOW | Smart accounts (Nexus/Safe) are trusted |
| 4 | Reentrancy — Read-only | INFO | No view functions used by other contracts for state decisions |
| 5 | Access Control | INFO | Permissionless by design — no role-based access |
| 6 | Integer Overflow | INFO | Solidity 0.8.30 checked math |
| 7 | ETH Transfer Failure | LOW | Handled by `ETH_TRANSFER_FAILED` revert |
| 8 | Front-running — Deposit/Withdraw Race | MEDIUM | Accepted tradeoff; atomic wrapper mitigates normal flow |
| 9 | Flash Loan Exploitation | INFO | No price-dependent logic; pure ledger contract |
| 10 | Oracle Manipulation | N/A | No oracle dependencies |
| 11 | MEV/Sandwich | LOW | Deposit+handleOps is atomic; no swap/price exposure |
| 12 | Proxy/Upgrade | N/A | No proxy pattern used |
| 13 | Orphaned Deposits | MEDIUM | Inner call revert leaves deposits; manual reclaim required |
| 14 | Zero-address Deposits | LOW | Validated in all functions |
| 15 | Gas Griefing | LOW | ETH transfer to smart account could consume gas; trusted recipients |
| 16 | Denial of Service | LOW | No loops, no unbounded operations |
| 17 | Signature Replay | N/A | No signatures used (open balance model) |
| 18 | Cross-chain Replay | N/A | Each chain has independent sponsorship contract |

## Detailed Analysis

### HIGH Severity: 0

### MEDIUM Severity: 2

#### M-1: Orphaned Deposits on Inner Call Failure
- **Vector:** If UserOp execution reverts inside `innerHandleOp`, the FetchNativeFeeHook withdrawal is reverted, but the sponsorship deposit persists
- **Impact:** Bundler's ETH is stuck until manual reclaim
- **Mitigation:** `withdrawSponsorDeposit` allows sponsor to reclaim; bundler monitors for failed UserOps
- **Decision:** Accepted tradeoff per spec

#### M-2: Deposit/Withdraw Race Condition
- **Vector:** Between `sponsorNativeAndHandleUserOp` depositing and `FetchNativeFeeHook` withdrawing, the sponsor could call `withdrawSponsorDeposit` in a competing transaction
- **Impact:** FetchNativeFeeHook withdrawal fails, UserOp execution reverts, entire tx reverts (safe)
- **Likelihood:** Extremely low — bundler controls both transactions
- **Decision:** Accepted tradeoff per spec

### LOW Severity: 5

#### L-1: ETH Transfer Failure to Smart Account
- Smart accounts (Nexus/Safe) should always accept ETH
- If a custom account rejects ETH, withdrawal reverts with `ETH_TRANSFER_FAILED`
- No fund loss — ETH stays in sponsorship contract

#### L-2: Gas Consumption on ETH Transfer
- `call{value: amount}("")` forwards all gas to recipient
- Malicious recipient could consume excessive gas
- Mitigated: Only trusted smart accounts interact with the system

#### L-3: Zero-amount Edge Cases
- All functions validate `amount > 0` or `msg.value > 0`
- Zero-address validated on all external-facing parameters

#### L-4: Single-function Reentrancy
- CEI pattern followed in all functions
- ReentrancyGuard as defense-in-depth
- State updated before ETH transfers

#### L-5: MEV on Sponsorship Transactions
- Deposit+handleOps is atomic (single tx)
- No swap or price-dependent logic exposed to MEV
- Sandwich attacks not applicable

## Recommendations

1. **Use `ReentrancyGuardTransient`** instead of `ReentrancyGuard` for ~2000 gas savings (EIP-1153)
2. **Verify EntryPoint version** accepts contract-initiated `handleOps` calls
3. **Monitor orphaned deposits** — bundler should track failed UserOps and reclaim
4. **Consider adding a `receive()` function** to NativeFeeSponsorship if direct ETH sends are expected (currently not needed)
5. **Fuzz test boundaries:** max uint256 deposits, rapid deposit/withdraw cycles, multiple sponsors per account

## Exploit Precedent Check

No direct precedents for this exact pattern. Related:
- **Ronin Bridge (2022, $624M)** — different: centralized validator compromise, not relevant
- **ERC-4337 paymaster exploits** — none known for native sponsorship (novel pattern)
- **LayerZero fee handling** — standard pattern, no known exploits on fee quoting

## Recommended Fuzz Test Invariants

1. `sum(all deposits) - sum(all withdrawals) == contract.balance`
2. `sponsoredNative[s][a] >= 0` (always true with checked math, but verify)
3. After `withdrawSponsoredNative(s, amount)`: `pre_balance - amount == post_balance`
4. After `withdrawSponsorDeposit(a, to, amount)`: `pre_balance - amount == post_balance`
5. No function can increase `sponsoredNative[s][a]` without receiving exactly that amount of ETH
