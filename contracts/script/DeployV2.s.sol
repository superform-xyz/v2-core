// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Script } from "forge-std/Script.sol";
import "forge-std/console2.sol";

// Superform
import { ISuperDeployer } from "./utils/ISuperDeployer.sol";

import { Configuration } from "./utils/Configuration.sol";

import { SuperExecutor } from "../src/executors/SuperExecutor.sol";
import { SuperRbac } from "../src/settings/SuperRbac.sol";
import { SuperRegistry } from "../src/settings/SuperRegistry.sol";
import { SuperLedger } from "../src/accounting/SuperLedger.sol";
import { ISuperLedger } from "../src/interfaces/accounting/ISuperLedger.sol";
import { AcrossBridgeGateway } from "../src/bridges/AcrossBridgeGateway.sol";
import { SuperPositionsMock } from "../src/accounting/SuperPositionsMock.sol";
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
import { ERC4626YieldSourceOracle } from "../src/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { ERC5115YieldSourceOracle } from "../src/accounting/oracles/ERC5115YieldSourceOracle.sol";

contract DeployV2 is Script, Configuration {
    mapping(uint64 chainId => mapping(string contractName => address contractAddress)) public contractAddresses;

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
        address superLedger;
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
            _deploy(chainId);

            // Configure contracts
            _configure(chainId);

            // Setup SuperLedger
            _setupSuperLedger(chainId);

            unchecked {
                ++i;
            }
        }

        vm.stopBroadcast();
    }

    function _getDeployer() internal view returns (ISuperDeployer deployer) {
        return ISuperDeployer(configuration.deployer);
    }

    function _deploy(uint64 chainId) internal {
        DeployedContracts memory deployedContracts;
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
            abi.encodePacked(type(SuperExecutor).creationCode, abi.encode(deployedContracts.superRegistry))
        );

        // Deploy SuperRbac
        deployedContracts.superRbac = __deployContract(
            deployer,
            "SuperRbac",
            chainId,
            __getSalt(configuration.owner, configuration.deployer, "SuperRbac"),
            abi.encodePacked(type(SuperRbac).creationCode, abi.encode(configuration.owner))
        );

        // Deploy SuperLedger
        deployedContracts.superLedger = __deployContract(
            deployer,
            "SuperLedger",
            chainId,
            __getSalt(configuration.owner, configuration.deployer, "SuperLedger"),
            abi.encodePacked(type(SuperLedger).creationCode, abi.encode(deployedContracts.superRegistry))
        );

        // Deploy SuperPositionMock
        _deploySuperPositions(deployer, deployedContracts.superRegistry, configuration.superPositions, chainId);

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
        _deployHooks(deployer, deployedContracts.superRegistry, chainId);

        // Deploy Oracles
        _deployOracles(deployer, chainId);
    }

    function _configure(uint64 chainId) internal {
        SuperRbac superRbac = SuperRbac(_getContract(chainId, "SuperRbac"));
        SuperRegistry superRegistry = SuperRegistry(_getContract(chainId, "SuperRegistry"));

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
        superRbac.setRole(_getContract(chainId, "AcrossBridgeGateway"), superRbac.BRIDGE_GATEWAY(), true);
        superRbac.setRole(configuration.owner, superRbac.EXECUTOR_CONFIGURATOR(), true);
        superRbac.setRole(configuration.owner, superRbac.SENTINEL_CONFIGURATOR(), true);

        // -- SuperRegistry
        superRegistry.setAddress(superRegistry.SUPER_LEDGER_ID(), _getContract(chainId, "SuperLedger"));
        superRegistry.setAddress(
            superRegistry.SUPER_POSITION_SENTINEL_ID(), _getContract(chainId, "SuperPositionSentinel")
        );
        superRegistry.setAddress(superRegistry.SUPER_RBAC_ID(), _getContract(chainId, "SuperRbac"));
        superRegistry.setAddress(superRegistry.ACROSS_GATEWAY_ID(), _getContract(chainId, "AcrossBridgeGateway"));
        superRegistry.setAddress(superRegistry.SUPER_EXECUTOR_ID(), _getContract(chainId, "SuperExecutor"));
        superRegistry.setAddress(superRegistry.PAYMASTER_ID(), configuration.paymaster);
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getContract(uint64 chainId, string memory contractName) internal view returns (address) {
        return contractAddresses[chainId][contractName];
    }

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
        contractAddresses[chainId][contractName] = deployedAddr;
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
        oracles[0] = OracleDeployment("ERC4626YieldSourceOracle", type(ERC4626YieldSourceOracle).creationCode);
        oracles[1] = OracleDeployment("ERC5115YieldSourceOracle", type(ERC5115YieldSourceOracle).creationCode);

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

    function _setupSuperLedger(uint64 chainId) private {
        address[] memory mainHooks = new address[](2);

        mainHooks[0] = _getContract(chainId, "Deposit4626VaultHook");
        mainHooks[1] = _getContract(chainId, "Withdraw4626VaultHook");
        SuperRegistry superRegistry = SuperRegistry(_getContract(chainId, "SuperRegistry"));
        ISuperLedger.HookRegistrationConfig[] memory configs = new ISuperLedger.HookRegistrationConfig[](1);
        configs[0] = ISuperLedger.HookRegistrationConfig({
            mainHooks: mainHooks,
            yieldSourceOracle: _getContract(chainId, "ERC4626YieldSourceOracle"),
            yieldSourceOracleId: bytes32("ERC4626YieldSourceOracle"),
            feePercent: 100,
            vaultShareToken: address(0), // this is auto set because its standardized yield
            feeRecipient: superRegistry.getAddress(superRegistry.PAYMASTER_ID())
        });

        ISuperLedger(_getContract(chainId, "SuperLedger")).setYieldSourceOracles(configs);
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
