// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import {BytesLib} from "../../../vendor/BytesLib.sol";
import {Execution} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

/// @title BaseClaimRewardHook
/// @author Superform Labs
abstract contract BaseClaimRewardHook {
    error ASSET_ZERO_ADDRESS();
    error REWARD_TOKEN_ZERO_ADDRESS();

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _build(address yieldSource, bytes memory encoded) internal pure returns (Execution[] memory executions) {
        executions = new Execution[](1);
        executions[0] = Execution({target: yieldSource, value: 0, callData: encoded});
    }

    function _getBalance(bytes memory data) internal view returns (uint256) {
        address rewardToken = BytesLib.toAddress(data, 24);
        address account = BytesLib.toAddress(data, 44);

        if (rewardToken == address(0)) revert REWARD_TOKEN_ZERO_ADDRESS();

        return IERC20(rewardToken).balanceOf(account);
    }
}
