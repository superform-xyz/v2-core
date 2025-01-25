// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC4626 } from "@openzeppelin/contracts/token/ERC4626/extensions/ERC4626.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ISuperVault } from "../interfaces/ISuperVault.sol";
import { ISuperHook } from "../interfaces/ISuperHook.sol";
import { ISuperRegistry } from "../interfaces/ISuperRegistry.sol";
import { ISuperExecutor } from "../interfaces/ISuperExecutor.sol";
import { IHookDataEncoderRegistry } from "../interfaces/IHookDataEncoderRegistry.sol";
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";
import { HookWhitelist } from "../utils/HookWhitelist.sol";
import { YieldSourceOracleLibrary } from "../libraries/YieldSourceOracleLibrary.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";


/**
 * @title SuperVault
 * @notice An advanced ERC-4626 vault implementation that enables dynamic allocation across multiple yield sources
 * @dev Key features:
 *      1. Multi-source yield management through configurable hook pathways
 *      2. Automated accounting via SuperLedger integration
 *      3. Flexible allocation strategies with safety bounds
 *      4. Whitelisted hooks for security
 */
contract SuperVault is ISuperVault, ERC4626, SuperRegistryImplementer, HookWhitelist {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Address authorized to manage yield sources and allocation strategies
    address public strategist;

    /// @notice Immutable configuration parameters set at deployment
    VaultConfig public immutable vaultConfig;

    /// @notice List of yield sources currently integrated with the vault
    address[] public activeYieldSources;
    
    /// @notice Mapping of yield source to its configuration
    mapping(address => YieldSourceConfig) public yieldSourceConfigs;

    /// @notice Registry for standardizing hook data encoding across different vault types
    IHookDataEncoderRegistry public immutable encoderRegistry;

    /// @notice Central registry for contract addresses and configurations
    ISuperRegistry public immutable superRegistry;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Ensures only the strategist can call protected functions
    modifier onlyStrategist() {
        if (msg.sender != strategist) revert ONLY_STRATEGIST();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the SuperVault with its core configuration
     * @param asset_ The underlying asset token this vault manages
     * @param name_ Name of the vault share token
     * @param symbol_ Symbol of the vault share token
     * @param superRegistry_ Address of the central registry contract
     * @param vaultConfig_ Initial configuration parameters
     * @param timelockDuration_ Duration for hook whitelist changes
     * @dev Validates configuration parameters and sets up initial state
     */
    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        ISuperRegistry superRegistry_,
        VaultConfig memory vaultConfig_,
        uint256 timelockDuration_
    ) ERC4626(asset_) ERC20(name_, symbol_) SuperRegistryImplementer(superRegistry_) HookWhitelist(timelockDuration_) {
        if (
            vaultConfig_.vaultThreshold == 0 || 
            vaultConfig_.maxAllocationRate > 10000 ||
            vaultConfig_.vaultCap == 0 ||
            vaultConfig_.superVaultCap == 0 ||
            vaultConfig_.vaultCap > vaultConfig_.superVaultCap
        ) {
            revert INVALID_CONFIG();
        }

        superRegistry = superRegistry_;
        encoderRegistry = IHookDataEncoderRegistry(superRegistry_.getAddress("HOOK_DATA_ENCODER_REGISTRY"));
        vaultConfig = vaultConfig_;
        strategist = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Transfers strategist role to a new address
     * @dev Emits StrategistTransferred event on successful transfer
     * @param newStrategist Address of the new strategist
     */
    function transferStrategist(address newStrategist) external onlyStrategist {
        if (newStrategist == address(0)) revert INVALID_STRATEGIST();
        address oldStrategist = strategist;
        strategist = newStrategist;
        emit StrategistTransferred(oldStrategist, newStrategist);
    }

    /**
     * @notice Adds a new yield source to the vault
     * @dev Performs validation checks and sets up hook pathways
     * @param yieldSource Address of the yield source to add
     * @param oracle Price oracle for the yield source
     * @param vaultType Type identifier for the yield source
     * @param depositHooks Sequence of hooks for deposits
     * @param redeemHooks Sequence of hooks for redemptions
     */
    function addYieldSource(
        address yieldSource,
        address oracle,
        string calldata vaultType,
        address[] calldata depositHooks,
        address[] calldata redeemHooks
    ) external override onlyStrategist {
        if (yieldSource == address(0)) revert INVALID_YIELD_SOURCE();
        if (oracle == address(0)) revert INVALID_ORACLE();
        if (bytes(vaultType).length == 0) revert INVALID_TYPE();
        if (yieldSourceConfigs[yieldSource].oracle != address(0)) {
            revert YIELD_SOURCE_ALREADY_ADDED();
        }

        _validateHookPathways(depositHooks, redeemHooks);
        _validateNoDuplicateHooks(depositHooks);
        _validateNoDuplicateHooks(redeemHooks);

        yieldSourceConfigs[yieldSource] = YieldSourceConfig({
            oracle: oracle,
            vaultType: vaultType,
            depositHooks: depositHooks,
            redeemHooks: redeemHooks,
            allocation: 0,
            isActive: true
        });

        activeYieldSources.push(yieldSource);
        
        emit YieldSourceAdded(yieldSource, oracle, vaultType, depositHooks, redeemHooks);
    }

    function removeYieldSource(address yieldSource) external override onlyStrategist {
        YieldSourceConfig storage config = yieldSourceConfigs[yieldSource];
        if (!config.isActive) revert INVALID_YIELD_SOURCE();
        if (config.allocation > 0) revert INVALID_ALLOCATION();
        
        // Remove from active yield sources
        for (uint256 i = 0; i < activeYieldSources.length;) {
            if (activeYieldSources[i] == yieldSource) {
                activeYieldSources[i] = activeYieldSources[activeYieldSources.length - 1];
                activeYieldSources.pop();
                break;
            }
            unchecked { ++i; }
        }
        
        config.isActive = false;
        emit YieldSourceRemoved(yieldSource);
    }

    function updateYieldSourcePathway(
        address yieldSource,
        address[] calldata depositHooks,
        address[] calldata redeemHooks
    ) external override onlyStrategist {
        YieldSourceConfig storage config = yieldSourceConfigs[yieldSource];
        if (config.oracle == address(0)) revert YIELD_SOURCE_NOT_FOUND();

        _validateHookPathways(depositHooks, redeemHooks);

        config.depositHooks = depositHooks;
        config.redeemHooks = redeemHooks;
        
        emit HooksUpdated(yieldSource, depositHooks, redeemHooks);
    }

    function executeHookPathway(
        address yieldSource,
        address[] memory hooks,
        bytes[] memory hookData
    ) external override returns (bool) {
        YieldSourceConfig storage config = yieldSourceConfigs[yieldSource];
        if (config.oracle == address(0)) revert YIELD_SOURCE_NOT_FOUND();
        if (hookData.length != hooks.length) revert INVALID_HOOKS();
        
        // Verify all hooks are whitelisted and match either deposit or redeem pathway
        _validateHookSequence(yieldSource, hooks);
        
        // Execute hooks in sequence
        for (uint256 i = 0; i < hooks.length;) {
            address prevHook = i > 0 ? hooks[i-1] : address(0);
            
            ISuperHook hook = ISuperHook(hooks[i]);
            
            // Pre-execution
            hook.preExecute(prevHook, hookData[i]);
            
            // Build and execute
            Execution[] memory executions = hook.build(prevHook, hookData[i]);
            if (executions.length > 0) {
                ISuperExecutor executor = ISuperExecutor(superRegistry.getAddress("SUPER_EXECUTOR"));
                try executor.execute(abi.encode(executions)) {
                } catch {
                    revert EXECUTION_FAILED();
                }
            }
            
            // Post-execution
            hook.postExecute(prevHook, hookData[i]);
            
            unchecked { ++i; }
        }
        
        return true;
    }

    function setTargetProportions(uint256[] calldata proportions) external override onlyStrategist {
        if (proportions.length != activeYieldSources.length) revert INVALID_ALLOCATION();
        
        uint256 total;
        for (uint256 i = 0; i < proportions.length;) {
            if (proportions[i] > vaultConfig.maxAllocationRate) revert INVALID_ALLOCATION();
            total += proportions[i];
            unchecked { ++i; }
        }
        if (total != 10000) revert INVALID_ALLOCATION();
        
        for (uint256 i = 0; i < proportions.length;) {
            address yieldSource = activeYieldSources[i];
            YieldSourceConfig storage config = yieldSourceConfigs[yieldSource];
            if (config.isActive) {
                config.allocation = proportions[i];
            }
            unchecked { ++i; }
        }
        
        emit TargetProportionsSet(proportions);
    }

    function getVaultConfig() external view override returns (VaultConfig memory) {
        return vaultConfig;
    }

    function getYieldSourceConfig(address yieldSource) external view override returns (YieldSourceConfig memory) {
        return yieldSourceConfigs[yieldSource];
    }

    function getActiveYieldSources() external view override returns (address[] memory active) {
        uint256 count;
        for (uint256 i = 0; i < activeYieldSources.length;) {
            if (yieldSourceConfigs[activeYieldSources[i]].isActive) {
                count++;
            }
            unchecked { ++i; }
        }
        
        active = new address[](count);
        uint256 j;
        for (uint256 i = 0; i < activeYieldSources.length;) {
            if (yieldSourceConfigs[activeYieldSources[i]].isActive) {
                active[j] = activeYieldSources[i];
                j++;
            }
            unchecked { ++i; }
        }
    }

    function getYieldSourceHooks(address yieldSource, bool isDeposit) external view override returns (address[] memory) {
        YieldSourceConfig storage config = yieldSourceConfigs[yieldSource];
        return isDeposit ? config.depositHooks : config.redeemHooks;
    }

    function maxDeposit(address receiver) public view override(IERC4626, ERC4626) returns (uint256) {
        // Only limit based on the total SuperVault cap
        return vaultConfig.superVaultCap - totalAssets();
    }

    function totalAssets() public view virtual override returns (uint256) {
        uint256 total;
        for (uint256 i = 0; i < activeYieldSources.length;) {
            address yieldSource = activeYieldSources[i];
            YieldSourceConfig storage config = yieldSourceConfigs[yieldSource];
            if (config.isActive) {
                total += YieldSourceOracleLibrary.getTVL(config.oracle, yieldSource);
            }
            unchecked { ++i; }
        }
        return total;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal override {
        // Transfer assets from caller
        IERC20(asset()).safeTransferFrom(caller, address(this), assets);

        uint256[] memory depositAmounts = _calculateDepositAmounts(assets);
        _executeDeposits(receiver, caller, depositAmounts);

        _mint(receiver, shares);
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        uint256[] memory withdrawAmounts = _calculateWithdrawAmounts(assets);
        _executeWithdraws(receiver, owner, withdrawAmounts);

        _burn(owner, shares);
    }

    function _calculateDepositAmounts(uint256 assets) internal view returns (uint256[] memory) {
        uint256[] memory depositAmounts = new uint256[](activeYieldSources.length);
        for (uint256 i = 0; i < activeYieldSources.length;) {
            YieldSourceConfig storage config = yieldSourceConfigs[activeYieldSources[i]];
            depositAmounts[i] = (assets * config.allocation) / 10000;
            unchecked { ++i; }
        }
        return depositAmounts;
    }

    function _executeDeposits(
        address receiver,
        address caller,
        uint256[] memory depositAmounts
    ) internal {
        for (uint256 i = 0; i < activeYieldSources.length;) {
            if (depositAmounts[i] > 0) {
                // Check if deposit amount exceeds the per-vault cap
                if (depositAmounts[i] > vaultConfig.vaultCap) {
                    revert INVALID_ALLOCATION();
                }
                
                YieldSourceConfig storage config = yieldSourceConfigs[activeYieldSources[i]];
                bytes[] memory hookData = _encodeHookData(
                    activeYieldSources[i],
                    receiver,
                    caller,
                    depositAmounts[i],
                    true
                );
                _executeHookPathway(activeYieldSources[i], config.depositHooks, hookData);
            }
            unchecked { ++i; }
        }
    }

    function _calculateWithdrawAmounts(uint256 assets) internal view returns (uint256[] memory) {
        uint256[] memory withdrawAmounts = new uint256[](activeYieldSources.length);
        for (uint256 i = 0; i < activeYieldSources.length;) {
            YieldSourceConfig storage config = yieldSourceConfigs[activeYieldSources[i]];
            withdrawAmounts[i] = (assets * config.allocation) / 10000;
            unchecked { ++i; }
        }
        return withdrawAmounts;
    }

    function _executeWithdraws(
        address receiver,
        address owner,
        uint256[] memory withdrawAmounts
    ) internal {
        for (uint256 i = 0; i < activeYieldSources.length;) {
            if (withdrawAmounts[i] > 0) {
                YieldSourceConfig storage config = yieldSourceConfigs[activeYieldSources[i]];
                bytes[] memory hookData = _encodeHookData(
                    activeYieldSources[i],
                    receiver,
                    owner,
                    withdrawAmounts[i],
                    false
                );
                _executeHookPathway(activeYieldSources[i], config.redeemHooks, hookData);
            }
            unchecked { ++i; }
        }
    }

    function _encodeHookData(
        address yieldSource,
        address receiver,
        address owner,
        uint256 amount,
        bool isDeposit
    ) internal view returns (bytes[] memory) {
        YieldSourceConfig storage config = yieldSourceConfigs[yieldSource];
        address[] memory hooks = isDeposit ? config.depositHooks : config.redeemHooks;
        bytes[] memory hookData = new bytes[](hooks.length);

        _encodeOperationHookData(
            config,
            yieldSource,
            receiver,
            owner,
            amount,
            isDeposit,
            hooks,
            hookData
        );

        // Always encode SuperLedger hook data as the last hook
        hookData[hooks.length - 1] = _encodeSuperLedgerHookData(
            isDeposit ? receiver : owner,
            config.oracle,
            yieldSource,
            amount
        );

        return hookData;
    }

    function _validateHookSequence(address yieldSource, address[] memory hooks) internal view {
        YieldSourceConfig storage config = yieldSourceConfigs[yieldSource];
        
        // Check if hooks match deposit pathway
        if (hooks.length == config.depositHooks.length) {
            if (_validateHookPathwayMatch(hooks, config.depositHooks)) {
                return;
            }
        }
        
        // Check if hooks match redeem pathway
        if (hooks.length == config.redeemHooks.length) {
            if (_validateHookPathwayMatch(hooks, config.redeemHooks)) {
                return;
            }
        }
        
        revert INVALID_HOOKS();
    }

    function _validateHookPathwayMatch(
        address[] memory hooks,
        address[] memory pathwayHooks
    ) internal view returns (bool) {
        for (uint256 i = 0; i < hooks.length;) {
            if (!isHookWhitelisted(hooks[i])) revert HOOK_NOT_WHITELISTED();
            if (hooks[i] != pathwayHooks[i]) {
                return false;
            }
            unchecked { ++i; }
        }
        return true;
    }

    function _validateHookPathways(address[] calldata depositHooks, address[] calldata redeemHooks) internal view {
        if (depositHooks.length == 0 || redeemHooks.length == 0) revert INVALID_HOOKS();

        _validateSuperLedgerHook(depositHooks, redeemHooks);
        _validateHooksWhitelisted(depositHooks);
        _validateHooksWhitelisted(redeemHooks);
    }

    function _validateSuperLedgerHook(address[] calldata depositHooks, address[] calldata redeemHooks) internal view {
        address superLedgerHook = superRegistry.getAddress("SUPER_LEDGER_HOOK");
        if (depositHooks[depositHooks.length - 1] != superLedgerHook || 
            redeemHooks[redeemHooks.length - 1] != superLedgerHook) {
            revert INVALID_HOOKS();
        }
    }

    function _validateHooksWhitelisted(address[] calldata hooks) internal view {
        for (uint256 i = 0; i < hooks.length;) {
            if (!isHookWhitelisted(hooks[i])) revert HOOK_NOT_WHITELISTED();
            unchecked { ++i; }
        }
    }

    function _validateNoDuplicateHooks(address[] calldata hooks) internal pure {
        for (uint256 i = 0; i < hooks.length - 1;) {
            for (uint256 j = i + 1; j < hooks.length;) {
                if (hooks[i] == hooks[j]) revert DUPLICATE_HOOKS();
                unchecked { ++j; }
            }
            unchecked { ++i; }
        }
    }

    function _getAddress(bytes32 id_) internal view returns (address) {
        return superRegistry.getAddress(id_);
    }

    function _encodeOperationHookData(
        YieldSourceConfig storage config,
        address yieldSource,
        address receiver,
        address owner,
        uint256 amount,
        bool isDeposit,
        address[] memory hooks,
        bytes[] memory hookData
    ) internal view {
        for (uint256 i = 0; i < hooks.length - 1;) {
            try encoderRegistry.getEncoder(config.vaultType) returns (IHookDataEncoder encoder) {
                hookData[i] = isDeposit ? 
                    encoder.encodeDepositData(yieldSource, receiver, amount, "") :
                    encoder.encodeWithdrawData(yieldSource, receiver, owner, amount, "");
            } catch {
                revert ENCODER_NOT_FOUND();
            }
            unchecked { ++i; }
        }
    }

    function _encodeSuperLedgerHookData(
        address user,
        address oracle,
        address yieldSource,
        uint256 amount
    ) internal pure returns (bytes memory) {
        return abi.encode(user, oracle, yieldSource, amount);
    }

    /// @notice Execute a sequence of hooks for a yield source
    /// @param yieldSource Address of the yield source
    /// @param hooks Array of hook addresses to execute
    /// @param hookData Array of encoded data for each hook
    /// @return success Whether the execution was successful
    function _executeHookPathway(
        address yieldSource,
        address[] memory hooks,
        bytes[] memory hookData
    ) internal returns (bool) {
        YieldSourceConfig storage config = yieldSourceConfigs[yieldSource];
        if (config.oracle == address(0)) revert YIELD_SOURCE_NOT_FOUND();
        if (hookData.length != hooks.length) revert INVALID_HOOKS();
        
        // Verify all hooks are whitelisted and match either deposit or redeem pathway
        _validateHookSequence(yieldSource, hooks);
        
        // Execute hooks in sequence
        for (uint256 i = 0; i < hooks.length;) {
            address prevHook = i > 0 ? hooks[i-1] : address(0);
            
            ISuperHook hook = ISuperHook(hooks[i]);
            
            // Pre-execution
            hook.preExecute(prevHook, hookData[i]);
            
            // Build and execute
            Execution[] memory executions = hook.build(prevHook, hookData[i]);
            if (executions.length > 0) {
                ISuperExecutor executor = ISuperExecutor(superRegistry.getAddress("SUPER_EXECUTOR"));
                try executor.execute(abi.encode(executions)) {
                } catch {
                    revert EXECUTION_FAILED();
                }
            }
            
            // Post-execution
            hook.postExecute(prevHook, hookData[i]);
            
            unchecked { ++i; }
        }
        
        return true;
    }
} 