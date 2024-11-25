// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";

// Superform
import { IHook } from "src/mee-example/hooks/IHook.sol";

contract StrategyExecutor {
    // just an example
    /// ------
    mapping(uint256 => address[]) public strategies;

    function getStrategy(uint256 strategyId) public view returns (address[] memory) {
        return strategies[strategyId];
    }

    function setStrategy(uint256 strategyId, address[] memory hooks) external {
        strategies[strategyId] = hooks;
    }
    /// ----

    error PARAMS_NOT_VALID();

    function executeStrategy(bytes memory data) external view returns (Execution[] memory executions) {
        (uint256 strategyId, bytes[] memory hooksData) = abi.decode(data, (uint256, bytes[]));

        address[] memory hooks = getStrategy(strategyId);

        uint256 hooksLength = hooks.length;
        if (hooksLength == 0 || hooksLength != hooksData.length) revert PARAMS_NOT_VALID();

        uint256 totalOps;
        for (uint256 i; i < hooksLength; i++) {
            totalOps += IHook(hooks[i]).totalOps();
        }

        executions = new Execution[](totalOps);
        for (uint256 i; i < hooksLength; i++) {
            Execution[] memory hookExecutions = IHook(hooks[i]).build(hooksData[i]);
            for (uint256 j; j < hookExecutions.length; j++) {
                executions[i] = hookExecutions[j];
            }
        }

        return executions;
    }
}
