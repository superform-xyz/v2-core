# ERC20YieldSourceOracle — Repository Reference (v2-core)

(Repo-research agent output, 2026-09-15. AaveV4 material lives only on branch
`cosmin-sup-20854-feature-aave-v4-debt-oracle` — not yet merged to dev; citations for those
files are branch-prefixed.)

## 1. The interface contract

### 1.1 `IYieldSourceOracle` — src/interfaces/accounting/IYieldSourceOracle.sol

Pragma 0.8.30, Apache-2.0. Errors: `ARRAY_LENGTH_MISMATCH()` (L17), `INVALID_BASE_ASSET()` (L21 —
declared but unused by identity oracles; they ignore `assetIn`).

Functions (all external view):

| Function | Lines | Semantics |
|---|---|---|
| `decimals(address ys) → uint8` | 59 | share-token decimals |
| `getShareOutput(ys, assetIn, assetsIn) → uint256` | 67–74 | deposit sim: assets → shares |
| `getWithdrawalShareOutput(ys, assetIn, assetsIn) → uint256` | 82–89 | withdraw sim |
| `getAssetOutput(ys, assetIn, sharesIn) → uint256` | 97–104 | redeem sim: shares → assets |
| `getPricePerShare(ys) → uint256` | 110 | PPS in underlying units, scaled by decimals |
| `getTVLByOwnerOfShares(ys, owner) → uint256` | 117 | owner position value |
| `getBalanceOfOwner(ys, owner) → uint256` | 125 | raw share balance |
| `getTVL(ys) → uint256` | 131 | total value locked |
| `getPricePerShareMultiple(address[])` | 137–140 | batch PPS |
| `getTVLByOwnerOfSharesMultiple(address[], address[][]) → (uint256[][], bool[][])` | 157–163 | batch owner TVL **with succeeded mask**; NatSpec L143–156 documents the ROLLOUT NOTE (tuple ABI, mixed fleet until all oracles redeployed) |
| `getTVLMultiple(address[])` | 169 | batch TVL |
| `getAssetOutputWithFees(bytes32 id, ys, assetOut, user, usedShares) → uint256` | 180–189 | output + fee |

### 1.2 Defaults in `AbstractYieldSourceOracle` — src/accounting/oracles/AbstractYieldSourceOracle.sol

- `address public immutable SUPER_LEDGER_CONFIGURATION` (L21); constructor stores with **no
  zero-check** (L29–31) — newer oracles add their own `ZERO_ADDRESS` guard.
- Abstract (8 must-implement): `decimals` (38), `getShareOutput` (41–49),
  `getWithdrawalShareOutput` (52–60), `getAssetOutput` (**public** view virtual, 63–71 — must stay
  public so the fee-bypass override can call it), `getPricePerShare` (public, 74),
  `getTVLByOwnerOfShares` (public, 77–84), `getTVL` (public, 87), `getBalanceOfOwner` (144–151).
- **`getAssetOutputWithFees` default (90–126)**: computes base output, then
  `try …getYieldSourceOracleConfig(id)` (105); if `feePercent > 0 && ledger != 0` (108) calls
  `previewFees` (112–114) and returns `assetOutput + feeAmount` (117, fees ADDED); zero-fee or
  catch → base output. `external view virtual` — overridable.
- `getPricePerShareMultiple` (129–141) and `getTVLMultiple` (193–201): plain loops, **no
  try/catch — one reverting entry aborts the batch** (revert-poisoning).
- `getTVLByOwnerOfSharesMultiple` (154–190): `ARRAY_LENGTH_MISMATCH` on unequal outer lengths
  (163); per-entry isolation via external self-call try/catch (180); catch → `0, false` (184–187).

### 1.3 `ISuperYieldSourceOracle` (router)

Separate aggregator contract (deployed with no constructor args, DeployV2Core.s.sol:4805). A new
per-family oracle does NOT implement it; off-chain/periphery consumers pass the new oracle's
address as `yieldSourceOracle` into the Quote/batch forms. Zero code change needed there.

## 2. Identity-oracle precedents

| Oracle | Where | Identity? | Registry? |
|---|---|---|---|
| EulerDebtOracle | dev | yes | none |
| MorphoBlueDebtOracle | dev | no (real PPS; fee-bypass precedent only) | MorphoBlueMarketRegistry |
| AaveV4DebtOracle / AaveV4SupplyYieldSourceOracle | branch only | yes | AaveV4ReserveRegistry |

### 2.1 Identity converters (EulerDebtOracle.sol:57–69; identical in AaveV4 pair)

