// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC7579Account } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {
    IModule,
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_VALIDATOR
} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { CALLTYPE_BATCH, CallType, ModeCode, ModeLib } from "modulekit/accounts/common/lib/ModeLib.sol";
import { Execution, ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockHook } from "../../mocks/MockHook.sol";
import { AcrossV3AdapterV2Simulations } from "../../mocks/simulationHelpers/AcrossV3AdapterV2Simulations.sol";
import {
    SuperDestinationExecutorSimulations
} from "../../mocks/simulationHelpers/SuperDestinationExecutorSimulations.sol";
import {
    SuperDestinationValidatorSimulations
} from "../../mocks/simulationHelpers/SuperDestinationValidatorSimulations.sol";

import { DestinationSimulationTestBase, RejectingEIP1271Owner } from "./DestinationSimulationTestBase.sol";

contract ExecutingERC7579Account is IERC7579Account {
    error MODULE_NOT_INSTALLED();
    error UNSUPPORTED_EXECUTION_MODE();

    mapping(uint256 moduleTypeId => mapping(address module => bool installed)) private _installedModules;

    receive() external payable { }

    function execute(ModeCode mode, bytes calldata executionCalldata) external payable {
        _execute(mode, executionCalldata);
    }

    function executeFromExecutor(
        ModeCode mode,
        bytes calldata executionCalldata
    )
        external
        payable
        returns (bytes[] memory returnData)
    {
        if (!_installedModules[MODULE_TYPE_EXECUTOR][msg.sender]) revert MODULE_NOT_INSTALLED();
        return _execute(mode, executionCalldata);
    }

    function installModule(uint256 moduleTypeId, address module, bytes calldata initData) external payable {
        _installedModules[moduleTypeId][module] = true;
        IModule(module).onInstall(initData);
        emit ModuleInstalled(moduleTypeId, module);
    }

    function uninstallModule(uint256 moduleTypeId, address module, bytes calldata deInitData) external payable {
        _installedModules[moduleTypeId][module] = false;
        IModule(module).onUninstall(deInitData);
        emit ModuleUninstalled(moduleTypeId, module);
    }

    function isModuleInstalled(uint256 moduleTypeId, address module, bytes calldata) external view returns (bool) {
        return _installedModules[moduleTypeId][module];
    }

    function isValidSignature(bytes32, bytes calldata) external pure returns (bytes4) {
        return 0x1626ba7e;
    }

    function supportsExecutionMode(ModeCode encodedMode) external pure returns (bool) {
        return ModeCode.unwrap(encodedMode) == ModeCode.unwrap(ModeLib.encodeSimpleBatch());
    }

    function supportsModule(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_EXECUTOR;
    }

    function accountId() external pure returns (string memory) {
        return "superform.test.executing-account.1.0.0";
    }

    function _execute(
        ModeCode mode,
        bytes calldata executionCalldata
    )
        private
        returns (bytes[] memory returnData)
    {
        CallType callType = ModeLib.getCallType(mode);
        if (
            CallType.unwrap(callType) != CallType.unwrap(CALLTYPE_BATCH)
                || ModeCode.unwrap(mode) != ModeCode.unwrap(ModeLib.encodeSimpleBatch())
        ) {
            revert UNSUPPORTED_EXECUTION_MODE();
        }

        Execution[] calldata executions = ExecutionLib.decodeBatch(executionCalldata);
        uint256 length = executions.length;
        returnData = new bytes[](length);

        for (uint256 i; i < length; ++i) {
            (bool success, bytes memory result) =
                executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            if (!success) {
                assembly ("memory-safe") {
                    revert(add(result, 0x20), mload(result))
                }
            }
            returnData[i] = result;
        }
    }
}

contract HookLifecycleTarget {
    uint256 public callCount;
    address public lastCaller;

    function execute() external {
        ++callCount;
        lastCaller = msg.sender;
    }
}

