// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// Superform    
import { SuperRegistryImplementer } from "src/utils/SuperRegistryImplementer.sol";

contract BaseExecutorModule is SuperRegistryImplementer {
    // forgefmt: disable-start
    /// @dev Transient storage for hooks execution
    bool internal transient boolStorage;
    int256 internal transient intStorage;
    uint256 internal transient uintStorage;
    address internal transient addressStorage;
    bytes32 internal transient bytes32Storage;
    // forgefmt: disable-end

    constructor(address registry_) SuperRegistryImplementer(registry_) { }  

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _superActions() internal view returns (address) {
        return superRegistry.getAddress(superRegistry.SUPER_ACTIONS_ID());
    }

    function _isInitialized() internal pure returns (bool) {
        return true;
    }
}
