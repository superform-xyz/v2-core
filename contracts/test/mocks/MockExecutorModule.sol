// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import {ERC7579ExecutorBase} from "modulekit/Modules.sol";

contract MockExecutorModule is ERC7579ExecutorBase {
    uint256 public val;

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function isInitialized(address) external pure returns (bool) {
        return true;
    }

    function name() external pure returns (string memory) {
        return "MockExecutorModule";
    }

    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function onInstall(bytes calldata) external {}
    function onUninstall(bytes calldata) external {}

    function execute(address, bytes calldata data) external {
        uint256 toSet = abi.decode(data, (uint256));
        val = toSet;
    }
}
