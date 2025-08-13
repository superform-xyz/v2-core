// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

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
    /// @notice Initializes the smart account with a validator and custom data.
    /// @dev This method sets up the account for operation, linking it with a validator and initializing it with
    /// specific data.
    /// Can be called directly or via a factory.
    /// @param initData Encoded data used for the account's configuration during initialization.
    function initializeAccount(bytes calldata initData) external payable;
    /// @dev Retrieves a paginated list of validator addresses from the linked list.
    /// This utility function is not defined by the ERC-7579 standard and is implemented to facilitate
    /// easier management and retrieval of large sets of validator modules.
    /// @param cursor The address to start pagination from, or zero to start from the first entry.
    /// @param size The number of validator addresses to return.
    /// @return array An array of validator addresses.
    /// @return next The address to use as a cursor for the next page of results.
    function getValidatorsPaginated(
        address cursor,
        uint256 size
    )
        external
        view
        returns (address[] memory array, address next);
    function installModule(uint256 moduleTypeId, address module, bytes calldata initData) external payable;
}
