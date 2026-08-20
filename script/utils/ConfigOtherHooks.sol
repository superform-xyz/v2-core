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
        mapping(uint64 chainId => address algebraSwapRouter) algebraSwapRouters;
        mapping(uint64 chainId => address odosRouterV3) odosRouterV3s;
        mapping(uint64 chainId => address spectraRouter) spectraRouters;
        mapping(uint64 chainId => address aaveV3Pool) aaveV3Pools;
        mapping(uint64 chainId => address coreWriter) coreWriters;
        mapping(uint64 chainId => address hyperCoreUsdc) hyperCoreUsdcs;
        mapping(uint64 chainId => address hyperCoreUsdcGateway) hyperCoreUsdcGateways;
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
}
}
