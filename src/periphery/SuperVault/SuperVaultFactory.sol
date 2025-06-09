// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// External
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// Superform
import { SuperVault } from "./SuperVault.sol";
import { SuperVaultStrategy } from "./SuperVaultStrategy.sol";
import { SuperVaultEscrow } from "./SuperVaultEscrow.sol";
import { ISuperGovernor } from "../interfaces/ISuperGovernor.sol";
import { ISuperVaultFactory } from "../interfaces/SuperVault/ISuperVaultFactory.sol";
import { ISuperVaultAggregator } from "../interfaces/SuperVault/ISuperVaultAggregator.sol";
import { ISuperVaultRegistry } from "../interfaces/SuperVault/ISuperVaultRegistry.sol";
// Libraries
import { AssetMetadataLib } from "../libraries/AssetMetadataLib.sol";

/// @title SuperVaultFactory
/// @author Superform Labs
/// @notice Factory contract for creating SuperVault trios and managing registry
contract SuperVaultFactory is ISuperVaultFactory {
    using AssetMetadataLib for address;
    using Clones for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    // Vault implementation contracts
    address public immutable VAULT_IMPLEMENTATION;
    address public immutable STRATEGY_IMPLEMENTATION;
    address public immutable ESCROW_IMPLEMENTATION;

    // Governance and registry contracts
    ISuperGovernor public immutable SUPER_GOVERNOR;
    ISuperAssetRegistry public immutable SUPER_VAULT_REGISTRY;

    // Registry of created vaults
    EnumerableSet.AddressSet private _superVaults;
    EnumerableSet.AddressSet private _superVaultStrategies;
    EnumerableSet.AddressSet private _superVaultEscrows;

    // Nonce for vault creation tracking
    uint256 private _vaultCreationNonce;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /// @notice Validates that msg.sender is authorized to create vaults
    modifier onlyAuthorized() {
        // TODO: Implement proper role-based access control
        // For now, allow any caller to enable testing of the modular system
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @notice Initializes the SuperVaultFactory
    /// @param superGovernor_ Address of the SuperGovernor contract
    /// @param superAssetRegistry_ Address of the SuperAssetRegistry contract
    constructor(address superGovernor_, address superAssetRegistry_) {
        if (superGovernor_ == address(0) || superAssetRegistry_ == address(0)) revert ZERO_ADDRESS();

        // Deploy implementation contracts
        VAULT_IMPLEMENTATION = address(new SuperVault());
        STRATEGY_IMPLEMENTATION = address(new SuperVaultStrategy());
        ESCROW_IMPLEMENTATION = address(new SuperVaultEscrow());

        SUPER_GOVERNOR = ISuperGovernor(superGovernor_);
        SUPER_VAULT_REGISTRY = ISuperAssetRegistry(superAssetRegistry_);
    }

    /*//////////////////////////////////////////////////////////////
                            VAULT CREATION
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultFactory
    function createVault(ISuperVaultAggregator.VaultCreationParams calldata params)
        external
        onlyAuthorized
        returns (address superVault, address strategy, address escrow)
    {
        // Input validation
        if (
            params.asset == address(0) || params.mainStrategist == address(0)
                || params.feeConfig.recipient == address(0)
        ) {
            revert ZERO_ADDRESS();
        }

        // Increment nonce before creating proxies
        uint256 currentNonce = _vaultCreationNonce++;

        // Create minimal proxies
        superVault = VAULT_IMPLEMENTATION.cloneDeterministic(
            keccak256(abi.encodePacked(params.asset, params.name, params.symbol, currentNonce))
        );
        escrow = ESCROW_IMPLEMENTATION.cloneDeterministic(
            keccak256(abi.encodePacked(params.asset, params.name, params.symbol, currentNonce))
        );
        strategy = STRATEGY_IMPLEMENTATION.cloneDeterministic(
            keccak256(abi.encodePacked(params.asset, params.name, params.symbol, currentNonce))
        );

        // Initialize superVault
        SuperVault(superVault).initialize(params.asset, params.name, params.symbol, strategy, escrow);

        // Initialize escrow
        SuperVaultEscrow(escrow).initialize(superVault, strategy);

        // Initialize strategy
        SuperVaultStrategy(strategy).initialize(superVault, address(SUPER_GOVERNOR), params.feeConfig);

        // Store vault trio in registry
        _superVaults.add(superVault);
        _superVaultStrategies.add(strategy);
        _superVaultEscrows.add(escrow);

        // Get asset decimals for registry initialization
        (bool success, uint8 assetDecimals) = params.asset.tryGetAssetDecimals();
        uint8 underlyingDecimals = success ? assetDecimals : 18;

        // Initialize strategy data in the asset registry
        SUPER_VAULT_REGISTRY.initializeStrategyData(
            strategy, params.mainStrategist, params.minUpdateInterval, params.maxStaleness, underlyingDecimals
        );

        emit VaultDeployed(superVault, strategy, escrow, params.asset, params.name, params.symbol, currentNonce);

        return (superVault, strategy, escrow);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultFactory
    function getCurrentNonce() external view returns (uint256) {
        return _vaultCreationNonce;
    }

    /// @inheritdoc ISuperVaultFactory
    function getAllSuperVaults() external view returns (address[] memory) {
        return _superVaults.values();
    }

    /// @inheritdoc ISuperVaultFactory
    function superVaults(uint256 index) external view returns (address) {
        if (index >= _superVaults.length()) revert INDEX_OUT_OF_BOUNDS();
        return _superVaults.at(index);
    }

    /// @inheritdoc ISuperVaultFactory
    function getAllSuperVaultStrategies() external view returns (address[] memory) {
        return _superVaultStrategies.values();
    }

    /// @inheritdoc ISuperVaultFactory
    function superVaultStrategies(uint256 index) external view returns (address) {
        if (index >= _superVaultStrategies.length()) revert INDEX_OUT_OF_BOUNDS();
        return _superVaultStrategies.at(index);
    }

    /// @inheritdoc ISuperVaultFactory
    function getAllSuperVaultEscrows() external view returns (address[] memory) {
        return _superVaultEscrows.values();
    }

    /// @inheritdoc ISuperVaultFactory
    function superVaultEscrows(uint256 index) external view returns (address) {
        if (index >= _superVaultEscrows.length()) revert INDEX_OUT_OF_BOUNDS();
        return _superVaultEscrows.at(index);
    }
}
