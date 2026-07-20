// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.30;

import { ConfigStargateOFTs } from "./ConfigStargateOFTs.sol";

/// @title ConfigCore
/// @notice Standalone core configuration contract for core contract deployments
/// @dev Handles bridge, router, oracle, token, and shared dependency configuration
abstract contract ConfigCore is ConfigStargateOFTs {
    /*//////////////////////////////////////////////////////////////
                            CORE CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets up core contract dependencies
    /// @dev Configures addresses required for core contract deployment and operation
    /// @param env Environment (0 = prod, 1 = dev, 2 = staging)
    function _setCoreConfiguration(uint256 env) internal {
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
        configuration.acrossSpokePoolV3s[HYPEREVM_CHAIN_ID] = ACROSS_SPOKE_POOL_HYPEREVM;
        configuration.acrossSpokePoolV3s[FLARE_CHAIN_ID] = address(0); // Not deployed yet
        configuration.acrossSpokePoolV3s[STABLE_CHAIN_ID] = address(0); // Not deployed yet

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
        configuration.debridgeSrcDln[HYPEREVM_CHAIN_ID] = DEBRIDGE_DLN_SRC;
        configuration.debridgeSrcDln[FLARE_CHAIN_ID] = address(0); // Not deployed yet
        configuration.debridgeSrcDln[STABLE_CHAIN_ID] = address(0); // Not deployed yet

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
        configuration.debridgeDstDln[HYPEREVM_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[FLARE_CHAIN_ID] = address(0); // Not deployed yet
        configuration.debridgeDstDln[STABLE_CHAIN_ID] = address(0); // Not deployed yet

        // ===== LAYERZERO V2 ENDPOINT ADDRESSES =====
        // Standard EndpointV2 address on most chains
        configuration.lzEndpointV2s[MAINNET_CHAIN_ID] = LZ_ENDPOINT_V2;
        configuration.lzEndpointV2s[BASE_CHAIN_ID] = LZ_ENDPOINT_V2;
        configuration.lzEndpointV2s[BNB_CHAIN_ID] = LZ_ENDPOINT_V2;
        configuration.lzEndpointV2s[ARBITRUM_CHAIN_ID] = LZ_ENDPOINT_V2;
        configuration.lzEndpointV2s[OPTIMISM_CHAIN_ID] = LZ_ENDPOINT_V2;
        configuration.lzEndpointV2s[POLYGON_CHAIN_ID] = LZ_ENDPOINT_V2;
        configuration.lzEndpointV2s[LINEA_CHAIN_ID] = LZ_ENDPOINT_V2;
        configuration.lzEndpointV2s[AVALANCHE_CHAIN_ID] = LZ_ENDPOINT_V2;
        configuration.lzEndpointV2s[GNOSIS_CHAIN_ID] = LZ_ENDPOINT_V2;
        configuration.lzEndpointV2s[FLARE_CHAIN_ID] = LZ_ENDPOINT_V2;
        // Newer EndpointV2 deployment address
        configuration.lzEndpointV2s[UNICHAIN_CHAIN_ID] = LZ_ENDPOINT_V2_ALT;
        configuration.lzEndpointV2s[BERACHAIN_CHAIN_ID] = LZ_ENDPOINT_V2_ALT;
        configuration.lzEndpointV2s[SONIC_CHAIN_ID] = LZ_ENDPOINT_V2_ALT;
        configuration.lzEndpointV2s[WORLDCHAIN_CHAIN_ID] = LZ_ENDPOINT_V2_ALT;
        configuration.lzEndpointV2s[STABLE_CHAIN_ID] = LZ_ENDPOINT_V2_ALT;
        // HyperEVM has its own EndpointV2 address
        configuration.lzEndpointV2s[HYPEREVM_CHAIN_ID] = LZ_ENDPOINT_V2_HYPEREVM;

        // ===== STARGATE V2 TOKEN MESSAGING ADDRESSES =====
        configuration.stargateTokenMessagings[MAINNET_CHAIN_ID] = 0x6d6620eFa72948C5f68A3C8646d58C00d3f4A980;
        configuration.stargateTokenMessagings[BASE_CHAIN_ID] = 0x5634c4a5FEd09819E3c46D86A965Dd9447d86e47;
        configuration.stargateTokenMessagings[BNB_CHAIN_ID] = 0x6E3d884C96d640526F273C61dfcF08915eBd7e2B;
        configuration.stargateTokenMessagings[ARBITRUM_CHAIN_ID] = 0x19cFCE47eD54a88614648DC3f19A5980097007dD;
        configuration.stargateTokenMessagings[OPTIMISM_CHAIN_ID] = 0xF1fCb4CBd57B67d683972A59B6a7b1e2E8Bf27E6;
        configuration.stargateTokenMessagings[POLYGON_CHAIN_ID] = 0x6CE9bf8CDaB780416AD1fd87b318A077D2f50EaC;
        configuration.stargateTokenMessagings[AVALANCHE_CHAIN_ID] = 0x17E450Be3Ba9557F2378E20d64AD417E59Ef9A34;
        configuration.stargateTokenMessagings[LINEA_CHAIN_ID] = 0x5f688F563Dc16590e570f97b542FA87931AF2feD;
        configuration.stargateTokenMessagings[GNOSIS_CHAIN_ID] = 0xAf368c91793CB22739386DFCbBb2F1A9e4bCBeBf;
        configuration.stargateTokenMessagings[FLARE_CHAIN_ID] = 0x45d417612e177672958dC0537C45a8f8d754Ac2E;
        configuration.stargateTokenMessagings[UNICHAIN_CHAIN_ID] = 0xB1EeAD6959cb5bB9B20417d6689922523B2B86C3;
        configuration.stargateTokenMessagings[BERACHAIN_CHAIN_ID] = 0xAf5191B0De278C7286d6C7CC6ab6BB8A73bA2Cd6;
        configuration.stargateTokenMessagings[SONIC_CHAIN_ID] = 0x2086f755A6d9254045C257ea3d382ef854849B0f;
        configuration.stargateTokenMessagings[STABLE_CHAIN_ID] = 0xd027aFcc69ffA2bCB288BA68da6B71EC90d7B1d2;
        configuration.stargateTokenMessagings[WORLDCHAIN_CHAIN_ID] = address(0); // Not available yet

        // ===== STARGATE ALLOWED OFTs (non-pool OFT contracts that use LZ compose) =====
        _setStargateOFTConfiguration();

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
        configuration.permit2s[HYPEREVM_CHAIN_ID] = PERMIT2;
        configuration.permit2s[FLARE_CHAIN_ID] = PERMIT2;
        configuration.permit2s[STABLE_CHAIN_ID] = PERMIT2;

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
        configuration.merklDistributors[HYPEREVM_CHAIN_ID] = MERKL_DISTRIBUTOR;
        configuration.merklDistributors[FLARE_CHAIN_ID] = address(0); // Not deployed
        configuration.merklDistributors[STABLE_CHAIN_ID] = MERKL_DISTRIBUTOR;

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
        configuration.aggregationRouters[HYPEREVM_CHAIN_ID] = address(0); // Not deployed
        configuration.aggregationRouters[FLARE_CHAIN_ID] = address(0); // Not deployed
        configuration.aggregationRouters[STABLE_CHAIN_ID] = address(0); // Not deployed

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
        configuration.odosRouters[HYPEREVM_CHAIN_ID] = address(0); // Not deployed
        configuration.odosRouters[FLARE_CHAIN_ID] = address(0); // Not deployed
        configuration.odosRouters[STABLE_CHAIN_ID] = address(0); // Not deployed

        // ===== ODOS V3 ROUTER ADDRESSES =====
        // Same CREATE2 address on all EVM chains where deployed
        configuration.odosRouterV3s[MAINNET_CHAIN_ID] = ODOS_ROUTER_V3;
        configuration.odosRouterV3s[BASE_CHAIN_ID] = ODOS_ROUTER_V3;
        configuration.odosRouterV3s[BNB_CHAIN_ID] = ODOS_ROUTER_V3;
        configuration.odosRouterV3s[ARBITRUM_CHAIN_ID] = ODOS_ROUTER_V3;
        configuration.odosRouterV3s[OPTIMISM_CHAIN_ID] = ODOS_ROUTER_V3;
        configuration.odosRouterV3s[POLYGON_CHAIN_ID] = ODOS_ROUTER_V3;
        configuration.odosRouterV3s[UNICHAIN_CHAIN_ID] = address(0); // Not deployed
        configuration.odosRouterV3s[LINEA_CHAIN_ID] = ODOS_ROUTER_V3;
        configuration.odosRouterV3s[AVALANCHE_CHAIN_ID] = ODOS_ROUTER_V3;
        configuration.odosRouterV3s[BERACHAIN_CHAIN_ID] = address(0); // Not deployed
        configuration.odosRouterV3s[SONIC_CHAIN_ID] = ODOS_ROUTER_V3;
        configuration.odosRouterV3s[GNOSIS_CHAIN_ID] = address(0); // Not deployed
        configuration.odosRouterV3s[WORLDCHAIN_CHAIN_ID] = address(0); // Not deployed
        configuration.odosRouterV3s[HYPEREVM_CHAIN_ID] = address(0); // Not deployed
        configuration.odosRouterV3s[FLARE_CHAIN_ID] = address(0); // Not deployed

        // ===== KYBERSWAP ROUTER AND SCALE HELPER ADDRESSES =====
        // Same address across all supported chains
        configuration.kyberSwapRouters[MAINNET_CHAIN_ID] = KYBER_ROUTER;
        configuration.kyberSwapRouters[BASE_CHAIN_ID] = KYBER_ROUTER;
        configuration.kyberSwapRouters[BNB_CHAIN_ID] = KYBER_ROUTER;
        configuration.kyberSwapRouters[ARBITRUM_CHAIN_ID] = KYBER_ROUTER;
        configuration.kyberSwapRouters[OPTIMISM_CHAIN_ID] = KYBER_ROUTER;
        configuration.kyberSwapRouters[POLYGON_CHAIN_ID] = KYBER_ROUTER;
        configuration.kyberSwapRouters[UNICHAIN_CHAIN_ID] = KYBER_ROUTER;
        configuration.kyberSwapRouters[LINEA_CHAIN_ID] = KYBER_ROUTER;
        configuration.kyberSwapRouters[AVALANCHE_CHAIN_ID] = KYBER_ROUTER;
        configuration.kyberSwapRouters[BERACHAIN_CHAIN_ID] = KYBER_ROUTER;
        configuration.kyberSwapRouters[SONIC_CHAIN_ID] = KYBER_ROUTER;
        configuration.kyberSwapRouters[GNOSIS_CHAIN_ID] = address(0); // Not deployed
        configuration.kyberSwapRouters[WORLDCHAIN_CHAIN_ID] = address(0); // Not deployed
        configuration.kyberSwapRouters[HYPEREVM_CHAIN_ID] = KYBER_ROUTER;
        configuration.kyberSwapRouters[FLARE_CHAIN_ID] = address(0); // Not deployed
        configuration.kyberSwapRouters[STABLE_CHAIN_ID] = address(0); // Not deployed

        configuration.kyberSwapScaleHelpers[MAINNET_CHAIN_ID] = KYBER_SCALE_HELPER;
        configuration.kyberSwapScaleHelpers[BASE_CHAIN_ID] = KYBER_SCALE_HELPER;
        configuration.kyberSwapScaleHelpers[BNB_CHAIN_ID] = KYBER_SCALE_HELPER;
        configuration.kyberSwapScaleHelpers[ARBITRUM_CHAIN_ID] = KYBER_SCALE_HELPER;
        configuration.kyberSwapScaleHelpers[OPTIMISM_CHAIN_ID] = KYBER_SCALE_HELPER;
        configuration.kyberSwapScaleHelpers[POLYGON_CHAIN_ID] = KYBER_SCALE_HELPER;
        configuration.kyberSwapScaleHelpers[UNICHAIN_CHAIN_ID] = KYBER_SCALE_HELPER;
        configuration.kyberSwapScaleHelpers[LINEA_CHAIN_ID] = KYBER_SCALE_HELPER;
        configuration.kyberSwapScaleHelpers[AVALANCHE_CHAIN_ID] = KYBER_SCALE_HELPER;
        configuration.kyberSwapScaleHelpers[BERACHAIN_CHAIN_ID] = KYBER_SCALE_HELPER;
        configuration.kyberSwapScaleHelpers[SONIC_CHAIN_ID] = KYBER_SCALE_HELPER;
        configuration.kyberSwapScaleHelpers[GNOSIS_CHAIN_ID] = address(0); // Not deployed
        configuration.kyberSwapScaleHelpers[WORLDCHAIN_CHAIN_ID] = address(0); // Not deployed
        configuration.kyberSwapScaleHelpers[HYPEREVM_CHAIN_ID] = KYBER_SCALE_HELPER;
        configuration.kyberSwapScaleHelpers[FLARE_CHAIN_ID] = address(0); // Not deployed
        configuration.kyberSwapScaleHelpers[STABLE_CHAIN_ID] = address(0); // Not deployed

        // ===== OPENOCEAN SPARKDEX V4 ADDRESSES =====
        // OpenOcean V4 SparkDexV4 routing is used only on Flare.
        configuration.openOceanRouters[FLARE_CHAIN_ID] = OPENOCEAN_ROUTER;
        configuration.openOceanReferrers[FLARE_CHAIN_ID] = OPENOCEAN_REFERRER_FLARE;

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
        configuration.pendleRouters[BERACHAIN_CHAIN_ID] = PENDLE_ROUTER_BERACHAIN;
        configuration.pendleRouters[SONIC_CHAIN_ID] = PENDLE_ROUTER_SONIC;
        configuration.pendleRouters[GNOSIS_CHAIN_ID] = address(0); // Not deployed
        configuration.pendleRouters[WORLDCHAIN_CHAIN_ID] = address(0); // Not deployed
        configuration.pendleRouters[HYPEREVM_CHAIN_ID] = PENDLE_ROUTER_HYPEREVM;
        configuration.pendleRouters[FLARE_CHAIN_ID] = address(0); // Not deployed
        configuration.pendleRouters[STABLE_CHAIN_ID] = address(0); // Not deployed

        // ===== PENDLE PT AMORTIZED ORACLE ADDRESSES (V1) =====
        // NOTE: Set to address(0) - oracles are deployed via DeployV2Core and config is updated dynamically
        // Legacy addresses (for reference):
        // - Staging: 0xE31FD1d26A52B4a958651a8E751e9362B3880524
        // - Production: 0xD64089698f82cbCD91ba5e0422aDFa81D247eB62
        configuration.pendlePTAmortizedOracles[MAINNET_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOracles[BASE_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOracles[HYPEREVM_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOracles[BNB_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOracles[ARBITRUM_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOracles[OPTIMISM_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOracles[POLYGON_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOracles[UNICHAIN_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOracles[LINEA_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOracles[AVALANCHE_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOracles[BERACHAIN_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOracles[SONIC_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOracles[GNOSIS_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOracles[WORLDCHAIN_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOracles[FLARE_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOracles[STABLE_CHAIN_ID] = address(0);

        // ===== PENDLE PT AMORTIZED ORACLE V2 ADDRESSES =====
        // NOTE: Set to address(0) - oracles are deployed via DeployV2Core and config is updated dynamically
        // Legacy addresses (for reference):
        // - Staging: 0x1F32A55b20Ee7bA0bC083671c7723dBA1608D66e
        // - Production: 0x2185B40476510Ad27d17AF90889CE91BE9282A04
        configuration.pendlePTAmortizedOraclesV2[MAINNET_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOraclesV2[BASE_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOraclesV2[HYPEREVM_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOraclesV2[BNB_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOraclesV2[ARBITRUM_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOraclesV2[OPTIMISM_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOraclesV2[POLYGON_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOraclesV2[UNICHAIN_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOraclesV2[LINEA_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOraclesV2[AVALANCHE_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOraclesV2[BERACHAIN_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOraclesV2[SONIC_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOraclesV2[GNOSIS_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOraclesV2[WORLDCHAIN_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOraclesV2[FLARE_CHAIN_ID] = address(0);
        configuration.pendlePTAmortizedOraclesV2[STABLE_CHAIN_ID] = address(0);

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
        configuration.nativeTokens[HYPEREVM_CHAIN_ID] = NATIVE_TOKEN_DEFAULT;
        configuration.nativeTokens[FLARE_CHAIN_ID] = NATIVE_TOKEN_DEFAULT;
        configuration.nativeTokens[STABLE_CHAIN_ID] = NATIVE_TOKEN_DEFAULT;

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
        configuration.uniswapV4PoolManagers[HYPEREVM_CHAIN_ID] = address(0); // Not deployed
        configuration.uniswapV4PoolManagers[FLARE_CHAIN_ID] = address(0); // Not deployed
        configuration.uniswapV4PoolManagers[STABLE_CHAIN_ID] = address(0); // Not deployed

        // ===== UNISWAP V3 SWAP ROUTER ADDRESSES =====
        // Using SwapRouter (exactInputSingle with deadline in struct)
        configuration.uniswapV3SwapRouters[MAINNET_CHAIN_ID] = address(0);
        configuration.uniswapV3SwapRouters[BASE_CHAIN_ID] = address(0);
        configuration.uniswapV3SwapRouters[BNB_CHAIN_ID] = address(0);
        configuration.uniswapV3SwapRouters[ARBITRUM_CHAIN_ID] = address(0);
        configuration.uniswapV3SwapRouters[OPTIMISM_CHAIN_ID] = address(0);
        configuration.uniswapV3SwapRouters[POLYGON_CHAIN_ID] = address(0);
        configuration.uniswapV3SwapRouters[UNICHAIN_CHAIN_ID] = address(0);
        configuration.uniswapV3SwapRouters[LINEA_CHAIN_ID] = address(0);
        configuration.uniswapV3SwapRouters[AVALANCHE_CHAIN_ID] = address(0);
        configuration.uniswapV3SwapRouters[BERACHAIN_CHAIN_ID] = address(0);
        configuration.uniswapV3SwapRouters[SONIC_CHAIN_ID] = address(0);
        configuration.uniswapV3SwapRouters[GNOSIS_CHAIN_ID] = address(0);
        configuration.uniswapV3SwapRouters[WORLDCHAIN_CHAIN_ID] = address(0);
        configuration.uniswapV3SwapRouters[HYPEREVM_CHAIN_ID] = 0x1EbDFC75FfE3ba3de61E7138a3E8706aC841Af9B;
        configuration.uniswapV3SwapRouters[FLARE_CHAIN_ID] = address(0); // Not deployed
        configuration.uniswapV3SwapRouters[STABLE_CHAIN_ID] = address(0); // Not deployed

        // ===== UNISWAP V3 SWAP ROUTER 02 ADDRESSES =====
        // Using SwapRouter02 (exactInputSingle WITHOUT deadline in struct)
        configuration.uniswapV3SwapRouter02s[MAINNET_CHAIN_ID] = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
        configuration.uniswapV3SwapRouter02s[BASE_CHAIN_ID] = 0x2626664c2603336E57B271c5C0b26F421741e481;
        configuration.uniswapV3SwapRouter02s[BNB_CHAIN_ID] = 0xB971eF87ede563556b2ED4b1C0b0019111Dd85d2;
        configuration.uniswapV3SwapRouter02s[ARBITRUM_CHAIN_ID] = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
        configuration.uniswapV3SwapRouter02s[OPTIMISM_CHAIN_ID] = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
        configuration.uniswapV3SwapRouter02s[POLYGON_CHAIN_ID] = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
        configuration.uniswapV3SwapRouter02s[UNICHAIN_CHAIN_ID] = 0x73855d06DE49d0fe4A9c42636Ba96c62da12FF9C;
        configuration.uniswapV3SwapRouter02s[LINEA_CHAIN_ID] = 0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a;
        configuration.uniswapV3SwapRouter02s[AVALANCHE_CHAIN_ID] = 0xbb00FF08d01D300023C629E8fFfFcb65A5a578cE;
        configuration.uniswapV3SwapRouter02s[BERACHAIN_CHAIN_ID] = address(0); // Not deployed
        configuration.uniswapV3SwapRouter02s[SONIC_CHAIN_ID] = address(0); // Not confirmed
        configuration.uniswapV3SwapRouter02s[GNOSIS_CHAIN_ID] = address(0); // Not confirmed
        configuration.uniswapV3SwapRouter02s[WORLDCHAIN_CHAIN_ID] = 0x091AD9e2e6e5eD44c1c66dB50e49A601F9f36cF6;
        configuration.uniswapV3SwapRouter02s[HYPEREVM_CHAIN_ID] = address(0); // Uses HyperSwap v1 router
        configuration.uniswapV3SwapRouter02s[FLARE_CHAIN_ID] = address(0); // Not deployed
        configuration.uniswapV3SwapRouter02s[STABLE_CHAIN_ID] = 0x32eaf9B5d5F2CD7361c5012890C943D7de84C22a;

        // ===== UNISWAP V2 SWAP ROUTER ADDRESSES =====
        // SparkDex on Flare is a Uniswap V2 fork
        configuration.uniswapV2SwapRouters[MAINNET_CHAIN_ID] = address(0);
        configuration.uniswapV2SwapRouters[BASE_CHAIN_ID] = address(0);
        configuration.uniswapV2SwapRouters[BNB_CHAIN_ID] = address(0);
        configuration.uniswapV2SwapRouters[ARBITRUM_CHAIN_ID] = address(0);
        configuration.uniswapV2SwapRouters[OPTIMISM_CHAIN_ID] = address(0);
        configuration.uniswapV2SwapRouters[POLYGON_CHAIN_ID] = address(0);
        configuration.uniswapV2SwapRouters[UNICHAIN_CHAIN_ID] = address(0);
        configuration.uniswapV2SwapRouters[LINEA_CHAIN_ID] = address(0);
        configuration.uniswapV2SwapRouters[AVALANCHE_CHAIN_ID] = address(0);
        configuration.uniswapV2SwapRouters[BERACHAIN_CHAIN_ID] = address(0);
        configuration.uniswapV2SwapRouters[SONIC_CHAIN_ID] = address(0);
        configuration.uniswapV2SwapRouters[GNOSIS_CHAIN_ID] = address(0);
        configuration.uniswapV2SwapRouters[WORLDCHAIN_CHAIN_ID] = address(0);
        configuration.uniswapV2SwapRouters[HYPEREVM_CHAIN_ID] = address(0);
        configuration.uniswapV2SwapRouters[FLARE_CHAIN_ID] = SPARKDEX_V2_ROUTER_FLARE;
        configuration.uniswapV2SwapRouters[STABLE_CHAIN_ID] = address(0); // Not deployed

        // ===== SPARK PSM3 ADDRESSES =====
        // PSM3 is only deployed on Base
        configuration.sparkPsm3s[MAINNET_CHAIN_ID] = address(0);
        configuration.sparkPsm3s[BASE_CHAIN_ID] = 0x1601843c5E9bC251A3272907010AFa41Fa18347E;
        configuration.sparkPsm3s[BNB_CHAIN_ID] = address(0);
        configuration.sparkPsm3s[ARBITRUM_CHAIN_ID] = address(0);
        configuration.sparkPsm3s[OPTIMISM_CHAIN_ID] = address(0);
        configuration.sparkPsm3s[POLYGON_CHAIN_ID] = address(0);
        configuration.sparkPsm3s[UNICHAIN_CHAIN_ID] = address(0);
        configuration.sparkPsm3s[LINEA_CHAIN_ID] = address(0);
        configuration.sparkPsm3s[AVALANCHE_CHAIN_ID] = address(0);
        configuration.sparkPsm3s[BERACHAIN_CHAIN_ID] = address(0);
        configuration.sparkPsm3s[SONIC_CHAIN_ID] = address(0);
        configuration.sparkPsm3s[GNOSIS_CHAIN_ID] = address(0);
        configuration.sparkPsm3s[WORLDCHAIN_CHAIN_ID] = address(0);
        configuration.sparkPsm3s[HYPEREVM_CHAIN_ID] = address(0);
        configuration.sparkPsm3s[FLARE_CHAIN_ID] = address(0);
        configuration.sparkPsm3s[STABLE_CHAIN_ID] = address(0);

        // ===== DETH FOUNDATION ADDRESS =====
        // DETH async redemption routing: the FOUNDATION address receives ERC-721 NFT receipts
        // on behalf of the strategy (SuperVaultStrategy lacks onERC721Received).
        configuration.dethFoundation = 0x97b5e4a707A4D5AB4A58b2c93bc8d249a63Ff153;
    }
}
