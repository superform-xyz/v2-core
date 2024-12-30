// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// Superform    
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

contract BaseExecutorModule is SuperRegistryImplementer {
    // forgefmt: disable-start
    /// @dev Transient storage for hooks execution
    uint256 internal transient shareDelta;
    // forgefmt: disable-end

    constructor(address registry_) SuperRegistryImplementer(registry_) { }  

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _isInitialized() internal pure returns (bool) {
        return true;
    }
}
