// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.30;

import { ConfigBase } from "./ConfigBase.sol";
import { ConstantsOtherHooks } from "./ConstantsOtherHooks.sol";

/// @title ConfigOtherHooks
/// @notice Morpho protocol address configuration for hook deployment
abstract contract ConfigOtherHooks is ConfigBase, ConstantsOtherHooks {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    struct OtherHooksData {
        mapping(uint64 chainId => address morpho) morphos;
    }

    OtherHooksData internal otherHooksConfiguration;

    /*//////////////////////////////////////////////////////////////
                        PROTOCOL CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets up Morpho protocol addresses per chain
    function _setOtherHooksConfiguration() internal {
        otherHooksConfiguration.morphos[MAINNET_CHAIN_ID] = MORPHO_MAINNET;
        otherHooksConfiguration.morphos[BASE_CHAIN_ID] = MORPHO_BASE;
        otherHooksConfiguration.morphos[OPTIMISM_CHAIN_ID] = MORPHO_OPTIMISM;
        otherHooksConfiguration.morphos[ARBITRUM_CHAIN_ID] = MORPHO_ARBITRUM;
        otherHooksConfiguration.morphos[BNB_CHAIN_ID] = MORPHO_BNB;
    }
}
