// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// External
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Clones } from "openzeppelin-contracts/contracts/proxy/Clones.sol";

// Superform
import { SuperVault } from "./SuperVault.sol";
import { SuperVaultStrategy } from "./SuperVaultStrategy.sol";
import { SuperVaultEscrow } from "./SuperVaultEscrow.sol";
import { ISuperVaultFactory } from "./interfaces/ISuperVaultFactory.sol";

/// @title SuperVaultFactory
/// @author SuperForm Labs
/// @notice Factory contract that deploys SuperVault, SuperVaultStrategy, and SuperVaultEscrow
contract SuperVaultFactory is ISuperVaultFactory {
    using Clones for address;
    using SafeERC20 for IERC20;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/
    address public immutable vaultImplementation;
    address public immutable strategyImplementation;
    address public immutable escrowImplementation;
    address public immutable peripheryRegistry;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address peripheryRegistry_) {
        vaultImplementation = address(new SuperVault());
        strategyImplementation = address(new SuperVaultStrategy());
        escrowImplementation = address(new SuperVaultEscrow());
        peripheryRegistry = peripheryRegistry_;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperVaultFactory
    function createVault(VaultCreationParams calldata params)
        external
        returns (address superVault, address strategy, address escrow)
    {
        // Input validation
        if (
            params.asset == address(0) || params.manager == address(0) || params.strategist == address(0)
                || params.emergencyAdmin == address(0) || params.feeRecipient == address(0)
        ) {
            revert ZERO_ADDRESS();
        }

        // Create minimal proxies
        superVault = vaultImplementation.clone();
        escrow = escrowImplementation.clone();
        strategy = strategyImplementation.clone();

        // Initialize superVault
        SuperVault(superVault).initialize(params.asset, params.name, params.symbol, strategy, escrow);

        // Initialize escrow
        SuperVaultEscrow(escrow).initialize(superVault, strategy);

        // Initialize strategy
        SuperVaultStrategy(strategy).initialize(
            superVault,
            params.manager,
            params.strategist,
            params.emergencyAdmin,
            peripheryRegistry,
            params.superVaultCap
        );

        emit VaultDeployed(superVault, strategy, escrow, params.asset, params.name, params.symbol);

        return (superVault, strategy, escrow);
    }
}
