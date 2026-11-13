// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.30;

import { ConfigBase } from "./ConfigBase.sol";
import { ConstantsOtherHooks } from "./ConstantsOtherHooks.sol";

/// @title ConfigOtherHooks
/// @notice Morpho protocol address configuration for hook deployment
abstract contract ConfigOtherHooks is ConfigBase, ConstantsOtherHooks {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    struct OtherHooksData {
        mapping(uint64 chainId => address morpho) morphos;
        mapping(uint64 chainId => address eulerEvc) eulerEvcs;
        mapping(uint64 chainId => address eulerEVaultFactory) eulerEVaultFactories;
        mapping(uint64 chainId => address algebraSwapRouter) algebraSwapRouters;
        mapping(uint64 chainId => address odosRouterV3) odosRouterV3s;
        mapping(uint64 chainId => address spectraRouter) spectraRouters;
        mapping(uint64 chainId => address aaveV3Pool) aaveV3Pools;
        mapping(uint64 chainId => address coreWriter) coreWriters;
        mapping(uint64 chainId => address hyperCoreUsdc) hyperCoreUsdcs;
        mapping(uint64 chainId => address hyperCoreUsdcGateway) hyperCoreUsdcGateways;
        mapping(uint64 chainId => address superVaultGovernor) superVaultGovernors;
        mapping(uint64 chainId => address binanceRouter) binanceRouters;
        // SushiSwap v7 (SUP-21826): RedSnwapper is the approval spender/call target, the RouteProcessor is the
        // ONLY executor the hooks accept inside the calldata. Both pinned per chain; presence of BOTH gates.
        mapping(uint64 chainId => address redSnwapper) sushiRedSnwappers;
        mapping(uint64 chainId => address routeProcessor) sushiRouteProcessors;
        // Everlong Router (SUP-21826): canonical Uniswap SwapRouter02 + its WETH9. Presence of BOTH gates.
        mapping(uint64 chainId => address router) everlongRouters;
        mapping(uint64 chainId => address weth9) everlongWeth9s;
        mapping(uint64 chainId => uint256 maxInputAmount) binanceMaxInputAmounts;
        // Gyld tokenized bonds. TWO gates, deliberately, because the valuation half and the trading half
        // have different prerequisites: the registry, oracle and guard need nothing from Gyld and can ship
        // ahead of the venue, while the trade hooks pin a settlement address that does not exist yet.
        mapping(uint64 chainId => bool enabled) gyldOracleEnabled;
        mapping(uint64 chainId => address gyldSettlement) gyldSettlements;
        /// @notice SuperVaultAggregator per chain, for `GyldTradePolicy`'s strategy pause / PPS checks.
        /// @dev Zero means those checks are DISABLED and a paused strategy could still trade, so leave it
        ///      unset only on a chain with no SuperVault aggregator. The deploy script warns when it is zero.
        mapping(uint64 chainId => address aggregator) superVaultAggregators;
        /// @notice STAGING SuperVaultAggregator per chain, kept separate from the production table above.
        /// @dev `_setOtherHooksConfiguration()` takes no `env`, so one shared table would mean a staging Gyld
        ///      deploy pinned the PRODUCTION aggregator into the staging policy's immutable — and the
        ///      `code.length > 0` guard would pass, because the prod aggregator has code. Two tables plus an
        ///      env-selected read in `_deployGyldHooks` is the structural fix for that.
        mapping(uint64 chainId => address aggregator) superVaultAggregatorsStaging;
        mapping(uint64 chainId => uint256 maxInputAmount) gyldMaxCashInputAmounts;
        mapping(uint64 chainId => uint256 maxInputAmount) gyldMaxBondInputAmounts;
    }

    OtherHooksData internal otherHooksConfiguration;

    /*//////////////////////////////////////////////////////////////
                        PROTOCOL CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets up protocol addresses per chain for other hooks
    function _setOtherHooksConfiguration() internal {
        // Morpho
        otherHooksConfiguration.morphos[MAINNET_CHAIN_ID] = MORPHO_MAINNET;
        otherHooksConfiguration.morphos[BASE_CHAIN_ID] = MORPHO_BASE;
        otherHooksConfiguration.morphos[OPTIMISM_CHAIN_ID] = MORPHO_OPTIMISM;
        otherHooksConfiguration.morphos[ARBITRUM_CHAIN_ID] = MORPHO_ARBITRUM;
        otherHooksConfiguration.morphos[ROBINHOOD_CHAIN_ID] = MORPHO_ROBINHOOD; // Morpho live on RH (chain 4663)
        otherHooksConfiguration.morphos[BNB_CHAIN_ID] = MORPHO_BNB;

        // Euler EVK singletons per chain — gate Euler hook deployment (Base only for now, Clearstar).
        otherHooksConfiguration.eulerEvcs[BASE_CHAIN_ID] = EULER_EVC_BASE;
        otherHooksConfiguration.eulerEVaultFactories[BASE_CHAIN_ID] = EULER_EVAULT_FACTORY_BASE;

        // Aave V3 Pool per chain — gates Aave V3 hook deployment (only where Aave V3 is live).
        otherHooksConfiguration.aaveV3Pools[MAINNET_CHAIN_ID] = AAVE_V3_POOL_MAINNET;
        otherHooksConfiguration.aaveV3Pools[BASE_CHAIN_ID] = AAVE_V3_POOL_BASE;
        otherHooksConfiguration.aaveV3Pools[BNB_CHAIN_ID] = AAVE_V3_POOL_BNB;
        otherHooksConfiguration.aaveV3Pools[ARBITRUM_CHAIN_ID] = AAVE_V3_POOL_ARBITRUM;
        otherHooksConfiguration.aaveV3Pools[OPTIMISM_CHAIN_ID] = AAVE_V3_POOL_OPTIMISM;
        otherHooksConfiguration.aaveV3Pools[POLYGON_CHAIN_ID] = AAVE_V3_POOL_POLYGON;
        otherHooksConfiguration.aaveV3Pools[AVALANCHE_CHAIN_ID] = AAVE_V3_POOL_AVALANCHE;
        otherHooksConfiguration.aaveV3Pools[GNOSIS_CHAIN_ID] = AAVE_V3_POOL_GNOSIS;
        otherHooksConfiguration.aaveV3Pools[LINEA_CHAIN_ID] = AAVE_V3_POOL_LINEA;
        otherHooksConfiguration.aaveV3Pools[SONIC_CHAIN_ID] = AAVE_V3_POOL_SONIC;
        // Not deployed on: Unichain, Berachain, Worldchain, HyperEVM, Flare, Stable, Robinhood.

        // Algebra Integral (SparkDEX V4)
        otherHooksConfiguration.algebraSwapRouters[FLARE_CHAIN_ID] = ALGEBRA_INTEGRAL_SWAP_ROUTER_FLARE;

        // Spectra Router
        otherHooksConfiguration.spectraRouters[MAINNET_CHAIN_ID] = SPECTRA_ROUTER_MAINNET;
        otherHooksConfiguration.spectraRouters[BASE_CHAIN_ID] = SPECTRA_ROUTER_BASE;
        otherHooksConfiguration.spectraRouters[ARBITRUM_CHAIN_ID] = SPECTRA_ROUTER_ARBITRUM;
        otherHooksConfiguration.spectraRouters[OPTIMISM_CHAIN_ID] = SPECTRA_ROUTER_OPTIMISM;
        otherHooksConfiguration.spectraRouters[BNB_CHAIN_ID] = SPECTRA_ROUTER_BNB;
        otherHooksConfiguration.spectraRouters[SONIC_CHAIN_ID] = SPECTRA_ROUTER_SONIC;
        otherHooksConfiguration.spectraRouters[AVALANCHE_CHAIN_ID] = SPECTRA_ROUTER_AVALANCHE;
        otherHooksConfiguration.spectraRouters[HYPEREVM_CHAIN_ID] = SPECTRA_ROUTER_HYPEREVM;

        // Binance DEX router — BSC only (SuperMAG7 USDT -> bStocks). Presence gates the family.
        // Router confirmed on-chain by us 2026-10-12 (see BINANCE_DEX_ROUTER_BNB). The generic `run`
        // path deploys the family on BSC whenever this row is set; clear it (or deploy only via
        // TARGET_FAMILY=Binance) if the hook must not ship with a routine BSC run.
        otherHooksConfiguration.binanceRouters[BNB_CHAIN_ID] = BINANCE_DEX_ROUTER_BNB;
        otherHooksConfiguration.binanceMaxInputAmounts[BNB_CHAIN_ID] = BINANCE_MAX_INPUT_AMOUNT_BNB;

        // SushiSwap v7 — Katana (SUP-21826). RedSnwapper verified on Katanascan; the Katana RouteProcessor is
        // byte-identical to Base's and exposes the 8-arg processRoute the hooks patch. Ethereum's executor has
        // a different ABI and is deliberately NOT configured. Presence of both rows gates the family.
        otherHooksConfiguration.sushiRedSnwappers[KATANA_CHAIN_ID] = SUSHISWAP_RED_SNWAPPER;
        otherHooksConfiguration.sushiRouteProcessors[KATANA_CHAIN_ID] = SUSHISWAP_ROUTE_PROCESSOR_KATANA;

        // Everlong Router — Katana (SUP-21826). Verified canonical Uniswap SwapRouter02; WETH9 = vbETH. Both
        // are constructor immutables of the two hooks. Presence of both rows gates the family.
        otherHooksConfiguration.everlongRouters[KATANA_CHAIN_ID] = EVERLONG_ROUTER_KATANA;
        otherHooksConfiguration.everlongWeth9s[KATANA_CHAIN_ID] = EVERLONG_WETH9_KATANA;

        // Odos V3 Router (same CREATE2 address on all EVM chains)
        otherHooksConfiguration.odosRouterV3s[MAINNET_CHAIN_ID] = ODOS_ROUTER_V3;
        otherHooksConfiguration.odosRouterV3s[BASE_CHAIN_ID] = ODOS_ROUTER_V3;
        otherHooksConfiguration.odosRouterV3s[BNB_CHAIN_ID] = ODOS_ROUTER_V3;
        otherHooksConfiguration.odosRouterV3s[ARBITRUM_CHAIN_ID] = ODOS_ROUTER_V3;
        otherHooksConfiguration.odosRouterV3s[OPTIMISM_CHAIN_ID] = ODOS_ROUTER_V3;
        otherHooksConfiguration.odosRouterV3s[POLYGON_CHAIN_ID] = ODOS_ROUTER_V3;
        otherHooksConfiguration.odosRouterV3s[AVALANCHE_CHAIN_ID] = ODOS_ROUTER_V3;
        otherHooksConfiguration.odosRouterV3s[SONIC_CHAIN_ID] = ODOS_ROUTER_V3;
        otherHooksConfiguration.odosRouterV3s[LINEA_CHAIN_ID] = ODOS_ROUTER_V3;

        // HyperCore hooks — HyperEVM only. Presence of coreWriters gates the whole family.
        otherHooksConfiguration.coreWriters[HYPEREVM_CHAIN_ID] = CORE_WRITER;
        otherHooksConfiguration.hyperCoreUsdcs[HYPEREVM_CHAIN_ID] = HYPERCORE_USDC_HYPEREVM;
        otherHooksConfiguration.hyperCoreUsdcGateways[HYPEREVM_CHAIN_ID] = HYPERCORE_USDC_GATEWAY_HYPEREVM;

        // Gyld tokenized bonds — Katana. BOTH tables are deliberately EMPTY, so the family is skipped on
        // every chain by the generic `run` path and must be deployed with TARGET_FAMILY=Gyld.
        //
        // Why nothing is enabled yet:
        //   1. Gyld's settlement contract and NAV feed are deployed NOWHERE. `IGyldSettlement` and
        //      `IGyldNavFeed` are our ASSUMED ABIs and venue requirements R1-R7 are unconfirmed, so the
        //      trade hooks have no address to pin and the registry has no feed to point an instrument at.
        //   2. Three high-severity findings from the 2026-11-02 security review are open against the
        //      change set (recovery NAV outranking the suspension switch; a future-dated publication
        //      timestamp suspending the staleness check; the guard not being bound to the trade it
        //      accompanies). See .claude/sessions/context_session_gyld_bonds.md.
        //   3. Katana is not yet a deployable target in this repo beyond this chain id: no networks entry,
        //      no RPC wiring, and the Nexus K1 factory and bootstrap are not deployed there.
        //
        // To enable the VALUATION half on a chain (registry + oracle + guard, all inert until an
        // instrument is registered):
        //     otherHooksConfiguration.gyldOracleEnabled[KATANA_CHAIN_ID] = true;

        // SuperVaultAggregator — SET, and the one Gyld-adjacent address that IS confirmed. GyldTradePolicy
        // reads strategy pause and PPS freshness through it; zero would mean a PAUSED strategy could still
        // trade, so it is wired ahead of the rest rather than left for later.
        // VERIFIED on Katana mainnet 2026-11-05: 21,772 bytes of code; `isStrategyPaused` and `isPPSStale`
        // answer for any address (no `validStrategy` upstream); `getPPS` reverts UNKNOWN_STRATEGY
        // (0x8a525cdd) for a non-strategy, which is precisely the registration probe the policy relies on.
        // Source: v2-periphery script/output/prod/747474/Katana-latest.json.
        // Inert until gyldOracleEnabled[747474] is set, because the policy deploys with the oracle half.
        //
        // TWO HAZARDS BEFORE ENABLING ANY CHAIN.
        // 1. THIS TABLE IS SHARED BY PROD AND STAGING. `_setOtherHooksConfiguration()` takes no `env` and
        //    branches on none; only the CREATE2 salt namespace differs. v2-periphery has no
        //    script/output/staging/747474, so a STAGING Gyld deploy on Katana would pin this PRODUCTION
        //    aggregator into the staging policy's immutable — and the `code.length > 0` guard in
        //    _deployGyldHooks PASSES, because the prod aggregator has code. Nothing catches it. Add an env
        //    branch or a staging row before deploying Gyld to staging.
        // 2. CHANGING THIS ADDRESS CHANGES THREE ADDRESSES. It is a constructor arg of GyldTradePolicy,
        //    which is itself a constructor arg of both trade instances, so a new aggregator means a new
        //    policy AND two new trade hook addresses — re-registration in SuperGovernor plus a Merkle root
        //    re-sign. That is the deliberate cost of pinning it rather than resolving it dynamically; note
        //    SuperVaultStrategy resolves its own aggregator through SUPER_GOVERNOR precisely so it can move.
        otherHooksConfiguration.superVaultAggregators[KATANA_CHAIN_ID] = 0x10AC0b33e1C4501CF3ec1cB1AE51ebfdbd2d4698;
        // VERIFICATION STATUS of the values these mappings would hold, checked 2026-11-02:
        //   gyldOracleEnabled        chain 747474 confirmed live (eth_chainId). Katana is NOT in
        //                            networks-production.sh / networks-staging.sh, so even a targeted run
        //                            cannot reach it until it is added there with an RPC variable.
        //   gyldSettlements          DO NOT SET. Gyld's stack is deployed on Katana BOKUTO TESTNET
        //                            (chain 737373), not on mainnet 747474, and the settling contract is
        //                            named GyldAtomicSwap, which does NOT match the fill(Quote, bytes)
        //                            shape assumed in src/vendor/gyld/IGyldSettlement.sol. Two public
        //                            sources give different addresses for it, the deployment PR was
        //                            superseded, and no Bokuto RPC was reachable to verify on-chain.
        //                            Get the address AND the real ABI from Gyld before setting this.
        //   gyldMaxCashInputAmounts  GYLD_MAX_CASH_INPUT_AMOUNT_KATANA, re-derived after an earlier draft
        //                            was found to be 1.75x the ENTIRE live vbUSDC supply. See the
        //                            constant's derivation note; GyldBondKatanaFork asserts it against
        //                            live supply. STILL PROVISIONAL: needs a position-size sign-off.
        //   gyldMaxBondInputAmounts  GYLD_MAX_BOND_INPUT_AMOUNT_KATANA, which ASSUMES an 18-decimal bond
        //                            token. Unverifiable today: no bond token exists on Katana mainnet.
        //                            Confirm decimals() on the real token first.
        //
        // To additionally enable the TRADING half, once Gyld's settlement address is confirmed:
        //     otherHooksConfiguration.gyldSettlements[KATANA_CHAIN_ID] = <the venue>;
        //     otherHooksConfiguration.gyldMaxCashInputAmounts[KATANA_CHAIN_ID] =
        //         GYLD_MAX_CASH_INPUT_AMOUNT_KATANA;
        //     otherHooksConfiguration.gyldMaxBondInputAmounts[KATANA_CHAIN_ID] =
        //         GYLD_MAX_BOND_INPUT_AMOUNT_KATANA;
        // Enabling the trading half without the valuation half is rejected by the deploy function: the
        // trade hooks read the registry, and the guard that makes a Gyld trade safe reads the oracle.

        // SuperVault cap-bridge hooks — gated on superVaultGovernors. SuperGovernor is a
        // v2-periphery deployment that has not reached staging/prod yet, so this table is
        // deliberately EMPTY and the family is skipped on every chain. To enable a chain:
        // set its SuperGovernor address here AND populate the bridge endpoints the family
        // reads (configuration.acrossSpokePoolV3s / debridgeSrcDln / lzEndpointV2s +
        // stargateTokenMessagings) for that chain from the shared Constants.
    }
}
