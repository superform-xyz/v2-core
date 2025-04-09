// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import {
    RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, AccountType, UserOpData
} from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_VALIDATOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";
import { ERC7579ValidatorBase } from "modulekit/Modules.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Superform
import { BaseTest } from "../../BaseTest.t.sol";
import { SuperDestinationValidator } from "../../../src/core/validators/SuperDestinationValidator.sol";

import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";

import { MerkleReader } from "../../utils/merkle/helper/MerkleReader.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "forge-std/console2.sol";

contract SuperDestinationValidatorTest is BaseTest, MerkleReader {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    struct DestinationData {
        uint256 nonce;
        bytes callData;
        uint64 chainId;
        address sender;
        address executor;
    }
    struct SignatureData {
        uint48 validUntil;
        bytes32 merkleRoot;
        bytes32[] proof;
        bytes signature;
    }


    IERC4626 public vaultInstance;
    ISuperExecutor public superExecutor;
    AccountInstance public instance;
    address public account;

    SuperDestinationValidator public validator;
    bytes public validSigData;

    DestinationData approveDestinationData;
    DestinationData transferDestinationData;
    DestinationData depositDestinationData;
    DestinationData withdrawDestinationData;

    uint256 privateKey;
    address signerAddr;

    uint256 executorNonce;

    bytes4 constant VALID_SIGNATURE = bytes4(0x1626ba7e);

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);
        superExecutor = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));

        validator = SuperDestinationValidator(_getContract(ETH, SUPER_DESTINATION_VALIDATOR_KEY));
        
        signerAddr = validatorSigners[BASE];
        privateKey = validatorSignerPrivateKeys[BASE];

        instance = accountInstances[ETH];
        account = instance.account;
        assertEq(validator.getAccountOwner(account), signerAddr);

        executorNonce = 0;
        approveDestinationData = _createDummyApproveDestinationData(executorNonce);
        transferDestinationData = _createDummyTransferDestinationData(executorNonce);
        depositDestinationData = _createDummyDepositDestinationData(executorNonce);
        withdrawDestinationData = _createDummyWithdrawDestinationData(executorNonce);
    }

    function test_Dummy_OnChainMerkleTreeXX() public pure {
        bytes32[] memory leaves = new bytes32[](4);
        leaves[0] = keccak256(bytes.concat(keccak256(abi.encode("leaf 0"))));
        leaves[1] = keccak256(bytes.concat(keccak256(abi.encode("leaf 1"))));
        leaves[2] = keccak256(bytes.concat(keccak256(abi.encode("leaf 2"))));
        leaves[3] = keccak256(bytes.concat(keccak256(abi.encode("leaf 3"))));

        (bytes32[][] memory proof, bytes32 root) = _createTree(leaves);

        bool isValid = MerkleProof.verify(proof[0], root, leaves[0]);
        assertTrue(isValid, "Merkle proof for leaf 0 should be valid");

        // check 2nd leaf
        isValid = MerkleProof.verify(proof[1], root, leaves[1]);
        assertTrue(isValid, "Merkle proof for leaf 1 should be valid");

        // check 3rd leaf
        isValid = MerkleProof.verify(proof[2], root, leaves[2]);
        assertTrue(isValid, "Merkle proof for leaf 2 should be valid");

        // check 4th leaf
        isValid = MerkleProof.verify(proof[3], root, leaves[3]);
        assertTrue(isValid, "Merkle proof for leaf 3 should be valid");
    }

    function test_Dummy_OnChainMerkleTree_WithActualUserOps() public view {
        uint48 validUntil = uint48(block.timestamp + 1 hours);
        bytes32[] memory leaves = new bytes32[](4);
        leaves[0] = _createDestinationValidatorLeaf(approveDestinationData.callData, approveDestinationData.chainId, approveDestinationData.sender, approveDestinationData.nonce, approveDestinationData.executor, validUntil);
        leaves[1] = _createDestinationValidatorLeaf(transferDestinationData.callData, transferDestinationData.chainId, transferDestinationData.sender, transferDestinationData.nonce, transferDestinationData.executor, validUntil);
        leaves[2] = _createDestinationValidatorLeaf(depositDestinationData.callData, depositDestinationData.chainId, depositDestinationData.sender, depositDestinationData.nonce, depositDestinationData.executor, validUntil);
        leaves[3] = _createDestinationValidatorLeaf(withdrawDestinationData.callData, withdrawDestinationData.chainId, withdrawDestinationData.sender, withdrawDestinationData.nonce, withdrawDestinationData.executor, validUntil);

        (bytes32[][] memory proof, bytes32 root) = _createValidatorMerkleTree(leaves);

        bool isValid = MerkleProof.verify(proof[0], root, leaves[0]);
        assertTrue(isValid, "Merkle proof should be valid");
    }

    function test_IsValidSignatureWithSender() public {
        uint48 validUntil = uint48(block.timestamp + 1 hours);

        // simulate a merkle tree with 4 leaves (4 user ops)
        bytes32[] memory leaves = new bytes32[](4);
        leaves[0] = _createDestinationValidatorLeaf(approveDestinationData.callData, approveDestinationData.chainId, approveDestinationData.sender, approveDestinationData.nonce, approveDestinationData.executor, validUntil);
        leaves[1] = _createDestinationValidatorLeaf(transferDestinationData.callData, transferDestinationData.chainId, transferDestinationData.sender, transferDestinationData.nonce, transferDestinationData.executor, validUntil);
        leaves[2] = _createDestinationValidatorLeaf(depositDestinationData.callData, depositDestinationData.chainId, depositDestinationData.sender, depositDestinationData.nonce, depositDestinationData.executor, validUntil);
            leaves[3] = _createDestinationValidatorLeaf(withdrawDestinationData.callData, withdrawDestinationData.chainId, withdrawDestinationData.sender, withdrawDestinationData.nonce, withdrawDestinationData.executor, validUntil);

        (bytes32[][] memory proof, bytes32 root) = _createValidatorMerkleTree(leaves);

        bytes memory signature = _getSignature(root);

        vm.startPrank(signerAddr);
        validator.onInstall(abi.encode(signerAddr));

        // validate first execution
        _testDestinationDataValidation(validUntil, root, proof[0], signature, approveDestinationData);

        // validate second execution
        _testDestinationDataValidation(validUntil, root, proof[1], signature, transferDestinationData);

        // validate third execution
        _testDestinationDataValidation(validUntil, root, proof[2], signature, depositDestinationData);

        // validate fourth execution
        _testDestinationDataValidation(validUntil, root, proof[3], signature, withdrawDestinationData);
        vm.stopPrank();
    }

    function test_ExpiredSignature() public view {
        uint48 validUntil = uint48(block.timestamp - 1 hours);

        // simulate a merkle tree with 4 leaves (4 user ops)
        bytes32[] memory leaves = new bytes32[](4);
        leaves[0] = _createDestinationValidatorLeaf(approveDestinationData.callData, approveDestinationData.chainId, approveDestinationData.sender, approveDestinationData.nonce, approveDestinationData.executor, validUntil);
        leaves[1] = _createDestinationValidatorLeaf(transferDestinationData.callData, transferDestinationData.chainId, transferDestinationData.sender, transferDestinationData.nonce, transferDestinationData.executor, validUntil);
        leaves[2] = _createDestinationValidatorLeaf(depositDestinationData.callData, depositDestinationData.chainId, depositDestinationData.sender, depositDestinationData.nonce, depositDestinationData.executor, validUntil);
        leaves[3] = _createDestinationValidatorLeaf(withdrawDestinationData.callData, withdrawDestinationData.chainId, withdrawDestinationData.sender, withdrawDestinationData.nonce, withdrawDestinationData.executor, validUntil);

        (bytes32[][] memory proof, bytes32 root) = _createValidatorMerkleTree(leaves);

        bytes memory signature = _getSignature(root);

        bytes memory sigDataRaw = abi.encode(validUntil, root, proof[0], signature);
        bytes memory destinationDataRaw = abi.encode(approveDestinationData.nonce, approveDestinationData.callData, approveDestinationData.chainId, approveDestinationData.sender, approveDestinationData.executor);

        bytes4 validationResult = validator.isValidSignatureWithSender(signerAddr, bytes32(0), abi.encode(sigDataRaw, destinationDataRaw));

        assertEq(validationResult, bytes4(""), "Sig should be invalid");
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getSignature(bytes32 root) private view returns (bytes memory) {
        bytes32 messageHash = keccak256(abi.encode(validator.namespace(), root));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // test sig here; fail early if invalid
        address _expectedSigner = ECDSA.recover(ethSignedMessageHash, signature);
        assertEq(_expectedSigner, signerAddr, "Signature should be valid");
        return signature;
    }

    function _testDestinationDataValidation(
        uint48 validUntil,
        bytes32 root,
        bytes32[] memory proof,
        bytes memory signature,
        DestinationData memory destinationData
    )
        private 
        view
    {
        bytes memory sigDataRaw = abi.encode(validUntil, root, proof, signature);
        bytes memory destinationDataRaw = abi.encode(destinationData.nonce, destinationData.callData, destinationData.chainId, destinationData.sender, destinationData.executor);

        bytes4 validationResult = validator.isValidSignatureWithSender(signerAddr, bytes32(0), abi.encode(sigDataRaw, destinationDataRaw));
        assertEq(validationResult, VALID_SIGNATURE, "Sig should be valid");
    }

    function _createValidatorLeaf(DestinationData memory destinationData, uint48 validUntil) private view returns (bytes32) {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        destinationData.callData,
                        uint64(block.chainid),
                        destinationData.sender,
                        destinationData.nonce,
                        destinationData.executor,
                        validUntil
                    )
                )
            )
        );
    }

    function _createTree(bytes32[] memory leaves) private pure returns (bytes32[][] memory proof, bytes32 root) {
        bytes32[] memory level1 = new bytes32[](2);
        level1[0] = _hashPair(leaves[0], leaves[1]);
        level1[1] = _hashPair(leaves[2], leaves[3]);

        root = _hashPair(level1[0], level1[1]);

        proof = new bytes32[][](4);

        // Proof for leaves[0] - Sibling is leaves[1], Parent is level1[1]
        proof[0] = new bytes32[](2);
        proof[0][0] = leaves[1]; // Sibling of leaves[0]
        proof[0][1] = level1[1]; // Parent of leaves[0] and leaves[1]

        // Proof for leaves[1] - Sibling is leaves[0], Parent is level1[1]
        proof[1] = new bytes32[](2);
        proof[1][0] = leaves[0]; // Sibling of leaves[1]
        proof[1][1] = level1[1]; // Parent of leaves[0] and leaves[1]

        // Proof for leaves[2] - Sibling is leaves[3], Parent is level1[0]
        proof[2] = new bytes32[](2);
        proof[2][0] = leaves[3]; // Sibling of leaves[2]
        proof[2][1] = level1[0]; // Parent of leaves[2] and leaves[3]

        // Proof for leaves[3] - Sibling is leaves[2], Parent is level1[0]
        proof[3] = new bytes32[](2);
        proof[3][0] = leaves[2]; // Sibling of leaves[3]
        proof[3][1] = level1[0]; // Parent of leaves[2] and leaves[3]

        return (proof, root);
    }

    function _createDummyApproveDestinationData(uint256 nonce) private view returns (DestinationData memory) {
        return DestinationData(
            nonce,
            abi.encodeWithSelector(IERC20.approve.selector, address(this), 1e18),
            uint64(block.chainid),
            signerAddr,
            address(this)
        );
    }

    function _createDummyTransferDestinationData(uint256 nonce) private view returns (DestinationData memory) {
        return DestinationData(
            nonce,
            abi.encodeWithSelector(IERC20.transfer.selector, address(this), 1e18),
            uint64(block.chainid),
            signerAddr,
            address(this)
        );
    }

    function _createDummyDepositDestinationData(uint256 nonce) private view returns (DestinationData memory) {
        return DestinationData(
            nonce,
            abi.encodeWithSelector(IERC4626.deposit.selector, 1e18, address(this)),
            uint64(block.chainid),
            signerAddr,
            address(this)
        );
    }

    function _createDummyWithdrawDestinationData(uint256 nonce) private view returns (DestinationData memory) {
        return DestinationData(
            nonce,
            abi.encodeWithSelector(IERC4626.withdraw.selector, 1e18, address(this)),
            uint64(block.chainid),
            signerAddr,
            address(this)
        );
    }
}
