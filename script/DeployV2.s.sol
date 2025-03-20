// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Script } from "forge-std/Script.sol";
import "forge-std/console2.sol";

// Superform
import { SuperDeployer } from "./utils/SuperDeployer.sol";
import { ISuperDeployer } from "./utils/ISuperDeployer.sol";
import { Configuration } from "./utils/Configuration.sol";

import { SuperExecutor } from "../src/core/executors/SuperExecutor.sol";
import { SuperRegistry } from "../src/core/settings/SuperRegistry.sol";
import { PeripheryRegistry } from "../src/periphery/PeripheryRegistry.sol";
import { SuperLedger } from "../src/core/accounting/SuperLedger.sol";
import { ERC5115Ledger } from "../src/core/accounting/ERC5115Ledger.sol";
import { SuperLedgerConfiguration } from "../src/core/accounting/SuperLedgerConfiguration.sol";
import { ISuperLedgerConfiguration } from "../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { AcrossReceiveFundsAndExecuteGateway } from "../src/core/bridges/AcrossReceiveFundsAndExecuteGateway.sol";

import { MockValidatorModule } from "../test/mocks/MockValidatorModule.sol";

// -- hooks
// ---- | swappers
import { Swap1InchHook } from "../src/core/hooks/swappers/1inch/Swap1InchHook.sol";
import { SwapOdosHook } from "../src/core/hooks/swappers/odos/SwapOdosHook.sol";
import { ApproveAndSwapOdosHook } from "../src/core/hooks/swappers/odos/ApproveAndSwapOdosHook.sol";

// ---- | tokens
import { ApproveERC20Hook } from "../src/core/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { TransferERC20Hook } from "../src/core/hooks/tokens/erc20/TransferERC20Hook.sol";
// ---- | claim
import { FluidClaimRewardHook } from "../src/core/hooks/claim/fluid/FluidClaimRewardHook.sol";
import { GearboxClaimRewardHook } from "../src/core/hooks/claim/gearbox/GearboxClaimRewardHook.sol";
import { YearnClaimOneRewardHook } from "../src/core/hooks/claim/yearn/YearnClaimOneRewardHook.sol";
// ---- | vault
import { Deposit4626VaultHook } from "../src/core/hooks/vaults/4626/Deposit4626VaultHook.sol";
import { ApproveAndDeposit4626VaultHook } from "../src/core/hooks/vaults/4626/ApproveAndDeposit4626VaultHook.sol";

import { Redeem4626VaultHook } from "../src/core/hooks/vaults/4626/Redeem4626VaultHook.sol";
import { Deposit5115VaultHook } from "../src/core/hooks/vaults/5115/Deposit5115VaultHook.sol";
import { ApproveAndDeposit5115VaultHook } from "../src/core/hooks/vaults/5115/ApproveAndDeposit5115VaultHook.sol";
import { Redeem5115VaultHook } from "../src/core/hooks/vaults/5115/Redeem5115VaultHook.sol";
import { RequestDeposit7540VaultHook } from "../src/core/hooks/vaults/7540/RequestDeposit7540VaultHook.sol";
import { ApproveAndRequestDeposit7540VaultHook } from
    "../src/core/hooks/vaults/7540/ApproveAndRequestDeposit7540VaultHook.sol";
import { Deposit7540VaultHook } from "../src/core/hooks/vaults/7540/Deposit7540VaultHook.sol";
import { RequestRedeem7540VaultHook } from "../src/core/hooks/vaults/7540/RequestRedeem7540VaultHook.sol";
import { Withdraw7540VaultHook } from "../src/core/hooks/vaults/7540/Withdraw7540VaultHook.sol";

