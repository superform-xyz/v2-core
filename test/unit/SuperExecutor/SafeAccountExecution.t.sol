// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    AccountInstance,
    UserOpData,
    PackedUserOperation,
    AccountType
} from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { Safe7579Precompiles } from "modulekit/deployment/precompiles/Safe7579Precompiles.sol";
import { ISafe7579 } from "modulekit/accounts/safe/interfaces/ISafe7579.sol";
import { ISafe7579Launchpad, ModuleInit } from "modulekit/accounts/safe/interfaces/ISafe7579Launchpad.sol";
import { IERC7579Account, Execution } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import { SafeFactory } from "modulekit/accounts/safe/SafeFactory.sol";
import { IAccountFactory } from "modulekit/accounts/factory/interface/IAccountFactory.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IValidator } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { IStakeManager } from "modulekit/external/ERC4337.sol";

// --safe
import { Safe } from "@safe/Safe.sol";

// Safe7579 EIP712
import { EIP712 } from "@safe7579/lib/EIP712.sol";

// Superform
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { SuperExecutorBase } from  "../../../src/executors/SuperExecutorBase.sol";
import { SuperValidatorBase } from  "../../../src/validators/SuperValidatorBase.sol";
import { ApproveERC20Hook } from "../../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { AcrossV3Adapter } from "../../../src/adapters/AcrossV3Adapter.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MaliciousSafeAccount } from "../../mocks/MaliciousSafeAccount.sol";
import { SuperMerkleValidator } from "../../../src/validators/SuperMerkleValidator.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { ISuperDestinationExecutor } from "../../../src/interfaces/ISuperDestinationExecutor.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";
import { MockHook } from "../../mocks/MockHook.sol";
import { BaseTest } from "../../BaseTest.t.sol";

import "forge-std/console2.sol";
import "forge-std/Test.sol";

