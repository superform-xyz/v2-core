// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";

// Testing transient storage vs non-transient storage for gas benchmarks
contract TransientStorageExecutor is ERC7579ExecutorBase {
    bool transient boolStorage;
    int256 transient intStorage;
    uint256 transient uintStorage;
    address transient addressStorage;
    bytes32 transient bytes32Storage;

    uint256 uintNonTransient;
    address addressNonTransient;
    bytes32 bytes32NonTransient;

  
    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    function execute(bytes calldata) external {
        uintStorage = 1e8;
        addressStorage = address(this); 
        bytes32Storage = bytes32("0x123");
    }

    function executeNotTransient(bytes calldata) external {
        uintNonTransient = 1e8;
        addressNonTransient = address(this);
        bytes32NonTransient = bytes32("0x123");
    }

    function onInstall(bytes calldata) external { }
    function onUninstall(bytes calldata) external { }


      /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function isInitialized(address) external pure returns (bool) {
        return true;
    }

    function name() external pure returns (string memory) {
        return "SuperModuleExecutor";
    }

    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

}  