// ---- | stake
import { ApproveAndGearboxStakeHook } from "../src/core/hooks/stake/gearbox/ApproveAndGearboxStakeHook.sol";
import { GearboxStakeHook } from "../src/core/hooks/stake/gearbox/GearboxStakeHook.sol";
import { GearboxUnstakeHook } from "../src/core/hooks/stake/gearbox/GearboxUnstakeHook.sol";
import { FluidStakeHook } from "../src/core/hooks/stake/fluid/FluidStakeHook.sol";
import { FluidUnstakeHook } from "../src/core/hooks/stake/fluid/FluidUnstakeHook.sol";
import { ApproveAndFluidStakeHook } from "../src/core/hooks/stake/fluid/ApproveAndFluidStakeHook.sol";
// ---- | bridges
import { AcrossSendFundsAndExecuteOnDstHook } from
    "../src/core/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol";

// -- oracles
import { ERC4626YieldSourceOracle } from "../src/core/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { ERC5115YieldSourceOracle } from "../src/core/accounting/oracles/ERC5115YieldSourceOracle.sol";
import { SuperOracle } from "../src/core/accounting/oracles/SuperOracle.sol";
import { ERC7540YieldSourceOracle } from "../src/core/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { GearboxYieldSourceOracle } from "../src/core/accounting/oracles/GearboxYieldSourceOracle.sol";
import { FluidYieldSourceOracle } from "../src/core/accounting/oracles/FluidYieldSourceOracle.sol";

// SuperVault