```solidity
function getShareOutput(address, address, uint256 assetsIn) external pure override returns (uint256) { return assetsIn; }
function getWithdrawalShareOutput(address, address, uint256 assetsIn) external pure override returns (uint256) { return assetsIn; }
function getAssetOutput(address, address, uint256 sharesIn) public pure override returns (uint256) { return sharesIn; }
```
Unnamed params; pure; `getAssetOutput` stays public (called by fee-bypass). AaveV4 NatSpec: pure
identity converters "do NOT consult the registry … cannot be used to probe registration status."

### 2.2 Decimals + identity PPS

Euler (45–54): `decimals` passthrough; `getPricePerShare` = `10 ** uint256(decimals)` with the
"reverts via checked arithmetic if decimals >= 78" dev-note. ERC20 analog: `IERC20Metadata`
(import precedent MorphoBlueDebtOracle.sol:5).

### 2.3 Balance/TVL views

Euler: `getBalanceOfOwner` → `debtOf(owner)` (82); `getTVLByOwnerOfShares` identical ("since PPS
= 1:1", 86–97); `getTVL` → `totalBorrows()` (100–103). AaveV4Supply delegates:
`getTVLByOwnerOfShares → return getBalanceOfOwner(...)`. ERC20 analog: `balanceOf(owner)` both,
`totalSupply()` for TVL.

### 2.4 Fee-bypass override (MorphoBlueDebtOracle.sol:208–228; verbatim in AaveV4 pair)

```solidity
/// @inheritdoc AbstractYieldSourceOracle
/// @dev Overridden to bypass fee computation entirely. … NOTE: only protects the view path —
///      BaseLedger._processOutflow() computes fees directly from config.feePercent and does not
///      route through here. feePercent = 0 in SuperLedgerConfiguration remains required.
function getAssetOutputWithFees(bytes32, address yieldSourceAddress, address assetOut, address, uint256 usedShares)
    external view override returns (uint256)
{ return getAssetOutput(yieldSourceAddress, assetOut, usedShares); }
```
EulerDebtOracle does NOT override (documents only, L17–24); the later oracles override AND
document — follow the later pattern. AaveV4Supply adds: "re-enabling the fee view requires a new
oracle version, not a config change."

### 2.5 Contract-level invariant block (MorphoBlueDebtOracle.sol:26–36 template)

MUST NOT be configured with feePercent > 0 in SuperLedgerConfiguration; applies to BOTH fee paths
(view — overridden here; ledger — `BaseLedger._processOutflow` computes fees directly and is NOT
guarded on-chain); operational invariant: feePercent = 0 or unregistered. ERC20 rationale =
AaveV4Supply variant: no hook snapshots cost basis for plain ERC20 holdings → previewFees would
treat the entire balance as profit.

### 2.6 Constructor convention

Euler: bare passthrough, no checks (L38). AaveV4 pair: `error ZERO_ADDRESS();` + revert on zero
args; `superLedgerConfiguration_` NatSpec carries "(retained for interface parity with a future
fee-capable oracle version; getAssetOutputWithFees intentionally bypasses the inherited fee
path)". ERC20 oracle: single arg, zero-check, parity NatSpec.

### 2.7 Batch-behavior NatSpec block (AaveV4 contract-level `@dev`, copy)

"Batch methods … isolate reverts via try/catch in getTVLByOwnerOfSharesMultiple only;
getPricePerShareMultiple/getTVLMultiple loop without isolation (inherited behavior — one
reverting key aborts those batch calls)."

## 3. Structural template: ERC4626YieldSourceOracle (107 lines)

src/accounting/oracles/ERC4626YieldSourceOracle.sol — one instance serves every 4626 vault; no
registry, no storage beyond inherited immutable, no events/errors. Shape: license+pragma →
labeled imports → @title/@author/@notice → one-line constructor → single `EXTERNAL FUNCTIONS`
banner → 8 `@inheritdoc` overrides. `getTVLByOwnerOfShares` early-returns `if (shares == 0)
return 0;`. Unused assetIn params left bare. ERC20YieldSourceOracle = this shape × Euler/AaveV4
identity math + fee-bypass. Expected ~100–140 lines with docs.

## 4. Deployment wiring checklist (6 touch points)

1. `ORACLE_CONTRACTS` — script/run/tooling/regenerate_bytecode.sh:195–216, append
   `"ERC20YieldSourceOracle"` (after `"MorphoBlueDebtOracle"`).
2. `_deployOracles` — script/DeployV2Core.s.sol:4747+: bump `uint256 len = 20;` (4755) → 21; add
   `oracles[20] = _createSafeOracleDeploymentWithArgs(ERC20_YIELD_SOURCE_ORACLE_KEY,
   "ERC20YieldSourceOracle", env, abi.encode(superLedgerConfig));` (Euler precedent at 4861–4863).
   Missing bytecode → empty slot → skipped (partial-fleet safe).
