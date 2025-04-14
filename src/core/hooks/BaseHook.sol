// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// External
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { ISuperHook } from "../interfaces/ISuperHook.sol";
import { HookSubTypes } from "../libraries/HookSubTypes.sol";
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

/// @title BaseHook
/// @author Superform Labs
/// @notice Base hook for all hooks
abstract contract BaseHook is SuperRegistryImplementer, ISuperHook {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    // forgefmt: disable-start
    uint256 public transient outAmount;
    uint256 public transient usedShares;
    bool public transient lockForSP;
    address public transient spToken;
    address public transient asset;
    address public transient lastExecutionCaller;

    // forgefmt: disable-end

    bytes32 public immutable subType;
    ISuperHook.HookType public hookType;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NOT_AUTHORIZED();
    error AMOUNT_NOT_VALID();
    error ADDRESS_NOT_VALID();
    error DATA_LENGTH_INSUFFICIENT();

    constructor(address registry_, ISuperHook.HookType hookType_, string memory subType_) SuperRegistryImplementer(registry_) {
        hookType = hookType_;
        subType = HookSubTypes.getHookSubType(subType_);
    }

    /*//////////////////////////////////////////////////////////////
                          EXECUTION SECURITY
    //////////////////////////////////////////////////////////////*/

    // built as a view function to allow test mocking
    function getExecutionCaller() public view returns (address) {
        return lastExecutionCaller;
    }

    // @inheritdoc ISuperHook
    function build(address prevHook, address account, bytes calldata data) external view virtual returns (Execution[] memory executions) {}
    
    // @inheritdoc ISuperHook
    function preExecute(address prevHook, address account, bytes calldata data) external  {
        _validateCaller();
        _preExecute(prevHook, account, data);
    }
    
    // @inheritdoc ISuperHook
    function postExecute(address prevHook, address account, bytes calldata data) external  {
        _validateCaller();
        _postExecute(prevHook, account, data);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function subtype() external view returns (bytes32) {
        return subType;
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    // Internal function for validation logic
    function _validateCaller() internal {
        // start a new execution context, useful for testing
        address caller = this.getExecutionCaller();

        // First call in this transaction - allow it and set the caller
        if (caller == address(0)) {
            lastExecutionCaller = msg.sender;
            return;
        }
        
        // Subsequent calls must be from the same caller that initiated execution
        if (msg.sender == caller) {
            return;
        }
        
        // If we already had a different caller and now we're trying to call from another address, reject
        revert NOT_AUTHORIZED();
    }

    /// @notice Internal implementation of preExecute
    /// @dev To be implemented by derived hooks
    function _preExecute(address prevHook, address account, bytes calldata data) internal virtual;
    
    /// @notice Internal implementation of postExecute
    /// @dev To be implemented by derived hooks
    function _postExecute(address prevHook, address account, bytes calldata data) internal virtual;

    function _decodeBool(bytes memory data, uint256 offset) internal pure returns (bool) {
        return data[offset] != 0;
    }

    function _replaceCalldataAmount(bytes memory data, uint256 amount, uint256 offset) internal pure returns (bytes memory) {
        bytes memory newAmountEncoded = abi.encodePacked(amount);
        for (uint256 i; i < 32; ++i) {
            data[offset + i] = newAmountEncoded[i];
        }
        return data;
    }   

    function _getAddress(bytes32 id_) internal view returns (address) {
        return superRegistry.getAddress(id_);
    }
}
