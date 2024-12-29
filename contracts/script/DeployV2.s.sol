// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Script } from "forge-std/Script.sol";
import "forge-std/console2.sol";

// Superform
import { ISuperDeployer } from "./utils/ISuperDeployer.sol";

import { Configuration } from "./utils/Configuration.sol";

import { SuperExecutorV2 } from "../src/executors/SuperExecutorV2.sol";
import { SuperRbac } from "../src/settings/SuperRbac.sol";
import { SharedState } from "../src/state/SharedState.sol";
import { SuperRegistry } from "../src/settings/SuperRegistry.sol";
import { SuperActions } from "../src/strategies/SuperActions.sol";
import { ISuperActions } from "../src/interfaces/strategies/ISuperActions.sol";
import { AcrossBridgeGateway } from "../src/bridges/AcrossBridgeGateway.sol";
import { SuperPositionsMock } from "../src/strategies/SuperPositionsMock.sol";
import { SuperPositionSentinel } from "../src/sentinels/SuperPositionSentinel.sol";

// -- hooks
// ---- | tokens
import { ApproveERC20Hook } from "../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { TransferERC20Hook } from "../src/hooks/tokens/erc20/TransferERC20Hook.sol";
// ---- | claim
import { FluidClaimRewardHook } from "../src/hooks/claim/fluid/FluidClaimRewardHook.sol";
import { GearboxClaimRewardHook } from "../src/hooks/claim/gearbox/GearboxClaimRewardHook.sol";
import { SomelierClaimAllRewardsHook } from "../src/hooks/claim/somelier/SomelierClaimAllRewardsHook.sol";
import { SomelierClaimOneRewardHook } from "../src/hooks/claim/somelier/SomelierClaimOneRewardHook.sol";
import { YearnClaimOneRewardHook } from "../src/hooks/claim/yearn/YearnClaimOneRewardHook.sol";
import { YearnClaimAllRewardsHook } from "../src/hooks/claim/yearn/YearnClaimAllRewardsHook.sol";
// ---- | vault
import { Deposit4626VaultHook } from "../src/hooks/vaults/4626/Deposit4626VaultHook.sol";
import { Withdraw4626VaultHook } from "../src/hooks/vaults/4626/Withdraw4626VaultHook.sol";
import { Deposit5115VaultHook } from "../src/hooks/vaults/5115/Deposit5115VaultHook.sol";
import { Withdraw5115VaultHook } from "../src/hooks/vaults/5115/Withdraw5115VaultHook.sol";
import { RequestDeposit7540VaultHook } from "../src/hooks/vaults/7540/RequestDeposit7540VaultHook.sol";
import { RequestWithdraw7540VaultHook } from "../src/hooks/vaults/7540/RequestWithdraw7540VaultHook.sol";
// ---- | bridges
import { AcrossExecuteOnDestinationHook } from "../src/hooks/bridges/across/AcrossExecuteOnDestinationHook.sol";
// -- oracles
import { DepositRedeem4626ActionOracle } from "../src/strategies/oracles/DepositRedeem4626ActionOracle.sol";
import { DepositRedeem5115ActionOracle } from "../src/strategies/oracles/DepositRedeem5115ActionOracle.sol";

