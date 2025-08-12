// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
// -- nexus
import { Nexus } from "@nexus/Nexus.sol";
import { NexusAccountFactory } from "@nexus/factory/NexusAccountFactory.sol";
import { MockValidator } from "@nexus/mocks/MockValidator.sol";
import { MockExecutor } from "@nexus/mocks/MockExecutor.sol";
import { MockRegistry } from "@nexus/mocks/MockRegistry.sol";
import { MockPreValidationHook } from "@nexus/mocks/MockPreValidationHook.sol";
import { MockTarget } from "@nexus/mocks/MockTarget.sol";
import {
    BootstrapConfig,
    BootstrapPreValidationHookConfig,
    RegistryConfig,
    NexusBootstrap
} from "@nexus/utils/NexusBootstrap.sol";
import { BootstrapLib } from "@nexus/lib/BootstrapLib.sol";
import { K1Validator } from "@nexus/modules/validators/K1Validator.sol";
import { IExecutionHelper } from "@nexus/interfaces/base/IExecutionHelper.sol";
import { PackedUserOperation } from "account-abstraction/interfaces/PackedUserOperation.sol";
import { EntryPoint } from "account-abstraction/core/EntryPoint.sol";
import { ModeLib } from "@nexus/lib/ModeLib.sol";
import { ExecLib } from "@nexus/lib/ExecLib.sol";
import { INexus } from "@nexus/interfaces/INexus.sol";
import { Execution } from "@nexus/types/DataTypes.sol";
import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";
import { AcrossV3Helper } from "pigeon/across/AcrossV3Helper.sol";

import { IERC7579Account } from "../../../lib/modulekit/src/accounts/common/interfaces/IERC7579Account.sol";
import { ModeCode } from "../../../lib/modulekit/src/accounts/common/lib/ModeLib.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// Superform
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { SuperExecutorBase } from "../../../src/executors/SuperExecutorBase.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { SuperDestinationExecutor } from "../../../src/executors/SuperDestinationExecutor.sol";
import { SuperValidatorBase } from "../../../src/validators/SuperValidatorBase.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { SuperValidator } from "../../../src/validators/SuperValidator.sol";
import { SuperDestinationValidator } from "../../../src/validators/SuperDestinationValidator.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperDestinationExecutor } from "../../../src/interfaces/ISuperDestinationExecutor.sol";
import { ISuperLedger, ISuperLedgerData } from "../../../src/interfaces/accounting/ISuperLedger.sol";
import { ApproveERC20Hook } from "../../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { Deposit4626VaultHook } from "../../../src/hooks/vaults/4626/Deposit4626VaultHook.sol";
import { ERC4626YieldSourceOracle } from "../../../src/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { Mock4626Vault } from "../../mocks/Mock4626Vault.sol";
import { AcrossSendFundsAndExecuteOnDstHook } from
    "../../../src/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol";
import { AcrossV3Adapter } from "../../../src/adapters/AcrossV3Adapter.sol";

import { MockHook } from "../../mocks/MockHook.sol";
import { BaseTest } from "../../BaseTest.t.sol";

import "forge-std/console2.sol";
import "forge-std/Test.sol";
import "forge-std/Vm.sol";

