// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { ISuperVaultStrategy } from "./ISuperVaultStrategy.sol";

/// @title ISuperVaultFactory
/// @notice Interface for the SuperVaultFactory contract
/// @author SuperForm Labs
interface ISuperVaultFactory {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZERO_ADDRESS();
    error HOOK_NOT_REGISTERED();
    error BOOTSTRAP_FAILED();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event VaultDeployed(
        address indexed vault,
        address indexed strategy,
        address indexed escrow,
        address asset,
        string name,
        string symbol
    );

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Parameters for creating a new vault
    struct VaultCreationParams {
        // Basic vault parameters
        address asset;
        string name;
        string symbol;
        // Role addresses
        address manager;
        address strategist;
        address emergencyAdmin;
        address feeRecipient;
        // Strategy configuration
        ISuperVaultStrategy.GlobalConfig config;
        // Initialization parameters
        address initYieldSource;
        bytes32 initHooksRoot;
        address initYieldSourceOracle;
        // Bootstrapping parameters
        address[] bootstrappingHooks;
        bytes32[][] bootstrappingHookProofs;
        bytes[] bootstrappingHookCalldata;
    }

    /*//////////////////////////////////////////////////////////////
                            FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Create a new SuperVault with associated strategy and escrow
    /// @param params The parameters for creating the vault
    /// @return superVault The deployed vault address
    /// @return strategy The deployed strategy address
    /// @return escrow The deployed escrow address
    function createVault(VaultCreationParams calldata params)
        external
        returns (address superVault, address strategy, address escrow);

    /// @notice Get the implementation addresses
    function vaultImplementation() external view returns (address);
    function strategyImplementation() external view returns (address);
    function escrowImplementation() external view returns (address);
    function peripheryRegistry() external view returns (address);
}
