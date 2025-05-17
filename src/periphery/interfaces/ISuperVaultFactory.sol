// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC7540 } from "../../vendor/vaults/7540/IERC7540.sol";
import { ISuperVaultStrategy } from "./ISuperVaultStrategy.sol";

/// @title ISuperVaultFactory
/// @notice Interface for the SuperVaultFactory contract
/// @author Superform Labs
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
        uint256 superVaultCap;
    }

    // Local variables struct to improve readability and organization
    struct LocalVars {
        IERC20 assetToken;
        ISuperVaultStrategy strategyContract;
        IERC7540 superVaultContract;
        address[] users;
        uint256 hookCount;
        bytes32 MANAGER_ROLE;
        bytes32 STRATEGIST_ROLE;
        uint256 totalAssets;
        uint256 totalSupply;
        uint256 precision;
        uint256 pricePerShare;
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
