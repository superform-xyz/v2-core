// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { IHook } from "src/interfaces/IHook.sol";
import { BaseHook } from "src/utils/BaseHook.sol";

contract TransferERC20Hook is BaseHook, IHook {
    constructor(address registry_) BaseHook(registry_) { }

    function totalOps() external pure override returns (uint256) {
        return 1;
    }

    function build(bytes memory data) external pure override returns (Execution[] memory executions) {
        (address token, address to, uint256 amount) = abi.decode(data, (address, address, uint256));

        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (token == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.transfer, (to, amount)) });
    }
}
