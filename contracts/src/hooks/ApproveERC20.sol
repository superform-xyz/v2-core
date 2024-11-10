// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

library ApproveERC20 {
    function hook(
        IERC20 token,
        address spender,
        uint256 amount
    )
        internal
        pure
        returns (Execution[] memory executions)
    {
        executions = new Execution[](2);
        executions[0] =
            Execution({ target: address(token), value: 0, callData: abi.encodeCall(IERC20.approve, (spender, 0)) });
        executions[1] =
            Execution({ target: address(token), value: 0, callData: abi.encodeCall(IERC20.approve, (spender, amount)) });
    }
}
