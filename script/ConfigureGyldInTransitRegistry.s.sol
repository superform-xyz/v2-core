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
///      deposit additionally needs a non-zero per-instrument cap. A deploy without this script is inert.
/// @dev ORDER. `runDestinations` and `runTransitDefaults` run AS DEPLOYER (still MANAGER_ROLE), then
///      `TransferGyldInTransitRegistryRoles` hands the roles over, then `runCap` runs AS GOVERNOR per
///      registered instrument. The destinations come from Gyld onboarding (`GET /deposit/address`,
///      `GET /portfolio.redeem_holding_wallet`) for OUR Gyld account; the first set is immediate and every
///      later change waits `DESTINATION_DELAY` behind `proposeDestinations`.
contract ConfigureGyldInTransitRegistry is DeployV2Base, ConstantsOtherHooks {
    /// @notice First-time set of the two Gyld destinations
    function runDestinations(
        uint256 env,
        uint64 chainId,
        address registryAddr,
        address depositAddress,
        address redeemHoldingWallet
    )
        external
        broadcast(env)
    {
        _requireRegistry(chainId, registryAddr);
        require(depositAddress != address(0) && redeemHoldingWallet != address(0), "ZERO_DESTINATION");
        GyldInTransitRegistry registry = GyldInTransitRegistry(registryAddr);
        console2.log("depositAddress      ->", depositAddress);
        console2.log("redeemHoldingWallet ->", redeemHoldingWallet);
        registry.setDestinations(depositAddress, redeemHoldingWallet);
        require(registry.depositAddress() == depositAddress, "DEPOSIT_ADDRESS_NOT_APPLIED");
        require(registry.redeemHoldingWallet() == redeemHoldingWallet, "HOLDING_WALLET_NOT_APPLIED");
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

    /// @notice Per-instrument cap on OUTSTANDING cash at Gyld, in raw cash-token units. Zero disables deposits.
    function runCap(
        uint256 env,
        uint64 chainId,
        address registryAddr,
        address bondToken,
        uint256 cap
    )
        external
        broadcast(env)
    {
        _requireRegistry(chainId, registryAddr);
        GyldInTransitRegistry registry = GyldInTransitRegistry(registryAddr);
        console2.log("maxCashInTransit for", bondToken, "->", cap);
        registry.setMaxCashInTransit(bondToken, cap);
        require(registry.maxCashInTransit(bondToken) == cap, "CAP_NOT_APPLIED");
        console2.log("====== Cap configured ======");
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

    /// @notice Read-only check. Prints UNSET for every value the hooks would fail closed on.
    function runCheck(uint64 chainId, address registryAddr, address[] calldata bondTokens) external view {
        _requireRegistry(chainId, registryAddr);
        GyldInTransitRegistry registry = GyldInTransitRegistry(registryAddr);
        console2.log("====== GyldInTransitRegistry check ======");
        address dep = registry.depositAddress();
        address hold = registry.redeemHoldingWallet();
        uint256 age = registry.maxTransitAge();
        if (dep == address(0)) console2.log("depositAddress: UNSET (every deposit leaf reverts)");
        else console2.log("depositAddress:", dep);
        if (hold == address(0)) console2.log("redeemHoldingWallet: UNSET (every redeem leaf reverts)");
        else console2.log("redeemHoldingWallet:", hold);
        if (age == 0) console2.log("maxTransitAge: UNSET (every record reverts)");
        else console2.log("maxTransitAge:", age);
        console2.log("lots recorded so far:", registry.lotCount());
        (address pd, address ph, uint64 at) = registry.pendingDestinations();
        if (at != 0) {
            console2.log("PENDING destination change ->", pd, ph);
            console2.log("  executable at", uint256(at));
        }
        for (uint256 i; i < bondTokens.length; ++i) {
            uint256 cap = registry.maxCashInTransit(bondTokens[i]);
            if (cap == 0) console2.log("maxCashInTransit UNSET (deposits disabled) for", bondTokens[i]);
            else console2.log("maxCashInTransit", cap, "for", bondTokens[i]);
            console2.log("  totalCashInTransit", registry.totalCashInTransit(bondTokens[i]));
        }
    }

    function _requireRegistry(uint64 chainId, address registryAddr) internal view {
        require(block.chainid == chainId, "CHAIN_ID_MISMATCH");
        require(registryAddr != address(0), "REGISTRY_ZERO");
        require(registryAddr.code.length > 0, "REGISTRY_NOT_DEPLOYED");
    }
}
