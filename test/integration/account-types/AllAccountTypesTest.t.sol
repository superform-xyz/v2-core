// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {
    ModuleKitHelpers, AccountInstance, UserOpData, PackedUserOperation, AccountType
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
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { IValidator } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { IStakeManager } from "modulekit/external/ERC4337.sol";

// Superform
import { BytesLib } from "../../../src/vendor/BytesLib.sol";

import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { SuperExecutorBase } from "../../../src/executors/SuperExecutorBase.sol";
import { SuperValidatorBase } from "../../../src/validators/SuperValidatorBase.sol";
import { ApproveERC20Hook } from "../../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { AcrossV3Adapter } from "../../../src/adapters/AcrossV3Adapter.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MaliciousSafeAccount } from "../../mocks/MaliciousSafeAccount.sol";
import { MockEIP1271Contract } from "../../mocks/MockEIP1271Contract.sol";

import { SuperValidator } from "../../../src/validators/SuperValidator.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { ISuperDestinationExecutor } from "../../../src/interfaces/ISuperDestinationExecutor.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";
import { MockHook } from "../../mocks/MockHook.sol";
import { BaseTest } from "../../BaseTest.t.sol";

import "forge-std/console2.sol";
import "forge-std/Test.sol";

/**
 * @title AllAccountTypesTest
 * @author Superform Labs
 * @notice Comprehensive test suite for Smart Account signature validation covering all supported account types
 * @dev This test suite validates the complete signature processing pipeline in
 * SuperValidatorBase._processSignatureForAccountType
 *
 * SIGNATURE PROCESSING SCENARIOS COVERED:
 * ==========================================
 *
 * 1. **EIP-7702 ACCOUNTS (Delegated EOAs)**
 *    - EIP-7702 accounts are detected by bytecode prefix (0xef0100)
 *    - Treated as EOAs and validated using ECDSA signature recovery
 *    - Tests: test_EIP7702AccountOwner_TreatedAsEOA, test_EIP7702AccountOwner_NotUsingEIP1271
 *
 * 2. **EOA ACCOUNTS (Externally Owned Accounts)**
 *    - Standard EOAs with no bytecode (code.length == 0)
 *    - Validated using ECDSA signature recovery with Ethereum message prefix
 *    - Tests: Various tests using EOA owners with threshold configurations
 *
 * 3. **SMART CONTRACT OWNERS - SAFE MULTISIG (Chain-Agnostic)**
 *    - Safe contracts implementing ISafeConfiguration interface
 *    - Uses chain-agnostic domain separator for cross-chain compatibility
 *    - Fixed chainId (1) for multi-chain signature validity
 *    - Supports multiple threshold configurations (1-of-n, 2-of-n, etc.)
 *    - Tests: test_CrossChain_execution_1_threshold, test_CrossChain_execution_2_threshold,
 *             test_SameChain_Execution_Signers_3_Threshold_1, test_Safe7579SelfOwnership_ChainAgnostic
 *
 * 4. **SMART CONTRACT OWNERS - SAFE MULTISIG (Native EIP-1271)**
 *    - Safe contracts using native chain-specific domain separator
 *    - Standard Safe signature validation as fallback for non-cross-chain operations
 *    - Tests: test_SameChainTx_execution_NativeSafeSignature
 *
 * 5. **SMART CONTRACT OWNERS - GENERIC EIP-1271 CONTRACTS**
 *    - Non-Safe smart contracts implementing IERC1271.isValidSignature
 *    - Limited to single-chain operations (no chain-agnostic support)
 *    - Tests: test_NonSafeEIP1271ContractOwner_SingleChain
 *
 * 6. **SAFE7579 SELF-OWNERSHIP**
 *    - Safe7579 accounts where the account owns itself
 *    - Supports both chain-agnostic and native Safe signature validation
 *    - Tests: test_Safe7579SelfOwnership_ChainAgnostic
 *
 * ADDITIONAL TEST SCENARIOS:
 * ==========================
 *
 * - **Module Management**: Installation/uninstallation of validators and executors
 * - **Security Edge Cases**: Malicious contracts, unauthorized operations, expired signatures
 * - **Boundary Conditions**: Zero values, maximum values, edge case amounts
 * - **Cross-Chain Execution**: Multi-chain operations with Across V3 bridge integration
 * - **Same-Chain Execution**: Single-chain operations with various hook configurations
 * - **Signature Validation**: Multiple signature formats and validation paths
 * - **Account Mutability**: Dynamic module installation/removal during execution
 *
 * SIGNATURE VALIDATION FLOW:
 * ==========================
 *
 * The validation follows this hierarchy in SuperValidatorBase._processSignatureForAccountType:
 * 1. Check if sender is EIP-7702 → Use ECDSA (treat as EOA)
 * 2. Get owner from _accountOwners mapping
 * 3. Check if owner is EOA or EIP-7702 → Use ECDSA
 * 4. Owner is smart contract → Try chain-agnostic Safe validation
 * 5. Fallback to generic EIP-1271 validation
 * 6. Revert if no validation succeeds
 *
 * This comprehensive coverage ensures all possible account types and signature scenarios
 * are properly validated across both same-chain and cross-chain operations.
 */

