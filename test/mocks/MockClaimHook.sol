// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { BaseClaimRewardHook } from "../../src/hooks/claim/BaseClaimRewardHook.sol";

contract MockClaimHook is BaseClaimRewardHook {
    constructor() BaseClaimRewardHook() { }

    function getBalanceMock(bytes memory data, address account) public view returns (uint256) {
        return _getBalance(data, account);
    }
}
