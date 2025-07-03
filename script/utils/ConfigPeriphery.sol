// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import "./ConfigBase.sol";

/// @title ConfigPeriphery
/// @notice Standalone periphery configuration contract for periphery contract deployments
/// @dev Handles Polymer provers and other periphery-specific configurations
abstract contract ConfigPeriphery is ConfigBase {
    /*//////////////////////////////////////////////////////////////
                          PERIPHERY CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets up periphery contract dependencies
    /// @dev Configures addresses required for periphery contract deployment and operation
    function _setPeripheryConfiguration() internal {
        // ===== POLYMER PROVER ADDRESSES =====
        configuration.polymerProvers[MAINNET_CHAIN_ID] = POLYMER_PROVER_MAINNET;
        configuration.polymerProvers[BASE_CHAIN_ID] = POLYMER_PROVER_BASE;
        configuration.polymerProvers[OPTIMISM_CHAIN_ID] = POLYMER_PROVER_OPTIMISM;
        configuration.polymerProvers[ARBITRUM_CHAIN_ID] = address(0); // TODO: Add Arbitrum Polymer prover address
        configuration.polymerProvers[BNB_CHAIN_ID] = address(0); // TODO: Add BNB Polymer prover address
    }
}
