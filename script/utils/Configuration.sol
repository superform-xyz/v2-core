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
        mapping(uint64 chainId => address acrossSpokePoolV3) acrossSpokePoolV3s;
        mapping(uint64 chainId => address debridgeGate) debridgeGates;
        mapping(uint64 chainId => address odosRouter) odosRouters;
        SuperPositionData[] superPositions;
        RolesData[] externalRoles;
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
        configuration.deployer = SUPER_DEPLOYER;

        if (env == 0) {
            configuration.owner = PROD_MULTISIG;
            configuration.paymaster = PROD_MULTISIG;
            configuration.bundler = PROD_MULTISIG;
        } else {
            configuration.owner = TEST_DEPLOYER;
            configuration.paymaster = TEST_DEPLOYER;
            configuration.bundler = TEST_DEPLOYER;
        }

        // chain specific configuration
        configuration.acrossSpokePoolV3s[MAINNET_CHAIN_ID] = ACROSS_SPOKE_POOL_MAINNET;
        configuration.acrossSpokePoolV3s[BASE_CHAIN_ID] = ACROSS_SPOKE_POOL_BASE;
        configuration.acrossSpokePoolV3s[OPTIMISM_CHAIN_ID] = ACROSS_SPOKE_POOL_OPTIMISM;
        configuration.acrossSpokePoolV3s[ARB_SEPOLIA_CHAIN_ID] = ACROSS_SPOKE_POOL_ARB_SEPOLIA;
        configuration.acrossSpokePoolV3s[BASE_SEPOLIA_CHAIN_ID] = ACROSS_SPOKE_POOL_BASE_SEPOLIA;
        configuration.acrossSpokePoolV3s[OP_SEPOLIA_CHAIN_ID] = ACROSS_SPOKE_POOL_OP_SEPOLIA;

        configuration.debridgeGates[MAINNET_CHAIN_ID] = DEBRIDGE_GATE_MAINNET;
        configuration.debridgeGates[BASE_CHAIN_ID] = DEBRIDGE_GATE_BASE;
        configuration.debridgeGates[OPTIMISM_CHAIN_ID] = DEBRIDGE_GATE_OPTIMISM;
        configuration.debridgeGates[ARB_SEPOLIA_CHAIN_ID] = DEBRIDGE_GATE_ARB_SEPOLIA;
        configuration.debridgeGates[BASE_SEPOLIA_CHAIN_ID] = DEBRIDGE_GATE_BASE_SEPOLIA;
        configuration.debridgeGates[OP_SEPOLIA_CHAIN_ID] = DEBRIDGE_GATE_OP_SEPOLIA;

        configuration.odosRouters[MAINNET_CHAIN_ID] = ODOS_ROUTER_MAINNET;
        configuration.odosRouters[BASE_CHAIN_ID] = ODOS_ROUTER_BASE;
        configuration.odosRouters[OPTIMISM_CHAIN_ID] = ODOS_ROUTER_OPTIMISM;
        configuration.odosRouters[ARB_SEPOLIA_CHAIN_ID] = ODOS_ROUTER_ARB_SEPOLIA;
        configuration.odosRouters[BASE_SEPOLIA_CHAIN_ID] = ODOS_ROUTER_BASE_SEPOLIA;
        configuration.odosRouters[OP_SEPOLIA_CHAIN_ID] = ODOS_ROUTER_OP_SEPOLIA;
    }
}
