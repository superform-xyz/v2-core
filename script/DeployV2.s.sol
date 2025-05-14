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
import { SuperDestinationExecutor } from "../src/core/executors/SuperDestinationExecutor.sol";
import { AcrossV3Adapter } from "../src/core/adapters/AcrossV3Adapter.sol";
import { DebridgeAdapter } from "../src/core/adapters/DebridgeAdapter.sol";

import { SuperGovernor } from "../src/periphery/SuperGovernor.sol";

import { SuperLedger } from "../src/core/accounting/SuperLedger.sol";
import { ERC5115Ledger } from "../src/core/accounting/ERC5115Ledger.sol";
import { SuperLedgerConfiguration } from "../src/core/accounting/SuperLedgerConfiguration.sol";
import { ISuperLedgerConfiguration } from "../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { SuperMerkleValidator } from "../src/core/validators/SuperMerkleValidator.sol";
import { SuperDestinationValidator } from "../src/core/validators/SuperDestinationValidator.sol";
import { SuperNativePaymaster } from "../src/core/paymaster/SuperNativePaymaster.sol";

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
import { CancelDepositRequest7540Hook } from "../src/core/hooks/vaults/7540/CancelDepositRequest7540Hook.sol";
import { CancelRedeemRequest7540Hook } from "../src/core/hooks/vaults/7540/CancelRedeemRequest7540Hook.sol";
import { ClaimCancelDepositRequest7540Hook } from "../src/core/hooks/vaults/7540/ClaimCancelDepositRequest7540Hook.sol";
import { ClaimCancelRedeemRequest7540Hook } from "../src/core/hooks/vaults/7540/ClaimCancelRedeemRequest7540Hook.sol";
import { CancelRedeemHook } from "../src/core/hooks/vaults/super-vault/CancelRedeemHook.sol";

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
import { ApproveAndRedeem4626VaultHook } from "../src/core/hooks/vaults/4626/ApproveAndRedeem4626VaultHook.sol";
import { ApproveAndRedeem5115VaultHook } from "../src/core/hooks/vaults/5115/ApproveAndRedeem5115VaultHook.sol";
import { ApproveAndWithdraw7540VaultHook } from "../src/core/hooks/vaults/7540/ApproveAndWithdraw7540VaultHook.sol";
import { ApproveAndRedeem7540VaultHook } from "../src/core/hooks/vaults/7540/ApproveAndRedeem7540VaultHook.sol";
import { DeBridgeSendOrderAndExecuteOnDstHook } from
    "../src/core/hooks/bridges/debridge/DeBridgeSendOrderAndExecuteOnDstHook.sol";
import { EthenaCooldownSharesHook } from "../src/core/hooks/vaults/ethena/EthenaCooldownSharesHook.sol";
import { EthenaUnstakeHook } from "../src/core/hooks/vaults/ethena/EthenaUnstakeHook.sol";
import { SpectraExchangeHook } from "../src/core/hooks/swappers/spectra/SpectraExchangeHook.sol";
import { PendleRouterSwapHook } from "../src/core/hooks/swappers/pendle/PendleRouterSwapHook.sol";
import { MorphoBorrowHook } from "../src/core/hooks/loan/morpho/MorphoBorrowHook.sol";
import { MorphoRepayHook } from "../src/core/hooks/loan/morpho/MorphoRepayHook.sol";
import { MorphoRepayAndWithdrawHook } from "../src/core/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol";
import { PendleRouterRedeemHook } from "../src/core/hooks/swappers/pendle/PendleRouterRedeemHook.sol";
// -- oracles
import { ERC4626YieldSourceOracle } from "../src/core/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { ERC5115YieldSourceOracle } from "../src/core/accounting/oracles/ERC5115YieldSourceOracle.sol";
import { ERC7540YieldSourceOracle } from "../src/core/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { PendlePTYieldSourceOracle } from "../src/core/accounting/oracles/PendlePTYieldSourceOracle.sol";
import { SpectraPTYieldSourceOracle } from "../src/core/accounting/oracles/SpectraPTYieldSourceOracle.sol";
import { StakingYieldSourceOracle } from "../src/core/accounting/oracles/StakingYieldSourceOracle.sol";
import { SuperOracle } from "../src/periphery/oracles/SuperOracle.sol";

// SuperVault

