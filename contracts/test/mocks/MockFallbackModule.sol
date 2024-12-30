// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

    // external
    import { ERC7579FallbackBase } from "modulekit/Modules.sol";

contract MockFallback is ERC7579FallbackBase {
    function onInstall(bytes calldata) external override { }

    function onUninstall(bytes calldata) external override { }

    function targetFunction() external pure returns (bool) {
        return false;
    }

    function isModuleType(uint256 typeID) external pure returns (bool) {
        return typeID == TYPE_FALLBACK;
    }

    function isInitialized(
        address // smartAccount
    )
        external
        pure
        returns (bool)
    {
        return true;
    }
}
