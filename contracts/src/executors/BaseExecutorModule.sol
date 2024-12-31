// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// Superform    
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

contract BaseExecutorModule is SuperRegistryImplementer {
    // forgefmt: disable-start
    /// @dev Transient storage for hooks execution
    bool internal transient boolStorage;
    int256 internal transient intStorage;
    uint256 internal transient uintStorage;
    address internal transient addressStorage;
    bytes32 internal transient bytes32Storage;
    uint256 internal transient shareDelta;
    bytes32 internal transient typeOfMainAction;
    // forgefmt: disable-end

    mapping(address => bool) internal _initialized;

    constructor(address registry_) SuperRegistryImplementer(registry_) { }  

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _superActions() internal view returns (address) {
        return superRegistry.getAddress(superRegistry.SUPER_ACTIONS_ID());
    }

    function _isInitialized(address account) internal view returns (bool) {
        return _initialized[account];
    }
}