contract EIP7702Test is BaseTest {
    using ECDSA for bytes32;

    // generic
    uint256 latestEthFork;
    uint256 latestBaseFork;
    uint256 latestOpFork;
    uint256 warpStartTime;

    // external
    EntryPoint internal ENTRYPOINT;
    K1Validator internal DEFAULT_VALIDATOR_MODULE;
    Nexus internal ACCOUNT_IMPLEMENTATION;
    NexusAccountFactory internal FACTORY;
    MockRegistry internal REGISTRY;
    NexusBootstrap internal BOOTSTRAPPER;

    SuperDestinationValidator internal DEFAULT_VALIDATOR_MODULE_BASE;
    Nexus internal ACCOUNT_IMPLEMENTATION_BASE;
    NexusAccountFactory internal FACTORY_BASE;
    MockRegistry internal REGISTRY_BASE;
    NexusBootstrap internal BOOTSTRAPPER_BASE;

    address[] internal ATTESTERS;
    uint8 internal THRESHOLD;

    MockPreValidationHook public mockPreValidationHook;
    MockPreValidationHook public mockPreValidationHook_Base;
    MockValidator public mockValidator;
    MockValidator public mockValidator_Base;
    MockExecutor public mockExecutor;
    MockExecutor public mockExecutor_Base;
    MockTarget public target;

    address factoryOwner;
    uint256 constant MODULE_TYPE_PREVALIDATION_HOOK_ERC4337 = 9;
    bytes3 internal constant EIP7702_PREFIX = bytes3(0xef0100);

    // superform
    MockHook public mockHook;
    address public underlyingETH_USDC;
    address public underlyingBase_USDC;
    address public underlyingOP_USDC;

    SuperDestinationValidator public superDestinationValidator_Base;
    SuperDestinationExecutor public superDestinationExecutor_Base;

    address public mockVault;

    function setUp() public override {
        // Use specific block numbers from after Pectra deployment where vaults are working
        // ETH Block 23096042 - Aug-08-2025 11:27:23 AM +UTC
        // Base Block 33931553 - Aug-08-2025 11:27:33 AM +UTC
        // OP Block 139526853 - Aug-08-2025 11:28:03 AM +UTC
        warpStartTime = 1_723_115_243; // Aug-08-2025 11:27:23 AM +UTC
        latestEthFork = vm.createFork(ETHEREUM_RPC_URL, 23_096_042);
        latestBaseFork = vm.createFork(BASE_RPC_URL, 33_931_553);
        latestOpFork = vm.createFork(OPTIMISM_RPC_URL, 139_526_853);

        ENTRYPOINT = EntryPoint(payable(ENTRYPOINT_ADDR));
        vm.label(address(ENTRYPOINT), "ENTRYPOINT");

        factoryOwner = makeAddr("factoryOwner");
        deal(factoryOwner, 100 ether);
        vm.label(factoryOwner, "FactoryOwner");

        ATTESTERS = new address[](1);
        ATTESTERS[0] = address(this);
        THRESHOLD = 1;

        mockHook = new MockHook(ISuperHook.HookType.NONACCOUNTING, address(this));
        vm.label(address(mockHook), "MockHook");
        vm.makePersistent(address(mockHook));

        target = new MockTarget();
        vm.label(address(target), "MockTarget");
        vm.makePersistent(address(target));

        super.setUp();

        // create BASE fork data
        _useBaseFork(0);
        deal(factoryOwner, 100 ether);

        DEFAULT_VALIDATOR_MODULE_BASE = new SuperDestinationValidator();
        vm.label(address(DEFAULT_VALIDATOR_MODULE_BASE), "SuperDestinationValidator-Base");
        ACCOUNT_IMPLEMENTATION_BASE =
            new Nexus(address(ENTRYPOINT), address(DEFAULT_VALIDATOR_MODULE_BASE), abi.encode(address(0xeEeEeEeE)));
        vm.label(address(ACCOUNT_IMPLEMENTATION_BASE), "ACCOUNT_IMPLEMENTATION-Base");
        FACTORY_BASE = new NexusAccountFactory(address(ACCOUNT_IMPLEMENTATION_BASE), factoryOwner);
        vm.label(address(FACTORY_BASE), "FACTORY-Base");
        REGISTRY_BASE = new MockRegistry();
        vm.label(address(REGISTRY_BASE), "REGISTRY-Base");
        BOOTSTRAPPER_BASE = new NexusBootstrap(address(DEFAULT_VALIDATOR_MODULE_BASE), abi.encode(address(0xa11ce)));
        vm.label(address(BOOTSTRAPPER_BASE), "BOOTSTRAPPER-Base");

        mockValidator_Base = new MockValidator();
        vm.label(address(mockValidator_Base), "MockValidator-Base");
        mockExecutor_Base = new MockExecutor();
        vm.label(address(mockExecutor_Base), "MockExecutor-Base");
        mockPreValidationHook_Base = new MockPreValidationHook();
        vm.label(address(mockPreValidationHook_Base), "MockPreValidationHook-Base");

        superDestinationValidator_Base = new SuperDestinationValidator();
        vm.label(address(superDestinationValidator_Base), "SuperDestinationValidator-Base");
        superDestinationExecutor_Base =
            SuperDestinationExecutor(_createSuperDestinationExecutor(address(superDestinationValidator_Base)));
        vm.label(address(superDestinationExecutor_Base), "SuperDestinationExecutor-Base");

        // create ETH fork data
        _useEthFork(0);
        deal(factoryOwner, 100 ether);

        DEFAULT_VALIDATOR_MODULE = new K1Validator();
        vm.label(address(DEFAULT_VALIDATOR_MODULE), "K1Validator");
        ACCOUNT_IMPLEMENTATION =
            new Nexus(address(ENTRYPOINT), address(DEFAULT_VALIDATOR_MODULE), abi.encodePacked(address(0xeEeEeEeE)));
        vm.label(address(ACCOUNT_IMPLEMENTATION), "ACCOUNT_IMPLEMENTATION");
        FACTORY = new NexusAccountFactory(address(ACCOUNT_IMPLEMENTATION), factoryOwner);
        vm.label(address(FACTORY), "FACTORY");
        REGISTRY = new MockRegistry();
        vm.label(address(REGISTRY), "REGISTRY");
        BOOTSTRAPPER = new NexusBootstrap(address(DEFAULT_VALIDATOR_MODULE), abi.encodePacked(address(0xa11ce)));
        vm.label(address(BOOTSTRAPPER), "BOOTSTRAPPER");
        mockValidator = new MockValidator();
        vm.label(address(mockValidator), "MockValidator");
        mockExecutor = new MockExecutor();
        vm.label(address(mockExecutor), "MockExecutor");
        mockPreValidationHook = new MockPreValidationHook();
        vm.label(address(mockPreValidationHook), "MockPreValidationHook");
        target = new MockTarget();
        vm.label(address(target), "MockTarget");

        // Superform
        underlyingBase_USDC = existingUnderlyingTokens[BASE][USDC_KEY];
        vm.label(underlyingBase_USDC, "underlyingBase_USDC");
        underlyingETH_USDC = existingUnderlyingTokens[ETH][USDC_KEY];
        vm.label(underlyingETH_USDC, "underlyingETH_USDC");
        underlyingOP_USDC = existingUnderlyingTokens[OP][USDC_KEY];
        vm.label(underlyingOP_USDC, "underlyingOP_USDC");
    }

    /*//////////////////////////////////////////////////////////////
                          TESTS
    //////////////////////////////////////////////////////////////*/
    function test_Nothing() public pure {
        assertTrue(true);
    }

    function test_execSingle() public returns (address) {
        // Create calldata for the account to execute
        bytes memory setValueOnTarget = abi.encodeCall(MockTarget.setValue, 1337);

        // Encode the call into the calldata for the userOp
        bytes memory userOpCalldata = abi.encodeCall(
            IExecutionHelper.execute,
            (ModeLib.encodeSimpleSingle(), ExecLib.encodeSingle(address(target), uint256(0), setValueOnTarget))
        );

        // Get the account, initcode and nonce
        uint256 eoaKey = uint256(8);
        address account = vm.addr(eoaKey);
        vm.deal(account, 100 ether);

        uint256 nonce = _getNonce(account, MODE_VALIDATION, address(0), 0);

        // Create the userOp and add the data
        PackedUserOperation memory userOp = _buildPackedUserOp(address(account), nonce);
        userOp.callData = userOpCalldata;

        userOp.signature = _getSignature(eoaKey, userOp);
        _doEIP7702(account);

        // Create userOps array
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        // Send the userOp to the entrypoint
        ENTRYPOINT.handleOps(userOps, payable(address(0x69)));

        // Assert that the value was set ie that execution was successful
        assertTrue(target.value() == 1337);
        return account;
    }

    function test_initializeAndExecSingle() public returns (address) {
        // Get the account, initcode and nonce
        uint256 eoaKey = uint256(8);
        address account = vm.addr(eoaKey);
        vm.deal(account, 100 ether);

        // Create calldata for the account to execute
        bytes memory setValueOnTarget = abi.encodeCall(MockTarget.setValue, 1337);

        bytes memory initData = _getInitData(
            InitData({
                executor: address(mockExecutor),
                validator: address(mockValidator),
                signer: address(0),
                prevalidationHook: address(mockPreValidationHook),
                bootstrap: BOOTSTRAPPER,
                registry: REGISTRY
            })
        );

        Execution[] memory executions = new Execution[](2);
        executions[0] =
            Execution({ target: account, value: 0, callData: abi.encodeCall(INexus.initializeAccount, initData) });
        executions[1] = Execution({ target: address(target), value: 0, callData: setValueOnTarget });

        // Encode the call into the calldata for the userOp
        bytes memory userOpCalldata =
            abi.encodeCall(IExecutionHelper.execute, (ModeLib.encodeSimpleBatch(), ExecLib.encodeBatch(executions)));

        uint256 nonce = _getNonce(account, MODE_VALIDATION, address(0), 0);

        // Create the userOp and add the data
        PackedUserOperation memory userOp = _buildPackedUserOp(address(account), nonce);
        userOp.callData = userOpCalldata;

        userOp.signature = _getSignature(eoaKey, userOp);
        _doEIP7702(account);

        // Create userOps array
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        // Send the userOp to the entrypoint
        ENTRYPOINT.handleOps(userOps, payable(address(0x69)));

        // Assert that the value was set ie that execution was successful
        assertTrue(target.value() == 1337);
        return account;
    }

    function test_initializeAndExecSingle_DoubleExecution() public returns (address) {
        // Get the account, initcode and nonce
        uint256 eoaKey = uint256(8);
        address account = vm.addr(eoaKey);
        vm.deal(account, 100 ether);

        // Create calldata for the account to execute
        bytes memory setValueOnTarget = abi.encodeCall(MockTarget.setValue, 1337);

        bytes memory initData = _getInitData(
            InitData({
                executor: address(mockExecutor),
                validator: address(mockValidator),
                signer: address(0),
                prevalidationHook: address(mockPreValidationHook),
                bootstrap: BOOTSTRAPPER,
                registry: REGISTRY
            })
        );

        Execution[] memory executions = new Execution[](2);
        executions[0] =
            Execution({ target: account, value: 0, callData: abi.encodeCall(INexus.initializeAccount, initData) });
        executions[1] = Execution({ target: address(target), value: 0, callData: setValueOnTarget });

        // Encode the call into the calldata for the userOp
        bytes memory userOpCalldata =
            abi.encodeCall(IExecutionHelper.execute, (ModeLib.encodeSimpleBatch(), ExecLib.encodeBatch(executions)));

        uint256 nonce = _getNonce(account, MODE_VALIDATION, address(0), 0);

        // Create the userOp and add the data
        PackedUserOperation memory userOp = _buildPackedUserOp(address(account), nonce);
        userOp.callData = userOpCalldata;

        userOp.signature = _getSignature(eoaKey, userOp);
        _doEIP7702(account);

        // Create userOps array
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        // Send the userOp to the entrypoint
        ENTRYPOINT.handleOps(userOps, payable(address(0x69)));
        assertTrue(target.value() == 1337);

        setValueOnTarget = abi.encodeCall(MockTarget.setValue, 1338);

        executions = new Execution[](2);
        executions[0] = Execution({ target: address(target), value: 0, callData: setValueOnTarget });
        executions[1] = Execution({ target: address(target), value: 0, callData: setValueOnTarget });
        userOpCalldata =
            abi.encodeCall(IExecutionHelper.execute, (ModeLib.encodeSimpleBatch(), ExecLib.encodeBatch(executions)));
        nonce = _getNonce(account, MODE_VALIDATION, address(0), bytes3(uint24(1)));
        userOp = _buildPackedUserOp(address(account), nonce);
        userOp.callData = userOpCalldata;
        userOp.signature = _getSignature(eoaKey, userOp);
        userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;
        ENTRYPOINT.handleOps(userOps, payable(address(0x69)));
        assertTrue(target.value() == 1338);

        return account;
    }

    function test_initializeAndExecSingle_SuperExecutor() public returns (address) {
        // Get the account, initcode and nonce
        uint256 eoaKey = uint256(8);
        address account = vm.addr(eoaKey);
        vm.deal(account, 100 ether);

        // create executor
        address executor = _createSuperExecutor();

        Execution[] memory mockHookExecutions = new Execution[](1);
        mockHookExecutions[0] =
            Execution({ target: address(target), value: 0, callData: abi.encodeCall(MockTarget.setValue, 1337) });
        mockHook.setExecutionBytes(abi.encode(mockHookExecutions));

        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = address(mockHook);
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = "";
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hooksData });

        // Create calldata for the account to execute
        bytes memory initData = _getInitData(
            InitData({
                executor: executor,
                validator: address(mockValidator),
                signer: address(0),
                prevalidationHook: address(mockPreValidationHook),
                bootstrap: BOOTSTRAPPER,
                registry: REGISTRY
            })
        );

        Execution[] memory executions = new Execution[](2);
        executions[0] =
            Execution({ target: account, value: 0, callData: abi.encodeCall(INexus.initializeAccount, initData) });
        executions[1] = Execution({
            target: address(executor),
            value: 0,
            callData: abi.encodeCall(ISuperExecutor.execute, abi.encode(entry))
        });

        // Encode the call into the calldata for the userOp
        bytes memory userOpCalldata =
            abi.encodeCall(IExecutionHelper.execute, (ModeLib.encodeSimpleBatch(), ExecLib.encodeBatch(executions)));

        uint256 nonce = _getNonce(account, MODE_VALIDATION, address(0), 0);

        // Create the userOp and add the data
        PackedUserOperation memory userOp = _buildPackedUserOp(address(account), nonce);
        userOp.callData = userOpCalldata;

        userOp.signature = _getSignature(eoaKey, userOp);
        _doEIP7702(account);

        console2.log("--------- acc code length", account.code.length);

        // Create userOps array
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        // Send the userOp to the entrypoint
        ENTRYPOINT.handleOps(userOps, payable(address(0x69)));

        // Assert that the value was set ie that execution was successful
        assertTrue(target.value() == 1337);
        return account;
    }

    function test_initializeAndExecSingle_SuperExecutor_And_SuperValidator() public returns (address) {
        // Get the account, initcode and nonce
        uint256 eoaKey = uint256(8);
        address account = vm.addr(eoaKey);
        vm.label(account, "Account");
        vm.deal(account, 100 ether);

        // create executor
        address executor = _createSuperExecutor();
        address validator = _createSuperValidator();

        // recreate account
        ACCOUNT_IMPLEMENTATION = new Nexus(address(ENTRYPOINT), address(validator), abi.encode(address(0xeEeEeEeE)));
        vm.label(address(ACCOUNT_IMPLEMENTATION), "AccountImplementation");

        Execution[] memory mockHookExecutions = new Execution[](1);
        mockHookExecutions[0] =
            Execution({ target: address(target), value: 0, callData: abi.encodeCall(MockTarget.setValue, 1337) });
        mockHook.setExecutionBytes(abi.encode(mockHookExecutions));

        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = address(mockHook);
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = "";
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hooksData });

        // Create calldata for the account to execute
        bytes memory initData = _getInitData(
            InitData({
                executor: executor,
                validator: validator,
                signer: address(account),
                prevalidationHook: address(mockPreValidationHook),
                bootstrap: BOOTSTRAPPER,
                registry: REGISTRY
            })
        );

        Execution[] memory executions = new Execution[](2);
        executions[0] =
            Execution({ target: account, value: 0, callData: abi.encodeCall(INexus.initializeAccount, initData) });
        executions[1] = Execution({
            target: address(executor),
            value: 0,
            callData: abi.encodeCall(ISuperExecutor.execute, abi.encode(entry))
        });

        // Encode the call into the calldata for the userOp
        bytes memory userOpCalldata =
            abi.encodeCall(IExecutionHelper.execute, (ModeLib.encodeSimpleBatch(), ExecLib.encodeBatch(executions)));

        uint256 nonce = _getNonce(account, MODE_VALIDATION, address(0), 0);

        // Create the userOp and add the data
        PackedUserOperation memory userOp = _buildPackedUserOp(address(account), nonce);
        userOp.callData = userOpCalldata;
        userOp.sender = address(account);

        bytes32 userOpHash = ENTRYPOINT.getUserOpHash(userOp);
        userOp.signature = _createNoDestinationExecutionMerkleRootAndSignature(account, eoaKey, userOpHash, validator);
        _doEIP7702(account);

        // Create userOps array
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        // Send the userOp to the entrypoint
        ENTRYPOINT.handleOps(userOps, payable(address(0x69)));

        // Assert that the value was set ie that execution was successful
        assertTrue(target.value() == 1337);

        return account;
    }

    function test_CrossChainIntent_NoExecution_7702() public {
        uint256 eoaKey = uint256(8);
        address account = vm.addr(eoaKey);
        vm.label(account, "Account");
        vm.deal(account, 100 ether);

        address executorEth = _createSuperExecutor();
        address validatorEth = _createSuperValidator();

        ACCOUNT_IMPLEMENTATION = new Nexus(address(ENTRYPOINT), address(validatorEth), abi.encode(address(0xeEeEeEeE)));
        vm.label(address(ACCOUNT_IMPLEMENTATION), "AccountImplementation");

        bytes memory initData = _getInitData(
            InitData({
                executor: executorEth,
                validator: validatorEth,
                signer: address(account),
                prevalidationHook: address(mockPreValidationHook),
                bootstrap: BOOTSTRAPPER,
                registry: REGISTRY
            })
        );

        // ETH IS SRC
        _getTokens(underlyingETH_USDC, account, 1000e6);

        address approveERC20HookAddressEth = address(new ApproveERC20Hook());
        vm.label(approveERC20HookAddressEth, "ApproveERC20Hook");
        address acrossSendFundsAndExecuteOnDstHookAddressEth =
            address(new AcrossSendFundsAndExecuteOnDstHook(SPOKE_POOL_V3_ADDRESSES[ETH], validatorEth));
        vm.label(acrossSendFundsAndExecuteOnDstHookAddressEth, "AcrossSendFundsAndExecuteOnDstHook");

        address[] memory srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = approveERC20HookAddressEth;
        srcHooksAddresses[1] = acrossSendFundsAndExecuteOnDstHookAddressEth;

        bytes[] memory srcHooksData = new bytes[](2);
        srcHooksData[0] = _createApproveHookData(underlyingETH_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], 1000e6, false);
        srcHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingETH_USDC, underlyingBase_USDC, 1000e6, 1000e6, BASE, true, ""
        );
        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: srcHooksAddresses, hooksData: srcHooksData });

        Execution[] memory executions = new Execution[](2);
        executions[0] =
            Execution({ target: account, value: 0, callData: abi.encodeCall(INexus.initializeAccount, initData) });
        executions[1] = Execution({
            target: address(executorEth),
            value: 0,
            callData: abi.encodeCall(ISuperExecutor.execute, abi.encode(entryToExecute))
        });

        uint256 nonce = _getNonce(account, MODE_VALIDATION, address(0), 0);
        PackedUserOperation memory userOp = _buildPackedUserOp(address(account), nonce);
        userOp.callData =
            abi.encodeCall(IExecutionHelper.execute, (ModeLib.encodeSimpleBatch(), ExecLib.encodeBatch(executions)));
        userOp.sender = address(account);

        bytes32 userOpHash = ENTRYPOINT.getUserOpHash(userOp);
        userOp.signature =
            _createNoDestinationExecutionMerkleRootAndSignature(account, eoaKey, userOpHash, validatorEth);
        _doEIP7702(account);

        {
            uint256 balanceBefore = IERC20(underlyingETH_USDC).balanceOf(account);
            assertEq(balanceBefore, 1000e6);
        }
        {
            PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
            userOps[0] = userOp;
            ENTRYPOINT.handleOps(userOps, payable(address(0x69)));
        }
        {
            uint256 balanceAfter = IERC20(underlyingETH_USDC).balanceOf(account);
            assertEq(balanceAfter, 0);
        }
    }

    struct CrosschainTest {
        uint256 eoaKey;
        address account;
        address executorBase;
        address validatorBase;
        address dstExecutorBase;
        address executorEth;
        address validatorEth;
        address dstValidatorBase;
    }

    /// @notice Tests cross-chain execution using EIP-7702 delegated EOAs
    /// @dev Flow: Same EOA exists on both ETH (source) and BASE (destination) with different smart contract
    /// implementations.
    ///      1. ETH: EOA submits cross-chain tx via Across bridge (source validation with SuperValidator)
    ///      2. BASE: Across delivers message and executes on destination (destination validation with
    /// SuperDestinationValidator)
    ///      Both validators must handle EIP-7702 accounts where the signer is the account itself, not
    /// _accountOwners[account]
    function test_CrossChain_InitializePrereq_Execution() public {
        CrosschainTest memory test = CrosschainTest({
            eoaKey: uint256(8),
            account: vm.addr(uint256(8)),
            executorBase: address(0),
            validatorBase: address(0),
            dstExecutorBase: address(0),
            executorEth: address(0),
            validatorEth: address(0),
            dstValidatorBase: address(0)
        });

        console2.log("------------------------------------------------");
        console2.log("test_CrossChain_InitializePrereq_Execution");
        console2.log("------------------------------------------------");

        // ----- PRE-REQUISITES ----
        // BASE is dst - initialize and delegate
        (test.executorBase, test.validatorBase, test.dstExecutorBase, test.dstValidatorBase) =
            _initializeBaseAccount(test.eoaKey);
        address acrossV3Adapter =
            address(new AcrossV3Adapter(SPOKE_POOL_V3_ADDRESSES[BASE], address(test.dstExecutorBase)));
        vm.label(acrossV3Adapter, "AcrossV3Adapter-EIP7702");

        // ETH is src - initalize and delegate
        (test.executorEth, test.validatorEth) = _initializeEthAccount(test.eoaKey);

        // ----- Check account states ----
        _useBaseFork(1 days);
        address acrossV3Helper = address(new AcrossV3Helper());
        vm.label(acrossV3Helper, "AcrossV3Helper-EIP7702");
        vm.allowCheatcodes(acrossV3Helper);
        vm.makePersistent(acrossV3Helper);

        _executeSameChainAccountStateTest(test.eoaKey, test.executorBase, test.validatorBase, 1);

        _useEthFork(1 days);
        _executeSameChainAccountStateTest(test.eoaKey, test.executorEth, test.validatorEth, 1);

        // ----- Cross-chain call ----
        // create source data
        bytes memory destinationHookData = _getDestinationMessageInitialize(test.account);
        ISuperExecutor.ExecutorEntry memory entryToExecute =
            _createSourceEntry(destinationHookData, test.validatorEth, acrossV3Adapter);
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: address(test.executorEth),
            value: 0,
            callData: abi.encodeCall(ISuperExecutor.execute, abi.encode(entryToExecute))
        });

        // create userOp
        PackedUserOperation memory userOp = _createPackedUserOp(test.account, executions);
        bytes32 userOpHash = ENTRYPOINT.getUserOpHash(userOp);

        console2.log("----------address(test.validatorBase)", address(test.validatorBase));
        console2.log("----------address(test.validatorEth)", address(test.validatorEth));
        userOp.signature = _createCrosschainSig(
            CrosschainSigParams({
                userOpHash: userOpHash,
                accountToUse: test.account,
                dstChainId: BASE,
                srcValidator: test.validatorEth,
                dstValidator: address(test.dstValidatorBase),
                dstExecutionData: destinationHookData,
                signer: test.account,
                signerPrivateKey: test.eoaKey,
                dstExecutor: address(test.dstExecutorBase)
            })
        );

        // get tokens for across call
        _getTokens(underlyingETH_USDC, test.account, 1000e6);

        vm.recordLogs();

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        ENTRYPOINT.handleOps(userOps, payable(address(0x69)));

        VmSafe.Log[] memory logs = vm.getRecordedLogs();
        ExecutionReturnData memory executionData = ExecutionReturnData({ logs: logs });

        _processAcrossV3MessageWithSpecificDestinationFork(
            uint64(ETH), uint64(BASE), warpStartTime + 1 days, executionData, latestBaseFork, acrossV3Helper
        );

        _useBaseFork(10 days);

        // Check vault shares were minted to the account
        uint256 shares = IERC20(mockVault).balanceOf(test.account);
        uint256 expectedShares = IERC4626(mockVault).previewDeposit(1000e6);
        assertEq(shares, expectedShares, "vault shares mismatch after deposit");
    }

    /// @notice Two independent sources (ETH and OP) send Across messages to one destination (BASE)
    ///         Ensure destination execution occurs on BASE using EIP-7702 delegated EOA
    function test_CrossChainIntent_TwoSources_OneDestination_7702() public {
        uint256 eoaKey = uint256(8);
        _runTwoSourcesScenario(eoaKey, vm.addr(eoaKey));
    }

    function _runTwoSourcesScenario(uint256 eoaKey, address account) internal {
        // ----- Destination (BASE) setup with 7702 delegated EOA and modules -----
        (,, address dstExecutorBase, address dstValidatorBase) = _initializeBaseAccount(eoaKey);
        address acrossV3Adapter = address(new AcrossV3Adapter(SPOKE_POOL_V3_ADDRESSES[BASE], address(dstExecutorBase)));
        vm.label(acrossV3Adapter, "AcrossV3Adapter-TwoSources");

        // Helper on BASE for log delivery
        _useBaseFork(1 days);
        address acrossV3Helper = address(new AcrossV3Helper());
        vm.label(acrossV3Helper, "AcrossV3Helper-TwoSources");
        vm.allowCheatcodes(acrossV3Helper);
        vm.makePersistent(acrossV3Helper);

        // ----- Source setups (ETH and OP) -----
        (address executorEth, address validatorEth) = _initializeEthAccount(eoaKey);
        (address executorOp, address validatorOp) = _initializeOpAccount(eoaKey);

        // Destination execution payload (approve on BASE)
        bytes memory destinationHookData = _getDestinationMessageInitialize(account);

        // ---------- Source #1: ETH ----------
        ExecutionReturnData memory executionDataEth = _sendAcrossFromEthTwoSources(
            TwoSourcesCall({
                account: account,
                executor: executorEth,
                validator: validatorEth,
                dstValidatorBase: address(dstValidatorBase),
                dstExecutorBase: address(dstExecutorBase),
                acrossV3Adapter: acrossV3Adapter,
                destinationHookData: destinationHookData,
                eoaKey: eoaKey
            })
        );

        // ---------- Source #2: OP ----------
        ExecutionReturnData memory executionDataOp = _sendAcrossFromOpTwoSources(
            TwoSourcesCall({
                account: account,
                executor: executorOp,
                validator: validatorOp,
                dstValidatorBase: address(dstValidatorBase),
                dstExecutorBase: address(dstExecutorBase),
                acrossV3Adapter: acrossV3Adapter,
                destinationHookData: destinationHookData,
                eoaKey: eoaKey
            })
        );

        // ----- Deliver both Across messages to BASE -----
        _processAcrossV3MessageWithSpecificDestinationFork(
            uint64(ETH), uint64(BASE), warpStartTime + 1 days, executionDataEth, latestBaseFork, acrossV3Helper
        );
        _processAcrossV3MessageWithSpecificDestinationFork(
            uint64(OP), uint64(BASE), warpStartTime + 1 days, executionDataOp, latestBaseFork, acrossV3Helper
        );

        // ----- Assert destination execution occurred (full deposit) -----
        _useBaseFork(10 days);
        uint256 usdcBal = IERC20(underlyingBase_USDC).balanceOf(account);
        assertEq(usdcBal, 0, "USDC should be fully deposited");

        // Check vault shares were minted to the account
        uint256 shares = IERC20(mockVault).balanceOf(account);
        uint256 expectedShares = IERC4626(mockVault).previewDeposit(1000e6);
        assertEq(shares, expectedShares, "vault shares mismatch after deposit");
    }

    struct TwoSourcesCall {
        address account;
        address executor;
        address validator;
        address dstValidatorBase;
        address dstExecutorBase;
        address acrossV3Adapter;
        bytes destinationHookData;
        uint256 eoaKey;
    }

    function _sendAcrossFromEthTwoSources(TwoSourcesCall memory p) internal returns (ExecutionReturnData memory) {
        _useEthFork(1 days);
        _getTokens(underlyingETH_USDC, p.account, 1000e6);

        ISuperExecutor.ExecutorEntry memory srcEntryEth =
            _createSourceEntry(p.destinationHookData, p.validator, p.acrossV3Adapter);
        Execution[] memory executionsEth = new Execution[](1);
        executionsEth[0] = Execution({
            target: address(p.executor),
            value: 0,
            callData: abi.encodeCall(ISuperExecutor.execute, abi.encode(srcEntryEth))
        });
        PackedUserOperation memory userOpEth = _createPackedUserOp(p.account, executionsEth);
        bytes32 userOpHashEth = ENTRYPOINT.getUserOpHash(userOpEth);
        userOpEth.signature = _createCrosschainSig(
            CrosschainSigParams({
                userOpHash: userOpHashEth,
                accountToUse: p.account,
                dstChainId: BASE,
                srcValidator: p.validator,
                dstValidator: p.dstValidatorBase,
                dstExecutionData: p.destinationHookData,
                signer: p.account,
                signerPrivateKey: p.eoaKey,
                dstExecutor: p.dstExecutorBase
            })
        );
        vm.recordLogs();
        _executeOps(userOpEth);
        VmSafe.Log[] memory logsEth = vm.getRecordedLogs();
        return ExecutionReturnData({ logs: logsEth });
    }

    function _sendAcrossFromOpTwoSources(TwoSourcesCall memory p) internal returns (ExecutionReturnData memory) {
        _useOpFork(1 days);
        _getTokens(underlyingOP_USDC, p.account, 1000e6);

        address approveERC20HookAddressOp = address(new ApproveERC20Hook());
        vm.label(approveERC20HookAddressOp, "ApproveERC20Hook-OP");
        address acrossSendFundsAndExecuteOnDstHookAddressOp =
            address(new AcrossSendFundsAndExecuteOnDstHook(SPOKE_POOL_V3_ADDRESSES[OP], p.validator));
        vm.label(acrossSendFundsAndExecuteOnDstHookAddressOp, "AcrossSendFundsAndExecuteOnDstHook-OP");

        address[] memory srcHooksAddressesOp = new address[](2);
        srcHooksAddressesOp[0] = approveERC20HookAddressOp;
        srcHooksAddressesOp[1] = acrossSendFundsAndExecuteOnDstHookAddressOp;

        bytes[] memory srcHooksDataOp = new bytes[](2);
        srcHooksDataOp[0] = _createApproveHookData(underlyingOP_USDC, SPOKE_POOL_V3_ADDRESSES[OP], 1000e6, false);
        srcHooksDataOp[1] = _createAcrossV3ReceiveFundsAndExecuteHookDataAdapter(
            p.acrossV3Adapter, underlyingOP_USDC, underlyingBase_USDC, 1000e6, 1000e6, BASE, true, p.destinationHookData
        );
        ISuperExecutor.ExecutorEntry memory srcEntryOp =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: srcHooksAddressesOp, hooksData: srcHooksDataOp });

        Execution[] memory executionsOp = new Execution[](1);
        executionsOp[0] = Execution({
            target: address(p.executor),
            value: 0,
            callData: abi.encodeCall(ISuperExecutor.execute, abi.encode(srcEntryOp))
        });
        PackedUserOperation memory userOpOp = _createPackedUserOp(p.account, executionsOp);
        bytes32 userOpHashOp = ENTRYPOINT.getUserOpHash(userOpOp);
        userOpOp.signature = _createCrosschainSig(
            CrosschainSigParams({
                userOpHash: userOpHashOp,
                accountToUse: p.account,
                dstChainId: BASE,
                srcValidator: p.validator,
                dstValidator: p.dstValidatorBase,
                dstExecutionData: p.destinationHookData,
                signer: p.account,
                signerPrivateKey: p.eoaKey,
                dstExecutor: p.dstExecutorBase
            })
        );
        vm.recordLogs();
        _executeOps(userOpOp);
        VmSafe.Log[] memory logsOp = vm.getRecordedLogs();
        return ExecutionReturnData({ logs: logsOp });
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/
    function _useEthFork(uint256 extraTime) internal {
        vm.selectFork(latestEthFork);
        vm.warp(warpStartTime + extraTime);
    }

    function _useBaseFork(uint256 extraTime) internal {
        vm.selectFork(latestBaseFork);
        vm.warp(warpStartTime + extraTime);
    }

    function _useOpFork(uint256 extraTime) internal {
        vm.selectFork(latestOpFork);
        vm.warp(warpStartTime + extraTime);
    }

    function _executeSameChainAccountStateTest(
        uint256 eoaKey,
        address executor,
        address validator,
        uint256 txNo
    )
        internal
    {
        address account = vm.addr(eoaKey);
        vm.label(account, "Account");

        mockHook = new MockHook(ISuperHook.HookType.NONACCOUNTING, address(this));
        vm.label(address(mockHook), "MockHook");

        target = new MockTarget();
        vm.label(address(target), "MockTarget");

        Execution[] memory mockHookExecutions = new Execution[](1);
        mockHookExecutions[0] =
            Execution({ target: address(target), value: 0, callData: abi.encodeCall(MockTarget.setValue, 1337) });
        mockHook.setExecutionBytes(abi.encode(mockHookExecutions));

        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = address(mockHook);
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = "";
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hooksData });

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: address(executor),
            value: 0,
            callData: abi.encodeCall(ISuperExecutor.execute, abi.encode(entry))
        });

        bytes memory userOpCalldata =
            abi.encodeCall(IExecutionHelper.execute, (ModeLib.encodeSimpleBatch(), ExecLib.encodeBatch(executions)));
        uint256 nonce = _getNonce(account, MODE_VALIDATION, address(0), bytes3(uint24(txNo)));

        PackedUserOperation memory userOp = _buildPackedUserOp(address(account), nonce);
        userOp.callData = userOpCalldata;
        userOp.sender = address(account);

        bytes32 userOpHash = ENTRYPOINT.getUserOpHash(userOp);
        userOp.signature = _createNoDestinationExecutionMerkleRootAndSignature(account, eoaKey, userOpHash, validator);
        userOp.initCode = "";

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        ENTRYPOINT.handleOps(userOps, payable(address(0x69)));
        assertTrue(target.value() == 1337);
    }

    function _initializeBaseAccount(uint256 eoaKey)
        public
        returns (address executor, address validator, address dstExecutor, address dstValidator)
    {
        _useBaseFork(0);
        address account = vm.addr(eoaKey);
        vm.label(account, "AccountBase");
        vm.deal(account, 100 ether);

        executor = _createSuperExecutor();
        validator = _createSuperValidator();
        dstValidator = _createSuperDestinationValidator();
        dstExecutor = _createSuperDestinationExecutor(dstValidator);

        ACCOUNT_IMPLEMENTATION_BASE =
            new Nexus(address(ENTRYPOINT), address(validator), abi.encode(address(0xeEeEeEeE)));
        vm.label(address(ACCOUNT_IMPLEMENTATION_BASE), "AccountImplementationBase");

        address[] memory executors = new address[](2);
        executors[0] = executor;
        executors[1] = dstExecutor;
        address[] memory validators = new address[](2);
        validators[0] = validator;
        validators[1] = dstValidator;

        {
            bytes memory initDataBase = _getInitDataForDestination(
                account,
                InitDataDestination({
                    executor: executors,
                    validator: validators,
                    signer: address(account),
                    prevalidationHook: address(mockPreValidationHook_Base),
                    bootstrap: BOOTSTRAPPER_BASE,
                    registry: REGISTRY_BASE
                })
            );

            Execution[] memory executionsBase = new Execution[](1);
            executionsBase[0] = Execution({
                target: account,
                value: 0,
                callData: abi.encodeCall(INexus.initializeAccount, initDataBase)
            });

            bytes memory userOpCalldataBase = abi.encodeCall(
                IExecutionHelper.execute, (ModeLib.encodeSimpleBatch(), ExecLib.encodeBatch(executionsBase))
            );
            _initializeBaseAccountExecuteUserOp(account, validator, eoaKey, userOpCalldataBase);
        }
    }

    function _initializeBaseAccountExecuteUserOp(
        address account,
        address validator,
        uint256 eoaKey,
        bytes memory userOpCalldataBase
    )
        internal
    {
        uint256 nonce = _getNonce(account, MODE_VALIDATION, address(0), 0);

        PackedUserOperation memory userOpBase = _buildPackedUserOp(address(account), nonce);
        userOpBase.callData = userOpCalldataBase;
        userOpBase.sender = address(account);

        bytes32 userOpHashBase = ENTRYPOINT.getUserOpHash(userOpBase);
        userOpBase.signature =
            _createNoDestinationExecutionMerkleRootAndSignature(account, eoaKey, userOpHashBase, address(validator));

        _doEIP7702OnDestination(account);
        assertEq(account.code.length, 23, "base account not delegated");

        PackedUserOperation[] memory userOpsBase = new PackedUserOperation[](1);
        userOpsBase[0] = userOpBase;

        ENTRYPOINT.handleOps(userOpsBase, payable(address(0x69)));
    }

    function _initializeEthAccount(uint256 eoaKey) public returns (address, address) {
        _useEthFork(0);
        address account = vm.addr(eoaKey);
        vm.label(account, "AccountETH");
        vm.deal(account, 100 ether);

        address executor = _createSuperExecutor();
        address validator = _createSuperValidator();

        ACCOUNT_IMPLEMENTATION = new Nexus(address(ENTRYPOINT), address(validator), abi.encode(address(0xeEeEeEeE)));
        vm.label(address(ACCOUNT_IMPLEMENTATION), "AccountImplementationETH");

        bytes memory initData = _getInitData(
            InitData({
                executor: address(executor),
                validator: address(validator),
                signer: address(account),
                prevalidationHook: address(mockPreValidationHook),
                bootstrap: BOOTSTRAPPER,
                registry: REGISTRY
            })
        );

        Execution[] memory executions = new Execution[](1);
        executions[0] =
            Execution({ target: account, value: 0, callData: abi.encodeCall(INexus.initializeAccount, initData) });

        bytes memory userOpCalldata =
            abi.encodeCall(IExecutionHelper.execute, (ModeLib.encodeSimpleBatch(), ExecLib.encodeBatch(executions)));
        uint256 nonce = _getNonce(account, MODE_VALIDATION, address(0), 0);

        PackedUserOperation memory userOp = _buildPackedUserOp(address(account), nonce);
        userOp.callData = userOpCalldata;
        userOp.sender = address(account);

        bytes32 userOpHash = ENTRYPOINT.getUserOpHash(userOp);
        userOp.signature =
            _createNoDestinationExecutionMerkleRootAndSignature(account, eoaKey, userOpHash, address(validator));

        _doEIP7702(account);
        assertEq(account.code.length, 23, "base account not delegated");

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        ENTRYPOINT.handleOps(userOps, payable(address(0x69)));

        return (executor, validator);
    }

    function _initializeOpAccount(uint256 eoaKey) public returns (address, address) {
        _useOpFork(0);
        address account = vm.addr(eoaKey);
        vm.label(account, "AccountOP");
        vm.deal(account, 100 ether);

        address executor = _createSuperExecutor();
        address validator = _createSuperValidator();

        ACCOUNT_IMPLEMENTATION = new Nexus(address(ENTRYPOINT), address(validator), abi.encode(address(0xeEeEeEeE)));
        vm.label(address(ACCOUNT_IMPLEMENTATION), "AccountImplementationOP");

        bytes memory initData = _getInitData(
            InitData({
                executor: address(executor),
                validator: address(validator),
                signer: address(account),
                prevalidationHook: address(mockPreValidationHook),
                bootstrap: BOOTSTRAPPER,
                registry: REGISTRY
            })
        );

        Execution[] memory executions = new Execution[](1);
        executions[0] =
            Execution({ target: account, value: 0, callData: abi.encodeCall(INexus.initializeAccount, initData) });

        bytes memory userOpCalldata =
            abi.encodeCall(IExecutionHelper.execute, (ModeLib.encodeSimpleBatch(), ExecLib.encodeBatch(executions)));
        uint256 nonce = _getNonce(account, MODE_VALIDATION, address(0), 0);

        PackedUserOperation memory userOp = _buildPackedUserOp(address(account), nonce);
        userOp.callData = userOpCalldata;
        userOp.sender = address(account);

        bytes32 userOpHash = ENTRYPOINT.getUserOpHash(userOp);
        userOp.signature =
            _createNoDestinationExecutionMerkleRootAndSignature(account, eoaKey, userOpHash, address(validator));

        _doEIP7702(account);
        assertEq(account.code.length, 23, "op account not delegated");

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        ENTRYPOINT.handleOps(userOps, payable(address(0x69)));

        return (executor, validator);
    }

    function _executeOps(PackedUserOperation memory userOp) internal {
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;
        ENTRYPOINT.handleOps(userOps, payable(address(0x69)));
    }

    function _createPackedUserOp(
        address account,
        Execution[] memory executions
    )
        internal
        view
        returns (PackedUserOperation memory userOp)
    {
        uint256 nonce = _getNonce(account, MODE_VALIDATION, address(0), 0);
        userOp = _buildPackedUserOp(address(account), nonce);
        userOp.callData =
            abi.encodeCall(IExecutionHelper.execute, (ModeLib.encodeSimpleBatch(), ExecLib.encodeBatch(executions)));
        userOp.sender = address(account);
    }

    function _createDestinationEntry() internal returns (ISuperExecutor.ExecutorEntry memory entryToExecute) {
        // Deploy hooks on BASE so they exist at execution time
        _useBaseFork(1 days);
        address approveERC20HookAddressBase = address(new ApproveERC20Hook());
        vm.label(approveERC20HookAddressBase, "ApproveERC20Hook-Base");
        address deposit4626HookAddressBase = address(new Deposit4626VaultHook());
        vm.label(deposit4626HookAddressBase, "Deposit4626VaultHook-Base");

        // Return to ETH fork for the rest of the flow construction
        _useEthFork(1 days);

        address[] memory hookAddresses = new address[](2);
        hookAddresses[0] = approveERC20HookAddressBase;
        hookAddresses[1] = deposit4626HookAddressBase;

        bytes[] memory hookData = new bytes[](2);
        // Deploy a simple mock ERC4626 vault for testing on BASE fork (only if not already deployed)
        if (mockVault == address(0)) {
            _useBaseFork(1 days);
            mockVault = _deployMockERC4626Vault(underlyingBase_USDC);
            _useEthFork(1 days);
        }

        // Approve the vault to pull the full intent amount
        hookData[0] = _createApproveHookData(underlyingBase_USDC, mockVault, 1000e6, false);
        // Deposit uses previous hook amount (allowance) as assets
        hookData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            mockVault,
            1000e6,
            true,
            address(0),
            0
        );

        entryToExecute = ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookData });
    }

    function _deployMockERC4626Vault(address _asset) internal returns (address) {
        Mock4626Vault vault = new Mock4626Vault(_asset, "Mock Vault", "MVAULT");
        vm.label(address(vault), "Mock4626Vault");
        return address(vault);
    }

    function _getDestinationMessageInitialize(address _account) internal returns (bytes memory) {
        // get execution data
        ISuperExecutor.ExecutorEntry memory entryToExecute = _createDestinationEntry();
        bytes memory destinationExecutionData =
            abi.encodeWithSelector(ISuperExecutor.execute.selector, abi.encode(entryToExecute));

        bytes memory initData = "";

        address[] memory dstTokens = new address[](1);
        dstTokens[0] = underlyingBase_USDC;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1000e6;

        return abi.encode(initData, destinationExecutionData, _account, dstTokens, intentAmounts);
    }

    function _createSourceEntry(
        bytes memory _destinationMessage,
        address _validator,
        address _adapter
    )
        internal
        returns (ISuperExecutor.ExecutorEntry memory entryToExecute)
    {
        (address[] memory srcHooksAddresses, bytes[] memory srcHooksData) =
            _prepareSourceEntryData(_destinationMessage, _validator, _adapter);

        entryToExecute = ISuperExecutor.ExecutorEntry({ hooksAddresses: srcHooksAddresses, hooksData: srcHooksData });
    }

    function _prepareSourceEntryData(
        bytes memory _destinationMessage,
        address _validator,
        address _adapter
    )
        internal
        returns (address[] memory srcHooksAddresses, bytes[] memory srcHooksData)
    {
        (address approveERC20HookAddressEth, address acrossSendFundsAndExecuteOnDstHookAddressEth) =
            _createSourceEntryHooks(_validator);

        srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = approveERC20HookAddressEth;
        srcHooksAddresses[1] = acrossSendFundsAndExecuteOnDstHookAddressEth;

        srcHooksData = new bytes[](2);
        srcHooksData[0] = _createApproveHookData(underlyingETH_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], 1000e6, false);
        srcHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookDataAdapter(
            _adapter, underlyingETH_USDC, underlyingBase_USDC, 1000e6, 1000e6, BASE, true, _destinationMessage
        );
    }

    function _createSourceEntryHooks(address _validator)
        private
        returns (address approveERC20HookAddressEth, address acrossSendFundsAndExecuteOnDstHookAddressEth)
    {
        approveERC20HookAddressEth = address(new ApproveERC20Hook());
        vm.label(approveERC20HookAddressEth, "ApproveERC20Hook-Eth");
        acrossSendFundsAndExecuteOnDstHookAddressEth =
            address(new AcrossSendFundsAndExecuteOnDstHook(SPOKE_POOL_V3_ADDRESSES[ETH], _validator));
        vm.label(acrossSendFundsAndExecuteOnDstHookAddressEth, "AcrossSendFundsAndExecuteOnDstHook-Eth");
    }

    function _createSuperDestinationExecutor(address _validator) internal returns (address superDestinationExecutor) {
        // install a new SuperDestinationExecutor (so we can uninstall the old one)
        // -- create
        ISuperLedgerConfiguration superLedgerConfigurationNew =
            ISuperLedgerConfiguration(address(new SuperLedgerConfiguration()));
        vm.label(address(superLedgerConfigurationNew), "NewSuperLedgerConfiguration");

        ISuperDestinationExecutor superDestinationExecutorNew = ISuperDestinationExecutor(
            address(new SuperDestinationExecutor(address(superLedgerConfigurationNew), address(_validator)))
        );
        vm.label(address(superDestinationExecutorNew), "NewSuperDestinationExecutor");
        // -- configure ledger and yield source oracle for 4626 on BASE so INFLOW hooks don't revert
        address[] memory allowedExecutors = new address[](1);
        allowedExecutors[0] = address(superDestinationExecutorNew);
        ISuperLedger superLedgerNew =
            ISuperLedger(address(new SuperLedger(address(superLedgerConfigurationNew), allowedExecutors)));
        address ledgerFeeReceiver = makeAddr("LedgerFeeReceiver-Base");

        // Deploy ERC4626YieldSourceOracle on Base fork
        address erc4626Oracle = address(new ERC4626YieldSourceOracle(address(superLedgerConfigurationNew)));
        vm.label(erc4626Oracle, "ERC4626YieldSourceOracle-Base");

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: erc4626Oracle,
            feePercent: 100,
            feeRecipient: ledgerFeeReceiver,
            ledger: address(superLedgerNew)
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY));
        superLedgerConfigurationNew.setYieldSourceOracles(salts, configs);

        return address(superDestinationExecutorNew);
    }

    function _createSuperExecutor() internal returns (address superExecutor) {
        // install a new SuperExecutor (so we can uninstall the old one)
        // -- create
        ISuperLedgerConfiguration superLedgerConfigurationNew =
            ISuperLedgerConfiguration(address(new SuperLedgerConfiguration()));
        vm.label(address(superLedgerConfigurationNew), "NewSuperLedgerConfiguration");
        ISuperExecutor superExecutorNew =
            ISuperExecutor(address(new SuperExecutor(address(superLedgerConfigurationNew))));
        vm.label(address(superExecutorNew), "NewSuperExecutor");

        // -- configure ledger
        address[] memory allowedExecutors = new address[](1);
        allowedExecutors[0] = address(superExecutorNew);
        ISuperLedger superLedgerNew =
            ISuperLedger(address(new SuperLedger(address(superLedgerConfigurationNew), allowedExecutors)));

        address ledgerFeeReceiver = makeAddr("LedgerFeeReceiver");
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY),
            feePercent: 100,
            feeRecipient: ledgerFeeReceiver,
            ledger: address(superLedgerNew)
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY));

        return address(superExecutorNew);
    }

    function _createSuperValidator() internal returns (address superValidator) {
        return address(new SuperValidator());
    }

    function _createSuperDestinationValidator() internal returns (address superValidator) {
        return address(new SuperDestinationValidator());
    }

    struct CrosschainSigParams {
        bytes32 userOpHash;
        address accountToUse;
        uint64 dstChainId;
        address srcValidator;
        address dstValidator;
        bytes dstExecutionData;
        address signer;
        uint256 signerPrivateKey;
        address dstExecutor;
    }

    function _createCrosschainSig(CrosschainSigParams memory params) internal view returns (bytes memory sig) {
        MerkleContext memory ctx;

        ctx.validUntil = uint48(block.timestamp + 100 days);
        ctx.executionData = params.dstExecutionData;

        ctx.leaves = new bytes32[](2);
        (, ctx.executionData,, ctx.dstTokens, ctx.intentAmounts) =
            abi.decode(params.dstExecutionData, (bytes, bytes, address, address[], uint256[]));
        ctx.leaves[0] = _createDestinationValidatorLeaf(
            ctx.executionData,
            params.dstChainId,
            params.accountToUse,
            params.dstExecutor,
            ctx.dstTokens,
            ctx.intentAmounts,
            ctx.validUntil,
            params.dstValidator
        );
        console2.log("ctx.executionData length", ctx.executionData.length);
        console2.log("params.dstChainId", params.dstChainId);
        console2.log("params.accountToUse", params.accountToUse);
        console2.log("params.dstExecutor", params.dstExecutor);
        console2.log("params.dstTokens", ctx.dstTokens.length);
        console2.log("params.intentAmounts", ctx.intentAmounts.length);
        console2.log("params.validUntil", uint256(ctx.validUntil));
        console2.log("params.dstValidator", params.dstValidator);
        uint64[] memory chainsForLeaf = new uint64[](1);
        chainsForLeaf[0] = params.dstChainId;
        ctx.leaves[1] =
            _createSourceValidatorLeaf(params.userOpHash, ctx.validUntil, chainsForLeaf, params.srcValidator);

        (ctx.merkleProof, ctx.merkleRoot) = _createValidatorMerkleTree(ctx.leaves);

        ctx.signature = _createSignature("SuperValidator", ctx.merkleRoot, params.signer, params.signerPrivateKey);

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        ISuperValidator.DstInfo memory dstInfo = ISuperValidator.DstInfo({
            data: ctx.executionData,
            executor: params.dstExecutor,
            dstTokens: ctx.dstTokens,
            intentAmounts: ctx.intentAmounts,
            account: params.accountToUse,
            validator: params.dstValidator
        });
        proofDst[0] =
            ISuperValidator.DstProof({ proof: ctx.merkleProof[0], dstChainId: params.dstChainId, info: dstInfo });

        uint64[] memory chainsWithDestExecution = new uint64[](1);
        chainsWithDestExecution[0] = params.dstChainId;
        sig = _createSignatureData_DestinationExecutorWithChains(
            chainsWithDestExecution, ctx.validUntil, ctx.merkleRoot, ctx.merkleProof[1], proofDst, ctx.signature
        );
    }

    function _doEIP7702(address eoa) internal {
        vm.etch(eoa, abi.encodePacked(EIP7702_PREFIX, bytes20(address(ACCOUNT_IMPLEMENTATION))));
    }

    function _doEIP7702OnDestination(address eoa) internal {
        vm.etch(eoa, abi.encodePacked(EIP7702_PREFIX, bytes20(address(ACCOUNT_IMPLEMENTATION_BASE))));
    }

    function _getSignature(uint256 eoaKey, PackedUserOperation memory userOp) internal view returns (bytes memory) {
        bytes32 _hash = ENTRYPOINT.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(eoaKey, MessageHashUtils.toEthSignedMessageHash(_hash));
        return abi.encodePacked(r, s, v);
    }

    struct InitData {
        address executor;
        address validator;
        address signer;
        address prevalidationHook;
        NexusBootstrap bootstrap;
        MockRegistry registry;
    }

    struct InitDataDestination {
        address[] executor;
        address[] validator;
        address signer;
        address prevalidationHook;
        NexusBootstrap bootstrap;
        MockRegistry registry;
    }

    function _prepareBootstrapConfigs(InitData memory initData)
        internal
        pure
        returns (
            BootstrapConfig[] memory validators,
            BootstrapConfig[] memory executors,
            BootstrapConfig memory hook,
            BootstrapConfig[] memory fallbacks,
            BootstrapPreValidationHookConfig[] memory preValidationHooks
        )
    {
        // Create validator configs
        if (initData.signer == address(0)) {
            validators = BootstrapLib.createArrayConfig(initData.validator, "");
        } else {
            validators = BootstrapLib.createArrayConfig(initData.validator, abi.encode(initData.signer));
        }

        // Create other configs
        executors = BootstrapLib.createArrayConfig(initData.executor, "");
        hook = BootstrapLib.createSingleConfig(address(0), "");
        fallbacks = BootstrapLib.createArrayConfig(address(0), "");
        preValidationHooks = BootstrapLib.createArrayPreValidationHookConfig(
            MODULE_TYPE_PREVALIDATION_HOOK_ERC4337, initData.prevalidationHook, ""
        );
    }

    function _createRegistryConfig(InitData memory initData) internal view returns (RegistryConfig memory config) {
        return RegistryConfig({ registry: initData.registry, attesters: ATTESTERS, threshold: THRESHOLD });
    }

    function _createRegistryConfigForDestinationData(InitDataDestination memory initData)
        internal
        view
        returns (RegistryConfig memory config)
    {
        return RegistryConfig({ registry: initData.registry, attesters: ATTESTERS, threshold: THRESHOLD });
    }

    function _getInitData(InitData memory initData) internal view returns (bytes memory) {
        (
            BootstrapConfig[] memory validators,
            BootstrapConfig[] memory executors,
            BootstrapConfig memory hook,
            BootstrapConfig[] memory fallbacks,
            BootstrapPreValidationHookConfig[] memory preValidationHooks
        ) = _prepareBootstrapConfigs(initData);

        return abi.encode(
            address(initData.bootstrap),
            abi.encodeCall(
                initData.bootstrap.initNexus,
                (validators, executors, hook, fallbacks, preValidationHooks, _createRegistryConfig(initData))
            )
        );
    }

    function _prepareBootstrapConfigsForDestination(
        InitDataDestination memory initDataDestination,
        address account
    )
        internal
        pure
        returns (
            BootstrapConfig[] memory validators,
            BootstrapConfig[] memory executors,
            BootstrapConfig memory hook,
            BootstrapConfig[] memory fallbacks,
            BootstrapPreValidationHookConfig[] memory preValidationHooks
        )
    {
        validators = _arrToBootstrapConfigArr(initDataDestination.validator, account);
        executors = _arrToBootstrapConfigArr(initDataDestination.executor, account);
        hook = BootstrapLib.createSingleConfig(address(0), "");
        fallbacks = BootstrapLib.createArrayConfig(address(0), "");
        preValidationHooks = BootstrapLib.createArrayPreValidationHookConfig(
            MODULE_TYPE_PREVALIDATION_HOOK_ERC4337, initDataDestination.prevalidationHook, ""
        );
    }

    function _arrToBootstrapConfigArr(
        address[] memory arr,
        address account
    )
        internal
        pure
        returns (BootstrapConfig[] memory)
    {
        //struct BootstrapConfig {
        //    address module;
        //    bytes data;
        //}
        BootstrapConfig[] memory bootstrapArr = new BootstrapConfig[](arr.length);
        for (uint256 i; i < arr.length; ++i) {
            bootstrapArr[i] = BootstrapConfig({ module: arr[i], data: abi.encode(account) });
        }
        return bootstrapArr;
    }

    function _getInitDataForDestination(
        address account,
        InitDataDestination memory initDataDestination
    )
        internal
        view
        returns (bytes memory)
    {
        (
            BootstrapConfig[] memory validators,
            BootstrapConfig[] memory executors,
            BootstrapConfig memory hook,
            BootstrapConfig[] memory fallbacks,
            BootstrapPreValidationHookConfig[] memory preValidationHooks
        ) = _prepareBootstrapConfigsForDestination(initDataDestination, account);

        return abi.encode(
            address(initDataDestination.bootstrap),
            abi.encodeCall(
                initDataDestination.bootstrap.initNexus,
                (
                    validators,
                    executors,
                    hook,
                    fallbacks,
                    preValidationHooks,
                    _createRegistryConfigForDestinationData(initDataDestination)
                )
            )
        );
    }

    function _getNonce(
        address account,
        bytes1 vMode,
        address validator,
        bytes3 batchId
    )
        internal
        view
        returns (uint256 nonce)
    {
        uint192 key = _makeNonceKey(vMode, validator, batchId);
        nonce = ENTRYPOINT.getNonce(address(account), key);
    }

    function _makeNonceKey(bytes1 vMode, address validator, bytes3 batchId) internal pure returns (uint192 key) {
        assembly {
            key := or(shr(88, vMode), validator)
            key := or(shr(64, batchId), key)
        }
    }

    function _buildPackedUserOp(address sender, uint256 nonce) internal pure returns (PackedUserOperation memory) {
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: "",
            callData: "",
            accountGasLimits: bytes32(abi.encodePacked(uint128(3e6), uint128(3e6))), // verification and call gas limit
            preVerificationGas: 3e5, // Adjusted preVerificationGas
            gasFees: bytes32(abi.encodePacked(uint128(3e6), uint128(3e6))), // maxFeePerGas and maxPriorityFeePerGas
            paymasterAndData: "",
            signature: ""
        });
    }
}
