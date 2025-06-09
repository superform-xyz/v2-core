// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// Superform
import { ISuperGovernor } from "../interfaces/ISuperGovernor.sol";
import { ISuperVaultAggregator } from "../interfaces/SuperVault/ISuperVaultAggregator.sol";
import { ISuperVaultFactory } from "../interfaces/SuperVault/ISuperVaultFactory.sol";
import { IHookRegistry } from "../interfaces/SuperVault/IHookRegistry.sol";
import { ISuperVaultRegistry } from "../interfaces/SuperVault/ISuperVaultRegistry.sol";

/// @title SuperVaultAggregator
/// @author Superform Labs
/// @notice Lightweight orchestrator for the modular SuperVault factory system
contract SuperVaultAggregator is ISuperVaultAggregator {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    // Governance
    ISuperGovernor public immutable SUPER_GOVERNOR;

    // Factory contracts
    ISuperVaultFactory public immutable SUPER_VAULT_FACTORY;
    IHookRegistry public immutable HOOK_FACTORY;
    ISuperVaultRegistry public immutable SUPER_VAULT_REGISTRY;

    // Constant for PPS decimals
    uint256 public constant PPS_DECIMALS = 18;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /// @notice Validates that msg.sender is the active PPS Oracle
    modifier onlyPPSOracle() {
        if (!SUPER_GOVERNOR.isActivePPSOracle(msg.sender)) {
            revert UNAUTHORIZED_PPS_ORACLE();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @notice Initializes the SuperVaultAggregator
    /// @param superGovernor_ Address of the SuperGovernor contract
    /// @param superVaultFactory_ Address of the SuperVaultFactory contract
    /// @param HookRegistry_ Address of the HookRegistry contract
    /// @param superVaultRegistry_ Address of the SuperVaultRegistry contract
    constructor(
        address superGovernor_,
        address superVaultFactory_,
        address HookRegistry_,
        address superVaultRegistry_
    ) {
        if (
            superGovernor_ == address(0) || superVaultFactory_ == address(0) || HookRegistry_ == address(0)
                || superVaultRegistry_ == address(0)
        ) {
            revert ZERO_ADDRESS();
        }

        SUPER_GOVERNOR = ISuperGovernor(superGovernor_);
        SUPER_VAULT_FACTORY = ISuperVaultFactory(superVaultFactory_);
        HOOK_FACTORY = IHookRegistry(HookRegistry_);
        SUPER_VAULT_REGISTRY = ISuperVaultRegistry(superVaultRegistry_);
    }

    /*//////////////////////////////////////////////////////////////
                            VAULT CREATION
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultAggregator
    function createVault(VaultCreationParams calldata params)
        external
        returns (address superVault, address strategy, address escrow)
    {
        return SUPER_VAULT_FACTORY.createVault(params);
    }

    /*//////////////////////////////////////////////////////////////
                          PPS UPDATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultAggregator
    function forwardPPS(address updateAuthority, ForwardPPSArgs calldata args) external onlyPPSOracle {
        SUPER_VAULT_REGISTRY.forwardPPS(updateAuthority, args);
    }

    /// @inheritdoc ISuperVaultAggregator
    function batchForwardPPS(BatchForwardPPSArgs calldata args) external onlyPPSOracle {
        SUPER_VAULT_REGISTRY.batchForwardPPS(args);
    }

    /*//////////////////////////////////////////////////////////////
                        UPKEEP MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultAggregator
    function depositUpkeep(address strategist, uint256 amount) external {
        SUPER_VAULT_REGISTRY.depositUpkeep(strategist, amount);
    }

    /// @inheritdoc ISuperVaultAggregator
    function withdrawUpkeep(uint256 amount) external {
        SUPER_VAULT_REGISTRY.withdrawUpkeep(amount);
    }

    /*//////////////////////////////////////////////////////////////
                        AUTHORIZED CALLER MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultAggregator
    function addAuthorizedCaller(address strategy, address caller) external {
        SUPER_VAULT_REGISTRY.addAuthorizedCaller(strategy, caller);
    }

    /// @inheritdoc ISuperVaultAggregator
    function removeAuthorizedCaller(address strategy, address caller) external {
        SUPER_VAULT_REGISTRY.removeAuthorizedCaller(strategy, caller);
    }

    /*//////////////////////////////////////////////////////////////
                       STRATEGIST MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultAggregator
    function addSecondaryStrategist(address strategy, address strategist) external {
        SUPER_VAULT_REGISTRY.addSecondaryStrategist(strategy, strategist);
    }

    /// @inheritdoc ISuperVaultAggregator
    function removeSecondaryStrategist(address strategy, address strategist) external {
        SUPER_VAULT_REGISTRY.removeSecondaryStrategist(strategy, strategist);
    }

    /// @inheritdoc ISuperVaultAggregator
    function updatePPSVerificationThresholds(
        address strategy,
        uint256 dispersionThreshold_,
        uint256 deviationThreshold_,
        uint256 mnThreshold_
    )
        external
    {
        SUPER_VAULT_REGISTRY.updatePPSVerificationThresholds(
            strategy, dispersionThreshold_, deviationThreshold_, mnThreshold_
        );
    }

    /// @inheritdoc ISuperVaultAggregator
    function changePrimaryStrategist(address strategy, address newStrategist) external {
        SUPER_VAULT_REGISTRY.changePrimaryStrategist(strategy, newStrategist);
    }

    /// @inheritdoc ISuperVaultAggregator
    function proposeChangePrimaryStrategist(address strategy, address newStrategist) external {
        SUPER_VAULT_REGISTRY.proposeChangePrimaryStrategist(strategy, newStrategist);
    }

    /// @inheritdoc ISuperVaultAggregator
    function executeChangePrimaryStrategist(address strategy) external {
        SUPER_VAULT_REGISTRY.executeChangePrimaryStrategist(strategy);
    }

    /*//////////////////////////////////////////////////////////////
                        HOOK VALIDATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultAggregator
    function setHooksRootUpdateTimelock(uint256 newTimelock) external {
        HOOK_FACTORY.setHooksRootUpdateTimelock(newTimelock);
    }

    /// @inheritdoc ISuperVaultAggregator
    function proposeGlobalHooksRoot(bytes32 newRoot) external {
        HOOK_FACTORY.proposeGlobalHooksRoot(newRoot);
    }

    /// @inheritdoc ISuperVaultAggregator
    function executeGlobalHooksRootUpdate() external {
        HOOK_FACTORY.executeGlobalHooksRootUpdate();
    }

    /// @inheritdoc ISuperVaultAggregator
    function setGlobalHooksRootVetoStatus(bool vetoed) external {
        HOOK_FACTORY.setGlobalHooksRootVetoStatus(vetoed);
    }

    /// @inheritdoc ISuperVaultAggregator
    function proposeStrategyHooksRoot(address strategy, bytes32 newRoot) external {
        HOOK_FACTORY.proposeStrategyHooksRoot(strategy, newRoot);
    }

    /// @inheritdoc ISuperVaultAggregator
    function executeStrategyHooksRootUpdate(address strategy) external {
        HOOK_FACTORY.executeStrategyHooksRootUpdate(strategy);
    }

    /// @inheritdoc ISuperVaultAggregator
    function setStrategyHooksRootVetoStatus(address strategy, bool vetoed) external {
        HOOK_FACTORY.setStrategyHooksRootVetoStatus(strategy, vetoed);
    }

    /// @inheritdoc ISuperVaultAggregator
    function isGlobalHooksRootVetoed() external view returns (bool vetoed) {
        return HOOK_FACTORY.isGlobalHooksRootVetoed();
    }

    /// @inheritdoc ISuperVaultAggregator
    function isStrategyHooksRootVetoed(address strategy) external view returns (bool vetoed) {
        return HOOK_FACTORY.isStrategyHooksRootVetoed(strategy);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultAggregator
    function getCurrentNonce() external view returns (uint256) {
        return SUPER_VAULT_FACTORY.getCurrentNonce();
    }

    /// @inheritdoc ISuperVaultAggregator
    function getHooksRootUpdateTimelock() external view returns (uint256) {
        return HOOK_FACTORY.getHooksRootUpdateTimelock();
    }

    /// @inheritdoc ISuperVaultAggregator
    function getPPS(address strategy) external view returns (uint256 pps) {
        return SUPER_VAULT_REGISTRY.getPPS(strategy);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getPPSWithStdDev(address strategy) external view returns (uint256 pps, uint256 ppsStdev) {
        return SUPER_VAULT_REGISTRY.getPPSWithStdDev(strategy);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getLastUpdateTimestamp(address strategy) external view returns (uint256 timestamp) {
        return SUPER_VAULT_REGISTRY.getLastUpdateTimestamp(strategy);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getMinUpdateInterval(address strategy) external view returns (uint256 interval) {
        return SUPER_VAULT_REGISTRY.getMinUpdateInterval(strategy);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getMaxStaleness(address strategy) external view returns (uint256 staleness) {
        return SUPER_VAULT_REGISTRY.getMaxStaleness(strategy);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getPPSVerificationThresholds(address strategy)
        external
        view
        returns (uint256 dispersionThreshold, uint256 deviationThreshold, uint256 mnThreshold)
    {
        return SUPER_VAULT_REGISTRY.getPPSVerificationThresholds(strategy);
    }

    /// @inheritdoc ISuperVaultAggregator
    function isStrategyPaused(address strategy) external view returns (bool isPaused) {
        return SUPER_VAULT_REGISTRY.isStrategyPaused(strategy);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getUpkeepBalance(address strategist) external view returns (uint256 balance) {
        return SUPER_VAULT_REGISTRY.getUpkeepBalance(strategist);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getAuthorizedCallers(address strategy) external view returns (address[] memory callers) {
        return SUPER_VAULT_REGISTRY.getAuthorizedCallers(strategy);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getMainStrategist(address strategy) external view returns (address strategist) {
        return SUPER_VAULT_REGISTRY.getMainStrategist(strategy);
    }

    /// @inheritdoc ISuperVaultAggregator
    function isMainStrategist(address strategist, address strategy) external view returns (bool) {
        return SUPER_VAULT_REGISTRY.isMainStrategist(strategist, strategy);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getSecondaryStrategists(address strategy) external view returns (address[] memory) {
        return SUPER_VAULT_REGISTRY.getSecondaryStrategists(strategy);
    }

    /// @inheritdoc ISuperVaultAggregator
    function isSecondaryStrategist(address strategist, address strategy) external view returns (bool) {
        return SUPER_VAULT_REGISTRY.isSecondaryStrategist(strategist, strategy);
    }

    /// @inheritdoc ISuperVaultAggregator
    function isAnyStrategist(address strategist, address strategy) external view returns (bool) {
        return SUPER_VAULT_REGISTRY.isAnyStrategist(strategist, strategy);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getAllSuperVaults() external view returns (address[] memory) {
        return SUPER_VAULT_FACTORY.getAllSuperVaults();
    }

    /// @inheritdoc ISuperVaultAggregator
    function superVaults(uint256 index) external view returns (address) {
        return SUPER_VAULT_FACTORY.superVaults(index);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getAllSuperVaultStrategies() external view returns (address[] memory) {
        return SUPER_VAULT_FACTORY.getAllSuperVaultStrategies();
    }

    /// @inheritdoc ISuperVaultAggregator
    function superVaultStrategies(uint256 index) external view returns (address) {
        return SUPER_VAULT_FACTORY.superVaultStrategies(index);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getAllSuperVaultEscrows() external view returns (address[] memory) {
        return SUPER_VAULT_FACTORY.getAllSuperVaultEscrows();
    }

    /// @inheritdoc ISuperVaultAggregator
    function superVaultEscrows(uint256 index) external view returns (address) {
        return SUPER_VAULT_FACTORY.superVaultEscrows(index);
    }

    /// @inheritdoc ISuperVaultAggregator
    function validateHook(
        address strategy,
        bytes calldata hookArgs,
        bytes32[] calldata globalProof,
        bytes32[] calldata strategyProof
    )
        external
        view
        returns (bool isValid)
    {
        return HOOK_FACTORY.validateHook(strategy, hookArgs, globalProof, strategyProof);
    }

    /// @inheritdoc ISuperVaultAggregator
    function validateHooks(
        address strategy,
        bytes[] calldata hooksArgs,
        bytes32[][] calldata globalProofs,
        bytes32[][] calldata strategyProofs
    )
        external
        view
        returns (bool[] memory validHooks)
    {
        return HOOK_FACTORY.validateHooks(strategy, hooksArgs, globalProofs, strategyProofs);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getGlobalHooksRoot() external view returns (bytes32 root) {
        return HOOK_FACTORY.getGlobalHooksRoot();
    }

    /// @inheritdoc ISuperVaultAggregator
    function getProposedGlobalHooksRoot() external view returns (bytes32 root, uint256 effectiveTime) {
        return HOOK_FACTORY.getProposedGlobalHooksRoot();
    }

    /// @inheritdoc ISuperVaultAggregator
    function isGlobalHooksRootActive() external view returns (bool) {
        return HOOK_FACTORY.isGlobalHooksRootActive();
    }

    /// @inheritdoc ISuperVaultAggregator
    function getStrategyHooksRoot(address strategy) external view returns (bytes32 root) {
        return HOOK_FACTORY.getStrategyHooksRoot(strategy);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getProposedStrategyHooksRoot(address strategy)
        external
        view
        returns (bytes32 root, uint256 effectiveTime)
    {
        return HOOK_FACTORY.getProposedStrategyHooksRoot(strategy);
    }
}
