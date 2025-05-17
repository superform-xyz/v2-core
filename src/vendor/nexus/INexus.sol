// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import "modulekit/accounts/common/lib/ModeLib.sol";

interface INexus {
    function accountId() external view returns (string memory accountImplementationId);
    function supportsModule(uint256 moduleTypeId) external view returns (bool supported);
    /// @notice Executes a transaction with specified execution mode and calldata.
    /// @param mode The execution mode, defining how the transaction is processed.
    /// @param executionCalldata The calldata to execute.
    /// @dev This function ensures that the execution complies with smart account execution policies and handles errors
    /// appropriately.
    function execute(ModeCode mode, bytes calldata executionCalldata) external payable;
}
