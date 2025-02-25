// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Script } from "forge-std/Script.sol";
import "forge-std/console2.sol";

// Superform
import "./DeploySuperDeployer.s.sol";
import { SuperDeployer } from "./utils/SuperDeployer.sol";
import { ISuperDeployer } from "./utils/ISuperDeployer.sol";
import { Configuration } from "./utils/Configuration.sol";

import { SuperExecutor } from "../src/core/executors/SuperExecutor.sol";
import { SuperRegistry } from "../src/core/settings/SuperRegistry.sol";
import { HooksRegistry } from "../src/core/hooks/HooksRegistry.sol";
import { SuperLedger } from "../src/core/accounting/SuperLedger.sol";
import { ERC1155Ledger } from "../src/core/accounting/ERC1155Ledger.sol";
import { SuperLedgerConfiguration } from "../src/core/accounting/SuperLedgerConfiguration.sol";
import { ISuperLedgerConfiguration } from "../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { AcrossReceiveFundsAndExecuteGateway } from "../src/core/bridges/AcrossReceiveFundsAndExecuteGateway.sol";
import { DeBridgeReceiveFundsAndExecuteGateway } from "../src/core/bridges/DeBridgeReceiveFundsAndExecuteGateway.sol";

import { SuperPositionsMock } from "../test/mocks/SuperPositionsMock.sol";

import { MockValidatorModule } from "../test/mocks/MockValidatorModule.sol";

// -- hooks
// ---- | swappers
import { SwapOdosHook } from "../src/core/hooks/swappers/odos/SwapOdosHook.sol";

// ---- | tokens
import { ApproveERC20Hook } from "../src/core/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { TransferERC20Hook } from "../src/core/hooks/tokens/erc20/TransferERC20Hook.sol";
// ---- | claim
import { FluidClaimRewardHook } from "../src/core/hooks/claim/fluid/FluidClaimRewardHook.sol";
import { GearboxClaimRewardHook } from "../src/core/hooks/claim/gearbox/GearboxClaimRewardHook.sol";
import { YearnClaimOneRewardHook } from "../src/core/hooks/claim/yearn/YearnClaimOneRewardHook.sol";
import { YearnClaimAllRewardsHook } from "../src/core/hooks/claim/yearn/YearnClaimAllRewardsHook.sol";
// ---- | vault
import { Deposit4626VaultHook } from "../src/core/hooks/vaults/4626/Deposit4626VaultHook.sol";
import { Withdraw4626VaultHook } from "../src/core/hooks/vaults/4626/Withdraw4626VaultHook.sol";
import { Deposit5115VaultHook } from "../src/core/hooks/vaults/5115/Deposit5115VaultHook.sol";
import { Withdraw5115VaultHook } from "../src/core/hooks/vaults/5115/Withdraw5115VaultHook.sol";
import { RequestDeposit7540VaultHook } from "../src/core/hooks/vaults/7540/RequestDeposit7540VaultHook.sol";
import { RequestWithdraw7540VaultHook } from "../src/core/hooks/vaults/7540/RequestWithdraw7540VaultHook.sol";
// ---- | stake
import { GearboxStakeHook } from "../src/core/hooks/stake/gearbox/GearboxStakeHook.sol";
import { GearboxUnstakeHook } from "../src/core/hooks/stake/gearbox/GearboxUnstakeHook.sol";
import { FluidStakeHook } from "../src/core/hooks/stake/fluid/FluidStakeHook.sol";
import { FluidStakeWithPermitHook } from "../src/core/hooks/stake/fluid/FluidStakeWithPermitHook.sol";
import { FluidUnstakeHook } from "../src/core/hooks/stake/fluid/FluidUnstakeHook.sol";
// ---- | bridges
import { AcrossSendFundsAndExecuteOnDstHook } from
    "../src/core/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol";
import { DeBridgeSendFundsAndExecuteOnDstHook } from
    "../src/core/hooks/bridges/debridge/DeBridgeSendFundsAndExecuteOnDstHook.sol";
