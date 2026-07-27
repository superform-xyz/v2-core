// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { BaseAerodromeUniversalRouterHook } from "./BaseAerodromeUniversalRouterHook.sol";

/// @title SwapAerodromeUniversalRouterHook
/// @author Superform Labs
/// @notice Executes an exact-input Aerodrome Universal Router swap using an existing ERC20 allowance
contract SwapAerodromeUniversalRouterHook is BaseAerodromeUniversalRouterHook {
    /// @notice Initializes the Aerodrome swap hook
    /// @param universalRouter_ Aerodrome Universal Router address
    constructor(address universalRouter_) BaseAerodromeUniversalRouterHook(universalRouter_) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Swap Aerodrome Universal Router";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Swaps tokens via the Aerodrome Universal Router";
    }

    /// @inheritdoc BaseAerodromeUniversalRouterHook
    function _includeApproval() internal pure override returns (bool) {
        return false;
    }
}
