# Security Analysis Report

## Metadata
- **Target:** `src/accounting/oracles/MorphoBlueYieldSourceOracle.sol`, `src/accounting/oracles/MorphoBlueMarketRegistry.sol`
- **Mode:** review
- **Date:** 2026-06-26
- **Contract Types Detected:** Oracle, Registry (Vault-adjacent — supply-side Morpho Blue)
- **Files Analyzed:** 2 (+ `AbstractYieldSourceOracle.sol` for base class context)
- **Vulnerability Database:** vulnerabilities.md (36 sections, 300+ patterns, 175+ exploits)
- **Branch:** `feat/morpho-blue-tests`

---

## Summary

| Severity   | Count | Blocks Merge |
|------------|-------|--------------|
| P0 Critical | 1    | Yes          |
| P1 High     | 4    | Yes          |
| P2 Medium   | 7    | No           |
| P3 Low      | 7    | No           |

## Verdict

**FAIL** — 5 blocking findings (1 P0 + 4 P1) must be resolved before merge.

---

## P0 Findings (Critical — Must Fix)

### [P0-01] Read-Only Reentrancy via Morpho Blue Callback Window

- **File:** `src/accounting/oracles/MorphoBlueYieldSourceOracle.sol:173`
- **SWC:** SWC-107
- **Category:** Reentrancy
- **Description:**
  `_getAccruedMarketState` calls `IIrm(mp.irm).borrowRateView(mp, mkt)` — an external call to an arbitrary IRM contract. Any consumer of this oracle (e.g., SuperLedger's `getAssetOutputWithFees`) can be invoked during a Morpho Blue supply/repay callback before Morpho has settled its own state. In that window, the oracle reads `totalSupplyAssets`, `totalSupplyShares`, and `totalBorrowAssets` from Morpho while the market is in a transient mid-operation state, producing an inconsistent PPS. This is the **read-only reentrancy** pattern — the oracle itself does not modify state, but upstream callers that take decisions based on the returned value (e.g., minting SuperLedger shares, calculating fees) can be manipulated.
- **Exploit Scenario:**
  An attacker flash-loans a large amount, calls `Morpho.supply()`. Inside Morpho's ERC-20 `transferFrom` callback (fee-on-transfer token or custom ERC-777), the attacker calls a SuperLedger function that queries `MorphoBlueYieldSourceOracle.getPricePerShare()`. At this point Morpho's `totalSupplyAssets` has been incremented but `totalSupplyShares` has not yet been updated, causing the PPS to appear inflated. The attacker gets credited with inflated share value and immediately redeems.
- **Real-World Precedent:**
  - dForce re-entrancy via ERC-777 (2020, $3.7M) — read-only reentrancy path into price oracle during token callback
  - Sturdy Finance (2023, $800K) — read-only reentrancy from Balancer flash loan into Curve LP oracle
- **Vulnerable Code:**
  ```solidity
  // MorphoBlueYieldSourceOracle.sol:213
  uint256 borrowRate = IIrm(mp.irm).borrowRateView(mp, mkt); // external call
  // ...called from getPricePerShare(), getTVL(), getAssetOutput() etc.
  ```
- **Secure Pattern:**
  The fix depends on the IRM trust model. Options in priority order:
  1. **Whitelist IRM addresses** in `MorphoBlueMarketRegistry` and verify `mp.irm` is whitelisted before calling `borrowRateView`. Only Morpho's canonical `AdaptiveCurveIrm` should be permitted.
  2. **Add `nonReentrant` to `_getAccruedMarketState`** and propagate to all callers (`getPricePerShare`, `getTVL`, `getAssetOutput`, `getTVLByOwnerOfShares`, `getShareOutput`, `getWithdrawalShareOutput`). Since this oracle is `view`-only, this requires making callers `nonReentrant` at the SuperLedger boundary instead.
  3. **Use `Morpho.accrueInterest(mp)` + read stored state** instead of replicating accrual in a view — this avoids the external IRM call entirely (though it requires a state-modifying call before reading).
  ```solidity
  // In MorphoBlueMarketRegistry.registerMarket():
  bytes32 IRM_WHITELIST_SLOT = keccak256("morpho.irm.whitelist");
  require(approvedIrms[irm_], "IRM_NOT_WHITELISTED");
  ```
- **Reference:** vulnerabilities.md Section 1.4 (Read-Only Reentrancy), Section 4 (Oracle Manipulation)

---

## P1 Findings (High — Must Fix)

### [P1-01] Malicious or Unbounded IRM `borrowRateView` Corrupts PPS

- **File:** `src/accounting/oracles/MorphoBlueYieldSourceOracle.sol:213`
- **SWC:** SWC-107
- **Category:** Oracle
- **Description:**
  `IIrm(mp.irm).borrowRateView(mp, mkt)` calls an arbitrary externally-supplied address with no validation. A malicious IRM can return `type(uint256).max` to make `wTaylorCompounded` overflow (reverting the entire oracle), or return `0` to suppress all PPS accrual and make the oracle report a stale/wrong value. Since `mp.irm` is stored at market registration time and is never re-validated post-registration, a market registered with a trusted IRM that is later upgraded/replaced via a proxy is also vulnerable.
- **Exploit Scenario:**
  Attacker registers a market with a custom `irm` contract that implements `IIrm.borrowRateView` but returns an attacker-controlled value. Any time the oracle is queried for that market, the attacker can make PPS appear arbitrarily high or cause a revert-DoS.
- **Vulnerable Code:**
  ```solidity
  uint256 borrowRate = IIrm(mp.irm).borrowRateView(mp, mkt);
  interest = s.totalBorrowAssets.wMulDown(borrowRate.wTaylorCompounded(elapsed));
  ```
- **Secure Pattern:**
  ```solidity
  // In MorphoBlueMarketRegistry: maintain an IRM whitelist
  mapping(address => bool) public approvedIrms;

  function registerMarket(...) external {
      require(irm_ == address(0) || approvedIrms[irm_], "IRM_NOT_APPROVED");
      // ...
  }
  ```
- **Reference:** vulnerabilities.md Section 4.1 (Oracle Manipulation), Section 2.1 (Access Control)

---

### [P1-02] `wTaylorCompounded` Overflow / Revert for Large `elapsed × rate`

- **File:** `src/accounting/oracles/MorphoBlueYieldSourceOracle.sol:214`
- **SWC:** SWC-101
- **Category:** Arithmetic
- **Description:**
  `MathLib.wTaylorCompounded(borrowRate, elapsed)` uses a 3-term Taylor expansion: `x + x²/2 + x³/6` where `x = borrowRate × elapsed / WAD`. For sufficiently large values (e.g., `elapsed = 365 days`, `borrowRate = 1e18` — 100%/second), intermediate terms overflow `uint256`, causing an uncaught revert. This silently bricks the oracle for any market that hasn't been updated recently, which is likely in low-activity markets (e.g., after a chain halt or a long period of no activity).
- **Exploit Scenario:**
  On a chain that experienced downtime for several hours (e.g., Arbitrum sequencer outage), all Morpho markets have large `elapsed`. The oracle's `_getAccruedMarketState` reverts, causing all oracle-dependent SuperLedger operations to revert for affected markets.
- **Vulnerable Code:**
  ```solidity
  interest = s.totalBorrowAssets.wMulDown(borrowRate.wTaylorCompounded(elapsed));
  ```
- **Secure Pattern:**
  ```solidity
  // Cap elapsed to a safe maximum (e.g., 365 days) matching Morpho's own protection
  uint256 safeElapsed = elapsed > 365 days ? 365 days : elapsed;
  interest = s.totalBorrowAssets.wMulDown(borrowRate.wTaylorCompounded(safeElapsed));
  ```
  Note: Morpho's own `_accrueInterest` in production code caps `elapsed` to avoid this exact overflow. Verify the version of `MathLib` in use matches the deployed Morpho contract.
- **Reference:** vulnerabilities.md Section 3 (Arithmetic/Overflow)

---

### [P1-03] Fee Calculation Underflow: `totalSupplyAssets - feeAmount`

- **File:** `src/accounting/oracles/MorphoBlueYieldSourceOracle.sol:223`
- **SWC:** SWC-101
- **Category:** Arithmetic
- **Description:**
  Inside the fee accrual block:
  ```solidity
  uint256 feeAmount = interest.wMulDown(fee);
  uint256 feeShares = feeAmount.toSharesDown(s.totalSupplyAssets - feeAmount, s.totalSupplyShares);
  ```
  If `feeAmount > s.totalSupplyAssets` (e.g., due to a malicious IRM returning an extreme `borrowRate` or a fee set at 100%), the subtraction underflows and reverts. In non-malicious but extreme conditions (e.g., `fee = WAD` meaning 100%), `feeAmount` can equal `totalSupplyAssets` and the denominator passed to `toSharesDown` is `0`, which may revert or produce an incorrect result depending on the math library.
- **Exploit Scenario:**
  A market registered with `fee = WAD - 1` (near-100% fee) combined with a high borrow rate causes `feeAmount ≈ interest ≈ totalSupplyAssets`. The subtraction underflows silently or the zero denominator causes a division revert, bricking the oracle for this market.
- **Vulnerable Code:**
  ```solidity
  uint256 feeShares = feeAmount.toSharesDown(s.totalSupplyAssets - feeAmount, s.totalSupplyShares);
  ```
- **Secure Pattern:**
  ```solidity
  // Replicate Morpho's exact safe computation
  if (feeAmount > 0 && s.totalSupplyAssets >= feeAmount) {
      uint256 feeShares = feeAmount.toSharesDown(s.totalSupplyAssets - feeAmount, s.totalSupplyShares);
      s.totalSupplyShares += feeShares;
  }
  ```
- **Reference:** vulnerabilities.md Section 3.2 (Integer Underflow)

---

### [P1-04] No Timelock on `deregisterMarket` — Instant DoS or Registry Poisoning

- **File:** `src/accounting/oracles/MorphoBlueMarketRegistry.sol` (`deregisterMarket`)
- **SWC:** SWC-115
- **Category:** Access Control
- **Description:**
  `deregisterMarket(marketKey)` is callable by any `MARKET_MANAGER_ROLE` holder with immediate effect. There is no timelock, no pending-removal queue, and no grace period. A compromised or rogue `MARKET_MANAGER_ROLE` key can instantly remove all registered markets, causing every oracle query to revert with `MARKET_NOT_REGISTERED`. Since `MARKET_MANAGER_ROLE` is granted to the same address as `DEFAULT_ADMIN_ROLE` (the constructor grants both to `admin_`), a single compromised key can simultaneously (a) deregister markets, (b) grant the role to a new address, and (c) revoke other admins — all in one transaction with no recourse.
- **Exploit Scenario:**
  An attacker compromises the `MARKET_MANAGER_ROLE` EOA (which is the same as `DEFAULT_ADMIN_ROLE`). They call `deregisterMarket` for all registered markets in a single transaction. All active user positions that rely on the oracle for PPS/TVL calculations become inaccessible. If the oracle is used as a guard for withdrawals, users may be unable to exit.
- **Vulnerable Code:**
  ```solidity
  function deregisterMarket(address marketKey) external onlyRole(MARKET_MANAGER_ROLE) {
      if (!_markets[marketKey].registered) revert MARKET_NOT_REGISTERED();
      delete _markets[marketKey];
      emit MarketDeregistered(marketKey);
  }
  ```
- **Secure Pattern:**
  ```solidity
  // Add a 2-day timelock for deregistration
  mapping(address => uint256) public pendingDeregistrations;
  uint256 public constant DEREGISTER_DELAY = 2 days;

  function proposeDeregisterMarket(address marketKey) external onlyRole(MARKET_MANAGER_ROLE) {
      require(_markets[marketKey].registered, "MARKET_NOT_REGISTERED");
      pendingDeregistrations[marketKey] = block.timestamp + DEREGISTER_DELAY;
      emit MarketDeregistrationProposed(marketKey, pendingDeregistrations[marketKey]);
  }

  function executeDeregisterMarket(address marketKey) external onlyRole(MARKET_MANAGER_ROLE) {
      require(pendingDeregistrations[marketKey] != 0 &&
              block.timestamp >= pendingDeregistrations[marketKey], "TIMELOCK_NOT_ELAPSED");
      delete pendingDeregistrations[marketKey];
      delete _markets[marketKey];
      emit MarketDeregistered(marketKey);
  }
  ```
- **Reference:** vulnerabilities.md Section 2.4 (Timelock Requirements), Section 34 (Governance)

---

## P2 Findings (Medium — Should Fix)

### [P2-01] Registry Accepts Arbitrary `morpho_` Address Without Validation

- **File:** `src/accounting/oracles/MorphoBlueMarketRegistry.sol` (`registerMarket`)
- **Category:** Access Control / Logic
- **Description:**
  `registerMarket` validates market params against `IMorpho(morpho_).idToMarketParams(id)` but does not verify that `morpho_` is itself a legitimate Morpho Blue deployment. Any contract implementing `idToMarketParams` that returns the expected params can be registered. A malicious `morpho_` could return correct params during registration but behave maliciously during oracle queries (e.g., `market()` returns inflated state, `position()` returns arbitrary share balances).
- **Secure Pattern:**
  Maintain a `morphoWhitelist` mapping and require `morpho_` to be in it:
  ```solidity
  mapping(address => bool) public approvedMorphoDeployments;
  // Add Morpho's canonical deployments per chain at construction/governance
  ```
- **Reference:** vulnerabilities.md Section 2.1, Section 10 (External Contract Trust)

---

### [P2-02] Market Key Truncation Collision (Keccak256 → address)

- **File:** `src/accounting/oracles/MorphoBlueMarketRegistry.sol` (`computeMarketKey`)
- **Category:** Logic
- **Description:**
  `marketKey = address(uint160(uint256(Id.unwrap(id))))` takes only the lower 160 bits of a 256-bit keccak256 hash. While birthday-collision probability is negligible for honest markets, a malicious actor can mine a `MarketParams` whose lower 160 bits collide with a legitimately registered market's key, then attempt `registerMarket` with the colliding params. The registry's `isRegistered` check would pass (collision matches), potentially overwriting a legitimate registration or causing unexpected routing to the wrong market's data.
- **Secure Pattern:**
  Store the full 32-byte `Id` alongside `MarketInfo` and map `bytes32 → MarketInfo` instead of truncating to an address:
  ```solidity
  mapping(bytes32 => MarketInfo) private _markets; // key = full Id (32 bytes)
  ```
  Since the market key is only used as a pseudo-address parameter in the oracle interface, document clearly that callers must use `computeMarketKey` and never construct keys manually.
- **Reference:** vulnerabilities.md Section 9.1 (Hash Collision)

---

### [P2-03] `registerMarket` Does Not Validate Individual Param Addresses

- **File:** `src/accounting/oracles/MorphoBlueMarketRegistry.sol` (`registerMarket`)
- **Category:** Logic
- **Description:**
  `registerMarket` checks that `IMorpho(morpho_).idToMarketParams(id)` matches the provided params, but does not validate that `loanToken_`, `collateralToken_`, `oracle_`, or `irm_` are non-zero (except for the Morpho validation). A market can be registered with `loanToken_ = address(0)`, causing `IERC20Metadata(mp.loanToken).decimals()` to revert in the oracle's `decimals()` and `getPricePerShare()` methods.
- **Secure Pattern:**
  ```solidity
  require(loanToken_ != address(0), "INVALID_LOAN_TOKEN");
  // oracle_ and irm_ may legitimately be address(0) for zero-IRM markets
  ```
- **Reference:** vulnerabilities.md Section 15.2 (Missing Input Validation)

---

### [P2-04] Unbounded Batch Arrays in `AbstractYieldSourceOracle`

- **File:** `src/accounting/oracles/AbstractYieldSourceOracle.sol` (inherited batch methods)
- **Category:** DoS / Gas
- **Description:**
  `getPricePerShareMultiple`, `getTVLMultiple`, `getTVLByOwnerOfSharesMultiple` iterate over caller-supplied arrays with no length cap. A call with a very large array will exceed the block gas limit, causing a revert. If the oracle is called by a keeper or automation contract that constructs the array dynamically, this can cause a liveness failure.
- **Secure Pattern:**
  ```solidity
  uint256 constant MAX_BATCH = 50;
  require(yieldSources.length <= MAX_BATCH, "BATCH_TOO_LARGE");
  ```
- **Reference:** vulnerabilities.md Section 7.1 (DoS via Gas Limit)

---

### [P2-05] Missing Zero-Address Validation in Constructors

- **File:** `src/accounting/oracles/MorphoBlueYieldSourceOracle.sol:55`, `MorphoBlueMarketRegistry.sol` constructor
- **Category:** Logic
- **Description:**
  `MorphoBlueYieldSourceOracle` constructor does not validate `registry_ != address(0)`. `MorphoBlueMarketRegistry` constructor does not validate `admin_ != address(0)`. Deploying with zero address for either locks the contract permanently (registry becomes unusable; no admin can manage the registry).
- **Secure Pattern:**
  ```solidity
  constructor(address superLedgerConfiguration_, address registry_) {
      require(registry_ != address(0), "ZERO_REGISTRY");
      // ...
  }
  ```
- **Reference:** vulnerabilities.md Section 15.2

---

### [P2-06] Flash-Loan PPS Inflation (Supply-Then-Query Pattern)

- **File:** `src/accounting/oracles/MorphoBlueYieldSourceOracle.sol:120`
- **Category:** Flash Loan / Oracle
- **Description:**
  `getPricePerShare` reads live Morpho market state. An attacker can, within a single transaction: (1) flash-borrow a large amount, (2) supply to the Morpho market to inflate `totalSupplyAssets` without proportionally increasing `totalSupplyShares` (because virtual shares dilution is bounded by VIRTUAL_SHARES = 1e6), (3) call an upstream SuperLedger function that uses the oracle's PPS to calculate the value of their existing position, (4) repay the flash loan. On large production markets the VIRTUAL_SHARES protection is negligible.
- **Secure Pattern:**
  This is primarily mitigated at the SuperLedger consumer level (e.g., snapshotting PPS at deposit time rather than using live PPS for fee calculations), but the oracle should document this risk clearly in its NatSpec. A secondary mitigation is to use time-weighted state (e.g., read from a recent block via TWAP) or require the oracle to be called with a minimum elapsed block threshold.
- **Reference:** vulnerabilities.md Section 5.1 (Flash Loan Price Manipulation), Section 28 (ERC-4626 Donation Attack)

---

### [P2-07] `DEFAULT_ADMIN_ROLE` and `MARKET_MANAGER_ROLE` Granted to Same Address

- **File:** `src/accounting/oracles/MorphoBlueMarketRegistry.sol` (constructor)
- **Category:** Access Control
- **Description:**
  The constructor calls `_grantRole(DEFAULT_ADMIN_ROLE, admin_)` and `_grantRole(MARKET_MANAGER_ROLE, admin_)`. This means `admin_` has both the ability to manage markets AND grant/revoke any role — a single compromised key is a total protocol compromise. Separation of duties requires these roles to be held by different addresses (ideally a multisig for DEFAULT_ADMIN and a hot-key for MARKET_MANAGER with limited blast radius).
- **Secure Pattern:**
  ```solidity
  // Only grant MARKET_MANAGER_ROLE to admin in constructor
  // Require a separate call to grantRole(DEFAULT_ADMIN_ROLE) for a different multisig
  _grantRole(DEFAULT_ADMIN_ROLE, admin_);
  // MARKET_MANAGER_ROLE: grant separately via governance
  ```
- **Reference:** vulnerabilities.md Section 2.3 (Role Separation)

---

## P3 Findings (Low — Consider Fixing)

### [P3-01] `totalBorrowShares: 0` in Market Struct Passed to IRM

- **File:** `src/accounting/oracles/MorphoBlueYieldSourceOracle.sol:209`
- **Category:** Logic
- **Description:**
  `Market.totalBorrowShares` is set to `0` in the struct passed to `IIrm.borrowRateView`. While the canonical Morpho `AdaptiveCurveIrm` does not use `totalBorrowShares` in its rate calculation, a custom IRM may depend on it. Using `0` causes the IRM to see an inconsistent market state and potentially return a wrong borrow rate.
- **Secure Pattern:**
  Read and pass the actual `totalBorrowShares` from `IMorphoStaticTyping(morpho).market(id)`.
  ```solidity
  uint128 totalBorrowShares,
  // ... assign in scope
  mkt = Market({
      totalBorrowShares: totalBorrowShares, // use actual value
      // ...
  });
  ```

---

### [P3-02] Double Registry Lookup in `getPricePerShare`

- **File:** `src/accounting/oracles/MorphoBlueYieldSourceOracle.sol:120-124`
- **Category:** Gas / Efficiency
- **Description:**
  `getPricePerShare` calls `REGISTRY.getMarketInfo(yieldSourceAddress)` twice: once on line 121 to get `mp.loanToken` for decimals, and again inside `_getAccruedMarketState` on line 174. This is a redundant external call that wastes gas and increases the attack surface (two SLOAD-equivalent reads from the registry).
- **Secure Pattern:**
  ```solidity
  function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
      AccruedState memory s = _getAccruedMarketState(yieldSourceAddress);
      // _getAccruedMarketState already loaded mp; pass it through or cache decimals
      (MarketParams memory mp,) = REGISTRY.getMarketInfo(yieldSourceAddress);
      uint8 dec = IERC20Metadata(mp.loanToken).decimals();
      return (10 ** dec).toAssetsDown(s.totalSupplyAssets, s.totalSupplyShares);
  }
  ```
  Better: refactor `_getAccruedMarketState` to return `MarketParams` alongside `AccruedState`.

---

### [P3-03] Single-Step Admin Role Transfer (No `pendingAdmin` Pattern)

- **File:** `src/accounting/oracles/MorphoBlueMarketRegistry.sol`
- **Category:** Access Control
- **Description:**
  `DEFAULT_ADMIN_ROLE` can be transferred to a new address in a single `grantRole` + `revokeRole` call with no two-step pending/accept pattern. A typo in the new admin address permanently locks admin access.
- **Secure Pattern:**
  Use OpenZeppelin `AccessControlDefaultAdminRules` which enforces a delay on admin transfers.

---

### [P3-04] Missing NatSpec `@param` and `@return` on Key Functions

- **File:** `src/accounting/oracles/MorphoBlueMarketRegistry.sol`
- **Category:** Documentation
- **Description:**
  `registerMarket`, `deregisterMarket`, `getMarketInfo`, `computeMarketKey`, `isRegistered` lack `@param` and `@return` NatSpec tags. Auditors and integrators cannot understand parameter semantics without reading the code.

---

### [P3-05] `AccruedState.totalBorrowAssets` Unused by Callers

- **File:** `src/accounting/oracles/MorphoBlueYieldSourceOracle.sol:36-40`
- **Category:** Gas / Cleanliness
- **Description:**
  `AccruedState` includes `totalBorrowAssets` which is computed and stored in the struct but never read by any public function (`getShareOutput`, `getAssetOutput`, `getPricePerShare`, `getTVL` all only use `totalSupplyAssets`/`totalSupplyShares`). It is only needed internally during the accrual computation. Consider removing it from the returned struct or making it a local variable.

---

### [P3-06] Import Grouping Inconsistency

- **File:** `src/accounting/oracles/MorphoBlueYieldSourceOracle.sol:1-16`
- **Category:** Code Style
- **Description:**
  Imports mix vendor (morpho) and internal (superform) without clear separator comments. Morpho vendor imports (`IMorphoStaticTyping`, `MarketParamsLib`, etc.) appear in a single group with no blank line separating them from the OpenZeppelin imports. Follow the project convention: external, vendor, internal, with blank lines between groups.

---

### [P3-07] `MarketInfo` Struct Suboptimal Packing

- **File:** `src/accounting/oracles/MorphoBlueMarketRegistry.sol` (`MarketInfo`)
- **Category:** Gas
- **Description:**
  `MarketInfo` contains `address morpho` (20 bytes), a `MarketParams` struct (5 × 20 bytes = 100 bytes), and `bool registered` (1 byte). `bool registered` at the end after a non-aligned struct causes an extra storage slot. Placing `bool registered` and `address morpho` in the same slot saves one slot per registered market.

---

## Attack Surface Summary

### External Entry Points
- `MorphoBlueYieldSourceOracle`: `decimals`, `getShareOutput`, `getWithdrawalShareOutput`, `getAssetOutput`, `getPricePerShare`, `getBalanceOfOwner`, `getTVLByOwnerOfShares`, `getTVL` (all public/external view)
- `MorphoBlueMarketRegistry`: `registerMarket`, `deregisterMarket`, `getMarketInfo`, `isRegistered`, `computeMarketKey`
- Inherited from `AbstractYieldSourceOracle`: `getPricePerShareMultiple`, `getTVLMultiple`, `getTVLByOwnerOfSharesMultiple`, `getAssetOutputWithFees`

### Value Transfer Points
- Oracle values feed into SuperLedger fee calculations — incorrect PPS directly translates to incorrect fee deductions or incorrect share minting

### Oracle Dependencies
- `IIrm.borrowRateView(mp, mkt)` — fully external, arbitrary contract, called on every `_getAccruedMarketState`
- `IMorphoStaticTyping(morpho).market(id)` — trusted Morpho Blue deployment (but not validated by registry)
- `IMorphoStaticTyping(morpho).position(id, ownerOfShares)` — same trust assumption

### Cross-Contract Interactions
- Calls into Morpho Blue core (`market`, `position`)
- Calls into IRM contracts (`borrowRateView`)
- Called by SuperLedger (`getAssetOutputWithFees`, `getPricePerShare`, etc.)

### Upgrade Mechanisms
- `MorphoBlueMarketRegistry`: upgradeable roles via `AccessControl`; no proxy pattern
- `MorphoBlueYieldSourceOracle`: `immutable REGISTRY` — registry address cannot change post-deployment

---

## Coding Standards Findings

| File | Line | Rule | Severity | Issue |
|------|------|------|----------|-------|
| `MorphoBlueYieldSourceOracle.sol` | 55-61 | Missing zero-address check | P2 | `registry_` not validated |
| `MorphoBlueMarketRegistry.sol` | constructor | Missing zero-address check | P2 | `admin_` not validated |
| `MorphoBlueYieldSourceOracle.sol` | 120-124 | Redundant external call | P3 | Double `getMarketInfo` in `getPricePerShare` |
| `MorphoBlueYieldSourceOracle.sol` | 1-16 | Import grouping | P3 | Missing blank line separator between external/vendor/internal groups |
| `MorphoBlueMarketRegistry.sol` | MarketInfo | Struct packing | P3 | `bool registered` should be packed with `address morpho` |
| `MorphoBlueMarketRegistry.sol` | registerMarket etc. | Missing NatSpec @param/@return | P3 | All public registry functions missing parameter docs |
| `MorphoBlueYieldSourceOracle.sol` | 36-40 | Dead struct field | P3 | `AccruedState.totalBorrowAssets` unused by callers |
| `MorphoBlueMarketRegistry.sol` | n/a | Role separation | P2 | `MARKET_MANAGER_ROLE` and `DEFAULT_ADMIN_ROLE` same address |

---

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1.4 (Read-Only Reentrancy), 2.1/2.3/2.4 (Access Control), 3.2 (Arithmetic), 4.1 (Oracle Manipulation), 5.1 (Flash Loan), 7.1 (DoS), 9.1 (Hash Collision), 10 (Token Integration), 15.2 (Input Validation), 22/28 (Vault/Share Accounting), 34 (Governance)
- **evmresearch.io patterns checked:** reentrancy/read-only-reentrancy, oracle-manipulation/spot-vs-twap, flash-loan-attacks/price-manipulation, access-control/role-separation, vault/share-inflation
- **Coding rules validated:** zero-address checks, import grouping, struct packing, NatSpec completeness, role separation
- **Historical exploits cross-referenced:** dForce (2020, $3.7M), Sturdy Finance (2023, $800K), ERC-4626 first-depositor, Euler Finance (2023, $197M — fee calculation underflow pattern)
