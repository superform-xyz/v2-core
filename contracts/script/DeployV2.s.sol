// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Script } from "forge-std/Script.sol";
import "forge-std/console2.sol";

// Superform
import { ISuperDeployer } from "./utils/ISuperDeployer.sol";

import { Data } from "./utils/Data.sol";
import { SuperRbac } from "../src/settings/SuperRbac.sol";
import { SharedState } from "../src/state/SharedState.sol";
import { SuperRegistry } from "../src/settings/SuperRegistry.sol";
import { SuperActions } from "../src/strategies/SuperActions.sol";
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

/**
 * SuperRegistry
 *     SuperRbac
 *     SuperActions
 *     SuperPositionsMock
 *     SharedState
 *     SuperPositionSentinel
 *     AcrossBridgeGateway
 *
 *     Hooks:
 *         AcrossExecuteOnDestinationHook
 *         FluidClaimRewardHook
 *         GearboxClaimRewardHook
 *         SomelierClaimAllRewardsHook
 *         SomelierClaimOneRewardHook
 *         YearnClaimAllRewardsHook
 *         YearnClaimOneRewardHook
 *         ApproveERC20Hook
 *         TransferERC20Hook
 *         Deposit4626VaultHook
 *         Withdraw4626VaultHook
 *         Deposit5115VaultHook
 *         Withdraw5115VaultHook
 *         RequestDeposit7540VaultHook
 *         RequestWithdraw7540VaultHook
 *
 *     Oracles:
 *         DepositRedeem4626ActionOracle
 *         DepositRedeem5115ActionOracle
 */
