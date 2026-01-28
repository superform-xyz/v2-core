// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ISuperHook } from "../../src/interfaces/ISuperHook.sol";

/// @notice Mock that simulates PendleRouterSwapHook behavior
/// @dev In the real flow:
///      - swapExactTokenForPt: outAmount = PT received (used by RecordPurchaseHook)
///      - swapExactPtForToken: outAmount = underlying token received (NOT used by RecordRedemptionHook)
/// @dev For redemption, ptSold is the INPUT to the swap, known ahead of time, passed directly to the hook
contract MockPendleRouterSwapHook {
    mapping(address => uint256) public outAmounts;

    function setOutAmount(address account, uint256 amount) external {
        outAmounts[account] = amount;
    }

    function getOutAmount(address account) external view returns (uint256) {
        return outAmounts[account];
    }

    function hookType() external pure returns (ISuperHook.HookType) {
        return ISuperHook.HookType.NONACCOUNTING;
    }

    function spToken() external pure returns (address) {
        return address(0);
    }

    function asset() external pure returns (address) {
        return address(0);
    }
}