contract SafeAccountExecution is Safe7579Precompiles, BaseTest {
    using BytesLib for bytes;
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    /// @notice Structure to hold variables for cross-chain execution tests
    /// @dev Used to mitigate stack too deep errors in test functions
    struct CrossChainTestVars {
        // Execution parameters
        uint256 amountPerVault;
        uint256 warpStartTime;
        bytes initData;
        address predictedAddress;
        bytes initCode;
        // Account instances
        AccountInstance instanceOp;
        AccountInstance instanceBase;
        address accountOp;
        address accountBase;
        // Message data
        bytes targetExecutorMessage;
        TargetExecutorMessage messageData;
        address accountToUse;
        // Target chain (OP) data
        address[] opHooksAddresses;
        bytes[] opHooksData;
        uint256 previewDepositAmountOP;
        // Source chain (BASE) data
        address[] srcHooksAddresses;
        bytes[] srcHooksData;
        uint256 userBalanceBaseUSDCBefore;
        ISuperExecutor.ExecutorEntry entryToExecute;
        UserOpData srcUserOpData;
        // Proof data
        MerkleContext ctx;
        ISuperValidator.DstProof[] proofDst;
        bytes signature;
        bytes signatureData;
    }

    struct SignatureData {
        bytes32 rawHash;
        bytes32 domainSeparator;
        bytes32 finalHash;
        uint8 v1;
        uint8 v2;
        bytes32 r1;
        bytes32 r2;
        bytes32 s1;
        bytes32 s2;
        address recovered1;
        address recovered2;
    }

    // SafeERC7579
    // -- erc7579 account
    AccountInstance instance;
    address account;
    bytes32 accountSalt;

    // -- owners
    uint256 privateKey1;
    uint256 privateKey2;
    address owner1;
    address owner2;
    address[] owners;
    // -- multisig safe
    uint256 threshold = 2;
    bytes4 constant ERC1271_MAGICVALUE = 0x1626ba7e;

    // Superform
    // -- same-chain
    ApproveERC20Hook approveERC20Hook;
    SuperLedgerConfiguration superLedgerConfiguration;
    SuperExecutor superExecutor;
    MockERC20 mockERC20;
    SuperMerkleValidator validator;
    // -- cross-chain
    address underlyingOpUsdce;
    address underlyingBaseUsdc;
    address yieldSource4626AddressOpUsdce;
    IERC4626 vaultInstance4626OP;
    AcrossV3Adapter acrossV3AdapterOnOP;
    IValidator validatorOnOP;
    IValidator validatorOnETH;
    IValidator sourceValidatorOnBase;
    IValidator sourceValidatorOnETH;
    ISuperExecutor superSourceExecutorOnBase;
    ISuperExecutor superSourceExecutorOnETH;
    ISuperDestinationExecutor superDestinationExecutorOnOP;
    ISuperDestinationExecutor superDestinationExecutorOnETH;
    // -- 
    address underlyingETH_USDC;
    address yieldSourceMorphoUsdcAddressEth;
    IERC4626 vaultInstanceMorphoEth;
    ISuperNativePaymaster superNativePaymaster;
    
    // used to simulate a malicious mid execution module uninstall
    MockHook mockHook;

    function setUp() public override {
        skipAccountsCreation = true;
        super.setUp();
        accountSalt = keccak256(abi.encode("acc1"));

        // -- same-chain
        approveERC20Hook = new ApproveERC20Hook();
        mockERC20 = new MockERC20("MockERC20", "MOCK", 18);
        superLedgerConfiguration = new SuperLedgerConfiguration();
        superExecutor = new SuperExecutor(address(superLedgerConfiguration));
        validator = new SuperMerkleValidator();

        // -- cross-chain
        underlyingOpUsdce = existingUnderlyingTokens[OP][USDCe_KEY];
        underlyingBaseUsdc = existingUnderlyingTokens[BASE][USDC_KEY];
        yieldSource4626AddressOpUsdce = realVaultAddresses[OP][ERC4626_VAULT_KEY][ALOE_USDC_VAULT_KEY][USDCe_KEY];
        vaultInstance4626OP = IERC4626(yieldSource4626AddressOpUsdce);
        acrossV3AdapterOnOP = AcrossV3Adapter(_getContract(OP, ACROSS_V3_ADAPTER_KEY));
        validatorOnOP = IValidator(_getContract(OP, SUPER_DESTINATION_VALIDATOR_KEY));
        validatorOnETH = IValidator(_getContract(ETH, SUPER_DESTINATION_VALIDATOR_KEY));
        sourceValidatorOnBase = IValidator(_getContract(BASE, SUPER_MERKLE_VALIDATOR_KEY));
        sourceValidatorOnETH = IValidator(_getContract(ETH, SUPER_MERKLE_VALIDATOR_KEY));
        superSourceExecutorOnBase = ISuperExecutor(_getContract(BASE, SUPER_EXECUTOR_KEY));
        superSourceExecutorOnETH = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        superDestinationExecutorOnOP = ISuperDestinationExecutor(_getContract(OP, SUPER_DESTINATION_EXECUTOR_KEY));
        superDestinationExecutorOnETH = ISuperDestinationExecutor(_getContract(ETH, SUPER_DESTINATION_EXECUTOR_KEY));

        vm.label(address(superLedgerConfiguration), "Superform ledger config");
        vm.label(address(superExecutor), "Superform executor");
        vm.label(address(validator), "Superform validator");
        vm.label(address(approveERC20Hook), "Superform ApproveERC20Hook");
        vm.label(address(mockERC20), "Superform MockERC20");
        vm.label(underlyingOpUsdce, "underlyingOpUsdce");

        // safe
        privateKey1 = 1;
        owner1 = vm.addr(privateKey1);
        privateKey2 = 2;
        owner2 = vm.addr(privateKey2);

        owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;

        underlyingETH_USDC = existingUnderlyingTokens[ETH][USDC_KEY];
        yieldSourceMorphoUsdcAddressEth =
            realVaultAddresses[ETH][ERC4626_VAULT_KEY][MORPHO_VAULT_KEY][USDC_KEY];
        vaultInstanceMorphoEth = IERC4626(yieldSourceMorphoUsdcAddressEth);
        vm.label(yieldSourceMorphoUsdcAddressEth, "YIELD_SOURCE_MORPHO_USDC_ETH");

        superNativePaymaster = ISuperNativePaymaster(_getContract(ETH, SUPER_NATIVE_PAYMASTER_KEY));
    }

    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/
    function test_SafeAccountType() public usingAccountEnv(AccountType.SAFE) {
        instance = makeAccountInstance(accountSalt);
        account = instance.account;
        assertEq(uint256(instance.accountType), uint256(AccountType.SAFE), "not safe");
    }

    function test_SafeAccount_Mutability_Execution() public {
        vm.selectFork(FORKS[ETH]);

        _initializeModuleKit("SAFE", keccak256("123"));
        address safeFactory = _getFactory("SAFE");
        deal(safeFactory, 10 ether);
        vm.prank(safeFactory);
        IStakeManager(ENTRYPOINT_ADDR).addStake{ value: 10 ether }(100_000);

        // setup SafeERC7579
        bytes memory initData = _getInitData();
        address predictedAddress = IAccountFactory(_getFactory("SAFE")).getAddress(accountSalt, initData);
        bytes memory initCode = abi.encodePacked(
            address(_getFactory("SAFE")), abi.encodeCall(IAccountFactory.createAccount, (accountSalt, initData))
        );
        instance = makeAccountInstance(accountSalt, predictedAddress, initCode);
        account = instance.account;
        deal(account, 1 ether);
        assertEq(uint256(instance.accountType), uint256(AccountType.SAFE), "not safe");
        
        // Start event recording for module installation
        vm.recordLogs();
        
        // Install modules and check events
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superSourceExecutorOnETH), data: "" });
        
        // Verify ModuleInstalled event for superSourceExecutorOnETH
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 1, "wrong number of events emitted during first module installation");
        
        // Clear logs and install next module
        vm.recordLogs();
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superDestinationExecutorOnETH), data: "" });
        
        // Verify ModuleInstalled event for superDestinationExecutorOnETH
        entries = vm.getRecordedLogs();
        assertEq(entries.length, 1, "wrong number of events emitted during second module installation");
        
        // Clear logs and install validator
        vm.recordLogs();
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(sourceValidatorOnETH),
            data: abi.encode(address(predictedAddress))
        });
        
        // Verify ModuleInstalled event for validator
        entries = vm.getRecordedLogs();
        assertEq(entries.length, 1, "wrong number of events emitted during validator installation");

        // check installed modules
        // -- check executor
        // -- check validator
        assertTrue(SuperExecutorBase(address(superSourceExecutorOnETH)).isInitialized(account), "executor source not installed");
        assertTrue(SuperExecutorBase(address(superDestinationExecutorOnETH)).isInitialized(account), "executor destination not installed");
        assertTrue(SuperValidatorBase(address(sourceValidatorOnETH)).isInitialized(account), "validator not installed");

        // deposit & assert
        uint256 amount = 1e8;
        uint256 accountVaultBalanceBefore = vaultInstanceMorphoEth.balanceOf(account);
        assertEq(accountVaultBalanceBefore, 0, "vault shares should not exist");
        _performDeposit(account, amount, address(sourceValidatorOnETH), address(superNativePaymaster), address(superSourceExecutorOnETH));
        uint256 accountVaultBalanceAfter = vaultInstanceMorphoEth.balanceOf(account);
        assertGt(accountVaultBalanceAfter, accountVaultBalanceBefore, "vault shares were not minted");

        // Record events during module uninstallation
        vm.recordLogs();
        
        // uninstall superDestinationExecutorOnETH
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, address(superDestinationExecutorOnETH), "");
        
        // Verify ModuleUninstalled event
        entries = vm.getRecordedLogs();
        assertEq(entries.length, 1, "wrong number of events emitted during module uninstallation");
        
        assertFalse(SuperExecutorBase(address(superDestinationExecutorOnETH)).isInitialized(account), "executor destination still installed");

        // assert balance of vault 
        uint256 accountVaultBalanceAfterUninstall = vaultInstanceMorphoEth.balanceOf(account);
        assertEq(accountVaultBalanceAfterUninstall, accountVaultBalanceAfter, "vault shares should be the same");

        // perform offramp hook
        address receiver = makeAddr("RECEIVER");
        _performOfframp(receiver, account, address(sourceValidatorOnETH), address(superNativePaymaster), address(superSourceExecutorOnETH));

        // assert balance of vault 
        uint256 accountVaultBalanceAfterOfframp = vaultInstanceMorphoEth.balanceOf(account);
        assertEq(accountVaultBalanceAfterOfframp, 0, "vault shares should be 0 after off ramp");
        uint256 receiverVaultBalanceAfterOfframp = vaultInstanceMorphoEth.balanceOf(receiver);
        assertEq(receiverVaultBalanceAfterOfframp, accountVaultBalanceAfterUninstall, "vault shares should have been trasnferred");

        // Record events during module reinstallation
        vm.recordLogs();
        
        // re-install removed executor
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superDestinationExecutorOnETH), data: "" });
        
        // Verify ModuleInstalled event for reinstallation
        entries = vm.getRecordedLogs();
        assertEq(entries.length, 1, "wrong number of events emitted during module reinstallation");
        
        assertTrue(SuperExecutorBase(address(superDestinationExecutorOnETH)).isInitialized(account), "executor destination should be reinstalled");
        uint256 accountVaultBalanceAfterReinstall = vaultInstanceMorphoEth.balanceOf(account);
        assertEq(accountVaultBalanceAfterReinstall, 0, "vault shares should be 0 after reinstall");
    }


     function test_SafeAccount_UninstallMidExecution_DoNotWork() public {
        vm.selectFork(FORKS[ETH]);

        _initializeModuleKit("SAFE", keccak256("123"));
        address safeFactory = _getFactory("SAFE");
        deal(safeFactory, 10 ether);
        vm.prank(safeFactory);
        IStakeManager(ENTRYPOINT_ADDR).addStake{ value: 10 ether }(100_000);

        // setup SafeERC7579
        bytes memory initData = _getInitData();
        address predictedAddress = IAccountFactory(_getFactory("SAFE")).getAddress(accountSalt, initData);
        bytes memory initCode = abi.encodePacked(
            address(_getFactory("SAFE")), abi.encodeCall(IAccountFactory.createAccount, (accountSalt, initData))
        );
        instance = makeAccountInstance(accountSalt, predictedAddress, initCode);
        account = instance.account;
        deal(account, 1 ether);
        assertEq(uint256(instance.accountType), uint256(AccountType.SAFE), "not safe");
        
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superSourceExecutorOnETH), data: "" });
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superDestinationExecutorOnETH), data: "" });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validatorOnETH),
            data: abi.encode(address(predictedAddress))
        });
        
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(sourceValidatorOnETH),
            data: abi.encode(address(predictedAddress))
        });
        
        // Verify ModuleInstalled event for validator

        // check installed modules
        // -- check executor
        // -- check validator
        assertTrue(SuperExecutorBase(address(superSourceExecutorOnETH)).isInitialized(account), "executor source not installed");
        assertTrue(SuperExecutorBase(address(superDestinationExecutorOnETH)).isInitialized(account), "executor destination not installed");
        assertTrue(SuperValidatorBase(address(sourceValidatorOnETH)).isInitialized(account), "validator not installed");

        // create malicious uninstall validator hook
        mockHook = new MockHook(ISuperHook.HookType.NONACCOUNTING, address(this));
        vm.label(address(mockHook), "MockHook");

        // deposit & assert
        uint256 amount = 1e8;
        uint256 accountVaultBalanceBefore = vaultInstanceMorphoEth.balanceOf(account);
        assertEq(accountVaultBalanceBefore, 0, "vault shares should not exist");
        _performDepositAndUninstallValidator(account, amount, address(sourceValidatorOnETH), address(superNativePaymaster), address(superSourceExecutorOnETH));

        uint256 accountVaultBalanceAfter = vaultInstanceMorphoEth.balanceOf(account);
        assertEq(accountVaultBalanceAfter, 0, "shares should not be minted - uninstall not allowed");
    }


    function test_BoundaryValues() public initializeModuleKit usingAccountEnv(AccountType.SAFE) {
        // Setup SafeERC7579
        bytes memory initData = _getInitData();
        address predictedAddress = IAccountFactory(_getFactory("SAFE")).getAddress(accountSalt, initData);
        bytes memory initCode = abi.encodePacked(
            address(_getFactory("SAFE")), abi.encodeCall(IAccountFactory.createAccount, (accountSalt, initData))
        );
        instance = makeAccountInstance(accountSalt, predictedAddress, initCode);
        account = instance.account;
        assertEq(uint256(instance.accountType), uint256(AccountType.SAFE), "not safe");
        
        // Install modules
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(address(predictedAddress))
        });
        
        // transfer a very large amount of tokens to the account
        uint256 veryLargeAmount = type(uint256).max - 1;
        _getTokens(address(mockERC20), account, veryLargeAmount);
        assertEq(mockERC20.balanceOf(account), veryLargeAmount, "account should have very large token balance");
        
        // max uint256 approval
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(approveERC20Hook);
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveHookData(address(mockERC20), address(this), veryLargeAmount, false);
        
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
            
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));
        
        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSafeSigData(validUntil, address(validator), userOpData.userOpHash, address(account));
        userOpData.userOp.signature = sigData;
        
        executeOp(userOpData);
        
        assertEq(mockERC20.allowance(address(account), address(this)), veryLargeAmount, "max allowance should be set");
        
        // very small amount approval
        uint256 verySmallAmount = 1;
        hooksData[0] = _createApproveHookData(address(mockERC20), address(this), verySmallAmount, false);
        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        
        userOpData = _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));
        sigData = _createSafeSigData(validUntil, address(validator), userOpData.userOpHash, address(account));
        userOpData.userOp.signature = sigData;
        
        executeOp(userOpData);
        
        assertEq(mockERC20.allowance(address(account), address(this)), verySmallAmount, "min allowance should be set");

        // 0 approval
        uint256 zeroAmount = 0;
        hooksData[0] = _createApproveHookData(address(mockERC20), address(this), zeroAmount, false);
        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        
        userOpData = _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));
        sigData = _createSafeSigData(validUntil, address(validator), userOpData.userOpHash, address(account));
        userOpData.userOp.signature = sigData;
        
        executeOp(userOpData);
        
        assertEq(mockERC20.allowance(address(account), address(this)), zeroAmount, "zero allowance should be set");
    }
    
    function test_UnauthorizedUninstall_Revert() public initializeModuleKit usingAccountEnv(AccountType.SAFE) {
        // Setup SafeERC7579
        bytes memory initData = _getInitData();
        address predictedAddress = IAccountFactory(_getFactory("SAFE")).getAddress(accountSalt, initData);
        bytes memory initCode = abi.encodePacked(
            address(_getFactory("SAFE")), abi.encodeCall(IAccountFactory.createAccount, (accountSalt, initData))
        );
        instance = makeAccountInstance(accountSalt, predictedAddress, initCode);
        account = instance.account;
        assertEq(uint256(instance.accountType), uint256(AccountType.SAFE), "not safe");
        
        // Install modules
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(address(predictedAddress))
        });
        
        // assert modules
        assertTrue(SuperExecutorBase(address(superExecutor)).isInitialized(account), "executor not installed");
        assertTrue(SuperValidatorBase(address(validator)).isInitialized(account), "validator not installed");
        
        // try to uninstall the module as an attacker
        address attacker = makeAddr("ATTACKER");
        vm.prank(attacker);
        vm.expectRevert(); 
        IERC7579Account(account).uninstallModule(MODULE_TYPE_EXECUTOR, address(superExecutor), "");
        
        // assert module still installed
        assertTrue(SuperExecutorBase(address(superExecutor)).isInitialized(account), "executor should still be installed");
        
        // same thing but with low level calls
        bytes memory callData = abi.encodeCall(
            IERC7579Account.uninstallModule,
            (MODULE_TYPE_EXECUTOR, address(superExecutor), "")
        );
        
        vm.prank(attacker);
        (bool success,) = account.call(callData);
        assertFalse(success, "unauthorized call should fail");
        
        // assert module still installed
        assertTrue(SuperExecutorBase(address(superExecutor)).isInitialized(account), "executor should still be installed after failed direct call");
        
        // verify the owner can uninstall
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, address(superExecutor), "");
        assertFalse(SuperExecutorBase(address(superExecutor)).isInitialized(account), "executor should be uninstalled");
    }
    
    function test_ExpiredSignature_Revert() public initializeModuleKit usingAccountEnv(AccountType.SAFE) {
        // Setup SafeERC7579
        bytes memory initData = _getInitData();
        address predictedAddress = IAccountFactory(_getFactory("SAFE")).getAddress(accountSalt, initData);
        bytes memory initCode = abi.encodePacked(
            address(_getFactory("SAFE")), abi.encodeCall(IAccountFactory.createAccount, (accountSalt, initData))
        );
        instance = makeAccountInstance(accountSalt, predictedAddress, initCode);
        account = instance.account;
        assertEq(uint256(instance.accountType), uint256(AccountType.SAFE), "not safe");
        
        // Install modules
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(address(predictedAddress))
        });
        
        // Setup execution data with a standard ERC20 approval
        uint256 amount = 1e8;
        uint256 allowanceBefore = mockERC20.allowance(address(account), address(this));
        assertEq(allowanceBefore, 0, "initial allowance should be zero");
        
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(approveERC20Hook);
        
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveHookData(address(mockERC20), address(this), amount, false);
        
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
            
        // Create user operation with validator
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));
        
        // EDGE CASE: Create a signature with expired validUntil (1 second in the past)
        uint48 validUntil = uint48(block.timestamp - 1);
        bytes memory sigData = _createSafeSigData(validUntil, address(validator), userOpData.userOpHash, address(account));
        userOpData.userOp.signature = sigData;
        
        // Expect the transaction to revert when submitted
        vm.recordLogs();
        instance.expect4337Revert();
        executeOp(userOpData);
        
        // Verify logs contain the appropriate error
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertTrue(entries.length > 0, "should emit at least one event on failure");
        
        // Allowance should remain unchanged since the transaction failed
        uint256 allowanceAfter = mockERC20.allowance(address(account), address(this));
        assertEq(allowanceAfter, 0, "allowance should remain zero after failed transaction");
        
        // CONTROL: Verify the same transaction succeeds with a valid timestamp
        validUntil = uint48(block.timestamp + 100 days);
        sigData = _createSafeSigData(validUntil, address(validator), userOpData.userOpHash, address(account));
        userOpData.userOp.signature = sigData;
        
        executeOp(userOpData);
        
        // Now the allowance should be updated
        allowanceAfter = mockERC20.allowance(address(account), address(this));
        assertEq(allowanceAfter, amount, "allowance should be updated after successful transaction");
    }
    
    function test_SameChainTx_execution() public initializeModuleKit usingAccountEnv(AccountType.SAFE) {
        // setup SafeERC7579
        bytes memory initData = _getInitData();
        address predictedAddress = IAccountFactory(_getFactory("SAFE")).getAddress(accountSalt, initData);
        bytes memory initCode = abi.encodePacked(
            address(_getFactory("SAFE")), abi.encodeCall(IAccountFactory.createAccount, (accountSalt, initData))
        );
        instance = makeAccountInstance(accountSalt, predictedAddress, initCode);
        account = instance.account;
        assertEq(uint256(instance.accountType), uint256(AccountType.SAFE), "not safe");

        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(address(predictedAddress))
        });

        // setup execution data
        uint256 amount = 1e8;
        uint256 allowanceBefore = mockERC20.allowance(address(account), address(this));
        assertEq(allowanceBefore, 0);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(approveERC20Hook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveHookData(address(mockERC20), address(this), amount, false);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));

        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSafeSigData(validUntil, address(validator), userOpData.userOpHash, address(account));
        userOpData.userOp.signature = sigData;

        executeOp(userOpData);

        uint256 allowanceAfter = mockERC20.allowance(address(account), address(this));
        assertEq(allowanceAfter, amount);
    }

    /**
     * @notice Test cross-chain transaction execution
     */
    function test_CrossChain_execution() public {
        CrossChainTestVars memory vars;
        vars.amountPerVault = 1e8 / 2;
        vars.warpStartTime = 1_740_559_708;

        _setupAccountsAndCode(vars);
        _setupDestinationChain(vars);
        _setupSourceChain(vars);
        _executeAndVerifyCrossChainTx(vars);
    }

    function test_MaliciousSafeLike_revert() public  initializeModuleKit usingAccountEnv(AccountType.SAFE)  {
        address[] memory _owners = new address[](2);
        _owners[0] = address(0x1); 
        _owners[1] = address(0x2); 
        MaliciousSafeAccount maliciousSafeAccount = new MaliciousSafeAccount(_owners);
        vm.label(address(maliciousSafeAccount), "MaliciousSafeAccount");

        bytes memory initData = _getInitData();
        address predictedAddress = IAccountFactory(_getFactory("SAFE")).getAddress(accountSalt, initData);
        bytes memory initCode = abi.encodePacked(
            address(_getFactory("SAFE")), abi.encodeCall(IAccountFactory.createAccount, (accountSalt, initData))
        );
        instance = makeAccountInstance(accountSalt, predictedAddress, initCode);
        account = instance.account;
        assertEq(uint256(instance.accountType), uint256(AccountType.SAFE), "not safe");

        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(address(maliciousSafeAccount))
        });

        // setup execution data
        uint256 amount = 1e8;
        uint256 allowanceBefore = mockERC20.allowance(address(account), address(this));
        assertEq(allowanceBefore, 0);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(approveERC20Hook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveHookData(address(mockERC20), address(this), amount, false);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));

        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSafeSigData(validUntil, address(validator), userOpData.userOpHash, address(account));
        userOpData.userOp.signature = sigData;

        instance.expect4337Revert();
        executeOp(userOpData);
    }

    function test_MaliciousSafeLike_execution_no_harm() public  initializeModuleKit usingAccountEnv(AccountType.SAFE)  {
        MaliciousSafeAccount maliciousSafeAccount = new MaliciousSafeAccount(owners);
        vm.label(address(maliciousSafeAccount), "MaliciousSafeAccount");

        bytes memory initData = _getInitData();
        address predictedAddress = IAccountFactory(_getFactory("SAFE")).getAddress(accountSalt, initData);
        bytes memory initCode = abi.encodePacked(
            address(_getFactory("SAFE")), abi.encodeCall(IAccountFactory.createAccount, (accountSalt, initData))
        );
        instance = makeAccountInstance(accountSalt, predictedAddress, initCode);
        account = instance.account;
        assertEq(uint256(instance.accountType), uint256(AccountType.SAFE), "not safe");

        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(address(maliciousSafeAccount))
        });

        // setup execution data
        uint256 amount = 1e8;
        uint256 allowanceBefore = mockERC20.allowance(address(account), address(this));
        assertEq(allowanceBefore, 0);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(approveERC20Hook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveHookData(address(mockERC20), address(this), amount, false);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));

        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSafeSigData(validUntil, address(validator), userOpData.userOpHash, address(maliciousSafeAccount));
        userOpData.userOp.signature = sigData;

        executeOp(userOpData);
    }

    function test_EOA_UsingSafeSig() public {
        address[] memory _owners = new address[](2);
        _owners[0] = address(0x1); 
        _owners[1] = address(0x2); 
        MaliciousSafeAccount maliciousSafeAccount = new MaliciousSafeAccount(_owners);
        vm.label(address(maliciousSafeAccount), "MaliciousSafeAccount");
        AccountInstance memory testInstance = makeAccountInstance(keccak256(abi.encode("TEST")));
        address testAccount = testInstance.account;

        testInstance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        testInstance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(address(maliciousSafeAccount))
        });

        uint256 amount = 1e8;

        _getTokens(address(mockERC20), testAccount, amount);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(approveERC20Hook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveHookData(address(mockERC20), address(this), amount, false);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(testInstance, superExecutor, abi.encode(entry), address(validator));

        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSafeSigData(validUntil, address(validator), userOpData.userOpHash, address(testAccount));
        userOpData.userOp.signature = sigData;

        testInstance.expect4337Revert();
        executeOp(userOpData);
    }
    

    function test_SameChainTx_execution_MalformedHash() public initializeModuleKit usingAccountEnv(AccountType.SAFE) {
        // setup SafeERC7579
        bytes memory initData = _getInitData();
        address predictedAddress = IAccountFactory(_getFactory("SAFE")).getAddress(accountSalt, initData);
        bytes memory initCode = abi.encodePacked(
            address(_getFactory("SAFE")), abi.encodeCall(IAccountFactory.createAccount, (accountSalt, initData))
        );
        /// @dev FLAG TODO
        instance = makeAccountInstance(accountSalt, predictedAddress, initCode);
        account = instance.account;
        assertEq(uint256(instance.accountType), uint256(AccountType.SAFE), "not safe");

        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(address(predictedAddress))
        });

        // setup execution data
        uint256 amount = 1e8;
        uint256 allowanceBefore = mockERC20.allowance(address(account), address(this));
        assertEq(allowanceBefore, 0);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(approveERC20Hook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveHookData(address(mockERC20), address(this), amount, false);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));

        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSafeSigData(validUntil, address(validator), userOpData.userOpHash, address(0x1));
        userOpData.userOp.signature = sigData;

        vm.recordLogs();
        instance.expect4337Revert();
        executeOp(userOpData);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertTrue(entries.length == 1);
    }



    /*//////////////////////////////////////////////////////////////
                                INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/
    function _performOfframp(address _receiver, address _account, address _validator, address _paymaster, address _executor) private {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, OFFRAMP_TOKENS_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](1);
        address[] memory offRampTokens = new address[](2);
        offRampTokens[0] = underlyingETH_USDC;
        offRampTokens[1] = yieldSourceMorphoUsdcAddressEth;
        hooksData[0] = _createOfframpTokensHookData(_receiver, offRampTokens);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, ISuperExecutor(_executor), abi.encode(entry), address(_validator));

        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSafeSigData(validUntil, _validator, userOpData.userOpHash, address(_account));
        userOpData.userOp.signature = sigData;

        executeOpsThroughPaymaster(userOpData, ISuperNativePaymaster(_paymaster), 1e18); 
    }

    function _performDeposit(address _account, uint256 _amount, address _validator, address _paymaster, address _executor) private {
        _getTokens(underlyingETH_USDC, _account, _amount);

        address[] memory hookAddresses = new address[](2);
        hookAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hookAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingETH_USDC, yieldSourceMorphoUsdcAddressEth, _amount, false);
        hooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSourceMorphoUsdcAddressEth,
            _amount,
            false,
            address(0),
            0
        );
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hooksData });

        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, ISuperExecutor(_executor), abi.encode(entry), address(_validator));

        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSafeSigData(validUntil, _validator, userOpData.userOpHash, address(_account));
        userOpData.userOp.signature = sigData;

        executeOpsThroughPaymaster(userOpData, ISuperNativePaymaster(_paymaster), 1e18); 
    }

    function _performDepositAndUninstallValidator(address _account, uint256 _amount, address _validator, address _paymaster, address _executor) private {
        _getTokens(underlyingETH_USDC, _account, _amount);

        address[] memory hookAddresses = new address[](3);
        hookAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hookAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);
        hookAddresses[2] = address(mockHook);

        bytes[] memory hooksData = new bytes[](3);
        hooksData[0] = _createApproveHookData(underlyingETH_USDC, yieldSourceMorphoUsdcAddressEth, _amount, false);
        hooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSourceMorphoUsdcAddressEth,
            _amount,
            false,
            address(0),
            0
        );
        hooksData[2] = "";


        Execution[] memory _uninstallExecutions = new Execution[](1);
        _uninstallExecutions[0] = Execution({
            target: _account,
            value: 0,
            callData: abi.encodeCall(IERC7579Account.uninstallModule, (MODULE_TYPE_VALIDATOR, _validator, abi.encode(address(validatorOnETH), "")))
        });
        mockHook.setExecutionBytes(abi.encode(_uninstallExecutions));

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hooksData });

        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, ISuperExecutor(_executor), abi.encode(entry), address(_validator));

        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSafeSigData(validUntil, _validator, userOpData.userOpHash, address(_account));
        userOpData.userOp.signature = sigData;

        executeOpsThroughPaymaster(userOpData, ISuperNativePaymaster(_paymaster), 1e18); 
    }
    
    
    // -- cross chain helpers
    /**
     * @notice Setup account code and salt for both chains
     * @param vars Test variables
     */
    function _setupAccountsAndCode(CrossChainTestVars memory vars) internal {
        //src account
        vm.selectFork(FORKS[BASE]);
        _initializeModuleKit("SAFE", keccak256("123"));

        address safeFactory = _getFactory("SAFE");
        vars.initData = _getInitData();
        vars.predictedAddress = IAccountFactory(safeFactory).getAddress(accountSalt, vars.initData);
        vars.initCode = abi.encodePacked(
            address(safeFactory), abi.encodeCall(IAccountFactory.createAccount, (accountSalt, vars.initData))
        );
        vars.instanceBase = makeAccountInstance(accountSalt, vars.predictedAddress, vars.initCode);
        vars.accountBase = vars.instanceBase.account;
        deal(vars.accountBase, 1 ether);
        vars.instanceBase.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(superSourceExecutorOnBase),
            data: ""
        });
        vars.instanceBase.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(sourceValidatorOnBase),
            data: abi.encode(address(vars.predictedAddress))
        });
        assertEq(uint256(vars.instanceBase.accountType), uint256(AccountType.SAFE), "not safe on base");

        //dst account
        vm.selectFork(FORKS[OP]);
        _initializeModuleKit("SAFE", keccak256("123"));
        deal(safeFactory, 10 ether);
        vm.prank(safeFactory);
        IStakeManager(ENTRYPOINT_ADDR).addStake{ value: 10 ether }(100_000);
        vars.instanceOp = makeAccountInstance(accountSalt, vars.predictedAddress, vars.initCode);
        vars.accountOp = vars.instanceOp.account;
        deal(vars.accountOp, 1 ether);
        vars.instanceOp.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(superDestinationExecutorOnOP),
            data: ""
        });
        vars.instanceOp.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validatorOnOP),
            data: abi.encode(address(vars.predictedAddress))
        });
        assertEq(uint256(vars.instanceOp.accountType), uint256(AccountType.SAFE), "not safe on op");
    }
    /**
     * @notice Setup destination chain (OP) environment and data
     * @param vars Test variables
     */

    function _setupDestinationChain(CrossChainTestVars memory vars) internal {
        // OP IS DST
        SELECT_FORK_AND_WARP(OP, vars.warpStartTime + 1);

        // PREPARE OP DATA
        vars.opHooksAddresses = new address[](2);
        vars.opHooksAddresses[0] = _getHookAddress(OP, APPROVE_ERC20_HOOK_KEY);
        vars.opHooksAddresses[1] = _getHookAddress(OP, DEPOSIT_4626_VAULT_HOOK_KEY);

        vars.opHooksData = new bytes[](2);
        vars.opHooksData[0] =
            _createApproveHookData(underlyingOpUsdce, yieldSource4626AddressOpUsdce, vars.amountPerVault, false);
        vars.opHooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSource4626AddressOpUsdce,
            vars.amountPerVault,
            true,
            address(0),
            0
        );

        vars.messageData = TargetExecutorMessage({
            hooksAddresses: vars.opHooksAddresses,
            hooksData: vars.opHooksData,
            validator: address(validatorOnOP),
            signer: address(0), // signed later in the test by the multisig
            signerPrivateKey: 0,
            targetAdapter: address(acrossV3AdapterOnOP),
            targetExecutor: address(superDestinationExecutorOnOP),
            nexusFactory: CHAIN_10_NEXUS_FACTORY,
            nexusBootstrap: CHAIN_10_NEXUS_BOOTSTRAP,
            chainId: uint64(OP),
            amount: vars.amountPerVault,
            account: vars.accountOp,
            tokenSent: underlyingOpUsdce
        });

        (vars.targetExecutorMessage, vars.accountToUse) = _createTargetExecutorMessage(vars.messageData);
        vars.previewDepositAmountOP = vaultInstance4626OP.previewDeposit(vars.amountPerVault);
    }
    /**
     * @notice Setup source chain (BASE) environment and data
     * @param vars Test variables
     */

    function _setupSourceChain(CrossChainTestVars memory vars) internal {
        // BASE IS SRC
        SELECT_FORK_AND_WARP(BASE, vars.warpStartTime + 1);

        // PREPARE BASE DATA
        vars.srcHooksAddresses = new address[](2);
        vars.srcHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        vars.srcHooksAddresses[1] = _getHookAddress(BASE, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        vars.srcHooksData = new bytes[](2);
        vars.srcHooksData[0] =
            _createApproveHookData(underlyingBaseUsdc, SPOKE_POOL_V3_ADDRESSES[BASE], vars.amountPerVault, false);
        vars.srcHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingBaseUsdc,
            underlyingOpUsdce,
            vars.amountPerVault,
            vars.amountPerVault,
            OP,
            true,
            vars.targetExecutorMessage
        );

        vars.entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: vars.srcHooksAddresses, hooksData: vars.srcHooksData });

        vars.srcUserOpData = _getExecOpsWithValidator(
            vars.instanceBase, superSourceExecutorOnBase, abi.encode(vars.entryToExecute), address(sourceValidatorOnBase)
        );

        // Give account tokens FIRST, then capture balance
        _getTokens(underlyingBaseUsdc, address(vars.accountBase), vars.amountPerVault);
        vars.userBalanceBaseUSDCBefore = IERC20(underlyingBaseUsdc).balanceOf(vars.accountBase);

        _prepareMerkleRootAndSignature(vars);
    }

    /**
     * @notice Prepare the Merkle root and signature for validation
     * @param vars Test variables
     */
    function _prepareMerkleRootAndSignature(CrossChainTestVars memory vars) internal view {
        (vars.ctx, vars.proofDst) = _createMerkleRootWithoutSignature(
            vars.messageData, vars.srcUserOpData.userOpHash, vars.accountToUse, OP, address(sourceValidatorOnBase)
        );

        vars.signature = _getSafeSignature(vars.ctx.merkleRoot, vars.accountToUse, address(validator));
        vars.signatureData = abi.encode(
            true, vars.ctx.validUntil, vars.ctx.merkleRoot, vars.ctx.merkleProof[1], vars.proofDst, vars.signature
        );
        vars.srcUserOpData.userOp.signature = vars.signatureData;
    }

    /**
     * @notice Execute the cross-chain transaction and verify results
     * @param vars Test variables
     */
    function _executeAndVerifyCrossChainTx(CrossChainTestVars memory vars) internal {
        // EXECUTE OP
        _processAcrossV3Message(
            ProcessAcrossV3MessageParams({
                srcChainId: BASE,
                dstChainId: OP,
                warpTimestamp: vars.warpStartTime,
                executionData: executeOp(vars.srcUserOpData),
                relayerType: RELAYER_TYPE.ENOUGH_BALANCE,
                errorMessage: bytes4(0),
                errorReason: "",
                root: bytes32(0),
                account: vars.accountOp,
                relayerGas: 0
            })
        );

        // Verify source chain: tokens should be sent via Across bridge
        uint256 currentBaseBalance = IERC20(underlyingBaseUsdc).balanceOf(vars.accountBase);
        uint256 expectedBaseBalance = vars.userBalanceBaseUSDCBefore - vars.amountPerVault;

        assertEq(
            currentBaseBalance, expectedBaseBalance, "Source chain BASE USDC balance incorrect after cross-chain send"
        );

        // Verify destination chain: tokens should be deposited into vault
        vm.selectFork(FORKS[OP]);
        uint256 currentOpShares = vaultInstance4626OP.balanceOf(vars.accountOp);

        assertEq(
            currentOpShares, vars.previewDepositAmountOP, "Destination chain OP vault shares incorrect after deposit"
        );
    }

    // -- SAFEERC7579 helper
    function _getInitData() internal view returns (bytes memory _init) {
        ModuleInit[] memory validators = new ModuleInit[](1);
        validators[0] = ModuleInit({ module: address(_defaultValidator), initData: "" });
        ModuleInit[] memory executors = new ModuleInit[](0);
        ModuleInit[] memory fallbacks = new ModuleInit[](0);
        ModuleInit[] memory hooks = new ModuleInit[](0);

        ISafe7579Launchpad.InitData memory initDataSafe = ISafe7579Launchpad.InitData({
            singleton: address(SafeFactory(_getFactory("SAFE")).safeSingleton()),
            owners: owners,
            threshold: threshold,
            setupTo: address(SafeFactory(_getFactory("SAFE")).launchpad()),
            setupData: abi.encodeCall(
                ISafe7579Launchpad.initSafe7579,
                (address(SafeFactory(_getFactory("SAFE")).safe7579()), executors, fallbacks, hooks, owners, 2)
            ),
            safe7579: ISafe7579(SafeFactory(_getFactory("SAFE")).safe7579()),
            validators: validators,
            callData: ""
        });
        _init = abi.encode(initDataSafe);
    }

    // -- modulekit helpers
    function _getFactory(string memory factoryType) internal view returns (address factory) {
        bytes32 slot = keccak256(abi.encode("ModuleKit.", factoryType, "FactorySlot"));
        assembly {
            factory := sload(slot)
        }
    }

    // -- 1271 signature helper
    function _createSafeSigData(
        uint48 validUntil,
        address _validator,
        bytes32 userOpHash,
        address _account
    )
        internal
        view
        returns (bytes memory signatureData)
    {
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _createSourceValidatorLeaf(userOpHash, validUntil, false, address(_validator));

        (bytes32[][] memory merkleProof, bytes32 merkleRoot) = _createValidatorMerkleTree(leaves);
        bytes memory signature = _getSafeSignature(merkleRoot, _account, _validator);

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        signatureData = abi.encode(false, validUntil, merkleRoot, merkleProof[0], proofDst, signature);
    }

    function _getSafeSignature(bytes32 merkleRoot, address _account, address _validator) internal view returns (bytes memory) {
        SignatureData memory sigData;
        sigData.rawHash = keccak256(abi.encode(SuperMerkleValidator(_validator).namespace(), merkleRoot));

        // Use chain-agnostic domain separator instead of Safe's native one
        sigData.domainSeparator = _getChainAgnosticDomainSeparator(_account);

        // Create the final hash using the same logic as SuperValidatorBase
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                bytes1(0x19),
                bytes1(0x01),
                sigData.domainSeparator,
                keccak256(abi.encode(keccak256("SafeMessage(bytes message)"), keccak256(abi.encode(sigData.rawHash))))
            )
        );

        // Sign the chain-agnostic hash
        (sigData.v1, sigData.r1, sigData.s1) = vm.sign(privateKey1, messageHash);
        (sigData.v2, sigData.r2, sigData.s2) = vm.sign(privateKey2, messageHash);

        // Verify recovery
        sigData.recovered1 = ecrecover(messageHash, sigData.v1, sigData.r1, sigData.s1);
        sigData.recovered2 = ecrecover(messageHash, sigData.v2, sigData.r2, sigData.s2);

        return _buildAndValidateSignature(sigData);
    }

    /// @notice Helper function to create chain-agnostic domain separator
    /// @dev Must match the logic in SuperValidatorBase
    function _getChainAgnosticDomainSeparator(address _account) internal pure returns (bytes32) {
        bytes32 CHAIN_AGNOSTIC_DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
        uint256 FIXED_CHAIN_ID = 1;
        string memory DOMAIN_NAME = "SuperformSafe";
        string memory DOMAIN_VERSION = "1.0.0";

        console2.log("---------------------------_account ", _account);
        return keccak256(
            abi.encode(
                CHAIN_AGNOSTIC_DOMAIN_TYPEHASH,
                keccak256(bytes(DOMAIN_NAME)),
                keccak256(bytes(DOMAIN_VERSION)),
                FIXED_CHAIN_ID,
                _account
            )
        );
    }

    function _buildAndValidateSignature(
        SignatureData memory sigData
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory sig1 = abi.encodePacked(sigData.r1, sigData.s1, sigData.v1);
        bytes memory sig2 = abi.encodePacked(sigData.r2, sigData.s2, sigData.v2);

        bytes memory signature;
        if (owner1 < owner2) {
            signature = bytes.concat(sig1, sig2);
        } else {
            signature = bytes.concat(sig2, sig1);
        }

        bytes memory dataWithValidator = abi.encodePacked(address(0), signature);
        return dataWithValidator;
    }

    // -- UserOps helpers
    function _makeNonceKey(bytes1 vMode) internal view returns (uint192 key) {
        key = (uint192(uint8(vMode)) << 160) | uint192(uint160(address(validator)));
    }

    function _getDefaultUserOp() internal pure returns (PackedUserOperation memory userOp) {
        userOp = PackedUserOperation({
            sender: address(0),
            nonce: 0,
            initCode: "",
            callData: "",
            accountGasLimits: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            preVerificationGas: 2e6,
            gasFees: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            paymasterAndData: bytes(""),
            signature: abi.encodePacked(hex"41414141")
        });
    }
}
