// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "src/utils/BaseHook.sol";

import { ISuperHook } from "src/interfaces/ISuperHook.sol";
import { ISentinel } from "src/interfaces/sentinel/ISentinel.sol";
import { ISentinelData } from "src/interfaces/sentinel/ISentinelData.sol";

contract SuperSentinelHook is BaseHook, ISuperHook {
    constructor(address registry_, address author_) BaseHook(registry_, author_) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function totalOps() external pure override returns (uint256) {
        return 1;
    }

    /// @inheritdoc ISuperHook
    function build(bytes memory data) external pure override returns (Execution[] memory executions) {
        (address sentinel_, ISentinelData.Entry memory entry) = abi.decode(data, (address, ISentinelData.Entry));

        executions = new Execution[](1);
        executions[0] = Execution({ target: sentinel_, value: 0, callData: abi.encodeCall(ISentinel.notify, (entry)) });
    }
}