3. Availability array — DeployV2Core.s.sol:724–747: `string[20]` → `string[21]`, append
   `"ERC20YieldSourceOracle" // [20]`; order must match deploy indices; expectedOracles
   auto-follows (763).
4. Constants — script/utils/Constants.sol:391 area:
   `string internal constant ERC20_YIELD_SOURCE_ORACLE_KEY = "ERC20YieldSourceOracle";`
   Salt derives from the key (DeployV2Base.s.sol:391–395); debt oracles added no `_SALT` legacy
   constant — follow them.
5. Bytecode artifacts: `script/generated-bytecode/ERC20YieldSourceOracle.json` +
   `script/locked-bytecode-dev/…` committed in the same PR (AaveV4 precedent).
6. verify_v2_staging_prod.sh: append `|"ERC20YieldSourceOracle"` to the
   `constructor(address superLedgerConfig)` args case (near L537–539) AND add the source-path
   case (`get_contract_source`, ~L734–752). Known gap not to replicate: EulerDebtOracle is
   missing from both cases (falls to the wrong `constructor()` fallback); MorphoBlueDebtOracle
   was wired correctly.

Consumer side: zero code. `SuperVaultStrategy.manageYieldSource(token, oracle, Add)`
(v2-periphery SuperVaultStrategy.sol:462–464, `_addYieldSource` 871–878) stores the pair after
non-zero checks; pricing flows off-chain.

## 5. Test conventions

Location: test/unit/accounting/oracles/ (EulerDebtOracle.t.sol is the closest template; branch
adds AaveV4Oracles.t.sol, 647 lines). Plain `Test` subclass, relative imports.
- `MockZeroCostBasisLedger` inline at top of EulerDebtOracle.t.sol:16–31 —
  `previewFees = amountAssets * feePercent / 10_000`; reuse verbatim for the bypass proof
  (AaveV4 precedent test: `test_getAssetOutputWithFees_supplyOracle_overrideBypassesFees_zeroCostBasis`, AaveV4Oracles.t.sol:473).
- `MockERC20` — test/mocks/MockERC20.sol: OZ ERC20 with settable decimals + `mint`; also stubs
  `asset()/share()` = self ("the asset is the token itself"). Real mocks beat mockCall here.
- Real `SuperLedgerConfiguration` used where cheap (`new SuperLedgerConfiguration()`).
- Grammar: `test_<fn>_<case>`, `test_fuzz_<fn>_<property>`; banners per function group.
- Standard matrix: 6/18 decimals fixtures, zero, 1 wei, `type(uint256).max`, identity round-trip,
  77-max-safe/78-revert decimals boundary, EOA/zero-address yieldSource reverts, fee matrix
  (noConfig/zeroFee/configuredFee-with-MockZeroCostBasisLedger/real-ledger).
- Fuzz bounds: `bound(amount, 0, type(uint128).max)`; `bound(feePercent, 1, 5000)`.
- Batch: `..._failureIsolation` (EOA entry → succeeded=false, others fine),
  `..._arrayLengthMismatch`, `..._emptyArrays`, and the KNOWN ISSUE poisoning pin
  (`test_batch_ppsAndTvlMultiple_knownIssue_abortOnNonToken`).

## 6. House style

0.8.30 / Apache-2.0 (src), UNLICENSED (tests). Labeled import groups. 64-char section banners
(minimal oracles: just `EXTERNAL FUNCTIONS`, plus ERRORS/CONSTRUCTOR if present). Custom errors
SCREAMING_SNAKE, never strings. `@title` = name, `@author Superform Labs`, one-line `@notice`,
long contract-level `@dev` carrying ALL operational caveats. Every override
`/// @inheritdoc AbstractYieldSourceOracle`. Immutables SCREAMING_SNAKE; ctor params trailing
underscore; unused params bare types; `10 ** uint256(dec)` widening; no events in stateless
oracles.

## Spec-relevant conclusions

1. ERC20YieldSourceOracle = ERC4626 template minus vault calls: `IERC20Metadata.decimals()`
   passthrough; PPS = `10 ** decimals`; pure identity converters; `getBalanceOfOwner` =
   `getTVLByOwnerOfShares` = `balanceOf(owner)`; `getTVL` = `totalSupply()`; Morpho/AaveV4-style
   fee-bypass + invariant doc block; `constructor(address)` with ZERO_ADDRESS check + parity
   NatSpec.
2. `getTVL = totalSupply()` deserves an explicit semantic NatSpec note (global supply, not
   vault-held value; monitoring-only, never a pricing input).
3. Wiring = 6 mechanical edits (locations above); Euler is the exact single-arg deploy precedent.
4. Tests: single unit file mirroring EulerDebtOracle.t.sol with real MockERC20s.
5. Consumer side needs zero code.
