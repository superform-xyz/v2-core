// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { BaseClaimRewardHook } from "../../src/hooks/claim/BaseClaimRewardHook.sol";

contract MockClaimHook is BaseClaimRewardHook {
    constructor() BaseClaimRewardHook() { }

    /// @notice Human-readable name for UI display
    function name() external pure returns (string memory) {
        return "Mock Claim";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure returns (string memory) {
        return "Mock hook for testing";
    }


    function getBalanceMock(bytes memory data, address account) public view returns (uint256) {
        return _getBalance(data, account);
    }
}
