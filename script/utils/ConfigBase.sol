// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.30;

import { Constants } from "./Constants.sol";

/// @title ConfigBase
/// @notice Base configuration contract containing common addresses, owner settings, and environment data structure
abstract contract ConfigBase is Constants {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Base environment data structure for common configuration
    struct EnvironmentData {
        address treasury;
        // Core contract dependencies
        mapping(uint64 chainId => address acrossSpokePoolV3) acrossSpokePoolV3s;
        mapping(uint64 chainId => address debridgeDstDln) debridgeDstDln;
        mapping(uint64 chainId => address permit2) permit2s;
        mapping(uint64 chainId => address merklDistributor) merklDistributors;
        mapping(uint64 chainId => address routers) aggregationRouters;
        mapping(uint64 chainId => address odosRouter) odosRouters;
        mapping(uint64 chainId => address nativeToken) nativeTokens;
    }

    EnvironmentData public configuration;

    mapping(uint64 chainId => string chainName) internal chainNames;
    bytes internal saltNamespace;
    string internal constant MNEMONIC = "test test test test test test test test test test test junk";
    string internal constant PRODUCTION_SALT_NAMESPACE = "PROD1.0.0";
    string internal constant STAGING_SALT_NAMESPACE = "STAGING1.0.0";

    address internal constant TEST_DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address internal constant SUPERFORM_TREASURY = 0x0E24b0F342F034446Ec814281AD1a7653cBd85e9; // superform.eth

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets up base configuration including chain names and common addresses
    /// @param env_ Environment (0 = prod, 1 = dev, 2 = staging)
    /// @param saltNamespace_ Salt namespace for deployment (if empty, uses environment-specific default)
    function _setBaseConfiguration(uint256 env_, string memory saltNamespace_) internal {
        // Set salt namespace based on environment with different salts for prod vs staging
        if (bytes(saltNamespace_).length == 0) {
            if (env_ == 0) {
                // Production environment - use production salt
                saltNamespace = bytes(PRODUCTION_SALT_NAMESPACE);
            } else if (env_ == 2) {
                // Staging environment - use staging salt
                saltNamespace = bytes(STAGING_SALT_NAMESPACE);
            } else {
                revert("INVALID_ENVIRONMENT");
            }
        } else {
            saltNamespace = bytes(saltNamespace_);
        }

        // ===== MAINNET CHAIN NAMES =====
        chainNames[MAINNET_CHAIN_ID] = ETHEREUM_KEY;
        chainNames[BASE_CHAIN_ID] = BASE_KEY;
        chainNames[OPTIMISM_CHAIN_ID] = OPTIMISM_KEY;
        chainNames[ARBITRUM_CHAIN_ID] = ARBITRUM_KEY;
        chainNames[BNB_CHAIN_ID] = BNB_KEY;
        chainNames[AVALANCHE_CHAIN_ID] = AVALANCHE_KEY;

        // ===== COMMON CONFIGURATION =====
        if (env_ == 0 || env_ == 2) {
            // Production and Staging environments - use superform.eth treasury
            configuration.treasury = SUPERFORM_TREASURY;
        } else {
            // Test environment
            configuration.treasury = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        }
    }
}
