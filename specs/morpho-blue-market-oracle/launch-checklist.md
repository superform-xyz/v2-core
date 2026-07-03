# Morpho Blue Market Oracle — Launch Checklist

> This PR delivers the oracle/registry substrate. The items below track the configuration
> and wiring work required before the oracle is live for production accounting.
> None of these are in scope for the substrate PR — they are tracked here to prevent
> the launch/config layer from being accidentally treated as done.

## Status Key

- `[ ]` Not started
- `[~]` In progress
- `[x]` Done
- `[n/a]` Not applicable for this launch

---

## 1. Contract Deployment

| Step | Chain | Status | Notes |
|------|-------|--------|-------|
| Deploy `MorphoBlueMarketRegistry` | Ethereum | `[ ]` | Deterministic address via CREATE2 |
| Deploy `MorphoBlueMarketRegistry` | Base | `[ ]` | Same bytecode, same address |
| Deploy `MorphoBlueYieldSourceOracle` | Ethereum | `[ ]` | Constructor: `(superLedgerConfig, registry)` |
| Deploy `MorphoBlueYieldSourceOracle` | Base | `[ ]` | Constructor: `(superLedgerConfig, registry)` |

---

## 2. Registry Configuration

| Step | Status | Notes |
|------|--------|-------|
| Approve IRMs via `setIrmApproval` | `[ ]` | One call per IRM address; typically AdaptiveCurveIRM |
| Register markets via `registerMarket` | `[ ]` | Blocked until Morpho markets are created; need exact `MarketParams` |
| Verify market keys match expected pseudo-addresses | `[ ]` | `computeMarketKey(...)` or check `MarketRegistered` event logs |
| Document registered market keys in ops config | `[ ]` | Map market key → human-readable name (e.g., "USDC/equity-X supply") |

### Markets to register (fill in when known)

| Market | loanToken | collateralToken | oracle | irm | lltv | marketKey |
|--------|-----------|-----------------|--------|-----|------|-----------|
| TBD | | | | | | |

---

## 3. SuperLedgerConfiguration

| Step | Status | Notes |
|------|--------|-------|
| Register oracle ID for each market key | `[ ]` | Links market key → oracle for fee calculations |
| Configure fee parameters (performance fee bps) | `[ ]` | Per-vault or per-strategy |
| Verify PPS reads work end-to-end through ledger | `[ ]` | `getPricePerShare(marketKey)` returns sane value |

---

## 4. Ownership & Access Control

| Step | Status | Notes |
|------|--------|-------|
| Transfer `DEFAULT_ADMIN_ROLE` on registry to multisig | `[ ]` | Deployer retains temporarily for setup |
| Grant `MARKET_MANAGER_ROLE` to ops multisig | `[ ]` | For register/deregister operations |
| Revoke `MARKET_MANAGER_ROLE` from deployer EOA | `[ ]` | After setup complete |
| Verify role assignments via `hasRole` | `[ ]` | |

---

## 5. Monitoring

| Step | Status | Notes |
|------|--------|-------|
| Deploy `monitorMorphoRegistryDeregistration` Tenderly action | `[ ]` | Alerts on `MarketDeregistrationProposed` / `MarketDeregistered` events |
| Configure Tenderly transaction trigger for registry address | `[ ]` | Per chain (Ethereum, Base) |
| Add market keys to PPS monitoring (if applicable) | `[ ]` | Only if oracle feeds into existing PPS deviation monitors |
| Add market keys to solvency monitoring (if applicable) | `[ ]` | Only if SuperVault strategies reference these positions |

---

## 6. Validation (pre-launch)

| Step | Status | Notes |
|------|--------|-------|
| Fork test: `getPricePerShare` returns sane value for registered markets | `[ ]` | Compare against Morpho UI / manual calculation |
| Fork test: bit-exact parity (oracle view vs `accrueInterest`) | `[x]` | `test_fork_morpho*_bitExactParity` — in substrate PR |
| Staging dry-run: full supply → PPS read → withdraw cycle | `[ ]` | End-to-end with hooks on staging |
| Confirm accounting unit (loanToken denomination) with downstream consumers | `[ ]` | See oracle NatSpec `ACCOUNTING UNIT` block |

---

## 7. Deregistration Safety (ongoing ops)

| Step | Status | Notes |
|------|--------|-------|
| Ops runbook documented | `[x]` | In spec.md and registry NatSpec |
| Monitoring for `MarketDeregistrationProposed` events | `[ ]` | 2-day window to cancel mistakes |
| Pre-deregistration checklist enforced by ops process | `[ ]` | No active positions, oracle unregistered from ledger |
