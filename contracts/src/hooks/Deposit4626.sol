// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

library Deposit4626 {
    function hook(
        IERC4626 vault,
        address account,
        uint256 amount
    )
        internal
        pure
        returns (Execution[] memory executions)
    {
        executions = new Execution[](2);
        executions[0] = Execution({
            target: address(vault),
            value: 0,
            callData: abi.encodeCall(IERC4626.deposit, (amount, account))
        });
    }
}
