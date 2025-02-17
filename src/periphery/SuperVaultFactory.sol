// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { Clones } from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import { SuperVault } from "./SuperVault.sol";
import { SuperVaultStrategy } from "./SuperVaultStrategy.sol";
import { SuperVaultEscrow } from "./SuperVaultEscrow.sol";
import { ISuperVaultStrategy } from "./interfaces/ISuperVaultStrategy.sol";

/// @title SuperVaultFactory
/// @notice Factory contract that deploys SuperVault, SuperVaultStrategy, and SuperVaultEscrow
/// @author SuperForm Labs
contract SuperVaultFactory {
    using Clones for address;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZERO_ADDRESS();

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
                                STATE
    //////////////////////////////////////////////////////////////*/
    address public immutable vaultImplementation;
    address public immutable strategyImplementation;
    address public immutable escrowImplementation;
    address public immutable superRegistry;
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address superRegistry_) {
        vaultImplementation = address(new SuperVault());
        strategyImplementation = address(new SuperVaultStrategy());
        escrowImplementation = address(new SuperVaultEscrow());
        superRegistry = superRegistry_;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Create a new SuperVault with associated strategy and escrow
    /// @param asset The underlying asset token address
    /// @param name The name of the vault token
    /// @param symbol The symbol of the vault token
    /// @param manager The manager address
    /// @param strategist The strategist address
    /// @param emergencyAdmin The emergency admin address
    /// @param config The initial global configuration
    /// @param feeRecipient The fee recipient address
    /// @return vault The deployed vault address
    /// @return strategy The deployed strategy address
    /// @return escrow The deployed escrow address
    function createVault(
        address asset,
        string memory name,
        string memory symbol,
        address manager,
        address strategist,
        address emergencyAdmin,
        ISuperVaultStrategy.GlobalConfig memory config,
        address feeRecipient
    )
        external
        returns (address vault, address strategy, address escrow)
    {
        // Input validation
        if (
            asset == address(0) || manager == address(0) || strategist == address(0) || emergencyAdmin == address(0)
                || feeRecipient == address(0)
        ) {
            revert ZERO_ADDRESS();
        }

        // Create minimal proxies
        vault = vaultImplementation.clone();
        escrow = escrowImplementation.clone();
        strategy = strategyImplementation.clone();

        // Initialize vault
        SuperVault(vault).initialize(asset, name, symbol, strategy, escrow);

        // Initialize escrow
        SuperVaultEscrow(escrow).initialize(vault, strategy);

        // Initialize strategy
        SuperVaultStrategy(strategy).initialize(vault, manager, strategist, emergencyAdmin, superRegistry, config);

        emit VaultDeployed(vault, strategy, escrow, asset, name, symbol);
        return (vault, strategy, escrow);
    }
}
