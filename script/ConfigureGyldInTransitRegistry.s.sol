// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { DeployV2Base } from "./DeployV2Base.s.sol";
import { ConstantsOtherHooks } from "./utils/ConstantsOtherHooks.sol";
import { GyldInTransitRegistry } from "../src/accounting/oracles/GyldInTransitRegistry.sol";
import { console2 } from "forge-std/console2.sol";

/// @title ConfigureGyldInTransitRegistry
/// @notice Post-deploy configuration of `GyldInTransitRegistry` (Gyld Investor API hooks, SUP-21848).
/// @dev EVERY VALUE FAILS CLOSED WHEN UNSET. The registry refuses `recordCashOut` / `recordBondsOut`, and so
///      both investor hooks revert in `build()`, until the destinations AND the transit age are set, and a
///      deposit additionally needs non-zero per-strategy AND instrument-wide caps (`runCap`). A deploy without this
///      script is inert.
/// @dev ORDER. AS DEPLOYER (still MANAGER_ROLE): `runDestinations` once PER STRATEGY, `runTransitDefaults`, and
///      `runOracle` (binds the valuation oracle the NAV-tied settles read; without it `settleMint` and
///      `settleRedemption` revert `NAV_UNAVAILABLE` and only the cash-for-cash / bonds-for-bonds settles work).
///      Then `TransferGyldInTransitRegistryRoles` hands the roles over. Then AS GOVERNOR, per registered instrument:
///      `runCap` (zero = deposits disabled) and `runFee` (the expected upfront fee, netted from the valuation and
///      tolerated by the settle tie). A strategy onboarded AFTER the handover gets its pair through the same
///      `runDestinations`, run as GOVERNOR. The destinations come from Gyld onboarding (`GET /deposit/address`,
///      `GET /portfolio.redeem_holding_wallet`) for the Gyld account that strategy trades through; the first set is
///      immediate and every later change waits `DESTINATION_DELAY` behind `proposeDestinations`. A strategy with no
///      pair is refused by both hooks, whatever else is configured.
/// @dev THE RECEIVER IS AN ONBOARDING INPUT. `runDestinations` also deploys the strategy's `GyldDeliveryReceiver`
///      (printed, and shown by `runCheck`). That address, not the strategy, is what Gyld must hold as the
///      whitelisted withdrawal address and use as the `wallet_address` of every mint order: a delivery that lands
///      on the strategy directly cannot be settled by the reconciler and needs the MANAGER's manual path.
contract ConfigureGyldInTransitRegistry is DeployV2Base, ConstantsOtherHooks {
    /// @notice First-time set of ONE strategy's two Gyld destinations
    function runDestinations(
        uint256 env,
        uint64 chainId,
        address registryAddr,
        address strategy,
        address depositAddress,
        address redeemHoldingWallet
    )
        external
        broadcast(env)
    {
        _requireRegistry(chainId, registryAddr);
        require(strategy != address(0), "ZERO_STRATEGY");
        require(depositAddress != address(0) && redeemHoldingWallet != address(0), "ZERO_DESTINATION");
        GyldInTransitRegistry registry = GyldInTransitRegistry(registryAddr);
        console2.log("strategy            ->", strategy);
        console2.log("depositAddress      ->", depositAddress);
        console2.log("redeemHoldingWallet ->", redeemHoldingWallet);
        registry.setDestinations(strategy, depositAddress, redeemHoldingWallet);
        (address dep, address hold) = registry.destinationsOf(strategy);
        require(dep == depositAddress, "DEPOSIT_ADDRESS_NOT_APPLIED");
        require(hold == redeemHoldingWallet, "HOLDING_WALLET_NOT_APPLIED");
        console2.log("deliveryReceiver    ->", address(registry.receiverOf(strategy)));
        console2.log("  (one Gyld account per strategy: a deposit address already used by another strategy is refused)");
        console2.log("  ^ give THIS to Gyld: whitelisted withdrawal address and mint wallet_address");
        console2.log("====== Destinations configured ======");
    }

    /// @notice Sets `maxTransitAge` to the reviewed constant
    function runTransitDefaults(uint256 env, uint64 chainId, address registryAddr) external broadcast(env) {
        _requireRegistry(chainId, registryAddr);
        GyldInTransitRegistry registry = GyldInTransitRegistry(registryAddr);
        uint256 current = registry.maxTransitAge();
        console2.log("maxTransitAge: current", current, "-> target", GYLD_MAX_TRANSIT_AGE);
        if (current == GYLD_MAX_TRANSIT_AGE) {
            console2.log("  already set, skipping");
        } else {
            registry.setMaxTransitAge(GYLD_MAX_TRANSIT_AGE);
            require(registry.maxTransitAge() == GYLD_MAX_TRANSIT_AGE, "MAX_TRANSIT_AGE_NOT_APPLIED");
            console2.log("  applied");
        }
        console2.log("====== Transit defaults configured ======");
    }

    /// @notice The two per-instrument caps on OUTSTANDING cash at Gyld, in raw cash-token units: per strategy and
    ///         across all strategies. Either at zero disables deposits for the instrument.
    function runCap(
        uint256 env,
        uint64 chainId,
        address registryAddr,
        address bondToken,
        uint256 perStrategyCap,
        uint256 totalCap
    )
        external
        broadcast(env)
    {
        _requireRegistry(chainId, registryAddr);
        require(totalCap >= perStrategyCap, "TOTAL_CAP_BELOW_PER_STRATEGY");
        GyldInTransitRegistry registry = GyldInTransitRegistry(registryAddr);
        console2.log("maxCashInTransit (per strategy) for", bondToken, "->", perStrategyCap);
        registry.setMaxCashInTransit(bondToken, perStrategyCap);
        require(registry.maxCashInTransit(bondToken) == perStrategyCap, "CAP_NOT_APPLIED");
        console2.log("maxTotalCashInTransit (all strategies) for", bondToken, "->", totalCap);
        registry.setMaxTotalCashInTransit(bondToken, totalCap);
        require(registry.maxTotalCashInTransit(bondToken) == totalCap, "TOTAL_CAP_NOT_APPLIED");
        console2.log("====== Caps configured ======");
    }

    /// @notice Expected Gyld fee on in-transit legs for an instrument, in bps (netted out of in-transit value).
    function runFee(
        uint256 env,
        uint64 chainId,
        address registryAddr,
        address bondToken,
        uint256 bps
    )
        external
        broadcast(env)
    {
        _requireRegistry(chainId, registryAddr);
        GyldInTransitRegistry registry = GyldInTransitRegistry(registryAddr);
        console2.log("transitFeeBps for", bondToken, "->", bps);
        registry.setTransitFeeBps(bondToken, bps);
        require(registry.transitFeeBps(bondToken) == bps, "FEE_NOT_APPLIED");
        console2.log("====== Fee haircut configured ======");
    }

    /// @notice Bind the valuation oracle whose NAV ties `settleMint` / `settleRedemption` to the delivered value.
    ///         The oracle must pin THIS registry (`IN_TRANSIT`), which the registry checks. The FIRST oracle is set
    ///         immediately; a later change is only PROPOSED here and applied by `runOracleExecute` after
    ///         `DESTINATION_DELAY` (2 days): the oracle is the NAV every settle trusts.
    function runOracle(uint256 env, uint64 chainId, address registryAddr, address oracleAddr) external broadcast(env) {
        _requireRegistry(chainId, registryAddr);
        require(oracleAddr != address(0) && oracleAddr.code.length > 0, "ORACLE_NOT_DEPLOYED");
        GyldInTransitRegistry registry = GyldInTransitRegistry(registryAddr);
        address current = address(registry.valuationOracle());
        console2.log("valuationOracle: current", current, "-> target", oracleAddr);
        if (current == oracleAddr) {
            console2.log("  already set, skipping");
        } else if (current == address(0)) {
            registry.setValuationOracle(oracleAddr);
            require(address(registry.valuationOracle()) == oracleAddr, "ORACLE_NOT_APPLIED");
            console2.log("  applied (first set, immediate)");
        } else {
            registry.proposeValuationOracle(oracleAddr);
            (address pending, uint64 at) = registry.pendingValuationOracle();
            require(pending == oracleAddr, "ORACLE_NOT_PROPOSED");
            console2.log("  PROPOSED; run runOracleExecute at or after", uint256(at));
        }
        console2.log("====== Valuation oracle configured ======");
    }

    /// @notice Apply a proposed oracle change once `DESTINATION_DELAY` has elapsed.
    function runOracleExecute(uint256 env, uint64 chainId, address registryAddr) external broadcast(env) {
        _requireRegistry(chainId, registryAddr);
        GyldInTransitRegistry registry = GyldInTransitRegistry(registryAddr);
        (address pending, uint64 at) = registry.pendingValuationOracle();
        require(pending != address(0), "NO_PENDING_ORACLE");
        require(block.timestamp >= at, "ORACLE_TIMELOCK_NOT_ELAPSED");
        registry.executeValuationOracle();
        require(address(registry.valuationOracle()) == pending, "ORACLE_NOT_APPLIED");
        console2.log("valuationOracle ->", pending);
        console2.log("====== Valuation oracle change executed ======");
    }

    /// @notice Read-only check. Prints UNSET for every value the hooks or the reconciler would fail closed on.
    function runCheck(
        uint64 chainId,
        address registryAddr,
        address[] calldata strategies,
        address[] calldata bondTokens
    )
        external
        view
    {
        _requireRegistry(chainId, registryAddr);
        GyldInTransitRegistry registry = GyldInTransitRegistry(registryAddr);
        console2.log("====== GyldInTransitRegistry check ======");
        uint256 age = registry.maxTransitAge();
        if (age == 0) console2.log("maxTransitAge: UNSET (every record reverts)");
        else console2.log("maxTransitAge:", age);
        address oracle = address(registry.valuationOracle());
        if (oracle == address(0)) console2.log("valuationOracle: UNSET (mint / redemption settles revert)");
        else console2.log("valuationOracle:", oracle);
        (address pendingOracle, uint64 oracleAt) = registry.pendingValuationOracle();
        if (pendingOracle != address(0)) {
            console2.log("  PENDING oracle change ->", pendingOracle, "executable at", uint256(oracleAt));
        }
        console2.log("flag policy for the PPS pusher / aggregator:");
        console2.log("  STALE lot             -> pause the strategy's deposits, keep pushing (value unchanged)");
        console2.log("  PENDING manual settle -> push the NETTED PPS and pause deposits (the write-down is priced in)");
        console2.log("  UNSWEPT delivery      -> settle first, then push (apply a dust floor to the amounts)");
        console2.log("lots recorded so far:", registry.lotCount());
        for (uint256 i; i < strategies.length; ++i) {
            _printStrategy(registry, strategies[i], bondTokens);
        }
        for (uint256 i; i < bondTokens.length; ++i) {
            uint256 cap = registry.maxCashInTransit(bondTokens[i]);
            if (cap == 0) console2.log("maxCashInTransit UNSET (deposits disabled) for", bondTokens[i]);
            else console2.log("maxCashInTransit (per strategy)", cap, "for", bondTokens[i]);
            uint256 totalCap = registry.maxTotalCashInTransit(bondTokens[i]);
            if (totalCap == 0) console2.log("maxTotalCashInTransit UNSET (deposits disabled) for", bondTokens[i]);
            else console2.log("maxTotalCashInTransit (all strategies)", totalCap, "for", bondTokens[i]);
            console2.log("  transitFeeBps", registry.transitFeeBps(bondTokens[i]));
            uint16 tol = registry.BOND_REGISTRY().getInstrumentConfig(bondTokens[i]).maxEntryPremiumBps;
            if (tol == 0) {
                console2.log("  WARNING maxEntryPremiumBps is 0 (unconfigured): the settle band tolerates no premium");
            }
            console2.log("  totalCashInTransit", registry.totalCashInTransit(bondTokens[i]));
            console2.log("  totalCashInTransitNet (valued)", registry.totalCashInTransitNet(bondTokens[i]));
        }
    }

    /// @dev One strategy's block of `runCheck`, split out to keep the stack flat
    function _printStrategy(
        GyldInTransitRegistry registry,
        address strategy,
        address[] calldata bondTokens
    )
        internal
        view
    {
        console2.log("strategy", strategy);
        (address dep, address hold) = registry.destinationsOf(strategy);
        if (dep == address(0)) console2.log("  depositAddress: UNSET (every deposit leaf reverts)");
        else console2.log("  depositAddress:", dep);
        if (hold == address(0)) console2.log("  redeemHoldingWallet: UNSET (every redeem leaf reverts)");
        else console2.log("  redeemHoldingWallet:", hold);
        address receiver = address(registry.receiverOf(strategy));
        if (receiver == address(0)) console2.log("  deliveryReceiver: UNSET (no destinations yet)");
        else console2.log("  deliveryReceiver (Gyld's withdrawal address + mint wallet):", receiver);
        (address pd, address ph, uint64 at) = registry.pendingDestinations(strategy);
        if (at != 0) {
            console2.log("  PENDING destination change ->", pd, ph);
            console2.log("    executable at", uint256(at));
        }
        for (uint256 j; j < bondTokens.length; ++j) {
            GyldInTransitRegistry.Transit memory t = registry.transit(strategy, bondTokens[j]);
            if (t.cashOut == 0 && t.bondsOut == 0) continue;
            console2.log("  open on", bondTokens[j], ": cashOut", t.cashOut);
            console2.log("    bondsOut", t.bondsOut, "oldest open lot at", uint256(t.oldestOpenAt));
            if (registry.isStale(strategy, bondTokens[j])) {
                console2.log("    STALE: new deposits refused for this pair until the oldest lot settles");
            }
            (uint256 unsweptBonds, uint256 unsweptCash) = registry.unsweptDelivery(strategy, bondTokens[j]);
            if (unsweptBonds != 0 || unsweptCash != 0) {
                console2.log("    UNSWEPT in the receiver: bonds", unsweptBonds, "cash", unsweptCash);
            }
            if (registry.hasPendingManualSettle(strategy, bondTokens[j])) {
                console2.log("    PENDING manual settle (already netted from the valuation)");
            }
        }
    }

    function _requireRegistry(uint64 chainId, address registryAddr) internal view {
        require(block.chainid == chainId, "CHAIN_ID_MISMATCH");
        require(registryAddr != address(0), "REGISTRY_ZERO");
        require(registryAddr.code.length > 0, "REGISTRY_NOT_DEPLOYED");
    }
}