contract DeployV2 is Script, Data {
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
        address superRegistry;
        address superRbac;
        address superActions;
        address superPositionSentinel;
        address sharedState;
        address acrossBridgeGateway;
    }

    function run(uint64[] memory chainIds) public {
        vm.startBroadcast();

        uint256 len = chainIds.length;
        for (uint256 i; i < len;) {
            uint64 chainId = chainIds[i];
            console2.log("Deploying on chainId: ", chainId);

            // set chain configuration
            _setConfiguration(chainId);

            // deploy contracts
            DeployedContracts memory deployedContracts = _deploy();

            // configure contracts
            _configure(deployedContracts);

            unchecked {
                ++i;
            }
        }

        vm.stopBroadcast();
    }

    function _getDeployer() internal view returns (ISuperDeployer deployer) {
        return ISuperDeployer(configuration.deployer);
    }


    function _deploy() private returns(DeployedContracts memory deployedContracts) {
        // set configuration
        _setConfiguration(uint8(DeployChain.TESTNET1));

        // retrieve deployer
        ISuperDeployer deployer = _getDeployer();

        // Deploy SuperRegistry
        deployedContracts.superRegistry = __deployContract(
            deployer,
            "SuperRegistry",
            __getSalt(configuration.owner, configuration.deployer, "SuperRegistry"),
            abi.encodePacked(type(SuperRegistry).creationCode, configuration.owner)
        );

        // Deploy SuperRbac
        deployedContracts.superRbac = __deployContract(
            deployer,
            "SuperRbac",
            __getSalt(configuration.owner, configuration.deployer, "SuperRbac"),
            abi.encodePacked(type(SuperRbac).creationCode, configuration.owner)
        );

        // Deploy SuperActions
        deployedContracts.superActions = __deployContract(
            deployer,
            "SuperActions",
            __getSalt(configuration.owner, configuration.deployer, "SuperActions"),
            abi.encodePacked(type(SuperActions).creationCode, deployedContracts.superRegistry)
        );

        // Deploy SuperPositionMock
        _deploySuperPositions(deployer, deployedContracts.superRegistry, configuration.superPositions);

        // Deploy SharedState
        deployedContracts.sharedState = __deployContract(
            deployer,
            "SharedState",
            __getSalt(configuration.owner, configuration.deployer, "SharedState"),
            type(SharedState).creationCode
        );

        // Deploy SuperPositionSentinel
        deployedContracts.superPositionSentinel = __deployContract(
            deployer,
            "SuperPositionSentinel",
            __getSalt(configuration.owner, configuration.deployer, "SuperPositionSentinel"),
            abi.encodePacked(type(SuperPositionSentinel).creationCode, deployedContracts.superRegistry)
        );

        // Deploy AcrossBridgeGateway
        deployedContracts.acrossBridgeGateway = __deployContract(
            deployer,
            "AcrossBridgeGateway",
            __getSalt(configuration.owner, configuration.deployer, "AcrossBridgeGateway"),
            abi.encodePacked(type(AcrossBridgeGateway).creationCode, deployedContracts.superRegistry, configuration.acrossSpokePoolV3)
        );

        // Deploy Hooks
        _deployHooks(deployer, deployedContracts.superRegistry);

        // Deploy Oracles
        _deployOracles(deployer, deployedContracts.superRegistry);
    }
    function _configure(DeployedContracts memory deployedContracts) private {
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
        superRegistry.setAddress(superRegistry.SUPER_RBAC_ID(), deployedContracts.superRbac);
        superRegistry.setAddress(superRegistry.SHARED_STATE_ID(), deployedContracts.sharedState);
        superRegistry.setAddress(superRegistry.SUPER_ACTIONS_ID(), deployedContracts.superActions);
        superRegistry.setAddress(superRegistry.ACROSS_GATEWAY_ID(), deployedContracts.acrossBridgeGateway);
        superRegistry.setAddress(superRegistry.SUPER_POSITION_SENTINEL_ID(), deployedContracts.superPositionSentinel);
        superRegistry.setAddress(superRegistry.PAYMASTER_ID(), configuration.paymaster);
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    function _deploySuperPositions(
        ISuperDeployer deployer,
        address registry,
        SuperPositionData[] memory superPositions
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
                __getSalt(configuration.owner, configuration.deployer, name),
                abi.encodePacked(type(SuperPositionsMock).creationCode, registry, _superPosition.decimals)
            );

            unchecked {
                ++i;
            }
        }
    }

    function _deployHooks(ISuperDeployer deployer, address registry) private {
        uint256 len = 15;
        HookDeployment[] memory hooks = new HookDeployment[](len);
        hooks[0] = HookDeployment(
            "AcrossExecuteOnDestinationHook",
            abi.encodePacked(
                type(AcrossExecuteOnDestinationHook).creationCode,
                registry,
                configuration.owner,
                configuration.acrossSpokePoolV3
            )
        );
        hooks[1] = HookDeployment(
            "FluidClaimRewardHook",
            abi.encodePacked(type(FluidClaimRewardHook).creationCode, registry, configuration.owner)
        );
        hooks[2] = HookDeployment(
            "GearboxClaimRewardHook",
            abi.encodePacked(type(GearboxClaimRewardHook).creationCode, registry, configuration.owner)
        );
        hooks[3] = HookDeployment(
            "SomelierClaimAllRewardsHook",
            abi.encodePacked(type(SomelierClaimAllRewardsHook).creationCode, registry, configuration.owner)
        );
        hooks[4] = HookDeployment(
            "SomelierClaimOneRewardHook",
            abi.encodePacked(type(SomelierClaimOneRewardHook).creationCode, registry, configuration.owner)
        );
        hooks[5] = HookDeployment(
            "YearnClaimAllRewardsHook",
            abi.encodePacked(type(YearnClaimAllRewardsHook).creationCode, registry, configuration.owner)
        );
        hooks[6] = HookDeployment(
            "YearnClaimOneRewardHook",
            abi.encodePacked(type(YearnClaimOneRewardHook).creationCode, registry, configuration.owner)
        );
        hooks[7] = HookDeployment(
            "ApproveERC20Hook", abi.encodePacked(type(ApproveERC20Hook).creationCode, registry, configuration.owner)
        );
        hooks[8] = HookDeployment(
            "TransferERC20Hook", abi.encodePacked(type(TransferERC20Hook).creationCode, registry, configuration.owner)
        );
        hooks[9] = HookDeployment(
            "Deposit4626VaultHook",
            abi.encodePacked(type(Deposit4626VaultHook).creationCode, registry, configuration.owner)
        );
        hooks[10] = HookDeployment(
            "Withdraw4626VaultHook",
            abi.encodePacked(type(Withdraw4626VaultHook).creationCode, registry, configuration.owner)
        );
        hooks[11] = HookDeployment(
            "Deposit5115VaultHook",
            abi.encodePacked(type(Deposit5115VaultHook).creationCode, registry, configuration.owner)
        );
        hooks[12] = HookDeployment(
            "Withdraw5115VaultHook",
            abi.encodePacked(type(Withdraw5115VaultHook).creationCode, registry, configuration.owner)
        );
        hooks[13] = HookDeployment(
            "RequestDeposit7540VaultHook",
            abi.encodePacked(type(RequestDeposit7540VaultHook).creationCode, registry, configuration.owner)
        );
        hooks[14] = HookDeployment(
            "RequestWithdraw7540VaultHook",
            abi.encodePacked(type(RequestWithdraw7540VaultHook).creationCode, registry, configuration.owner)
        );

        for (uint256 i = 0; i < len;) {
            HookDeployment memory hook = hooks[i];
            __deployContract(
                deployer,
                hook.name,
                __getSalt(configuration.owner, configuration.deployer, hook.name),
                hook.creationCode
            );

            unchecked {
                ++i;
            }
        }
    }

    function _deployOracles(ISuperDeployer deployer, address registry) private {
        uint256 len = 2;
        OracleDeployment[] memory oracles = new OracleDeployment[](len);
        oracles[0] = OracleDeployment("DepositRedeem4626ActionOracle", type(DepositRedeem4626ActionOracle).creationCode);
        oracles[1] = OracleDeployment("DepositRedeem5115ActionOracle", type(DepositRedeem5115ActionOracle).creationCode);

        for (uint256 i = 0; i < len;) {
            OracleDeployment memory oracle = oracles[i];
            __deployContract(
                deployer,
                oracle.name,
                __getSalt(configuration.owner, configuration.deployer, oracle.name),
                oracle.creationCode
            );

            unchecked {
                ++i;
            }
        }
    }

    function __deployContract(
        ISuperDeployer deployer,
        string memory contractName,
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
        return deployedAddr;
    }

    function __getSalt(address eoa, address deployer, string memory name) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(eoa, deployer, bytes(SALT_NAMESPACE), bytes(string.concat(name, ".v0.1"))));
    }
}
