// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import "modulekit/accounts/common/lib/ModeLib.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { INexus } from "../src/vendor/nexus/INexus.sol";
import { INexusFactory } from "../src/vendor/nexus/INexusFactory.sol";
import { BootstrapConfig, INexusBoostrap } from "../src/vendor/nexus/INexusBootstrap.sol";
import { IERC7484 } from "../src/vendor/nexus/IERC7484.sol";

// Superform
import { IMinimalEntryPoint, PackedUserOperation } from "../src/vendor/account-abstraction/IMinimalEntryPoint.sol";
import { ISuperExecutor } from "../src/core/interfaces/ISuperExecutor.sol";

import { SuperExecutor } from "../src/core/executors/SuperExecutor.sol";
import "./BaseTest.t.sol";

contract BaseE2ETest is BaseTest {
    SuperMerkleValidator superMerkleValidator;
    INexusFactory nexusFactory;
    INexusBoostrap nexusBootstrap;
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
    

    function _executeThroughEntrypoint(
        address account,
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
        PackedUserOperation memory userOp = _createPackedUserOperation(account, nonce, callData);

        // create validator merkle tree & get signature data
        uint48 validUntil = uint48(block.timestamp + 1 hours);
        bytes32[] memory leaves = _createLeaves(userOp, validUntil);
        (bytes32[] memory proof, bytes32 root) = _createTree(leaves);
        bytes memory signature = _getSignature(root);   
        bytes memory sigData = abi.encode(validUntil, root, proof, signature);
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
    function _createLeaves(PackedUserOperation memory userOp, uint48 validUntil) private view returns (bytes32[] memory leaves) {
        PackedUserOperation[] memory userOps = new PackedUserOperation[](4);
        for (uint256 i; i < 4; ++i) {
            userOps[i] = userOp;
        }

        leaves = new bytes32[](4);
        for (uint256 i = 0; i < 4; i++) {
            leaves[i] = _hashUserOp(userOps[i], validUntil);
        }
    }
    function _hashUserOp(PackedUserOperation memory userOp, uint48 validUntil) private view returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(userOp.callData, userOp.gasFees, userOp.sender, userOp.nonce, validUntil, block.chainid, userOp.initCode))));
    }
    // @dev needs 4 leaves to create the merkle tree
    function _createTree(bytes32[] memory leaves) private pure returns (bytes32[] memory proof, bytes32 root) {
        bytes32[] memory level1 = new bytes32[](2);
        level1[0] = _hashPair(leaves[0], leaves[1]); 
        level1[1] = _hashPair(leaves[2], leaves[3]); 

        root = _hashPair(level1[0], level1[1]);

        proof = new bytes32[](2);
        proof[0] = leaves[1];      
        proof[1] = level1[1];      
      
        return (proof, root);
    }

    function _getSignature(bytes32 root) private view returns (bytes memory) {
        bytes32 messageHash = keccak256(abi.encode(superMerkleValidator.namespace(), root));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrvKey, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }
}