contract DeployV2 is Script, Configuration {
    string private constant SALT_NAMESPACE = "Superform.v2.0.1";

    struct HookDeployment {
        string name;
        bytes creationCode;
    }

    // leave it separately from `HookDeployment` to avoid confusion
    struct OracleDeployment {
        string name;
        bytes creationCode;
    }

    struct DeployedContracts {
        address superExecutor;
        address superRegistry;
        address superRbac;
        address superActions;
        address superPositionSentinel;
        address sharedState;
        address acrossBridgeGateway;
    }

    function run(uint64[] memory chainIds) public {
        vm.startBroadcast();
        _setAllChainsConfiguration();
        uint256 len = chainIds.length;
        for (uint256 i; i < len;) {
            uint64 chainId = chainIds[i];
            console2.log("Deploying on chainId: ", chainId);

            // set chain configuration
            _setConfiguration(chainId);

            // deploy contracts
            (
                DeployedContracts memory deployedContracts,
                address[] memory hookAddresses,
                address[] memory oracleAddresses
            ) = _deploy(chainId);

            // configure contracts
            _configure(deployedContracts);

            // Register SuperActions
            _registerSuperActions(deployedContracts.superActions, hookAddresses, oracleAddresses);

            unchecked {
                ++i;
            }
        }

        vm.stopBroadcast();
    }

    function _getDeployer() internal view returns (ISuperDeployer deployer) {
        return ISuperDeployer(configuration.deployer);
    }

    mapping(uint64 chainId => string chainName) private chainNames;

    function _deploy(uint64 chainId)
        internal
        returns (
            DeployedContracts memory deployedContracts,
            address[] memory hookAddresses,
            address[] memory oracleAddresses
        )
    {
        // set configuration
        _setConfiguration(chainId);

        // retrieve deployer
        ISuperDeployer deployer = _getDeployer();

        // Deploy SuperRegistry
        deployedContracts.superRegistry = __deployContract(
            deployer,
            "SuperRegistry",
            chainId,
            __getSalt(configuration.owner, configuration.deployer, "SuperRegistry"),
            abi.encodePacked(type(SuperRegistry).creationCode, abi.encode(configuration.owner))
        );

        // Deploy SuperExecutor
        deployedContracts.superExecutor = __deployContract(
            deployer,
            "SuperExecutor",
            chainId,
            __getSalt(configuration.owner, configuration.deployer, "SuperExecutor"),
            abi.encodePacked(type(SuperExecutorV2).creationCode, abi.encode(deployedContracts.superRegistry))
        );

        // Deploy SuperRbac
        deployedContracts.superRbac = __deployContract(
            deployer,
            "SuperRbac",
            chainId,
            __getSalt(configuration.owner, configuration.deployer, "SuperRbac"),
            abi.encodePacked(type(SuperRbac).creationCode, abi.encode(configuration.owner))
        );

        // Deploy SuperActions
        deployedContracts.superActions = __deployContract(
            deployer,
            "SuperActions",
            chainId,
            __getSalt(configuration.owner, configuration.deployer, "SuperActions"),
            abi.encodePacked(type(SuperActions).creationCode, abi.encode(deployedContracts.superRegistry))
        );

        // Deploy SuperPositionMock
        _deploySuperPositions(deployer, deployedContracts.superRegistry, configuration.superPositions, chainId);

        // Deploy SharedState
        deployedContracts.sharedState = __deployContract(
            deployer,
            "SharedState",
            chainId,
            __getSalt(configuration.owner, configuration.deployer, "SharedState"),
            type(SharedState).creationCode
        );

        // Deploy SuperPositionSentinel
        deployedContracts.superPositionSentinel = __deployContract(
            deployer,
            "SuperPositionSentinel",
            chainId,
            __getSalt(configuration.owner, configuration.deployer, "SuperPositionSentinel"),
            abi.encodePacked(type(SuperPositionSentinel).creationCode, abi.encode(deployedContracts.superRegistry))
        );

        // Deploy AcrossBridgeGateway
        deployedContracts.acrossBridgeGateway = __deployContract(
            deployer,
            "AcrossBridgeGateway",
            chainId,
            __getSalt(configuration.owner, configuration.deployer, "AcrossBridgeGateway"),
            abi.encodePacked(
                type(AcrossBridgeGateway).creationCode,
                abi.encode(deployedContracts.superRegistry, configuration.acrossSpokePoolV3)
            )
        );

        // Deploy Hooks
        hookAddresses = _deployHooks(deployer, deployedContracts.superRegistry, chainId);

        // Deploy Oracles
        oracleAddresses = _deployOracles(deployer, chainId);
    }

    function _configure(DeployedContracts memory deployedContracts) internal {
        SuperRbac superRbac = SuperRbac(deployedContracts.superRbac);
        SuperRegistry superRegistry = SuperRegistry(deployedContracts.superRegistry);

        // -- Roles
        // ---- | set external roles (ex: SUPER_ACTIONS_CONFIGURATOR for another address)
        uint256 len = configuration.externalRoles.length;
        for (uint256 i; i < len;) {
            RolesData memory _roleInfo = configuration.externalRoles[i];
            superRbac.setRole(_roleInfo.addr, _roleInfo.role, true);

            unchecked {
                ++i;
            }
        }
        // ---- | set deployed contracts roles
        superRbac.setRole(deployedContracts.acrossBridgeGateway, superRbac.BRIDGE_GATEWAY(), true);
        superRbac.setRole(configuration.owner, superRbac.EXECUTOR_CONFIGURATOR(), true);
        superRbac.setRole(configuration.owner, superRbac.SENTINEL_CONFIGURATOR(), true);
        superRbac.setRole(configuration.owner, superRbac.STRATEGY_ORACLE_CONFIGURATOR(), true);
        superRbac.setRole(configuration.owner, superRbac.SUPER_ACTIONS_CONFIGURATOR(), true);

        // -- SuperRegistry
        superRegistry.setAddress(superRegistry.SUPER_ACTIONS_ID(), deployedContracts.superActions);
        superRegistry.setAddress(superRegistry.SUPER_POSITION_SENTINEL_ID(), deployedContracts.superPositionSentinel);
        superRegistry.setAddress(superRegistry.SUPER_RBAC_ID(), deployedContracts.superRbac);
        superRegistry.setAddress(superRegistry.ACROSS_GATEWAY_ID(), deployedContracts.acrossBridgeGateway);
        superRegistry.setAddress(superRegistry.SUPER_EXECUTOR_ID(), deployedContracts.superExecutor);
        superRegistry.setAddress(superRegistry.SHARED_STATE_ID(), deployedContracts.sharedState);
        superRegistry.setAddress(superRegistry.PAYMASTER_ID(), configuration.paymaster);
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    function __deployContract(
        ISuperDeployer deployer,
        string memory contractName,
        uint64 chainId,
        bytes32 salt,
        bytes memory creationCode
    )
        private
        returns (address)
    {
        address expectedAddr = deployer.getDeployed(salt);
        if (expectedAddr.code.length > 0) {
            console2.log("[!] %s already deployed at:", contractName, expectedAddr);
            console2.log("      skipping...");
            return expectedAddr;
        }

        address deployedAddr = deployer.deploy(salt, creationCode);
        console2.log("  [+] %s deployed at:", contractName, deployedAddr);

        _exportContract(chainNames[chainId], contractName, deployedAddr, chainId);

        return deployedAddr;
    }

    function __getSalt(address eoa, address deployer, string memory name) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(eoa, deployer, bytes(SALT_NAMESPACE), bytes(string.concat(name, ".v0.1"))));
    }

    function _deployHooks(
        ISuperDeployer deployer,
        address registry,
        uint64 chainId
    )
        private
        returns (address[] memory hookAddresses)
    {
        uint256 len = 15;
        HookDeployment[] memory hooks = new HookDeployment[](len);
        hookAddresses = new address[](len);
        hooks[0] = HookDeployment(
            "AcrossExecuteOnDestinationHook",
            abi.encodePacked(
                type(AcrossExecuteOnDestinationHook).creationCode,
                abi.encode(registry, configuration.owner, configuration.acrossSpokePoolV3)
            )
        );
        hooks[1] = HookDeployment(
            "FluidClaimRewardHook",
            abi.encodePacked(type(FluidClaimRewardHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[2] = HookDeployment(
            "GearboxClaimRewardHook",
            abi.encodePacked(type(GearboxClaimRewardHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[3] = HookDeployment(
            "SomelierClaimAllRewardsHook",
            abi.encodePacked(type(SomelierClaimAllRewardsHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[4] = HookDeployment(
            "SomelierClaimOneRewardHook",
            abi.encodePacked(type(SomelierClaimOneRewardHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[5] = HookDeployment(
            "YearnClaimAllRewardsHook",
            abi.encodePacked(type(YearnClaimAllRewardsHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[6] = HookDeployment(
            "YearnClaimOneRewardHook",
            abi.encodePacked(type(YearnClaimOneRewardHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[7] = HookDeployment(
            "ApproveERC20Hook",
            abi.encodePacked(type(ApproveERC20Hook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[8] = HookDeployment(
            "TransferERC20Hook",
            abi.encodePacked(type(TransferERC20Hook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[9] = HookDeployment(
            "Deposit4626VaultHook",
            abi.encodePacked(type(Deposit4626VaultHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[10] = HookDeployment(
            "Withdraw4626VaultHook",
            abi.encodePacked(type(Withdraw4626VaultHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[11] = HookDeployment(
            "Deposit5115VaultHook",
            abi.encodePacked(type(Deposit5115VaultHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[12] = HookDeployment(
            "Withdraw5115VaultHook",
            abi.encodePacked(type(Withdraw5115VaultHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[13] = HookDeployment(
            "RequestDeposit7540VaultHook",
            abi.encodePacked(type(RequestDeposit7540VaultHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[14] = HookDeployment(
            "RequestWithdraw7540VaultHook",
            abi.encodePacked(type(RequestWithdraw7540VaultHook).creationCode, abi.encode(registry, configuration.owner))
        );

        for (uint256 i = 0; i < len;) {
            HookDeployment memory hook = hooks[i];
            hookAddresses[i] = __deployContract(
                deployer,
                hook.name,
                chainId,
                __getSalt(configuration.owner, configuration.deployer, hook.name),
                hook.creationCode
            );

            unchecked {
                ++i;
            }
        }
    }

    function _deployOracles(
        ISuperDeployer deployer,
        uint64 chainId
    )
        private
        returns (address[] memory oracleAddresses)
    {
        uint256 len = 2;
        OracleDeployment[] memory oracles = new OracleDeployment[](len);
        oracleAddresses = new address[](len);
        oracles[0] = OracleDeployment("DepositRedeem4626ActionOracle", type(DepositRedeem4626ActionOracle).creationCode);
        oracles[1] = OracleDeployment("DepositRedeem5115ActionOracle", type(DepositRedeem5115ActionOracle).creationCode);

        for (uint256 i = 0; i < len;) {
            OracleDeployment memory oracle = oracles[i];
            oracleAddresses[i] = __deployContract(
                deployer,
                oracle.name,
                chainId,
                __getSalt(configuration.owner, configuration.deployer, oracle.name),
                oracle.creationCode
            );

            unchecked {
                ++i;
            }
        }
    }

    function _registerSuperActions(
        address superActions,
        address[] memory hookAddresses,
        address[] memory oracleAddresses
    )
        private
    {
        // Configure ERC4626 yield source
        ISuperActions.YieldSourceConfig memory erc4626Config = ISuperActions.YieldSourceConfig({
            yieldSourceId: "ERC4626",
            metadataOracle: address(oracleAddresses[0]),
            actions: new ISuperActions.ActionConfig[](2)
        });

        // Deposit action (approve + deposit)
        address[] memory depositHooks = new address[](2);
        depositHooks[0] = hookAddresses[7];
        depositHooks[1] = hookAddresses[9];

        erc4626Config.actions[0] = ISuperActions.ActionConfig({
            hooks: depositHooks,
            actionType: ISuperActions.ActionType.INFLOW,
            shareDeltaHookIndex: 1 // deposit4626VaultHook provides share delta
         });

        // Withdraw action
        address[] memory withdrawHooks = new address[](1);
        withdrawHooks[0] = hookAddresses[10];

        erc4626Config.actions[1] = ISuperActions.ActionConfig({
            hooks: withdrawHooks,
            actionType: ISuperActions.ActionType.OUTFLOW,
            shareDeltaHookIndex: 0 // withdraw4626VaultHook provides share delta
         });

        // Register ERC4626 actions
        ISuperActions(superActions).registerYieldSourceAndActions(erc4626Config);
    }

    function _deploySuperPositions(
        ISuperDeployer deployer,
        address registry,
        SuperPositionData[] memory superPositions,
        uint64 chainId
    )
        private
    {
        uint256 len = superPositions.length;
        for (uint256 i; i < len;) {
            SuperPositionData memory _superPosition = superPositions[i];
            string memory name = string.concat("SuperPositionsMock.", _superPosition.name);
            __deployContract(
                deployer,
                name,
                chainId,
                __getSalt(configuration.owner, configuration.deployer, name),
                abi.encodePacked(type(SuperPositionsMock).creationCode, registry, _superPosition.decimals)
            );

            unchecked {
                ++i;
            }
        }
    }

    function _exportContract(string memory name, string memory label, address addr, uint64 chainId) private {
        string memory json = vm.serializeAddress("EXPORTS", label, addr);
        string memory root = vm.projectRoot();

        string memory chainOutputFolder =
            string(abi.encodePacked("/script/output/", vm.toString(uint256(chainId)), "/"));

        if (vm.envOr("FOUNDRY_EXPORTS_OVERWRITE_LATEST", false)) {
            vm.writeJson(json, string(abi.encodePacked(root, chainOutputFolder, name, "-latest.json")));
        } else {
            vm.writeJson(
                json,
                string(abi.encodePacked(root, chainOutputFolder, name, "-", vm.toString(block.timestamp), ".json"))
            );
        }
    }
}
