// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { DeployV2Base } from "./DeployV2Base.s.sol";
import { AaveV4ReserveRegistryV2 } from "../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { ISuperLedgerConfiguration } from "../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { AaveV4ReserveRegistry } from "../src/accounting/oracles/AaveV4ReserveRegistry.sol";
import { IAaveV4Spoke } from "../src/vendor/aave-v4/IAaveV4Spoke.sol";
import { console2 } from "forge-std/console2.sol";

/// @title ConfigureAaveV4ReserveRegistry
/// @notice Seeds a deployed AaveV4ReserveRegistryV2 with every listed reserve of an Aave V4 spoke.
/// @dev Runs AFTER DeployV2Core has deployed the registry and BEFORE TransferAaveV4ReserveRegistryRoles
///      hands MARKET_MANAGER_ROLE to governance: registerReserve is role-gated and the broadcaster must
///      still hold the role (DEPLOYER does, from the constructor). Once roles are transferred, new
///      reserves are registered through governance, not this script.
///
///      Reserve ids are enumerated from the spoke itself (0, 1, 2, ... until getReserve reverts or
///      returns an empty underlying), so the script needs no per-reserve table and cannot drift from
///      what Aave has listed. The registry re-validates every id on-chain at registration.
///
///      Idempotent: reserves whose key is already registered are skipped, so re-running after Aave
///      lists a new reserve registers only the new one.
///
///      Usage (staging = 2, prod = 0). THE ONE-SHOT PATH — reserves, parity, markets, verification:
///        forge script script/ConfigureAaveV4ReserveRegistry.s.sol:ConfigureAaveV4ReserveRegistry \
///          --sig 'configureAll(uint256,uint64,address)' 0 8453 <registry> \
///          --rpc-url $BASE_RPC_URL --account v2 --broadcast
///        # read-only full status (reserves + markets + refs + roles + ledger wiring), no broadcast:
///          --sig 'runCheckAll(uint256,uint64,address)' 0 8453 <registry> --rpc-url $BASE_RPC_URL
///
///      Narrower entry points, all still available:
///        --sig 'run(uint256,uint64,address)' 0 8453 <registry>                       # seed reserves only
///        --sig 'runSpoke(uint256,uint64,address,address)' 0 1 <registry> <spoke>      # one explicit spoke
///        --sig 'runCheck(uint64,address,address)' 8453 <registry> <spoke>             # reserves of one spoke
///        --sig 'registerMarket(uint256,uint64,address,address,uint256,uint256)' \
///              0 8453 <registry> <spoke> <supplyId> <borrowId>                        # one explicit market
///
///      DELIBERATELY NOT part of `configureAll`, because neither is idempotent-and-harmless and both are
///      policy decisions rather than configuration: the SuperLedger oracle registration
///      (`AddToSuperLedgerConfiguration.s.sol` — a fee-policy choice, and only needed if the idle
///      MONEY_MARKET pair is ever driven) and the role transfer
///      (`TransferAaveV4ReserveRegistryRoles.s.sol` — irreversible for the deployer, must be LAST).
///      `configureAll` prints both as remaining steps with their exact commands.
contract ConfigureAaveV4ReserveRegistry is DeployV2Base {
    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev aave-address-book AaveV4EthereumSpokes.MAIN_SPOKE
    address internal constant ETHEREUM_MAIN_SPOKE = 0x94e7A5dCbE816e498b89aB752661904E2F56c485;
    /// @dev aave-address-book AaveV4BaseSpokes.MAG7_SPOKE (equities hub: AAPLc..TSLAc + USDC)
    address internal constant BASE_MAG7_SPOKE = 0x17905Db0e4A3514467539956c084180616AE7B8D;

    /// @dev Upper bound on reserve ids probed per spoke; a spoke listing more than this needs the
    ///      bound raised, which is a deliberate code change rather than an unbounded on-chain loop.
    uint256 internal constant MAX_RESERVES_PER_SPOKE = 64;

    /// @dev Sentinel for "this chain's default spoke has no default market set"
    uint256 internal constant NO_LOAN_RESERVE = type(uint256).max;

    /// @dev IDLE SETTLEMENT DESIGNATION (SUP-21263). Base MAG7 curation: the collateral reserve whose market
    ///      is the designated idle settlement key for the SHARED LOAN RESERVE. Reserve 7 (USDC) is the
    ///      borrow leg of all seven equity markets, so idle USDC could settle under any of the seven keys;
    ///      this names `computeMarketKey(spoke, 0, 7)` as the only one ops may use. The choice of 0 is
    ///      arbitrary but must be STABLE — changing it after an idle position exists strands that position's
    ///      accumulator under the old key.
    uint256 internal constant BASE_MAG7_IDLE_SETTLEMENT_COLLATERAL_ID = 0;

    /// @dev Base MAG7 curation rule: the equities market borrows ONE reserve — USDC, id 7 — against every
    ///      other listed reserve as collateral. Expressing it as "the loan reserve id, everything else is
    ///      collateral" rather than a hardcoded pair list means an eighth equity listed by Aave is picked up
    ///      on the next run instead of being silently skipped.
    ///      WHY REGISTERING ALL OF THEM IS SAFE: a market entry is identity metadata. It grants nothing and
    ///      gates nothing on-chain — the V2 LOAN hooks never call this registry (they are NONACCOUNTING and
    ///      only pin header == body) — so registering a pair a strategy does not use yet widens no
    ///      permission. Which markets a vault may touch stays an off-chain (Erebor) whitelist decision.
    uint256 internal constant BASE_MAG7_LOAN_RESERVE_ID = 7;

    uint64 internal constant ETHEREUM_CHAIN_ID = 1;

    struct MarketResult {
        uint256 candidates;
        uint256 registered;
        uint256 skipped;
    }

    struct SeedResult {
        uint256 listed;
        uint256 registered;
        uint256 skipped;
        /// @dev Reserves that were half-registered on entry and had their missing leg restored via
        ///      `repairLeg`. Should always be 0 on a healthy registry; non-zero means someone
        ///      deregistered a single leg.
        uint256 repaired;
    }

    /*//////////////////////////////////////////////////////////////
                            MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Register every reserve of the chain's default spoke(s).
    /// @param env Environment (0 = prod, 2 = staging)
    /// @param chainId Chain ID (selects the default spokes)
    /// @param registryAddr Deployed AaveV4ReserveRegistryV2
    function run(uint256 env, uint64 chainId, address registryAddr) external broadcast(env) {
        address[] memory spokes = _defaultSpokes(chainId);
        require(spokes.length > 0, "NO_DEFAULT_SPOKE: use runSpoke(env,chainId,registry,spoke)");
        _prepare(env, chainId, registryAddr);
        for (uint256 i; i < spokes.length; ++i) {
            _seedSpoke(AaveV4ReserveRegistryV2(registryAddr), spokes[i]);
        }
        console2.log("====== Registry Seeding Complete ======");
    }

    /// @notice Register every reserve of one explicit spoke.
    /// @param env Environment (0 = prod, 2 = staging)
    /// @param chainId Chain ID (logged and checked against the fork)
    /// @param registryAddr Deployed AaveV4ReserveRegistryV2
    /// @param spoke Aave V4 spoke to enumerate; trusted by the operator (see registry NatSpec)
    function runSpoke(uint256 env, uint64 chainId, address registryAddr, address spoke) external broadcast(env) {
        _prepare(env, chainId, registryAddr);
        _seedSpoke(AaveV4ReserveRegistryV2(registryAddr), spoke);
        console2.log("====== Registry Seeding Complete ======");
    }

    /// @notice ONE-SHOT CONFIGURATION: seed every reserve of the chain's default spoke(s), prove the V1
    ///         migration carried, register the chain's default markets, verify the result, and print whatever
    ///         is left to do. Idempotent — safe to re-run after Aave lists a new reserve or after a partial
    ///         failure; it registers only what is missing.
    /// @dev Order is not arbitrary: `registerMarket` requires BOTH of a market's NAV legs to be registered
    ///      first (the collateral reserve's SUPPLY key and the loan reserve's DEBT key), so reserves must be
    ///      seeded before markets. Parity against V1 runs in between, so a migration that silently lost a
    ///      reserve fails BEFORE any market is written on top of it.
    /// @param env Environment (0 = prod, 2 = staging)
    /// @param chainId Chain ID (selects the default spokes and the default market set)
    /// @param registryAddr Deployed AaveV4ReserveRegistryV2
    function configureAll(uint256 env, uint64 chainId, address registryAddr) external broadcast(env) {
        address[] memory spokes = _defaultSpokes(chainId);
        require(spokes.length > 0, "NO_DEFAULT_SPOKE: use runSpoke + registerMarket for this chain");
        _prepare(env, chainId, registryAddr);
        AaveV4ReserveRegistryV2 registry = AaveV4ReserveRegistryV2(registryAddr);

        // ---- 1. reserves (both legs per reserve) ----
        for (uint256 i; i < spokes.length; ++i) {
            _seedSpoke(registry, spokes[i]);
        }

        // ---- 2. migration parity against the V1 registry, when one is recorded for this chain ----
        address legacy = _outputAddress(env, chainId, "AaveV4ReserveRegistry");
        for (uint256 i; i < spokes.length; ++i) {
            if (legacy == address(0) || legacy.code.length == 0) {
                console2.log("");
                console2.log("[parity] SKIPPED: no AaveV4ReserveRegistry (V1) recorded for this chain");
                break;
            }
            if (!_legacyHasAnyReserve(AaveV4ReserveRegistry(legacy), spokes[i])) {
                console2.log("");
                console2.log("[parity] SKIPPED: V1 holds no reserve for spoke", spokes[i]);
                continue;
            }
            uint256 carried = assertMigrationParity(AaveV4ReserveRegistry(legacy), registry, spokes[i]);
            console2.log("");
            console2.log("[parity] V1 reserves carried into V2 (both legs):", carried);
        }

        // ---- 3. markets ----
        for (uint256 i; i < spokes.length; ++i) {
            _seedMarkets(registry, chainId, spokes[i]);
        }

        // ---- 4. verify and report what is left ----
        for (uint256 i; i < spokes.length; ++i) {
            _assertSpokeFullyConfigured(registry, chainId, spokes[i]);
        }
        _printRemainingSteps(env, chainId, registryAddr);
        console2.log("====== Configuration Complete ======");
    }

    /// @notice Register ONE explicit market pair. For chains or pairs outside the default set.
    /// @dev Idempotent: a market already registered is reported and skipped rather than reverting.
    /// @param env Environment (0 = prod, 2 = staging)
    /// @param chainId Chain ID (logged and checked against the fork)
    /// @param registryAddr Deployed AaveV4ReserveRegistryV2
    /// @param spoke Aave V4 spoke holding both reserves
    /// @param supplyReserveId Collateral reserve id
    /// @param borrowReserveId Loan reserve id — ORDER MATTERS, the reversed pair is a different market
    function registerMarket(
        uint256 env,
        uint64 chainId,
        address registryAddr,
        address spoke,
        uint256 supplyReserveId,
        uint256 borrowReserveId
    )
        external
        broadcast(env)
    {
        _prepare(env, chainId, registryAddr);
        _registerOneMarket(AaveV4ReserveRegistryV2(registryAddr), spoke, supplyReserveId, borrowReserveId);
        console2.log("====== Market Registration Complete ======");
    }

    /// @notice FULL read-only status: reserves, markets, leg refcounts, roles and the ledger wiring. No
    ///         broadcast, so it is safe to run against prod at any time — and it is the check to run BEFORE
    ///         publishing market keys to Erebor / snapshotd, since it prints the derived keys.
    /// @param env Environment (0 = prod, 2 = staging) — used to resolve sibling addresses from the output records
    /// @param chainId Chain ID
    /// @param registryAddr Deployed AaveV4ReserveRegistryV2
    /// @param ledgerOracleId The `yieldSourceOracleId` the oracle was registered under in
    ///        SuperLedgerConfiguration. NOT DERIVABLE: it is chosen at `AddToSuperLedgerConfiguration` time
    ///        and bears no required relation to the CREATE2 salt string, so the 3-argument overload reports
    ///        the wiring as UNKNOWN rather than querying a guessed id and printing a confident wrong answer.
    function runCheckAll(uint256 env, uint64 chainId, address registryAddr, bytes32 ledgerOracleId) external {
        _runCheckAll(env, chainId, registryAddr, ledgerOracleId);
    }

    /// @notice As above, without the ledger oracle id: the ledger-wiring section reports UNKNOWN.
    function runCheckAll(uint256 env, uint64 chainId, address registryAddr) external {
        _runCheckAll(env, chainId, registryAddr, bytes32(0));
    }

    function _runCheckAll(uint256 env, uint64 chainId, address registryAddr, bytes32 ledgerOracleId) internal {
        require(env == 0 || env == 2, "INVALID_ENV: only prod (0) or staging (2) supported");
        require(block.chainid == chainId, "CHAIN_MISMATCH: --rpc-url does not match chainId");
        _setBaseConfiguration(env, "");

        console2.log("====== AaveV4 Registry / Oracle Status ======");
        console2.log("Chain ID:", uint256(chainId));
        console2.log("Registry:", registryAddr);
        if (registryAddr.code.length == 0) {
            console2.log("Status: REGISTRY NOT DEPLOYED");
            return;
        }
        AaveV4ReserveRegistryV2 registry = AaveV4ReserveRegistryV2(registryAddr);

        address[] memory spokes = _defaultSpokes(chainId);
        // Counts BOTH idle-identity violations: a collateral leg claimed twice, and a multi-candidate
        // reserve with no registered designation.
        uint256 idleViolations;
        for (uint256 i; i < spokes.length; ++i) {
            _printReserveStatus(chainId, registryAddr, spokes[i]);
            idleViolations += _printMarketStatus(registry, chainId, spokes[i]);
        }
        if (spokes.length == 0) console2.log("(no default spoke for this chain: pass one to runCheck)");

        _printRoleStatus(registry);
        _printLedgerStatus(env, chainId, ledgerOracleId);

        // F1: the audit must not bless an ambiguous registry. Printed first, then failed, so the operator
        // gets the whole picture — including WHICH reserves are over-claimed — out of the same run.
        require(
            idleViolations == 0,
            "IDLE_IDENTITY_AMBIGUOUS: a reserve is claimed twice or settles under an undesignated market"
        );
    }

    /// @notice Print each listed reserve of a spoke and whether it is registered. No broadcast.
    function runCheck(uint64 chainId, address registryAddr, address spoke) external view {
        _printReserveStatus(chainId, registryAddr, spoke);
    }

    /// @dev Body of `runCheck`, callable internally so `runCheckAll` does not need an external self-call
    ///      (forge rejects `address(this)` in script contracts).
    function _printReserveStatus(uint64 chainId, address registryAddr, address spoke) internal view {
        console2.log("====== AaveV4ReserveRegistryV2 Reserve Check ======");
        console2.log("Chain ID:", uint256(chainId));
        console2.log("Registry:", registryAddr);
        console2.log("Spoke:", spoke);
        if (registryAddr.code.length == 0) {
            console2.log("Status: REGISTRY NOT DEPLOYED");
            return;
        }
        AaveV4ReserveRegistryV2 registry = AaveV4ReserveRegistryV2(registryAddr);
        uint256 missing;
        uint256 half;
        for (uint256 id; id < MAX_RESERVES_PER_SPOKE; ++id) {
            (bool listed, address underlying, uint8 decimals) = _probe(spoke, id);
            if (!listed) break;
            // BOTH legs must be checked: registration is per reserve but deregistration is per key, so a
            // supply-only check would report a half-registered reserve as healthy and the seeder would
            // skip past it (registerReserve reverts RESERVE_ALREADY_REGISTERED on the surviving leg).
            bool supplyOk = registry.isRegistered(registry.computeReserveKey(spoke, id));
            bool debtOk = registry.isRegistered(registry.computeDebtKey(spoke, id));
            if (!supplyOk || !debtOk) ++missing;
            if (supplyOk != debtOk) ++half;
            console2.log(
                string.concat(
                    "  id ",
                    vm.toString(id),
                    " ",
                    vm.toString(underlying),
                    " dec=",
                    vm.toString(uint256(decimals)),
                    supplyOk && debtOk
                        ? "  [REGISTERED both legs]"
                        : (supplyOk
                                ? "  [HALF: debt leg MISSING]"
                                : (debtOk ? "  [HALF: supply leg MISSING]" : "  [MISSING]"))
                )
            );
        }
        if (half != 0) {
            console2.log("Status: HALF-REGISTERED RESERVES PRESENT - run seed to repair the missing legs");
        } else {
            console2.log(missing == 0 ? "Status: ALL LISTED RESERVES REGISTERED" : "Status: RESERVES NEED REGISTRATION");
        }
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev The loan reserve of a chain's default market set, or `NO_LOAN_RESERVE` when the chain has none.
    ///      Everything else listed on the spoke is treated as collateral against it — see the curation note
    ///      on `BASE_MAG7_LOAN_RESERVE_ID`. Ethereum's MAIN_SPOKE has no curated set: its pairs are a
    ///      strategy decision, so markets there go through `registerMarket` explicitly.
    function _defaultLoanReserveId(uint64 chainId) internal pure returns (uint256) {
        if (chainId == BASE_CHAIN_ID) return BASE_MAG7_LOAN_RESERVE_ID;
        return NO_LOAN_RESERVE;
    }

    /// @dev Read a sibling contract address out of the committed deployment record. Returns address(0) when
    ///      the file or the key is absent, so callers can degrade instead of reverting.
    function _outputAddress(uint256 env, uint64 chainId, string memory key) internal view returns (address) {
        string memory envFolder = env == 0 ? "prod" : "staging";
        string memory path = string.concat(
            vm.projectRoot(),
            "/script/output/",
            envFolder,
            "/",
            vm.toString(uint256(chainId)),
            "/",
            chainNames[chainId],
            "-latest.json"
        );
        try vm.readFile(path) returns (string memory json) {
            try vm.parseJsonAddress(json, string.concat(".", key)) returns (address found) {
                return found;
            } catch {
                return address(0);
            }
        } catch {
            return address(0);
        }
    }

    /// @dev True when the V1 registry holds at least one reserve of `spoke`, so parity is worth asserting
    function _legacyHasAnyReserve(AaveV4ReserveRegistry legacy, address spoke) internal view returns (bool) {
        for (uint256 id; id < MAX_RESERVES_PER_SPOKE; ++id) {
            if (legacy.isRegistered(legacy.computeReserveKey(spoke, id))) return true;
        }
        return false;
    }

    /// @dev Register every default market of `spoke`: each listed reserve except the loan reserve, paired
    ///      with the loan reserve. Skips pairs already registered, so re-running is a no-op.
    function _seedMarkets(
        AaveV4ReserveRegistryV2 registry,
        uint64 chainId,
        address spoke
    )
        internal
        returns (MarketResult memory r)
    {
        uint256 loanId = _defaultLoanReserveId(chainId);
        console2.log("");
        if (loanId == NO_LOAN_RESERVE) {
            console2.log("[markets] no default market set for this chain: use registerMarket(...)");
            return r;
        }
        (bool loanListed,,) = _probe(spoke, loanId);
        require(loanListed, "LOAN_RESERVE_NOT_LISTED: the curated loan reserve is absent from this spoke");

        console2.log("[markets] spoke:", spoke);
        console2.log("[markets] loan reserve id:", loanId);
        for (uint256 id; id < MAX_RESERVES_PER_SPOKE; ++id) {
            (bool listed,,) = _probe(spoke, id);
            if (!listed) break;
            if (id == loanId) continue;
            ++r.candidates;
            if (_registerOneMarket(registry, spoke, id, loanId)) ++r.registered;
            else ++r.skipped;
        }
        console2.log("  market candidates:", r.candidates);
        console2.log("  registered now:", r.registered);
        console2.log("  already registered:", r.skipped);
    }

    /// @dev Register one pair if missing. Returns true when it wrote, false when it was already there.
    ///      Asserts the returned key against an independent derivation and the stored binding against the
    ///      spoke, so a registry whose derivation or binding drifted cannot pass silently.
    ///      THE ALREADY-REGISTERED BRANCH ASSERTS TOO (F1): skipping it meant a rerun over a registry that
    ///      had acquired an ambiguous second supply claim out-of-band completed cleanly and reported
    ///      success. Re-running is how this script is meant to be used, so it is also where the ambiguity
    ///      has to surface.
    function _registerOneMarket(
        AaveV4ReserveRegistryV2 registry,
        address spoke,
        uint256 supplyId,
        uint256 borrowId
    )
        internal
        returns (bool registered)
    {
        address marketKey = registry.computeMarketKey(spoke, supplyId, borrowId);
        if (registry.isMarketRegistered(marketKey)) {
            console2.log(
                string.concat(
                    "  [=] market ",
                    vm.toString(supplyId),
                    "/",
                    vm.toString(borrowId),
                    " already registered as ",
                    vm.toString(marketKey)
                )
            );
            _assertMarketBound(registry, spoke, supplyId, borrowId, marketKey);
            return false;
        }

        address returnedKey = registry.registerMarket(spoke, supplyId, borrowId);
        require(returnedKey == marketKey, "MARKET_KEY_MISMATCH: registry derivation drifted");
        _assertMarketBound(registry, spoke, supplyId, borrowId, marketKey);
        console2.log(
            string.concat(
                "  [+] market ", vm.toString(supplyId), "/", vm.toString(borrowId), " -> ", vm.toString(marketKey)
            )
        );
        return true;
    }

    /// @dev Post-registration assertion: the stored binding is the live spoke's, and the two NAV legs this
    ///      market depends on are both claimed. Extracted to keep caller frames inside the stack limit.
    function _assertMarketBound(
        AaveV4ReserveRegistryV2 registry,
        address spoke,
        uint256 supplyId,
        uint256 borrowId,
        address marketKey
    )
        internal
        view
    {
        (address mSpoke, uint256 mSupplyId, uint256 mBorrowId, address collateralToken, address loanToken) =
            registry.getMarketInfo(marketKey);
        require(mSpoke == spoke && mSupplyId == supplyId && mBorrowId == borrowId, "MARKET_BINDING_MISMATCH");
        require(collateralToken == IAaveV4Spoke(spoke).getReserve(supplyId).underlying, "COLLATERAL_MISMATCH");
        require(loanToken == IAaveV4Spoke(spoke).getReserve(borrowId).underlying, "LOAN_TOKEN_MISMATCH");
        require(registry.marketRefs(registry.computeReserveKey(spoke, supplyId)) > 0, "COLLATERAL_LEG_UNCLAIMED");
        require(registry.marketRefs(registry.computeDebtKey(spoke, borrowId)) > 0, "LOAN_LEG_UNCLAIMED");
        _assertIdleCanonical(registry, spoke, supplyId);
    }

    /// @dev THE F1 GUARD (PR #1025 review, P2). At most ONE registered market may name a given reserve as
    ///      its SUPPLY leg. The idle MONEY_MARKET pair's SuperLedger key is the MARKET key, which the oracle
    ///      resolves to the market's collateral leg — so a reserve claimed by two markets gives ONE Aave
    ///      supply position TWO accepted ledger identities: lend under market A, redeem under market B, and
    ///      B's accumulator is empty while A's shares and cost basis are stranded. That is a stale
    ///      accumulator, a double count for any consumer summing both keys, and a fee bypass the day
    ///      `feePercent = 0` stops holding.
    ///      WHY `<= 1` AND NOT `== 1`: a reserve with no market at all is legal (it is simply not
    ///      idle-lendable yet); two is the ambiguity. This gate constrains SUPPLY legs only — the loan
    ///      reserve's DEBT key is SHARED BY DESIGN (all seven Base equity markets borrow USDC, so its debt
    ///      refcount is 7 and must stay allowed).
    ///      SUP-21263 CHANGED WHAT THAT LAST SENTENCE IMPLIES. Once the idle hooks accept either leg of the
    ///      header market, the shared loan reserve is itself idle-settleable under all seven keys, so a
    ///      refcount of 7 is no longer harmless for idle accounting even though it remains correct for
    ///      loans. That direction is handled by `_assertIdleSettlementDesignated`, not here: this gate stays
    ///      exactly as strict as it was, and the designation covers the leg it cannot.
    ///      SCOPE, stated plainly: this is a SCRIPT-level guard. It protects this configuration process and
    ///      a `runCheckAll` audit of the result; it cannot stop a manager calling `registerMarket` on the
    ///      registry directly. The registry-level fix (a canonical-idle marker) is the stronger option and
    ///      is deliberately NOT taken here, because it would mean redeploying and re-seeding a registry that
    ///      is already live and configured.
    function _assertIdleCanonical(AaveV4ReserveRegistryV2 registry, address spoke, uint256 supplyId) internal view {
        require(
            registry.marketRefs(registry.computeReserveKey(spoke, supplyId)) <= 1,
            "COLLATERAL_LEG_CLAIMED_TWICE: reserve is the supply leg of two markets, idle identity is ambiguous"
        );
    }

    /// @dev THE IDLE SETTLEMENT KEY for `reserveId` on `spoke`, or `address(0)` when this chain curates none.
    ///      WHY THIS EXISTS (SUP-21263). The idle hooks now accept a `targetReserveId` that is EITHER leg of
    ///      the header market, so a reserve which is the BORROW leg of N registered markets can settle an
    ///      idle position under any of those N keys. `BaseLedger` accumulators are keyed
    ///      `(user, yieldSource)`: lend under market A, redeem under market B, and B's accumulator is empty,
    ///      so `calculateCostBasisView` CAPS `usedShares` instead of reverting — the redeem succeeds and A's
    ///      shares and cost basis are stranded forever. The supply-leg direction is already closed by
    ///      `_assertIdleCanonical` (`marketRefs <= 1`); the borrow-leg direction CANNOT be closed the same
    ///      way, because the shared loan leg's refcount is legitimately 7 on Base MAG7 and must stay so for
    ///      the LOAN hooks. A designation is therefore the only available answer: exactly one market key per
    ///      (spoke, reserveId) is blessed for idle settlement, and the OMS allowlist must never sign an idle
    ///      leaf naming any other.
    /// @param chainId Chain ID (selects the curated designation)
    /// @param spoke The spoke holding the reserve
    /// @param reserveId The reserve an idle op would move
    /// @param registry Registry used to derive the designated market key
    /// @return The designated market key, or address(0) when this chain has no curated designation
    function _idleSettlementMarket(
        uint64 chainId,
        address spoke,
        uint256 reserveId,
        AaveV4ReserveRegistryV2 registry
    )
        internal
        view
        returns (address)
    {
        uint256 loanId = _defaultLoanReserveId(chainId);
        if (loanId == NO_LOAN_RESERVE) return address(0);
        // The shared loan reserve: designate the single curated market. Every other listed reserve is the
        // SUPPLY leg of exactly one market (enforced by `_assertIdleCanonical`), so its own market IS the
        // designation and needs no curation table.
        if (reserveId == loanId) {
            // The constant is Base-specific by name AND by scope: Base is the only chain with a curated
            // loan reserve today, and a second curated chain must add its own designation here rather than
            // silently inherit "collateral id 0".
            if (chainId != BASE_CHAIN_ID) return address(0);
            return registry.computeMarketKey(spoke, BASE_MAG7_IDLE_SETTLEMENT_COLLATERAL_ID, loanId);
        }
        return registry.computeMarketKey(spoke, reserveId, loanId);
    }

    /// @dev Count the registered markets that name `reserveId` on EITHER leg — the number of distinct
    ///      SuperLedger identities an idle position on that reserve could acquire.
    function _idleSettlementCandidates(
        AaveV4ReserveRegistryV2 registry,
        address spoke,
        uint256 reserveId
    )
        internal
        view
        returns (uint256 candidates)
    {
        for (uint256 other; other < MAX_RESERVES_PER_SPOKE; ++other) {
            (bool listed,,) = _probe(spoke, other);
            if (!listed) break;
            if (other == reserveId) continue;
            if (registry.isMarketRegistered(registry.computeMarketKey(spoke, reserveId, other))) ++candidates;
            if (registry.isMarketRegistered(registry.computeMarketKey(spoke, other, reserveId))) ++candidates;
        }
    }

    /// @dev Enforce the designation for every listed reserve that has MORE THAN ONE candidate settlement
    ///      market: the designated key must exist, must be registered, and must actually name the reserve on
    ///      one of its legs. A reserve with 0 or 1 candidates needs no designation — there is nothing to
    ///      choose between. Reverts rather than warns: an ambiguous idle topology with no blessed key is a
    ///      configuration ops cannot safely sign against.
    function _assertIdleSettlementDesignated(
        AaveV4ReserveRegistryV2 registry,
        uint64 chainId,
        address spoke,
        uint256 reserveId
    )
        internal
        view
    {
        if (_idleSettlementCandidates(registry, spoke, reserveId) <= 1) return;

        address designated = _idleSettlementMarket(chainId, spoke, reserveId, registry);
        if (designated == address(0)) {
            // NO DESIGNATION TABLE FOR THIS CHAIN, and `require`ing one here would be a trap: this script
            // registers no markets on an uncurated chain (`_seedMarkets` returns early), so the ambiguity
            // came from a manual `registerMarket` — and reverting would permanently block `configureAll`
            // from doing the RESERVE seeding it is still needed for, with no table an operator could fill.
            // So warn loudly here and let `runCheckAll` be the gate that fails: an audit refusing to bless
            // the configuration is the right place to stop, because it blocks nothing.
            console2.log("");
            console2.log(
                string.concat(
                    "  [!] reserve ",
                    vm.toString(reserveId),
                    " settles under several markets and this chain curates NO idle designation."
                )
            );
            console2.log("      Add one to _idleSettlementMarket before signing ANY idle leaf on it.");
            return;
        }
        require(registry.isMarketRegistered(designated), "IDLE_SETTLEMENT_MARKET_NOT_REGISTERED");
        (, uint256 supplyId, uint256 borrowId,,) = registry.getMarketInfo(designated);
        require(reserveId == supplyId || reserveId == borrowId, "IDLE_SETTLEMENT_MARKET_LACKS_RESERVE");
    }

    function _defaultSpokes(uint64 chainId) internal pure returns (address[] memory spokes) {
        if (chainId == ETHEREUM_CHAIN_ID) {
            spokes = new address[](1);
            spokes[0] = ETHEREUM_MAIN_SPOKE;
        } else if (chainId == BASE_CHAIN_ID) {
            spokes = new address[](1);
            spokes[0] = BASE_MAG7_SPOKE;
        }
    }

    function _prepare(uint256 env, uint64 chainId, address registryAddr) internal {
        require(env == 0 || env == 2, "INVALID_ENV: only prod (0) or staging (2) supported");
        require(block.chainid == chainId, "CHAIN_MISMATCH: --rpc-url does not match chainId");
        _setBaseConfiguration(env, "");
        require(registryAddr.code.length > 0, "REGISTRY_NOT_DEPLOYED");
        AaveV4ReserveRegistryV2 registry = AaveV4ReserveRegistryV2(registryAddr);
        require(
            registry.hasRole(registry.MARKET_MANAGER_ROLE(), DEPLOYER),
            "DEPLOYER lacks MARKET_MANAGER_ROLE: roles already transferred, register via governance"
        );
        console2.log("====== Seed AaveV4ReserveRegistryV2 ======");
        console2.log("Registry:", registryAddr);
        console2.log("Chain ID:", uint256(chainId));
        console2.log("Environment:", env);
        console2.log("Manager (DEPLOYER):", DEPLOYER);
    }

    /// @dev Enumerates and registers every listed reserve of `spoke`, skipping ones already registered.
    function _seedSpoke(AaveV4ReserveRegistryV2 registry, address spoke) internal returns (SeedResult memory r) {
        require(spoke.code.length > 0, "SPOKE_HAS_NO_CODE");
        console2.log("");
        console2.log("Spoke:", spoke);
        for (uint256 id; id < MAX_RESERVES_PER_SPOKE; ++id) {
            (bool listed, address underlying, uint8 decimals) = _probe(spoke, id);
            if (!listed) break;
            ++r.listed;
            address key = registry.computeReserveKey(spoke, id);
            address debtKey = registry.computeDebtKey(spoke, id);
            bool supplyOk = registry.isRegistered(key);
            bool debtOk = registry.isRegistered(debtKey);
            if (supplyOk && debtOk) {
                ++r.skipped;
                console2.log(string.concat("  [=] id ", vm.toString(id), " already registered as ", vm.toString(key)));
                continue;
            }
            if (supplyOk || debtOk) {
                // Half-registered: `registerReserve` would revert on the surviving leg, so restore the
                // missing one. `repairLeg` re-derives the key and re-reads the binding from the Spoke, so
                // it can only ever restore the leg that is actually absent.
                AaveV4ReserveRegistryV2.Side missingSide =
                    supplyOk ? AaveV4ReserveRegistryV2.Side.DEBT : AaveV4ReserveRegistryV2.Side.SUPPLY;
                address restored = registry.repairLeg(spoke, id, missingSide);
                require(restored == (supplyOk ? debtKey : key), "REPAIR_KEY_MISMATCH");
                ++r.repaired;
                console2.log(
                    string.concat(
                        "  [~] id ",
                        vm.toString(id),
                        " was half-registered; restored ",
                        supplyOk ? "DEBT" : "SUPPLY",
                        " leg ",
                        vm.toString(restored)
                    )
                );
                continue;
            }
            // One call registers BOTH legs: the supply key (== `key`, the legacy derivation) and the
            // debt key. Assert both so a registry whose derivation drifted can never pass silently.
            registry.registerReserve(spoke, id);
            _assertBothLegsBound(registry, spoke, id, underlying, decimals);
            ++r.registered;
            console2.log(
                string.concat(
                    "  [+] id ",
                    vm.toString(id),
                    " ",
                    vm.toString(underlying),
                    " dec=",
                    vm.toString(uint256(decimals)),
                    " -> supply ",
                    vm.toString(key),
                    " debt ",
                    vm.toString(debtKey)
                )
            );
        }
        require(r.listed > 0, "SPOKE_LISTS_NO_RESERVES");
        require(r.listed < MAX_RESERVES_PER_SPOKE, "MAX_RESERVES_PER_SPOKE reached: raise the bound");
        console2.log("  listed:", r.listed);
        console2.log("  registered now:", r.registered);
        console2.log("  already registered:", r.skipped);
        console2.log("  half-registered legs repaired:", r.repaired);
    }

    /// @notice MIGRATION PARITY — every reserve the V1 registry holds must exist in V2, both legs
    /// @dev The whole point of the V2 seed is to carry the live V1 set across, which on Base is the MAG7
    ///      tokenized-stocks market (7 equity reserves plus USDC). `_seedSpoke` enumerates reserves from the
    ///      SPOKE rather than from V1, so in principle it could register a different set than V1 holds — if
    ///      a reserve were delisted on the spoke after V1 was seeded, the seeder would skip it and the
    ///      migration would silently lose that key. This asserts the migration is a superset: for every id
    ///      V1 has registered, V2 must have BOTH legs. Reverts loudly rather than leaving a gap.
    ///      V1's `isRegistered` / `computeReserveKey` are ABI-identical to V2's, so only the supply key is
    ///      needed to detect V1 membership (V1 has no debt leg at all).
    /// @param legacyRegistry The deployed V1 registry to compare against
    /// @param registry The V2 registry just seeded
    /// @param spoke The spoke whose reserves were seeded
    /// @return carried Number of V1 reserves confirmed present in V2
    function assertMigrationParity(
        AaveV4ReserveRegistry legacyRegistry,
        AaveV4ReserveRegistryV2 registry,
        address spoke
    )
        public
        view
        returns (uint256 carried)
    {
        for (uint256 id; id < MAX_RESERVES_PER_SPOKE; ++id) {
            address legacyKey = legacyRegistry.computeReserveKey(spoke, id);
            if (!legacyRegistry.isRegistered(legacyKey)) continue;

            // V1's supply key derivation is the unchanged legacy one, so it IS V2's supply key
            require(registry.isRegistered(registry.computeReserveKey(spoke, id)), "MIGRATION_SUPPLY_LEG_MISSING");
            require(registry.isRegistered(registry.computeDebtKey(spoke, id)), "MIGRATION_DEBT_LEG_MISSING");
            ++carried;
        }
        require(carried > 0, "MIGRATION_PARITY_FOUND_NOTHING_IN_V1");
    }

    /// @dev Post-registration assertion, extracted to keep `_seedSpoke`'s frame within stack limits
    ///      (the repo builds without via_ir). Verifies both derived keys exist, carry the correct side,
    ///      and share the binding this script independently probed from the Spoke.
    function _assertBothLegsBound(
        AaveV4ReserveRegistryV2 registry,
        address spoke,
        uint256 id,
        address underlying,
        uint8 decimals
    )
        internal
        view
    {
        address supplyKey = registry.computeReserveKey(spoke, id);
        address debtKey = registry.computeDebtKey(spoke, id);

        (,, address u1, uint8 d1, AaveV4ReserveRegistryV2.Side s1) = registry.getReserveInfo(supplyKey);
        require(u1 == underlying && d1 == decimals, "RESERVE_BINDING_MISMATCH");
        require(s1 == AaveV4ReserveRegistryV2.Side.SUPPLY, "SUPPLY_SIDE_MISMATCH");

        (,, address u2, uint8 d2, AaveV4ReserveRegistryV2.Side s2) = registry.getReserveInfo(debtKey);
        require(u2 == underlying && d2 == decimals, "DEBT_BINDING_MISMATCH");
        require(s2 == AaveV4ReserveRegistryV2.Side.DEBT, "DEBT_SIDE_MISMATCH");
    }

    /// @dev A reserve id is "listed" when getReserve succeeds with a non-zero underlying. Unlisted ids
    ///      revert on the live spokes; the empty-struct case is guarded as well.
    function _probe(address spoke, uint256 id) internal view returns (bool listed, address underlying, uint8 decimals) {
        try IAaveV4Spoke(spoke).getReserve(id) returns (IAaveV4Spoke.Reserve memory reserve) {
            if (reserve.underlying == address(0)) return (false, address(0), 0);
            return (true, reserve.underlying, reserve.decimals);
        } catch {
            return (false, address(0), 0);
        }
    }

    /*//////////////////////////////////////////////////////////////
                      VERIFICATION AND REPORTING
    //////////////////////////////////////////////////////////////*/

    /// @dev Final gate of `configureAll`: every listed reserve has BOTH legs, and every default market
    ///      resolves with both of its NAV legs claimed. Reverts rather than printing a warning — a
    ///      half-configured registry should fail the run, not be discovered later by a NAV read.
    function _assertSpokeFullyConfigured(
        AaveV4ReserveRegistryV2 registry,
        uint64 chainId,
        address spoke
    )
        internal
        view
    {
        uint256 loanId = _defaultLoanReserveId(chainId);
        for (uint256 id; id < MAX_RESERVES_PER_SPOKE; ++id) {
            (bool listed,,) = _probe(spoke, id);
            if (!listed) break;
            require(registry.isRegistered(registry.computeReserveKey(spoke, id)), "VERIFY_SUPPLY_LEG_MISSING");
            require(registry.isRegistered(registry.computeDebtKey(spoke, id)), "VERIFY_DEBT_LEG_MISSING");
            // F1: every listed reserve, not only the ones this run touched — an ambiguous claim written
            // out-of-band fails the gate rather than being inherited silently.
            _assertIdleCanonical(registry, spoke, id);
            // SUP-21263: and where a reserve can settle under several markets (the shared loan leg), one of
            // them must be the curated designation.
            _assertIdleSettlementDesignated(registry, chainId, spoke, id);
            if (loanId == NO_LOAN_RESERVE || id == loanId) continue;
            require(registry.isMarketRegistered(registry.computeMarketKey(spoke, id, loanId)), "VERIFY_MARKET_MISSING");
        }
    }

    /// @dev Print every default market of a spoke: the derived key, whether it is registered, and its
    ///      binding. This is the output to hand to Erebor / snapshotd — the keys printed here are what a
    ///      signed header must carry.
    function _printMarketStatus(
        AaveV4ReserveRegistryV2 registry,
        uint64 chainId,
        address spoke
    )
        internal
        view
        returns (uint256 overClaimed)
    {
        uint256 loanId = _defaultLoanReserveId(chainId);
        console2.log("");
        console2.log("  --- markets ---");
        if (loanId == NO_LOAN_RESERVE) {
            console2.log("  no default market set for this chain");
            // STILL FULLY AUDITED. Markets registered out-of-band on this chain can be ambiguous too, and
            // neither canonicality nor idle settlement depends on there being a curated loan reserve. An
            // earlier version returned before `_printIdleSettlement`, which meant the one chain where the
            // designation is NOT curated was also the one chain whose audit never mentioned it.
            return _printIdleCanonicality(registry, spoke) + _printIdleSettlement(registry, chainId, spoke);
        }
        uint256 missing;
        for (uint256 id; id < MAX_RESERVES_PER_SPOKE; ++id) {
            (bool listed,,) = _probe(spoke, id);
            if (!listed) break;
            if (id == loanId) continue;
            address marketKey = registry.computeMarketKey(spoke, id, loanId);
            bool ok = registry.isMarketRegistered(marketKey);
            if (!ok) ++missing;
            console2.log(
                string.concat(
                    "  ",
                    vm.toString(id),
                    "/",
                    vm.toString(loanId),
                    " -> ",
                    vm.toString(marketKey),
                    ok ? "  [REGISTERED]" : "  [MISSING]"
                )
            );
        }
        console2.log(
            "  loan DEBT leg claimed by N markets:", registry.marketRefs(registry.computeDebtKey(spoke, loanId))
        );
        overClaimed = _printIdleCanonicality(registry, spoke);
        overClaimed += _printIdleSettlement(registry, chainId, spoke);
        console2.log(missing == 0 ? "  Status: ALL DEFAULT MARKETS REGISTERED" : "  Status: MARKETS NEED REGISTRATION");
    }

    /// @dev Who holds the registry roles. The handoff is a blocking production task and must be LAST.
    function _printRoleStatus(AaveV4ReserveRegistryV2 registry) internal view {
        console2.log("");
        console2.log("  --- roles ---");
        bool deployerManages = registry.hasRole(registry.MARKET_MANAGER_ROLE(), DEPLOYER);
        console2.log("  DEPLOYER has MARKET_MANAGER:", deployerManages);
        console2.log("  DEPLOYER has DEFAULT_ADMIN:", registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), DEPLOYER));
        console2.log(
            deployerManages
                ? "  Status: ROLES NOT YET TRANSFERRED (configuration still runnable from the deployer key)"
                : "  Status: ROLES TRANSFERRED (further registration must go through governance)"
        );
    }

    /// @dev Whether the oracle is wired into SuperLedger. Only required if the idle MONEY_MARKET pair is
    ///      ever driven; the LOAN hooks are NONACCOUNTING and never consult it.
    /// @param ledgerOracleId The id the oracle was registered under. `bytes32(0)` means "not supplied":
    ///        the section then reports UNKNOWN. An earlier version queried
    ///        `bytes32(bytes(AAVE_V4_RESERVE_ORACLE_KEY))` — the CREATE2 SALT STRING — which is not the
    ///        ledger id and resolves to an empty config on Base, i.e. it printed "ORACLE NOT REGISTERED"
    ///        whether or not the oracle was in fact wired.
    function _printLedgerStatus(uint256 env, uint64 chainId, bytes32 ledgerOracleId) internal view {
        console2.log("");
        console2.log("  --- ledger wiring (idle pair only) ---");
        address oracle = _outputAddress(env, chainId, "AaveV4ReserveOracle");
        address ledgerConfig = _outputAddress(env, chainId, "SuperLedgerConfiguration");
        console2.log("  AaveV4ReserveOracle:", oracle);
        if (ledgerConfig == address(0) || ledgerConfig.code.length == 0) {
            console2.log("  SuperLedgerConfiguration not recorded for this chain");
            return;
        }
        if (ledgerOracleId == bytes32(0)) {
            console2.log("  Status: UNKNOWN - no yieldSourceOracleId supplied, and it cannot be inferred.");
            console2.log("  Re-run with --sig 'runCheckAll(uint256,uint64,address,bytes32)' and the id used at");
            console2.log("  AddToSuperLedgerConfiguration time. SuperLedgerConfiguration:", ledgerConfig);
            return;
        }
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory cfg =
            ISuperLedgerConfiguration(ledgerConfig).getYieldSourceOracleConfig(ledgerOracleId);
        if (cfg.yieldSourceOracle == address(0)) {
            console2.log("  Status: ORACLE NOT REGISTERED (idle pair would revert MANAGER_NOT_SET)");
            return;
        }
        console2.log("  registered oracle:", cfg.yieldSourceOracle);
        console2.log("  feePercent (MUST be 0):", cfg.feePercent);
        console2.log(
            cfg.yieldSourceOracle == oracle
                ? "  Status: ORACLE REGISTERED"
                : "  Status: REGISTERED ORACLE IS STALE - points at a superseded deployment"
        );
    }

    /// @dev The two steps `configureAll` deliberately does not take, with their exact commands
    function _printRemainingSteps(uint256 env, uint64 chainId, address registryAddr) internal view {
        console2.log("");
        console2.log("--- REMAINING STEPS (not performed by configureAll) ---");
        console2.log("1. SuperLedger registration, ONLY if the idle MONEY_MARKET pair is to be driven.");
        console2.log("   feePercent MUST be 0 (identity-PPS oracle; see SECURITY.md).");
        console2.log("   script/AddToSuperLedgerConfiguration.s.sol, salt string:", AAVE_V4_RESERVE_ORACLE_KEY);
        console2.log("   oracle:", _outputAddress(env, chainId, "AaveV4ReserveOracle"));
        console2.log("2. Role transfer - LAST, irreversible for the deployer:");
        console2.log(
            "   forge script script/TransferAaveV4ReserveRegistryRoles.s.sol:TransferAaveV4ReserveRegistryRoles \\"
        );
        console2.log("     --sig 'run(uint256,uint64,address)'", env);
        console2.log("     chainId / registry:", uint256(chainId), registryAddr);
        console2.log("Then publish the market keys printed above to Erebor / snapshotd / Superman.");
    }

    /// @dev IDLE CANONICALITY (SUP-21254): the idle pair's SuperLedger key is the MARKET key, which the oracle
    ///      resolves to the market's COLLATERAL leg. If two registered markets named the same collateral
    ///      reserve as their supply leg, one idle position on it would have TWO ledger keys — lend under one,
    ///      redeem under the other, and `usedShares` caps to zero (stale accumulator, NAV double count, and a
    ///      fee bypass the day `feePercent = 0` stops holding). The registry cannot enforce this without
    ///      forbidding legitimate multi-borrow-leg LOAN markets, so it is a curation rule — printed here and
    ///      asserted by `_assertMarketBound` at registration time.
    ///      Returns the number of over-claimed reserves so the caller can FAIL rather than merely report:
    ///      `runCheckAll` reverts on a non-zero count after printing the full diagnostic.
    function _printIdleCanonicality(
        AaveV4ReserveRegistryV2 registry,
        address spoke
    )
        internal
        view
        returns (uint256 overClaimed)
    {
        for (uint256 id; id < MAX_RESERVES_PER_SPOKE; ++id) {
            (bool listed,,) = _probe(spoke, id);
            if (!listed) break;
            uint256 refs = registry.marketRefs(registry.computeReserveKey(spoke, id));
            if (refs > 1) {
                ++overClaimed;
                console2.log(
                    string.concat(
                        "  [!] reserve ",
                        vm.toString(id),
                        " is the supply leg of ",
                        vm.toString(refs),
                        " markets - NOT idle-lendable unambiguously"
                    )
                );
            }
        }
        console2.log(
            overClaimed == 0
                ? "  Idle canonicality: OK (every collateral reserve has at most one market)"
                : "  Idle canonicality: VIOLATED - see the reserves flagged above"
        );
    }

    /// @dev IDLE SETTLEMENT REPORT (SUP-21263). For every listed reserve, how many registered markets could
    ///      settle an idle position on it and which key is designated. This is the output ops needs before
    ///      signing an idle leaf: the hooks accept ANY candidate, so the allowlist — not the contracts — is
    ///      what keeps one reserve on one ledger key.
    /// @return undesignated Reserves with several candidates and no curated designation
    function _printIdleSettlement(
        AaveV4ReserveRegistryV2 registry,
        uint64 chainId,
        address spoke
    )
        internal
        view
        returns (uint256 undesignated)
    {
        console2.log("");
        console2.log("  --- idle settlement keys (SUP-21263) ---");
        for (uint256 id; id < MAX_RESERVES_PER_SPOKE; ++id) {
            (bool listed,,) = _probe(spoke, id);
            if (!listed) break;
            uint256 candidates = _idleSettlementCandidates(registry, spoke, id);
            if (candidates == 0) continue;
            address designated = _idleSettlementMarket(chainId, spoke, id, registry);
            bool ok = designated != address(0) && registry.isMarketRegistered(designated);
            if (candidates > 1 && !ok) ++undesignated;
            console2.log(
                string.concat(
                    "  reserve ",
                    vm.toString(id),
                    ": ",
                    vm.toString(candidates),
                    " candidate market(s), designated ",
                    ok ? vm.toString(designated) : "NONE",
                    candidates > 1 ? "  [AMBIGUOUS - sign only the designated key]" : ""
                )
            );
        }
        console2.log(
            undesignated == 0
                ? "  Idle settlement: OK (every multi-candidate reserve has a registered designation)"
                : "  Idle settlement: UNDESIGNATED - an idle leaf could strand an accumulator"
        );
    }
}
