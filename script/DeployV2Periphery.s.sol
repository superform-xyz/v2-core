// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { DeployV2Base } from "./DeployV2Base.s.sol";
import { ISuperDeployer } from "./utils/ISuperDeployer.sol";

// Periphery contracts
import { SuperGovernor } from "../src/periphery/SuperGovernor.sol";
import { SuperVaultAggregator } from "../src/periphery/SuperVault/SuperVaultAggregator.sol";
import { SuperVault } from "../src/periphery/SuperVault/SuperVault.sol";
import { SuperVaultStrategy } from "../src/periphery/SuperVault/SuperVaultStrategy.sol";
import { SuperVaultEscrow } from "../src/periphery/SuperVault/SuperVaultEscrow.sol";
import { ECDSAPPSOracle } from "../src/periphery/oracles/ECDSAPPSOracle.sol";
import { SuperOracle } from "../src/periphery/oracles/SuperOracle.sol";
import { SuperYieldSourceOracle } from "../src/periphery/oracles/SuperYieldSourceOracle.sol";

import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { console2 } from "forge-std/console2.sol";

contract DeployV2Periphery is DeployV2Base {
    struct PeripheryContracts {
        address superGovernor;
        address superVaultAggregator;
        address ecdsappsOracle;
        address superOracle;
        address superYieldSourceOracle;
        address vaultImpl;
        address strategyImpl;
        address escrowImpl;
    }

    struct HookAddresses {
        address approveErc20Hook;
        address transferErc20Hook;
        address batchTransferHook;
        address batchTransferFromHook;
        address offrampTokensHook;
        address deposit4626VaultHook;
        address approveAndDeposit4626VaultHook;
        address redeem4626VaultHook;
        address deposit5115VaultHook;
        address redeem5115VaultHook;
        address approveAndDeposit5115VaultHook;
        address deposit7540VaultHook;
        address requestDeposit7540VaultHook;
        address approveAndRequestDeposit7540VaultHook;
        address approveAndRequestRedeem7540VaultHook;
        address redeem7540VaultHook;
        address requestRedeem7540VaultHook;
        address withdraw7540VaultHook;
        address acrossSendFundsAndExecuteOnDstHook;
        address swap1InchHook;
        address swapOdosHook;
        address approveAndSwapOdosHook;
        address cancelDepositRequest7540Hook;
        address cancelRedeemRequest7540Hook;
        address claimCancelDepositRequest7540Hook;
        address claimCancelRedeemRequest7540Hook;
        address cancelRedeemHook;
        address deBridgeSendOrderAndExecuteOnDstHook;
        address deBridgeCancelOrderHook;
        address ethenaCooldownSharesHook;
        address ethenaUnstakeHook;
    }

    function run(uint256 env, uint64 chainId, string memory saltNamespace) public broadcast(env) {
        _setConfiguration(env, saltNamespace);
        console2.log("Deploying V2 Periphery on chainId: ", chainId);

        _deployDeployer();

        // Deploy periphery contracts
        PeripheryContracts memory peripheryContracts = _deployPeripheryContracts(chainId);

        // Read hook addresses from core deployment
        HookAddresses memory hookAddresses = _readHookAddresses(chainId);

        // Register hooks and configure governor
        _registerHooks(hookAddresses, SuperGovernor(peripheryContracts.superGovernor));
        _configureGovernor(SuperGovernor(peripheryContracts.superGovernor), peripheryContracts.superVaultAggregator);

        // Grant roles and revoke from deployer
        _configureGovernorRoles(SuperGovernor(peripheryContracts.superGovernor));

        // Write all exported contracts for this chain
        _writeExportedContracts(chainId);
    }

    function _readHookAddresses(uint64 chainId) internal view returns (HookAddresses memory) {
        string memory coreJson = _readCoreContracts(chainId);

        HookAddresses memory hookAddresses;
        hookAddresses.approveErc20Hook = vm.parseJsonAddress(coreJson, ".ApproveERC20Hook");
        hookAddresses.transferErc20Hook = vm.parseJsonAddress(coreJson, ".TransferERC20Hook");
        hookAddresses.batchTransferHook = vm.parseJsonAddress(coreJson, ".BatchTransferHook");
        hookAddresses.batchTransferFromHook = vm.parseJsonAddress(coreJson, ".BatchTransferFromHook");
        hookAddresses.offrampTokensHook = vm.parseJsonAddress(coreJson, ".OfframpTokensHook");
        hookAddresses.deposit4626VaultHook = vm.parseJsonAddress(coreJson, ".Deposit4626VaultHook");
        hookAddresses.approveAndDeposit4626VaultHook = vm.parseJsonAddress(coreJson, ".ApproveAndDeposit4626VaultHook");
        hookAddresses.redeem4626VaultHook = vm.parseJsonAddress(coreJson, ".Redeem4626VaultHook");
        hookAddresses.deposit5115VaultHook = vm.parseJsonAddress(coreJson, ".Deposit5115VaultHook");
        hookAddresses.redeem5115VaultHook = vm.parseJsonAddress(coreJson, ".Redeem5115VaultHook");
        hookAddresses.approveAndDeposit5115VaultHook = vm.parseJsonAddress(coreJson, ".ApproveAndDeposit5115VaultHook");
        hookAddresses.deposit7540VaultHook = vm.parseJsonAddress(coreJson, ".Deposit7540VaultHook");
        hookAddresses.requestDeposit7540VaultHook = vm.parseJsonAddress(coreJson, ".RequestDeposit7540VaultHook");
        hookAddresses.approveAndRequestDeposit7540VaultHook =
            vm.parseJsonAddress(coreJson, ".ApproveAndRequestDeposit7540VaultHook");
        hookAddresses.approveAndRequestRedeem7540VaultHook =
            vm.parseJsonAddress(coreJson, ".ApproveAndRequestRedeem7540VaultHook");
        hookAddresses.redeem7540VaultHook = vm.parseJsonAddress(coreJson, ".Redeem7540VaultHook");
        hookAddresses.requestRedeem7540VaultHook = vm.parseJsonAddress(coreJson, ".RequestRedeem7540VaultHook");
        hookAddresses.withdraw7540VaultHook = vm.parseJsonAddress(coreJson, ".Withdraw7540VaultHook");
        hookAddresses.acrossSendFundsAndExecuteOnDstHook =
            vm.parseJsonAddress(coreJson, ".AcrossSendFundsAndExecuteOnDstHook");
        hookAddresses.swap1InchHook = vm.parseJsonAddress(coreJson, ".Swap1InchHook");
        hookAddresses.swapOdosHook = vm.parseJsonAddress(coreJson, ".SwapOdosV2Hook");
        hookAddresses.approveAndSwapOdosHook = vm.parseJsonAddress(coreJson, ".ApproveAndSwapOdosV2Hook");
        hookAddresses.cancelDepositRequest7540Hook = vm.parseJsonAddress(coreJson, ".CancelDepositRequest7540Hook");
        hookAddresses.cancelRedeemRequest7540Hook = vm.parseJsonAddress(coreJson, ".CancelRedeemRequest7540Hook");
        hookAddresses.claimCancelDepositRequest7540Hook =
            vm.parseJsonAddress(coreJson, ".ClaimCancelDepositRequest7540Hook");
        hookAddresses.claimCancelRedeemRequest7540Hook =
            vm.parseJsonAddress(coreJson, ".ClaimCancelRedeemRequest7540Hook");
        hookAddresses.cancelRedeemHook = vm.parseJsonAddress(coreJson, ".CancelRedeemHook");
        hookAddresses.deBridgeSendOrderAndExecuteOnDstHook =
            vm.parseJsonAddress(coreJson, ".DeBridgeSendOrderAndExecuteOnDstHook");
        hookAddresses.deBridgeCancelOrderHook = vm.parseJsonAddress(coreJson, ".DeBridgeCancelOrderHook");
        hookAddresses.ethenaCooldownSharesHook = vm.parseJsonAddress(coreJson, ".EthenaCooldownSharesHook");
        hookAddresses.ethenaUnstakeHook = vm.parseJsonAddress(coreJson, ".EthenaUnstakeHook");

        return hookAddresses;
    }

    function _deployPeripheryContracts(uint64 chainId)
        internal
        returns (PeripheryContracts memory peripheryContracts)
    {
        // retrieve deployer
        ISuperDeployer deployer = ISuperDeployer(configuration.deployer);

        // Deploy SuperGovernor
        peripheryContracts.superGovernor = __deployContract(
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

        // Deploy SuperVault implementations first
        peripheryContracts.vaultImpl = __deployContract(
            deployer,
            "SuperVaultImplementation",
            chainId,
            __getSalt(configuration.owner, configuration.deployer, "SuperVaultImplementation"),
            type(SuperVault).creationCode
        );

        peripheryContracts.strategyImpl = __deployContract(
            deployer,
            "SuperVaultStrategyImplementation",
            chainId,
            __getSalt(configuration.owner, configuration.deployer, "SuperVaultStrategyImplementation"),
            type(SuperVaultStrategy).creationCode
        );

        peripheryContracts.escrowImpl = __deployContract(
            deployer,
            "SuperVaultEscrowImplementation",
            chainId,
            __getSalt(configuration.owner, configuration.deployer, "SuperVaultEscrowImplementation"),
            type(SuperVaultEscrow).creationCode
        );

        // Deploy SuperVaultAggregator (takes all four addresses)
        peripheryContracts.superVaultAggregator = __deployContract(
            deployer,
            SUPER_VAULT_AGGREGATOR_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, SUPER_VAULT_AGGREGATOR_KEY),
            abi.encodePacked(
                type(SuperVaultAggregator).creationCode,
                abi.encode(
                    peripheryContracts.superGovernor,
                    peripheryContracts.vaultImpl,
                    peripheryContracts.strategyImpl,
                    peripheryContracts.escrowImpl
                )
            )
        );

        // Deploy ECDSAPPSOracle
        peripheryContracts.ecdsappsOracle = __deployContract(
            deployer,
            ECDSAPPS_ORACLE_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, ECDSAPPS_ORACLE_KEY),
            abi.encodePacked(type(ECDSAPPSOracle).creationCode, abi.encode(peripheryContracts.superGovernor))
        );

        // Deploy SuperOracle
        peripheryContracts.superOracle = __deployContract(
            deployer,
            SUPER_ORACLE_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, SUPER_ORACLE_KEY),
            abi.encodePacked(
                type(SuperOracle).creationCode,
                abi.encode(configuration.owner, new address[](0), new address[](0), new uint256[](0), new bytes32[](0))
            )
        );

        // Deploy SuperYieldSourceOracle
        peripheryContracts.superYieldSourceOracle = __deployContract(
            deployer,
            SUPER_YIELD_SOURCE_ORACLE_KEY,
            chainId,
            __getSalt(configuration.owner, configuration.deployer, SUPER_YIELD_SOURCE_ORACLE_KEY),
            abi.encodePacked(type(SuperYieldSourceOracle).creationCode, abi.encode(peripheryContracts.superOracle))
        );

        // Configure SuperGovernor with oracle and validator
        SuperGovernor(peripheryContracts.superGovernor).setActivePPSOracle(peripheryContracts.ecdsappsOracle);
        SuperGovernor(peripheryContracts.superGovernor).addValidator(configuration.validator);

        console2.log("All periphery contracts deployed successfully.");

        return peripheryContracts;
    }

    function _registerHooks(HookAddresses memory hookAddresses, SuperGovernor superGovernor) internal {
        // Register fulfillRequests hooks
        superGovernor.registerHook(hookAddresses.deposit4626VaultHook, true);
        superGovernor.registerHook(hookAddresses.approveAndDeposit4626VaultHook, true);
        superGovernor.registerHook(hookAddresses.redeem4626VaultHook, true);
        superGovernor.registerHook(hookAddresses.deposit5115VaultHook, true);
        superGovernor.registerHook(hookAddresses.approveAndDeposit5115VaultHook, true);
        superGovernor.registerHook(hookAddresses.redeem5115VaultHook, true);
        superGovernor.registerHook(hookAddresses.deposit7540VaultHook, true);
        superGovernor.registerHook(hookAddresses.redeem7540VaultHook, true);
        superGovernor.registerHook(hookAddresses.approveAndRequestRedeem7540VaultHook, true);

        // Register remaining hooks
        superGovernor.registerHook(hookAddresses.approveErc20Hook, false);
        superGovernor.registerHook(hookAddresses.transferErc20Hook, false);
        superGovernor.registerHook(hookAddresses.batchTransferHook, false);
        superGovernor.registerHook(hookAddresses.batchTransferFromHook, false);
        superGovernor.registerHook(hookAddresses.requestDeposit7540VaultHook, false);
        superGovernor.registerHook(hookAddresses.approveAndRequestDeposit7540VaultHook, false);
        superGovernor.registerHook(hookAddresses.requestRedeem7540VaultHook, false);
        superGovernor.registerHook(hookAddresses.withdraw7540VaultHook, false);
        superGovernor.registerHook(hookAddresses.swap1InchHook, false);
        superGovernor.registerHook(hookAddresses.swapOdosHook, false);
        superGovernor.registerHook(hookAddresses.approveAndSwapOdosHook, false);
        superGovernor.registerHook(hookAddresses.acrossSendFundsAndExecuteOnDstHook, false);
        superGovernor.registerHook(hookAddresses.deBridgeSendOrderAndExecuteOnDstHook, false);
        superGovernor.registerHook(hookAddresses.deBridgeCancelOrderHook, false);
        superGovernor.registerHook(hookAddresses.cancelDepositRequest7540Hook, false);
        superGovernor.registerHook(hookAddresses.cancelRedeemRequest7540Hook, false);
        superGovernor.registerHook(hookAddresses.claimCancelDepositRequest7540Hook, false);
        superGovernor.registerHook(hookAddresses.claimCancelRedeemRequest7540Hook, false);
        superGovernor.registerHook(hookAddresses.cancelRedeemHook, false);
        superGovernor.registerHook(hookAddresses.ethenaCooldownSharesHook, false);
        superGovernor.registerHook(hookAddresses.ethenaUnstakeHook, false);
        superGovernor.registerHook(hookAddresses.offrampTokensHook, false);

        console2.log("All hooks registered successfully.");
    }

    function _configureGovernor(SuperGovernor superGovernor, address aggregator) internal {
        superGovernor.setAddress(superGovernor.SUPER_VAULT_AGGREGATOR(), aggregator);
        console2.log("SuperGovernor configured with SuperVaultAggregator.");
    }

    function _configureGovernorRoles(SuperGovernor superGovernor) internal {
        // Grant SUPER_GOVERNOR_ROLE to the validator address and revoke from TEST_DEPLOYER
        superGovernor.grantRole(keccak256("SUPER_GOVERNOR_ROLE"), 0xd95f4bc7733d9E94978244C0a27c1815878a59BB);
        console2.log("Granted SUPER_GOVERNOR_ROLE to: 0xd95f4bc7733d9E94978244C0a27c1815878a59BB");

        superGovernor.revokeRole(keccak256("SUPER_GOVERNOR_ROLE"), TEST_DEPLOYER);
        console2.log("Revoked SUPER_GOVERNOR_ROLE from TEST_DEPLOYER");
    }
}
