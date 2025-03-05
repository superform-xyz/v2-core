// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import "modulekit/accounts/common/lib/ModeLib.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { INexus } from "../src/vendor/nexus/INexus.sol";
import { INexusFactory } from "../src/vendor/nexus/INexusFactory.sol";
import { BootstrapConfig, INexusBoostrap } from "../src/vendor/nexus/INexusBootstrap.sol";
import { IERC7484 } from "../src/vendor/nexus/IERC7484.sol";

// Superform
import { IMinimalEntryPoint, PackedUserOperation } from "../src/vendor/account-abstraction/IMinimalEntryPoint.sol";
import { ISuperExecutor } from "../src/core/interfaces/ISuperExecutor.sol";

import { SuperExecutor } from "../src/core/executors/SuperExecutor.sol";
import { MockValidatorModule } from "./mocks/MockValidatorModule.sol";
import "./BaseTest.t.sol";

contract BaseE2ETest is BaseTest {
    MockValidatorModule mockValidatorModule;
    INexusFactory nexusFactory;
    INexusBoostrap nexusBootstrap;
    SuperExecutor superExecutorModule;

    bytes32 initSalt;

    function setUp() public virtual override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        initSalt = keccak256(abi.encode("test"));

        mockValidatorModule = new MockValidatorModule();
        vm.label(address(mockValidatorModule), "MockValidatorModule");
        nexusFactory = INexusFactory(CHAIN_1_NEXUS_FACTORY);
        vm.label(address(nexusFactory), "NexusFactory");
        nexusBootstrap = INexusBoostrap(CHAIN_1_NEXUS_BOOTSTRAP);
        vm.label(address(nexusBootstrap), "NexusBootstrap");

        superExecutorModule = SuperExecutor(_getContract(ETH, "SuperExecutor"));
    }
    /*//////////////////////////////////////////////////////////////
                                 TOKENS METHODS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                                 ACCOUNT CREATION METHODS
    //////////////////////////////////////////////////////////////*/
    function _createWithNexus(
        address registry,
        address[] memory attesters,
        uint8 threshold
    )
        internal
        returns (address)
    {
        bytes memory initData = _getNexusInitData(registry, attesters, threshold);
        //bytes memory factoryData = abi.encodeWithSelector(nexusFactory.createAccount.selector, initData, initSalt);

        address computedAddress = nexusFactory.computeAccountAddress(initData, initSalt);
        address deployedAddress = nexusFactory.createAccount{ value: 1 ether }(initData, initSalt);

        if (deployedAddress != computedAddress) revert("Nexus SCA addresses mismatch");
        return computedAddress;
    }

    function _getNexusInitData(
        address registry,
        address[] memory attesters,
        uint8 threshold
    )
        internal
        view
        returns (bytes memory)
    {
        // create validators
        BootstrapConfig[] memory validators = new BootstrapConfig[](1);
        validators[0] = BootstrapConfig({ module: address(mockValidatorModule), data: "" });

        // create executors
        BootstrapConfig[] memory executors = new BootstrapConfig[](1);
        executors[0] = BootstrapConfig({ module: address(superExecutorModule), data: "" });

        // create hooks
        BootstrapConfig memory hook = BootstrapConfig({ module: address(0), data: "" });

        // create fallbacks
        BootstrapConfig[] memory fallbacks = new BootstrapConfig[](0);

        return nexusBootstrap.getInitNexusCalldata(
            validators, executors, hook, fallbacks, IERC7484(registry), attesters, threshold
        );
    }

    /*//////////////////////////////////////////////////////////////
                                USER OPERATION METHODS
    //////////////////////////////////////////////////////////////*/
    function _executeThroughEntrypoint(
        address account,
        bytes memory signature,
        ISuperExecutor.ExecutorEntry memory entry
    )
        internal
    {
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: address(superExecutorModule),
            value: 0,
            callData: abi.encodeWithSelector(ISuperExecutor.execute.selector, abi.encode(entry))
        });

        bytes memory callData = _prepareExecutionCalldata(executions);
        uint256 nonce = _prepareNonce(account);
        PackedUserOperation memory userOp = _createPackedUserOperation(account, nonce, callData, signature);

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;
        IMinimalEntryPoint(ENTRYPOINT_ADDR).handleOps(userOps, payable(account));
    }

    function _prepareExecutionCalldata(Execution[] memory executions)
        internal
        pure
        returns (bytes memory executionCalldata)
    {
        ModeCode mode;
        uint256 length = executions.length;

        if (length == 1) {
            mode = ModeLib.encodeSimpleSingle();
            executionCalldata = abi.encodeCall(
                INexus.execute,
                (mode, ExecutionLib.encodeSingle(executions[0].target, executions[0].value, executions[0].callData))
            );
        } else if (length > 1) {
            mode = ModeLib.encodeSimpleBatch();
            executionCalldata = abi.encodeCall(INexus.execute, (mode, ExecutionLib.encodeBatch(executions)));
        } else {
            revert("Executions array cannot be empty");
        }
    }

    function _prepareNonce(address account) internal view returns (uint256 nonce) {
        uint192 nonceKey;
        address validator = address(mockValidatorModule);
        bytes32 batchId = bytes3(0);
        bytes1 vMode = MODE_VALIDATION;
        assembly {
            nonceKey := or(shr(88, vMode), validator)
            nonceKey := or(shr(64, batchId), nonceKey)
        }
        nonce = IMinimalEntryPoint(ENTRYPOINT_ADDR).getNonce(account, nonceKey);
    }

    function _createPackedUserOperation(
        address account,
        uint256 nonce,
        bytes memory callData,
        bytes memory signature
    )
        internal
        pure
        returns (PackedUserOperation memory)
    {
        return PackedUserOperation({
            sender: account,
            nonce: nonce,
            initCode: "", //we assume contract is already deployed (following the Bundler flow)
            callData: callData,
            accountGasLimits: bytes32(abi.encodePacked(uint128(3e6), uint128(1e6))),
            preVerificationGas: 3e5,
            gasFees: bytes32(abi.encodePacked(uint128(3e5), uint128(1e7))),
            paymasterAndData: "",
            signature: signature
        });
    }
}
