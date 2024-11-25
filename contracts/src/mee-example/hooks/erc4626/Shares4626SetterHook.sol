// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

// Superform
import { IHook } from "src/mee-example/hooks/IHook.sol";

import { BaseHook } from "src/mee-example/hooks/BaseHook.sol";
import { ERC4626Helpers } from "src/mee-example/ERC4626Helpers.sol";
import { ComposabilityStorageMock } from "src/mee-example/ComposabilityStorageMock.sol";

contract Shares4626SetterHook is BaseHook, IHook {
    ComposabilityStorageMock public immutable composabilityStorage;
    ERC4626Helpers public immutable erc4626Helpers;

    constructor(address registry_, address composabilityStorage_, address erc4626Helpers_) BaseHook(registry_) {
        composabilityStorage = ComposabilityStorageMock(composabilityStorage_);
        erc4626Helpers = ERC4626Helpers(erc4626Helpers_);
    }

    function totalOps() external pure override returns (uint256) {
        return 1;
    }

    function build(bytes memory data) external view override returns (Execution[] memory executions) {
        (address vault, address receiver, bool initialAmount) = abi.decode(data, (address, address, bool));

        if (receiver == address(0) || vault == address(0)) revert ADDRESS_NOT_VALID();

        bytes memory callData = initialAmount
            ? abi.encodeCall(erc4626Helpers.getAndStoreShares, (composabilityStorage, vault, receiver))
            : abi.encodeCall(erc4626Helpers.getAndComputeObtainedShares, (composabilityStorage, vault, receiver));

        executions = new Execution[](1);
        executions[0] = Execution({ target: address(erc4626Helpers), value: 0, callData: callData });
    }
}
