// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.30;

import "./Constants.sol";

/// @title ConfigBase
/// @notice Base configuration contract containing common addresses, owner settings, and environment data structure
abstract contract ConfigBase is Constants {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Base environment data structure for common configuration
    struct EnvironmentData {
        address owner;
        address treasury;
        address validator;
        // Core contract dependencies
        mapping(uint64 chainId => address acrossSpokePoolV3) acrossSpokePoolV3s;
        mapping(uint64 chainId => address debridgeDstDln) debridgeDstDln;
        mapping(uint64 chainId => address nexusFactory) nexusFactories;
        mapping(uint64 chainId => address permit2) permit2s;
        // Periphery contract dependencies
        mapping(uint64 chainId => address polymerProver) polymerProvers;
        // Protocol router dependencies
        mapping(uint64 chainId => address routers) aggregationRouters;
        mapping(uint64 chainId => address odosRouter) odosRouters;
        mapping(uint64 chainId => address okxRouter) okxRouters;
        mapping(uint64 chainId => address spectraRouter) spectraRouters;
        mapping(uint64 chainId => address pendleRouter) pendleRouters;
    }

    EnvironmentData public configuration;

    mapping(uint64 chainId => string chainName) internal chainNames;
    bytes internal SALT_NAMESPACE;
    string internal constant MNEMONIC = "test test test test test test test test test test test junk";
    string internal constant PRODUCTION_SALT_NAMESPACE = "DEPLOYPROD1.0.0";
    string internal constant STAGING_SALT_NAMESPACE = "DEPLOYSTAGING1.0.0";

    address internal constant TEST_DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address internal constant SUPERFORM_TREASURY = 0x0E24b0F342F034446Ec814281AD1a7653cBd85e9; // superform.eth

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets up base configuration including chain names and common addresses
    /// @param env Environment (0 = prod, 1 = dev, 2 = staging)
    /// @param saltNamespace Salt namespace for deployment (if empty, uses environment-specific default)
    function _setBaseConfiguration(uint256 env, string memory saltNamespace) internal {
        // Set salt namespace based on environment with different salts for prod vs staging
        if (bytes(saltNamespace).length == 0) {
            if (env == 0) {
                // Production environment - use production salt
                SALT_NAMESPACE = bytes(PRODUCTION_SALT_NAMESPACE);
            } else if (env == 2) {
                // Staging environment - use staging salt
                SALT_NAMESPACE = bytes(STAGING_SALT_NAMESPACE);
            } else {
                revert("INVALID_ENVIRONMENT");
            }
        } else {
            SALT_NAMESPACE = bytes(saltNamespace);
        }

        // ===== MAINNET CHAIN NAMES =====
        chainNames[MAINNET_CHAIN_ID] = ETHEREUM_KEY;
        chainNames[BASE_CHAIN_ID] = BASE_KEY;
        chainNames[OPTIMISM_CHAIN_ID] = OPTIMISM_KEY;
        chainNames[POLYGON_CHAIN_ID] = POLYGON_KEY;
        chainNames[ARBITRUM_CHAIN_ID] = ARBITRUM_KEY;
        chainNames[BNB_CHAIN_ID] = BNB_KEY;

        // ===== COMMON CONFIGURATION =====
        if (env == 0 || env == 2) {
            // Production and Staging environments - use superform.eth treasury
            configuration.owner = 0x22BC97cFac64D6d9BCaDF5dC36e4D01Db9e929c5;
            configuration.treasury = SUPERFORM_TREASURY; // Updated to superform.eth
            configuration.validator = 0x22BC97cFac64D6d9BCaDF5dC36e4D01Db9e929c5;
        } else {
            // Test environment
            configuration.owner = TEST_DEPLOYER;
            configuration.treasury = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
            configuration.validator = 0xd95f4bc7733d9E94978244C0a27c1815878a59BB;
        }
    }
}
