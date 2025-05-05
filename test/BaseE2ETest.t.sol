// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import "modulekit/accounts/common/lib/ModeLib.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { INexus } from "../src/vendor/nexus/INexus.sol";
import { INexusFactory } from "../src/vendor/nexus/INexusFactory.sol";
import { BootstrapConfig, INexusBootstrap } from "../src/vendor/nexus/INexusBootstrap.sol";
import { IERC7484 } from "../src/vendor/nexus/IERC7484.sol";

// Superform
import { IMinimalEntryPoint, PackedUserOperation } from "../src/vendor/account-abstraction/IMinimalEntryPoint.sol";
import { ISuperExecutor } from "../src/core/interfaces/ISuperExecutor.sol";

import { SuperExecutor } from "../src/core/executors/SuperExecutor.sol";
import "./BaseTest.t.sol";

contract BaseE2ETest is BaseTest {
    SuperMerkleValidator superMerkleValidator;
    INexusFactory nexusFactory;
    INexusBootstrap nexusBootstrap;
    SuperExecutor superExecutorModule;

    bytes32 initSalt;

    address signer;
    uint256 signerPrvKey;

    function setUp() public virtual override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        (signer, signerPrvKey) = makeAddrAndKey("signer");

        initSalt = keccak256(abi.encode("test"));

        superMerkleValidator = new SuperMerkleValidator();
        vm.label(address(superMerkleValidator), "SuperMerkleValidator");
        nexusFactory = INexusFactory(CHAIN_1_NEXUS_FACTORY);
        vm.label(address(nexusFactory), "NexusFactory");
        nexusBootstrap = INexusBootstrap(CHAIN_1_NEXUS_BOOTSTRAP);
        vm.label(address(nexusBootstrap), "NexusBootstrap");

        superExecutorModule = SuperExecutor(_getContract(ETH, "SuperExecutor"));
    }

    /*//////////////////////////////////////////////////////////////
                                 ACCOUNT CREATION METHODS
    //////////////////////////////////////////////////////////////*/
    function _createWithNexus(
        address registry,
        address[] memory attesters,
        uint8 threshold,
        uint256 value
    )
        internal
        returns (address)
    {
        bytes memory initData = _getNexusInitData(registry, attesters, threshold);

        address computedAddress = nexusFactory.computeAccountAddress(initData, initSalt);
        address deployedAddress = nexusFactory.createAccount{ value: value }(initData, initSalt);

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
        validators[0] = BootstrapConfig({ module: address(superMerkleValidator), data: abi.encode(signer) });

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

    function _executeThroughEntrypoint(address account, ISuperExecutor.ExecutorEntry memory entry) internal {
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: address(superExecutorModule),
            value: 0,
            callData: abi.encodeWithSelector(ISuperExecutor.execute.selector, abi.encode(entry))
        });

        bytes memory callData = _prepareExecutionCalldata(executions);
        uint256 nonce = _prepareNonce(account);
        PackedUserOperation memory userOp = _createPackedUserOperation(account, nonce, callData);

        // create validator merkle tree & get signature data
        uint48 validUntil = uint48(block.timestamp + 1 hours);
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _createSourceValidatorLeaf(IMinimalEntryPoint(ENTRYPOINT_ADDR).getUserOpHash(userOp), validUntil);
        (bytes32[][] memory proof, bytes32 root) = _createValidatorMerkleTree(leaves);
        bytes memory signature = _getSignature(root);
        bytes memory sigData = abi.encode(validUntil, root, proof[0], proof[0], signature);
        // -- replace signature with validator signature
        userOp.signature = sigData;

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
        address validator = address(superMerkleValidator);
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
        bytes memory callData
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
            signature: hex"1234"
        });
    }

    /*//////////////////////////////////////////////////////////////
                                VALIDATOR HELPER METHODS
    //////////////////////////////////////////////////////////////*/
    function _getSignature(bytes32 root) private view returns (bytes memory) {
        bytes32 messageHash = keccak256(abi.encode(superMerkleValidator.namespace(), root));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrvKey, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }
}
