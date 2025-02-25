// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// testing
import { BaseTest } from "../../BaseTest.t.sol";

// external
import { console2 } from "forge-std/console2.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

import {
    RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, AccountType, UserOpData
} from "modulekit/ModuleKit.sol";

// superform
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { MerkleReader } from "../../utils/merkle/helper/MerkleReader.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVaultEscrow.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { ISuperLedgerData } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";
import { SuperVaultFactory } from "../../../src/periphery/SuperVaultFactory.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVaultStrategy.sol";
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";

contract BaseSuperVaultTest is BaseTest, MerkleReader {
    using ModuleKitHelpers for *;

    address public accountEth;
    AccountInstance public instanceOnEth;
    ISuperExecutor public superExecutorOnEth;

    // Core contracts
    SuperVaultFactory public factory;
    SuperVault public vault;
    SuperVaultStrategy public strategy;
    SuperVaultEscrow public escrow;

    // Roles
    address public SV_MANAGER;
    address public STRATEGIST;
    address public EMERGENCY_ADMIN;
    address public FEE_RECIPIENT;

    // Tokens and yield sources
    IERC20Metadata public asset;
    IERC4626 public fluidVault;
    IERC4626 public aaveVault;

    // Constants
    uint256 constant VAULT_CAP = 1_000_000e6; // 1M USDC
    uint256 constant SUPER_VAULT_CAP = 5_000_000e6; // 5M USDC
    uint256 constant MAX_ALLOCATION_RATE = 5000; // 50%
    uint256 constant VAULT_THRESHOLD = 100_000e6; // 100k USDC

    function setUp() public virtual override {
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        // Set up accounts
        accountEth = accountInstances[ETH].account;
        instanceOnEth = accountInstances[ETH];

        // Set up super executor
        superExecutorOnEth = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));

        // Deploy factory
        factory = new SuperVaultFactory(_getContract(ETH, SUPER_REGISTRY_KEY));

        // Set up roles
        SV_MANAGER = _deployAccount(MANAGER_KEY, "SV_MANAGER");
        STRATEGIST = _deployAccount(STRATEGIST_KEY, "STRATEGIST");
        EMERGENCY_ADMIN = _deployAccount(EMERGENCY_ADMIN_KEY, "EMERGENCY_ADMIN");
        FEE_RECIPIENT = _deployAccount(FEE_RECIPIENT_KEY, "FEE_RECIPIENT");

        // Get USDC from fork
        asset = IERC20Metadata(existingUnderlyingTokens[ETH][USDC_KEY]);

        address fluidVaultAddr = 0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33;
        address aaveVaultAddr = 0x73edDFa87C71ADdC275c2b9890f5c3a8480bC9E6;
        vm.label(fluidVaultAddr, "FluidVault");
        vm.label(aaveVaultAddr, "AaveVault");
        // Get real yield sources from fork
        fluidVault = IERC4626(fluidVaultAddr);
        aaveVault = IERC4626(aaveVaultAddr);

        // Deploy vault trio with initial config
        ISuperVaultStrategy.GlobalConfig memory config = ISuperVaultStrategy.GlobalConfig({
            vaultCap: VAULT_CAP,
            superVaultCap: SUPER_VAULT_CAP,
            maxAllocationRate: MAX_ALLOCATION_RATE,
            vaultThreshold: VAULT_THRESHOLD
        });

        // Deploy vault trio
        (address vaultAddr, address strategyAddr, address escrowAddr) = factory.createVault(
            address(asset), "SuperVault USDC", "svUSDC", SV_MANAGER, STRATEGIST, EMERGENCY_ADMIN, config, FEE_RECIPIENT
        );
        vm.label(vaultAddr, "SuperVault");
        vm.label(strategyAddr, "SuperVaultStrategy");
        vm.label(escrowAddr, "SuperVaultEscrow");

        // Cast addresses to contract types
        vault = SuperVault(vaultAddr);
        strategy = SuperVaultStrategy(strategyAddr);
        escrow = SuperVaultEscrow(escrowAddr);

        // Add yield sources as manager
        vm.startPrank(SV_MANAGER);
        strategy.addYieldSource(address(fluidVault), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY));
        strategy.addYieldSource(address(aaveVault), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY));
        vm.stopPrank();

        // Set up hook root
        bytes32 hookRoot = _getMerkleRoot();
        vm.startPrank(SV_MANAGER);
        strategy.proposeOrExecuteHookRoot(hookRoot);
        vm.warp(block.timestamp + 7 days);
        strategy.proposeOrExecuteHookRoot(bytes32(0));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function __requestDeposit(AccountInstance memory accInst, uint256 depositAmount) private {
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(address(asset), address(vault), depositAmount, false);
        hooksData[1] = _createRequestDeposit7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(vault), accInst.account, depositAmount, false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(accInst, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);
    }

    function __claimDeposit(AccountInstance memory accInst, uint256 depositAmount) private {
        address[] memory claimHooksAddresses = new address[](1);
        claimHooksAddresses[0] = _getHookAddress(ETH, DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory claimHooksData = new bytes[](1);
        claimHooksData[0] = _createDeposit7540VaultHookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(vault), accInst.account, depositAmount, false, false
        );

        ISuperExecutor.ExecutorEntry memory claimEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: claimHooksAddresses, hooksData: claimHooksData });
        UserOpData memory claimUserOpData = _getExecOps(accInst, superExecutorOnEth, abi.encode(claimEntry));
        executeOp(claimUserOpData);
    }

    function __requestRedeem(AccountInstance memory accInst, uint256 redeemShares, bool shouldRevert) private {
        address[] memory redeemHooksAddresses = new address[](1);
        redeemHooksAddresses[0] = _getHookAddress(ETH, REQUEST_WITHDRAW_7540_VAULT_HOOK_KEY);

        bytes[] memory redeemHooksData = new bytes[](1);
        redeemHooksData[0] = _createRequestWithdraw7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(vault), accInst.account, redeemShares, false
        );

        ISuperExecutor.ExecutorEntry memory redeemEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: redeemHooksAddresses, hooksData: redeemHooksData });
        UserOpData memory redeemUserOpData = _getExecOps(accInst, superExecutorOnEth, abi.encode(redeemEntry));

        if (shouldRevert) {
            accInst.expect4337Revert();
        }
        executeOp(redeemUserOpData);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _requestDeposit(uint256 depositAmount) internal {
        __requestDeposit(instanceOnEth, depositAmount);
    }

    function _requestDepositForAccount(AccountInstance memory accInst, uint256 depositAmount) internal {
        __requestDeposit(accInst, depositAmount);
    }

    function _fulfillDeposit(uint256 depositAmount) internal {
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accountEth;
        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](2);
        fulfillHooksAddresses[0] = depositHookAddress;
        fulfillHooksAddresses[1] = depositHookAddress;

        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = _getMerkleProof(depositHookAddress);
        proofs[1] = proofs[0];

        bytes[] memory fulfillHooksData = new bytes[](2);
        // allocate up to the max allocation rate in the two Vaults
        fulfillHooksData[0] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(fluidVault), depositAmount / 2, false, false
        );
        fulfillHooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(aaveVault), depositAmount / 2, false, false
        );

        vm.startPrank(STRATEGIST);
        strategy.fulfillDepositRequests(requestingUsers, fulfillHooksAddresses, proofs, fulfillHooksData);
        vm.stopPrank();
    }

    function _claimDeposit(uint256 depositAmount) internal {
        __claimDeposit(instanceOnEth, depositAmount);
    }

    function _claimDepositForAccount(AccountInstance memory accInst, uint256 depositAmount) internal {
        __claimDeposit(accInst, depositAmount);
    }

    function _requestRedeem(uint256 redeemShares) internal {
        __requestRedeem(instanceOnEth, redeemShares, false);
    }

    function _requestRedeemForAccount(AccountInstance memory accInst, uint256 redeemShares) internal {
        __requestRedeem(accInst, redeemShares, false);
    }

    function _requestRedeemForAccount_Revert(AccountInstance memory accInst, uint256 redeemShares) internal {
        __requestRedeem(accInst, redeemShares, true);
    }

    function _fulfillRedeem(uint256 redeemShares) internal {
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accountEth;
        address withdrawHookAddress = _getHookAddress(ETH, WITHDRAW_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](2);
        fulfillHooksAddresses[0] = withdrawHookAddress;
        fulfillHooksAddresses[1] = withdrawHookAddress;

        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = _getMerkleProof(withdrawHookAddress);
        proofs[1] = proofs[0];

        bytes[] memory fulfillHooksData = new bytes[](2);
        // Withdraw proportionally from both vaults
        fulfillHooksData[0] = _createWithdraw4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(fluidVault),
            address(strategy),
            redeemShares / 2,
            false,
            false
        );
        fulfillHooksData[1] = _createWithdraw4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(aaveVault),
            address(strategy),
            redeemShares / 2,
            false,
            false
        );

        vm.startPrank(STRATEGIST);
        strategy.fulfillRedeemRequests(requestingUsers, fulfillHooksAddresses, proofs, fulfillHooksData);
        vm.stopPrank();
    }

    function _claimWithdraw(uint256 assets) internal {
        address[] memory claimHooksAddresses = new address[](1);
        claimHooksAddresses[0] = _getHookAddress(ETH, WITHDRAW_7540_VAULT_HOOK_KEY);

        bytes[] memory claimHooksData = new bytes[](1);
        claimHooksData[0] = _createWithdraw7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(vault), accountEth, assets, false, false
        );

        ISuperExecutor.ExecutorEntry memory claimEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: claimHooksAddresses, hooksData: claimHooksData });
        UserOpData memory claimUserOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(claimEntry));
        executeOp(claimUserOpData);
    }

    function _claimWithdrawWithAccountingChecks(
        uint256 assets,
        uint256 expectedFee,
        address oracle
    ) internal {
        address[] memory claimHooksAddresses = new address[](1);
        claimHooksAddresses[0] = _getHookAddress(ETH, WITHDRAW_7540_VAULT_HOOK_KEY);

        bytes[] memory claimHooksData = new bytes[](1);
        claimHooksData[0] = _createWithdraw7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(vault), accountEth, assets, false, false
        );
        ISuperExecutor.ExecutorEntry memory claimEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: claimHooksAddresses, hooksData: claimHooksData });

        UserOpData memory claimUserOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(claimEntry));

        // vm.expectEmit(true, true, true, true);
        // emit ISuperLedgerData.AccountingOutflow(
        //     accountEth,
        //     oracle,
        //     address(vault),
        //     assets,
        //     expectedFee // add SV fee
        // );
        executeOp(claimUserOpData);
    }
}
