// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.30;

import { ConfigBase } from "./ConfigBase.sol";

/// @title ConfigCore
/// @notice Standalone core configuration contract for core contract deployments
/// @dev Handles Nexus factories, Permit2, Across Spoke Pools, and DeBridge configurations
abstract contract ConfigCore is ConfigBase {
    /*//////////////////////////////////////////////////////////////
                            CORE CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets up core contract dependencies
    /// @dev Configures addresses required for core contract deployment and operation
    function _setCoreConfiguration() internal {
        // ===== ACROSS SPOKE POOL V3 ADDRESSES =====
        configuration.acrossSpokePoolV3s[MAINNET_CHAIN_ID] = ACROSS_SPOKE_POOL_MAINNET;
        configuration.acrossSpokePoolV3s[BASE_CHAIN_ID] = ACROSS_SPOKE_POOL_BASE;
        configuration.acrossSpokePoolV3s[BNB_CHAIN_ID] = ACROSS_SPOKE_POOL_BNB;
        configuration.acrossSpokePoolV3s[ARBITRUM_CHAIN_ID] = ACROSS_SPOKE_POOL_ARBITRUM;
        configuration.acrossSpokePoolV3s[OPTIMISM_CHAIN_ID] = ACROSS_SPOKE_POOL_OPTIMISM;
        configuration.acrossSpokePoolV3s[POLYGON_CHAIN_ID] = ACROSS_SPOKE_POOL_POLYGON;
        configuration.acrossSpokePoolV3s[UNICHAIN_CHAIN_ID] = ACROSS_SPOKE_POOL_UNICHAIN;
        configuration.acrossSpokePoolV3s[LINEA_CHAIN_ID] = ACROSS_SPOKE_POOL_LINEA;
        configuration.acrossSpokePoolV3s[AVALANCHE_CHAIN_ID] = address(0); // Across not available on Avalanche
        configuration.acrossSpokePoolV3s[BERACHAIN_CHAIN_ID] = address(0); // Not deployed yet
        configuration.acrossSpokePoolV3s[SONIC_CHAIN_ID] = address(0); // Not deployed yet
        configuration.acrossSpokePoolV3s[GNOSIS_CHAIN_ID] = address(0); // Not deployed yet
        configuration.acrossSpokePoolV3s[WORLDCHAIN_CHAIN_ID] = ACROSS_SPOKE_POOL_WORLDCHAIN;

        // ===== DEBRIDGE DLN SOURCE ADDRESSES =====
        configuration.debridgeSrcDln[MAINNET_CHAIN_ID] = DEBRIDGE_DLN_SRC;
        configuration.debridgeSrcDln[BASE_CHAIN_ID] = DEBRIDGE_DLN_SRC;
        configuration.debridgeSrcDln[BNB_CHAIN_ID] = DEBRIDGE_DLN_SRC;
        configuration.debridgeSrcDln[ARBITRUM_CHAIN_ID] = DEBRIDGE_DLN_SRC;
        configuration.debridgeSrcDln[OPTIMISM_CHAIN_ID] = DEBRIDGE_DLN_SRC;
        configuration.debridgeSrcDln[POLYGON_CHAIN_ID] = DEBRIDGE_DLN_SRC;
        configuration.debridgeSrcDln[UNICHAIN_CHAIN_ID] = address(0);
        configuration.debridgeSrcDln[LINEA_CHAIN_ID] = DEBRIDGE_DLN_SRC;
        configuration.debridgeSrcDln[AVALANCHE_CHAIN_ID] = DEBRIDGE_DLN_SRC;
        configuration.debridgeSrcDln[BERACHAIN_CHAIN_ID] = DEBRIDGE_DLN_SRC;
        configuration.debridgeSrcDln[SONIC_CHAIN_ID] = DEBRIDGE_DLN_SRC;
        configuration.debridgeSrcDln[GNOSIS_CHAIN_ID] = DEBRIDGE_DLN_SRC;
        configuration.debridgeSrcDln[WORLDCHAIN_CHAIN_ID] = address(0); // Not deployed yet

        // ===== DEBRIDGE DLN DESTINATION ADDRESSES =====
        configuration.debridgeDstDln[MAINNET_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[BASE_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[BNB_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[ARBITRUM_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[OPTIMISM_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[POLYGON_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[UNICHAIN_CHAIN_ID] = address(0);
        configuration.debridgeDstDln[LINEA_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[AVALANCHE_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[BERACHAIN_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[SONIC_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[GNOSIS_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[WORLDCHAIN_CHAIN_ID] = address(0); // Not deployed yet

        // ===== PERMIT2 ADDRESSES =====
        configuration.permit2s[MAINNET_CHAIN_ID] = PERMIT2;
        configuration.permit2s[BASE_CHAIN_ID] = PERMIT2;
        configuration.permit2s[BNB_CHAIN_ID] = PERMIT2;
        configuration.permit2s[ARBITRUM_CHAIN_ID] = PERMIT2;
        configuration.permit2s[OPTIMISM_CHAIN_ID] = PERMIT2;
        configuration.permit2s[POLYGON_CHAIN_ID] = PERMIT2;
        configuration.permit2s[UNICHAIN_CHAIN_ID] = PERMIT2;
        configuration.permit2s[LINEA_CHAIN_ID] = PERMIT2;
        configuration.permit2s[AVALANCHE_CHAIN_ID] = PERMIT2;
        configuration.permit2s[BERACHAIN_CHAIN_ID] = PERMIT2;
        configuration.permit2s[SONIC_CHAIN_ID] = PERMIT2;
        configuration.permit2s[GNOSIS_CHAIN_ID] = PERMIT2;
        configuration.permit2s[WORLDCHAIN_CHAIN_ID] = PERMIT2;

        // ===== MERKL DISTRIBUTOR ADDRESSES =====
        configuration.merklDistributors[MAINNET_CHAIN_ID] = MERKL_DISTRIBUTOR;
        configuration.merklDistributors[BASE_CHAIN_ID] = MERKL_DISTRIBUTOR;
        configuration.merklDistributors[BNB_CHAIN_ID] = MERKL_DISTRIBUTOR;
        configuration.merklDistributors[ARBITRUM_CHAIN_ID] = MERKL_DISTRIBUTOR;
        configuration.merklDistributors[OPTIMISM_CHAIN_ID] = MERKL_DISTRIBUTOR;
        configuration.merklDistributors[POLYGON_CHAIN_ID] = MERKL_DISTRIBUTOR;
        configuration.merklDistributors[UNICHAIN_CHAIN_ID] = MERKL_DISTRIBUTOR;
        configuration.merklDistributors[LINEA_CHAIN_ID] = MERKL_DISTRIBUTOR;
        configuration.merklDistributors[AVALANCHE_CHAIN_ID] = MERKL_DISTRIBUTOR;
        configuration.merklDistributors[BERACHAIN_CHAIN_ID] = MERKL_DISTRIBUTOR;
        configuration.merklDistributors[SONIC_CHAIN_ID] = MERKL_DISTRIBUTOR;
        configuration.merklDistributors[GNOSIS_CHAIN_ID] = MERKL_DISTRIBUTOR;
        configuration.merklDistributors[WORLDCHAIN_CHAIN_ID] = MERKL_DISTRIBUTOR;

        // ===== CRITICAL ROUTER ADDRESSES FOR CORE HOOKS =====
        // These are required for core hook deployments
        configuration.aggregationRouters[MAINNET_CHAIN_ID] = AGGREGATION_ROUTER;
        configuration.aggregationRouters[BASE_CHAIN_ID] = AGGREGATION_ROUTER;
        configuration.aggregationRouters[BNB_CHAIN_ID] = AGGREGATION_ROUTER;
        configuration.aggregationRouters[ARBITRUM_CHAIN_ID] = AGGREGATION_ROUTER;
        configuration.aggregationRouters[OPTIMISM_CHAIN_ID] = AGGREGATION_ROUTER;
        configuration.aggregationRouters[POLYGON_CHAIN_ID] = AGGREGATION_ROUTER;
        configuration.aggregationRouters[UNICHAIN_CHAIN_ID] = AGGREGATION_ROUTER;
        configuration.aggregationRouters[LINEA_CHAIN_ID] = AGGREGATION_ROUTER;
        configuration.aggregationRouters[AVALANCHE_CHAIN_ID] = AGGREGATION_ROUTER;
        configuration.aggregationRouters[BERACHAIN_CHAIN_ID] = address(0); // Not deployed
        configuration.aggregationRouters[SONIC_CHAIN_ID] = AGGREGATION_ROUTER;
        configuration.aggregationRouters[GNOSIS_CHAIN_ID] = AGGREGATION_ROUTER;
        configuration.aggregationRouters[WORLDCHAIN_CHAIN_ID] = address(0); // Not deployed

        configuration.odosRouters[MAINNET_CHAIN_ID] = ODOS_ROUTER_MAINNET;
        configuration.odosRouters[BASE_CHAIN_ID] = ODOS_ROUTER_BASE;
        configuration.odosRouters[BNB_CHAIN_ID] = ODOS_ROUTER_BNB;
        configuration.odosRouters[ARBITRUM_CHAIN_ID] = ODOS_ROUTER_ARBITRUM;
        configuration.odosRouters[OPTIMISM_CHAIN_ID] = ODOS_ROUTER_OPTIMISM;
        configuration.odosRouters[POLYGON_CHAIN_ID] = ODOS_ROUTER_POLYGON;
        configuration.odosRouters[UNICHAIN_CHAIN_ID] = ODOS_ROUTER_UNICHAIN;
        configuration.odosRouters[LINEA_CHAIN_ID] = ODOS_ROUTER_LINEA;
        configuration.odosRouters[AVALANCHE_CHAIN_ID] = ODOS_ROUTER_AVALANCHE;
        configuration.odosRouters[BERACHAIN_CHAIN_ID] = address(0); // Not deployed
        configuration.odosRouters[SONIC_CHAIN_ID] = ODOS_ROUTER_SONIC;
        configuration.odosRouters[GNOSIS_CHAIN_ID] = address(0); // Not deployed
        configuration.odosRouters[WORLDCHAIN_CHAIN_ID] = address(0); // Not deployed

        // ===== PENDLE ROUTER ADDRESSES =====
        configuration.pendleRouters[MAINNET_CHAIN_ID] = PENDLE_ROUTER_MAINNET;
        configuration.pendleRouters[BASE_CHAIN_ID] = PENDLE_ROUTER_BASE;
        configuration.pendleRouters[BNB_CHAIN_ID] = PENDLE_ROUTER_BNB;
        configuration.pendleRouters[ARBITRUM_CHAIN_ID] = PENDLE_ROUTER_ARBITRUM;
        configuration.pendleRouters[OPTIMISM_CHAIN_ID] = PENDLE_ROUTER_OPTIMISM;
        configuration.pendleRouters[POLYGON_CHAIN_ID] = address(0); // Not deployed
        configuration.pendleRouters[UNICHAIN_CHAIN_ID] = address(0); // Not deployed
        configuration.pendleRouters[LINEA_CHAIN_ID] = address(0); // Not deployed
        configuration.pendleRouters[AVALANCHE_CHAIN_ID] = address(0); // Not deployed
        configuration.pendleRouters[BERACHAIN_CHAIN_ID] = address(0); // Not deployed
        configuration.pendleRouters[SONIC_CHAIN_ID] = address(0); // Not deployed
        configuration.pendleRouters[GNOSIS_CHAIN_ID] = address(0); // Not deployed
        configuration.pendleRouters[WORLDCHAIN_CHAIN_ID] = address(0); // Not deployed

        // ===== NATIVE TOKEN ADDRESSES =====
        configuration.nativeTokens[MAINNET_CHAIN_ID] = NATIVE_TOKEN_DEFAULT;
        configuration.nativeTokens[BASE_CHAIN_ID] = NATIVE_TOKEN_DEFAULT;
        configuration.nativeTokens[BNB_CHAIN_ID] = NATIVE_TOKEN_DEFAULT;
        configuration.nativeTokens[ARBITRUM_CHAIN_ID] = NATIVE_TOKEN_DEFAULT;
        configuration.nativeTokens[OPTIMISM_CHAIN_ID] = NATIVE_TOKEN_DEFAULT;
        configuration.nativeTokens[POLYGON_CHAIN_ID] = NATIVE_TOKEN_POLYGON;
        configuration.nativeTokens[UNICHAIN_CHAIN_ID] = NATIVE_TOKEN_DEFAULT;
        configuration.nativeTokens[LINEA_CHAIN_ID] = NATIVE_TOKEN_DEFAULT;
        configuration.nativeTokens[AVALANCHE_CHAIN_ID] = NATIVE_TOKEN_DEFAULT;
        configuration.nativeTokens[BERACHAIN_CHAIN_ID] = NATIVE_TOKEN_DEFAULT;
        configuration.nativeTokens[SONIC_CHAIN_ID] = NATIVE_TOKEN_DEFAULT;
        configuration.nativeTokens[GNOSIS_CHAIN_ID] = NATIVE_TOKEN_DEFAULT;
        configuration.nativeTokens[WORLDCHAIN_CHAIN_ID] = NATIVE_TOKEN_DEFAULT;

        // ===== UNISWAP V4 POOL MANAGER ADDRESSES =====
        configuration.uniswapV4PoolManagers[MAINNET_CHAIN_ID] = 0x000000000004444c5dc75cB358380D2e3dE08A90;
        configuration.uniswapV4PoolManagers[BASE_CHAIN_ID] = 0x498581fF718922c3f8e6A244956aF099B2652b2b;
        configuration.uniswapV4PoolManagers[BNB_CHAIN_ID] = address(0); // Not deployed
        configuration.uniswapV4PoolManagers[ARBITRUM_CHAIN_ID] = 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;
        configuration.uniswapV4PoolManagers[OPTIMISM_CHAIN_ID] = 0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3;
        configuration.uniswapV4PoolManagers[POLYGON_CHAIN_ID] = 0x67366782805870060151383F4BbFF9daB53e5cD6;
        configuration.uniswapV4PoolManagers[UNICHAIN_CHAIN_ID] = 0x1F98400000000000000000000000000000000004;
        configuration.uniswapV4PoolManagers[LINEA_CHAIN_ID] = address(0); // Not deployed
        configuration.uniswapV4PoolManagers[AVALANCHE_CHAIN_ID] = 0x06380C0e0912312B5150364B9DC4542BA0DbBc85;
        configuration.uniswapV4PoolManagers[BERACHAIN_CHAIN_ID] = address(0); // Not deployed
        configuration.uniswapV4PoolManagers[SONIC_CHAIN_ID] = address(0); // Not deployed
        configuration.uniswapV4PoolManagers[GNOSIS_CHAIN_ID] = address(0); // Not deployed
        configuration.uniswapV4PoolManagers[WORLDCHAIN_CHAIN_ID] = 0xb1860D529182ac3BC1F51Fa2ABd56662b7D13f33;
    }
}