import { SuperVaultFactory } from "../src/periphery/SuperVaultFactory.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";

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
        address mockValidatorModule;
        address oracleRegistry;
        address peripheryRegistry;
        address superVaultFactory;
    }

    struct HookAddresses {
        address approveErc20Hook;
        address transferErc20Hook;
        address deposit4626VaultHook;
        address approveAndDeposit4626VaultHook;
        address redeem4626VaultHook;
        address deposit5115VaultHook;
        address redeem5115VaultHook;
        address approveAndDeposit5115VaultHook;
        address deposit7540VaultHook;
        address requestDeposit7540VaultHook;
        address approveAndRequestDeposit7540VaultHook;
        address requestRedeem7540VaultHook;
        address withdraw7540VaultHook;
        address acrossSendFundsAndExecuteOnDstHook;
        address swap1InchHook;
        address swapOdosHook;
        address approveAndSwapOdosHook;
        address gearboxStakeHook;
        address approveAndGearboxStakeHook;
        address gearboxUnstakeHook;
        address fluidStakeHook;
        address approveAndFluidStakeHook;
        address fluidUnstakeHook;
        address fluidClaimRewardHook;
        address gearboxClaimRewardHook;
        address yearnClaimOneRewardHook;
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

        deployedContracts.peripheryRegistry = __deployContract(
            deployer,
            PERIPHERY_REGISTRY_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, PERIPHERY_REGISTRY_KEY),
            abi.encodePacked(
                type(PeripheryRegistry).creationCode, abi.encode(configuration.owner, configuration.treasury)
            )
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

        // Deploy ERC5115Ledger
        deployedContracts.pendleLedger = __deployContract(
            deployer,
            ERC1155_LEDGER_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, ERC1155_LEDGER_KEY),
            abi.encodePacked(type(ERC5115Ledger).creationCode, abi.encode(deployedContracts.superLedgerConfiguration))
        );

        // Deploy AcrossReceiveFundsAndExecuteGateway
        deployedContracts.acrossReceiveFundsAndExecuteGateway = __deployContract(
            deployer,
            ACROSS_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, ACROSS_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_KEY),
            abi.encodePacked(
                type(AcrossReceiveFundsAndExecuteGateway).creationCode,
                abi.encode(configuration.acrossSpokePoolV3s[chainId], ENTRY_POINT, configuration.bundler)
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

        // Deploy SuperVaultFactory
        deployedContracts.superVaultFactory = __deployContract(
            deployer,
            SUPER_VAULT_FACTORY_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, SUPER_VAULT_FACTORY_KEY),
            abi.encodePacked(type(SuperVaultFactory).creationCode, abi.encode(deployedContracts.peripheryRegistry))
        );

        // Deploy Hooks
        HookAddresses memory hookAddresses = _deployHooks(deployer, deployedContracts.superRegistry, chainId);

        _registerHooks(hookAddresses, PeripheryRegistry(deployedContracts.peripheryRegistry));

        // Deploy Oracles
        _deployOracles(deployer, deployedContracts.superRegistry, chainId);
    }

    function _configure(uint64 chainId) internal {
        SuperRegistry superRegistry = SuperRegistry(_getContract(chainId, SUPER_REGISTRY_KEY));

        superRegistry.setAddress(
            keccak256(bytes(SUPER_LEDGER_CONFIGURATION_ID)), _getContract(chainId, SUPER_LEDGER_CONFIGURATION_KEY)
        );
        superRegistry.setAddress(keccak256(bytes(SUPER_EXECUTOR_ID)), _getContract(chainId, SUPER_EXECUTOR_KEY));
        superRegistry.setAddress(keccak256(bytes(SUPER_REGISTRY_ID)), _getContract(chainId, SUPER_REGISTRY_KEY));
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
        returns (HookAddresses memory hookAddresses)
    {
        uint256 len = 26;
        HookDeployment[] memory hooks = new HookDeployment[](len);
        address[] memory addresses = new address[](len);

        hooks[0] = HookDeployment(
            APPROVE_ERC20_HOOK_KEY,
            abi.encodePacked(type(ApproveERC20Hook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[1] = HookDeployment(
            TRANSFER_ERC20_HOOK_KEY,
            abi.encodePacked(type(TransferERC20Hook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[2] = HookDeployment(
            DEPOSIT_4626_VAULT_HOOK_KEY,
            abi.encodePacked(type(Deposit4626VaultHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[3] = HookDeployment(
            APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY,
            abi.encodePacked(
                type(ApproveAndDeposit4626VaultHook).creationCode, abi.encode(registry, configuration.owner)
            )
        );
        hooks[4] = HookDeployment(
            REDEEM_4626_VAULT_HOOK_KEY,
            abi.encodePacked(type(Redeem4626VaultHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[5] = HookDeployment(
            DEPOSIT_5115_VAULT_HOOK_KEY,
            abi.encodePacked(type(Deposit5115VaultHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[6] = HookDeployment(
            APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY,
            abi.encodePacked(
                type(ApproveAndDeposit5115VaultHook).creationCode, abi.encode(registry, configuration.owner)
            )
        );
        hooks[7] = HookDeployment(
            REDEEM_5115_VAULT_HOOK_KEY,
            abi.encodePacked(type(Redeem5115VaultHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[8] = HookDeployment(
            REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY,
            abi.encodePacked(type(RequestDeposit7540VaultHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[9] = HookDeployment(
            APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY,
            abi.encodePacked(
                type(ApproveAndRequestDeposit7540VaultHook).creationCode, abi.encode(registry, configuration.owner)
            )
        );
        hooks[10] = HookDeployment(
            REQUEST_REDEEM_7540_VAULT_HOOK_KEY,
            abi.encodePacked(type(RequestRedeem7540VaultHook).creationCode, abi.encode(registry, configuration.owner))
        );

        hooks[11] = HookDeployment(
            DEPOSIT_7540_VAULT_HOOK_KEY,
            abi.encodePacked(type(Deposit7540VaultHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[12] = HookDeployment(
            WITHDRAW_7540_VAULT_HOOK_KEY,
            abi.encodePacked(type(Withdraw7540VaultHook).creationCode, abi.encode(registry, configuration.owner))
        );
       
        hooks[13] = HookDeployment(
            SWAP_1INCH_HOOK_KEY,
            abi.encodePacked(
                type(Swap1InchHook).creationCode,
                abi.encode(registry, configuration.owner, configuration.aggregationRouters[chainId])
            )
        );
        hooks[14] = HookDeployment(
            SWAP_ODOS_HOOK_KEY,
            abi.encodePacked(
                type(SwapOdosHook).creationCode,
                abi.encode(registry, configuration.owner, configuration.odosRouters[chainId])
            )
        );
        hooks[15] = HookDeployment(
            APPROVE_AND_SWAP_ODOS_HOOK_KEY,
            abi.encodePacked(
                type(ApproveAndSwapOdosHook).creationCode,
                abi.encode(registry, configuration.owner, configuration.odosRouters[chainId])
            )
        );

        hooks[16] = HookDeployment(
            ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY,
            abi.encodePacked(
                type(AcrossSendFundsAndExecuteOnDstHook).creationCode,
                abi.encode(registry, configuration.owner, configuration.acrossSpokePoolV3s[chainId])
            )
        );
        hooks[17] = HookDeployment(
            FLUID_CLAIM_REWARD_HOOK_KEY,
            abi.encodePacked(type(FluidClaimRewardHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[18] = HookDeployment(
            FLUID_STAKE_HOOK_KEY,
            abi.encodePacked(type(FluidStakeHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[19] = HookDeployment(
            APPROVE_AND_FLUID_STAKE_HOOK_KEY,
            abi.encodePacked(type(ApproveAndFluidStakeHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[20] = HookDeployment(
            FLUID_UNSTAKE_HOOK_KEY,
            abi.encodePacked(type(FluidUnstakeHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[21] = HookDeployment(
            GEARBOX_CLAIM_REWARD_HOOK_KEY,
            abi.encodePacked(type(GearboxClaimRewardHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[22] = HookDeployment(
            GEARBOX_STAKE_HOOK_KEY,
            abi.encodePacked(type(GearboxStakeHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[23] = HookDeployment(
            GEARBOX_APPROVE_AND_STAKE_HOOK_KEY,
            abi.encodePacked(type(ApproveAndGearboxStakeHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[24] = HookDeployment(
            GEARBOX_UNSTAKE_HOOK_KEY,
            abi.encodePacked(type(GearboxUnstakeHook).creationCode, abi.encode(registry, configuration.owner))
        );
        hooks[25] = HookDeployment(
            YEARN_CLAIM_ONE_REWARD_HOOK_KEY,
            abi.encodePacked(type(YearnClaimOneRewardHook).creationCode, abi.encode(registry, configuration.owner))
        );

        for (uint256 i = 0; i < len; ++i) {
            HookDeployment memory hook = hooks[i];
            addresses[i] = __deployContract(
                deployer,
                hook.name,
                chainId,
                __getSalt(configuration.owner, configuration.deployer, hook.name),
                hook.creationCode
            );
        }

        hookAddresses.approveErc20Hook =
            Strings.equal(hooks[0].name, APPROVE_ERC20_HOOK_KEY) ? addresses[0] : address(0);
        hookAddresses.transferErc20Hook =
            Strings.equal(hooks[1].name, TRANSFER_ERC20_HOOK_KEY) ? addresses[1] : address(0);
        hookAddresses.deposit4626VaultHook =
            Strings.equal(hooks[2].name, DEPOSIT_4626_VAULT_HOOK_KEY) ? addresses[2] : address(0);
        hookAddresses.approveAndDeposit4626VaultHook =
            Strings.equal(hooks[3].name, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY) ? addresses[3] : address(0);
        hookAddresses.redeem4626VaultHook =
            Strings.equal(hooks[4].name, REDEEM_4626_VAULT_HOOK_KEY) ? addresses[4] : address(0);
        hookAddresses.deposit5115VaultHook =
            Strings.equal(hooks[5].name, DEPOSIT_5115_VAULT_HOOK_KEY) ? addresses[5] : address(0);
        hookAddresses.approveAndDeposit5115VaultHook =
            Strings.equal(hooks[6].name, APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY) ? addresses[6] : address(0);
        hookAddresses.redeem5115VaultHook =
            Strings.equal(hooks[7].name, REDEEM_5115_VAULT_HOOK_KEY) ? addresses[7] : address(0);
        hookAddresses.requestDeposit7540VaultHook =
            Strings.equal(hooks[8].name, REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY) ? addresses[8] : address(0);
        hookAddresses.approveAndRequestDeposit7540VaultHook =
            Strings.equal(hooks[9].name, APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY) ? addresses[9] : address(0);
        hookAddresses.requestRedeem7540VaultHook =
            Strings.equal(hooks[10].name, REQUEST_REDEEM_7540_VAULT_HOOK_KEY) ? addresses[10] : address(0);
        hookAddresses.deposit7540VaultHook =
            Strings.equal(hooks[11].name, DEPOSIT_7540_VAULT_HOOK_KEY) ? addresses[11] : address(0);
        hookAddresses.withdraw7540VaultHook =
            Strings.equal(hooks[12].name, WITHDRAW_7540_VAULT_HOOK_KEY) ? addresses[12] : address(0);
        hookAddresses.swap1InchHook = Strings.equal(hooks[13].name, SWAP_1INCH_HOOK_KEY) ? addresses[13] : address(0);
        hookAddresses.swapOdosHook = Strings.equal(hooks[14].name, SWAP_ODOS_HOOK_KEY) ? addresses[14] : address(0);
        hookAddresses.approveAndSwapOdosHook =
            Strings.equal(hooks[15].name, APPROVE_AND_SWAP_ODOS_HOOK_KEY) ? addresses[15] : address(0);
        hookAddresses.acrossSendFundsAndExecuteOnDstHook =
            Strings.equal(hooks[16].name, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY) ? addresses[16] : address(0);
        hookAddresses.fluidClaimRewardHook =
            Strings.equal(hooks[17].name, FLUID_CLAIM_REWARD_HOOK_KEY) ? addresses[17] : address(0);
        hookAddresses.fluidStakeHook = Strings.equal(hooks[18].name, FLUID_STAKE_HOOK_KEY) ? addresses[18] : address(0);
        hookAddresses.approveAndFluidStakeHook =
            Strings.equal(hooks[19].name, APPROVE_AND_FLUID_STAKE_HOOK_KEY) ? addresses[19] : address(0);
        hookAddresses.fluidUnstakeHook =
            Strings.equal(hooks[20].name, FLUID_UNSTAKE_HOOK_KEY) ? addresses[20] : address(0);
        hookAddresses.gearboxClaimRewardHook =
            Strings.equal(hooks[21].name, GEARBOX_CLAIM_REWARD_HOOK_KEY) ? addresses[21] : address(0);
        hookAddresses.gearboxStakeHook =
            Strings.equal(hooks[22].name, GEARBOX_STAKE_HOOK_KEY) ? addresses[22] : address(0);
        hookAddresses.approveAndGearboxStakeHook =
            Strings.equal(hooks[23].name, GEARBOX_APPROVE_AND_STAKE_HOOK_KEY) ? addresses[23] : address(0);
        hookAddresses.gearboxUnstakeHook =
            Strings.equal(hooks[24].name, GEARBOX_UNSTAKE_HOOK_KEY) ? addresses[24] : address(0);
        hookAddresses.yearnClaimOneRewardHook =
            Strings.equal(hooks[25].name, YEARN_CLAIM_ONE_REWARD_HOOK_KEY) ? addresses[25] : address(0);

        // Verify no hooks were assigned address(0)
        require(hookAddresses.approveErc20Hook != address(0), "approveErc20Hook not assigned");
        require(hookAddresses.transferErc20Hook != address(0), "transferErc20Hook not assigned");
        require(hookAddresses.deposit4626VaultHook != address(0), "deposit4626VaultHook not assigned");
        require(
            hookAddresses.approveAndDeposit4626VaultHook != address(0), "approveAndDeposit4626VaultHook not assigned"
        );
        require(hookAddresses.redeem4626VaultHook != address(0), "redeem4626VaultHook not assigned");
        require(hookAddresses.deposit5115VaultHook != address(0), "deposit5115VaultHook not assigned");
        require(
            hookAddresses.approveAndDeposit5115VaultHook != address(0), "approveAndDeposit5115VaultHook not assigned"
        );
        require(hookAddresses.redeem5115VaultHook != address(0), "redeem5115VaultHook not assigned");
        require(hookAddresses.requestDeposit7540VaultHook != address(0), "requestDeposit7540VaultHook not assigned");
        require(
            hookAddresses.approveAndRequestDeposit7540VaultHook != address(0),
            "approveAndRequestDeposit7540VaultHook not assigned"
        );
        require(hookAddresses.requestRedeem7540VaultHook != address(0), "requestRedeem7540VaultHook not assigned");
        require(hookAddresses.deposit7540VaultHook != address(0), "deposit7540VaultHook not assigned");
        require(hookAddresses.withdraw7540VaultHook != address(0), "withdraw7540VaultHook not assigned");
        require(hookAddresses.swap1InchHook != address(0), "swap1InchHook not assigned");
        require(hookAddresses.swapOdosHook != address(0), "swapOdosHook not assigned");
        require(hookAddresses.approveAndSwapOdosHook != address(0), "approveAndSwapOdosHook not assigned");
        require(
            hookAddresses.acrossSendFundsAndExecuteOnDstHook != address(0),
            "acrossSendFundsAndExecuteOnDstHook not assigned"
        );
        require(hookAddresses.fluidClaimRewardHook != address(0), "fluidClaimRewardHook not assigned");
        require(hookAddresses.fluidStakeHook != address(0), "fluidStakeHook not assigned");
        require(hookAddresses.approveAndFluidStakeHook != address(0), "approveAndFluidStakeHook not assigned");
        require(hookAddresses.fluidUnstakeHook != address(0), "fluidUnstakeHook not assigned");
        require(hookAddresses.fluidClaimRewardHook != address(0), "fluidClaimRewardHook not assigned");
        require(hookAddresses.gearboxClaimRewardHook != address(0), "gearboxClaimRewardHook not assigned");
        require(hookAddresses.gearboxStakeHook != address(0), "gearboxStakeHook not assigned");
        require(hookAddresses.approveAndGearboxStakeHook != address(0), "approveAndGearboxStakeHook not assigned");
        require(hookAddresses.gearboxUnstakeHook != address(0), "gearboxUnstakeHook not assigned");
        require(hookAddresses.yearnClaimOneRewardHook != address(0), "yearnClaimOneRewardHook not assigned");
    }

    function _registerHooks(HookAddresses memory hookAddresses, PeripheryRegistry peripheryRegistry) internal {
        // Register fulfillRequests hooks
        peripheryRegistry.registerHook(address(hookAddresses.deposit4626VaultHook), true);
        peripheryRegistry.registerHook(address(hookAddresses.approveAndDeposit4626VaultHook), true);
        peripheryRegistry.registerHook(address(hookAddresses.redeem4626VaultHook), true);
        peripheryRegistry.registerHook(address(hookAddresses.deposit5115VaultHook), true);
        peripheryRegistry.registerHook(address(hookAddresses.redeem5115VaultHook), true);

        // Register remaining hooks
        peripheryRegistry.registerHook(address(hookAddresses.approveErc20Hook), false);
        peripheryRegistry.registerHook(address(hookAddresses.transferErc20Hook), false);
        peripheryRegistry.registerHook(address(hookAddresses.requestDeposit7540VaultHook), false);
        peripheryRegistry.registerHook(address(hookAddresses.requestRedeem7540VaultHook), false);
        peripheryRegistry.registerHook(address(hookAddresses.deposit7540VaultHook), false);
        peripheryRegistry.registerHook(address(hookAddresses.withdraw7540VaultHook), false);
        peripheryRegistry.registerHook(address(hookAddresses.swap1InchHook), false);
        peripheryRegistry.registerHook(address(hookAddresses.swapOdosHook), false);
        peripheryRegistry.registerHook(address(hookAddresses.acrossSendFundsAndExecuteOnDstHook), false);
        peripheryRegistry.registerHook(address(hookAddresses.fluidClaimRewardHook), false);
        peripheryRegistry.registerHook(address(hookAddresses.fluidStakeHook), false);
        peripheryRegistry.registerHook(address(hookAddresses.fluidUnstakeHook), false);
        peripheryRegistry.registerHook(address(hookAddresses.gearboxClaimRewardHook), false);
        peripheryRegistry.registerHook(address(hookAddresses.gearboxStakeHook), false);
        peripheryRegistry.registerHook(address(hookAddresses.approveAndGearboxStakeHook), false);
        peripheryRegistry.registerHook(address(hookAddresses.gearboxUnstakeHook), false);
        peripheryRegistry.registerHook(address(hookAddresses.yearnClaimOneRewardHook), false);
    }

    function _deployOracles(
        ISuperDeployer deployer,
        address registry,
        uint64 chainId
    )
        private
        returns (address[] memory oracleAddresses)
    {
        uint256 len = 5;
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
        oracles[4] = OracleDeployment(
            GEARBOX_YIELD_SOURCE_ORACLE_KEY,
            abi.encodePacked(type(GearboxYieldSourceOracle).creationCode, abi.encode(registry))
        );

        for (uint256 i = 0; i < len; ++i) {
            OracleDeployment memory oracle = oracles[i];
            oracleAddresses[i] = __deployContract(
                deployer,
                oracle.name,
                chainId,
                __getSalt(configuration.owner, configuration.deployer, oracle.name),
                oracle.creationCode
            );
        }
    }

    function _setupSuperLedgerConfiguration(uint64 chainId) private {
        PeripheryRegistry peripheryRegistry = PeripheryRegistry(_getContract(chainId, PERIPHERY_REGISTRY_KEY));
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](5);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceOracle: _getContract(chainId, ERC4626_YIELD_SOURCE_ORACLE_KEY),
            feePercent: 100,
            feeRecipient: peripheryRegistry.getTreasury(),
            ledger: _getContract(chainId, SUPER_LEDGER_KEY)
        });
        configs[1] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceOracle: _getContract(chainId, ERC7540_YIELD_SOURCE_ORACLE_KEY),
            feePercent: 100,
            feeRecipient: peripheryRegistry.getTreasury(),
            ledger: _getContract(chainId, SUPER_LEDGER_KEY)
        });
        configs[2] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: bytes4(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceOracle: _getContract(chainId, ERC5115_YIELD_SOURCE_ORACLE_KEY),
            feePercent: 100,
            feeRecipient: peripheryRegistry.getTreasury(),
            ledger: _getContract(chainId, ERC1155_LEDGER_KEY)
        });
        configs[3] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: bytes4(bytes(FLUID_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceOracle: _getContract(chainId, FLUID_YIELD_SOURCE_ORACLE_KEY),
            feePercent: 100,
            feeRecipient: peripheryRegistry.getTreasury(),
            ledger: _getContract(chainId, SUPER_LEDGER_KEY)
        });
        configs[4] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: bytes4(bytes(GEARBOX_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceOracle: _getContract(chainId, GEARBOX_YIELD_SOURCE_ORACLE_KEY),
            feePercent: 100,
            feeRecipient: peripheryRegistry.getTreasury(),
            ledger: _getContract(chainId, SUPER_LEDGER_KEY)
        });
        ISuperLedgerConfiguration(_getContract(chainId, SUPER_LEDGER_CONFIGURATION_KEY)).setYieldSourceOracles(configs);
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
