// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

interface INexusFactory {
    /// @notice Creates a new Nexus with initialization data.
    /// @param initData Initialization data to be called on the new Smart Account.
    /// @param salt Unique salt for the Smart Account creation.
    /// @return The address of the newly created Nexus.
    function createAccount(bytes calldata initData, bytes32 salt) external payable returns (address payable);

    /// @notice Computes the expected address of a Nexus contract using the factory's deterministic deployment
    /// algorithm.
    /// @param initData Initialization data to be called on the new Smart Account.
    /// @param salt Unique salt for the Smart Account creation.
    /// @return expectedAddress The expected address at which the Nexus contract will be deployed if the provided
    /// parameters are used.
    function computeAccountAddress(
        bytes calldata initData,
        bytes32 salt
    )
        external
        view
        returns (address payable expectedAddress);
}
