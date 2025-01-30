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

// Superform
import { BaseTest } from "../../BaseTest.t.sol";
import { SuperMerkleValidator } from "../../../src/core/validators/SuperMerkleValidator.sol";

import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";

import { console2 } from "forge-std/console2.sol";

contract SuperMerkleValidatorTest is BaseTest {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    IERC4626 public vaultInstance;
    ISuperExecutor public superExecutor;
    AccountInstance public instance;
    address public account;
    address public underlying;
    address public yieldSourceAddress;

    SuperMerkleValidator public validator;
    bytes public dummyData;
    UserOpData public dummyUserOp;
    bytes public dummySigData;
    bytes public validSigData;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);
        underlying = existingUnderlyingTokens[1][USDC_KEY];
        yieldSourceAddress = realVaultAddresses[1][ERC4626_VAULT_KEY][MORPHO_VAULT_KEY][USDC_KEY];
        vaultInstance = IERC4626(yieldSourceAddress);
        superExecutor = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));

        validator = SuperMerkleValidator(_getContract(ETH, SUPER_MERKLE_VALIDATOR_KEY));

        instance = accountInstances[ETH];
        account = instance.account;
        instance.installModule({ moduleTypeId: MODULE_TYPE_VALIDATOR, module: address(validator), data: "" });

        dummyData = abi.encode(address(this));
        dummyUserOp = instance.getExecOps(
            address(this),
            0,
            abi.encodeWithSelector(IERC20.approve.selector, address(this), 1e18),
            address(instance.defaultValidator)
        );
        dummySigData = bytes("1234");
    }

    function test_GivenTheSignatureIsInvalid() external {
        // it should return validation failure
        vm.expectRevert();
        validator.validateUserOp(dummyUserOp.userOp, bytes32(0));
    }

    modifier givenTheSignatureIsValid(uint256 timestamp) {
        uint48 validUntil = uint48(timestamp); // 1 hour valid
        bytes32 merkleRoot = keccak256(abi.encodePacked("validMerkleRoot"));
        bytes32 leaf = keccak256(
            abi.encodePacked(
                address(this),
                dummyUserOp.userOp.nonce,
                dummyUserOp.userOp.callData,
                dummyUserOp.userOp.accountGasLimits
            )
        );
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = keccak256(
            abi.encodePacked(
                address(this),
                dummyUserOp.userOp.nonce,
                dummyUserOp.userOp.callData,
                dummyUserOp.userOp.accountGasLimits
            )
        );

        bytes32 messageHash =
            keccak256(abi.encode(validator.namespace(), merkleRoot, leaf, address(this), dummyUserOp.userOp.nonce));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(uint160(address(this))), ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        validSigData = abi.encode(validUntil, merkleRoot, proof, signature);
        _;
    }

    function test_WhenTimestampIsExpired() external givenTheSignatureIsValid(block.timestamp - 1 hours) {
        dummyUserOp.userOp.signature = validSigData;
        validator.validateUserOp(dummyUserOp.userOp, bytes32(0));
        // it should return validation failure
    }

    function test_WhenTimestampIsValid() external givenTheSignatureIsValid(block.timestamp + 1 hours) {
        dummyUserOp.userOp.signature = validSigData;
        ERC7579ValidatorBase.ValidationData result = validator.validateUserOp(dummyUserOp.userOp, bytes32(0));

        uint256 rawResult = ERC7579ValidatorBase.ValidationData.unwrap(result);
        bool sigFailed = (rawResult >> 255) & 1 == 1;
        uint48 validUntil = uint48(rawResult >> 160);

        assertFalse(sigFailed);
        assertGt(validUntil, block.timestamp);
    }

    function test_ValidSignatureWithActualData(uint256 amount) external {
        // valid amount
        amount = _bound(amount);

        // get tokens for deposit
        _getTokens(underlying, account, amount);

        // hooks
        address[] memory hooksAddresses = new address[](2);
        address approveHook = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        address depositHook = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = depositHook;

        // hooks data
        bytes[] memory hooksData = new bytes[](2);
        bytes memory approveData = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        bytes memory depositData = _createDepositHookData(
            account, bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, amount, false, false
        );

        hooksData[0] = approveData;
        hooksData[1] = depositData;

        uint256 sharesPreviewed = vaultInstance.previewDeposit(amount);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));

        // merkle proof
        //  -- leaf
        bytes32 leaf = keccak256(
            abi.encodePacked(
                account, userOpData.userOp.nonce, userOpData.userOp.callData, userOpData.userOp.accountGasLimits
            )
        );

        //  -- proof
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = keccak256(
            abi.encodePacked(
                account, userOpData.userOp.nonce, userOpData.userOp.callData, userOpData.userOp.accountGasLimits
            )
        );

        // -- root
        bytes32 merkleRoot = proof[0];

        {
            uint48 validUntil = uint48(block.timestamp + 1 hours);
            bytes32 messageHash =
                keccak256(abi.encode(validator.namespace(), merkleRoot, leaf, account, userOpData.userOp.nonce));
            bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(uint160(account)), ethSignedMessageHash);
            bytes memory signature = abi.encodePacked(r, s, v);

            validSigData = abi.encode(validUntil, merkleRoot, proof, signature);
            userOpData.userOp.signature = validSigData;

            ERC7579ValidatorBase.ValidationData result = validator.validateUserOp(userOpData.userOp, bytes32(0));
            uint256 rawResult = ERC7579ValidatorBase.ValidationData.unwrap(result);
            bool _sigFailed = (rawResult >> 255) & 1 == 1;
            uint48 _validUntil = uint48(rawResult >> 160);

            assertFalse(_sigFailed);
            assertGt(_validUntil, block.timestamp);
        }
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstance.balanceOf(account);
        assertEq(accSharesAfter, sharesPreviewed);
    }
}
