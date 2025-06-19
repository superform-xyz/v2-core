// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import {ModuleKitHelpers, AccountInstance, UserOpData} from "modulekit/ModuleKit.sol";
import {ExecutionLib} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Superform
import {SuperDestinationValidator} from "../../../src/core/validators/SuperDestinationValidator.sol";
import {SuperValidatorBase} from "../../../src/core/validators/SuperValidatorBase.sol";
import {ISuperSignatureStorage} from "../../../src/core/interfaces/ISuperSignatureStorage.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MerkleTreeHelper} from "../../utils/MerkleTreeHelper.sol";
import {RhinestoneModuleKit, ModuleKitHelpers, AccountInstance} from "modulekit/ModuleKit.sol";
import {MODULE_TYPE_VALIDATOR} from "modulekit/accounts/kernel/types/Constants.sol";

contract SuperDestinationValidatorTest is MerkleTreeHelper, RhinestoneModuleKit {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    struct DestinationData {
        uint256 nonce;
        bytes callData;
        uint64 chainId;
        address sender;
        address executor;
        address adapter;
        address tokenSent;
        address[] dstTokens;
        uint256[] intentAmounts;
    }

    struct SignatureData {
        uint48 validUntil;
        bytes32 merkleRoot;
        bytes32[] proof;
        bytes signature;
    }

    IERC4626 public vaultInstance;
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

    bytes4 constant VALID_SIGNATURE = bytes4(0x5c2ec0f3);

    function setUp() public {
        validator = new SuperDestinationValidator();

        (signerAddr, privateKey) = makeAddrAndKey("The signer");

        instance = makeAccountInstance(keccak256(abi.encode("TEST")));
        account = instance.account;
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(address(signerAddr))
        });
        assertEq(validator.getAccountOwner(account), signerAddr);

        executorNonce = 0;
        approveDestinationData = _createDummyApproveDestinationData(executorNonce);
        transferDestinationData = _createDummyTransferDestinationData(executorNonce);
        depositDestinationData = _createDummyDepositDestinationData(executorNonce);
        withdrawDestinationData = _createDummyWithdrawDestinationData(executorNonce);
    }

    function test_DestinationValidator_IsModuleType() public view {
        assertTrue(validator.isModuleType(MODULE_TYPE_VALIDATOR));
        assertFalse(validator.isModuleType(1234));
    }

    function test_DestinationValidator_OnInstall() public view {
        assertTrue(validator.isInitialized(account));
    }

    function test_DestinationValidator_namespace() public view {
        assertEq(validator.namespace(), "SuperValidator");
    }

    function test_DestinationValidator_GetAccountOwner() public view {
        assertEq(validator.getAccountOwner(account), address(signerAddr));
    }

    function test_DestinationValidator_OnInstall_RevertIf_AlreadyInitialized() public {
        AccountInstance memory newInstance = makeAccountInstance(keccak256(abi.encode("TEST")));
        address newAccount = newInstance.account;

        vm.startPrank(newAccount);

        vm.expectRevert(SuperValidatorBase.ALREADY_INITIALIZED.selector);
        validator.onInstall("");
        vm.stopPrank();
    }

    function test_DestinationValidator_OnUninstall() public {
        vm.startPrank(account);
        validator.onUninstall("");
        vm.stopPrank();

        assertFalse(validator.isInitialized(account));
    }

    function test_DestinationValidator_ValidateUserOp_NotImplemented() public {
        UserOpData memory userOpData = instance.getExecOps(
            address(this),
            0,
            abi.encodeWithSelector(IERC20.approve.selector, address(this), 1e18),
            address(instance.defaultValidator)
        );
        vm.expectRevert(SuperDestinationValidator.NOT_IMPLEMENTED.selector);
        validator.validateUserOp(userOpData.userOp, bytes32(0));
    }

    function test_DestinationValidator_isValidSignatureWithSender_NotImplemented() public {
        vm.expectRevert(SuperDestinationValidator.NOT_IMPLEMENTED.selector);
        validator.isValidSignatureWithSender(account, bytes32(0), "");
    }

    function test_DestinationValidator_OnUninstall_RevertIf_NotInitialized() public {
        vm.startPrank(makeAddr("account"));
        vm.expectRevert(ISuperSignatureStorage.NOT_INITIALIZED.selector);
        validator.onUninstall("");
        vm.stopPrank();
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

        leaves[0] = _createDestinationValidatorLeaf(
            approveDestinationData.callData,
            approveDestinationData.chainId,
            approveDestinationData.sender,
            approveDestinationData.executor,
            approveDestinationData.dstTokens,
            approveDestinationData.intentAmounts,
            validUntil
        );
        leaves[1] = _createDestinationValidatorLeaf(
            transferDestinationData.callData,
            transferDestinationData.chainId,
            transferDestinationData.sender,
            transferDestinationData.executor,
            transferDestinationData.dstTokens,
            transferDestinationData.intentAmounts,
            validUntil
        );
        leaves[2] = _createDestinationValidatorLeaf(
            depositDestinationData.callData,
            depositDestinationData.chainId,
            depositDestinationData.sender,
            depositDestinationData.executor,
            depositDestinationData.dstTokens,
            depositDestinationData.intentAmounts,
            validUntil
        );
        leaves[3] = _createDestinationValidatorLeaf(
            withdrawDestinationData.callData,
            withdrawDestinationData.chainId,
            withdrawDestinationData.sender,
            withdrawDestinationData.executor,
            withdrawDestinationData.dstTokens,
            withdrawDestinationData.intentAmounts,
            validUntil
        );

        (bytes32[][] memory proof, bytes32 root) = _createValidatorMerkleTree(leaves);

        bool isValid = MerkleProof.verify(proof[0], root, leaves[0]);
        assertTrue(isValid, "Merkle proof should be valid");
    }

    function test_IsValidDestinationSignature() public {
        uint48 validUntil = uint48(block.timestamp + 1 hours);

        // simulate a merkle tree with 4 leaves (4 user ops)
        bytes32[] memory leaves = new bytes32[](4);

        leaves[0] = _createDestinationValidatorLeaf(
            approveDestinationData.callData,
            approveDestinationData.chainId,
            approveDestinationData.sender,
            approveDestinationData.executor,
            approveDestinationData.dstTokens,
            approveDestinationData.intentAmounts,
            validUntil
        );
        leaves[1] = _createDestinationValidatorLeaf(
            transferDestinationData.callData,
            transferDestinationData.chainId,
            transferDestinationData.sender,
            transferDestinationData.executor,
            transferDestinationData.dstTokens,
            transferDestinationData.intentAmounts,
            validUntil
        );
        leaves[2] = _createDestinationValidatorLeaf(
            depositDestinationData.callData,
            depositDestinationData.chainId,
            depositDestinationData.sender,
            depositDestinationData.executor,
            depositDestinationData.dstTokens,
            depositDestinationData.intentAmounts,
            validUntil
        );
        leaves[3] = _createDestinationValidatorLeaf(
            withdrawDestinationData.callData,
            withdrawDestinationData.chainId,
            withdrawDestinationData.sender,
            withdrawDestinationData.executor,
            withdrawDestinationData.dstTokens,
            withdrawDestinationData.intentAmounts,
            validUntil
        );

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

    function test_ExpiredSignature() public {
        vm.warp(block.timestamp + 2 hours);
        uint48 validUntil = uint48(block.timestamp - 1 hours);

        // simulate a merkle tree with 4 leaves (4 user ops)
        bytes32[] memory leaves = new bytes32[](4);

        leaves[0] = _createDestinationValidatorLeaf(
            approveDestinationData.callData,
            approveDestinationData.chainId,
            approveDestinationData.sender,
            approveDestinationData.executor,
            approveDestinationData.dstTokens,
            approveDestinationData.intentAmounts,
            validUntil
        );
        leaves[1] = _createDestinationValidatorLeaf(
            transferDestinationData.callData,
            transferDestinationData.chainId,
            transferDestinationData.sender,
            transferDestinationData.executor,
            transferDestinationData.dstTokens,
            transferDestinationData.intentAmounts,
            validUntil
        );
        leaves[2] = _createDestinationValidatorLeaf(
            depositDestinationData.callData,
            depositDestinationData.chainId,
            depositDestinationData.sender,
            depositDestinationData.executor,
            depositDestinationData.dstTokens,
            depositDestinationData.intentAmounts,
            validUntil
        );
        leaves[3] = _createDestinationValidatorLeaf(
            withdrawDestinationData.callData,
            withdrawDestinationData.chainId,
            withdrawDestinationData.sender,
            withdrawDestinationData.executor,
            withdrawDestinationData.dstTokens,
            withdrawDestinationData.intentAmounts,
            validUntil
        );

        (bytes32[][] memory proof, bytes32 root) = _createValidatorMerkleTree(leaves);

        bytes memory signature = _getSignature(root);

        SuperValidatorBase.DstProof[] memory proofDst = new SuperValidatorBase.DstProof[](1);

        SuperValidatorBase.DstInfo memory dstInfo = SuperValidatorBase.DstInfo({
            data: approveDestinationData.callData,
            executor: approveDestinationData.executor,
            dstTokens: approveDestinationData.dstTokens,
            intentAmounts: approveDestinationData.intentAmounts,
            account: approveDestinationData.sender
        });
        proofDst[0] = SuperValidatorBase.DstProof({proof: proof[0], dstChainId: uint64(block.chainid), info: dstInfo});

        bytes memory sigDataRaw = abi.encode(validUntil, root, proof, proofDst, signature);

        bytes memory destinationDataRaw = abi.encode(
            approveDestinationData.callData,
            approveDestinationData.chainId,
            approveDestinationData.sender,
            approveDestinationData.executor,
            approveDestinationData.dstTokens,
            approveDestinationData.intentAmounts
        );

        vm.startPrank(signerAddr);
        validator.onInstall(abi.encode(signerAddr));
        vm.stopPrank();
        bytes4 validationResult =
            validator.isValidDestinationSignature(signerAddr, abi.encode(sigDataRaw, destinationDataRaw));

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
    ) private view {

        SuperValidatorBase.DstProof[] memory proofDst = new SuperValidatorBase.DstProof[](1);

        SuperValidatorBase.DstInfo memory dstInfo = SuperValidatorBase.DstInfo({
            data: destinationData.callData,
            executor: destinationData.executor,
            dstTokens: destinationData.dstTokens,
            intentAmounts: destinationData.intentAmounts,
            account: destinationData.sender
        });
        proofDst[0] = SuperValidatorBase.DstProof({proof: proof, dstChainId: uint64(block.chainid), info: dstInfo});
        bytes memory sigDataRaw = abi.encode(validUntil, root, proof, proofDst, signature);

        bytes memory destinationDataRaw = abi.encode(
            destinationData.callData,
            destinationData.chainId,
            destinationData.sender,
            destinationData.executor,
            destinationData.dstTokens,
            destinationData.intentAmounts
        );

        bytes4 validationResult =
            validator.isValidDestinationSignature(signerAddr, abi.encode(sigDataRaw, destinationDataRaw));
        assertEq(validationResult, VALID_SIGNATURE, "Sig should be valid");
    }

    function _createValidatorLeaf(DestinationData memory destinationData, uint48 validUntil)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        destinationData.callData,
                        uint64(block.chainid),
                        destinationData.sender,
                        destinationData.nonce,
                        destinationData.executor,
                        destinationData.dstTokens,
                        destinationData.intentAmounts,
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
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = address(this);
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1e18;
        return DestinationData(
            nonce,
            abi.encodeWithSelector(IERC20.approve.selector, address(this), 1e18),
            uint64(block.chainid),
            signerAddr,
            address(this),
            address(this),
            address(this),
            dstTokens,
            intentAmounts
        );
    }

    function _createDummyTransferDestinationData(uint256 nonce) private view returns (DestinationData memory) {
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = address(this);
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1e18;
        return DestinationData(
            nonce,
            abi.encodeWithSelector(IERC20.transfer.selector, address(this), 1e18),
            uint64(block.chainid),
            signerAddr,
            address(this),
            address(this),
            address(this),
            dstTokens,
            intentAmounts
        );
    }

    function _createDummyDepositDestinationData(uint256 nonce) private view returns (DestinationData memory) {
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = address(this);
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1e18;
        return DestinationData(
            nonce,
            abi.encodeWithSelector(IERC4626.deposit.selector, 1e18, address(this)),
            uint64(block.chainid),
            signerAddr,
            address(this),
            address(this),
            address(this),
            dstTokens,
            intentAmounts
        );
    }

    function _createDummyWithdrawDestinationData(uint256 nonce) private view returns (DestinationData memory) {
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = address(this);
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1e18;
        return DestinationData(
            nonce,
            abi.encodeWithSelector(IERC4626.withdraw.selector, 1e18, address(this)),
            uint64(block.chainid),
            signerAddr,
            address(this),
            address(this),
            address(this),
            dstTokens,
            intentAmounts
        );
    }
}
