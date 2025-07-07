// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import "./ConfigBase.sol";

/// @title ConfigOtherHooks
/// @notice Standalone protocol-specific router configuration for hooks
/// @dev Handles router addresses for 1inch, ODOS, OKX, Spectra, Pendle and other protocol integrations
abstract contract ConfigOtherHooks is ConfigBase {
    /*//////////////////////////////////////////////////////////////
                        PROTOCOL ROUTER CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets up protocol-specific router addresses for hooks
    /// @dev Configures router addresses required for protocol integration hooks
    function _setOtherHooksConfiguration() internal {

        // ===== OKX ROUTER ADDRESSES =====
        configuration.okxRouters[MAINNET_CHAIN_ID] = OKX_ROUTER_MAINNET;
        configuration.okxRouters[BASE_CHAIN_ID] = OKX_ROUTER_BASE;
        configuration.okxRouters[OPTIMISM_CHAIN_ID] = OKX_ROUTER_OPTIMISM;
        configuration.okxRouters[ARBITRUM_CHAIN_ID] = address(0); // TODO: Add Arbitrum OKX router address
        configuration.okxRouters[BNB_CHAIN_ID] = address(0); // TODO: Add BNB OKX router address

        // ===== SPECTRA ROUTER ADDRESSES =====
        configuration.spectraRouters[MAINNET_CHAIN_ID] = SPECTRA_ROUTER_MAINNET;
        configuration.spectraRouters[BASE_CHAIN_ID] = SPECTRA_ROUTER_BASE;
        configuration.spectraRouters[OPTIMISM_CHAIN_ID] = SPECTRA_ROUTER_OPTIMISM;
        configuration.spectraRouters[ARBITRUM_CHAIN_ID] = address(0); // TODO: Add Arbitrum Spectra router address
        configuration.spectraRouters[BNB_CHAIN_ID] = address(0); // TODO: Add BNB Spectra router address

        // ===== PENDLE ROUTER ADDRESSES =====
        configuration.pendleRouters[MAINNET_CHAIN_ID] = PENDLE_ROUTER_MAINNET;
        configuration.pendleRouters[BASE_CHAIN_ID] = PENDLE_ROUTER_BASE;
        configuration.pendleRouters[OPTIMISM_CHAIN_ID] = PENDLE_ROUTER_OPTIMISM;
        configuration.pendleRouters[ARBITRUM_CHAIN_ID] = address(0); // TODO: Add Arbitrum Pendle router address
        configuration.pendleRouters[BNB_CHAIN_ID] = address(0); // TODO: Add BNB Pendle router address
    }
}
