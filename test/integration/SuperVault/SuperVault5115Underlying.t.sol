// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// testing
import { BaseTest } from "../../BaseTest.t.sol";
import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

// external
import { console2 } from "forge-std/console2.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC5115 } from "../../../src/vendor/vaults/5115/IERC5115.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {
    RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, AccountType, UserOpData
} from "modulekit/ModuleKit.sol";

// superform
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVaultEscrow.sol";
import { ISuperVault } from "../../../src/periphery/interfaces/ISuperVault.sol";
import { ERC7540YieldSourceOracle } from "../../../src/core/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { ERC5115YieldSourceOracle } from "../../../src/core/accounting/oracles/ERC5115YieldSourceOracle.sol";
import { ISuperLedger, ISuperLedgerData } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { ISuperVaultFactory } from "../../../src/periphery/interfaces/ISuperVaultFactory.sol";
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVaultStrategy.sol";

contract SuperVault5115Underlying is BaseSuperVaultTest {
    IERC5115 public pendleEthena;
    address public pendleEthenaAddress;

    address public account;
    AccountInstance public instance;

    SuperVault public superVaultsUSDE;
    SuperVaultEscrow public superVaultEscrowsUSDE;
    SuperVaultStrategy public superVaultStrategysUSDE;

    uint256 public amountToDeposit;

    function setUp() public override {
        super.setUp();

        amountToDeposit = 1000e6;

        vm.selectFork(FORKS[ETH]);

        // Set up accounts
        account = accountInstances[ETH].account;
        instance = accountInstances[ETH];

        // Get USDC from fork
        asset = IERC20Metadata(existingUnderlyingTokens[ETH][SUSDE_KEY]);
        vm.label(address(asset), "sUSDE");

        pendleEthenaAddress = realVaultAddresses[ETH][ERC5115_VAULT_KEY][PENDLE_ETHEANA_KEY][SUSDE_KEY];
        vm.label(pendleEthenaAddress, "PendleEthena");

        // Get real yield sources from fork
        pendleEthena = IERC5115(pendleEthena);

        // Deploy vault trio with initial config
        ISuperVaultStrategy.GlobalConfig memory config = ISuperVaultStrategy.GlobalConfig({
            vaultCap: VAULT_CAP,
            superVaultCap: SUPER_VAULT_CAP,
            maxAllocationRate: ONE_HUNDRED_PERCENT,
            vaultThreshold: VAULT_THRESHOLD
        });
        bytes32 hookRoot = _getMerkleRoot();
        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_5115_VAULT_HOOK_KEY);
        console2.log("depositHookAddress", depositHookAddress);

        address[] memory bootstrapHooks = new address[](1);
        bootstrapHooks[0] = depositHookAddress;

        bytes32[][] memory bootstrapHookProofs = new bytes32[][](1);
        bootstrapHookProofs[0] = _getMerkleProof(depositHookAddress);

        bytes[] memory bootstrapHooksData = new bytes[](1);
        bootstrapHooksData[0] = _createDeposit5115VaultHookData(
            bytes4(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)), 
            pendleEthenaAddress, 
            address(asset), 
            BOOTSTRAP_AMOUNT,
            BOOTSTRAP_AMOUNT,
            false, 
            false
        );

        vm.startPrank(SV_MANAGER);
        deal(address(asset), SV_MANAGER, BOOTSTRAP_AMOUNT * 2);
        asset.approve(address(factory), BOOTSTRAP_AMOUNT * 2);

        // Deploy vault trio
        (address vaultAddr, address strategyAddr, address escrowAddr) = factory.createVault(
            ISuperVaultFactory.VaultCreationParams({
                asset: address(asset),
                name: "SuperVault sUSDE",
                symbol: "svsUSDE",
                manager: SV_MANAGER,
                strategist: STRATEGIST,
                emergencyAdmin: EMERGENCY_ADMIN,
                feeRecipient: TREASURY,
                config: config,
                finalMaxAllocationRate: ONE_HUNDRED_PERCENT,
                bootstrapAmount: BOOTSTRAP_AMOUNT,
                initYieldSource: pendleEthenaAddress,
                initHooksRoot: hookRoot,
                initYieldSourceOracle: _getContract(ETH, ERC5115_YIELD_SOURCE_ORACLE_KEY),
                bootstrappingHooks: bootstrapHooks,
                bootstrappingHookProofs: bootstrapHookProofs,
                bootstrappingHookCalldata: bootstrapHooksData
            })
        );
        vm.label(vaultAddr, "SuperVaultsUSDE");
        vm.label(escrowAddr, "SuperVaultEscrowUSDE");
        vm.label(strategyAddr, "SuperVaultStrategyUSDE");

        vm.stopPrank();

        // Cast addresses to contract types
        superVaultsUSDE = SuperVault(vaultAddr);
        superVaultEscrowsUSDE = SuperVaultEscrow(escrowAddr);
        superVaultStrategysUSDE = SuperVaultStrategy(strategyAddr);

        _setFeeConfig(100, TREASURY);

        // Set up hook root (same one as bootstrap, just to test)
        vm.startPrank(SV_MANAGER);
        superVaultStrategysUSDE.proposeOrExecuteHookRoot(hookRoot);
        vm.warp(block.timestamp + 7 days);
        superVaultStrategysUSDE.proposeOrExecuteHookRoot(bytes32(0));
        vm.stopPrank();
    }

    function test_SuperVault_5115_Underlying_E2EFlow() public {
        vm.selectFork(FORKS[ETH]);

        // Record initial balances
        uint256 initialUserAssets = asset.balanceOf(accountEth);

        // Step 1: Request Deposit
        _requestSV5115Deposit(amountToDeposit);

        // Verify assets transferred from user to vault
        assertEq(
            asset.balanceOf(account), initialUserAssets - amountToDeposit, "User assets not reduced after deposit request"
        );

        // Step 2: Fulfill Deposit
        _fulfillSV5115Deposit(amountToDeposit);

        // Step 3: Claim Deposit
        _claimSV_5115Deposit(amountToDeposit);

        console2.log("----deposit done ---");

        // Get shares minted to user
        uint256 userShares = IERC20(superVaultsUSDE.share()).balanceOf(account);

        // Record balances before redeem
        uint256 preRedeemUserAssets = asset.balanceOf(account);
        uint256 feeBalanceBefore = asset.balanceOf(TREASURY);

        // Fast forward time to simulate yield on underlying vaults
        vm.warp(block.timestamp + 50 weeks);

        uint256 totalRedeemShares = superVaultsUSDE.balanceOf(account);

        // Step 4: Request Redeem
        _requestRedeemSV_5115(userShares);

        // Verify shares are escrowed
        assertEq(IERC20(superVaultsUSDE.share()).balanceOf(account), 0, "User shares not transferred from account");
        assertEq(IERC20(superVaultsUSDE.share()).balanceOf(address(superVaultEscrowsUSDE)), userShares, "Shares not transferred to escrow");

        _fulfillRedeemSV_5115(totalRedeemShares);

        uint256 claimableAssets = superVaultsUSDE.maxWithdraw(account);
    }

    function _requestSV5115Deposit(uint256 amount) internal {
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(address(asset), address(superVaultsUSDE), amount, false);
        hooksData[1] = _createRequestDeposit7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(superVaultsUSDE), account, amount, false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);
    }

    function _fulfillSV5115Deposit(uint256 amount) internal {
        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_5115_VAULT_HOOK_KEY);

        address[] memory hooks_ = new address[](1);
        hooks_[0] = depositHookAddress;

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = _getMerkleProof(depositHookAddress);

        bytes[] memory hookCalldata = new bytes[](1);
        hookCalldata[0] = _createDeposit5115VaultHookData(
            bytes4(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)),
            pendleEthenaAddress,
            address(asset),
            amount,
            amount,
            false,
            false
        );

        address[] memory users = new address[](1);
        users[0] = account;

        vm.startPrank(STRATEGIST);
        superVaultStrategysUSDE.fulfillRequests(users, hooks_, proofs, hookCalldata, true);
        vm.stopPrank();
    }

    function _claimSV_5115Deposit(uint256 amount) internal {
        address[] memory claimHooksAddresses = new address[](1);
        claimHooksAddresses[0] = _getHookAddress(ETH, DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory claimHooksData = new bytes[](1);
        claimHooksData[0] = _createDeposit7540VaultHookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(superVaultsUSDE), account, amount, false, false
        );

        ISuperExecutor.ExecutorEntry memory claimEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: claimHooksAddresses, hooksData: claimHooksData });
        UserOpData memory claimUserOpData = _getExecOps(instance, superExecutorOnEth, abi.encode(claimEntry));
        executeOp(claimUserOpData);
    }

    function _requestRedeemSV_5115(uint256 redeemShares) internal {
        address[] memory redeemHooksAddresses = new address[](1);
        redeemHooksAddresses[0] = _getHookAddress(ETH, REQUEST_WITHDRAW_7540_VAULT_HOOK_KEY);

        bytes[] memory redeemHooksData = new bytes[](1);
        redeemHooksData[0] = _createRequestWithdraw7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(superVaultsUSDE), account, redeemShares, false
        );

        ISuperExecutor.ExecutorEntry memory redeemEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: redeemHooksAddresses, hooksData: redeemHooksData });
        UserOpData memory redeemUserOpData = _getExecOps(instance, superExecutorOnEth, abi.encode(redeemEntry));

        executeOp(redeemUserOpData);
    }

    function _fulfillRedeemSV_5115(uint256 totalRedeemShares) internal {
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = account;

        address withdrawHookAddress = _getHookAddress(ETH, WITHDRAW_5115_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](1);
        fulfillHooksAddresses[0] = withdrawHookAddress;

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = _getMerkleProof(withdrawHookAddress);

        bytes[] memory fulfillHooksData = new bytes[](1);
        fulfillHooksData[0] = _create5115WithdrawHookData(
            bytes4(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)),
            address(superVaultsUSDE),
            account,
            totalRedeemShares,
            totalRedeemShares,
            false,
            false
        );

        vm.startPrank(STRATEGIST);
        superVaultStrategysUSDE.fulfillRequests(requestingUsers, fulfillHooksAddresses, proofs, fulfillHooksData, false);
        vm.stopPrank();
    }
    
}
