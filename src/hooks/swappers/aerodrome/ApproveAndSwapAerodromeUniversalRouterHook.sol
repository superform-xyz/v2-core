// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { BaseAerodromeUniversalRouterHook } from "./BaseAerodromeUniversalRouterHook.sol";

/// @title ApproveAndSwapAerodromeUniversalRouterHook
/// @author Superform Labs
/// @notice Temporarily approves and executes an exact-input Aerodrome Universal Router swap
contract ApproveAndSwapAerodromeUniversalRouterHook is BaseAerodromeUniversalRouterHook {
    /// @notice Initializes the Aerodrome approve-and-swap hook
    /// @param universalRouter_ Aerodrome Universal Router address
    constructor(address universalRouter_) BaseAerodromeUniversalRouterHook(universalRouter_) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Approve and Swap Aerodrome Universal Router";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Approves and swaps tokens via the Aerodrome Universal Router";
    }

    /// @inheritdoc BaseAerodromeUniversalRouterHook
    function _includeApproval() internal pure override returns (bool) {
        return true;
    }
}
