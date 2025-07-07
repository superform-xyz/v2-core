// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

interface ISuperDeployer {
    /// @notice Deploys a contract using CREATE3 - permissionless deployment
    /// @param salt The salt to use for deployment
    /// @param creationCode The contract creation code
    /// @return deployed The address of the deployed contract
    function deploy(bytes32 salt, bytes calldata creationCode) external payable returns (address);

    /// @notice Predicts the address of a deployed contract
    /// @param salt The salt to use for deployment
    /// @return The address where the contract will be deployed
    function getDeployed(bytes32 salt) external view returns (address);

    /// @notice Check if a contract is already deployed at the predicted address
    /// @param salt The salt that would be used for deployment
    /// @return True if contract exists at the predicted address
    function isDeployed(bytes32 salt) external view returns (bool);
}
