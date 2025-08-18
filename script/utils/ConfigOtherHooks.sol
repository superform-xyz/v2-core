// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.30;

import { ConfigBase } from "./ConfigBase.sol";

/// @title ConfigOtherHooks
/// @notice Standalone protocol-specific router configuration for hooks
/// @dev Handles router addresses for 1inch, ODOS, OKX, Spectra, Pendle and other protocol integrations
abstract contract ConfigOtherHooks is ConfigBase {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Protocol router dependencies for other hooks
    struct OtherHooksData {
        mapping(uint64 chainId => address okxRouter) okxRouters;
        mapping(uint64 chainId => address spectraRouter) spectraRouters;
        mapping(uint64 chainId => address pendleRouter) pendleRouters;
    }

    OtherHooksData internal otherHooksConfiguration;

    /*//////////////////////////////////////////////////////////////
                              GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get OKX router address for a specific chain
    function getOkxRouter(uint64 chainId) external view returns (address) {
        return otherHooksConfiguration.okxRouters[chainId];
    }

    /// @notice Get Spectra router address for a specific chain
    function getSpectraRouter(uint64 chainId) external view returns (address) {
        return otherHooksConfiguration.spectraRouters[chainId];
    }

    /// @notice Get Pendle router address for a specific chain
    function getPendleRouter(uint64 chainId) external view returns (address) {
        return otherHooksConfiguration.pendleRouters[chainId];
    }

    /*//////////////////////////////////////////////////////////////
                        PROTOCOL ROUTER CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets up protocol-specific router addresses for hooks
    /// @dev Configures router addresses required for protocol integration hooks
    function _setOtherHooksConfiguration() internal {
        // ===== OKX ROUTER ADDRESSES =====
        otherHooksConfiguration.okxRouters[MAINNET_CHAIN_ID] = OKX_ROUTER_MAINNET;
        otherHooksConfiguration.okxRouters[BASE_CHAIN_ID] = OKX_ROUTER_BASE;
        otherHooksConfiguration.okxRouters[OPTIMISM_CHAIN_ID] = OKX_ROUTER_OPTIMISM;
        otherHooksConfiguration.okxRouters[ARBITRUM_CHAIN_ID] = address(0); // TODO: Add Arbitrum OKX router address
        otherHooksConfiguration.okxRouters[BNB_CHAIN_ID] = address(0); // TODO: Add BNB OKX router address

        // ===== SPECTRA ROUTER ADDRESSES =====
        otherHooksConfiguration.spectraRouters[MAINNET_CHAIN_ID] = SPECTRA_ROUTER_MAINNET;
        otherHooksConfiguration.spectraRouters[BASE_CHAIN_ID] = SPECTRA_ROUTER_BASE;
        otherHooksConfiguration.spectraRouters[OPTIMISM_CHAIN_ID] = SPECTRA_ROUTER_OPTIMISM;
        otherHooksConfiguration.spectraRouters[ARBITRUM_CHAIN_ID] = address(0); // TODO: Add Arbitrum Spectra router
            // address
        otherHooksConfiguration.spectraRouters[BNB_CHAIN_ID] = address(0); // TODO: Add BNB Spectra router address

        // ===== PENDLE ROUTER ADDRESSES =====
        otherHooksConfiguration.pendleRouters[MAINNET_CHAIN_ID] = PENDLE_ROUTER_MAINNET;
        otherHooksConfiguration.pendleRouters[BASE_CHAIN_ID] = PENDLE_ROUTER_BASE;
        otherHooksConfiguration.pendleRouters[OPTIMISM_CHAIN_ID] = PENDLE_ROUTER_OPTIMISM;
        otherHooksConfiguration.pendleRouters[ARBITRUM_CHAIN_ID] = address(0); // TODO: Add Arbitrum Pendle router
            // address
        otherHooksConfiguration.pendleRouters[BNB_CHAIN_ID] = address(0); // TODO: Add BNB Pendle router address
    }
}
