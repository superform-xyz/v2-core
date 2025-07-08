// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import { SafeFactory } from "modulekit/accounts/safe/SafeFactory.sol";
import { ISafe7579Launchpad, ModuleInit } from "modulekit/accounts/safe/interfaces/ISafe7579Launchpad.sol";
import { ISafe7579 } from "modulekit/accounts/safe/interfaces/ISafe7579.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_VALIDATOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

import { Safe } from "@safe/Safe.sol";
import { ISafe } from "@safe/interfaces/ISafe.sol";
import { SafeProxy } from "@safe/proxies/SafeProxy.sol";
import { SignMessageLib } from "@safe/libraries/SignMessageLib.sol";
import { SafeProxyFactory } from "@safe/proxies/SafeProxyFactory.sol";

// Superform
import { MerkleTreeHelper } from "../../utils/MerkleTreeHelper.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { SuperDestinationValidator } from "../../../src/validators/SuperDestinationValidator.sol";

contract MultisigOwnerValidationTest is MerkleTreeHelper, RhinestoneModuleKit {
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

    SafeFactory public factory;

    SuperDestinationValidator public validator;
    bytes public validSigData;

    DestinationData public approveDestinationData;
    DestinationData public transferDestinationData;
    DestinationData public depositDestinationData;

    uint256 public executorNonce;

    uint256 public privateKey1;
    uint256 public privateKey2;

    address public owner1;
    address public owner2;

    ISafe7579 public safe7579;
    address public safeSmartAccount;

    SafeProxy public safeProxy;
    address public safeMultisig;

    SafeProxy public straightMultisig;
    address public straightMultisigAddress;

    AccountInstance public instance;
    address public companionAccount;

    bytes4 public constant VALID_SIGNATURE = bytes4(0x5c2ec0f3);

    function setUp() public {
        validator = new SuperDestinationValidator();

        (owner1, privateKey1) = makeAddrAndKey("alice");
        (owner2, privateKey2) = makeAddrAndKey("bob");

        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;

        // Deploy Safe smart account
        safeSmartAccount = _deploySafeSmartAccount(owners);
        safe7579 = ISafe7579(safeSmartAccount);

        // Deploy Safe proxy (multisig that will use companion accout)
        Safe singleton = new Safe();
        SafeProxyFactory proxyFactory = new SafeProxyFactory();

        safeProxy = proxyFactory.createProxyWithNonce(address(singleton), "", 999);
        safeMultisig = address(safeProxy);

        instance = makeAccountInstance(keccak256(abi.encode("acc1")));
        companionAccount = instance.account;

        bytes memory moduleData = abi.encode(safeMultisig);
        instance.installModule({ moduleTypeId: MODULE_TYPE_VALIDATOR, module: address(validator), data: moduleData });
        assertEq(validator.getAccountOwner(companionAccount), safeMultisig);

        // Deploy Safe proxy (multisig without 7570 modules)
        straightMultisig = proxyFactory.createProxyWithNonce(address(singleton), "", 200);
        straightMultisigAddress = address(straightMultisig);
        console2.log("straightMultisigAddress", straightMultisigAddress);

        executorNonce = 0;
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/
    function test_Multisig_With_CompanionAccount_SignatureValidation() public {
        uint48 validUntil = uint48(block.timestamp + 5 hours);

        console2.log("companionAccount", companionAccount);

        // simulate a merkle tree with 3 leaves (3 user ops)
        bytes32[] memory leaves = new bytes32[](3);
    }

    function test_Multisig7579_SignatureValidation_ViaConcat() public {
        uint48 validUntil = uint48(block.timestamp + 5 hours);

        approveDestinationData = _createApproveDestinationData(executorNonce, safeSmartAccount);
        transferDestinationData = _createTransferDestinationData(executorNonce, safeSmartAccount);
        depositDestinationData = _createDepositDestinationData(executorNonce, safeSmartAccount);

        // simulate a merkle tree with 3 leaves (3 user ops)
        bytes32[] memory leaves = new bytes32[](3);

        leaves[0] = _createDestinationValidatorLeaf(
            approveDestinationData.callData,
            approveDestinationData.chainId,
            approveDestinationData.sender,
            approveDestinationData.executor,
            approveDestinationData.dstTokens,
            approveDestinationData.intentAmounts,
            validUntil,
            address(validator)
        );
        leaves[1] = _createDestinationValidatorLeaf(
            transferDestinationData.callData,
            transferDestinationData.chainId,
            transferDestinationData.sender,
            transferDestinationData.executor,
            transferDestinationData.dstTokens,
            transferDestinationData.intentAmounts,
            validUntil,
            address(validator)
        );
        leaves[2] = _createDestinationValidatorLeaf(
            depositDestinationData.callData,
            depositDestinationData.chainId,
            depositDestinationData.sender,
            depositDestinationData.executor,
            depositDestinationData.dstTokens,
            depositDestinationData.intentAmounts,
            validUntil,
            address(validator)
        );

        (bytes32[][] memory proof, bytes32 root) = _createValidatorMerkleTree(leaves);

        bytes memory signature = _makeSignatureViaConcat(root);

        vm.prank(safeSmartAccount);
        validator.onInstall(abi.encode(safeSmartAccount));

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);

        ISuperValidator.DstInfo memory dstInfo = ISuperValidator.DstInfo({
            data: approveDestinationData.callData,
            executor: approveDestinationData.executor,
            dstTokens: approveDestinationData.dstTokens,
            intentAmounts: approveDestinationData.intentAmounts,
            account: approveDestinationData.sender,
            validator: address(validator)
        });
        proofDst[0] = ISuperValidator.DstProof({ proof: proof[0], dstChainId: uint64(block.chainid), info: dstInfo });

        bytes memory sigDataRaw = abi.encode(
            false, // isEthSignedMessage
            validUntil,
            root,
            proof,
            proofDst,
            signature
        );

        bytes memory destinationRaw = abi.encode(
            approveDestinationData.callData,
            approveDestinationData.chainId,
            approveDestinationData.sender,
            approveDestinationData.executor,
            approveDestinationData.dstTokens,
            approveDestinationData.intentAmounts
        );

        bytes4 rv = validator.isValidDestinationSignature(safeSmartAccount, abi.encode(sigDataRaw, destinationRaw));

        assertEq(rv, VALID_SIGNATURE);
    }

    function test_MutlisigOnly_Validation() public {
        uint48 validUntil = uint48(block.timestamp + 5 hours);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _deploySafeSmartAccount(address[] memory owners) internal returns (address account) {
        factory = new SafeFactory();
        factory.init(); // deploys singleton + proxy-factory

        ModuleInit[] memory validators = new ModuleInit[](1);

        validators[0] = ModuleInit({ module: address(validator), initData: "" });

        ISafe7579Launchpad.InitData memory initData = ISafe7579Launchpad.InitData({
            singleton: address(0),
            owners: owners,
            threshold: 2,
            setupTo: address(0),
            setupData: "",
            safe7579: ISafe7579(address(0)),
            validators: validators,
            callData: ""
        });

        bytes memory initCode = abi.encode(initData);
        bytes32 salt = keccak256("SAFE-1279-TEST");

        account = factory.createAccount(salt, initCode);
    }

    function _createValidatorLeaf(
        DestinationData memory destinationData,
        uint48 validUntil,
        address _validator
    )
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
                        validUntil,
                        _validator
                    )
                )
            )
        );
    }

    function _makeSignatureViaConcat(bytes32 root) private view returns (bytes memory) {
        bytes memory message = abi.encode(validator.namespace(), root);

        bytes32 SAFE_MESSAGE_TYPEHASH = 0x0f9ff3595466d2c304e2d88e1058190e8b7eb1cc1e81286209d4ed6199986368;

        bytes32 structHash = keccak256(abi.encode(SAFE_MESSAGE_TYPEHASH, keccak256(message)));

        bytes32 safeHash = keccak256(
            abi.encodePacked(bytes1(0x19), bytes1(0x01), ISafe(payable(safeSmartAccount)).domainSeparator(), structHash)
        );

        // sign with each owner key
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(privateKey1, safeHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(privateKey2, safeHash);

        bytes memory sig1 = abi.encodePacked(r1, s1, v1);
        bytes memory sig2 = abi.encodePacked(r2, s2, v2);

        // concat in ascending owner address order (Safe requirement)
        bytes memory signature = owner1 < owner2 ? bytes.concat(sig1, sig2) : bytes.concat(sig2, sig1);

        // check if the signature is valid
        bytes4 magic = IERC1271(safeSmartAccount).isValidSignature(safeHash, signature);
        assertEq(magic, bytes4(0x1626ba7e), "Safe rejected the signature blob");

        return signature;
    }

    function _makeSignatureViaApproveHash(bytes32 root) private returns (bytes memory) {
        // each owner approves the hash once
        vm.prank(owner1);
        ISafe(payable(safeProxy)).approveHash(root);

        vm.prank(owner2);
        ISafe(payable(safeProxy)).approveHash(root);

        // now call validator with empty sigs
        bytes memory signatures = "";

        return signatures;
    }

    function _createApproveDestinationData(
        uint256 nonce,
        address signerAddr
    )
        private
        view
        returns (DestinationData memory)
    {
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

    function _createTransferDestinationData(
        uint256 nonce,
        address signerAddr
    )
        private
        view
        returns (DestinationData memory)
    {
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

    function _createDepositDestinationData(
        uint256 nonce,
        address signerAddr
    )
        private
        view
        returns (DestinationData memory)
    {
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

    function _testDestinationDataValidation(
        address signerAddr,
        uint48 validUntil,
        bytes32 root,
        bytes32[] memory proof,
        bytes memory signature,
        DestinationData memory destinationData
    )
        private
        view
    {
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);

        ISuperValidator.DstInfo memory dstInfo = ISuperValidator.DstInfo({
            data: destinationData.callData,
            executor: destinationData.executor,
            dstTokens: destinationData.dstTokens,
            intentAmounts: destinationData.intentAmounts,
            account: destinationData.sender,
            validator: address(validator)
        });
        proofDst[0] = ISuperValidator.DstProof({ proof: proof, dstChainId: uint64(block.chainid), info: dstInfo });
        bytes memory sigDataRaw = abi.encode(false, validUntil, root, proof, proofDst, signature);

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
}
