// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { DeployV2Base } from "./DeployV2Base.s.sol";
import { ConstantsOtherHooks } from "./utils/ConstantsOtherHooks.sol";
import { GyldBondRegistry } from "../src/accounting/oracles/GyldBondRegistry.sol";
import { GyldTradePolicy } from "../src/accounting/oracles/GyldTradePolicy.sol";
import { console2 } from "forge-std/console2.sol";

/// @title ConfigureGyldBondRegistry
/// @notice Sets the two `GyldBondRegistry` tolerances that `GyldTradePolicy` refuses to trade without.
/// @dev WHY THIS SCRIPT IS NOT OPTIONAL. Both tolerances FAIL CLOSED when unset, by design (F1): an unset
///      value is a value nobody chose, so the policy names the gap instead of applying a default.
///        - `maxPpsAge == 0`, AND an aggregator is wired for the chain -> every trade reverts
///          `PPS_AGE_NOT_CONFIGURED`. With no aggregator the strategy block is skipped entirely and this
///          value is never read, so the cliff does not exist there.
///        - a direction's floor bps `== 0` -> fills in that direction revert `TRADE_FLOORS_NOT_SET`,
///          EXCEPT under a zero recovery mark, where `validateFill` returns before the floor is reached.
///      A Gyld deploy followed by instrument registration but NOT by this script is a configuration where
///      no trade can execute. That is the safe failure, but it is still a broken deployment.
/// @dev ORDER, and the earlier version of this note had it impossible. `runTradeFloors` requires the
///      instrument to be REGISTERED, and `TransferGyldBondRegistryRoles` must run BEFORE any registration
///      (its own NatSpec explains why). So the only achievable order is:
///        1. `runPolicyDefaults`            as DEPLOYER  (still holds INSTRUMENT_MANAGER_ROLE)
///        2. `TransferGyldBondRegistryRoles` as DEPLOYER
///        3. `registerInstrument`           as GOVERNOR  (set both floors in the config here)
///        4. `runTradeFloors`               as GOVERNOR  (only if step 3 left a floor at zero)
///      The runbook in `script/run/deploy/deploy_v2_other_hooks_staging_prod.sh` encodes this; keep the two
///      in step.
/// @dev NEITHER SETTER IS TIMELOCKED, matching `setStalenessBounds`: these are risk tolerances, not
///      valuations. Widening is the fail-open direction — alert on `MaxPpsAgeUpdated` and
///      `TradeFloorsUpdated` and treat a widening as an event that needs a stated reason.
/// @dev THE FLOOR VALUES ARE A JUDGEMENT CALL AND THIS SCRIPT HAS NO DEFAULTS — both bps are supplied by
///      whoever types the command, with no reviewed value recorded anywhere in the repo (contrast
///      `GYLD_MAX_PPS_AGE`, which is a constant with a rationale). They must absorb
///      Gyld's real bid/ask plus settlement fees, and Gyld's spread is unknown — the venue ABI itself is
///      still unconfirmed. Too tight and every honest trade reverts; too loose and the floor is theatre.
///      `GyldBondRegistry.MAX_TOLERANCE_BPS` caps either direction at 20% so a vacuous 100% is unsettable.
contract ConfigureGyldBondRegistry is DeployV2Base, ConstantsOtherHooks {
    /*//////////////////////////////////////////////////////////////
                              MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the registry-wide PPS freshness tolerance the policy reads on every trade
    /// @dev Registry-level rather than per-instrument because PPS freshness is a property of the STRATEGY.
    /// @param env Environment (0 = prod, 2 = staging)
    /// @param chainId Chain ID (logged, and checked against the fork)
    /// @param registryAddr Deployed GyldBondRegistry
    function runPolicyDefaults(uint256 env, uint64 chainId, address registryAddr) external broadcast(env) {
        _requireRegistry(chainId, registryAddr);
        GyldBondRegistry registry = GyldBondRegistry(registryAddr);

        uint256 current = registry.maxPpsAge();
        console2.log("maxPpsAge: current", current, "-> target", GYLD_MAX_PPS_AGE);
        if (current == GYLD_MAX_PPS_AGE) {
            console2.log("  already set, skipping");
        } else {
            registry.setMaxPpsAge(GYLD_MAX_PPS_AGE);
            require(registry.maxPpsAge() == GYLD_MAX_PPS_AGE, "MAX_PPS_AGE_NOT_APPLIED");
            console2.log("  applied");
        }
        console2.log("====== Policy defaults configured ======");
    }

    /// @notice Sets one instrument's realised-price tolerances, per direction
    /// @param env Environment (0 = prod, 2 = staging)
    /// @param chainId Chain ID
    /// @param registryAddr Deployed GyldBondRegistry
    /// @param bondToken The REGISTERED instrument to configure
    /// @param maxEntryPremiumBps How far a realised BUY may sit above NAV, in bps
    /// @param maxExitDiscountBps How far a realised SELL may sit below NAV, in bps
    function runTradeFloors(
        uint256 env,
        uint64 chainId,
        address registryAddr,
        address bondToken,
        uint16 maxEntryPremiumBps,
        uint16 maxExitDiscountBps
    )
        external
        broadcast(env)
    {
        _requireRegistry(chainId, registryAddr);
        GyldBondRegistry registry = GyldBondRegistry(registryAddr);

        // Fail here rather than letting the setter's own `_requireRegistered` produce a bare revert.
        require(registry.isRegistered(bondToken), "INSTRUMENT_NOT_REGISTERED: register it first");
        // A zero tolerance is what the policy reports as unconfigured, so setting one is a no-op at best
        // and a trade-blocking mistake at worst. Refuse it here instead of writing it.
        require(maxEntryPremiumBps != 0 && maxExitDiscountBps != 0, "ZERO_BPS_IS_UNCONFIGURED_NOT_STRICT");
        uint16 ceiling = registry.MAX_TOLERANCE_BPS();
        require(maxEntryPremiumBps <= ceiling && maxExitDiscountBps <= ceiling, "BPS_ABOVE_CEILING");

        console2.log("bond", bondToken);
        console2.log("  entry premium bps ->", maxEntryPremiumBps);
        console2.log("  exit discount bps ->", maxExitDiscountBps);
        registry.setTradeFloors(bondToken, maxEntryPremiumBps, maxExitDiscountBps);

        GyldBondRegistry.InstrumentConfig memory cfg = registry.getInstrumentConfig(bondToken);
        require(cfg.maxEntryPremiumBps == maxEntryPremiumBps, "ENTRY_BPS_NOT_APPLIED");
        require(cfg.maxExitDiscountBps == maxExitDiscountBps, "EXIT_BPS_NOT_APPLIED");
        console2.log("====== Trade floors configured ======");
    }

    /// @notice READ-ONLY. Reports every tolerance the policy needs, and whether a trade could execute.
    /// @dev No broadcast, so it is safe against prod at any time. Run it after a deploy and after any
    ///      registration: a green registry with an unset tolerance looks fine and trades nothing.
    /// @param chainId Chain ID
    /// @param registryAddr Deployed GyldBondRegistry
    /// @param policyAddr Deployed GyldTradePolicy, or address(0) to skip the wiring checks
    /// @param bondTokens Instruments to report on; pass an empty array for the chain-level view only
    function runCheck(
        uint64 chainId,
        address registryAddr,
        address policyAddr,
        address[] calldata bondTokens
    )
        external
        view
    {
        _requireRegistry(chainId, registryAddr);
        GyldBondRegistry registry = GyldBondRegistry(registryAddr);

        console2.log("====== Gyld policy configuration ======");
        console2.log("chain   ", chainId);
        console2.log("registry", registryAddr);

        uint256 ppsAge = registry.maxPpsAge();
        if (ppsAge == 0) {
            console2.log("maxPpsAge  UNSET -> every trade reverts PPS_AGE_NOT_CONFIGURED");
        } else {
            console2.log("maxPpsAge ", ppsAge);
        }

        if (policyAddr != address(0)) {
            GyldTradePolicy policy = GyldTradePolicy(policyAddr);
            require(address(policy.REGISTRY()) == registryAddr, "POLICY_BOUND_TO_A_DIFFERENT_REGISTRY");
            console2.log("policy    ", policyAddr);
            console2.log("  oracle    ", address(policy.ORACLE()));
            address agg = address(policy.AGGREGATOR());
            console2.log("  aggregator", agg);
            if (agg == address(0)) {
                console2.log("  WARNING: no aggregator -> strategy pause and PPS are UNCHECKED");
            }
        }

        for (uint256 i; i < bondTokens.length; ++i) {
            address bondToken = bondTokens[i];
            console2.log("---");
            console2.log("bond", bondToken);
            if (!registry.isRegistered(bondToken)) {
                console2.log("  NOT REGISTERED");
                continue;
            }
            GyldBondRegistry.InstrumentConfig memory cfg = registry.getInstrumentConfig(bondToken);
            console2.log("  cash          ", cfg.cashToken);
            console2.log("  suspended     ", cfg.navSuspended);
            console2.log("  recoveryNavSet", cfg.recoveryNavSet);
            if (cfg.maxEntryPremiumBps == 0) {
                console2.log("  BUY  floor UNSET -> buys revert TRADE_FLOORS_NOT_SET");
            } else {
                console2.log("  BUY  floor bps", cfg.maxEntryPremiumBps);
            }
            if (cfg.maxExitDiscountBps == 0) {
                console2.log("  SELL floor UNSET -> sells revert TRADE_FLOORS_NOT_SET");
            } else {
                console2.log("  SELL floor bps", cfg.maxExitDiscountBps);
            }
            // R4-3: an OPEN exit grace is a live relaxation of the sell floor, so it must be visible here
            // rather than only in an event from whenever it was opened. Closed is the normal state.
            if (cfg.emergencyExitMaxPublicationAge == 0) {
                console2.log("  exit grace    CLOSED (strict: a stale NAV blocks sells)");
            } else {
                console2.log("  exit grace OPEN, window s", cfg.emergencyExitMaxPublicationAge);
                console2.log("    graced SELL floor bps  ", cfg.emergencyExitDiscountBps);
                console2.log("    ^ close it with setEmergencyExit(bond, 0, 0) once the incident is over");
            }
        }
        console2.log("====== End ======");
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL
    //////////////////////////////////////////////////////////////*/

    function _requireRegistry(uint64 chainId, address registryAddr) private view {
        require(chainId == uint64(block.chainid), "CHAIN_ID_MISMATCH: wrong --rpc-url for this chainId");
        require(registryAddr != address(0), "REGISTRY_ADDRESS_ZERO");
        require(registryAddr.code.length > 0, "GYLD_REGISTRY_NOT_DEPLOYED_ON_THIS_CHAIN");
    }
}