import { SuperVaultAggregator } from "../src/periphery/SuperVault/SuperVaultAggregator.sol";
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
        address acrossV3Adapter;
        address debridgeAdapter;
        address superDestinationExecutor;
        address superLedger;
        address pendleLedger;
        address superLedgerConfiguration;
        address superPositionSentinel;
        address mockValidatorModule;
        address oracleRegistry;
        address superGovernor;
        address superVaultAggregator;
        address superMerkleValidator;
        address superDestinationValidator;
        address superNativePaymaster;
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
        address cancelDepositRequest7540Hook;
        address cancelRedeemRequest7540Hook;
        address claimCancelDepositRequest7540Hook;
        address claimCancelRedeemRequest7540Hook;
        address cancelRedeemHook;
        address approveAndRedeem4626VaultHook;
        address approveAndRedeem5115VaultHook;
        address approveAndWithdraw7540VaultHook;
        address approveAndRedeem7540VaultHook;
        address deBridgeSendOrderAndExecuteOnDstHook;
        address ethenaCooldownSharesHook;
        address ethenaUnstakeHook;
        address spectraExchangeHook;
        address pendleRouterSwapHook;
        address pendleRouterRedeemHook;
        address morphoBorrowHook;
        address morphoRepayHook;
        address morphoRepayAndWithdrawHook;
    }
    // --- New Hook Addresses End ---

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

        _deployDeployer();

        // deploy contracts
        _deploy(chainId);

        // Setup SuperLedger
        _setupSuperLedgerConfiguration(chainId);
    }

    function _deployDeployer() internal {
        address superDeployer = address(
            new SuperDeployer{ salt: __getSalt(configuration.owner, configuration.deployer, SUPER_DEPLOYER_KEY) }()
        );
        console2.log("SuperDeployer deployed at:", superDeployer);
        configuration.deployer = superDeployer;
    }

    function _deploy(uint64 chainId) internal {
        DeployedContracts memory deployedContracts;

        // retrieve deployer
        ISuperDeployer deployer = ISuperDeployer(configuration.deployer);

        // todo decide arguments for this
        deployedContracts.superGovernor = __deployContract(
            deployer,
            SUPER_GOVERNOR_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, SUPER_GOVERNOR_KEY),
            abi.encodePacked(
                type(SuperGovernor).creationCode,
                abi.encode(
                    configuration.owner,
                    configuration.owner,
                    configuration.owner,
                    configuration.treasury,
                    configuration.polymerProvers[chainId]
                )
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
                abi.encode(configuration.owner, new address[](0), new address[](0), new uint256[](0), new bytes32[](0))
            )
        );

        // Deploy SuperLedgerConfiguration
        deployedContracts.superLedgerConfiguration = __deployContract(
            deployer,
            SUPER_LEDGER_CONFIGURATION_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, SUPER_LEDGER_CONFIGURATION_KEY),
            type(SuperLedgerConfiguration).creationCode
        );

        // Deploy SuperMerkleValidator
        deployedContracts.superMerkleValidator = __deployContract(
            deployer,
            SUPER_MERKLE_VALIDATOR_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, SUPER_MERKLE_VALIDATOR_KEY),
            type(SuperMerkleValidator).creationCode
        );

        // Deploy SuperDestinationValidator
        deployedContracts.superDestinationValidator = __deployContract(
            deployer,
            SUPER_DESTINATION_VALIDATOR_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, SUPER_DESTINATION_VALIDATOR_KEY),
            type(SuperDestinationValidator).creationCode
        );

        // Deploy SuperExecutor
        deployedContracts.superExecutor = __deployContract(
            deployer,
            SUPER_EXECUTOR_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, SUPER_EXECUTOR_KEY),
            abi.encodePacked(type(SuperExecutor).creationCode, abi.encode(deployedContracts.superLedgerConfiguration))
        );

        // Deploy SuperDestinationExecutor
        deployedContracts.superDestinationExecutor = __deployContract(
            deployer,
            SUPER_DESTINATION_EXECUTOR_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, SUPER_DESTINATION_EXECUTOR_KEY),
            abi.encodePacked(
                type(SuperDestinationExecutor).creationCode,
                abi.encode(
                    deployedContracts.superLedgerConfiguration,
                    deployedContracts.superDestinationValidator,
                    configuration.nexusFactories[chainId]
                )
            )
        );

        // Deploy AcrossV3Adapter
        deployedContracts.acrossV3Adapter = __deployContract(
            deployer,
            ACROSS_V3_ADAPTER_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, ACROSS_V3_ADAPTER_KEY),
            abi.encodePacked(
                type(AcrossV3Adapter).creationCode,
                abi.encode(configuration.acrossSpokePoolV3s[chainId], deployedContracts.superDestinationExecutor)
            )
        );

        // Deploy DebridgeAdapter
        deployedContracts.debridgeAdapter = __deployContract(
            deployer,
            DEBRIDGE_ADAPTER_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, DEBRIDGE_ADAPTER_KEY),
            abi.encodePacked(
                type(DebridgeAdapter).creationCode,
                abi.encode(configuration.debridgeDstDln[chainId], deployedContracts.superDestinationExecutor)
            )
        );

        address[] memory allowedExecutors = new address[](2);
        allowedExecutors[0] = address(deployedContracts.superExecutor);
        allowedExecutors[1] = address(deployedContracts.superDestinationExecutor);

        // Deploy SuperLedger
        deployedContracts.superLedger = __deployContract(
            deployer,
            SUPER_LEDGER_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, SUPER_LEDGER_KEY),
            abi.encodePacked(
                type(SuperLedger).creationCode, abi.encode(deployedContracts.superLedgerConfiguration, allowedExecutors)
            )
        );

        // Deploy ERC5115Ledger
        deployedContracts.pendleLedger = __deployContract(
            deployer,
            ERC1155_LEDGER_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, ERC1155_LEDGER_KEY),
            abi.encodePacked(
                type(ERC5115Ledger).creationCode,
                abi.encode(deployedContracts.superLedgerConfiguration, allowedExecutors)
            )
        );

        // Deploy SuperNativePaymaster
        deployedContracts.superNativePaymaster = __deployContract(
            deployer,
            SUPER_NATIVE_PAYMASTER_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, SUPER_NATIVE_PAYMASTER_KEY),
            abi.encodePacked(type(SuperNativePaymaster).creationCode, abi.encode(ENTRY_POINT))
        );

        // Deploy SuperVaultAggregator
        deployedContracts.superVaultAggregator = __deployContract(
            deployer,
            SUPER_VAULT_AGGREGATOR_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, SUPER_VAULT_AGGREGATOR_KEY),
            abi.encodePacked(type(SuperVaultAggregator).creationCode, abi.encode(deployedContracts.superGovernor))
        );
        // Deploy Hooks
        HookAddresses memory hookAddresses = _deployHooks(deployer, chainId);

        _registerHooks(hookAddresses, SuperGovernor(deployedContracts.superGovernor));
        _configureGovernor(SuperGovernor(deployedContracts.superGovernor), deployedContracts.superVaultAggregator);
        // Deploy Oracles
        _deployOracles(deployer, chainId);
    }

    function _configureGovernor(SuperGovernor superGovernor, address aggregator) internal {
        superGovernor.setAddress(superGovernor.SUPER_VAULT_AGGREGATOR(), aggregator);
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
        console2.log("[!] Deploying %s...", contractName);
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
        uint64 chainId
    )
        private
        returns (HookAddresses memory hookAddresses)
    {
        uint256 len = 44; // Updated length including new Pendle hook
        HookDeployment[] memory hooks = new HookDeployment[](len);
        address[] memory addresses = new address[](len);

        hooks[0] = HookDeployment(APPROVE_ERC20_HOOK_KEY, type(ApproveERC20Hook).creationCode);
        hooks[1] = HookDeployment(TRANSFER_ERC20_HOOK_KEY, type(TransferERC20Hook).creationCode);
        hooks[2] = HookDeployment(DEPOSIT_4626_VAULT_HOOK_KEY, type(Deposit4626VaultHook).creationCode);
        hooks[3] =
            HookDeployment(APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY, type(ApproveAndDeposit4626VaultHook).creationCode);
        hooks[4] = HookDeployment(REDEEM_4626_VAULT_HOOK_KEY, type(Redeem4626VaultHook).creationCode);
        hooks[5] =
            HookDeployment(APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY, type(ApproveAndRedeem4626VaultHook).creationCode);
        hooks[6] = HookDeployment(DEPOSIT_5115_VAULT_HOOK_KEY, type(Deposit5115VaultHook).creationCode);
        hooks[7] =
            HookDeployment(APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY, type(ApproveAndDeposit5115VaultHook).creationCode);
        hooks[8] = HookDeployment(REDEEM_5115_VAULT_HOOK_KEY, type(Redeem5115VaultHook).creationCode);
        hooks[9] =
            HookDeployment(APPROVE_AND_REDEEM_5115_VAULT_HOOK_KEY, type(ApproveAndRedeem5115VaultHook).creationCode);
        hooks[10] = HookDeployment(REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY, type(RequestDeposit7540VaultHook).creationCode);
        hooks[11] = HookDeployment(
            APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY, type(ApproveAndRequestDeposit7540VaultHook).creationCode
        );
        hooks[12] = HookDeployment(REQUEST_REDEEM_7540_VAULT_HOOK_KEY, type(RequestRedeem7540VaultHook).creationCode);
        hooks[13] = HookDeployment(DEPOSIT_7540_VAULT_HOOK_KEY, type(Deposit7540VaultHook).creationCode);
        hooks[14] = HookDeployment(WITHDRAW_7540_VAULT_HOOK_KEY, type(Withdraw7540VaultHook).creationCode);
        hooks[15] =
            HookDeployment(APPROVE_AND_WITHDRAW_7540_VAULT_HOOK_KEY, type(ApproveAndWithdraw7540VaultHook).creationCode);
        hooks[16] =
            HookDeployment(APPROVE_AND_REDEEM_7540_VAULT_HOOK_KEY, type(ApproveAndRedeem7540VaultHook).creationCode);

        hooks[17] = HookDeployment(
            SWAP_1INCH_HOOK_KEY,
            abi.encodePacked(type(Swap1InchHook).creationCode, abi.encode(configuration.aggregationRouters[chainId]))
        );
        hooks[18] = HookDeployment(
            SWAP_ODOS_HOOK_KEY,
            abi.encodePacked(type(SwapOdosHook).creationCode, abi.encode(configuration.odosRouters[chainId]))
        );
        hooks[19] = HookDeployment(
            APPROVE_AND_SWAP_ODOS_HOOK_KEY,
            abi.encodePacked(type(ApproveAndSwapOdosHook).creationCode, abi.encode(configuration.odosRouters[chainId]))
        );

        hooks[20] = HookDeployment(
            ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY,
            abi.encodePacked(
                type(AcrossSendFundsAndExecuteOnDstHook).creationCode,
                abi.encode(configuration.acrossSpokePoolV3s[chainId], _getContract(chainId, SUPER_MERKLE_VALIDATOR_KEY))
            )
        );
        hooks[21] = HookDeployment(
            DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY,
            abi.encodePacked(
                type(DeBridgeSendOrderAndExecuteOnDstHook).creationCode,
                abi.encode(DEBRIDGE_DLN_SRC, _getContract(chainId, SUPER_MERKLE_VALIDATOR_KEY))
            )
        );

        hooks[22] = HookDeployment(FLUID_CLAIM_REWARD_HOOK_KEY, type(FluidClaimRewardHook).creationCode);
        hooks[23] = HookDeployment(FLUID_STAKE_HOOK_KEY, type(FluidStakeHook).creationCode);
        hooks[24] = HookDeployment(APPROVE_AND_FLUID_STAKE_HOOK_KEY, type(ApproveAndFluidStakeHook).creationCode);
        hooks[25] = HookDeployment(FLUID_UNSTAKE_HOOK_KEY, type(FluidUnstakeHook).creationCode);
        hooks[26] = HookDeployment(GEARBOX_CLAIM_REWARD_HOOK_KEY, type(GearboxClaimRewardHook).creationCode);
        hooks[27] = HookDeployment(GEARBOX_STAKE_HOOK_KEY, type(GearboxStakeHook).creationCode);
        hooks[28] = HookDeployment(GEARBOX_APPROVE_AND_STAKE_HOOK_KEY, type(ApproveAndGearboxStakeHook).creationCode);
        hooks[29] = HookDeployment(GEARBOX_UNSTAKE_HOOK_KEY, type(GearboxUnstakeHook).creationCode);
        hooks[30] = HookDeployment(YEARN_CLAIM_ONE_REWARD_HOOK_KEY, type(YearnClaimOneRewardHook).creationCode);
        hooks[31] = HookDeployment(ETHENA_COOLDOWN_SHARES_HOOK_KEY, type(EthenaCooldownSharesHook).creationCode);
        hooks[32] = HookDeployment(ETHENA_UNSTAKE_HOOK_KEY, type(EthenaUnstakeHook).creationCode);
        hooks[33] = HookDeployment(
            SPECTRA_EXCHANGE_HOOK_KEY,
            abi.encodePacked(type(SpectraExchangeHook).creationCode, abi.encode(configuration.spectraRouters[chainId]))
        );
        hooks[34] = HookDeployment(
            PENDLE_ROUTER_SWAP_HOOK_KEY,
            abi.encodePacked(type(PendleRouterSwapHook).creationCode, abi.encode(configuration.pendleRouters[chainId]))
        );
        hooks[35] = HookDeployment(
            PENDLE_ROUTER_REDEEM_HOOK_KEY,
            abi.encodePacked(
                type(PendleRouterRedeemHook).creationCode, abi.encode(configuration.pendleRouters[chainId])
            )
        );
        hooks[36] =
            HookDeployment(CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY, type(CancelDepositRequest7540Hook).creationCode);
        hooks[37] = HookDeployment(CANCEL_REDEEM_REQUEST_7540_HOOK_KEY, type(CancelRedeemRequest7540Hook).creationCode);
        hooks[38] = HookDeployment(
            CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY, type(ClaimCancelDepositRequest7540Hook).creationCode
        );
        hooks[39] = HookDeployment(
            CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY, type(ClaimCancelRedeemRequest7540Hook).creationCode
        );
        hooks[40] = HookDeployment(CANCEL_REDEEM_HOOK_KEY, type(CancelRedeemHook).creationCode);

        hooks[41] = HookDeployment(
            MORPHO_BORROW_HOOK_KEY, abi.encodePacked(type(MorphoBorrowHook).creationCode, abi.encode(MORPHO))
        );
        hooks[42] = HookDeployment(
            MORPHO_REPAY_HOOK_KEY, abi.encodePacked(type(MorphoRepayHook).creationCode, abi.encode(MORPHO))
        );
        hooks[43] = HookDeployment(
            MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY,
            abi.encodePacked(type(MorphoRepayAndWithdrawHook).creationCode, abi.encode(MORPHO))
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
        hookAddresses.approveAndRedeem4626VaultHook =
            Strings.equal(hooks[5].name, APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY) ? addresses[5] : address(0);
        hookAddresses.deposit5115VaultHook =
            Strings.equal(hooks[6].name, DEPOSIT_5115_VAULT_HOOK_KEY) ? addresses[6] : address(0);
        hookAddresses.approveAndDeposit5115VaultHook =
            Strings.equal(hooks[7].name, APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY) ? addresses[7] : address(0);
        hookAddresses.redeem5115VaultHook =
            Strings.equal(hooks[8].name, REDEEM_5115_VAULT_HOOK_KEY) ? addresses[8] : address(0);
        hookAddresses.approveAndRedeem5115VaultHook =
            Strings.equal(hooks[9].name, APPROVE_AND_REDEEM_5115_VAULT_HOOK_KEY) ? addresses[9] : address(0);
        hookAddresses.requestDeposit7540VaultHook =
            Strings.equal(hooks[10].name, REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY) ? addresses[10] : address(0);
        hookAddresses.approveAndRequestDeposit7540VaultHook =
            Strings.equal(hooks[11].name, APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY) ? addresses[11] : address(0);
        hookAddresses.requestRedeem7540VaultHook =
            Strings.equal(hooks[12].name, REQUEST_REDEEM_7540_VAULT_HOOK_KEY) ? addresses[12] : address(0);
        hookAddresses.deposit7540VaultHook =
            Strings.equal(hooks[13].name, DEPOSIT_7540_VAULT_HOOK_KEY) ? addresses[13] : address(0);
        hookAddresses.withdraw7540VaultHook =
            Strings.equal(hooks[14].name, WITHDRAW_7540_VAULT_HOOK_KEY) ? addresses[14] : address(0);
        hookAddresses.approveAndWithdraw7540VaultHook =
            Strings.equal(hooks[15].name, APPROVE_AND_WITHDRAW_7540_VAULT_HOOK_KEY) ? addresses[15] : address(0);
        hookAddresses.approveAndRedeem7540VaultHook =
            Strings.equal(hooks[16].name, APPROVE_AND_REDEEM_7540_VAULT_HOOK_KEY) ? addresses[16] : address(0);
        hookAddresses.swap1InchHook = Strings.equal(hooks[17].name, SWAP_1INCH_HOOK_KEY) ? addresses[17] : address(0);
        hookAddresses.swapOdosHook = Strings.equal(hooks[18].name, SWAP_ODOS_HOOK_KEY) ? addresses[18] : address(0);
        hookAddresses.approveAndSwapOdosHook =
            Strings.equal(hooks[19].name, APPROVE_AND_SWAP_ODOS_HOOK_KEY) ? addresses[19] : address(0);
        hookAddresses.acrossSendFundsAndExecuteOnDstHook =
            Strings.equal(hooks[20].name, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY) ? addresses[20] : address(0);
        hookAddresses.deBridgeSendOrderAndExecuteOnDstHook =
            Strings.equal(hooks[21].name, DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY) ? addresses[21] : address(0);
        hookAddresses.fluidClaimRewardHook =
            Strings.equal(hooks[22].name, FLUID_CLAIM_REWARD_HOOK_KEY) ? addresses[22] : address(0);
        hookAddresses.fluidStakeHook = Strings.equal(hooks[23].name, FLUID_STAKE_HOOK_KEY) ? addresses[23] : address(0);
        hookAddresses.approveAndFluidStakeHook =
            Strings.equal(hooks[24].name, APPROVE_AND_FLUID_STAKE_HOOK_KEY) ? addresses[24] : address(0);
        hookAddresses.fluidUnstakeHook =
            Strings.equal(hooks[25].name, FLUID_UNSTAKE_HOOK_KEY) ? addresses[25] : address(0);
        hookAddresses.gearboxClaimRewardHook =
            Strings.equal(hooks[26].name, GEARBOX_CLAIM_REWARD_HOOK_KEY) ? addresses[26] : address(0);
        hookAddresses.gearboxStakeHook =
            Strings.equal(hooks[27].name, GEARBOX_STAKE_HOOK_KEY) ? addresses[27] : address(0);
        hookAddresses.approveAndGearboxStakeHook =
            Strings.equal(hooks[28].name, GEARBOX_APPROVE_AND_STAKE_HOOK_KEY) ? addresses[28] : address(0);
        hookAddresses.gearboxUnstakeHook =
            Strings.equal(hooks[29].name, GEARBOX_UNSTAKE_HOOK_KEY) ? addresses[29] : address(0);
        hookAddresses.yearnClaimOneRewardHook =
            Strings.equal(hooks[30].name, YEARN_CLAIM_ONE_REWARD_HOOK_KEY) ? addresses[30] : address(0);
        hookAddresses.ethenaCooldownSharesHook =
            Strings.equal(hooks[31].name, ETHENA_COOLDOWN_SHARES_HOOK_KEY) ? addresses[31] : address(0);
        hookAddresses.ethenaUnstakeHook =
            Strings.equal(hooks[32].name, ETHENA_UNSTAKE_HOOK_KEY) ? addresses[32] : address(0);
        hookAddresses.spectraExchangeHook =
            Strings.equal(hooks[33].name, SPECTRA_EXCHANGE_HOOK_KEY) ? addresses[33] : address(0);
        hookAddresses.pendleRouterSwapHook =
            Strings.equal(hooks[34].name, PENDLE_ROUTER_SWAP_HOOK_KEY) ? addresses[34] : address(0);
        hookAddresses.pendleRouterRedeemHook =
            Strings.equal(hooks[35].name, PENDLE_ROUTER_REDEEM_HOOK_KEY) ? addresses[35] : address(0);
        hookAddresses.cancelDepositRequest7540Hook =
            Strings.equal(hooks[36].name, CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY) ? addresses[36] : address(0);
        hookAddresses.cancelRedeemRequest7540Hook =
            Strings.equal(hooks[37].name, CANCEL_REDEEM_REQUEST_7540_HOOK_KEY) ? addresses[37] : address(0);
        hookAddresses.claimCancelDepositRequest7540Hook =
            Strings.equal(hooks[38].name, CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY) ? addresses[38] : address(0);
        hookAddresses.claimCancelRedeemRequest7540Hook =
            Strings.equal(hooks[39].name, CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY) ? addresses[39] : address(0);
        hookAddresses.cancelRedeemHook =
            Strings.equal(hooks[40].name, CANCEL_REDEEM_HOOK_KEY) ? addresses[40] : address(0);
        hookAddresses.morphoBorrowHook =
            Strings.equal(hooks[41].name, MORPHO_BORROW_HOOK_KEY) ? addresses[41] : address(0);
        hookAddresses.morphoRepayHook =
            Strings.equal(hooks[42].name, MORPHO_REPAY_HOOK_KEY) ? addresses[42] : address(0);
        hookAddresses.morphoRepayAndWithdrawHook =
            Strings.equal(hooks[43].name, MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY) ? addresses[43] : address(0);

        // Verify no hooks were assigned address(0) (excluding experimental placeholders)
        require(hookAddresses.approveErc20Hook != address(0), "approveErc20Hook not assigned");
        require(hookAddresses.transferErc20Hook != address(0), "transferErc20Hook not assigned");
        require(hookAddresses.deposit4626VaultHook != address(0), "deposit4626VaultHook not assigned");
        require(
            hookAddresses.approveAndDeposit4626VaultHook != address(0), "approveAndDeposit4626VaultHook not assigned"
        );
        require(hookAddresses.redeem4626VaultHook != address(0), "redeem4626VaultHook not assigned");
        require(hookAddresses.approveAndRedeem4626VaultHook != address(0), "approveAndRedeem4626VaultHook not assigned");
        require(hookAddresses.deposit5115VaultHook != address(0), "deposit5115VaultHook not assigned");
        require(
            hookAddresses.approveAndDeposit5115VaultHook != address(0), "approveAndDeposit5115VaultHook not assigned"
        );
        require(hookAddresses.redeem5115VaultHook != address(0), "redeem5115VaultHook not assigned");
        require(hookAddresses.approveAndRedeem5115VaultHook != address(0), "approveAndRedeem5115VaultHook not assigned");
        require(hookAddresses.requestDeposit7540VaultHook != address(0), "requestDeposit7540VaultHook not assigned");
        require(
            hookAddresses.approveAndRequestDeposit7540VaultHook != address(0),
            "approveAndRequestDeposit7540VaultHook not assigned"
        );
        require(hookAddresses.requestRedeem7540VaultHook != address(0), "requestRedeem7540VaultHook not assigned");
        require(hookAddresses.deposit7540VaultHook != address(0), "deposit7540VaultHook not assigned");
        require(hookAddresses.withdraw7540VaultHook != address(0), "withdraw7540VaultHook not assigned");
        require(
            hookAddresses.approveAndWithdraw7540VaultHook != address(0), "approveAndWithdraw7540VaultHook not assigned"
        );
        require(hookAddresses.approveAndRedeem7540VaultHook != address(0), "approveAndRedeem7540VaultHook not assigned");
        require(hookAddresses.swap1InchHook != address(0), "swap1InchHook not assigned");
        require(hookAddresses.swapOdosHook != address(0), "swapOdosHook not assigned");
        require(hookAddresses.approveAndSwapOdosHook != address(0), "approveAndSwapOdosHook not assigned");
        require(
            hookAddresses.acrossSendFundsAndExecuteOnDstHook != address(0),
            "acrossSendFundsAndExecuteOnDstHook not assigned"
        );
        require(
            hookAddresses.deBridgeSendOrderAndExecuteOnDstHook != address(0),
            "deBridgeSendOrderAndExecuteOnDstHook not assigned"
        );
        require(hookAddresses.fluidClaimRewardHook != address(0), "fluidClaimRewardHook not assigned");
        require(hookAddresses.fluidStakeHook != address(0), "fluidStakeHook not assigned");
        require(hookAddresses.approveAndFluidStakeHook != address(0), "approveAndFluidStakeHook not assigned");
        require(hookAddresses.fluidUnstakeHook != address(0), "fluidUnstakeHook not assigned");
        require(hookAddresses.gearboxClaimRewardHook != address(0), "gearboxClaimRewardHook not assigned");
        require(hookAddresses.gearboxStakeHook != address(0), "gearboxStakeHook not assigned");
        require(hookAddresses.approveAndGearboxStakeHook != address(0), "approveAndGearboxStakeHook not assigned");
        require(hookAddresses.gearboxUnstakeHook != address(0), "gearboxUnstakeHook not assigned");
        require(hookAddresses.yearnClaimOneRewardHook != address(0), "yearnClaimOneRewardHook not assigned");
        require(hookAddresses.cancelDepositRequest7540Hook != address(0), "cancelDepositRequest7540Hook not assigned");
        require(hookAddresses.cancelRedeemRequest7540Hook != address(0), "cancelRedeemRequest7540Hook not assigned");
        require(
            hookAddresses.claimCancelDepositRequest7540Hook != address(0),
            "claimCancelDepositRequest7540Hook not assigned"
        );
        require(
            hookAddresses.claimCancelRedeemRequest7540Hook != address(0),
            "claimCancelRedeemRequest7540Hook not assigned"
        );
        require(hookAddresses.cancelRedeemHook != address(0), "cancelRedeemHook not assigned");
        require(hookAddresses.morphoBorrowHook != address(0), "morphoBorrowHook not assigned");
        require(hookAddresses.morphoRepayHook != address(0), "morphoRepayHook not assigned");
        require(hookAddresses.morphoRepayAndWithdrawHook != address(0), "morphoRepayAndWithdrawHook not assigned");
    }

    function _registerHooks(HookAddresses memory hookAddresses, SuperGovernor superGovernor) internal {
        // Register fulfillRequests hooks
        superGovernor.registerHook(address(hookAddresses.deposit4626VaultHook), true);
        superGovernor.registerHook(address(hookAddresses.approveAndDeposit4626VaultHook), true);
        superGovernor.registerHook(address(hookAddresses.redeem4626VaultHook), true);
        superGovernor.registerHook(address(hookAddresses.approveAndRedeem4626VaultHook), true);
        superGovernor.registerHook(address(hookAddresses.deposit5115VaultHook), true);
        superGovernor.registerHook(address(hookAddresses.approveAndDeposit5115VaultHook), true);
        superGovernor.registerHook(address(hookAddresses.redeem5115VaultHook), true);
        superGovernor.registerHook(address(hookAddresses.approveAndRedeem5115VaultHook), true);
        superGovernor.registerHook(address(hookAddresses.deposit7540VaultHook), true);
        superGovernor.registerHook(address(hookAddresses.approveAndWithdraw7540VaultHook), true);
        superGovernor.registerHook(address(hookAddresses.approveAndRedeem7540VaultHook), true);

        // Register remaining hooks
        superGovernor.registerHook(address(hookAddresses.approveErc20Hook), false);
        superGovernor.registerHook(address(hookAddresses.transferErc20Hook), false);
        superGovernor.registerHook(address(hookAddresses.requestDeposit7540VaultHook), false);
        superGovernor.registerHook(address(hookAddresses.approveAndRequestDeposit7540VaultHook), false);
        superGovernor.registerHook(address(hookAddresses.requestRedeem7540VaultHook), false);
        superGovernor.registerHook(address(hookAddresses.withdraw7540VaultHook), false);
        superGovernor.registerHook(address(hookAddresses.swap1InchHook), false);
        superGovernor.registerHook(address(hookAddresses.swapOdosHook), false);
        superGovernor.registerHook(address(hookAddresses.approveAndSwapOdosHook), false);
        superGovernor.registerHook(address(hookAddresses.acrossSendFundsAndExecuteOnDstHook), false);
        superGovernor.registerHook(address(hookAddresses.deBridgeSendOrderAndExecuteOnDstHook), false);
        superGovernor.registerHook(address(hookAddresses.fluidClaimRewardHook), false);
        superGovernor.registerHook(address(hookAddresses.fluidStakeHook), false);
        superGovernor.registerHook(address(hookAddresses.approveAndFluidStakeHook), false);
        superGovernor.registerHook(address(hookAddresses.fluidUnstakeHook), false);
        superGovernor.registerHook(address(hookAddresses.gearboxClaimRewardHook), false);
        superGovernor.registerHook(address(hookAddresses.gearboxStakeHook), false);
        superGovernor.registerHook(address(hookAddresses.approveAndGearboxStakeHook), false);
        superGovernor.registerHook(address(hookAddresses.gearboxUnstakeHook), false);
        superGovernor.registerHook(address(hookAddresses.yearnClaimOneRewardHook), false);
        superGovernor.registerHook(address(hookAddresses.cancelDepositRequest7540Hook), false);
        superGovernor.registerHook(address(hookAddresses.cancelRedeemRequest7540Hook), false);
        superGovernor.registerHook(address(hookAddresses.claimCancelDepositRequest7540Hook), false);
        superGovernor.registerHook(address(hookAddresses.claimCancelRedeemRequest7540Hook), false);
        superGovernor.registerHook(address(hookAddresses.cancelRedeemHook), false);
        superGovernor.registerHook(address(hookAddresses.morphoBorrowHook), false);
        superGovernor.registerHook(address(hookAddresses.morphoRepayHook), false);
        superGovernor.registerHook(address(hookAddresses.morphoRepayAndWithdrawHook), false);
        superGovernor.registerHook(address(hookAddresses.ethenaCooldownSharesHook), false);
        superGovernor.registerHook(address(hookAddresses.spectraExchangeHook), false);
        superGovernor.registerHook(address(hookAddresses.pendleRouterSwapHook), false);
        superGovernor.registerHook(address(hookAddresses.pendleRouterRedeemHook), false);
    }

    function _deployOracles(
        ISuperDeployer deployer,
        uint64 chainId
    )
        private
        returns (address[] memory oracleAddresses)
    {
        uint256 len = 6;
        OracleDeployment[] memory oracles = new OracleDeployment[](len);
        oracleAddresses = new address[](len);

        oracles[0] = OracleDeployment(
            ERC4626_YIELD_SOURCE_ORACLE_KEY, abi.encodePacked(type(ERC4626YieldSourceOracle).creationCode)
        );
        oracles[1] = OracleDeployment(
            ERC5115_YIELD_SOURCE_ORACLE_KEY, abi.encodePacked(type(ERC5115YieldSourceOracle).creationCode)
        );
        oracles[2] = OracleDeployment(
            ERC7540_YIELD_SOURCE_ORACLE_KEY, abi.encodePacked(type(ERC7540YieldSourceOracle).creationCode)
        );
        oracles[3] = OracleDeployment(
            PENDLE_PT_YIELD_SOURCE_ORACLE_KEY, abi.encodePacked(type(PendlePTYieldSourceOracle).creationCode)
        );
        oracles[4] = OracleDeployment(
            SPECTRA_PT_YIELD_SOURCE_ORACLE_KEY, abi.encodePacked(type(SpectraPTYieldSourceOracle).creationCode)
        );
        oracles[5] = OracleDeployment(
            STAKING_YIELD_SOURCE_ORACLE_KEY, abi.encodePacked(type(StakingYieldSourceOracle).creationCode)
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
        SuperGovernor superGovernor = SuperGovernor(_getContract(chainId, SUPER_GOVERNOR_KEY));
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](4);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceOracle: _getContract(chainId, ERC4626_YIELD_SOURCE_ORACLE_KEY),
            feePercent: 100,
            feeRecipient: superGovernor.getAddress(keccak256("TREASURY")),
            ledger: _getContract(chainId, SUPER_LEDGER_KEY)
        });
        configs[1] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceOracle: _getContract(chainId, ERC7540_YIELD_SOURCE_ORACLE_KEY),
            feePercent: 100,
            feeRecipient: superGovernor.getAddress(keccak256("TREASURY")),
            ledger: _getContract(chainId, SUPER_LEDGER_KEY)
        });
        configs[2] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: bytes4(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceOracle: _getContract(chainId, ERC5115_YIELD_SOURCE_ORACLE_KEY),
            feePercent: 100,
            feeRecipient: superGovernor.getAddress(keccak256("TREASURY")),
            ledger: _getContract(chainId, ERC1155_LEDGER_KEY)
        });
        configs[3] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: bytes4(bytes(STAKING_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceOracle: _getContract(chainId, STAKING_YIELD_SOURCE_ORACLE_KEY),
            feePercent: 100,
            feeRecipient: superGovernor.getAddress(keccak256("TREASURY")),
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
