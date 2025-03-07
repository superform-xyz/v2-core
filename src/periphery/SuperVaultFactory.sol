// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// External
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Clones } from "openzeppelin-contracts/contracts/proxy/Clones.sol";

// Superform
import { SuperVault } from "./SuperVault.sol";
import { SuperVaultStrategy } from "./SuperVaultStrategy.sol";
import { SuperVaultEscrow } from "./SuperVaultEscrow.sol";
import { ISuperVaultStrategy } from "./interfaces/ISuperVaultStrategy.sol";
import { ISuperVaultFactory } from "./interfaces/ISuperVaultFactory.sol";
import { IPeripheryRegistry } from "./interfaces/IPeripheryRegistry.sol";
import { IERC7540 } from "../vendor/vaults/7540/IERC7540.sol";

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
                || params.initYieldSource == address(0) || params.initYieldSourceOracle == address(0)
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
            address(this),
            address(this),
            params.emergencyAdmin,
            peripheryRegistry,
            params.config,
            params.initYieldSource,
            params.initHooksRoot,
            params.initYieldSourceOracle
        );

        _bootstrapVault(
            BootstrapParams({
                superVault: superVault,
                strategy: strategy,
                asset: params.asset,
                manager: params.manager,
                strategist: params.strategist,
                recipient: params.feeRecipient,
                bootstrappingHooks: params.bootstrappingHooks,
                bootstrappingHookCalldata: params.bootstrappingHookCalldata,
                minAssetsOrSharesOut: params.minAssetsOrSharesOut,
                config: params.config,
                bootstrapAmount: params.bootstrapAmount
            })
        );

        emit VaultDeployed(superVault, strategy, escrow, params.asset, params.name, params.symbol);

        return (superVault, strategy, escrow);
    }

    /// @notice Internal function to bootstrap a vault with an initial deposit
    function _bootstrapVault(BootstrapParams memory params) internal {
        LocalVars memory vars;

        vars.assetToken = IERC20(params.asset);
        vars.strategyContract = ISuperVaultStrategy(params.strategy);
        vars.MANAGER_ROLE = keccak256("MANAGER_ROLE");
        vars.STRATEGIST_ROLE = keccak256("STRATEGIST_ROLE");
        // Transfer bootstrap amount from sender to this contract
        // Note: this should be a non trivial amount, e.g $1 worth of asset
        // See:
        // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/3882a0916300b357f3d2f438450c1e9bc2902bae/contracts/token/ERC20/extensions/ERC4626.sol#L22C1-L28C82
        vars.assetToken.safeTransferFrom(msg.sender, address(this), params.bootstrapAmount);

        // Approve asset for superVault
        vars.assetToken.safeIncreaseAllowance(params.superVault, params.bootstrapAmount);

        // 1. Request deposit
        vars.superVaultContract = IERC7540(params.superVault);

        vars.superVaultContract.requestDeposit(params.bootstrapAmount, address(this), address(this));

        // 2. Fulfill deposit request
        vars.users = new address[](1);
        vars.users[0] = address(this);
        vars.hookCount = params.bootstrappingHooks.length;

        // Only core hooks are allowed to be used for bootstrapping
        for (uint256 i; i < vars.hookCount;) {
            if (!IPeripheryRegistry(peripheryRegistry).isHookRegistered(params.bootstrappingHooks[i])) {
                revert HOOK_NOT_REGISTERED();
            }
            unchecked {
                ++i;
            }
        }

        vars.strategyContract.fulfillRequests(
            vars.users, params.bootstrappingHooks, params.bootstrappingHookCalldata, params.minAssetsOrSharesOut, true
        );

        /// @dev Note: Theoretically this could go to an insurance fund
        vars.superVaultContract.deposit(params.bootstrapAmount, params.recipient, address(this));

        vars.strategyContract.setAddress(vars.STRATEGIST_ROLE, params.strategist);
        vars.strategyContract.setAddress(vars.MANAGER_ROLE, params.manager);
    }
}
