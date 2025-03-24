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
import { SuperMerkleValidator } from "../../../src/core/validators/SuperMerkleValidator.sol";

import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";

import { MerkleReader } from "../../utils/merkle/helper/MerkleReader.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SuperMerkleValidatorTest is BaseTest, MerkleReader {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    IERC4626 public vaultInstance;
    ISuperExecutor public superExecutor;
    AccountInstance public instance;
    address public account;

    SuperMerkleValidator public validator;
    bytes public validSigData;

    UserOpData approveUserOp;
    UserOpData transferUserOp;
    UserOpData depositUserOp;
    UserOpData withdrawUserOp;

    uint256 privateKey;
    address signerAddr;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);
        superExecutor = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));

        validator = SuperMerkleValidator(_getContract(ETH, SUPER_MERKLE_VALIDATOR_KEY));

        (signerAddr, privateKey) = makeAddrAndKey("The signer");
        vm.label(signerAddr, "The signer");

        instance = accountInstances[ETH];
        account = instance.account;
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(address(signerAddr))
        });
        assertEq(validator.getAccountOwner(account), signerAddr);

        approveUserOp = _createDummyApproveUserOp();
        transferUserOp = _createDummyTransferUserOp();
        depositUserOp = _createDummyDepositUserOp();
        withdrawUserOp = _createDummyWithdrawUserOp();
    }

    function test_Dummy_OnChainMerkleTree() public pure {
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
        leaves[0] = _createValidatorLeaf(approveUserOp, validUntil);
        leaves[1] = _createValidatorLeaf(transferUserOp, validUntil);
        leaves[2] = _createValidatorLeaf(approveUserOp, validUntil);
        leaves[3] = _createValidatorLeaf(transferUserOp, validUntil);

        (bytes32[][] memory proof, bytes32 root) = _createTree(leaves);

        bool isValid = MerkleProof.verify(proof[0], root, leaves[0]);
        assertTrue(isValid, "Merkle proof should be valid");
    }

    function test_ValidateUserOp() public {
        uint48 validUntil = uint48(block.timestamp + 1 hours);

        // simulate a merkle tree with 4 leaves (4 user ops)
        bytes32[] memory leaves = new bytes32[](4);
        leaves[0] = _createValidatorLeaf(approveUserOp, validUntil);
        leaves[1] = _createValidatorLeaf(transferUserOp, validUntil);
        leaves[2] = _createValidatorLeaf(depositUserOp, validUntil);
        leaves[3] = _createValidatorLeaf(withdrawUserOp, validUntil);

        (bytes32[][] memory proof, bytes32 root) = _createTree(leaves);

        bytes memory signature = _getSignature(root);

        // validate first user op
        _testUserOpValidation(validUntil, root, proof[0], signature, approveUserOp);

        // validate second user op
        _testUserOpValidation(validUntil, root, proof[1], signature, transferUserOp);

        // validate third user op
        _testUserOpValidation(validUntil, root, proof[2], signature, depositUserOp);

        // validate fourth user op
        _testUserOpValidation(validUntil, root, proof[3], signature, withdrawUserOp);
    }

    function test_ExpiredSignature() public {
        uint48 validUntil = uint48(block.timestamp - 1 hours);

        // simulate a merkle tree with 4 leaves (4 user ops)
        bytes32[] memory leaves = new bytes32[](4);
        leaves[0] = _createValidatorLeaf(approveUserOp, validUntil);
        leaves[1] = _createValidatorLeaf(transferUserOp, validUntil);
        leaves[2] = _createValidatorLeaf(depositUserOp, validUntil);
        leaves[3] = _createValidatorLeaf(withdrawUserOp, validUntil);

        (bytes32[][] memory proof, bytes32 root) = _createTree(leaves);

        bytes memory signature = _getSignature(root);

        validSigData = abi.encode(validUntil, root, proof[0], signature);

        approveUserOp.userOp.signature = validSigData;
        ERC7579ValidatorBase.ValidationData result = validator.validateUserOp(approveUserOp.userOp, bytes32(0));
        uint256 rawResult = ERC7579ValidatorBase.ValidationData.unwrap(result);
        bool _sigFailed = rawResult & 1 == 1;
        uint48 _validUntil = uint48(rawResult >> 160);

        assertTrue(_sigFailed, "Sig should fail");
        assertLt(_validUntil, block.timestamp, "Should not be valid");
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

    function _testUserOpValidation(
        uint48 validUntil,
        bytes32 root,
        bytes32[] memory proof,
        bytes memory signature,
        UserOpData memory userOpData
    )
        private
    {
        validSigData = abi.encode(validUntil, root, proof, signature);

        userOpData.userOp.signature = validSigData;
        ERC7579ValidatorBase.ValidationData result = validator.validateUserOp(userOpData.userOp, bytes32(0));
        uint256 rawResult = ERC7579ValidatorBase.ValidationData.unwrap(result);
        bool _sigFailed = rawResult & 1 == 1;
        uint48 _validUntil = uint48(rawResult >> 160);

        assertFalse(_sigFailed, "Sig should be valid");
        assertGt(_validUntil, block.timestamp, "validUntil should be valid");
    }

    function _createValidatorLeaf(UserOpData memory userOpData, uint48 validUntil) private view returns (bytes32) {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        userOpData.userOp.callData,
                        userOpData.userOp.gasFees,
                        userOpData.userOp.sender,
                        userOpData.userOp.nonce,
                        validUntil,
                        block.chainid,
                        userOpData.userOp.initCode
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

    function _createDummyApproveUserOp() private returns (UserOpData memory) {
        return instance.getExecOps(
            address(this),
            0,
            abi.encodeWithSelector(IERC20.approve.selector, address(this), 1e18),
            address(instance.defaultValidator)
        );
    }

    function _createDummyTransferUserOp() private returns (UserOpData memory) {
        return instance.getExecOps(
            address(this),
            0,
            abi.encodeWithSelector(IERC20.transfer.selector, address(this), 1e18),
            address(instance.defaultValidator)
        );
    }

    function _createDummyDepositUserOp() private returns (UserOpData memory) {
        return instance.getExecOps(
            address(this),
            0,
            abi.encodeWithSelector(IERC4626.deposit.selector, 1e18, address(this)),
            address(instance.defaultValidator)
        );
    }

    function _createDummyWithdrawUserOp() private returns (UserOpData memory) {
        return instance.getExecOps(
            address(this),
            0,
            abi.encodeWithSelector(IERC4626.withdraw.selector, 1e18, address(this)),
            address(instance.defaultValidator)
        );
    }
}
