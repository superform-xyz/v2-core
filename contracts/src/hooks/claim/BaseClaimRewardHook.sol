// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

abstract contract BaseClaimRewardHook {
    uint256 public transient obtainedReward;

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _build(address vault, bytes memory encoded) internal pure returns (Execution[] memory executions) {
        executions = new Execution[](1);
        executions[0] = Execution({ target: vault, value: 0, callData: encoded });
    }

    function _getBalance(bytes memory data) internal view returns (uint256) {
        (address account, address rewardToken) = abi.decode(data, (address, address));
        return IERC20(rewardToken).balanceOf(account);
    }
}
