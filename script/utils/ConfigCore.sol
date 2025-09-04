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
    }
}
