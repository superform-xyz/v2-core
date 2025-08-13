// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseTest } from "../../../BaseTest.t.sol";
import { CircleGatewayWalletHook } from "../../../../src/hooks/bridges/circle/CircleGatewayWalletHook.sol";
import { CircleGatewayMinterHook } from "../../../../src/hooks/bridges/circle/CircleGatewayMinterHook.sol";
import { ISuperHook, ISuperHookResult } from "../../../../src/interfaces/ISuperHook.sol";

// Test mocks
import { MockERC20 } from "../../../mocks/MockERC20.sol";

// Circle Gateway
import { TransferSpecLib, TransferSpec } from "evm-gateway/lib/TransferSpecLib.sol";
import {
    AttestationLib,
    Attestation,
    AttestationSet
} from "evm-gateway/lib/AttestationLib.sol";

/// @title CircleGatewayUnitTests
/// @author Superform Labs
/// @notice Unit tests for Circle Gateway hooks
contract CircleGatewayUnitTests is BaseTest {
    /*//////////////////////////////////////////////////////////////
                                CONTRACTS
    //////////////////////////////////////////////////////////////*/

    CircleGatewayWalletHook public walletHook;
    CircleGatewayMinterHook public minterHook;
    MockGatewayWallet public mockGatewayWallet;
    MockGatewayMinter public mockGatewayMinter;
    MockERC20 public mockToken;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address public constant ACCOUNT = address(0x123);
    uint256 public constant DEPOSIT_AMOUNT = 1000e6; // 1000 USDC
    uint256 public constant MINT_AMOUNT = 500e6; // 500 USDC

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();

        // Deploy mock contracts
        mockToken = new MockERC20("Mock USDC", "USDC", 6);
        mockGatewayWallet = new MockGatewayWallet();
        mockGatewayMinter = new MockGatewayMinter(address(mockToken));

        // Deploy hooks
        walletHook = new CircleGatewayWalletHook(address(mockGatewayWallet));
        minterHook = new CircleGatewayMinterHook(address(mockGatewayMinter));

        // Setup initial balances
        mockToken.mint(ACCOUNT, DEPOSIT_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                        CIRCLE GATEWAY WALLET TESTS
    //////////////////////////////////////////////////////////////*/

    function test_WalletHook_BuildExecutions_WithFixedAmount() public view {
        // Prepare hook data: token, amount, usePrevHookAmount=false
        bytes memory hookData = abi.encodePacked(
            address(mockToken), // token (20 bytes)
            DEPOSIT_AMOUNT, // amount (32 bytes)
            false // usePrevHookAmount (1 byte)
        );

        // Build executions using the public build method
        Execution[] memory executions = walletHook.build(address(0), ACCOUNT, hookData);

        // Should have 6 executions: preExecute, approve(0), approve(amount), deposit, approve(0), postExecute
        assertEq(executions.length, 6, "Should have 6 executions");

        // Check second execution (index 1): approve(0)
        assertEq(executions[1].target, address(mockToken), "Second target should be token");
        assertEq(executions[1].value, 0, "Second value should be 0");
        bytes memory expectedApprove0 = abi.encodeCall(IERC20.approve, (address(mockGatewayWallet), 0));
        assertEq(executions[1].callData, expectedApprove0, "Second execution should approve 0");

        // Check third execution (index 2): approve(amount)
        assertEq(executions[2].target, address(mockToken), "Third target should be token");
        assertEq(executions[2].value, 0, "Third value should be 0");
        bytes memory expectedApproveAmount =
            abi.encodeCall(IERC20.approve, (address(mockGatewayWallet), DEPOSIT_AMOUNT));
        assertEq(executions[2].callData, expectedApproveAmount, "Third execution should approve amount");

        // Check fourth execution (index 3): deposit
        assertEq(executions[3].target, address(mockGatewayWallet), "Fourth target should be gateway wallet");
        assertEq(executions[3].value, 0, "Fourth value should be 0");
        bytes memory expectedDeposit = abi.encodeCall(MockGatewayWallet.deposit, (address(mockToken), DEPOSIT_AMOUNT));
        assertEq(executions[3].callData, expectedDeposit, "Fourth execution should deposit");
    }

    function test_WalletHook_BuildExecutions_WithPrevHookAmount() public {
        // Create mock previous hook that returns an amount
        MockPrevHook mockPrevHook = new MockPrevHook(MINT_AMOUNT);

        // Prepare hook data: token, amount, usePrevHookAmount=true
        bytes memory hookData = abi.encodePacked(
            address(mockToken), // token (20 bytes)
            DEPOSIT_AMOUNT, // amount (32 bytes, will be overridden)
            true // usePrevHookAmount (1 byte)
        );

        // Build executions using the public build method
        Execution[] memory executions = walletHook.build(address(mockPrevHook), ACCOUNT, hookData);

        // Should use the amount from previous hook (execution at index 2 is approve(amount))
        bytes memory expectedApproveAmount = abi.encodeCall(IERC20.approve, (address(mockGatewayWallet), MINT_AMOUNT));
        assertEq(executions[2].callData, expectedApproveAmount, "Should use prev hook amount");

        bytes memory expectedDeposit = abi.encodeCall(MockGatewayWallet.deposit, (address(mockToken), MINT_AMOUNT));
        assertEq(executions[3].callData, expectedDeposit, "Should deposit prev hook amount");
    }

    function test_WalletHook_DecodeUsePrevHookAmount_True() public view {
        bytes memory hookData = abi.encodePacked(
            address(mockToken), // token (20 bytes)
            DEPOSIT_AMOUNT, // amount (32 bytes)
            true // usePrevHookAmount (1 byte)
        );

        bool result = walletHook.decodeUsePrevHookAmount(hookData);
        assertTrue(result, "Should decode true");
    }

    function test_WalletHook_DecodeUsePrevHookAmount_False() public view {
        bytes memory hookData = abi.encodePacked(
            address(mockToken), // token (20 bytes)
            DEPOSIT_AMOUNT, // amount (32 bytes)
            false // usePrevHookAmount (1 byte)
        );

        bool result = walletHook.decodeUsePrevHookAmount(hookData);
        assertFalse(result, "Should decode false");
    }

    function test_WalletHook_DecodeUsePrevHookAmount_ShortData() public {
        // Data shorter than expected position
        bytes memory hookData = abi.encodePacked(
            address(mockToken), // token (20 bytes)
            DEPOSIT_AMOUNT // amount (32 bytes) - missing bool
        );

        // This will cause an out-of-bounds error, so expect revert
        vm.expectRevert();
        walletHook.decodeUsePrevHookAmount(hookData);
    }

    function test_WalletHook_DecodeAmount() public view {
        bytes memory hookData = abi.encodePacked(
            address(mockToken), // token (20 bytes)
            DEPOSIT_AMOUNT, // amount (32 bytes)
            true // usePrevHookAmount (1 byte)
        );

        uint256 result = walletHook.decodeAmount(hookData);
        assertEq(result, DEPOSIT_AMOUNT, "Should decode correct amount");
    }

    function test_WalletHook_DecodeToken() public view {
        bytes memory hookData = abi.encodePacked(
            address(mockToken), // token (20 bytes)
            DEPOSIT_AMOUNT, // amount (32 bytes)
            true // usePrevHookAmount (1 byte)
        );

        address result = walletHook.decodeToken(hookData);
        assertEq(result, address(mockToken), "Should decode correct token");
    }

    function test_WalletHook_RevertZeroAddress() public {
        bytes memory hookData = abi.encodePacked(
            address(0), // invalid token
            DEPOSIT_AMOUNT, // amount (32 bytes)
            false // usePrevHookAmount (1 byte)
        );

        vm.expectRevert(abi.encodeWithSignature("ADDRESS_NOT_VALID()"));
        walletHook.build(address(0), ACCOUNT, hookData);
    }

    function test_WalletHook_RevertZeroAmount() public {
        bytes memory hookData = abi.encodePacked(
            address(mockToken), // token (20 bytes)
            uint256(0), // zero amount
            false // usePrevHookAmount (1 byte)
        );

        vm.expectRevert(abi.encodeWithSignature("AMOUNT_NOT_VALID()"));
        walletHook.build(address(0), ACCOUNT, hookData);
    }

    /*//////////////////////////////////////////////////////////////
                        CIRCLE GATEWAY MINTER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MinterHook_DecodeAttestationData_Valid() public view {
        // Create valid attestation data
        bytes memory attestationPayload = hex"deadbeef"; // 4 bytes
        bytes memory signature = new bytes(65); // 65 bytes signature

        bytes memory hookData = abi.encodePacked(
            uint256(attestationPayload.length), // payload length (32 bytes)
            attestationPayload, // payload (4 bytes)
            uint256(signature.length), // signature length (32 bytes)
            signature // signature (65 bytes)
        );

        (bytes memory decodedPayload, bytes memory decodedSignature) = minterHook.decodeAttestationData(hookData);

        assertEq(decodedPayload, attestationPayload, "Should decode correct payload");
        assertEq(decodedSignature, signature, "Should decode correct signature");
    }

    function test_MinterHook_DecodeAttestationData_RevertShortData() public {
        // Data too short (less than 64 bytes)
        bytes memory hookData = hex"deadbeef"; // Only 4 bytes

        vm.expectRevert(abi.encodeWithSignature("INVALID_DATA_LENGTH()"));
        minterHook.decodeAttestationData(hookData);
    }

    function test_MinterHook_DecodeAttestationData_RevertInsufficientDataForPayload() public {
        // Claims 100 bytes payload but only has 10 bytes total after length
        bytes memory hookData = abi.encodePacked(
            uint256(100), // claims 100 bytes payload
            hex"deadbeef", // only 4 bytes
            uint256(65) // signature length
        );

        vm.expectRevert(abi.encodeWithSignature("INVALID_DATA_LENGTH()"));
        minterHook.decodeAttestationData(hookData);
    }

    function test_MinterHook_DecodeAttestationData_RevertInsufficientDataForSignature() public {
        // Has payload but insufficient signature length
        bytes memory attestationPayload = hex"deadbeef"; // 4 bytes
        bytes memory shortSignature = new bytes(10); // Only 10 bytes

        bytes memory hookData = abi.encodePacked(
            uint256(attestationPayload.length), // payload length (32 bytes)
            attestationPayload, // payload (4 bytes)
            uint256(shortSignature.length), // signature length (32 bytes)
            shortSignature // short signature (10 bytes)
        );

        vm.expectRevert(abi.encodeWithSignature("INVALID_DATA_LENGTH()"));
        minterHook.decodeAttestationData(hookData);
    }

    function test_MinterHook_BuildExecutions_ValidData() public view {
        // Create valid attestation data using the helper function
        bytes memory hookData = _createValidAttestationDataWithCaller(address(mockToken), ACCOUNT);

        // Build executions using the public build method
        Execution[] memory executions = minterHook.build(address(0), ACCOUNT, hookData);

        // Should have 3 executions: preExecute, gatewayMint, postExecute
        assertEq(executions.length, 3, "Should have 3 executions");
        assertEq(executions[1].target, address(mockGatewayMinter), "Target should be gateway minter");
        assertEq(executions[1].value, 0, "Value should be 0");

        // Decode the attestation data to get the actual payload and signature
        (bytes memory attestationPayload, bytes memory signature) = minterHook.decodeAttestationData(hookData);
        bytes memory expectedCalldata = abi.encodeCall(MockGatewayMinter.gatewayMint, (attestationPayload, signature));
        assertEq(executions[1].callData, expectedCalldata, "Should call gatewayMint with correct data");
    }

    function test_MinterHook_BuildExecutions_RevertEmptyPayload() public {
        // Empty attestation payload
        bytes memory hookData = abi.encodePacked(
            uint256(0), // empty payload
            uint256(65), // signature length
            new bytes(65) // valid signature
        );

        vm.expectRevert(abi.encodeWithSignature("INVALID_DATA_LENGTH()"));
        minterHook.build(address(0), ACCOUNT, hookData);
    }

    function test_MinterHook_BuildExecutions_RevertEmptySignature() public {
        // Valid payload but empty signature (will fail on our enhanced validation)
        bytes memory hookData = abi.encodePacked(
            uint256(4), // payload length
            hex"deadbeef", // payload
            uint256(0), // signature length
            new bytes(0) // empty signature
        );

        // Our enhanced validation catches this as INVALID_DATA_LENGTH
        vm.expectRevert(abi.encodeWithSignature("INVALID_DATA_LENGTH()"));
        minterHook.build(address(0), ACCOUNT, hookData);
    }

    /*//////////////////////////////////////////////////////////////
                        DESTINATION CALLER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ValidateDestinationCaller_ValidCaller() public view {
        // Test with valid destination caller that matches the account
        bytes memory hookData = _createValidAttestationDataWithCaller(address(mockToken), ACCOUNT);

        // This should not revert when the destination caller matches the account
        minterHook.build(address(0), ACCOUNT, hookData);
    }

    function test_ValidateDestinationCaller_InvalidCaller() public {
        // Test with invalid destination caller that doesn't match the account
        address differentAccount = address(0x456);
        bytes memory hookData = _createValidAttestationDataWithCaller(address(mockToken), differentAccount);

        // This should revert when the destination caller doesn't match the account
        vm.expectRevert(abi.encodeWithSignature("INVALID_DESTINATION_CALLER()"));
        minterHook.build(address(0), ACCOUNT, hookData);
    }

    function test_ValidateDestinationCaller_ZeroAddressCaller() public view {
        // Test with zero address destination caller
        bytes memory hookData = _createValidAttestationDataWithCaller(address(mockToken), address(0));

        // This should not revert when the destination caller is zero address
        minterHook.build(address(0), ACCOUNT, hookData);
    }

    function test_ValidateDestinationCaller_CallerNotAccount() public {
        // Test with destination caller not equal to account
        address differentAccount = address(0x456);
        bytes memory hookData = _createValidAttestationDataWithCaller(address(mockToken), differentAccount);

        vm.expectRevert(abi.encodeWithSignature("INVALID_DESTINATION_CALLER()"));
        minterHook.build(address(0), ACCOUNT, hookData);
    }

    function test_ValidateDestinationCaller_ZeroAddressAccount() public {
        // Test with zero address account but non-zero destination caller
        address differentAccount = address(0x456);
        bytes memory hookData = _createValidAttestationDataWithCaller(address(mockToken), differentAccount);

        // This should revert when the account is zero address but destination caller is not
        vm.expectRevert(abi.encodeWithSignature("INVALID_DESTINATION_CALLER()"));
        minterHook.build(address(0), address(0), hookData);
    }

    function test_ValidateDestinationCaller_BothZeroAddress() public view {
        // Test with both zero address destination caller and account
        bytes memory hookData = _createValidAttestationDataWithCaller(address(mockToken), address(0));

        // This should not revert when both are zero address
        minterHook.build(address(0), address(0), hookData);
    }

    function test_ValidateDestinationCaller_DifferentValidAddresses() public {
        // Test with two different valid addresses
        address caller1 = address(0x111);
        address caller2 = address(0x222);
        bytes memory hookData = _createValidAttestationDataWithCaller(address(mockToken), caller1);

        // This should revert when the destination caller doesn't match the account
        vm.expectRevert(abi.encodeWithSignature("INVALID_DESTINATION_CALLER()"));
        minterHook.build(address(0), caller2, hookData);
    }

    function test_ValidateDestinationCaller_IntegrationWithBuild() public view {
        // Test that _validateDestinationCaller is properly integrated with the build function
        bytes memory hookData = _createValidAttestationDataWithCaller(address(mockToken), ACCOUNT);

        // Build should succeed when destination caller matches account
        Execution[] memory executions = minterHook.build(address(0), ACCOUNT, hookData);
        assertEq(executions.length, 3, "Should have 3 executions");
    }

    function test_ValidateDestinationCaller_IntegrationWithPreExecute() public {
        // Test that _validateDestinationCaller is called during preExecute
        bytes memory hookData = _createValidAttestationDataWithCaller(address(mockToken), ACCOUNT);

        // Set up execution context
        minterHook.setExecutionContext(ACCOUNT);

        // preExecute should succeed when destination caller matches account
        vm.prank(ACCOUNT);
        minterHook.preExecute(address(0), ACCOUNT, hookData);

        // Verify the asset was set correctly
        assertEq(minterHook.asset(), address(mockToken), "Should set asset to token address");
    }

    function test_ValidateDestinationCaller_IntegrationWithPostExecute() public {
        // Test that _validateDestinationCaller is called during postExecute
        bytes memory hookData = _createValidAttestationDataWithCaller(address(mockToken), ACCOUNT);

        // Set up execution context
        minterHook.setExecutionContext(ACCOUNT);

        // Call preExecute first to set up initial state
        vm.prank(ACCOUNT);
        minterHook.preExecute(address(0), ACCOUNT, hookData);

        // postExecute should succeed when destination caller matches account
        vm.prank(ACCOUNT);
        minterHook.postExecute(address(0), ACCOUNT, hookData);

        // Verify the outAmount was set
        assertEq(minterHook.getOutAmount(ACCOUNT), 0, "Should set outAmount to 0 (no minting occurred)");
    }

    /*//////////////////////////////////////////////////////////////
                            EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_WalletHook_LargeAmount() public view {
        uint256 largeAmount = type(uint256).max;

        bytes memory hookData = abi.encodePacked(address(mockToken), largeAmount, false);

        Execution[] memory executions = walletHook.build(address(0), ACCOUNT, hookData);

        // Should handle large amounts correctly
        assertEq(executions.length, 6, "Should have 6 executions");

        bytes memory expectedApprove = abi.encodeCall(IERC20.approve, (address(mockGatewayWallet), largeAmount));
        assertEq(executions[2].callData, expectedApprove, "Should approve large amount");
    }

    function test_MinterHook_LargeAttestationPayload() public view {
        // Create large attestation payload
        bytes memory largePayload = new bytes(10_000);
        bytes memory signature = new bytes(65);

        bytes memory hookData =
            abi.encodePacked(uint256(largePayload.length), largePayload, uint256(signature.length), signature);

        (bytes memory decodedPayload, bytes memory decodedSignature) = minterHook.decodeAttestationData(hookData);

        assertEq(decodedPayload.length, 10_000, "Should handle large payload");
        assertEq(decodedSignature.length, 65, "Should decode signature correctly");
    }

    function test_MinterHook_MinimumValidData() public view {
        // Minimum valid data: 1 byte payload + 65 byte signature
        bytes memory minPayload = hex"ff";
        bytes memory signature = new bytes(65);

        bytes memory hookData =
            abi.encodePacked(uint256(minPayload.length), minPayload, uint256(signature.length), signature);

        (bytes memory decodedPayload, bytes memory decodedSignature) = minterHook.decodeAttestationData(hookData);

        assertEq(decodedPayload, minPayload, "Should decode minimum payload");
        assertEq(decodedSignature, signature, "Should decode signature");
    }

    /*//////////////////////////////////////////////////////////////
                                FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_WalletHook_DecodeUsePrevHookAmount(uint8 boolByte, uint256 dataLength) public view {
        // Bound data length to reasonable range, ensuring minimum length for valid data
        dataLength = bound(dataLength, 53, 1000); // Minimum 53 bytes to access position 52

        bytes memory hookData = new bytes(dataLength);

        // Set the boolean byte at position 52
        hookData[52] = bytes1(boolByte);

        bool result = walletHook.decodeUsePrevHookAmount(hookData);
        assertEq(result, boolByte != 0, "Should match boolean conversion");
    }

    function testFuzz_MinterHook_DataValidation(uint256 payloadLength, uint256 signatureLength) public view {
        // Bound to reasonable ranges, ensuring meaningful test cases
        payloadLength = bound(payloadLength, 1, 1000); // Avoid zero-length payload
        signatureLength = bound(signatureLength, 65, 200); // Valid signature length range (min 65 for ECDSA)

        // Create payload and signature with the specified lengths
        bytes memory payload = new bytes(payloadLength);
        bytes memory signature = new bytes(signatureLength);

        // Use abi.encodePacked to create the hook data in the correct format
        bytes memory hookData = abi.encodePacked(uint256(payloadLength), payload, uint256(signatureLength), signature);

        // Should not revert for valid data
        (bytes memory decodedPayload, bytes memory decodedSignature) = minterHook.decodeAttestationData(hookData);
        assertEq(decodedPayload.length, payloadLength, "Payload length should match");
        assertEq(decodedSignature.length, signatureLength, "Signature length should match");
    }

    /*//////////////////////////////////////////////////////////////
                            BRANCH COVERAGE TESTS
    //////////////////////////////////////////////////////////////*/

    // ========== CircleGatewayWalletHook Branch Coverage ==========

    function test_WalletHook_BuildExecutions_WithPrevHookAmount_ZeroAmount() public {
        // Test the branch where usePrevHookAmount is true but prevHook returns 0
        MockPrevHook mockPrevHook = new MockPrevHook(0);

        bytes memory hookData = abi.encodePacked(
            address(mockToken), // token (20 bytes)
            DEPOSIT_AMOUNT, // amount (32 bytes, will be overridden)
            true // usePrevHookAmount (1 byte)
        );

        vm.expectRevert(abi.encodeWithSignature("AMOUNT_NOT_VALID()"));
        walletHook.build(address(mockPrevHook), ACCOUNT, hookData);
    }

    function test_WalletHook_BuildExecutions_WithPrevHookAmount_ZeroAddress() public {
        // Test the branch where usePrevHookAmount is true but token is zero address
        MockPrevHook mockPrevHook = new MockPrevHook(MINT_AMOUNT);

        bytes memory hookData = abi.encodePacked(
            address(0), // zero address token
            DEPOSIT_AMOUNT, // amount (32 bytes, will be overridden)
            true // usePrevHookAmount (1 byte)
        );

        vm.expectRevert(abi.encodeWithSignature("ADDRESS_NOT_VALID()"));
        walletHook.build(address(mockPrevHook), ACCOUNT, hookData);
    }

    function test_WalletHook_PostExecute_WithPrevHookAmount() public {
        // Test postExecute with usePrevHookAmount = true
        MockPrevHook mockPrevHook = new MockPrevHook(MINT_AMOUNT);

        bytes memory hookData = abi.encodePacked(
            address(mockToken), // token (20 bytes)
            DEPOSIT_AMOUNT, // amount (32 bytes, will be overridden)
            true // usePrevHookAmount (1 byte)
        );

        // Set up execution context
        walletHook.setExecutionContext(ACCOUNT);

        // Call postExecute directly
        vm.prank(ACCOUNT);
        walletHook.postExecute(address(mockPrevHook), ACCOUNT, hookData);

        // Verify the outAmount was set correctly
        assertEq(walletHook.getOutAmount(ACCOUNT), DEPOSIT_AMOUNT, "Should set outAmount to data amount");
    }

    function test_WalletHook_PostExecute_WithoutPrevHookAmount() public {
        // Test postExecute with usePrevHookAmount = false
        bytes memory hookData = abi.encodePacked(
            address(mockToken), // token (20 bytes)
            DEPOSIT_AMOUNT, // amount (32 bytes)
            false // usePrevHookAmount (1 byte)
        );

        // Set up execution context
        walletHook.setExecutionContext(ACCOUNT);

        // Call postExecute directly (this would normally be called by the executor)
        vm.prank(ACCOUNT);
        walletHook.postExecute(address(0), ACCOUNT, hookData);

        // Verify the outAmount was set correctly
        assertEq(walletHook.getOutAmount(ACCOUNT), DEPOSIT_AMOUNT, "Should set outAmount to data amount");
    }

    function test_WalletHook_Constructor_ZeroAddress() public {
        // Test constructor with zero address
        vm.expectRevert(abi.encodeWithSignature("ADDRESS_NOT_VALID()"));
        new CircleGatewayWalletHook(address(0));
    }

    function test_WalletHook_Constructor_ValidAddress() public {
        // Test constructor with valid address
        CircleGatewayWalletHook newHook = new CircleGatewayWalletHook(address(0x123));
        assertEq(newHook.GATEWAY_WALLET(), address(0x123), "Should set gateway wallet address");
    }

    function test_WalletHook_BuildExecutions_WithPrevHookAmount_NullPrevHook() public {
        // Test the branch where usePrevHookAmount is true but prevHook is address(0)
        bytes memory hookData = abi.encodePacked(
            address(mockToken), // token (20 bytes)
            DEPOSIT_AMOUNT, // amount (32 bytes)
            true // usePrevHookAmount (1 byte)
        );

        // This should revert when trying to call getOutAmount on address(0)
        vm.expectRevert();
        walletHook.build(address(0), ACCOUNT, hookData);
    }

    function test_WalletHook_PreExecute_DirectCall() public {
        bytes memory hookData = abi.encodePacked(
            address(mockToken), // token (20 bytes)
            DEPOSIT_AMOUNT, // amount (32 bytes)
            false // usePrevHookAmount (1 byte)
        );

        // Set up execution context
        walletHook.setExecutionContext(ACCOUNT);

        // Call preExecute directly - this function should execute without reverting
        vm.prank(ACCOUNT);
        walletHook.preExecute(address(0), ACCOUNT, hookData);

        // The function doesn't have any state changes to verify, but we can verify it executed
        // by checking that no revert occurred
    }

    // ========== CircleGatewayMinterHook Branch Coverage ==========

    function test_MinterHook_BuildExecutions_EmptyPayload() public {
        // Test the branch where attestationPayload.length == 0
        bytes memory hookData = abi.encodePacked(
            uint256(0), // empty payload length
            uint256(65), // signature length
            new bytes(65) // valid signature
        );

        vm.expectRevert(abi.encodeWithSignature("INVALID_DATA_LENGTH()"));
        minterHook.build(address(0), ACCOUNT, hookData);
    }

    function test_MinterHook_BuildExecutions_EmptySignature() public {
        // Test the branch where signature.length == 0
        bytes memory hookData = abi.encodePacked(
            uint256(4), // payload length
            hex"deadbeef", // payload
            uint256(0), // empty signature length
            new bytes(0) // empty signature
        );

        vm.expectRevert(abi.encodeWithSignature("INVALID_DATA_LENGTH()"));
        minterHook.build(address(0), ACCOUNT, hookData);
    }

    function test_MinterHook_DecodeAttestationData_SignatureTooShort() public {
        // Test the branch where signatureLength < 65
        bytes memory attestationPayload = hex"deadbeef"; // 4 bytes
        bytes memory shortSignature = new bytes(64); // 64 bytes (below minimum)

        bytes memory hookData = abi.encodePacked(
            uint256(attestationPayload.length), // payload length (32 bytes)
            attestationPayload, // payload (4 bytes)
            uint256(shortSignature.length), // signature length (32 bytes)
            shortSignature // short signature (64 bytes)
        );

        vm.expectRevert(abi.encodeWithSignature("INVALID_DATA_LENGTH()"));
        minterHook.decodeAttestationData(hookData);
    }

    function test_MinterHook_DecodeAttestationData_ExactMinimumLength() public {
        // Test the branch where data.length == 64 (exact minimum)
        bytes memory hookData = new bytes(64);
        // Set valid lengths in the first 64 bytes
        assembly {
            mstore(add(hookData, 32), 1) // payload length = 1
            mstore(add(hookData, 64), 65) // signature length = 65
        }

        vm.expectRevert(abi.encodeWithSignature("INVALID_DATA_LENGTH()"));
        minterHook.decodeAttestationData(hookData);
    }

    function test_MinterHook_DecodeAttestationData_InsufficientDataForSignatureLength() public {
        // Test the branch where data.length < offset + attestationPayloadLength + 32
        bytes memory hookData = abi.encodePacked(
            uint256(100), // claims 100 bytes payload
            hex"deadbeef", // only 4 bytes
            uint256(65) // signature length (but not enough data after)
        );

        vm.expectRevert(abi.encodeWithSignature("INVALID_DATA_LENGTH()"));
        minterHook.decodeAttestationData(hookData);
    }

    function test_MinterHook_DecodeAttestationData_InsufficientDataForSignature() public {
        // Test the branch where data.length < offset + signatureLength
        bytes memory attestationPayload = hex"deadbeef"; // 4 bytes
        bytes memory signature = new bytes(65);

        bytes memory hookData = abi.encodePacked(
            uint256(attestationPayload.length), // payload length (32 bytes)
            attestationPayload, // payload (4 bytes)
            uint256(signature.length), // signature length (32 bytes)
            hex"deadbeef" // only 4 bytes instead of 65
        );

        vm.expectRevert(abi.encodeWithSignature("INVALID_DATA_LENGTH()"));
        minterHook.decodeAttestationData(hookData);
    }

    function test_MinterHook_Inspect_ZeroTokenAddress() public {
        // Test preExecute with invalid token address from attestation
        // Create attestation with zero address token
        bytes memory hookData = _createValidAttestationData(address(0));

        vm.expectRevert(abi.encodeWithSignature("TOKEN_ADDRESS_INVALID()"));
        minterHook.inspect(hookData);
    }

    function test_MinterHook_PreExecute_ValidTokenAddress() public {
        // Test preExecute with valid token address
        bytes memory hookData = _createValidAttestationData(address(mockToken));

        // Set up execution context
        minterHook.setExecutionContext(ACCOUNT);

        // Call preExecute directly (this would normally be called by the executor)
        vm.prank(ACCOUNT);
        minterHook.preExecute(address(0), ACCOUNT, hookData);

        // Verify the asset was set correctly
        assertEq(minterHook.asset(), address(mockToken), "Should set asset to token address");

        // Verify initial balance was recorded
        assertEq(minterHook.getOutAmount(ACCOUNT), mockToken.balanceOf(ACCOUNT), "Should record initial balance");
    }

    function test_MinterHook_PostExecute_ValidMinting() public {
        // Test postExecute with successful minting
        bytes memory hookData = _createValidAttestationData(address(mockToken));

        uint256 initialBalance = mockToken.balanceOf(ACCOUNT);

        // Set up execution context
        minterHook.setExecutionContext(ACCOUNT);

        // Call preExecute to set up initial state
        vm.prank(ACCOUNT);
        minterHook.preExecute(address(0), ACCOUNT, hookData);

        // Simulate minting by transferring tokens to account
        mockToken.mint(ACCOUNT, MINT_AMOUNT);

        // Call postExecute to calculate the minted amount
        vm.prank(ACCOUNT);
        minterHook.postExecute(address(0), ACCOUNT, hookData);

        uint256 finalBalance = mockToken.balanceOf(ACCOUNT);
        uint256 expectedMintedAmount = finalBalance - initialBalance;

        // Verify the minted amount was calculated correctly
        assertEq(minterHook.getOutAmount(ACCOUNT), expectedMintedAmount, "Should calculate minted amount correctly");
    }

    function test_MinterHook_PostExecute_NoMinting() public {
        // Test postExecute when no minting occurred (balance didn't increase)
        bytes memory hookData = _createValidAttestationData(address(mockToken));

        uint256 initialBalance = mockToken.balanceOf(ACCOUNT);

        // Set up execution context
        minterHook.setExecutionContext(ACCOUNT);

        // Call preExecute to set up initial state
        vm.prank(ACCOUNT);
        minterHook.preExecute(address(0), ACCOUNT, hookData);

        // Don't mint any tokens, so balance should remain the same
        uint256 finalBalance = mockToken.balanceOf(ACCOUNT);
        uint256 expectedMintedAmount = finalBalance - initialBalance; // Should be 0

        // Call postExecute to calculate the minted amount
        vm.prank(ACCOUNT);
        minterHook.postExecute(address(0), ACCOUNT, hookData);

        // Verify the minted amount was calculated correctly (should be 0)
        assertEq(minterHook.getOutAmount(ACCOUNT), expectedMintedAmount, "Should calculate zero minted amount");
    }

    function test_MinterHook_Constructor_ZeroAddress() public {
        // Test constructor with zero address
        vm.expectRevert(abi.encodeWithSignature("ADDRESS_NOT_VALID()"));
        new CircleGatewayMinterHook(address(0));
    }

    function test_MinterHook_Constructor_ValidAddress() public {
        // Test constructor with valid address
        CircleGatewayMinterHook newHook = new CircleGatewayMinterHook(address(0x123));
        assertEq(newHook.GATEWAY_MINTER(), address(0x123), "Should set gateway minter address");
    }

    function test_MinterHook_Inspect_ValidData() public view {
        // Test the inspect function
        bytes memory hookData = _createValidAttestationData(address(mockToken));

        bytes memory result = minterHook.inspect(hookData);

        // The inspect function returns abi.encodePacked(usdc), which is a 20-byte packed address
        require(result.length == 20, "Expected 20 bytes for address");
        address decodedToken;
        assembly {
            decodedToken := shr(96, mload(add(result, 0x20)))
        }

        assertEq(decodedToken, address(mockToken), "Should extract correct token address");
    }

    // ========== Edge Cases and Error Conditions ==========

    function test_MinterHook_ExtractTokenFromAttestation_InvalidAttestation() public {
        // Test _extractTokenFromAttestation with invalid attestation data
        bytes memory invalidAttestation = hex"deadbeef"; // Valid hex but invalid attestation format

        bytes memory hookData = abi.encodePacked(
            uint256(invalidAttestation.length), // payload length
            invalidAttestation, // invalid payload
            uint256(65), // signature length
            new bytes(65) // signature
        );

        // This should revert when trying to validate the attestation
        vm.expectRevert();
        minterHook.inspect(hookData);
    }

    function test_MinterHook_ExtractTokenFromAttestation_ZeroTokenAddress() public {
        // Test _extractTokenFromAttestation with attestation that returns zero address
        bytes memory hookData = _createValidAttestationData(address(0));

        vm.expectRevert(abi.encodeWithSignature("TOKEN_ADDRESS_INVALID()"));
        minterHook.inspect(hookData);
    }

    // ========== Integration Tests ==========

    function test_WalletHook_FullExecutionFlow() public {
        // Test the complete execution flow for wallet hook
        bytes memory hookData = abi.encodePacked(
            address(mockToken), // token (20 bytes)
            DEPOSIT_AMOUNT, // amount (32 bytes)
            false // usePrevHookAmount (1 byte)
        );

        // Approve tokens to the hook
        mockToken.approve(address(walletHook), DEPOSIT_AMOUNT);

        // Set up execution context
        walletHook.setExecutionContext(ACCOUNT);

        // Call preExecute and postExecute to simulate full execution
        vm.prank(ACCOUNT);
        walletHook.preExecute(address(0), ACCOUNT, hookData);

        vm.prank(ACCOUNT);
        walletHook.postExecute(address(0), ACCOUNT, hookData);

        // Verify the outAmount was set
        assertEq(walletHook.getOutAmount(ACCOUNT), DEPOSIT_AMOUNT, "Should set outAmount");
    }

    function test_MinterHook_FullExecutionFlow() public {
        // Test the complete execution flow for minter hook
        bytes memory hookData = _createValidAttestationData(address(mockToken));

        uint256 initialBalance = mockToken.balanceOf(ACCOUNT);

        // Set up execution context
        minterHook.setExecutionContext(ACCOUNT);

        // Call preExecute to set up initial state
        vm.prank(ACCOUNT);
        minterHook.preExecute(address(0), ACCOUNT, hookData);

        // Verify the asset was set
        assertEq(minterHook.asset(), address(mockToken), "Should set asset");

        // Verify initial balance was recorded
        assertEq(minterHook.getOutAmount(ACCOUNT), initialBalance, "Should record initial balance");
    }

    function test_WalletHook_PostExecute_WithPrevHookAmount_Consistency() public {
        // Test that _postExecute correctly handles the case where usePrevHookAmount is true
        // The _postExecute function should use the amount from data, not from prevHook
        MockPrevHook mockPrevHook = new MockPrevHook(MINT_AMOUNT);

        bytes memory hookData = abi.encodePacked(
            address(mockToken), // token (20 bytes)
            DEPOSIT_AMOUNT, // amount in data (32 bytes)
            true // usePrevHookAmount (1 byte)
        );

        // Set up execution context
        walletHook.setExecutionContext(ACCOUNT);

        // Call postExecute directly
        vm.prank(ACCOUNT);
        walletHook.postExecute(address(mockPrevHook), ACCOUNT, hookData);

        // Verify the outAmount was set to the amount from data, not from prevHook
        // This tests the branch where _postExecute reads from data regardless of usePrevHookAmount
        assertEq(
            walletHook.getOutAmount(ACCOUNT), DEPOSIT_AMOUNT, "Should set outAmount to data amount, not prevHook amount"
        );
    }

    function test_MinterHook_PreExecute_ZeroTokenAddress_FromAttestation() public {
        // Test _preExecute when _extractTokenFromAttestation returns zero address
        // This tests the branch where the attestation contains a zero destination token
        bytes memory hookData = _createValidAttestationData(address(0));

        // Set up execution context
        minterHook.setExecutionContext(ACCOUNT);

        // Call preExecute - this should revert with TOKEN_ADDRESS_INVALID
        vm.prank(ACCOUNT);
        vm.expectRevert(abi.encodeWithSignature("TOKEN_ADDRESS_INVALID()"));
        minterHook.preExecute(address(0), ACCOUNT, hookData);
    }

    function test_MinterHook_BuildExecutions_EmptySignature_Branch() public {
        // Test the specific branch where signature.length == 0 in _buildHookExecutions (Line 77)
        // This creates a scenario where the signature is empty but the payload is valid
        bytes memory attestationPayload = _createMockAttestationPayload(address(mockToken));
        bytes memory emptySignature = new bytes(0);

        bytes memory hookData = abi.encodePacked(
            uint256(attestationPayload.length), // attestationPayloadLength (32 bytes)
            attestationPayload, // attestationPayload (variable length)
            uint256(emptySignature.length), // signatureLength (32 bytes) - 0
            emptySignature // empty signature
        );

        // This should revert with INVALID_DATA_LENGTH when signature.length == 0
        vm.expectRevert(abi.encodeWithSignature("INVALID_DATA_LENGTH()"));
        minterHook.build(address(0), ACCOUNT, hookData);
    }

    function test_MinterHook_PreExecute_ZeroTokenAddress() public {
        // Test the specific branch where usdc == address(0) in _preExecute (Line 121)
        // This tests the case where _extractTokenFromAttestation returns zero address
        bytes memory hookData = _createValidAttestationData(address(0));

        // Set up execution context
        minterHook.setExecutionContext(ACCOUNT);

        // Call preExecute - this should revert with TOKEN_ADDRESS_INVALID
        // This specifically tests the branch where usdc == address(0)
        vm.prank(ACCOUNT);
        vm.expectRevert(abi.encodeWithSignature("TOKEN_ADDRESS_INVALID()"));
        minterHook.preExecute(address(0), ACCOUNT, hookData);
    }

    function test_WalletHook_PreExecute_Function() public {
        // Test the _preExecute function in CircleGatewayWalletHook
        // This function is currently not covered by any tests
        bytes memory hookData = abi.encodePacked(
            address(mockToken), // token (20 bytes)
            DEPOSIT_AMOUNT, // amount (32 bytes)
            false // usePrevHookAmount (1 byte)
        );

        // Set up execution context
        walletHook.setExecutionContext(ACCOUNT);

        // Call preExecute directly - this function should not revert
        vm.prank(ACCOUNT);
        walletHook.preExecute(address(0), ACCOUNT, hookData);
    }

    function test_MinterHook_ExtractTokenFromAttestation_FirstIteration() public view {
        // This tests the first iteration where token is address(0), so the condition is false
        // and we don't enter the nested if statement
        bytes memory hookData = _createValidAttestationData(address(mockToken));

        // This should succeed because it's the first iteration and token starts as address(0)
        bytes memory result = minterHook.inspect(hookData);

        // Verify the result is correct
        require(result.length == 20, "Expected 20 bytes for address");
        address decodedToken;
        assembly {
            decodedToken := shr(96, mload(add(result, 0x20)))
        }
        assertEq(decodedToken, address(mockToken), "Should extract correct token address");
    }

    function test_MinterHook_ValidateDestinationCaller_Mismatch() public {
        // This tests when destinationCaller is not equal to account and not address(0)
        address differentAccount = address(0x456);
        bytes memory hookData = _createValidAttestationDataWithCaller(address(mockToken), differentAccount);

        // This should revert with INVALID_DESTINATION_CALLER when destinationCaller doesn't match account
        vm.expectRevert(abi.encodeWithSignature("INVALID_DESTINATION_CALLER()"));
        minterHook.build(address(0), ACCOUNT, hookData);
    }

    function test_MinterHook_ExtractTokenFromAttestation_BlankCursor() public {
        // Create a minimal valid signature (65 bytes for ECDSA)
        bytes memory signature = new bytes(65);

        // Create an empty attestation payload that will result in cursor.numElements == 0
        // We need to create a valid attestation structure but with no attestations
        bytes memory emptyAttestationPayload = _createEmptyAttestationPayload();

        bytes memory hookData = abi.encodePacked(
            uint256(emptyAttestationPayload.length), // attestationPayloadLength (32 bytes)
            emptyAttestationPayload, // empty attestation payload
            uint256(signature.length), // signatureLength (32 bytes)
            signature // signature (65 bytes)
        );

        // This should revert with INVALID_DATA_LENGTH when cursor.numElements == 0
        vm.expectRevert(abi.encodeWithSignature("INVALID_DATA_LENGTH()"));
        minterHook.build(address(0), ACCOUNT, hookData);
    }

    /*//////////////////////////////////////////////////////////////
                        ATTESTATION SET TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MinterHook_AttestationSet_SameTokenAddress() public view {
        // Create mock attestation set data with same token addresses
        // This simulates an AttestationSet with two attestations pointing to the same token
        bytes memory mockAttestationSet = _createMockAttestationSetWithSameToken(address(mockToken));
        bytes memory signature = new bytes(65); // Mock signature

        // Create hook data
        bytes memory hookData = abi.encodePacked(
            uint256(mockAttestationSet.length), // payload length (32 bytes)
            mockAttestationSet, // payload
            uint256(signature.length), // signature length (32 bytes)
            signature // signature
        );

        // Test build function - should succeed with same token addresses
        Execution[] memory executions = minterHook.build(address(0), ACCOUNT, hookData);
        assertEq(executions.length, 3, "Should have 3 executions");

        // Test inspect function - should return the token address
        bytes memory inspectResult = minterHook.inspect(hookData);

        // The inspect function returns abi.encodePacked(usdc), which is a 20-byte packed address
        require(inspectResult.length == 20, "Expected 20 bytes for address");
        address decodedToken;
        assembly {
            decodedToken := shr(96, mload(add(inspectResult, 0x20)))
        }

        assertEq(decodedToken, address(mockToken), "Should extract correct token address");
    }

    function test_MinterHook_AttestationSet_DifferentTokenAddresses() public {
        // Create a second mock token
        MockERC20 mockToken2 = new MockERC20("Mock USDC 2", "USDC2", 6);

        // Create mock attestation set data with different token addresses
        // This simulates an AttestationSet with two attestations pointing to different tokens
        bytes memory mockAttestationSet =
            _createMockAttestationSetWithDifferentTokens(address(mockToken), address(mockToken2));
        bytes memory signature = new bytes(65); // Mock signature

        // Create hook data
        bytes memory hookData = abi.encodePacked(
            uint256(mockAttestationSet.length), // payload length (32 bytes)
            mockAttestationSet, // payload
            uint256(signature.length), // signature length (32 bytes)
            signature // signature
        );

        // Test inspect function - should revert due to different token addresses
        // The hook validates that all tokens in the attestation set are the same
        // This should cause a revert when trying to process the attestation set with different tokens
        vm.expectRevert(abi.encodeWithSignature("DESTINATION_TOKENS_DIFFER()"));
        minterHook.inspect(hookData);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Create valid attestation data for testing
    /// @param tokenAddress The token address to include in the attestation (optional)
    /// @return hookData The encoded hook data
    function _createValidAttestationData(address tokenAddress) internal view returns (bytes memory hookData) {
        // Create a minimal valid signature (65 bytes for ECDSA)
        bytes memory signature = new bytes(65);

        // Use the new helper function to create the complete hook data structure
        hookData = _createMockHookData(tokenAddress, signature);
    }

    /// @notice Create valid attestation data for testing with default token address
    /// @return hookData The encoded hook data
    function _createValidAttestationData() internal view returns (bytes memory hookData) {
        return _createValidAttestationData(address(0xabc)); // Default token address
    }

    /// @notice Create a mock TransferSpec with proper magic numbers for testing
    /// @param tokenAddress The token address to include in the attestation
    /// @return transferSpec The encoded TransferSpec
    function _createMockTransferSpec(address tokenAddress) internal pure returns (bytes memory transferSpec) {
        // Create the TransferSpec header (first part)
        bytes memory header = _encodeTransferSpecHeader(
            TRANSFER_SPEC_VERSION,
            TRANSFER_SPEC_SOURCE_DOMAIN,
            TRANSFER_SPEC_DESTINATION_DOMAIN,
            bytes32(uint256(uint160(address(0x123)))), // sourceContract
            bytes32(uint256(uint160(address(0x456)))), // destinationContract
            bytes32(uint256(uint160(address(0x789)))), // sourceToken
            bytes32(uint256(uint160(tokenAddress))), // destinationToken
            bytes32(uint256(uint160(address(0xdef)))) // sourceDepositor
        );

        // Create the TransferSpec footer (second part)
        bytes memory footer = _encodeTransferSpecFooter(
            bytes32(uint256(uint160(address(0x123)))), // destinationRecipient
            bytes32(uint256(uint160(address(0xdef)))), // sourceSigner
            bytes32(0), // destinationCaller
            1000e6, // value
            keccak256("test-salt"), // salt
            "" // hookData
        );

        // Combine header and footer
        transferSpec = bytes.concat(header, footer);
    }

    /// @notice Encode the first part of a TransferSpec struct into bytes
    /// @param version The version field
    /// @param sourceDomain The sourceDomain field
    /// @param destinationDomain The destinationDomain field
    /// @param sourceContract The sourceContract field
    /// @param destinationContract The destinationContract field
    /// @param sourceToken The sourceToken field
    /// @param destinationToken The destinationToken field
    /// @param sourceDepositor The sourceDepositor field
    /// @return The encoded bytes
    function _encodeTransferSpecHeader(
        uint32 version,
        uint32 sourceDomain,
        uint32 destinationDomain,
        bytes32 sourceContract,
        bytes32 destinationContract,
        bytes32 sourceToken,
        bytes32 destinationToken,
        bytes32 sourceDepositor
    )
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            TRANSFER_SPEC_MAGIC,
            version,
            sourceDomain,
            destinationDomain,
            sourceContract,
            destinationContract,
            sourceToken,
            destinationToken,
            sourceDepositor
        );
    }

    /// @notice Encode the last part of a TransferSpec struct into bytes
    /// @param destinationRecipient The destinationRecipient field
    /// @param sourceSigner The sourceSigner field
    /// @param destinationCaller The destinationCaller field
    /// @param value The value field
    /// @param salt The salt field
    /// @param hookData The hookData field
    /// @return The encoded bytes
    function _encodeTransferSpecFooter(
        bytes32 destinationRecipient,
        bytes32 sourceSigner,
        bytes32 destinationCaller,
        uint256 value,
        bytes32 salt,
        bytes memory hookData
    )
        private
        pure
        returns (bytes memory)
    {
        if (hookData.length > type(uint32).max) {
            revert("TransferSpecHookDataFieldTooLarge");
        }

        return abi.encodePacked(
            destinationRecipient,
            sourceSigner,
            destinationCaller,
            value,
            salt,
            uint32(hookData.length), // 4 bytes
            hookData
        );
    }

    /// @notice Create complete hook data structure for CircleGatewayMinterHook
    /// @param tokenAddress The token address to include in the attestation
    /// @param signature The signature for the attestation
    /// @return hookData The complete hook data with proper structure
    function _createMockHookData(
        address tokenAddress,
        bytes memory signature
    )
        internal
        view
        returns (bytes memory hookData)
    {
        // Create the attestation payload
        bytes memory attestationPayload = _createMockAttestationPayload(tokenAddress);

        // Encode the hook data:
        // uint256 attestationPayloadLength = BytesLib.toUint256(data, 0);
        // bytes attestationPayload = BytesLib.slice(data, 32, attestationPayloadLength);
        // uint256 signatureLength = BytesLib.toUint256(data, 32 + attestationPayloadLength);
        // bytes signature = BytesLib.slice(data, 64 + attestationPayloadLength, signatureLength);

        hookData = abi.encodePacked(
            uint256(attestationPayload.length), // attestationPayloadLength (32 bytes)
            attestationPayload, // attestationPayload (variable length)
            uint256(signature.length), // signatureLength (32 bytes)
            signature // signature (variable length)
        );
    }

    /// @notice Create a mock attestation payload for testing
    /// @param tokenAddress The token address to include in the attestation
    /// @return attestationPayload The encoded attestation payload
    function _createMockAttestationPayload(address tokenAddress)
        internal
        view
        returns (bytes memory attestationPayload)
    {
        // Create the TransferSpec
        bytes memory transferSpec = _createMockTransferSpec(tokenAddress);

        // Create the attestation structure manually:
        // - magic (4 bytes): 0xff6fb334
        // - maxBlockHeight (32 bytes): uint256
        // - transferSpecLength (4 bytes): uint32
        // - transferSpec (variable bytes)

        bytes4 attestationMagic = 0xff6fb334; // ATTESTATION_MAGIC
        uint256 maxBlockHeight = block.number + 1000; // Valid for 1000 blocks
        uint32 transferSpecLength = uint32(transferSpec.length);

        attestationPayload = abi.encodePacked(attestationMagic, maxBlockHeight, transferSpecLength, transferSpec);
    }

    /// @notice Create a mock TransferSpec with a specific destination caller for testing
    /// @param tokenAddress The token address to include in the attestation
    /// @param destinationCaller The destination caller to include in the transfer spec
    /// @return transferSpec The encoded TransferSpec
    function _createMockTransferSpecWithCaller(
        address tokenAddress,
        address destinationCaller
    )
        internal
        pure
        returns (bytes memory transferSpec)
    {
        // Create the TransferSpec header (first part)
        bytes memory header = _encodeTransferSpecHeader(
            TRANSFER_SPEC_VERSION,
            TRANSFER_SPEC_SOURCE_DOMAIN,
            TRANSFER_SPEC_DESTINATION_DOMAIN,
            bytes32(uint256(uint160(address(0x123)))), // sourceContract
            bytes32(uint256(uint160(address(0x456)))), // destinationContract
            bytes32(uint256(uint160(address(0x789)))), // sourceToken
            bytes32(uint256(uint160(tokenAddress))), // destinationToken
            bytes32(uint256(uint160(address(0xdef)))) // sourceDepositor
        );

        // Create the TransferSpec footer (second part) with the specified destination caller
        bytes memory footer = _encodeTransferSpecFooter(
            bytes32(uint256(uint160(address(0x123)))), // destinationRecipient
            bytes32(uint256(uint160(address(0xdef)))), // sourceSigner
            bytes32(uint256(uint160(destinationCaller))), // destinationCaller - use the specified caller
            1000e6, // value
            keccak256("test-salt"), // salt
            "" // hookData
        );

        // Combine header and footer
        transferSpec = bytes.concat(header, footer);
    }

    /// @notice Create a mock attestation payload for testing with a specific destination caller
    /// @param tokenAddress The token address to include in the attestation
    /// @param destinationCaller The destination caller to include in the attestation
    /// @return attestationPayload The encoded attestation payload
    function _createMockAttestationPayloadWithCaller(
        address tokenAddress,
        address destinationCaller
    )
        internal
        view
        returns (bytes memory attestationPayload)
    {
        // Create the TransferSpec with the specified destination caller
        bytes memory transferSpec = _createMockTransferSpecWithCaller(tokenAddress, destinationCaller);

        // Create the attestation structure manually:
        // - magic (4 bytes): 0xff6fb334
        // - maxBlockHeight (32 bytes): uint256
        // - transferSpecLength (4 bytes): uint32
        // - transferSpec (variable bytes)

        bytes4 attestationMagic = 0xff6fb334; // ATTESTATION_MAGIC
        uint256 maxBlockHeight = block.number + 1000; // Valid for 1000 blocks
        uint32 transferSpecLength = uint32(transferSpec.length);

        attestationPayload = abi.encodePacked(attestationMagic, maxBlockHeight, transferSpecLength, transferSpec);
    }

    /// @notice Create complete hook data structure for CircleGatewayMinterHook with specific destination caller
    /// @param tokenAddress The token address to include in the attestation
    /// @param destinationCaller The destination caller to include in the attestation
    /// @return hookData The complete hook data with proper structure
    function _createValidAttestationDataWithCaller(
        address tokenAddress,
        address destinationCaller
    )
        internal
        view
        returns (bytes memory hookData)
    {
        // Create the attestation payload with the specified destination caller
        bytes memory attestationPayload = _createMockAttestationPayloadWithCaller(tokenAddress, destinationCaller);

        // Create a minimal valid signature (65 bytes for ECDSA)
        bytes memory signature = new bytes(65);

        // Encode the hook data:
        // uint256 attestationPayloadLength = BytesLib.toUint256(data, 0);
        // bytes attestationPayload = BytesLib.slice(data, 32, attestationPayloadLength);
        // uint256 signatureLength = BytesLib.toUint256(data, 32 + attestationPayloadLength);
        // bytes signature = BytesLib.slice(data, 64 + attestationPayloadLength, signatureLength);

        hookData = abi.encodePacked(
            uint256(attestationPayload.length), // attestationPayloadLength (32 bytes)
            attestationPayload, // attestationPayload (variable length)
            uint256(signature.length), // signatureLength (32 bytes)
            signature // signature (variable length)
        );
    }

    /// @notice Creates mock attestation set data with same token addresses
    /// @param token The token address to use for both attestations
    /// @return Mock attestation set bytes
    function _createMockAttestationSetWithSameToken(address token) internal pure returns (bytes memory) {
        bytes32 tokenBytes32 = bytes32(uint256(uint160(token)));

        TransferSpec memory transferSpec = TransferSpec({
            version: TRANSFER_SPEC_VERSION,
            sourceDomain: TRANSFER_SPEC_SOURCE_DOMAIN,
            destinationDomain: TRANSFER_SPEC_DESTINATION_DOMAIN,
            sourceContract: bytes32(uint256(uint160(address(0x111)))),
            destinationContract: bytes32(uint256(uint160(address(0x222)))),
            sourceToken: tokenBytes32,
            destinationToken: tokenBytes32,
            sourceDepositor: bytes32(uint256(uint160(address(0x333)))),
            destinationRecipient: bytes32(uint256(uint160(address(0x444)))),
            sourceSigner: bytes32(uint256(uint160(address(0x555)))),
            destinationCaller: bytes32(0),
            value: MINT_AMOUNT,
            salt: bytes32(uint256(1)),
            hookData: new bytes(0)
        });

        Attestation[] memory attestations = new Attestation[](2);
        Attestation memory attestation1 = Attestation({ maxBlockHeight: MAX_BLOCK_HEIGHT, spec: transferSpec });
        attestations[0] = attestation1;

        Attestation memory attestation2 = Attestation({ maxBlockHeight: MAX_BLOCK_HEIGHT, spec: transferSpec });
        attestations[1] = attestation2;

        AttestationSet memory attestationSet = AttestationSet({ attestations: attestations });

        // Create a simple mock attestation set structure
        // This simulates the Circle Gateway AttestationSet format
        bytes memory attestationSetBytes = AttestationLib.encodeAttestationSet(attestationSet);

        return attestationSetBytes;
    }

    /// @notice Creates mock attestation set data with different token addresses
    /// @param token1 The token address for the first attestation
    /// @param token2 The token address for the second attestation
    /// @return Mock attestation set bytes
    function _createMockAttestationSetWithDifferentTokens(
        address token1,
        address token2
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes32 token1Bytes32 = bytes32(uint256(uint160(token1)));
        bytes32 token2Bytes32 = bytes32(uint256(uint160(token2)));

        TransferSpec memory transferSpec = _createTransferSpecStructWithToken(token1Bytes32);

        TransferSpec memory transferSpec2 = _createTransferSpecStructWithToken(token2Bytes32);

        Attestation[] memory attestations = new Attestation[](2);
        attestations[0] = Attestation({ maxBlockHeight: MAX_BLOCK_HEIGHT, spec: transferSpec });
        attestations[1] = Attestation({ maxBlockHeight: MAX_BLOCK_HEIGHT, spec: transferSpec2 });

        AttestationSet memory attestationSet = AttestationSet({ attestations: attestations });

        // Create a simple mock attestation set structure with different tokens
        bytes memory attestationSetBytes = AttestationLib.encodeAttestationSet(attestationSet);

        return attestationSetBytes;
    }

    function _createTransferSpecStructWithToken(bytes32 token) internal pure returns (TransferSpec memory) {
        return TransferSpec({
            version: TRANSFER_SPEC_VERSION,
            sourceDomain: TRANSFER_SPEC_SOURCE_DOMAIN,
            destinationDomain: TRANSFER_SPEC_DESTINATION_DOMAIN,
            sourceContract: bytes32(uint256(uint160(address(0x111)))),
            destinationContract: bytes32(uint256(uint160(address(0x222)))),
            sourceToken: token,
            destinationToken: token,
            sourceDepositor: bytes32(uint256(uint160(address(0x333)))),
            destinationRecipient: bytes32(uint256(uint160(address(0x444)))),
            sourceSigner: bytes32(uint256(uint160(address(0x555)))),
            destinationCaller: bytes32(0),
            value: MINT_AMOUNT,
            salt: bytes32(uint256(1)),
            hookData: new bytes(0)
        });
    }

    /// @notice Create an empty attestation payload that results in cursor.numElements == 0
    /// @return emptyAttestationPayload The encoded empty attestation payload
    function _createEmptyAttestationPayload() internal pure returns (bytes memory emptyAttestationPayload) {
        // Create an attestation set with no attestations
        // This will result in cursor.numElements == 0 when processed by AttestationLib.cursor()

        // Create an empty AttestationSet structure
        // The AttestationSet format is: magic (4 bytes) + numAttestations (4 bytes) + attestations array
        bytes4 attestationSetMagic = 0x1e12db71; // ATTESTATION_SET_MAGIC
        uint32 numAttestations = 0; // No attestations

        emptyAttestationPayload = abi.encodePacked(attestationSetMagic, numAttestations);
    }
}

/// @title MockPrevHook
/// @notice Mock hook that implements ISuperHookResult for testing
contract MockPrevHook is ISuperHookResult {
    uint256 private _outAmount;
    address private _asset;
    address private _spToken;
    ISuperHook.HookType private _hookType;

    constructor(uint256 outAmount) {
        _outAmount = outAmount;
        _asset = address(0x123); // Mock asset
        _spToken = address(0x456); // Mock sp token
        _hookType = ISuperHook.HookType.NONACCOUNTING;
    }

    function getOutAmount(address) external view returns (uint256) {
        return _outAmount;
    }

    function asset() external view returns (address) {
        return _asset;
    }

    function spToken() external view returns (address) {
        return _spToken;
    }

    function hookType() external view returns (ISuperHook.HookType) {
        return _hookType;
    }
}

/// @title MockGatewayWallet
/// @notice Mock implementation of Circle Gateway Wallet for testing
contract MockGatewayWallet {
    event Deposit(address indexed token, uint256 value, address indexed depositor);

    mapping(address => mapping(address => uint256)) public deposits;

    function deposit(address token, uint256 value) external {
        // Transfer tokens from caller to this contract
        IERC20(token).transferFrom(msg.sender, address(this), value);

        // Record the deposit
        deposits[msg.sender][token] += value;

        emit Deposit(token, value, msg.sender);
    }

    function getDeposit(address depositor, address token) external view returns (uint256) {
        return deposits[depositor][token];
    }
}

/// @title MockGatewayMinter
/// @notice Mock implementation of Circle Gateway Minter for testing
contract MockGatewayMinter {
    event GatewayMint(bytes attestationPayload, bytes signature, address indexed recipient, uint256 amount);

    MockERC20 public immutable TOKEN;
    uint256 public constant MINT_AMOUNT = 100e6; // Fixed mint amount for testing

    constructor(address token) {
        TOKEN = MockERC20(token);
    }

    function gatewayMint(bytes memory attestationPayload, bytes memory signature) external {
        require(attestationPayload.length > 0, "Empty attestation payload");
        require(signature.length >= 65, "Invalid signature length");

        // In a real implementation, this would validate the attestation and signature
        // For testing, we just mint a fixed amount to the caller
        TOKEN.mint(msg.sender, MINT_AMOUNT);

        emit GatewayMint(attestationPayload, signature, msg.sender, MINT_AMOUNT);
    }
}

/// @title MockAttestationLib
/// @notice Mock implementation for testing attestation validation
contract MockAttestationLib {
    function _validate(bytes memory) external pure returns (bytes29) {
        revert("Mock validation failed");
    }
}