// ---- | swappers
import { Swap1InchHook } from "../src/core/hooks/swappers/1inch/Swap1InchHook.sol";

// -- oracles
import { ERC4626YieldSourceOracle } from "../src/core/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { ERC5115YieldSourceOracle } from "../src/core/accounting/oracles/ERC5115YieldSourceOracle.sol";
import { SuperOracle } from "../src/core/accounting/oracles/SuperOracle.sol";
import { ERC7540YieldSourceOracle } from "../src/core/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { FluidYieldSourceOracle } from "../src/core/accounting/oracles/FluidYieldSourceOracle.sol";

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
        address superLedger;
        address pendleLedger;
        address superLedgerConfiguration;
        address superPositionSentinel;
        address acrossReceiveFundsGateway;
        address acrossReceiveFundsAndExecuteGateway;
        address debridgeReceiveFundsAndExecuteGateway;
        address mockValidatorModule;
        address oracleRegistry;
        address hooksRegistry;
    }

    modifier broadcast(uint256 env) {
        if (env == 1) {
            (address deployer,) = deriveRememberKey(MNEMONIC, 0);
            console2.log("Deployer: ", deployer);
            vm.startBroadcast(deployer);
            _;
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            _;
            vm.stopBroadcast();
        }
    }

    function run(uint256 env, uint64 chainId, string memory saltNamespace) public broadcast(env) {
        _setConfiguration(env, saltNamespace);
        console2.log("Deploying on chainId: ", chainId);

        // deploy contracts
        ISuperDeployer deployer = _getDeployer();
        if (address(deployer) == address(0) || address(deployer).code.length == 0) {
            bytes32 salt = "SuperformSuperDeployer.v1.0.5";
            address expectedAddr = vm.computeCreate2Address(salt, keccak256(type(SuperDeployer).creationCode));
            console2.log("SuperDeployer expected address:", expectedAddr);
            if (expectedAddr.code.length > 0) {
                console2.log("SuperDeployer already deployed at:", expectedAddr);
                return;
            }
            SuperDeployer superDeployer = new SuperDeployer{ salt: salt }();
            console2.log("SuperDeployer deployed at:", address(superDeployer));
           
            configuration.deployer = address(superDeployer);
        }

        _deploy(chainId);

        // Configure contracts
        _configure(chainId);

        // Setup SuperLedger
        _setupSuperLedgerConfiguration(chainId);
    }

    function _getDeployer() internal view returns (ISuperDeployer deployer) {
        return ISuperDeployer(configuration.deployer);
    }

    function _deploy(uint64 chainId) internal {
        DeployedContracts memory deployedContracts;

        // retrieve deployer
        ISuperDeployer deployer = _getDeployer();

        // Deploy SuperRegistry
        deployedContracts.superRegistry = __deployContract(
            deployer,
            SUPER_REGISTRY_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, SUPER_REGISTRY_KEY),
            abi.encodePacked(type(SuperRegistry).creationCode, abi.encode(configuration.owner))
        );

        deployedContracts.hooksRegistry = __deployContract(
            deployer,
            HOOKS_REGISTRY_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, HOOKS_REGISTRY_KEY),
            abi.encodePacked(type(HooksRegistry).creationCode, abi.encode(deployedContracts.superRegistry))
        );

        // Deploy SuperOracle
        deployedContracts.oracleRegistry = __deployContract(
            deployer,
            SUPER_ORACLE_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, SUPER_ORACLE_KEY),
            abi.encodePacked(
                type(SuperOracle).creationCode,
                abi.encode(configuration.owner, new address[](0), new uint256[](0), new address[](0))
            )
        );

        // Deploy SuperExecutor
        deployedContracts.superExecutor = __deployContract(
            deployer,
            SUPER_EXECUTOR_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, SUPER_EXECUTOR_KEY),
            abi.encodePacked(type(SuperExecutor).creationCode, abi.encode(deployedContracts.superRegistry))
        );

        // Deploy SuperLedgerConfiguration
        deployedContracts.superLedgerConfiguration = __deployContract(
            deployer,
            SUPER_LEDGER_CONFIGURATION_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, SUPER_LEDGER_CONFIGURATION_KEY),
            abi.encodePacked(type(SuperLedgerConfiguration).creationCode, abi.encode(deployedContracts.superRegistry))
        );

        // Deploy SuperLedger
        deployedContracts.superLedger = __deployContract(
            deployer,
            SUPER_LEDGER_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, SUPER_LEDGER_KEY),
            abi.encodePacked(type(SuperLedger).creationCode, abi.encode(deployedContracts.superLedgerConfiguration))
        );

        // Deploy ERC1155Ledger
        deployedContracts.pendleLedger = __deployContract(
            deployer,
            ERC1155_LEDGER_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, ERC1155_LEDGER_KEY),
            abi.encodePacked(type(ERC1155Ledger).creationCode, abi.encode(deployedContracts.superLedgerConfiguration))
        );

        // Deploy SuperPositionMock
        _deploySuperPositions(deployer, deployedContracts.superRegistry, configuration.superPositions, chainId);

        // Deploy AcrossReceiveFundsAndExecuteGateway
        deployedContracts.acrossReceiveFundsAndExecuteGateway = __deployContract(
            deployer,
            ACROSS_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, ACROSS_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_KEY),
            abi.encodePacked(
                type(AcrossReceiveFundsAndExecuteGateway).creationCode,
                abi.encode(deployedContracts.superRegistry, configuration.acrossSpokePoolV3s[chainId], ENTRY_POINT)
            )
        );

        // Deploy DeBridgeReceiveFundsAndExecuteGateway
        deployedContracts.debridgeReceiveFundsAndExecuteGateway = __deployContract(
            deployer,
            DEBRIDGE_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, DEBRIDGE_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_KEY),
            abi.encodePacked(
                type(DeBridgeReceiveFundsAndExecuteGateway).creationCode,
                abi.encode(deployedContracts.superRegistry, configuration.debridgeGates[chainId], ENTRY_POINT)
            )
        );

        // Deploy MockValidatorModule
        deployedContracts.mockValidatorModule = __deployContract(
            deployer,
            MOCK_VALIDATOR_MODULE_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, MOCK_VALIDATOR_MODULE_KEY),
            type(MockValidatorModule).creationCode
        );

        // Deploy Hooks
        _deployHooks(deployer, deployedContracts.superRegistry, chainId);

        // Deploy Oracles
        _deployOracles(deployer, deployedContracts.superRegistry, chainId);
    }

    function _configure(uint64 chainId) internal {
        SuperRegistry superRegistry = SuperRegistry(_getContract(chainId, SUPER_REGISTRY_KEY));

        // -- Roles
        // ---- | set external roles
        uint256 len = configuration.externalRoles.length;
        for (uint256 i; i < len;) {
            RolesData memory _roleInfo = configuration.externalRoles[i];
            superRegistry.setRole(_roleInfo.addr, _roleInfo.role, true);

            unchecked {
                ++i;
            }
        }
        // ---- | set deployed contracts roles
        superRegistry.setRole(
            _getContract(chainId, ACROSS_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_KEY), keccak256("BRIDGE_GATEWAY"), true
        );

        // -- SuperRegistry
        superRegistry.setAddress(keccak256(bytes(SUPER_LEDGER_ID)), _getContract(chainId, SUPER_LEDGER_KEY));
        superRegistry.setAddress(
            keccak256(bytes(SUPER_LEDGER_CONFIGURATION_ID)), _getContract(chainId, SUPER_LEDGER_CONFIGURATION_KEY)
        );
        superRegistry.setAddress(
            keccak256(bytes(ACROSS_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_ID)),
            _getContract(chainId, ACROSS_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_KEY)
        );

        superRegistry.setAddress(keccak256(bytes(SUPER_EXECUTOR_ID)), _getContract(chainId, SUPER_EXECUTOR_KEY));
        superRegistry.setAddress(keccak256(bytes(SUPER_BUNDLER_ID)), configuration.bundler);
        superRegistry.setAddress(keccak256(bytes(ORACLE_REGISTRY_ID)), _getContract(chainId, SUPER_ORACLE_KEY));
        superRegistry.setAddress(keccak256(bytes(SUPER_REGISTRY_ID)), _getContract(chainId, SUPER_REGISTRY_KEY));
        superRegistry.setAddress(keccak256(bytes(TREASURY_ID)), configuration.treasury);
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

    function __getSalt(address eoa, address deployer, string memory name) private view returns (bytes32) {
        return keccak256(abi.encodePacked(eoa, deployer, SALT_NAMESPACE, bytes(string.concat(name, ".v0.1"))));
    }

    function _deployHooks(
        ISuperDeployer deployer,
        address registry,
        uint64 chainId
    )
        private
        returns (address[] memory hookAddresses)
    {
        uint256 len = 21;
        HookDeployment[] memory hooks = new HookDeployment[](len);
        hookAddresses = new address[](len);

        hooks[0] = HookDeployment(
            ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY,
            abi.encodePacked(
                type(AcrossSendFundsAndExecuteOnDstHook).creationCode,
                abi.encode(registry, configuration.owner, configuration.acrossSpokePoolV3s[chainId])
            )
        );
        hooks[1] = HookDeployment(
            DEBRIDGE_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY,
            abi.encodePacked(
                type(DeBridgeSendFundsAndExecuteOnDstHook).creationCode,
                abi.encode(registry, configuration.owner, configuration.debridgeGates[chainId])
            )
        );
        hooks[2] = HookDeployment(
            FLUID_CLAIM_REWARD_HOOK_KEY,
            abi.encodePacked(type(FluidClaimRewardHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[3] = HookDeployment(
            GEARBOX_CLAIM_REWARD_HOOK_KEY,
            abi.encodePacked(type(GearboxClaimRewardHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[4] = HookDeployment(
            YEARN_CLAIM_ALL_REWARDS_HOOK_KEY,
            abi.encodePacked(type(YearnClaimAllRewardsHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[5] = HookDeployment(
            YEARN_CLAIM_ONE_REWARD_HOOK_KEY,
            abi.encodePacked(type(YearnClaimOneRewardHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[6] = HookDeployment(
            APPROVE_ERC20_HOOK_KEY,
            abi.encodePacked(type(ApproveERC20Hook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[7] = HookDeployment(
            TRANSFER_ERC20_HOOK_KEY,
            abi.encodePacked(type(TransferERC20Hook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[8] = HookDeployment(
            DEPOSIT_4626_VAULT_HOOK_KEY,
            abi.encodePacked(type(Deposit4626VaultHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[9] = HookDeployment(
            WITHDRAW_4626_VAULT_HOOK_KEY,
            abi.encodePacked(type(Withdraw4626VaultHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[10] = HookDeployment(
            DEPOSIT_5115_VAULT_HOOK_KEY,
            abi.encodePacked(type(Deposit5115VaultHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[11] = HookDeployment(
            WITHDRAW_5115_VAULT_HOOK_KEY,
            abi.encodePacked(type(Withdraw5115VaultHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[12] = HookDeployment(
            REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY,
            abi.encodePacked(type(RequestDeposit7540VaultHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[13] = HookDeployment(
            REQUEST_WITHDRAW_7540_VAULT_HOOK_KEY,
            abi.encodePacked(type(RequestWithdraw7540VaultHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[14] = HookDeployment(
            GEARBOX_STAKE_HOOK_KEY,
            abi.encodePacked(type(GearboxStakeHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[15] = HookDeployment(
            GEARBOX_UNSTAKE_HOOK_KEY,
            abi.encodePacked(type(GearboxUnstakeHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[16] = HookDeployment(
            FLUID_STAKE_HOOK_KEY,
            abi.encodePacked(type(FluidStakeHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[17] = HookDeployment(
            FLUID_STAKE_WITH_PERMIT_HOOK_KEY,
            abi.encodePacked(type(FluidStakeWithPermitHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[18] = HookDeployment(
            FLUID_UNSTAKE_HOOK_KEY,
            abi.encodePacked(type(FluidUnstakeHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[19] = HookDeployment(
            SWAP_1INCH_HOOK_KEY,
            abi.encodePacked(
                type(Swap1InchHook).creationCode,
                abi.encode(registry, configuration.owner, configuration.aggregationRouters[chainId])
            )
        );

        hooks[20] = HookDeployment(
            SWAP_ODOS_HOOK_KEY,
            abi.encodePacked(
                type(SwapOdosHook).creationCode,
                abi.encode(registry, configuration.owner, configuration.odosRouters[chainId])
            )
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
        address registry,
        uint64 chainId
    )
        private
        returns (address[] memory oracleAddresses)
    {
        uint256 len = 4;
        OracleDeployment[] memory oracles = new OracleDeployment[](len);
        oracleAddresses = new address[](len);

        oracles[0] = OracleDeployment(
            ERC4626_YIELD_SOURCE_ORACLE_KEY,
            abi.encodePacked(type(ERC4626YieldSourceOracle).creationCode, abi.encode(registry))
        );
        oracles[1] = OracleDeployment(
            ERC5115_YIELD_SOURCE_ORACLE_KEY,
            abi.encodePacked(type(ERC5115YieldSourceOracle).creationCode, abi.encode(registry))
        );
        oracles[2] = OracleDeployment(
            ERC7540_YIELD_SOURCE_ORACLE_KEY,
            abi.encodePacked(type(ERC7540YieldSourceOracle).creationCode, abi.encode(registry))
        );
        oracles[3] = OracleDeployment(
            FLUID_YIELD_SOURCE_ORACLE_KEY,
            abi.encodePacked(type(FluidYieldSourceOracle).creationCode, abi.encode(registry))
        );

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

    function _setupSuperLedgerConfiguration(uint64 chainId) private {
        SuperRegistry superRegistry = SuperRegistry(_getContract(chainId, SUPER_REGISTRY_KEY));
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceOracle: _getContract(chainId, ERC4626_YIELD_SOURCE_ORACLE_KEY),
            feePercent: 100,
            feeRecipient: superRegistry.getTreasury(),
            ledger: _getContract(chainId, SUPER_LEDGER_KEY)
        });

        ISuperLedgerConfiguration(_getContract(chainId, SUPER_LEDGER_CONFIGURATION_KEY)).setYieldSourceOracles(configs);
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

    function _exportContract(
        string memory chainName,
        string memory contractName,
        address addr,
        uint64 chainId
    )
        private
    {
        string memory json = vm.serializeAddress("EXPORTS", contractName, addr);
        string memory root = vm.projectRoot();
        string memory chainOutputFolder = string(abi.encodePacked("/script/output/"));

        // For local runs, use local directory
        if (!vm.envOr("CI", false)) {
            chainOutputFolder =
                string(abi.encodePacked(chainOutputFolder, "local/", vm.toString(uint256(chainId)), "/"));
        } else {
            // For CI runs, use branch-specific directory
            string memory branchName = vm.envString("GITHUB_REF_NAME");

            chainOutputFolder =
                string(abi.encodePacked(chainOutputFolder, branchName, "/", vm.toString(uint256(chainId)), "/"));
        }

        // Create directory if it doesn't exist
        vm.createDir(string(abi.encodePacked(root, chainOutputFolder)), true);

        // Write to {ChainName}-latest.json
        string memory outputPath = string(abi.encodePacked(root, chainOutputFolder, chainName, "-latest.json"));
        vm.writeJson(json, outputPath);
    }
}
