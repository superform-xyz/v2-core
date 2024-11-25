// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

// Superform
import { IHook } from "src/mee-example/hooks/IHook.sol";
import { BaseHook } from "src/mee-example/hooks/BaseHook.sol";
import { IBridge } from "src/mee-example/interfaces/IBridge.sol";
import { SuperPositionHelper } from "src/mee-example/SuperPositionHelper.sol";

contract ReadAndMintSuperpositionHook is BaseHook, IHook {
    error PARAMS_NOT_VALID();

    SuperPositionHelper public immutable superPositionHelper;

    constructor(address registry_, address superPositionHelper_) BaseHook(registry_) {
        if (superPositionHelper_ == address(0)) revert ADDRESS_NOT_VALID();
        superPositionHelper = SuperPositionHelper(superPositionHelper_);
    }

    function totalOps() external pure override returns (uint256) {
        return 1;
    }

    function build(bytes memory data) external view override returns (Execution[] memory executions) {
        if (data.length == 0) revert PARAMS_NOT_VALID();

        (address superPositions, address receiver) = abi.decode(data, (address, address));

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(superPositionHelper),
            value: 0,
            callData: abi.encodeCall(SuperPositionHelper.retrieveAmountAndMint, (superPositions, receiver))
        });
    }
}
