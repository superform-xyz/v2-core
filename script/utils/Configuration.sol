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
        mapping(uint64 chainId => address acrossSpokePoolV3) acrossSpokePoolV3s;
        mapping(uint64 chainId => address debridgeDstDln) debridgeDstDln;
        mapping(uint64 chainId => address routers) aggregationRouters;
        mapping(uint64 chainId => address odosRouter) odosRouters;
        mapping(uint64 chainId => address okxRouter) okxRouters;
        mapping(uint64 chainId => address nexusFactory) nexusFactories;
        mapping(uint64 chainId => address spectraRouter) spectraRouters;
        mapping(uint64 chainId => address pendleRouter) pendleRouters;
        mapping(uint64 chainId => address polymerProver) polymerProvers;
        SuperPositionData[] superPositions;
    }

    EnvironmentData public configuration;

    mapping(uint64 chainId => string chainName) internal chainNames;
    bytes internal SALT_NAMESPACE;
    string internal constant MNEMONIC = "test test test test test test test test test test test junk";

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
        } else {
            configuration.owner = TEST_DEPLOYER;
            configuration.paymaster = TEST_DEPLOYER;
            configuration.bundler = TEST_DEPLOYER;
            configuration.treasury = TEST_DEPLOYER;
        }

        // chain specific configuration
        configuration.acrossSpokePoolV3s[MAINNET_CHAIN_ID] = ACROSS_SPOKE_POOL_MAINNET;
        configuration.acrossSpokePoolV3s[BASE_CHAIN_ID] = ACROSS_SPOKE_POOL_BASE;
        configuration.acrossSpokePoolV3s[OPTIMISM_CHAIN_ID] = ACROSS_SPOKE_POOL_OPTIMISM;
        configuration.acrossSpokePoolV3s[ARB_SEPOLIA_CHAIN_ID] = ACROSS_SPOKE_POOL_ARB_SEPOLIA;
        configuration.acrossSpokePoolV3s[BASE_SEPOLIA_CHAIN_ID] = ACROSS_SPOKE_POOL_BASE_SEPOLIA;
        configuration.acrossSpokePoolV3s[OP_SEPOLIA_CHAIN_ID] = ACROSS_SPOKE_POOL_OP_SEPOLIA;

        configuration.debridgeDstDln[MAINNET_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[BASE_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[OPTIMISM_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[ARB_SEPOLIA_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[BASE_SEPOLIA_CHAIN_ID] = DEBRIDGE_DLN_DST;
        configuration.debridgeDstDln[OP_SEPOLIA_CHAIN_ID] = DEBRIDGE_DLN_DST;

        configuration.aggregationRouters[MAINNET_CHAIN_ID] = AGGREGATION_ROUTER_MAINNET;
        configuration.aggregationRouters[BASE_CHAIN_ID] = AGGREGATION_ROUTER_BASE;
        configuration.aggregationRouters[OPTIMISM_CHAIN_ID] = AGGREGATION_ROUTER_OPTIMISM;
        configuration.aggregationRouters[ARB_SEPOLIA_CHAIN_ID] = AGGREGATION_ROUTER_ARB_SEPOLIA;
        configuration.aggregationRouters[BASE_SEPOLIA_CHAIN_ID] = AGGREGATION_ROUTER_BASE_SEPOLIA;
        configuration.aggregationRouters[OP_SEPOLIA_CHAIN_ID] = AGGREGATION_ROUTER_OP_SEPOLIA;

        configuration.odosRouters[MAINNET_CHAIN_ID] = ODOS_ROUTER_MAINNET;
        configuration.odosRouters[BASE_CHAIN_ID] = ODOS_ROUTER_BASE;
        configuration.odosRouters[OPTIMISM_CHAIN_ID] = ODOS_ROUTER_OPTIMISM;
        configuration.odosRouters[ARB_SEPOLIA_CHAIN_ID] = ODOS_ROUTER_ARB_SEPOLIA;
        configuration.odosRouters[BASE_SEPOLIA_CHAIN_ID] = ODOS_ROUTER_BASE_SEPOLIA;
        configuration.odosRouters[OP_SEPOLIA_CHAIN_ID] = ODOS_ROUTER_OP_SEPOLIA;

        configuration.okxRouters[MAINNET_CHAIN_ID] = OKX_ROUTER_MAINNET;
        configuration.okxRouters[BASE_CHAIN_ID] = OKX_ROUTER_BASE;
        configuration.okxRouters[OPTIMISM_CHAIN_ID] = OKX_ROUTER_OPTIMISM;
        configuration.okxRouters[ARB_SEPOLIA_CHAIN_ID] = OKX_ROUTER_ARB_SEPOLIA;
        configuration.okxRouters[BASE_SEPOLIA_CHAIN_ID] = OKX_ROUTER_BASE_SEPOLIA;
        configuration.okxRouters[OP_SEPOLIA_CHAIN_ID] = OKX_ROUTER_OP_SEPOLIA;

        configuration.nexusFactories[MAINNET_CHAIN_ID] = NEXUS_FACTORY_MAINNET;
        configuration.nexusFactories[BASE_CHAIN_ID] = NEXUS_FACTORY_BASE;
        configuration.nexusFactories[OPTIMISM_CHAIN_ID] = NEXUS_FACTORY_OPTIMISM;
        configuration.nexusFactories[ARB_SEPOLIA_CHAIN_ID] = NEXUS_FACTORY_ARB_SEPOLIA;
        configuration.nexusFactories[BASE_SEPOLIA_CHAIN_ID] = NEXUS_FACTORY_BASE_SEPOLIA;
        configuration.nexusFactories[OP_SEPOLIA_CHAIN_ID] = NEXUS_FACTORY_OP_SEPOLIA;

        configuration.spectraRouters[MAINNET_CHAIN_ID] = SPECTRA_ROUTER_MAINNET;
        configuration.spectraRouters[BASE_CHAIN_ID] = SPECTRA_ROUTER_BASE;
        configuration.spectraRouters[OPTIMISM_CHAIN_ID] = SPECTRA_ROUTER_OPTIMISM;

        configuration.pendleRouters[MAINNET_CHAIN_ID] = PENDLE_ROUTER_MAINNET;
        configuration.pendleRouters[BASE_CHAIN_ID] = PENDLE_ROUTER_BASE;
        configuration.pendleRouters[OPTIMISM_CHAIN_ID] = PENDLE_ROUTER_OPTIMISM;

        configuration.polymerProvers[MAINNET_CHAIN_ID] = POLYMER_PROVER_MAINNET;
        configuration.polymerProvers[BASE_CHAIN_ID] = POLYMER_PROVER_BASE;
        configuration.polymerProvers[OPTIMISM_CHAIN_ID] = POLYMER_PROVER_OPTIMISM;
        configuration.polymerProvers[ARB_SEPOLIA_CHAIN_ID] = POLYMER_PROVER_ARB_SEPOLIA;
        configuration.polymerProvers[BASE_SEPOLIA_CHAIN_ID] = POLYMER_PROVER_BASE_SEPOLIA;
        configuration.polymerProvers[OP_SEPOLIA_CHAIN_ID] = POLYMER_PROVER_OP_SEPOLIA;
    }
}
