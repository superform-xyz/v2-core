// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;


// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// -- nexus
import { Nexus } from "@nexus/Nexus.sol";
import { NexusAccountFactory } from "@nexus/factory/NexusAccountFactory.sol";
import { MockValidator } from "@nexus/mocks/MockValidator.sol";
import { MockExecutor } from "@nexus/mocks/MockExecutor.sol";
import { MockRegistry } from "@nexus/mocks/MockRegistry.sol";
import { MockPreValidationHook } from "@nexus/mocks/MockPreValidationHook.sol";
import { MockTarget } from "@nexus/mocks/MockTarget.sol";
import { BootstrapConfig, BootstrapPreValidationHookConfig, RegistryConfig, NexusBootstrap } from "@nexus/utils/NexusBootstrap.sol";
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

import { IERC7579Account } from "../../../lib/modulekit/src/accounts/common/interfaces/IERC7579Account.sol";
import { ModeCode } from "../../../lib/modulekit/src/accounts/common/lib/ModeLib.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// Superform
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { SuperExecutorBase } from  "../../../src/executors/SuperExecutorBase.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { SuperExecutor } from  "../../../src/executors/SuperExecutor.sol";
import { SuperDestinationExecutor } from "../../../src/executors/SuperDestinationExecutor.sol";
import { SuperValidatorBase } from "../../../src/validators/SuperValidatorBase.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { SuperMerkleValidator } from "../../../src/validators/SuperMerkleValidator.sol";
import { SuperDestinationValidator } from "../../../src/validators/SuperDestinationValidator.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperDestinationExecutor } from "../../../src/interfaces/ISuperDestinationExecutor.sol";
import { ISuperLedger, ISuperLedgerData } from "../../../src/interfaces/accounting/ISuperLedger.sol";
import { ApproveERC20Hook } from "../../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { AcrossSendFundsAndExecuteOnDstHook } from "../../../src/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol";
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
    MockTarget public target_Base;


    address factoryOwner;
    uint256 constant MODULE_TYPE_PREVALIDATION_HOOK_ERC4337 = 9;
    bytes3 internal constant EIP7702_PREFIX = bytes3(0xef0100);

    // superform
    MockHook public mockHook;
    address public underlyingETH_USDC;
    address public underlyingBase_USDC;

    SuperDestinationValidator public superDestinationValidator_Base;
    SuperDestinationExecutor public superDestinationExecutor_Base;

    function setUp() public override {
        warpStartTime = 1753501381;
         latestEthFork = vm.createFork(ETHEREUM_RPC_URL);
        latestBaseFork = vm.createFork(BASE_RPC_URL);

        ENTRYPOINT = EntryPoint(payable(ENTRYPOINT_ADDR));
        vm.label(address(ENTRYPOINT), "ENTRYPOINT");

        factoryOwner = makeAddr("factoryOwner");
        deal(factoryOwner, 100 ether);
        vm.label(factoryOwner, "FactoryOwner");

        ATTESTERS = new address[](1);
        ATTESTERS[0] = address(this);
        THRESHOLD = 1;

        super.setUp();

        // create BASE fork data
        _useBaseFork(0);
        deal(factoryOwner, 100 ether);

        DEFAULT_VALIDATOR_MODULE_BASE = new SuperDestinationValidator();
        vm.label(address(DEFAULT_VALIDATOR_MODULE_BASE), "SuperDestinationValidator-Base");
        vm.makePersistent(address(DEFAULT_VALIDATOR_MODULE_BASE));
        ACCOUNT_IMPLEMENTATION_BASE = new Nexus(address(ENTRYPOINT), address(DEFAULT_VALIDATOR_MODULE_BASE), abi.encode(address(0xeEeEeEeE)));
        vm.label(address(ACCOUNT_IMPLEMENTATION_BASE), "ACCOUNT_IMPLEMENTATION-Base");
        vm.makePersistent(address(ACCOUNT_IMPLEMENTATION_BASE));
        FACTORY_BASE = new NexusAccountFactory(address(ACCOUNT_IMPLEMENTATION_BASE), factoryOwner);
        vm.label(address(FACTORY_BASE), "FACTORY-Base");
        vm.makePersistent(address(FACTORY_BASE));
        REGISTRY_BASE = new MockRegistry();
        vm.label(address(REGISTRY_BASE), "REGISTRY-Base");
        BOOTSTRAPPER_BASE = new NexusBootstrap(address(DEFAULT_VALIDATOR_MODULE_BASE), abi.encode(address(0xa11ce)));
        vm.label(address(BOOTSTRAPPER_BASE), "BOOTSTRAPPER-Base");
        vm.makePersistent(address(BOOTSTRAPPER_BASE));

        mockValidator_Base = new MockValidator();
        vm.label(address(mockValidator_Base), "MockValidator-Base");
        mockExecutor_Base = new MockExecutor();
        vm.label(address(mockExecutor_Base), "MockExecutor-Base");
        mockPreValidationHook_Base = new MockPreValidationHook();
        vm.label(address(mockPreValidationHook_Base), "MockPreValidationHook-Base");
        target_Base = new MockTarget();
        vm.label(address(target_Base), "MockTarget-Base");

        superDestinationValidator_Base = new SuperDestinationValidator();
        vm.label(address(superDestinationValidator_Base), "SuperDestinationValidator-Base");
        vm.makePersistent(address(superDestinationValidator_Base));
        superDestinationExecutor_Base = SuperDestinationExecutor(_createSuperDestinationExecutor());
        vm.makePersistent(address(superDestinationExecutor_Base));
        vm.label(address(superDestinationExecutor_Base), "SuperDestinationExecutor-Base");
      
        // create ETH fork data
        _useEthFork(0);
        deal(factoryOwner, 100 ether);

        DEFAULT_VALIDATOR_MODULE = new K1Validator();
        vm.label(address(DEFAULT_VALIDATOR_MODULE), "K1Validator");
        ACCOUNT_IMPLEMENTATION = new Nexus(address(ENTRYPOINT), address(DEFAULT_VALIDATOR_MODULE), abi.encodePacked(address(0xeEeEeEeE)));
        vm.label(address(ACCOUNT_IMPLEMENTATION), "ACCOUNT_IMPLEMENTATION");
        FACTORY = new NexusAccountFactory(address(ACCOUNT_IMPLEMENTATION), factoryOwner);
        vm.label(address(FACTORY), "FACTORY");
        REGISTRY = new MockRegistry();
        vm.label(address(REGISTRY), "REGISTRY");
        BOOTSTRAPPER = new NexusBootstrap(address(DEFAULT_VALIDATOR_MODULE), abi.encodePacked(address(0xa11ce)));
        vm.label(address(BOOTSTRAPPER), "BOOTSTRAPPER");
        vm.makePersistent(address(BOOTSTRAPPER));       
        mockValidator = new MockValidator();
        vm.label(address(mockValidator), "MockValidator");
        mockExecutor = new MockExecutor();
        vm.label(address(mockExecutor), "MockExecutor");
        mockPreValidationHook = new MockPreValidationHook();
        vm.label(address(mockPreValidationHook), "MockPreValidationHook");
        vm.makePersistent(address(mockPreValidationHook));
        target = new MockTarget();
        vm.label(address(target), "MockTarget");

        mockHook = new MockHook(ISuperHook.HookType.NONACCOUNTING, address(this));

        // Superform
        underlyingBase_USDC = existingUnderlyingTokens[BASE][USDC_KEY];
        vm.label(underlyingBase_USDC, "underlyingBase_USDC");
        underlyingETH_USDC = existingUnderlyingTokens[ETH][USDC_KEY];
        vm.label(underlyingETH_USDC, "underlyingETH_USDC");

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
        bytes memory userOpCalldata =
            abi.encodeCall(IExecutionHelper.execute, (ModeLib.encodeSimpleSingle(), ExecLib.encodeSingle(address(target), uint256(0), setValueOnTarget)));

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

        bytes memory initData = _getInitData(InitData({
            executor: address(mockExecutor),
            validator: address(mockValidator),
            signer: address(0),
            prevalidationHook: address(mockPreValidationHook),
            bootstrap: BOOTSTRAPPER,
            registry: REGISTRY
        }));

        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({ target: account, value: 0, callData: abi.encodeCall(INexus.initializeAccount, initData) });
        executions[1] = Execution({ target: address(target), value: 0, callData: setValueOnTarget });

        // Encode the call into the calldata for the userOp
        bytes memory userOpCalldata = abi.encodeCall(IExecutionHelper.execute, (ModeLib.encodeSimpleBatch(), ExecLib.encodeBatch(executions)));

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

        bytes memory initData = _getInitData(InitData({
            executor: address(mockExecutor),
            validator: address(mockValidator),
            signer: address(0),
            prevalidationHook: address(mockPreValidationHook),
            bootstrap: BOOTSTRAPPER,
            registry: REGISTRY
        }));

        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({ target: account, value: 0, callData: abi.encodeCall(INexus.initializeAccount, initData) });
        executions[1] = Execution({ target: address(target), value: 0, callData: setValueOnTarget });

        // Encode the call into the calldata for the userOp
        bytes memory userOpCalldata = abi.encodeCall(IExecutionHelper.execute, (ModeLib.encodeSimpleBatch(), ExecLib.encodeBatch(executions)));

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
        userOpCalldata = abi.encodeCall(IExecutionHelper.execute, (ModeLib.encodeSimpleBatch(), ExecLib.encodeBatch(executions)));
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
        mockHookExecutions[0] = Execution({
            target: address(target),
            value: 0,
            callData: abi.encodeCall(MockTarget.setValue, 1337)
        });
        mockHook.setExecutionBytes(abi.encode(mockHookExecutions));

        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = address(mockHook);
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = "";
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hooksData });
        
        // Create calldata for the account to execute
        bytes memory initData = _getInitData(InitData({
            executor: executor,
            validator: address(mockValidator),
            signer: address(0),
            prevalidationHook: address(mockPreValidationHook),
            bootstrap: BOOTSTRAPPER,
            registry: REGISTRY
        }));

        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({ target: account, value: 0, callData: abi.encodeCall(INexus.initializeAccount, initData) });
        executions[1] = Execution({ target: address(executor), value: 0, callData: abi.encodeCall(ISuperExecutor.execute, abi.encode(entry)) });

        // Encode the call into the calldata for the userOp
        bytes memory userOpCalldata = abi.encodeCall(IExecutionHelper.execute, (ModeLib.encodeSimpleBatch(), ExecLib.encodeBatch(executions)));

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
        ACCOUNT_IMPLEMENTATION = new Nexus(address(ENTRYPOINT), address(validator), abi.encode(address(account)));
        vm.label(address(ACCOUNT_IMPLEMENTATION), "AccountImplementation");

        Execution[] memory mockHookExecutions = new Execution[](1);
        mockHookExecutions[0] = Execution({
            target: address(target),
            value: 0,
            callData: abi.encodeCall(MockTarget.setValue, 1337)
        });
        mockHook.setExecutionBytes(abi.encode(mockHookExecutions));

        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = address(mockHook);
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = "";
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hooksData });
        
        // Create calldata for the account to execute
        bytes memory initData = _getInitData(InitData({
            executor: executor,
            validator: validator,
            signer: address(account),
            prevalidationHook: address(mockPreValidationHook),
            bootstrap: BOOTSTRAPPER,
            registry: REGISTRY
        }));

        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({ target: account, value: 0, callData: abi.encodeCall(INexus.initializeAccount, initData) });
        executions[1] = Execution({ target: address(executor), value: 0, callData: abi.encodeCall(ISuperExecutor.execute, abi.encode(entry)) });

        // Encode the call into the calldata for the userOp
        bytes memory userOpCalldata = abi.encodeCall(IExecutionHelper.execute, (ModeLib.encodeSimpleBatch(), ExecLib.encodeBatch(executions)));

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

        ACCOUNT_IMPLEMENTATION = new Nexus(address(ENTRYPOINT), address(validatorEth), abi.encode(address(account)));
        vm.label(address(ACCOUNT_IMPLEMENTATION), "AccountImplementation");

        bytes memory initData = _getInitData(InitData({
            executor: executorEth,
            validator: validatorEth,
            signer: address(account),
            prevalidationHook: address(mockPreValidationHook),
            bootstrap: BOOTSTRAPPER,
            registry: REGISTRY
        }));


        // ETH IS SRC
        _getTokens(underlyingETH_USDC, account, 1e6);

        address approveERC20HookAddressEth = address(new ApproveERC20Hook());
        vm.label(approveERC20HookAddressEth, "ApproveERC20Hook");
        address acrossSendFundsAndExecuteOnDstHookAddressEth = address(new AcrossSendFundsAndExecuteOnDstHook(SPOKE_POOL_V3_ADDRESSES[ETH], validatorEth));
        vm.label(acrossSendFundsAndExecuteOnDstHookAddressEth, "AcrossSendFundsAndExecuteOnDstHook");

        address[] memory srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = approveERC20HookAddressEth;
        srcHooksAddresses[1] = acrossSendFundsAndExecuteOnDstHookAddressEth;

        bytes[] memory srcHooksData = new bytes[](2);
        srcHooksData[0] =
            _createApproveHookData(underlyingETH_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], 1e6, false);
        srcHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingETH_USDC, underlyingBase_USDC, 1e6, 1e6, BASE, true, ""
        );
        ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: srcHooksAddresses, hooksData: srcHooksData });


        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({ target: account, value: 0, callData: abi.encodeCall(INexus.initializeAccount, initData) });
        executions[1] = Execution({ target: address(executorEth), value: 0, callData: abi.encodeCall(ISuperExecutor.execute, abi.encode(entryToExecute)) });

        uint256 nonce = _getNonce(account, MODE_VALIDATION, address(0), 0);
        PackedUserOperation memory userOp = _buildPackedUserOp(address(account), nonce);
        userOp.callData = abi.encodeCall(IExecutionHelper.execute, (ModeLib.encodeSimpleBatch(), ExecLib.encodeBatch(executions)));
        userOp.sender = address(account);

        bytes32 userOpHash = ENTRYPOINT.getUserOpHash(userOp);
        userOp.signature = _createNoDestinationExecutionMerkleRootAndSignature(account, eoaKey, userOpHash, validatorEth);
        _doEIP7702(account);

       
        {
            uint256 balanceBefore = IERC20(underlyingETH_USDC).balanceOf(account);
            assertEq(balanceBefore, 1e6);
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


    //Note: leaving these 2 here for reference
    /**
    function test_CrossChain_7702() public {
        uint256 eoaKey = uint256(8);
        address account = vm.addr(eoaKey);
        vm.label(account, "Account");
        vm.deal(account, 100 ether);

        // BASE is destination chain
        _useBaseFork(1 days);
        bytes memory destinationHookData = _getDestinationMessage(account);

        // ETH is source chain
        _useEthFork(2 days);

        _getTokens(underlyingETH_USDC, account, 1e6);

        address executorEth = _createSuperExecutor();
        address validatorEth = _createSuperValidator();

        ACCOUNT_IMPLEMENTATION = new Nexus(address(ENTRYPOINT), address(validatorEth), abi.encode(address(account)));
        vm.label(address(ACCOUNT_IMPLEMENTATION), "AccountImplementation");

        bytes memory initDataEth = _getInitData(InitData({
            executor: executorEth,
            validator: validatorEth,
            signer: address(account),
            prevalidationHook: address(mockPreValidationHook),
            bootstrap: BOOTSTRAPPER,
            registry: REGISTRY
        }));

        ISuperExecutor.ExecutorEntry memory entryToExecute = _createSourceEntry(destinationHookData, validatorEth);
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({ target: account, value: 0, callData: abi.encodeCall(INexus.initializeAccount, initDataEth) });
        executions[1] = Execution({ target: address(executorEth), value: 0, callData: abi.encodeCall(ISuperExecutor.execute, abi.encode(entryToExecute)) });

        PackedUserOperation memory userOp = _createPackedUserOp(account, executions);
        bytes32 userOpHash = ENTRYPOINT.getUserOpHash(userOp);
        userOp.signature = _createCrosschainSig(CrosschainSigParams({
            userOpHash: userOpHash,
            accountToUse: account,
            dstChainId: BASE,
            srcValidator: validatorEth,
            dstValidator: address(superDestinationValidator_Base),
            dstExecutionData: destinationHookData,
            signer: account,
            signerPrivateKey: eoaKey
        }));

        _doEIP7702(account);

        vm.recordLogs();
        _executeOps(userOp);
        VmSafe.Log[] memory logs = vm.getRecordedLogs();
        ExecutionReturnData memory executionData = ExecutionReturnData({
            logs: logs
        });

        _processAcrossV3MessageWithoutDestinationAccount(
            uint64(ETH),
            uint64(BASE),
            warpStartTime + 2 days,
            executionData
        );
    }

    function test_CrossChain_7702_Initialize() public {
        uint256 eoaKey = uint256(8);
       
        address account = vm.addr(eoaKey);
        vm.label(account, "Account");
        vm.deal(account, 100 ether);
        vm.makePersistent(account);
        address executor = _createSuperExecutor();
        vm.makePersistent(executor);
        address validator = _createSuperValidator();
        vm.makePersistent(validator);
        
        ACCOUNT_IMPLEMENTATION_BASE = new Nexus(address(ENTRYPOINT), address(validator), abi.encode(address(account)));
        vm.makePersistent(address(ACCOUNT_IMPLEMENTATION_BASE));
        ACCOUNT_IMPLEMENTATION = new Nexus(address(ENTRYPOINT), address(validator), abi.encode(address(account)));
        vm.makePersistent(address(ACCOUNT_IMPLEMENTATION));
        _doEIP7702(account);

        // BASE is destination chain
        _useBaseFork(0);
  
        // initialize on base
        {
            bytes memory initDataBase = _getInitData(InitData({
                executor: address(superDestinationExecutor_Base),
                validator: address(superDestinationValidator_Base),
                signer: address(account),
                prevalidationHook: address(mockPreValidationHook_Base),
                bootstrap: BOOTSTRAPPER_BASE,
                registry: REGISTRY_BASE
            }));

            Execution[] memory executionsBase = new Execution[](1);
            executionsBase[0] = Execution({ target: account, value: 0, callData: abi.encodeCall(INexus.initializeAccount, initDataBase) });

            bytes memory userOpCalldataBase = abi.encodeCall(IExecutionHelper.execute, (ModeLib.encodeSimpleBatch(), ExecLib.encodeBatch(executionsBase)));
            uint256 nonce = _getNonce(account, MODE_VALIDATION, address(0), 0);

            // Create the userOp and add the data
            PackedUserOperation memory userOpBase = _buildPackedUserOp(address(account), nonce);
            userOpBase.callData = userOpCalldataBase;
            userOpBase.sender = address(account);

            bytes32 userOpHashBase = ENTRYPOINT.getUserOpHash(userOpBase);
            userOpBase.signature = _createNoDestinationExecutionMerkleRootAndSignature(account, eoaKey, userOpHashBase, address(validator));

            // Create userOps array
            PackedUserOperation[] memory userOpsBase = new PackedUserOperation[](1);
            userOpsBase[0] = userOpBase;

            // Send the userOp to the entrypoint
            ENTRYPOINT.handleOps(userOpsBase, payable(address(0x69)));
            console2.log("-----Account code length after etching on BASE:", account.code.length);
        }

        // ETH is source chain
        _useEthFork(2 days);
        _getTokens(underlyingETH_USDC, account, 1e6);

        bytes memory initDataEth = _getInitData(InitData({
            executor: executor,
            validator: validator,
            signer: address(account),
            prevalidationHook: address(mockPreValidationHook),
            bootstrap: BOOTSTRAPPER,
            registry: REGISTRY
        }));

        bytes memory destinationHookData = _getDestinationMessageInitialize(account);
        ISuperExecutor.ExecutorEntry memory entryToExecute = _createSourceEntry(destinationHookData, validator);
        Execution[] memory executions = new Execution[](1);
        //executions[0] = Execution({ target: account, value: 0, callData: abi.encodeCall(INexus.initializeAccount, initDataEth) });
        executions[0] = Execution({ target: address(executor), value: 0, callData: abi.encodeCall(ISuperExecutor.execute, abi.encode(entryToExecute)) });

        PackedUserOperation memory userOp = _createPackedUserOp(account, executions);
        bytes32 userOpHash = ENTRYPOINT.getUserOpHash(userOp);
        userOp.signature = _createCrosschainSig(CrosschainSigParams({
            userOpHash: userOpHash,
            accountToUse: account,
            dstChainId: BASE,
            srcValidator: validator,
            dstValidator: address(superDestinationValidator_Base),
            dstExecutionData: destinationHookData,
            signer: account,
            signerPrivateKey: eoaKey
        }));

        vm.recordLogs();
        _executeOps(userOp);
        VmSafe.Log[] memory logs = vm.getRecordedLogs();
        ExecutionReturnData memory executionData = ExecutionReturnData({
            logs: logs
        });

        _processAcrossV3MessageWithoutDestinationAccount(
            uint64(ETH),
            uint64(BASE),
            warpStartTime + 2 days,
            executionData
        );
    }
    */

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

    function _executeOps(PackedUserOperation memory userOp) internal {
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;
        ENTRYPOINT.handleOps(userOps, payable(address(0x69)));
    }
    function _createPackedUserOp(address account, Execution[] memory executions) internal view returns (PackedUserOperation memory userOp) {
        uint256 nonce = _getNonce(account, MODE_VALIDATION, address(0), 0);
        userOp = _buildPackedUserOp(address(account), nonce);
        userOp.callData = abi.encodeCall(IExecutionHelper.execute, (ModeLib.encodeSimpleBatch(), ExecLib.encodeBatch(executions)));
        userOp.sender = address(account);
    }
    function _createDestinationEntry() internal returns (ISuperExecutor.ExecutorEntry memory entryToExecute) {
        address approveERC20HookAddressBase = address(new ApproveERC20Hook());
        vm.label(approveERC20HookAddressBase, "ApproveERC20Hook-Base");
        
        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = approveERC20HookAddressBase;

        bytes[] memory hookData = new bytes[](1);
        hookData[0] =
            _createApproveHookData(underlyingBase_USDC, address(this), 1e6, false);

        entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookData });
    }
    function _getDestinationMessage(address _account) internal returns (bytes memory) {
        // get execution data
        ISuperExecutor.ExecutorEntry memory entryToExecute = _createDestinationEntry();
        bytes memory destinationExecutionData = abi.encodeWithSelector(ISuperExecutor.execute.selector, entryToExecute);

        // get cross chain init data
        bytes memory initCalldata = _getInitData(InitData({
            executor: address(superDestinationExecutor_Base),
            validator: address(superDestinationValidator_Base),
            signer: address(0),
            prevalidationHook: address(mockPreValidationHook_Base),
            bootstrap: BOOTSTRAPPER_BASE,
            registry: REGISTRY_BASE
        }));
        bytes memory initData = abi.encodeWithSelector(NexusAccountFactory.createAccount.selector, initCalldata, bytes32(keccak256("SIGNER_SALT")));
        initData = bytes.concat(abi.encodePacked(address(0)), INITCODE_EIP7702_MARKER, abi.encodePacked(address(FACTORY_BASE)), initData);
        //console2.log("super7702SenderCreator length", address(super7702SenderCreator).code.length);

        address[] memory dstTokens = new address[](1);
        dstTokens[0] = underlyingBase_USDC;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1e6;
        
        return abi.encode(initData, destinationExecutionData, _account, dstTokens, intentAmounts);
    }

    function _getDestinationMessageInitialize(address _account) internal returns (bytes memory) {
        // get execution data
        ISuperExecutor.ExecutorEntry memory entryToExecute = _createDestinationEntry();
        bytes memory destinationExecutionData = abi.encodeWithSelector(ISuperExecutor.execute.selector, entryToExecute);
        
        bytes memory initData = "";

        address[] memory dstTokens = new address[](1);
        dstTokens[0] = underlyingBase_USDC;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1e6;
        
        return abi.encode(initData, destinationExecutionData, _account, dstTokens, intentAmounts);
    }

    function _createSourceEntry(bytes memory _destinationMessage, address _validator) internal returns (ISuperExecutor.ExecutorEntry memory entryToExecute) {
        address approveERC20HookAddressEth = address(new ApproveERC20Hook());
        vm.label(approveERC20HookAddressEth, "ApproveERC20Hook-Eth");
        address acrossSendFundsAndExecuteOnDstHookAddressEth = address(new AcrossSendFundsAndExecuteOnDstHook(SPOKE_POOL_V3_ADDRESSES[ETH], _validator));
        vm.label(acrossSendFundsAndExecuteOnDstHookAddressEth, "AcrossSendFundsAndExecuteOnDstHook-Eth");

        address[] memory srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = approveERC20HookAddressEth;
        srcHooksAddresses[1] = acrossSendFundsAndExecuteOnDstHookAddressEth;

        bytes[] memory srcHooksData = new bytes[](2);
        srcHooksData[0] =
            _createApproveHookData(underlyingETH_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], 1e6, false);
        srcHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingETH_USDC, underlyingBase_USDC, 1e6, 1e6, BASE, true, _destinationMessage
        );
        entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: srcHooksAddresses, hooksData: srcHooksData });
    }

    function _createSuperDestinationExecutor() internal returns (address superDestinationExecutor) {
      // install a new SuperDestinationExecutor (so we can uninstall the old one) 
        // -- create
        ISuperLedgerConfiguration superLedgerConfigurationNew =
                ISuperLedgerConfiguration(address(new SuperLedgerConfiguration{ salt: "Test123" }()));
        vm.label(address(superLedgerConfigurationNew), "NewSuperLedgerConfiguration");

        ISuperDestinationExecutor superDestinationExecutorNew = ISuperDestinationExecutor(address(new SuperDestinationExecutor{ salt: "Test123" }(address(superLedgerConfigurationNew), address(superDestinationValidator_Base), address(FACTORY_BASE))));
        vm.label(address(superDestinationExecutorNew), "NewSuperDestinationExecutor");

        return address(superDestinationExecutorNew);
    }

    function _createSuperExecutor() internal returns (address superExecutor) {
      // install a new SuperExecutor (so we can uninstall the old one) 
        // -- create
        ISuperLedgerConfiguration superLedgerConfigurationNew =
                ISuperLedgerConfiguration(address(new SuperLedgerConfiguration()));
        vm.label(address(superLedgerConfigurationNew), "NewSuperLedgerConfiguration");
        ISuperExecutor superExecutorNew = ISuperExecutor(address(new SuperExecutor(address(superLedgerConfigurationNew))));
        vm.label(address(superExecutorNew), "NewSuperExecutor");

        // -- configure ledger
        address[] memory allowedExecutors = new address[](1);
        allowedExecutors[0] = address(superExecutorNew);
        ISuperLedger superLedgerNew = ISuperLedger(
            address(new SuperLedger(address(superLedgerConfigurationNew), allowedExecutors))
        );

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
        return address(new SuperMerkleValidator());
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
    }
    function _createCrosschainSig(
        CrosschainSigParams memory params
    )
        internal
        view
        returns (bytes memory sig)
    {
        MerkleContext memory ctx;

        ctx.validUntil = uint48(block.timestamp + 100 days);
        ctx.executionData = params.dstExecutionData;

        ctx.leaves = new bytes32[](2);
        ctx.dstTokens = new address[](1);
        ctx.dstTokens[0] = underlyingBase_USDC;
        ctx.intentAmounts = new uint256[](1);
        ctx.intentAmounts[0] = 1e6;

        ctx.leaves[0] = _createDestinationValidatorLeaf(
            ctx.executionData,
            params.dstChainId,
            params.accountToUse,
            address(superDestinationExecutor_Base),
            ctx.dstTokens,
            ctx.intentAmounts,
            ctx.validUntil,
            params.dstValidator
        );
        ctx.leaves[1] = _createSourceValidatorLeaf(params.userOpHash, ctx.validUntil, true, params.srcValidator);

        (ctx.merkleProof, ctx.merkleRoot) = _createValidatorMerkleTree(ctx.leaves);

        ctx.signature = _createSignature(
            "SuperValidator",
            ctx.merkleRoot,
            params.signer,
            params.signerPrivateKey
        );

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        ISuperValidator.DstInfo memory dstInfo = ISuperValidator.DstInfo({
            data: ctx.executionData,
            executor: address(superDestinationExecutor_Base),
            dstTokens: ctx.dstTokens,
            intentAmounts: ctx.intentAmounts,
            account: params.accountToUse,
            validator: params.dstValidator
        });
        proofDst[0] = ISuperValidator.DstProof({ proof: ctx.merkleProof[0], dstChainId: params.dstChainId, info: dstInfo });


        sig = _createSignatureData_DestinationExecutor(
            true, ctx.validUntil, ctx.merkleRoot, ctx.merkleProof[1], proofDst, ctx.signature
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

    struct InitData{
        address executor;
        address validator;
        address signer;
        address prevalidationHook;
        NexusBootstrap bootstrap;
        MockRegistry registry;
    }
    function _prepareBootstrapConfigs(InitData memory initData) internal pure returns (
        BootstrapConfig[] memory validators,
        BootstrapConfig[] memory executors,
        BootstrapConfig memory hook,
        BootstrapConfig[] memory fallbacks,
        BootstrapPreValidationHookConfig[] memory preValidationHooks
    ) {
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
            MODULE_TYPE_PREVALIDATION_HOOK_ERC4337,
            initData.prevalidationHook,
            ""
        );
    }
    function _createRegistryConfig(InitData memory initData) internal view returns (RegistryConfig memory config) {
        return RegistryConfig({
            registry: initData.registry,
            attesters: ATTESTERS,
            threshold: THRESHOLD
        });
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

    function _getNonce(address account, bytes1 vMode, address validator, bytes3 batchId) internal view returns (uint256 nonce) {
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