contract AllAccountTypesTest is Safe7579Precompiles, BaseTest {
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
        AccountInstance instanceETH;
        address accountOp;
        address accountBase;
        address accountETH;
        // Message data
        bytes targetExecutorMessage;
        TargetExecutorMessage messageData;
        address accountToUse;
        // Target chain (OP) data
        address[] opHooksAddresses;
        address[] ethHooksAddresses;
        bytes[] opHooksData;
        bytes[] ethHooksData;
        uint256 previewDepositAmountOP;
        uint256 previewDepositAmountETH;
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
    address public account;
    bytes32 public accountSalt;

    address public accountETH;
    address public accountBase;

    AccountInstance public instanceETH;
    AccountInstance public instanceBase;

    // -- owners
    uint256 public privateKey1;
    uint256 public privateKey2;
    uint256 public privateKey3;

    address public owner1;
    address public owner2;
    address public owner3;
    address[] public owners;

    // -- multisig safe
    uint256 public threshold;
    bytes4 public constant ERC1271_MAGICVALUE = 0x1626ba7e;

    address public underlyingOpUsdce;
    address public underlyingETH_USDC;
    address public underlyingBase_USDC;

    IERC4626 public vaultInstance4626OP;
    IERC4626 public vaultInstanceMorphoEth;
    IERC4626 public vaultInstanceMorphoBase;
    address public yieldSource4626AddressOpUsdce;
    address public yieldSourceMorphoUsdcAddressEth;
    address public yieldSource4626AddressBase;
    ISuperNativePaymaster public superNativePaymaster;

    // Superform
    // -- same-chain
    ApproveERC20Hook public approveERC20Hook;
    SuperExecutor public superExecutor;
    SuperExecutor public superExecutorBase;
    MockERC20 public mockERC20;
    SuperValidator public validator;
    // -- cross-chain
    AcrossV3Adapter public acrossV3AdapterOnOP;
    AcrossV3Adapter public acrossV3AdapterOnBase;
    AcrossV3Adapter public acrossV3AdapterOnETH;
    IValidator public validatorOnOP;
    IValidator public validatorOnETH;
    IValidator public sourceValidatorOnBase;
    IValidator public sourceValidatorOnETH;
    ISuperExecutor public superSourceExecutorOnBase;
    ISuperExecutor public superSourceExecutorOnETH;
    ISuperDestinationExecutor public superDestinationExecutorOnOP;
    ISuperDestinationExecutor public superDestinationExecutorOnETH;

    // used to simulate a malicious mid execution module uninstall
    MockHook public mockHook;

    function setUp() public override {
        skipAccountsCreation = true;
        super.setUp();
        accountSalt = keccak256(abi.encode("acc1"));

        // -- same-chain
        approveERC20Hook = new ApproveERC20Hook();
        mockERC20 = new MockERC20("MockERC20", "MOCK", 18);
        superExecutor = SuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        superExecutorBase = SuperExecutor(_getContract(BASE, SUPER_EXECUTOR_KEY));
        validator = new SuperValidator();

        // -- cross-chain
        underlyingOpUsdce = existingUnderlyingTokens[OP][USDCe_KEY];
        underlyingETH_USDC = existingUnderlyingTokens[ETH][USDC_KEY];
        underlyingBase_USDC = existingUnderlyingTokens[BASE][USDC_KEY];

        yieldSource4626AddressOpUsdce = realVaultAddresses[OP][ERC4626_VAULT_KEY][ALOE_USDC_VAULT_KEY][USDCe_KEY];
        vaultInstance4626OP = IERC4626(yieldSource4626AddressOpUsdce);

        yieldSourceMorphoUsdcAddressEth = realVaultAddresses[ETH][ERC4626_VAULT_KEY][EULER_VAULT_KEY][USDC_KEY];
        vaultInstanceMorphoEth = IERC4626(yieldSourceMorphoUsdcAddressEth);
        vm.label(yieldSourceMorphoUsdcAddressEth, "YIELD_SOURCE_MORPHO_USDC_ETH");

        yieldSource4626AddressBase = realVaultAddresses[BASE][ERC4626_VAULT_KEY][SPARK_USDC_VAULT_KEY][USDC_KEY];
        vaultInstanceMorphoBase = IERC4626(yieldSource4626AddressBase);
        vm.label(yieldSource4626AddressBase, "YIELD_SOURCE_MORPHO_USDC_BASE");

        acrossV3AdapterOnOP = AcrossV3Adapter(_getContract(OP, ACROSS_V3_ADAPTER_KEY));
        acrossV3AdapterOnBase = AcrossV3Adapter(_getContract(BASE, ACROSS_V3_ADAPTER_KEY));
        acrossV3AdapterOnETH = AcrossV3Adapter(_getContract(ETH, ACROSS_V3_ADAPTER_KEY));
        validatorOnOP = IValidator(_getContract(OP, SUPER_DESTINATION_VALIDATOR_KEY));
        validatorOnETH = IValidator(_getContract(ETH, SUPER_DESTINATION_VALIDATOR_KEY));
        sourceValidatorOnBase = IValidator(_getContract(BASE, SUPER_MERKLE_VALIDATOR_KEY));
        sourceValidatorOnETH = IValidator(_getContract(ETH, SUPER_MERKLE_VALIDATOR_KEY));
        superSourceExecutorOnBase = ISuperExecutor(_getContract(BASE, SUPER_EXECUTOR_KEY));
        superSourceExecutorOnETH = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        superDestinationExecutorOnOP = ISuperDestinationExecutor(_getContract(OP, SUPER_DESTINATION_EXECUTOR_KEY));
        superDestinationExecutorOnETH = ISuperDestinationExecutor(_getContract(ETH, SUPER_DESTINATION_EXECUTOR_KEY));

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
        privateKey3 = 3;
        owner3 = vm.addr(privateKey3);

        owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        superNativePaymaster = ISuperNativePaymaster(_getContract(ETH, SUPER_NATIVE_PAYMASTER_KEY));
    }

    receive() external payable { }

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

        threshold = 2;

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
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(superSourceExecutorOnETH),
            data: ""
        });

        // Verify ModuleInstalled event for superSourceExecutorOnETH
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 1, "wrong number of events emitted during first module installation");

        // Clear logs and install next module
        vm.recordLogs();
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(superDestinationExecutorOnETH),
            data: ""
        });

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
        assertTrue(
            SuperExecutorBase(address(superSourceExecutorOnETH)).isInitialized(account), "executor source not installed"
        );
        assertTrue(
            SuperExecutorBase(address(superDestinationExecutorOnETH)).isInitialized(account),
            "executor destination not installed"
        );
        assertTrue(SuperValidatorBase(address(sourceValidatorOnETH)).isInitialized(account), "validator not installed");

        // deposit & assert
        uint256 amount = 1e8;
        uint256 accountVaultBalanceBefore = vaultInstanceMorphoEth.balanceOf(account);
        assertEq(accountVaultBalanceBefore, 0, "vault shares should not exist");
        _performDeposit(
            account,
            amount,
            address(sourceValidatorOnETH),
            address(superNativePaymaster),
            address(superSourceExecutorOnETH)
        );
        uint256 accountVaultBalanceAfter = vaultInstanceMorphoEth.balanceOf(account);
        assertGt(accountVaultBalanceAfter, accountVaultBalanceBefore, "vault shares were not minted");

        // Record events during module uninstallation
        vm.recordLogs();

        // uninstall superDestinationExecutorOnETH
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, address(superDestinationExecutorOnETH), "");

        // Verify ModuleUninstalled event
        entries = vm.getRecordedLogs();
        assertEq(entries.length, 1, "wrong number of events emitted during module uninstallation");

        assertFalse(
            SuperExecutorBase(address(superDestinationExecutorOnETH)).isInitialized(account),
            "executor destination still installed"
        );

        // assert balance of vault
        uint256 accountVaultBalanceAfterUninstall = vaultInstanceMorphoEth.balanceOf(account);
        assertEq(accountVaultBalanceAfterUninstall, accountVaultBalanceAfter, "vault shares should be the same");

        // perform offramp hook
        address receiver = makeAddr("RECEIVER");
        _performOfframp(
            receiver,
            account,
            address(sourceValidatorOnETH),
            address(superNativePaymaster),
            address(superSourceExecutorOnETH)
        );

        // assert balance of vault
        uint256 accountVaultBalanceAfterOfframp = vaultInstanceMorphoEth.balanceOf(account);
        assertEq(accountVaultBalanceAfterOfframp, 0, "vault shares should be 0 after off ramp");
        uint256 receiverVaultBalanceAfterOfframp = vaultInstanceMorphoEth.balanceOf(receiver);
        assertEq(
            receiverVaultBalanceAfterOfframp,
            accountVaultBalanceAfterUninstall,
            "vault shares should have been trasnferred"
        );

        // Record events during module reinstallation
        vm.recordLogs();

        // re-install removed executor
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(superDestinationExecutorOnETH),
            data: ""
        });

        // Verify ModuleInstalled event for reinstallation
        entries = vm.getRecordedLogs();
        assertEq(entries.length, 1, "wrong number of events emitted during module reinstallation");

        assertTrue(
            SuperExecutorBase(address(superDestinationExecutorOnETH)).isInitialized(account),
            "executor destination should be reinstalled"
        );
        uint256 accountVaultBalanceAfterReinstall = vaultInstanceMorphoEth.balanceOf(account);
        assertEq(accountVaultBalanceAfterReinstall, 0, "vault shares should be 0 after reinstall");
    }

    function test_SafeAccount_UninstallMidExecution_DoNotWork() public {
        threshold = 2;

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

        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(superSourceExecutorOnETH),
            data: ""
        });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(superDestinationExecutorOnETH),
            data: ""
        });
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
        assertTrue(
            SuperExecutorBase(address(superSourceExecutorOnETH)).isInitialized(account), "executor source not installed"
        );
        assertTrue(
            SuperExecutorBase(address(superDestinationExecutorOnETH)).isInitialized(account),
            "executor destination not installed"
        );
        assertTrue(SuperValidatorBase(address(sourceValidatorOnETH)).isInitialized(account), "validator not installed");

        // create malicious uninstall validator hook
        mockHook = new MockHook(ISuperHook.HookType.NONACCOUNTING, address(this));
        vm.label(address(mockHook), "MockHook");

        // deposit & assert
        uint256 amount = 1e8;
        uint256 accountVaultBalanceBefore = vaultInstanceMorphoEth.balanceOf(account);
        assertEq(accountVaultBalanceBefore, 0, "vault shares should not exist");
        _performDepositAndUninstallValidator(
            account,
            amount,
            address(sourceValidatorOnETH),
            address(superNativePaymaster),
            address(superSourceExecutorOnETH)
        );

        uint256 accountVaultBalanceAfter = vaultInstanceMorphoEth.balanceOf(account);
        assertEq(accountVaultBalanceAfter, 0, "shares should not be minted - uninstall not allowed");
    }

    function test_BoundaryValues() public initializeModuleKit usingAccountEnv(AccountType.SAFE) {
        threshold = 2;

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
        bytes memory sigData =
            _createSafeSigData(2, validUntil, address(validator), userOpData.userOpHash, address(account));
        userOpData.userOp.signature = sigData;

        executeOp(userOpData);

        assertEq(mockERC20.allowance(address(account), address(this)), veryLargeAmount, "max allowance should be set");

        // very small amount approval
        uint256 verySmallAmount = 1;
        hooksData[0] = _createApproveHookData(address(mockERC20), address(this), verySmallAmount, false);
        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        userOpData = _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));
        sigData = _createSafeSigData(2, validUntil, address(validator), userOpData.userOpHash, address(account));
        userOpData.userOp.signature = sigData;

        executeOp(userOpData);

        assertEq(mockERC20.allowance(address(account), address(this)), verySmallAmount, "min allowance should be set");

        // 0 approval
        uint256 zeroAmount = 0;
        hooksData[0] = _createApproveHookData(address(mockERC20), address(this), zeroAmount, false);
        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        userOpData = _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));
        sigData = _createSafeSigData(2, validUntil, address(validator), userOpData.userOpHash, address(account));
        userOpData.userOp.signature = sigData;

        executeOp(userOpData);

        assertEq(mockERC20.allowance(address(account), address(this)), zeroAmount, "zero allowance should be set");
    }

    function test_UnauthorizedUninstall_Revert() public initializeModuleKit usingAccountEnv(AccountType.SAFE) {
        threshold = 2;

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
        assertTrue(
            SuperExecutorBase(address(superExecutor)).isInitialized(account), "executor should still be installed"
        );

        // same thing but with low level calls
        bytes memory callData =
            abi.encodeCall(IERC7579Account.uninstallModule, (MODULE_TYPE_EXECUTOR, address(superExecutor), ""));

        vm.prank(attacker);
        (bool success,) = account.call(callData);
        assertFalse(success, "unauthorized call should fail");

        // assert module still installed
        assertTrue(
            SuperExecutorBase(address(superExecutor)).isInitialized(account),
            "executor should still be installed after failed direct call"
        );

        // verify the owner can uninstall
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, address(superExecutor), "");
        assertFalse(SuperExecutorBase(address(superExecutor)).isInitialized(account), "executor should be uninstalled");
    }

    function test_ExpiredSignature_Revert() public initializeModuleKit usingAccountEnv(AccountType.SAFE) {
        threshold = 2;

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
        bytes memory sigData =
            _createSafeSigData(2, validUntil, address(validator), userOpData.userOpHash, address(account));
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
        sigData = _createSafeSigData(2, validUntil, address(validator), userOpData.userOpHash, address(account));
        userOpData.userOp.signature = sigData;

        executeOp(userOpData);

        // Now the allowance should be updated
        allowanceAfter = mockERC20.allowance(address(account), address(this));
        assertEq(allowanceAfter, amount, "allowance should be updated after successful transaction");
    }

    function test_SameChainTx_execution() public initializeModuleKit usingAccountEnv(AccountType.SAFE) {
        threshold = 2;

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
        bytes memory sigData =
            _createSafeSigData(2, validUntil, address(validator), userOpData.userOpHash, address(account));
        userOpData.userOp.signature = sigData;

        executeOp(userOpData);

        uint256 allowanceAfter = mockERC20.allowance(address(account), address(this));
        assertEq(allowanceAfter, amount);
    }

    function test_SameChainTx_execution_NativeSafeSignature()
        public
        initializeModuleKit
        usingAccountEnv(AccountType.SAFE)
    {
        threshold = 2;

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

        // 🔥 KEY: Use native Safe signature (like Safe UI would produce) instead of chain-agnostic
        bytes memory sigData =
            _createNativeSafeSigData(validUntil, address(validator), userOpData.userOpHash, address(account));
        userOpData.userOp.signature = sigData;

        executeOp(userOpData);

        uint256 allowanceAfter = mockERC20.allowance(address(account), address(this));
        assertEq(allowanceAfter, amount);
    }

    function test_MaliciousSafeLike_revert() public initializeModuleKit usingAccountEnv(AccountType.SAFE) {
        threshold = 2;
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
        bytes memory sigData =
            _createSafeSigData(2, validUntil, address(validator), userOpData.userOpHash, address(account));
        userOpData.userOp.signature = sigData;

        instance.expect4337Revert();
        executeOp(userOpData);
    }

    function test_MaliciousSafeLike_execution_no_harm() public initializeModuleKit usingAccountEnv(AccountType.SAFE) {
        threshold = 2;

        MaliciousSafeAccount maliciousSafeAccount = new MaliciousSafeAccount(owners);
        vm.label(address(maliciousSafeAccount), "MaliciousSafeAccount");

        bytes memory initData = _getInitData();
        address predictedAddress = IAccountFactory(_getFactory("SAFE")).getAddress(accountSalt, initData);
        bytes memory initCode = abi.encodePacked(
            address(_getFactory("SAFE")), abi.encodeCall(IAccountFactory.createAccount, (accountSalt, initData))
        );
        instance = makeAccountInstance(accountSalt, predictedAddress, initCode);
        account = instance.account;

        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(address(maliciousSafeAccount))
        });

        // setup execution data
        uint256 amount = 1e8;

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(approveERC20Hook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveHookData(address(mockERC20), address(this), amount, false);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));

        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData =
            _createSafeSigData(2, validUntil, address(validator), userOpData.userOpHash, address(maliciousSafeAccount));
        userOpData.userOp.signature = sigData;

        executeOp(userOpData);
    }

    function test_EOA_UsingSafeSig() public {
        threshold = 2;
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
        bytes memory sigData =
            _createSafeSigData(2, validUntil, address(validator), userOpData.userOpHash, address(testAccount));
        userOpData.userOp.signature = sigData;

        testInstance.expect4337Revert();
        executeOp(userOpData);
    }

    function test_SameChainTx_execution_MalformedHash() public initializeModuleKit usingAccountEnv(AccountType.SAFE) {
        threshold = 2;

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
        bytes memory sigData =
            _createSafeSigData(2, validUntil, address(validator), userOpData.userOpHash, address(0x1));
        userOpData.userOp.signature = sigData;

        vm.recordLogs();
        instance.expect4337Revert();
        executeOp(userOpData);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertTrue(entries.length == 1);
    }

    function test_SameChain_Execution_Signers_3_Threshold_1()
        public
        initializeModuleKit
        usingAccountEnv(AccountType.SAFE)
    {
        threshold = 1;
        uint256 amount = 1000e6;
        vm.selectFork(FORKS[BASE]);

        // setup SafeERC7579
        bytes memory initData = _getInitData();
        address predictedAddress = IAccountFactory(_getFactory("SAFE")).getAddress(accountSalt, initData);
        bytes memory initCode = abi.encodePacked(
            address(_getFactory("SAFE")), abi.encodeCall(IAccountFactory.createAccount, (accountSalt, initData))
        );
        instanceBase = makeAccountInstance(accountSalt, predictedAddress, initCode);
        accountBase = instanceBase.account;
        assertEq(uint256(instanceBase.accountType), uint256(AccountType.SAFE), "not safe");

        instanceBase.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutorBase), data: "" });
        instanceBase.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(address(predictedAddress))
        });

        deal(underlyingBase_USDC, accountBase, amount);

        uint256 shareBalanceBefore = vaultInstanceMorphoBase.balanceOf(accountBase);

        uint256 expectedShares = vaultInstanceMorphoBase.convertToShares(amount);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingBase_USDC, yieldSource4626AddressBase, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSource4626AddressBase,
            amount,
            false,
            address(0),
            0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instanceBase, superExecutorBase, abi.encode(entry), address(validator));

        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData =
            _createSafeSigData(1, validUntil, address(validator), userOpData.userOpHash, address(accountBase));
        userOpData.userOp.signature = sigData;

        executeOp(userOpData);

        uint256 shareBalanceAfter = vaultInstanceMorphoBase.balanceOf(accountBase);

        assertEq(shareBalanceAfter, shareBalanceBefore + expectedShares, "share balance not increased");
    }

    function test_CrossChain_execution_2_threshold() public {
        threshold = 2;

        CrossChainTestVars memory vars;
        vars.amountPerVault = 1e8 / 2;
        vars.warpStartTime = 1_740_559_708;

        // Create accounts first
        _createAccountsAndCode(
            vars, OP, underlyingOpUsdce, address(superDestinationExecutorOnOP), address(validatorOnOP)
        );

        // Then setup destination chain with account addresses available
        _setupDestinationChain(
            vars,
            OP,
            underlyingOpUsdce,
            address(vaultInstance4626OP),
            address(acrossV3AdapterOnOP),
            address(superDestinationExecutorOnOP),
            address(validatorOnOP),
            CHAIN_10_NEXUS_FACTORY,
            CHAIN_10_NEXUS_BOOTSTRAP
        );

        // Setup source chain
        _setupSourceChain(vars, OP, underlyingOpUsdce, 2, address(superSourceExecutorOnBase));

        // Execute and verify
        _executeAndVerifyCrossChainTx(vars, OP, vaultInstance4626OP);
    }

    function test_CrossChain_execution_1_threshold() public {
        threshold = 1;

        CrossChainTestVars memory vars;
        vars.amountPerVault = 1e8 / 2;
        vars.warpStartTime = 1_740_559_708;

        // Create accounts first
        _createAccountsAndCode(
            vars, ETH, underlyingETH_USDC, address(superDestinationExecutorOnETH), address(validatorOnETH)
        );

        // Then setup destination chain with account addresses available
        _setupDestinationChain(
            vars,
            ETH,
            underlyingETH_USDC,
            yieldSourceMorphoUsdcAddressEth,
            address(acrossV3AdapterOnETH),
            address(superDestinationExecutorOnETH),
            address(validatorOnETH),
            CHAIN_1_NEXUS_FACTORY,
            CHAIN_1_NEXUS_BOOTSTRAP
        );

        // Setup source chain
        _setupSourceChain(vars, ETH, underlyingETH_USDC, 1, address(superSourceExecutorOnBase));

        // Execute and verify
        _executeAndVerifyCrossChainTx(vars, ETH, vaultInstanceMorphoEth);
    }

    function test_NonSafeEIP1271ContractOwner_SingleChain()
        public
        initializeModuleKit
        usingAccountEnv(AccountType.SAFE)
    {
        threshold = 2;

        // Create a non-Safe EIP-1271 contract as owner
        MockEIP1271Contract customContract = new MockEIP1271Contract(owner1);
        vm.label(address(customContract), "MockEIP1271Contract");

        // Setup SafeERC7579
        bytes memory initData = _getInitData();
        address predictedAddress = IAccountFactory(_getFactory("SAFE")).getAddress(accountSalt, initData);
        bytes memory initCode = abi.encodePacked(
            address(_getFactory("SAFE")), abi.encodeCall(IAccountFactory.createAccount, (accountSalt, initData))
        );
        instance = makeAccountInstance(accountSalt, predictedAddress, initCode);
        account = instance.account;
        assertEq(uint256(instance.accountType), uint256(AccountType.SAFE), "not safe");

        // Install modules with custom EIP-1271 contract as owner
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(address(customContract)) // ← Custom contract is the owner
         });

        // Verify the owner is set correctly
        address registeredOwner = SuperValidatorBase(address(validator)).getAccountOwner(account);
        assertEq(registeredOwner, address(customContract), "Custom contract should be the owner");

        // Setup execution data
        uint256 amount = 1e8;
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(approveERC20Hook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveHookData(address(mockERC20), address(this), amount, false);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));

        uint48 validUntil = uint48(block.timestamp + 100 days);

        // Create signature using the custom contract owner (should use regular EIP-1271, not chain-agnostic)
        bytes memory sigData = _createCustomEIP1271SigData(
            validUntil,
            address(validator),
            userOpData.userOpHash,
            address(customContract),
            privateKey1 // owner1's private key
        );
        userOpData.userOp.signature = sigData;

        executeOp(userOpData);

        uint256 allowanceAfter = mockERC20.allowance(address(account), address(this));
        assertEq(allowanceAfter, amount, "Single chain operation should work with custom EIP-1271 contract");
    }

    function test_Safe7579SelfOwnership_ChainAgnostic() public initializeModuleKit usingAccountEnv(AccountType.SAFE) {
        threshold = 2;

        // Setup SafeERC7579 where the Safe owns itself
        bytes memory initData = _getInitData();
        address predictedAddress = IAccountFactory(_getFactory("SAFE")).getAddress(accountSalt, initData);
        bytes memory initCode = abi.encodePacked(
            address(_getFactory("SAFE")), abi.encodeCall(IAccountFactory.createAccount, (accountSalt, initData))
        );
        instance = makeAccountInstance(accountSalt, predictedAddress, initCode);
        account = instance.account;
        assertEq(uint256(instance.accountType), uint256(AccountType.SAFE), "not safe");

        // Install modules with the Safe account itself as owner (self-ownership)
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(address(account)) // ← Safe owns itself
         });

        // Verify self-ownership
        address registeredOwner = SuperValidatorBase(address(validator)).getAccountOwner(account);
        assertEq(registeredOwner, account, "Safe7579 should own itself");

        // Test both chain-agnostic and native Safe signature validation
        uint256 amount = 1e8;
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(approveERC20Hook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveHookData(address(mockERC20), address(this), amount, false);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));

        uint48 validUntil = uint48(block.timestamp + 100 days);

        // Test 1: Chain-agnostic signature (for multi-chain operations)
        bytes memory chainAgnosticSigData =
            _createSafeSigData(2, validUntil, address(validator), userOpData.userOpHash, address(account));
        userOpData.userOp.signature = chainAgnosticSigData;

        executeOp(userOpData);

        uint256 allowanceAfter = mockERC20.allowance(address(account), address(this));
        assertEq(allowanceAfter, amount, "Chain-agnostic signature should work for Safe7579 self-ownership");

        // Reset for second test
        hooksData[0] = _createApproveHookData(address(mockERC20), address(this), 0, false);
        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        userOpData = _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));

        // Test 2: Native Safe signature (fallback to standard EIP-1271)
        bytes memory nativeSigData =
            _createNativeSafeSigData(validUntil, address(validator), userOpData.userOpHash, address(account));
        userOpData.userOp.signature = nativeSigData;

        executeOp(userOpData);

        allowanceAfter = mockERC20.allowance(address(account), address(this));
        assertEq(allowanceAfter, 0, "Native Safe signature should also work for Safe7579 self-ownership");
    }

    function test_EIP7702AccountOwner_TreatedAsEOA() public initializeModuleKit usingAccountEnv(AccountType.SAFE) {
        threshold = 2;

        // Create a proper EIP-7702 account by etching the bytecode with EIP-7702 prefix
        // First, we need an implementation contract to delegate to
        address implementation = address(new MockEIP1271Contract(owner1));

        // Use owner1 as the EIP-7702 account address and etch it with proper EIP-7702 bytecode
        bytes3 EIP7702_PREFIX = bytes3(0xef0100);
        vm.etch(owner1, abi.encodePacked(EIP7702_PREFIX, bytes20(implementation)));
        vm.label(owner1, "EIP7702Account");

        // Setup SafeERC7579
        bytes memory initData = _getInitData();
        address predictedAddress = IAccountFactory(_getFactory("SAFE")).getAddress(accountSalt, initData);
        bytes memory initCode = abi.encodePacked(
            address(_getFactory("SAFE")), abi.encodeCall(IAccountFactory.createAccount, (accountSalt, initData))
        );
        instance = makeAccountInstance(accountSalt, predictedAddress, initCode);
        account = instance.account;
        assertEq(uint256(instance.accountType), uint256(AccountType.SAFE), "not safe");

        // Install modules with EIP-7702 account as owner
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(owner1) // ← owner1 is now an EIP-7702 account
         });

        // Verify the EIP-7702 account is set as owner
        address registeredOwner = SuperValidatorBase(address(validator)).getAccountOwner(account);
        assertEq(registeredOwner, owner1, "EIP-7702 account should be the owner");

        // Setup execution data
        uint256 amount = 1e8;
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(approveERC20Hook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveHookData(address(mockERC20), address(this), amount, false);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));

        uint48 validUntil = uint48(block.timestamp + 100 days);

        // Create ECDSA signature (EIP-7702 should be treated as EOA, not EIP-1271)
        bytes memory sigData = _createECDSASigDataForEIP7702(
            validUntil,
            address(validator),
            userOpData.userOpHash,
            privateKey1 // owner1's private key (the underlying EOA)
        );
        userOpData.userOp.signature = sigData;

        executeOp(userOpData);

        uint256 allowanceAfter = mockERC20.allowance(address(account), address(this));
        assertEq(allowanceAfter, amount, "EIP-7702 account should be treated as EOA and use ECDSA validation");
    }

    function test_EIP7702AccountOwner_NotUsingEIP1271() public initializeModuleKit usingAccountEnv(AccountType.SAFE) {
        // This test verifies that EIP-7702 accounts are NOT treated as EIP-1271 contracts
        // even though they have the isValidSignature method due to delegated code

        threshold = 2;

        // Create a proper EIP-7702 account by etching the bytecode with EIP-7702 prefix
        // First, we need an implementation contract to delegate to
        address implementation = address(new MockEIP1271Contract(owner1));

        // Use owner1 as the EIP-7702 account address and etch it with proper EIP-7702 bytecode
        bytes3 EIP7702_PREFIX = bytes3(0xef0100);
        vm.etch(owner1, abi.encodePacked(EIP7702_PREFIX, bytes20(implementation)));
        vm.label(owner1, "EIP7702Account");

        // Setup SafeERC7579
        bytes memory initData = _getInitData();
        address predictedAddress = IAccountFactory(_getFactory("SAFE")).getAddress(accountSalt, initData);
        bytes memory initCode = abi.encodePacked(
            address(_getFactory("SAFE")), abi.encodeCall(IAccountFactory.createAccount, (accountSalt, initData))
        );
        instance = makeAccountInstance(accountSalt, predictedAddress, initCode);
        account = instance.account;

        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(owner1) // ← owner1 is now an EIP-7702 account
         });

        // Verify that the EIP-7702 contract's isValidSignature should never be called
        // If our validator correctly detects EIP-7702, it should use ECDSA instead of EIP-1271

        uint256 amount = 1e8;
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(approveERC20Hook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveHookData(address(mockERC20), address(this), amount, false);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));

        uint48 validUntil = uint48(block.timestamp + 100 days);

        // If we try to use EIP-1271 signature format, it should fail because
        // the validator should detect EIP-7702 and use ECDSA validation instead
        bytes memory sigData =
            _createECDSASigDataForEIP7702(validUntil, address(validator), userOpData.userOpHash, privateKey1);
        userOpData.userOp.signature = sigData;

        // This should succeed because the validator correctly treats EIP-7702 as EOA
        executeOp(userOpData);

        uint256 allowanceAfter = mockERC20.allowance(address(account), address(this));
        assertEq(allowanceAfter, amount, "EIP-7702 account should work with ECDSA, not EIP-1271");

        // The EIP-7702 account's isValidSignature should never have been called
        // because the validator should detect EIP-7702 and use ECDSA validation instead
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/
    function _performOfframp(
        address _receiver,
        address _account,
        address _validator,
        address _paymaster,
        address _executor
    )
        private
    {
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
        bytes memory sigData = _createSafeSigData(2, validUntil, _validator, userOpData.userOpHash, address(_account));
        userOpData.userOp.signature = sigData;

        executeOpsThroughPaymaster(userOpData, ISuperNativePaymaster(_paymaster), 1e18);
    }

    function _performDeposit(
        address _account,
        uint256 _amount,
        address _validator,
        address _paymaster,
        address _executor
    )
        private
    {
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
        bytes memory sigData = _createSafeSigData(2, validUntil, _validator, userOpData.userOpHash, address(_account));
        userOpData.userOp.signature = sigData;

        executeOpsThroughPaymaster(userOpData, ISuperNativePaymaster(_paymaster), 1e18);
    }

    struct LocalVars {
        address[] hookAddresses;
        bytes[] hooksData;
        Execution[] uninstallExecutions;
        ISuperExecutor.ExecutorEntry entry;
        UserOpData userOpData;
        uint48 validUntil;
        bytes sigData;
    }

    struct CustomEIP1271SigVars {
        bytes32[] leaves;
        bytes32[][] merkleProof;
        bytes32 merkleRoot;
        bytes32 messageHash;
        bytes32 ethSignedMessageHash;
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes signature;
        ISuperValidator.DstProof[] proofDst;
    }

    struct EIP7702SigVars {
        bytes32[] leaves;
        bytes32[][] merkleProof;
        bytes32 merkleRoot;
        bytes32 messageHash;
        bytes32 ethSignedMessageHash;
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes signature;
        ISuperValidator.DstProof[] proofDst;
    }

    function _performDepositAndUninstallValidator(
        address _account,
        uint256 _amount,
        address _validator,
        address _paymaster,
        address _executor
    )
        private
    {
        LocalVars memory vars;

        _getTokens(underlyingETH_USDC, _account, _amount);

        vars.hookAddresses = new address[](3);
        vars.hookAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        vars.hookAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);
        vars.hookAddresses[2] = address(mockHook);

        vars.hooksData = new bytes[](3);
        vars.hooksData[0] = _createApproveHookData(underlyingETH_USDC, yieldSourceMorphoUsdcAddressEth, _amount, false);
        vars.hooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSourceMorphoUsdcAddressEth,
            _amount,
            false,
            address(0),
            0
        );
        vars.hooksData[2] = "";

        vars.uninstallExecutions = new Execution[](1);
        vars.uninstallExecutions[0] = Execution({
            target: _account,
            value: 0,
            callData: abi.encodeCall(
                IERC7579Account.uninstallModule,
                (MODULE_TYPE_VALIDATOR, _validator, abi.encode(address(validatorOnETH), ""))
            )
        });
        mockHook.setExecutionBytes(abi.encode(vars.uninstallExecutions));

        vars.entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: vars.hookAddresses, hooksData: vars.hooksData });

        vars.userOpData =
            _getExecOpsWithValidator(instance, ISuperExecutor(_executor), abi.encode(vars.entry), address(_validator));

        vars.validUntil = uint48(block.timestamp + 100 days);
        vars.sigData = _createSafeSigData(2, vars.validUntil, _validator, vars.userOpData.userOpHash, address(_account));
        vars.userOpData.userOp.signature = vars.sigData;

        executeOpsThroughPaymaster(vars.userOpData, ISuperNativePaymaster(_paymaster), 1e18);
    }

    // -- cross chain helpers

    /**
     * @notice Setup destination chain environment and data
     * @param vars Test variables
     * @param dstChainId Destination chain ID (OP or ETH)
     * @param dstToken Destination token address
     * @param dstVault Destination vault address
     * @param dstAdapter Destination adapter address
     * @param dstExecutor Destination executor address
     * @param dstValidator Destination validator address
     * @param nexusFactory Nexus factory address for destination chain
     * @param nexusBootstrap Nexus bootstrap address for destination chain
     */
    function _setupDestinationChain(
        CrossChainTestVars memory vars,
        uint64 dstChainId,
        address dstToken,
        address dstVault,
        address dstAdapter,
        address dstExecutor,
        address dstValidator,
        address nexusFactory,
        address nexusBootstrap
    )
        internal
    {
        // Setup destination chain - ensure we're on the right fork with proper timing
        SELECT_FORK_AND_WARP(dstChainId, vars.warpStartTime + 1);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(dstChainId, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(dstChainId, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(dstToken, dstVault, vars.amountPerVault, false);
        hooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            dstVault,
            vars.amountPerVault,
            false,
            address(0),
            0
        );

        vars.messageData = TargetExecutorMessage({
            hooksAddresses: hooksAddresses,
            hooksData: hooksData,
            validator: dstValidator,
            signer: address(0),
            signerPrivateKey: 0,
            targetAdapter: dstAdapter,
            targetExecutor: dstExecutor,
            nexusFactory: nexusFactory,
            nexusBootstrap: nexusBootstrap,
            chainId: dstChainId,
            amount: vars.amountPerVault,
            account: address(0), // Will be set properly after accounts are created
            tokenSent: dstToken
        });

        // Set the correct account after creation
        if (dstChainId == ETH) {
            vars.messageData.account = vars.accountETH;
        } else if (dstChainId == OP) {
            vars.messageData.account = vars.accountOp;
        }

        (vars.targetExecutorMessage, vars.accountToUse) = _createTargetExecutorMessage(vars.messageData, false);

        // Store chain-specific data for verification
        if (dstChainId == ETH) {
            vars.ethHooksAddresses = hooksAddresses;
            vars.ethHooksData = hooksData;
            vars.previewDepositAmountETH = IERC4626(dstVault).previewDeposit(vars.amountPerVault);
        } else if (dstChainId == OP) {
            vars.opHooksAddresses = hooksAddresses;
            vars.opHooksData = hooksData;
            vars.previewDepositAmountOP = IERC4626(dstVault).previewDeposit(vars.amountPerVault);
        }
    }

    /**
     * @notice Setup source chain (BASE) environment and data
     * @param vars Test variables
     * @param dstChainId Destination chain ID (OP or ETH)
     * @param dstToken Destination token address
     * @param signerThreshold Number of signers required for signature
     * @param executor Super executor contract to use
     */
    function _setupSourceChain(
        CrossChainTestVars memory vars,
        uint64 dstChainId,
        address dstToken,
        uint256 signerThreshold,
        address executor
    )
        internal
    {
        // BASE IS SRC
        SELECT_FORK_AND_WARP(BASE, vars.warpStartTime + 1);

        // PREPARE BASE DATA
        vars.srcHooksAddresses = new address[](2);
        vars.srcHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        vars.srcHooksAddresses[1] = _getHookAddress(BASE, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        vars.srcHooksData = new bytes[](2);
        vars.srcHooksData[0] =
            _createApproveHookData(underlyingBase_USDC, SPOKE_POOL_V3_ADDRESSES[BASE], vars.amountPerVault, false);
        vars.srcHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingBase_USDC,
            dstToken,
            vars.amountPerVault,
            vars.amountPerVault,
            dstChainId,
            true,
            vars.targetExecutorMessage
        );

        vars.entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: vars.srcHooksAddresses, hooksData: vars.srcHooksData });

        vars.srcUserOpData = _getExecOpsWithValidator(
            vars.instanceBase, ISuperExecutor(executor), abi.encode(vars.entryToExecute), address(sourceValidatorOnBase)
        );

        // Give account tokens FIRST, then capture balance
        _getTokens(underlyingBase_USDC, address(vars.accountBase), vars.amountPerVault);
        vars.userBalanceBaseUSDCBefore = IERC20(underlyingBase_USDC).balanceOf(vars.accountBase);

        _prepareMerkleRootAndSignature(vars, signerThreshold, dstChainId, address(sourceValidatorOnBase));
    }

    /**
     * @notice Prepare the Merkle root and signature for validation
     * @param vars Test variables
     */
    function _prepareMerkleRootAndSignature(
        CrossChainTestVars memory vars,
        uint256 amountSigners,
        uint64 dstChainId,
        address srcValidator
    )
        internal
        view
    {
        (vars.ctx, vars.proofDst) = _createMerkleRootWithoutSignature(
            vars.messageData, vars.srcUserOpData.userOpHash, vars.accountToUse, dstChainId, srcValidator
        );

        vars.signature = _getSafeSignature(vars.ctx.merkleRoot, vars.accountBase, srcValidator, amountSigners);
        uint64[] memory chainsWithDestExecutionCrosschain = new uint64[](1);
        chainsWithDestExecutionCrosschain[0] = dstChainId;
        vars.signatureData = abi.encode(
            chainsWithDestExecutionCrosschain, vars.ctx.validUntil, vars.ctx.merkleRoot, vars.ctx.merkleProof[1], vars.proofDst, vars.signature
        );
        vars.srcUserOpData.userOp.signature = vars.signatureData;
    }

    /**
     * @notice Execute the cross-chain transaction and verify results
     * @param vars Test variables
     * @param dstChainId Destination chain ID (OP or ETH)
     * @param dstVault Destination vault contract for verification
     */
    function _executeAndVerifyCrossChainTx(
        CrossChainTestVars memory vars,
        uint64 dstChainId,
        IERC4626 dstVault
    )
        internal
    {
        address dstAccount = dstChainId == ETH ? vars.accountETH : vars.accountOp;
        uint256 expectedShares = dstChainId == ETH ? vars.previewDepositAmountETH : vars.previewDepositAmountOP;

        // Execute cross-chain transaction
        _processAcrossV3Message(
            ProcessAcrossV3MessageParams({
                srcChainId: BASE,
                dstChainId: dstChainId,
                warpTimestamp: vars.warpStartTime,
                executionData: executeOp(vars.srcUserOpData),
                relayerType: RELAYER_TYPE.ENOUGH_BALANCE,
                errorMessage: bytes4(0),
                errorReason: "",
                root: bytes32(0),
                account: dstAccount,
                relayerGas: 0
            })
        );

        // Verify source chain: tokens should be sent via Across bridge
        uint256 currentBaseBalance = IERC20(underlyingBase_USDC).balanceOf(vars.accountBase);
        uint256 expectedBaseBalance = vars.userBalanceBaseUSDCBefore - vars.amountPerVault;

        assertEq(
            currentBaseBalance, expectedBaseBalance, "Source chain BASE USDC balance incorrect after cross-chain send"
        );

        // Verify destination chain: tokens should be deposited into vault
        vm.selectFork(FORKS[dstChainId]);
        uint256 currentShares = dstVault.balanceOf(dstAccount);

        assertEq(currentShares, expectedShares, "Destination chain vault shares incorrect after deposit");
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
        uint256 amountSigners,
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
        uint64[] memory chainsForLeaf = new uint64[](0);
        leaves[0] = _createSourceValidatorLeaf(userOpHash, validUntil, chainsForLeaf, address(_validator));

        (bytes32[][] memory merkleProof, bytes32 merkleRoot) = _createValidatorMerkleTree(leaves);
        bytes memory signature = _getSafeSignature(merkleRoot, _account, _validator, amountSigners);

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        uint64[] memory chainsWithDestExecutionAccount = new uint64[](0);
        signatureData = abi.encode(chainsWithDestExecutionAccount, validUntil, merkleRoot, merkleProof[0], proofDst, signature);
    }

    function _createNativeSafeSigData(
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
        uint64[] memory chainsForLeaf = new uint64[](0);
        leaves[0] = _createSourceValidatorLeaf(userOpHash, validUntil, chainsForLeaf, address(_validator));

        (bytes32[][] memory merkleProof, bytes32 merkleRoot) = _createValidatorMerkleTree(leaves);

        // 🔥 KEY: Use native Safe signature format (like Safe UI would produce)
        bytes memory signature = _getNativeSafeSignature(merkleRoot, _account, _validator);

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        uint64[] memory chainsWithDestExecutionAccount = new uint64[](0);
        signatureData = abi.encode(chainsWithDestExecutionAccount, validUntil, merkleRoot, merkleProof[0], proofDst, signature);
    }

    function _getSafeSignature(
        bytes32 merkleRoot,
        address _account,
        address _validator,
        uint256 amountSigners
    )
        internal
        view
        returns (bytes memory)
    {
        SignatureData memory sigData;
        sigData.rawHash = keccak256(abi.encode(SuperValidator(_validator).namespace(), merkleRoot));

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

        // Sign the chain-agnostic hash with specified number of signers
        (sigData.v1, sigData.r1, sigData.s1) = vm.sign(privateKey1, messageHash);
        (sigData.v2, sigData.r2, sigData.s2) = vm.sign(privateKey2, messageHash);

        // Verify recovery
        sigData.recovered1 = ecrecover(messageHash, sigData.v1, sigData.r1, sigData.s1);
        sigData.recovered2 = ecrecover(messageHash, sigData.v2, sigData.r2, sigData.s2);

        return _buildAndValidateSignature(sigData, amountSigners);
    }

    function _getNativeSafeSignature(
        bytes32 merkleRoot,
        address _account,
        address _validator
    )
        internal
        view
        returns (bytes memory)
    {
        SignatureData memory sigData;

        // Create the message hash that the validator expects: namespace + merkleRoot
        sigData.rawHash = keccak256(abi.encode(SuperValidator(_validator).namespace(), merkleRoot));

        // Use Safe's native domain separator (with actual chainid) - this is what Safe UI would use
        sigData.domainSeparator = _getNativeSafeDomainSeparator(_account);

        // Create Safe message hash using Safe's format:
        // keccak256(abi.encode(SAFE_MSG_TYPEHASH, keccak256(message)))
        bytes32 SAFE_MSG_TYPEHASH = 0x60b3cbf8b4a223d68d641b3b6ddf9a298e7f33710cf3d3a9d1146b5a6150fbca;
        bytes32 safeMessageHash = keccak256(abi.encode(SAFE_MSG_TYPEHASH, keccak256(abi.encode(sigData.rawHash))));

        // Create the final EIP-712 hash using Safe's native domain separator
        bytes32 messageHash =
            keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), sigData.domainSeparator, safeMessageHash));

        // Sign the native Safe hash
        (sigData.v1, sigData.r1, sigData.s1) = vm.sign(privateKey1, messageHash);
        (sigData.v2, sigData.r2, sigData.s2) = vm.sign(privateKey2, messageHash);

        // Verify recovery
        sigData.recovered1 = ecrecover(messageHash, sigData.v1, sigData.r1, sigData.s1);
        sigData.recovered2 = ecrecover(messageHash, sigData.v2, sigData.r2, sigData.s2);

        return _buildAndValidateSignatureNative(sigData, 2);
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

    /// @notice Helper function to create Safe's native domain separator
    /// @dev Uses actual chain ID - this is what Safe UI would use
    function _getNativeSafeDomainSeparator(address _account) internal view returns (bytes32) {
        // Safe's native domain separator typehash:
        // keccak256("EIP712Domain(uint256 chainId,address verifyingContract)")
        bytes32 DOMAIN_SEPARATOR_TYPEHASH = 0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

        return keccak256(
            abi.encode(
                DOMAIN_SEPARATOR_TYPEHASH,
                block.chainid, // 🔥 KEY: Use actual chain ID (not fixed like chain-agnostic)
                _account
            )
        );
    }

    function _buildAndValidateSignatureNative(
        SignatureData memory sigData,
        uint256 amountSigners
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory signature;

        if (amountSigners == 1) {
            bytes memory sig1 = abi.encodePacked(sigData.r1, sigData.s1, sigData.v1);
            signature = sig1;
        } else if (amountSigners == 2) {
            bytes memory sig1 = abi.encodePacked(sigData.r1, sigData.s1, sigData.v1);
            bytes memory sig2 = abi.encodePacked(sigData.r2, sigData.s2, sigData.v2);

            if (owner1 < owner2) {
                signature = bytes.concat(sig1, sig2);
            } else {
                signature = bytes.concat(sig2, sig1);
            }
        } else {
            revert("Invalid amount of signers");
        }

        bytes memory dataWithValidator = abi.encodePacked(address(0), signature);
        return dataWithValidator;
    }

    function _buildAndValidateSignature(
        SignatureData memory sigData,
        uint256 amountSigners
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory signature;

        if (amountSigners == 1) {
            bytes memory sig1 = abi.encodePacked(sigData.r1, sigData.s1, sigData.v1);
            signature = sig1;
        } else if (amountSigners == 2) {
            bytes memory sig1 = abi.encodePacked(sigData.r1, sigData.s1, sigData.v1);
            bytes memory sig2 = abi.encodePacked(sigData.r2, sigData.s2, sigData.v2);

            signature = bytes.concat(sig1, sig2);
        } else {
            revert("Invalid amount of signers");
        }
        // For ECDSA signatures, return the signature without any prefix
        // Only EIP-1271 and pre-validated signatures need prefixes according to Safe docs
        return signature;
    }

    function _buildAndValidateSignature(SignatureData memory sigData) internal pure returns (bytes memory) {
        bytes memory sig1 = abi.encodePacked(sigData.r1, sigData.s1, sigData.v1);
        bytes memory sig2 = abi.encodePacked(sigData.r2, sigData.s2, sigData.v2);

        bytes memory signature = bytes.concat(sig1, sig2);

        return signature;
    }

    /// @notice Create signature data for custom EIP-1271 contract owner
    function _createCustomEIP1271SigData(
        uint48 validUntil,
        address _validator,
        bytes32 userOpHash,
        address _customContract,
        uint256 _privateKey
    )
        internal
        view
        returns (bytes memory signatureData)
    {
        CustomEIP1271SigVars memory vars;

        vars.leaves = new bytes32[](1);
        uint64[] memory chainsForLeaf2 = new uint64[](0);
        vars.leaves[0] = _createSourceValidatorLeaf(userOpHash, validUntil, chainsForLeaf2, address(_validator));

        (vars.merkleProof, vars.merkleRoot) = _createValidatorMerkleTree(vars.leaves);

        // Create signature for custom EIP-1271 contract
        vars.messageHash = keccak256(abi.encode(SuperValidator(_validator).namespace(), vars.merkleRoot));
        vars.ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(vars.messageHash);

        (vars.v, vars.r, vars.s) = vm.sign(_privateKey, vars.ethSignedMessageHash);
        vars.signature = abi.encodePacked(vars.r, vars.s, vars.v);

        vars.proofDst = new ISuperValidator.DstProof[](0);
        signatureData =
            abi.encode(new uint64[](0), validUntil, vars.merkleRoot, vars.merkleProof[0], vars.proofDst, vars.signature);
    }

    /// @notice Create ECDSA signature data for EIP-7702 account owner (treated as EOA)
    function _createECDSASigDataForEIP7702(
        uint48 validUntil,
        address _validator,
        bytes32 userOpHash,
        uint256 _privateKey
    )
        internal
        pure
        returns (bytes memory signatureData)
    {
        EIP7702SigVars memory vars;

        vars.leaves = new bytes32[](1);
        uint64[] memory chainsForLeaf2 = new uint64[](0);
        vars.leaves[0] = _createSourceValidatorLeaf(userOpHash, validUntil, chainsForLeaf2, address(_validator));

        (vars.merkleProof, vars.merkleRoot) = _createValidatorMerkleTree(vars.leaves);

        // Create ECDSA signature (EIP-7702 accounts should be treated as EOAs)
        vars.messageHash = keccak256(abi.encode(SuperValidator(_validator).namespace(), vars.merkleRoot));
        vars.ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(vars.messageHash);

        (vars.v, vars.r, vars.s) = vm.sign(_privateKey, vars.ethSignedMessageHash);
        vars.signature = abi.encodePacked(vars.r, vars.s, vars.v);

        vars.proofDst = new ISuperValidator.DstProof[](0);
        signatureData =
            abi.encode(new uint64[](0), validUntil, vars.merkleRoot, vars.merkleProof[0], vars.proofDst, vars.signature);
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

    /**
     * @notice Create accounts and setup code for cross-chain tests
     * @param vars Test variables
     * @param dstChainId Destination chain ID (OP or ETH)
     * @param dstToken Destination token address
     * @param dstExecutor Destination executor contract
     * @param dstValidator Destination validator contract
     */
    function _createAccountsAndCode(
        CrossChainTestVars memory vars,
        uint64 dstChainId,
        address dstToken,
        address dstExecutor,
        address dstValidator
    )
        internal
    {
        // src account (always BASE)
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
        deal(underlyingBase_USDC, vars.accountBase, vars.amountPerVault);

        // install modules
        vars.instanceBase.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(superExecutorBase),
            data: ""
        });
        vars.instanceBase.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(sourceValidatorOnBase),
            data: abi.encode(address(vars.predictedAddress))
        });
        assertEq(uint256(vars.instanceBase.accountType), uint256(AccountType.SAFE), "not safe on base");

        // dst account (dynamic based on dstChainId)
        vm.selectFork(FORKS[dstChainId]);
        _initializeModuleKit("SAFE", keccak256("123"));

        deal(safeFactory, 10 ether);

        vm.prank(safeFactory);
        IStakeManager(ENTRYPOINT_ADDR).addStake{ value: 10 ether }(100_000);

        if (dstChainId == ETH) {
            vars.instanceETH = makeAccountInstance(accountSalt, vars.predictedAddress, vars.initCode);
            vars.accountETH = vars.instanceETH.account;
            deal(vars.accountETH, 1 ether);
            deal(dstToken, vars.accountETH, vars.amountPerVault);

            vars.instanceETH.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: dstExecutor, data: "" });
            vars.instanceETH.installModule({
                moduleTypeId: MODULE_TYPE_VALIDATOR,
                module: dstValidator,
                data: abi.encode(address(vars.predictedAddress))
            });
            assertEq(uint256(vars.instanceETH.accountType), uint256(AccountType.SAFE), "not safe on dst");
        } else if (dstChainId == OP) {
            vars.instanceOp = makeAccountInstance(accountSalt, vars.predictedAddress, vars.initCode);
            vars.accountOp = vars.instanceOp.account;
            deal(vars.accountOp, 1 ether);
            deal(dstToken, vars.accountOp, vars.amountPerVault);

            vars.instanceOp.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: dstExecutor, data: "" });
            vars.instanceOp.installModule({
                moduleTypeId: MODULE_TYPE_VALIDATOR,
                module: dstValidator,
                data: abi.encode(address(vars.predictedAddress))
            });
            assertEq(uint256(vars.instanceOp.accountType), uint256(AccountType.SAFE), "not safe on dst");
        }
    }
}
