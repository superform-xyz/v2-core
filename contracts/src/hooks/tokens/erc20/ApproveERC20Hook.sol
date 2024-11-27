// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "src/utils/BaseHook.sol";

import { ISuperHook } from "src/interfaces/ISuperHook.sol";

contract ApproveERC20Hook is BaseHook, ISuperHook {
    constructor(address registry_, address author_) BaseHook(registry_, author_) { }

    function totalOps() external pure override returns (uint256) {
        return 2;
    }

    function build(bytes memory data) external pure override returns (Execution[] memory executions) {
        (address token, address spender, uint256 amount) = abi.decode(data, (address, address, uint256));

        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (token == address(0) || spender == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](2);
        executions[0] = Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (spender, 0)) });
        executions[1] =
            Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (spender, amount)) });
    }
}
