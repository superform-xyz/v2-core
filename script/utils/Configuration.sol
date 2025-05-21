// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import "./Constants.sol";

abstract contract Configuration is Constants {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    error INVALID_CONFIG();

    struct SuperPositionData {
        string name;
        string symbol;
        uint8 decimals;
    }

    struct RolesData {
        bytes32 role;
        address addr;
    }

    struct EnvironmentData {
        address deployer;
        address owner;
        address paymaster;
        address bundler;
        address treasury;
        address validator;
        mapping(uint64 chainId => address acrossSpokePoolV3) acrossSpokePoolV3s;
        mapping(uint64 chainId => address debridgeDstDln) debridgeDstDln;
        mapping(uint64 chainId => address routers) aggregationRouters;
        mapping(uint64 chainId => address odosRouter) odosRouters;
        mapping(uint64 chainId => address okxRouter) okxRouters;
        mapping(uint64 chainId => address nexusFactory) nexusFactories;
        mapping(uint64 chainId => address spectraRouter) spectraRouters;
        mapping(uint64 chainId => address pendleRouter) pendleRouters;
        mapping(uint64 chainId => address polymerProver) polymerProvers;
        mapping(uint64 chainId => address permit2) permit2s;
        SuperPositionData[] superPositions;
    }

    EnvironmentData public configuration;

    mapping(uint64 chainId => string chainName) internal chainNames;
    bytes internal SALT_NAMESPACE;
    string internal MNEMONIC;

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    function _setConfiguration(uint256 env, string memory saltNamespace) internal {
        SALT_NAMESPACE = bytes(saltNamespace);
        chainNames[MAINNET_CHAIN_ID] = ETHEREUM_KEY;
        chainNames[BASE_CHAIN_ID] = BASE_KEY;
        chainNames[OPTIMISM_CHAIN_ID] = OPTIMISM_KEY;
        chainNames[POLYGON_CHAIN_ID] = POLYGON_KEY;
        chainNames[ARBITRUM_CHAIN_ID] = ARBITRUM_KEY;
        chainNames[SEPOLIA_CHAIN_ID] = SEPOLIA_KEY;
        chainNames[ARB_SEPOLIA_CHAIN_ID] = ARB_SEPOLIA_KEY;
        chainNames[BASE_SEPOLIA_CHAIN_ID] = BASE_SEPOLIA_KEY;
        chainNames[OP_SEPOLIA_CHAIN_ID] = OP_SEPOLIA_KEY;

        // common configuration
        if (env == 0) {
            configuration.owner = PROD_MULTISIG;
            configuration.paymaster = PROD_MULTISIG;
            configuration.bundler = PROD_MULTISIG;
            configuration.treasury = PROD_MULTISIG;
            configuration.validator = PROD_MULTISIG;
        } else {
            configuration.owner = TEST_DEPLOYER;
            configuration.paymaster = TEST_DEPLOYER;
            configuration.bundler = TEST_DEPLOYER;
            configuration.treasury = TEST_DEPLOYER;
            configuration.validator = 0xd95f4bc7733d9E94978244C0a27c1815878a59BB;
        }

        // chain specific configuration
        configuration.acrossSpokePoolV3s[MAINNET_CHAIN_ID] = ACROSS_SPOKE_POOL_MAINNET;
        configuration.acrossSpokePoolV3s[BASE_CHAIN_ID] = ACROSS_SPOKE_POOL_BASE;
        configuration.acrossSpokePoolV3s[OPTIMISM_CHAIN_ID] = ACROSS_SPOKE_POOL_OPTIMISM;
        configuration.acrossSpokePoolV3s[SEPOLIA_CHAIN_ID] = ACROSS_SPOKE_POOL_SEPOLIA;
        configuration.acrossSpokePoolV3s[ARB_SEPOLIA_CHAIN_ID] = ACROSS_SPOKE_POOL_ARB_SEPOLIA;
        configuration.acrossSpokePoolV3s[BASE_SEPOLIA_CHAIN_ID] = ACROSS_SPOKE_POOL_BASE_SEPOLIA;
        configuration.acrossSpokePoolV3s[OP_SEPOLIA_CHAIN_ID] = ACROSS_SPOKE_POOL_OP_SEPOLIA;

        configuration.debridgeDstDln[MAINNET_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[BASE_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[OPTIMISM_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[SEPOLIA_CHAIN_ID] = address(0);
        configuration.debridgeDstDln[ARB_SEPOLIA_CHAIN_ID] = address(0);
        configuration.debridgeDstDln[BASE_SEPOLIA_CHAIN_ID] = address(0);
        configuration.debridgeDstDln[OP_SEPOLIA_CHAIN_ID] = address(0);

        configuration.aggregationRouters[MAINNET_CHAIN_ID] = AGGREGATION_ROUTER_MAINNET;
        configuration.aggregationRouters[BASE_CHAIN_ID] = AGGREGATION_ROUTER_BASE;
        configuration.aggregationRouters[OPTIMISM_CHAIN_ID] = AGGREGATION_ROUTER_OPTIMISM;
        configuration.aggregationRouters[SEPOLIA_CHAIN_ID] = AGGREGATION_ROUTER_SEPOLIA;
        configuration.aggregationRouters[ARB_SEPOLIA_CHAIN_ID] = AGGREGATION_ROUTER_ARB_SEPOLIA;
        configuration.aggregationRouters[BASE_SEPOLIA_CHAIN_ID] = AGGREGATION_ROUTER_BASE_SEPOLIA;
        configuration.aggregationRouters[OP_SEPOLIA_CHAIN_ID] = AGGREGATION_ROUTER_OP_SEPOLIA;

        configuration.odosRouters[MAINNET_CHAIN_ID] = ODOS_ROUTER_MAINNET;
        configuration.odosRouters[BASE_CHAIN_ID] = ODOS_ROUTER_BASE;
        configuration.odosRouters[OPTIMISM_CHAIN_ID] = ODOS_ROUTER_OPTIMISM;
        configuration.odosRouters[SEPOLIA_CHAIN_ID] = ODOS_ROUTER_SEPOLIA;
        configuration.odosRouters[ARB_SEPOLIA_CHAIN_ID] = ODOS_ROUTER_ARB_SEPOLIA;
        configuration.odosRouters[BASE_SEPOLIA_CHAIN_ID] = ODOS_ROUTER_BASE_SEPOLIA;
        configuration.odosRouters[OP_SEPOLIA_CHAIN_ID] = ODOS_ROUTER_OP_SEPOLIA;

        configuration.okxRouters[MAINNET_CHAIN_ID] = OKX_ROUTER_MAINNET;
        configuration.okxRouters[BASE_CHAIN_ID] = OKX_ROUTER_BASE;
        configuration.okxRouters[OPTIMISM_CHAIN_ID] = OKX_ROUTER_OPTIMISM;
        configuration.okxRouters[SEPOLIA_CHAIN_ID] = OKX_ROUTER_SEPOLIA;
        configuration.okxRouters[ARB_SEPOLIA_CHAIN_ID] = OKX_ROUTER_ARB_SEPOLIA;
        configuration.okxRouters[BASE_SEPOLIA_CHAIN_ID] = OKX_ROUTER_BASE_SEPOLIA;
        configuration.okxRouters[OP_SEPOLIA_CHAIN_ID] = OKX_ROUTER_OP_SEPOLIA;

        configuration.nexusFactories[MAINNET_CHAIN_ID] = NEXUS_FACTORY_MAINNET;
        configuration.nexusFactories[BASE_CHAIN_ID] = NEXUS_FACTORY_BASE;
        configuration.nexusFactories[OPTIMISM_CHAIN_ID] = NEXUS_FACTORY_OPTIMISM;
        configuration.nexusFactories[SEPOLIA_CHAIN_ID] = NEXUS_FACTORY_SEPOLIA;
        configuration.nexusFactories[ARB_SEPOLIA_CHAIN_ID] = NEXUS_FACTORY_ARB_SEPOLIA;
        configuration.nexusFactories[BASE_SEPOLIA_CHAIN_ID] = NEXUS_FACTORY_BASE_SEPOLIA;
        configuration.nexusFactories[OP_SEPOLIA_CHAIN_ID] = NEXUS_FACTORY_OP_SEPOLIA;

        configuration.spectraRouters[MAINNET_CHAIN_ID] = SPECTRA_ROUTER_MAINNET;
        configuration.spectraRouters[BASE_CHAIN_ID] = SPECTRA_ROUTER_BASE;
        configuration.spectraRouters[OPTIMISM_CHAIN_ID] = SPECTRA_ROUTER_OPTIMISM;
        configuration.spectraRouters[SEPOLIA_CHAIN_ID] = SPECTRA_ROUTER_SEPOLIA;
        configuration.spectraRouters[ARB_SEPOLIA_CHAIN_ID] = SPECTRA_ROUTER_ARB_SEPOLIA;
        configuration.spectraRouters[BASE_SEPOLIA_CHAIN_ID] = SPECTRA_ROUTER_BASE_SEPOLIA;
        configuration.spectraRouters[OP_SEPOLIA_CHAIN_ID] = SPECTRA_ROUTER_OP_SEPOLIA;

        configuration.pendleRouters[MAINNET_CHAIN_ID] = PENDLE_ROUTER_MAINNET;
        configuration.pendleRouters[BASE_CHAIN_ID] = PENDLE_ROUTER_BASE;
        configuration.pendleRouters[OPTIMISM_CHAIN_ID] = PENDLE_ROUTER_OPTIMISM;
        configuration.pendleRouters[SEPOLIA_CHAIN_ID] = PENDLE_ROUTER_SEPOLIA;
        configuration.pendleRouters[ARB_SEPOLIA_CHAIN_ID] = PENDLE_ROUTER_ARB_SEPOLIA;
        configuration.pendleRouters[BASE_SEPOLIA_CHAIN_ID] = PENDLE_ROUTER_BASE_SEPOLIA;
        configuration.pendleRouters[OP_SEPOLIA_CHAIN_ID] = PENDLE_ROUTER_OP_SEPOLIA;

        configuration.polymerProvers[MAINNET_CHAIN_ID] = POLYMER_PROVER_MAINNET;
        configuration.polymerProvers[BASE_CHAIN_ID] = POLYMER_PROVER_BASE;
        configuration.polymerProvers[OPTIMISM_CHAIN_ID] = POLYMER_PROVER_OPTIMISM;
        configuration.polymerProvers[SEPOLIA_CHAIN_ID] = POLYMER_PROVER_SEPOLIA;
        configuration.polymerProvers[ARB_SEPOLIA_CHAIN_ID] = POLYMER_PROVER_ARB_SEPOLIA;
        configuration.polymerProvers[BASE_SEPOLIA_CHAIN_ID] = POLYMER_PROVER_BASE_SEPOLIA;
        configuration.polymerProvers[OP_SEPOLIA_CHAIN_ID] = POLYMER_PROVER_OP_SEPOLIA;

        configuration.permit2s[MAINNET_CHAIN_ID] = PERMIT2_MAINNET;
        configuration.permit2s[BASE_CHAIN_ID] = PERMIT2_BASE;
        configuration.permit2s[OPTIMISM_CHAIN_ID] = PERMIT2_OPTIMISM;
        configuration.permit2s[SEPOLIA_CHAIN_ID] = PERMIT2_SEPOLIA;
        configuration.permit2s[ARB_SEPOLIA_CHAIN_ID] = PERMIT2_ARB_SEPOLIA;
        configuration.permit2s[BASE_SEPOLIA_CHAIN_ID] = PERMIT2_BASE_SEPOLIA;
        configuration.permit2s[OP_SEPOLIA_CHAIN_ID] = PERMIT2_OP_SEPOLIA;
    }
}
