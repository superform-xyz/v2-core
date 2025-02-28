// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

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
import { console2 } from "forge-std/console2.sol";

/// @title SuperVaultFactory
/// @notice Factory contract that deploys SuperVault, SuperVaultStrategy, and SuperVaultEscrow
/// @author SuperForm Labs
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
    uint256 private constant BOOTSTRAP_AMOUNT = 1000;

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
            superVault,
            strategy,
            params.asset,
            params.manager,
            params.strategist,
            params.feeRecipient,
            params.bootstrappingHooks,
            params.bootstrappingHookProofs,
            params.bootstrappingHookCalldata
        );

        emit VaultDeployed(superVault, strategy, escrow, params.asset, params.name, params.symbol);

        return (superVault, strategy, escrow);
    }

    // Local variables struct to improve readability and organization
    struct LocalVars {
        IERC20 assetToken;
        ISuperVaultStrategy strategyContract;
        address[] users;
        uint256 hookCount;
        bytes32 MANAGER_ROLE;
        bytes32 STRATEGIST_ROLE;
        uint256 totalAssets;
        uint256 totalSupply;
        uint256 precision;
        uint256 pricePerShare;
    }

    /// @notice Internal function to bootstrap a vault with an initial deposit
    function _bootstrapVault(
        address superVault,
        address strategy,
        address asset,
        address manager,
        address strategist,
        address recipient,
        address[] calldata bootstrappingHooks,
        bytes32[][] calldata bootstrappingHookProofs,
        bytes[] calldata bootstrappingHookCalldata
    )
        internal
    {
        LocalVars memory vars;

        vars.assetToken = IERC20(asset);
        vars.strategyContract = ISuperVaultStrategy(strategy);
        vars.MANAGER_ROLE = keccak256("MANAGER_ROLE");
        vars.STRATEGIST_ROLE = keccak256("STRATEGIST_ROLE");
        // Transfer bootstrap amount from sender to this contract
        vars.assetToken.safeTransferFrom(msg.sender, address(this), BOOTSTRAP_AMOUNT);

        // Approve asset for superVault
        vars.assetToken.safeIncreaseAllowance(superVault, BOOTSTRAP_AMOUNT);

        // 1. Request deposit
        SuperVault(superVault).requestDeposit(BOOTSTRAP_AMOUNT, address(this), address(this));

        // 2. Fulfill deposit request
        vars.users = new address[](1);
        vars.users[0] = address(this);
        vars.hookCount = bootstrappingHooks.length;

        // Only core hooks are allowed to be used for bootstrapping
        for (uint256 i; i < vars.hookCount;) {
            if (!IPeripheryRegistry(peripheryRegistry).isHookRegistered(bootstrappingHooks[i])) {
                revert HOOK_NOT_REGISTERED();
            }
            unchecked {
                ++i;
            }
        }

        vars.strategyContract.fulfillRequests(
            vars.users, bootstrappingHooks, bootstrappingHookProofs, bootstrappingHookCalldata, true
        );
        vars.strategyContract.setAddress(vars.STRATEGIST_ROLE, strategist);
        vars.strategyContract.setAddress(vars.MANAGER_ROLE, manager);

        // 3. Verify price per share has increased
        (vars.totalAssets,) = vars.strategyContract.totalAssets();
        vars.totalSupply = SuperVault(superVault).totalSupply();
        vars.precision = vars.strategyContract.PRECISION();
        vars.pricePerShare = vars.totalAssets.mulDiv(vars.precision, vars.totalSupply, Math.Rounding.Floor);

        console2.log("----------------- pricePerShare", vars.pricePerShare);

        // prevent bootstrapping vaults where the PPS does not increase
        if (vars.pricePerShare <= vars.precision) {
            revert BOOTSTRAP_FAILED();
        }

        /*
        // 3. Claim deposit
        try SuperVault(superVault).deposit(BOOTSTRAP_AMOUNT, recipient, address(this)) {
            emit VaultBootstrapped(superVault, strategy, BOOTSTRAP_AMOUNT);
        } catch {
            revert BOOTSTRAP_FAILED();
        }
        */
    }
}
