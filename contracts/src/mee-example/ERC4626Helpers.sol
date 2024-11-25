// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

// Superform
import { ComposabilityStorageMock } from "src/mee-example/ComposabilityStorageMock.sol";

contract ERC4626Helpers {
    function getAndStoreShares(
        ComposabilityStorageMock composabilityStorage,
        address vault,
        address receiver
    )
        external
    {
        uint256 shares = IERC4626(vault).balanceOf(receiver);
        composabilityStorage.setAmount(shares);
    }

    function getAndComputeObtainedShares(
        ComposabilityStorageMock composabilityStorage,
        address vault,
        address receiver
    )
        external
    {
        uint256 shares = IERC4626(vault).balanceOf(receiver);
        composabilityStorage.setObtained(shares);
    }
}
