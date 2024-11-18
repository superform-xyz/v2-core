// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

library TransferERC20 {
    error AMOUNT_NOT_VALID();
    error ADDRESS_NOT_VALID();

    function hook(IERC20 token, address to, uint256 amount) internal pure returns (Execution[] memory executions) {
        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (address(token) == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] =
            Execution({ target: address(token), value: 0, callData: abi.encodeCall(IERC20.transfer, (to, amount)) });
    }
}
