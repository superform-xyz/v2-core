// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { BaseTest } from "../../BaseTest.t.sol";
import { SuperMerkleValidator } from "../../../src/validators/SuperMerkleValidator.sol";
import { IERC7579Account } from "../../../lib/modulekit/src/accounts/common/interfaces/IERC7579Account.sol";
import { ModeCode } from "../../../lib/modulekit/src/accounts/common/lib/ModeLib.sol";
import { Execution } from "../../../lib/modulekit/src/accounts/common/interfaces/IERC7579Account.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import "forge-std/console2.sol";

contract POC_IncorrectValidUntilTest is BaseTest {
    function test_POC_IncorrectValidUntilHandling() public {
        // Select fork for testing
        vm.selectFork(FORKS[ETH]);

        // Setup - Create new User contract instance
        User user = new User();
        vm.label(address(user), "User");
        vm.makePersistent(address(user));

        // Get validator address
        address validator = _getContract(ETH, SUPER_MERKLE_VALIDATOR_KEY);
        console2.log("--------- test validator", validator);

        uint256 privateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address signer = vm.addr(privateKey);

        // Initialize validator for user
        vm.startPrank(address(user));
        SuperMerkleValidator(validator).onInstall(abi.encode(signer));

        // Create merkle tree data
        bytes32[] memory leaves = new bytes32[](1);
        bytes32 userOpHash = keccak256("test");
        leaves[0] = keccak256(bytes.concat(keccak256(abi.encode(userOpHash, uint48(0), false, address(validator)))));

        // Create merkle tree using _createValidatorMerkleTree
        (bytes32[][] memory proofs, bytes32 root) = _createValidatorMerkleTree(leaves);

        // Create and sign the message hash using the correct format
        bytes32 messageHash = keccak256(abi.encode("SuperValidator", root)); // Use root as merkleRoot

        bytes memory signature = _signMessage(messageHash, privateKey);

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        // Pack the signature data with validUntil = 0
        bytes memory sigDataRaw = abi.encode(
            false,
            uint48(0), // validUntil = 0 should mean infinite validity
            root, // merkleRoot
            proofs[0], // proofSrc
            proofDst, // proofDst
            signature
        );

        // Try to validate the signature
        // This should return 0x1626ba7e (VALID_SIGNATURE) and now will succeed with the correct signature format
        bytes4 result = SuperMerkleValidator(validator).isValidSignatureWithSender(
            address(user), userOpHash, abi.encode(sigDataRaw)
        );

        // The validation should succeed now that we use the correct signature format
        assertEq(result, bytes4(0x1626ba7e), "Signature validation should succeed with correct format and validUntil=0");

        vm.stopPrank();
    }

    function _signMessage(bytes32 messageHash, uint256 privateKey) internal pure returns (bytes memory) {
        // Use the correct Ethereum message hash format that the validator expects
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(abi.encode(messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }
}

contract User is IERC7579Account {
    mapping(uint256 => mapping(address => bool)) private installedModules;

    function execute(ModeCode, bytes calldata executionCalldata) external payable {
        // Just forward the execution
        (bool success,) = address(this).call(executionCalldata);
        require(success, "User: execution failed");
    }

    function executeFromExecutor(
        ModeCode,
        bytes calldata executionCalldata
    )
        external
        payable
        returns (bytes[] memory returnData)
    {
        // Execute the call
        (bool success, bytes memory result) = address(this).call(executionCalldata);
        require(success, "User: execution failed");

        // Return the result in an array
        returnData = new bytes[](1);
        returnData[0] = result;
        return returnData;
    }

    function installModule(uint256 moduleTypeId, address module, bytes calldata) external payable {
        installedModules[moduleTypeId][module] = true;
        emit ModuleInstalled(moduleTypeId, module);
    }

    function uninstallModule(uint256 moduleTypeId, address module, bytes calldata) external payable {
        installedModules[moduleTypeId][module] = false;
        emit ModuleUninstalled(moduleTypeId, module);
    }

    function isModuleInstalled(uint256 moduleTypeId, address module, bytes calldata) external view returns (bool) {
        return installedModules[moduleTypeId][module];
    }

    function isValidSignature(bytes32, bytes calldata) external pure returns (bytes4) {
        return 0x1626ba7e; // Magic value for EIP-1271
    }

    function supportsExecutionMode(ModeCode) external pure returns (bool) {
        return true; // Support all execution modes for testing
    }

    function supportsModule(uint256) external pure returns (bool) {
        return true; // Support all module types for testing
    }

    function accountId() external pure returns (string memory) {
        return "TestUser"; // Simple ID for testing
    }

    receive() external payable { }
}
