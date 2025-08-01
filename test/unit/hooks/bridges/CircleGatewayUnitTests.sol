// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// foundry
import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

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

    address constant ACCOUNT = address(0x123);
    uint256 constant DEPOSIT_AMOUNT = 1000e6; // 1000 USDC
    uint256 constant MINT_AMOUNT = 500e6; // 500 USDC

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
        // Create valid attestation data
        bytes memory attestationPayload = hex"deadbeef";
        bytes memory signature = new bytes(65);

        bytes memory hookData = abi.encodePacked(
            uint256(attestationPayload.length), attestationPayload, uint256(signature.length), signature
        );

        // Build executions using the public build method
        Execution[] memory executions = minterHook.build(address(0), ACCOUNT, hookData);

        // Should have 3 executions: preExecute, gatewayMint, postExecute
        assertEq(executions.length, 3, "Should have 3 executions");
        assertEq(executions[1].target, address(mockGatewayMinter), "Target should be gateway minter");
        assertEq(executions[1].value, 0, "Value should be 0");

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
