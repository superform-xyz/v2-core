// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.30;

import "./ConfigBase.sol";

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
        configuration.acrossSpokePoolV3s[OPTIMISM_CHAIN_ID] = ACROSS_SPOKE_POOL_OPTIMISM;
        configuration.acrossSpokePoolV3s[ARBITRUM_CHAIN_ID] = ACROSS_SPOKE_POOL_ARBITRUM;
        configuration.acrossSpokePoolV3s[BNB_CHAIN_ID] = ACROSS_SPOKE_POOL_BNB;

        // ===== DEBRIDGE DLN DESTINATION ADDRESSES =====
        configuration.debridgeDstDln[MAINNET_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[BASE_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[OPTIMISM_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[ARBITRUM_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[BNB_CHAIN_ID] = DEBRIDGE_DLN_DST;

        // ===== PERMIT2 ADDRESSES =====
        configuration.permit2s[MAINNET_CHAIN_ID] = PERMIT2_MAINNET;
        configuration.permit2s[BASE_CHAIN_ID] = PERMIT2_BASE;
        configuration.permit2s[OPTIMISM_CHAIN_ID] = PERMIT2_OPTIMISM;
        configuration.permit2s[ARBITRUM_CHAIN_ID] = PERMIT2_ARBITRUM;
        configuration.permit2s[BNB_CHAIN_ID] = PERMIT2_BNB;

        // ===== MERKL DISTRIBUTOR ADDRESSES =====
        configuration.merklDistributors[MAINNET_CHAIN_ID] = MERKL_DISTRIBUTOR_MAINNET;
        configuration.merklDistributors[BASE_CHAIN_ID] = MERKL_DISTRIBUTOR_BASE;
        configuration.merklDistributors[OPTIMISM_CHAIN_ID] = MERKL_DISTRIBUTOR_OPTIMISM;
        configuration.merklDistributors[ARBITRUM_CHAIN_ID] = MERKL_DISTRIBUTOR_ARBITRUM;
        configuration.merklDistributors[BNB_CHAIN_ID] = MERKL_DISTRIBUTOR_BNB;

        // ===== CRITICAL ROUTER ADDRESSES FOR CORE HOOKS =====
        // These are required for core hook deployments
        configuration.aggregationRouters[MAINNET_CHAIN_ID] = AGGREGATION_ROUTER_MAINNET;
        configuration.aggregationRouters[BASE_CHAIN_ID] = AGGREGATION_ROUTER_BASE;
        configuration.aggregationRouters[OPTIMISM_CHAIN_ID] = AGGREGATION_ROUTER_OPTIMISM;
        configuration.aggregationRouters[ARBITRUM_CHAIN_ID] = AGGREGATION_ROUTER_ARBITRUM;
        configuration.aggregationRouters[BNB_CHAIN_ID] = AGGREGATION_ROUTER_BNB;

        configuration.odosRouters[MAINNET_CHAIN_ID] = ODOS_ROUTER_MAINNET;
        configuration.odosRouters[BASE_CHAIN_ID] = ODOS_ROUTER_BASE;
        configuration.odosRouters[OPTIMISM_CHAIN_ID] = ODOS_ROUTER_OPTIMISM;
        configuration.odosRouters[ARBITRUM_CHAIN_ID] = ODOS_ROUTER_ARBITRUM;
        configuration.odosRouters[BNB_CHAIN_ID] = ODOS_ROUTER_BNB;
    }
}