contract AcrossDestinationExecutionE2ETest is DestinationSimulationTestBase {
    uint256 internal constant AMOUNT = 1_000_000;
    bytes32 internal constant ROOT = keccak256("strict-across-destination-e2e-root");

    address internal adapterAddress;
    address internal executorAddress;
    address internal validatorAddress;
    address internal spokePool;

    AcrossV3AdapterV2Simulations internal adapter;
    SuperDestinationExecutorSimulations internal executor;
    SuperDestinationValidatorSimulations internal validator;
    ExecutingERC7579Account internal account;
    HookLifecycleTarget internal lifecycleTarget;
    MockHook internal hook;
    MockERC20 internal token;

    function setUp() public {
        adapterAddress = makeAddr("strictAcrossAdapter");
        executorAddress = makeAddr("strictDestinationExecutor");
        validatorAddress = makeAddr("strictDestinationValidator");
        spokePool = makeAddr("acrossSpokePool");

        token = new MockERC20("Mock Token", "MOCK", 18);
        lifecycleTarget = new HookLifecycleTarget();
        hook = new MockHook(ISuperHook.HookType.NONACCOUNTING, address(token));

        vm.etch(validatorAddress, type(SuperDestinationValidatorSimulations).runtimeCode);
        validator = SuperDestinationValidatorSimulations(validatorAddress);

        vm.etch(executorAddress, type(SuperDestinationExecutorSimulations).runtimeCode);
        vm.store(executorAddress, bytes32(uint256(0)), bytes32(uint256(1)));
        vm.store(executorAddress, bytes32(uint256(2)), bytes32(uint256(uint160(makeAddr("ledgerConfiguration")))));
        vm.store(executorAddress, bytes32(uint256(3)), bytes32(uint256(uint160(validatorAddress))));
        executor = SuperDestinationExecutorSimulations(executorAddress);

        account = new ExecutingERC7579Account();
        RejectingEIP1271Owner owner = new RejectingEIP1271Owner();
        account.installModule(MODULE_TYPE_VALIDATOR, validatorAddress, abi.encode(address(owner)));
        account.installModule(MODULE_TYPE_EXECUTOR, executorAddress, bytes(""));

        Execution[] memory hookExecutions = new Execution[](1);
        hookExecutions[0] = Execution({
            target: address(lifecycleTarget), value: 0, callData: abi.encodeCall(HookLifecycleTarget.execute, ())
        });
        hook.setExecutions(hookExecutions);

        AcrossV3AdapterV2Simulations adapterImplementation =
            new AcrossV3AdapterV2Simulations(spokePool, executorAddress);
        vm.etch(adapterAddress, address(adapterImplementation).code);
        adapter = AcrossV3AdapterV2Simulations(adapterAddress);
    }

    function test_StateOverriddenAcrossRuntimeCompletesDestinationHookLifecycle() public {
        bytes memory executorCalldata = _executorCalldata();
        bytes memory sigData = _signatureData(
            address(account),
            executorAddress,
            _singleAddress(address(token)),
            _singleUint(AMOUNT),
            executorCalldata,
            uint64(block.chainid),
            ROOT
        );
        token.mint(adapterAddress, AMOUNT);

        vm.prank(spokePool);
        adapter.handleV3AcrossMessage(address(token), AMOUNT, makeAddr("relayer"), abi.encode(bytes(""), sigData));

        assertEq(token.balanceOf(address(account)), AMOUNT);
        assertEq(token.balanceOf(adapterAddress), 0);
        assertTrue(hook.preExecuteCalled());
        assertTrue(hook.postExecuteCalled());
        assertEq(lifecycleTarget.callCount(), 1);
        assertEq(lifecycleTarget.lastCaller(), address(account));
        assertTrue(executor.isMerkleRootUsed(address(account), ROOT));
        assertTrue(executor.isInitialized(address(account)));
        assertTrue(validator.isInitialized(address(account)));
    }

    function _executorCalldata() private view returns (bytes memory) {
        address[] memory hooks = new address[](1);
        hooks[0] = address(hook);
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = hex"01";

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: hooksData });
        return abi.encodeCall(ISuperExecutor.execute, (abi.encode(entry)));
    }
}
