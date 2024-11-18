// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

library Deposit4626 {
    error AMOUNT_NOT_VALID();
    error ADDRESS_NOT_VALID();

    function hook(
        IERC4626 vault,
        address account,
        uint256 amount
    )
        internal
        pure
        returns (Execution[] memory executions)
    {
        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (address(vault) == address(0) || account == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(vault),
            value: 0,
            callData: abi.encodeCall(IERC4626.deposit, (amount, account))
        });
    }
}
