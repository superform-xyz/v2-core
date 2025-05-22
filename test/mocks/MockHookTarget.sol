// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @notice Mock contract to be targeted by hooks during testing
contract MockHookTarget {
    // Event for verification
    event Executed();
    event ExecutedWithData(bytes data);
    
    // Control parameters
    bool public shouldFailExecution;
    
    function setShouldFailExecution(bool _shouldFail) external {
        shouldFailExecution = _shouldFail;
    }
    
    function execute() external {
        if (shouldFailExecution) {
            revert("MockHookTarget: execution failed");
        }
        emit Executed();
    }
    
    function executeWithData(bytes calldata data) external {
        if (shouldFailExecution) {
            revert("MockHookTarget: execution failed");
        }
        emit ExecutedWithData(data);
    }
    
    // Fallback function to handle any calls
    fallback() external {
        if (shouldFailExecution) {
            revert("MockHookTarget: fallback execution failed");
        }
        emit Executed();
    }
    
    // Allow receiving ETH
    receive() external payable {}
}
