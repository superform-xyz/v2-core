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
        mapping(uint64 chainId => uint256 maxInputAmount) binanceMaxInputAmounts;
        // Gyld tokenized bonds. TWO gates, deliberately, because the valuation half and the trading half
        // have different prerequisites: the registry, oracle and guard need nothing from Gyld and can ship
        // ahead of the venue, while the trade hooks pin a settlement address that does not exist yet.
        mapping(uint64 chainId => bool enabled) gyldOracleEnabled;
        mapping(uint64 chainId => address gyldSettlement) gyldSettlements;
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
