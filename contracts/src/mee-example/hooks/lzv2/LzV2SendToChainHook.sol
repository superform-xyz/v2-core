// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

// Superform
import { IHook } from "src/mee-example/hooks/IHook.sol";
import { BaseHook } from "src/mee-example/hooks/BaseHook.sol";
import { IBridge } from "src/mee-example/interfaces/IBridge.sol";

contract LzV2SendToChainHook is BaseHook, IHook {
    IBridge public immutable bridge;

    error PARAMS_NOT_VALID();

    constructor(address registry_, address lzV2Helper_) BaseHook(registry_) {
        if (lzV2Helper_ == address(0)) revert ADDRESS_NOT_VALID();
        bridge = IBridge(lzV2Helper_);
    }

    function totalOps() external pure override returns (uint256) {
        return 1;
    }

    function build(bytes memory data) external view override returns (Execution[] memory executions) {
        if (data.length == 0) revert PARAMS_NOT_VALID();

        (uint256 value, bytes memory payload) = abi.decode(data, (uint256, bytes));

        executions = new Execution[](1);
        executions[0] =
            Execution({ target: address(bridge), value: value, callData: abi.encodeCall(IBridge.send, (payload)) });
    }
}
