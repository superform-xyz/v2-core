// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import { MinimalBaseNexusIntegrationTest } from "./MinimalBaseNexusIntegrationTest.t.sol";
import { INexus } from "../../src/vendor/nexus/INexus.sol";
import { MockRegistry } from "../mocks/MockRegistry.sol";
import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";
import { IERC7579Account } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

import { IMinimalEntryPoint, PackedUserOperation } from "../../src/vendor/account-abstraction/IMinimalEntryPoint.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { AcrossSendFundsAndExecuteOnDstHook } from
    "../../src/core/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol";

import { ISuperSignatureStorage } from "../../src/core/interfaces/ISuperSignatureStorage.sol";
import { MockValidator } from "../../lib/modulekit/src/module-bases/mocks/MockValidator.sol";
import "forge-std/console.sol";

contract E2EExecutionTest is MinimalBaseNexusIntegrationTest {
    MockRegistry public nexusRegistry;
    address[] public attesters;
    uint8 public threshold;

    bytes public mockSignature;

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();
        nexusRegistry = new MockRegistry();
        attesters = new address[](1);
        attesters[0] = address(MANAGER);
        threshold = 1;

        mockSignature = abi.encodePacked(hex"41414141");
    }

    function test_AccountCreation_WithNexus() public {
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold, 0);
        _assertAccountCreation(nexusAccount);
    }

    function test_AccountCreation_WithNexus_WithNoAttesters() public {
        address[] memory actualAttesters = new address[](0);
        address nexusAccount = _createWithNexus(address(nexusRegistry), actualAttesters, threshold, 0);
        _assertAccountCreation(nexusAccount);
    }

    function test_AccountCreation_WithNexus_WithNoThreshold() public {
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, 0, 0);
        _assertAccountCreation(nexusAccount);
    }

    function test_AccountCreation_Multiple_Times() public {
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold, 0);
        _assertAccountCreation(nexusAccount);

        address nexusAccount2 = _createWithNexus(address(nexusRegistry), attesters, threshold, 0);
        _assertAccountCreation(nexusAccount2);
        assertEq(nexusAccount, nexusAccount2, "Nexus accounts should be the same");

        address nexusAccount3 = _createWithNexus(address(nexusRegistry), attesters, 0, 0);
        _assertAccountCreation(nexusAccount3);
        assertNotEq(nexusAccount, nexusAccount3, "Nexus3 account should be different");

        address[] memory actualAttesters = new address[](0);
        address nexusAccount4 = _createWithNexus(address(nexusRegistry), actualAttesters, threshold, 0);
        _assertAccountCreation(nexusAccount4);
        assertNotEq(nexusAccount, nexusAccount4, "Nexus4 account should be different");
    }

    struct TestData {
        address[] hooksAddresses;
        bytes[] hooksData;
        uint256 zero;
        uint256 ten;
        PackedUserOperation[] userOps;
        bytes signature;
        bytes sigData;
        bytes32[] leaves;
        bytes32[][] proof;
        bytes32 root;
    }

    struct DestinationMessage {
        bytes initData;
        bytes executorCalldata;
        address _account;
        address[] dstTokens;
        uint256[] intentAmounts;
    }

    function testOrion_multipleUserOpsBreakFetchedSignature() public {
        TestData memory testData;
        testData.zero = 0;
        testData.ten = 10;

        uint256 amount = 100e6;

        AcrossSendFundsAndExecuteOnDstHook acrossHook = new AcrossSendFundsAndExecuteOnDstHook(
            0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5, address(superMerkleValidator)
        );

        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold, 1e18);

        _getTokens(CHAIN_1_USDC, nexusAccount, amount);
        _getTokens(CHAIN_1_WETH, nexusAccount, amount);

        testData.userOps = new PackedUserOperation[](2);
        testData.userOps[0] = _buildUserOp(testData, nexusAccount, amount, CHAIN_1_USDC, acrossHook);
        testData.userOps[1] = _buildUserOp(testData, nexusAccount, amount, CHAIN_1_WETH, acrossHook);

        vm.expectRevert(
            abi.encodeWithSelector(
                IMinimalEntryPoint.FailedOpWithRevert.selector,
                1,
                "AA23 reverted",
                abi.encodePacked(ISuperSignatureStorage.INVALID_USER_OP.selector)
            )
        );
        IMinimalEntryPoint(ENTRYPOINT_ADDR).handleOps(testData.userOps, payable(nexusAccount));
    }

    function _buildUserOp(
        TestData memory testData,
        address nexusAccount,
        uint256 amount,
        address token,
        AcrossSendFundsAndExecuteOnDstHook acrossHook
    )
        internal
        view
        returns (PackedUserOperation memory userOp)
    {
        testData.hooksAddresses = new address[](2);
        testData.hooksAddresses[0] = approveHook;
        testData.hooksAddresses[1] = address(acrossHook);

        testData.hooksData = new bytes[](2);
        testData.hooksData[0] = _createApproveHookData(token, CHAIN_1_SPOKE_POOL_V3_ADDRESS, amount, false);

        DestinationMessage memory message = _buildDestinationMessage(token, amount);

        testData.hooksData[1] = _encodeAcrossHookData(nexusAccount, token, amount, message, testData.zero, testData.ten);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: testData.hooksAddresses, hooksData: testData.hooksData });

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: address(superExecutorModule),
            value: 0,
            callData: abi.encodeWithSelector(ISuperExecutor.execute.selector, abi.encode(entry))
        });

        bytes memory callData = _prepareExecutionCalldata(executions);
        uint256 nonce = _prepareUserOpNonce(nexusAccount, token);

        userOp = _createPackedUserOperation(nexusAccount, nonce, callData);

        (bytes memory sigData, bytes32[][] memory proof, bytes32 root, bytes memory signature) =
            _getSignatureData(userOp, ENTRYPOINT_ADDR);

        testData.sigData = sigData;
        testData.proof = proof;
        testData.root = root;
        testData.signature = signature;

        userOp.signature = testData.sigData;
    }

    function _buildDestinationMessage(
        address token,
        uint256 amount
    )
        internal
        pure
        returns (DestinationMessage memory message)
    {
        message.initData = hex"aaaaaaaa";
        message.executorCalldata = hex"eeeeeeee";
        message.dstTokens = new address[](1);
        message.dstTokens[0] = token;
        message.intentAmounts = new uint256[](1);
        message.intentAmounts[0] = amount;
    }

    function _encodeAcrossHookData(
        address nexusAccount,
        address token,
        uint256 amount,
        DestinationMessage memory message,
        uint256 zero,
        uint256 ten
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory messageData = _encodeMessageData(message);
        return abi.encodePacked(
            zero,
            nexusAccount,
            token,
            token,
            amount,
            amount,
            ten,
            address(0),
            uint32(zero),
            uint32(zero),
            false,
            messageData
        );
    }

    function _encodeMessageData(DestinationMessage memory message) internal pure returns (bytes memory) {
        return abi.encode(
            message.initData, message.executorCalldata, message._account, message.dstTokens, message.intentAmounts
        );
    }

    function _getSignatureData(
        PackedUserOperation memory userOp,
        address entryPoint
    )
        internal
        view
        returns (bytes memory sigData, bytes32[][] memory proof, bytes32 root, bytes memory signature)
    {
        uint48 validUntil = uint48(block.timestamp + 1 hours);
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _createSourceValidatorLeaf(IMinimalEntryPoint(entryPoint).getUserOpHash(userOp), validUntil);
        (proof, root) = _createValidatorMerkleTree(leaves);
        signature = _getSignature(root);
        sigData = abi.encode(validUntil, root, proof[0], hex"1111", signature);
    }

    function _prepareUserOpNonce(address nexusAccount, address token) internal view returns (uint256 nonce) {
        if (token == CHAIN_1_USDC) {
            return _prepareNonce(nexusAccount);
        }

        return _prepareUserOpNonceWithCustomBatchId(nexusAccount, bytes3(0));
    }

    function _prepareUserOpNonceWithCustomBatchId(
        address nexusAccount,
        bytes3 customBatchId
    )
        internal
        view
        returns (uint256 nonce)
    {
        uint192 nonceKey;
        address validator = address(superMerkleValidator);
        bytes32 batchId = customBatchId;
        bytes1 vMode = MODE_VALIDATION;
        assembly {
            nonceKey := or(shr(88, vMode), validator)
            nonceKey := or(shr(64, batchId), nonceKey)
        }

        nonce = (IMinimalEntryPoint(ENTRYPOINT_ADDR).nonceSequenceNumber(nexusAccount, nonceKey) + 1)
            | (uint256(nonceKey) << 64);
    }

    function test_Approval_With_Nexus(uint256 amount) public {
        amount = _bound(amount);

        // create account
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold, 0);
        _assertAccountCreation(nexusAccount);

        // fund account
        vm.deal(nexusAccount, LARGE);

        // assert account initialized with super executor
        _assertExecutorIsInitialized(nexusAccount);

        // add tokens to account
        _getTokens(CHAIN_1_WETH, nexusAccount, amount);

        // create SuperExecutor data
        address[] memory hooksAddresses = new address[](1);
        bytes[] memory hooksData = new bytes[](1);
        hooksAddresses[0] = approveHook;
        hooksData[0] = _createApproveHookData(CHAIN_1_WETH, address(MANAGER), amount, false);
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        // prepare data & execute through entry point
        _executeThroughEntrypoint(nexusAccount, entry);

        uint256 allowanceAmount = IERC20(CHAIN_1_WETH).allowance(nexusAccount, address(MANAGER));
        assertEq(allowanceAmount, amount, "Allowance should be set correctly");
    }

    function test_Approval_With_Existing_Account(uint256 amount) public {
        amount = _bound(amount);

        // create account
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold, 1e18);
        _assertAccountCreation(nexusAccount);

        // "re-create" account
        nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold, 0);
        _assertAccountCreation(nexusAccount);

        _assertExecutorIsInitialized(nexusAccount);

        // add tokens to account
        _getTokens(CHAIN_1_WETH, nexusAccount, amount);

        // create SuperExecutor data
        address[] memory hooksAddresses = new address[](1);
        bytes[] memory hooksData = new bytes[](1);
        hooksAddresses[0] = approveHook;
        hooksData[0] = _createApproveHookData(CHAIN_1_WETH, address(MANAGER), amount, false);
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        // prepare data & execute through entry point
        _executeThroughEntrypoint(nexusAccount, entry);

        uint256 allowanceAmount = IERC20(CHAIN_1_WETH).allowance(nexusAccount, address(MANAGER));
        assertEq(allowanceAmount, amount, "Allowance should be set correctly");
    }

    function test_Deposit_To_Morpho_And_TransferShares(uint256 amount) public {
        amount = _bound(amount);
        address underlyingToken = CHAIN_1_USDC;
        address morphoVault = CHAIN_1_MorphoVault;

        // create account
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold, 1e18);
        _assertAccountCreation(nexusAccount);

        // add tokens to account
        _getTokens(underlyingToken, nexusAccount, amount);

        uint256 obtainable = IERC4626(morphoVault).previewDeposit(amount);

        // create SuperExecutor data
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = deposit4626Hook;

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingToken, morphoVault, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), morphoVault, amount, false, address(0), 0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        // prepare data & execute through entry point
        _executeThroughEntrypoint(nexusAccount, entry);

        uint256 accSharesAfter = IERC4626(morphoVault).balanceOf(nexusAccount);
        assertApproxEqAbs(
            accSharesAfter,
            obtainable,
            /**
             * 10% max delta
             */
            amount * 1e5 / 1e6,
            "Shares should be close to obtainable"
        );
    }

    function testOrion_feesCauseChainedOperationFailures() public {
        uint256 amount = 100e6;
        address underlyingToken = CHAIN_1_USDC;
        address morphoVault = CHAIN_1_MorphoVault;

        // 1. Create account
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold, 1e18);

        // add tokens to account
        _getTokens(underlyingToken, nexusAccount, amount);
        // Mock account approval to vault
        vm.startPrank(nexusAccount);
        IERC20(CHAIN_1_USDC).approve(morphoVault, type(uint256).max);

        // 2. Create SuperExecutor data, with:
        // - approval
        // - deposit
        // - redemption, whose amount should be charged
        // - approval
        // - deposit
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = deposit4626Hook;

        bytes[] memory hooksData = new bytes[](1);

        hooksData[0] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), morphoVault, amount, false, address(0), 0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        // prepare data & execute through entry point
        _executeThroughEntrypoint(nexusAccount, entry);

        // Warp to mock interest accrual so that fees are applied
        vm.warp(block.timestamp + 10 weeks);

        {
            hooksAddresses = new address[](2);
            hooksAddresses[0] = redeem4626Hook;
            hooksAddresses[1] = deposit4626Hook;

            hooksData = new bytes[](2);

            // Store initial values for assertions
            uint256 initialShares = IERC4626(morphoVault).balanceOf(nexusAccount);
            uint256 sharesToRedeem = IERC4626(morphoVault).convertToShares(amount);

            hooksData[0] = _createRedeem4626HookData(
                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), morphoVault, nexusAccount, sharesToRedeem, false
            );

            hooksData[1] = _createDeposit4626HookData(
                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                morphoVault,
                amount,
                true, // use previous output amount set to true
                address(0),
                0
            );

            entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

            // prepare data & execute through entry point
            _executeThroughEntrypoint(nexusAccount, entry);

            uint256 finalShares = IERC4626(morphoVault).balanceOf(nexusAccount);
            uint256 tokenBalanceAfter = IERC20(underlyingToken).balanceOf(nexusAccount);

            assertLt(finalShares, initialShares);

            uint256 redeemedAmount = IERC4626(morphoVault).convertToAssets(initialShares - finalShares);
            assertGt(redeemedAmount, 0);
            assertLt(redeemedAmount, amount);

            if (tokenBalanceAfter > 0) {
                assertLt(tokenBalanceAfter, amount);
            }
        }
    }

    function test_feeBypassByCustomHook_Reverts() public {
        uint256 amount = 10_000e6;
        address underlyingToken = CHAIN_1_USDC;
        address morphoVault = CHAIN_1_MorphoVault;

        address accountOwner = makeAddr("owner");
        MaliciousHook maliciousHook = new MaliciousHook(accountOwner, underlyingToken);

        // Step 1: Create account and install custom malicious hook
        address nexusAccount = _createWithNexusWithMaliciousHook(
            address(nexusRegistry), attesters, threshold, 1e18, address(maliciousHook)
        );

        maliciousHook.setAccount(nexusAccount);

        // Step 2: Account approval to the hook
        vm.startPrank(nexusAccount);
        IERC4626(underlyingToken).approve(address(maliciousHook), type(uint256).max);

        // add tokens to account
        _getTokens(underlyingToken, nexusAccount, amount);

        // 3. Create SuperExecutor data, with:
        // - approval
        // - deposit
        // - redemption, whose amount should be charged
        // - approval
        // - deposit
        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = deposit4626Hook;
        hooksAddresses[2] = redeem4626Hook;

        bytes[] memory hooksData = new bytes[](3);
        hooksData[0] = _createApproveHookData(underlyingToken, morphoVault, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), morphoVault, amount, false, address(0), 0
        );
        hooksData[2] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            morphoVault,
            nexusAccount,
            IERC4626(morphoVault).convertToShares(amount),
            false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        address feeRecipient = makeAddr("feeRecipient"); // this is the recipient configured in base
            // tests.

        // Fetch the fee recipient balance before execution
        uint256 feeReceiverBalanceBefore = IERC4626(CHAIN_1_USDC).balanceOf(feeRecipient);

        // prepare data & execute through entry point
        _executeThroughEntrypointWithMaliciousHook(nexusAccount, entry);

        // Ensure fee obtained is 0
        assertEq(IERC4626(CHAIN_1_USDC).balanceOf(feeRecipient) - feeReceiverBalanceBefore, 0);
    }

    function test_HookPoisoning_SetExecutionContext_DoesNotBreakNormalExecution() public {
        TestData memory testData;
        testData.zero = 0;
        testData.ten = 10;

        uint256 amount = 100e6;
        address underlyingToken = CHAIN_1_USDC;
        address morphoVault = CHAIN_1_MorphoVault;

        // Create account
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold, 1e18);

        // Fund account with tokens
        _getTokens(underlyingToken, nexusAccount, amount * 2); // Double amount to handle both
            // operations

        // Create hook instance that we'll try to poison
        address targetHook = deposit4626Hook;

        // Build two userOps with proper nonce ordering
        testData.userOps = new PackedUserOperation[](2);

        // Get base nonce for proper sequencing
        uint256 baseNonce = _prepareNonce(nexusAccount);

        // First userOp: Direct call to setExecutionContext (attempting to poison)
        testData.userOps[0] = _buildPoisoningUserOp(nexusAccount, targetHook, baseNonce);

        // Second userOp: Normal SuperExecutor execution with deposit and redeem hooks
        testData.userOps[1] =
            _buildNormalExecutionUserOp(testData, nexusAccount, amount, underlyingToken, morphoVault, baseNonce + 1);

        // Execute both operations - this should revert as we expect that only one userOp is passed
        // through SuperForm
        // sytem
        vm.expectRevert();
        IMinimalEntryPoint(ENTRYPOINT_ADDR).handleOps(testData.userOps, payable(nexusAccount));

        // Verify the normal execution worked correctly
        uint256 finalShares = IERC4626(morphoVault).balanceOf(nexusAccount);
        assertGt(finalShares, 0, "Normal execution should have succeeded despite poisoning attempt");
    }

    function test_HookPoisoning_DirectCall_DoesNotBreakNormalExecution() public {
        TestData memory testData;
        testData.zero = 0;
        testData.ten = 10;

        uint256 amount = 100e6;
        address underlyingToken = CHAIN_1_USDC;
        address morphoVault = CHAIN_1_MorphoVault;

        // Create legitimate account
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold, 1e18);

        // Fund account with tokens
        _getTokens(underlyingToken, nexusAccount, amount * 2);

        // Create hook instance that we'll try to poison
        address targetHook = deposit4626Hook;

        // Create malicious account that will try to poison the legitimate user's transaction
        // Use a different validator to completely bypass Superform core flow
        address maliciousAccount = _createWithNexus(address(nexusRegistry), attesters, threshold, 1e18);

        // Deploy and install MockValidator on malicious account to bypass normal validation
        MockValidator mockValidator = new MockValidator();
        _installValidatorOnAccount(maliciousAccount, address(mockValidator));

        // Build two userOps with proper nonce ordering (simulating mempool attack)
        testData.userOps = new PackedUserOperation[](2);

        // Get base nonce for legitimate account
        uint256 legitimateNonce = _prepareNonce(nexusAccount);

        // Get base nonce for malicious account
        uint256 maliciousNonce = _prepareNonce(maliciousAccount);

        // First userOp: Malicious account tries to poison hooks (attacker frontrunning)
        testData.userOps[0] = _buildDirectPoisoningUserOp(
            maliciousAccount, targetHook, nexusAccount, "setExecutionContext", maliciousNonce
        );

        // Second userOp: Legitimate user's normal SuperExecutor execution
        testData.userOps[1] =
            _buildNormalExecutionUserOp(testData, nexusAccount, amount, underlyingToken, morphoVault, legitimateNonce);

        // Execute both operations - legitimate execution should succeed despite poisoning attempt
        IMinimalEntryPoint(ENTRYPOINT_ADDR).handleOps(testData.userOps, payable(nexusAccount));

        // Verify the normal execution worked correctly despite poisoning attempt
        uint256 finalShares = IERC4626(morphoVault).balanceOf(nexusAccount);
        assertGt(finalShares, 0, "Normal execution should have succeeded despite poisoning attempt");
    }

    function _buildDirectPoisoningUserOp(
        address maliciousAccount,
        address targetHook,
        address victimAccount,
        string memory functionName,
        uint256 nonce
    )
        internal
        pure
        returns (PackedUserOperation memory userOp)
    {
        bytes memory hookCallData;

        // Build callData for the hook function we want to poison with
        if (keccak256(bytes(functionName)) == keccak256("setExecutionContext")) {
            hookCallData = abi.encodeWithSignature("setExecutionContext(address,bytes)", victimAccount, hex"deadbeef");
        } else if (keccak256(bytes(functionName)) == keccak256("preExecute")) {
            hookCallData =
                abi.encodeWithSignature("preExecute(address,address,bytes)", address(0), victimAccount, hex"deadbeef");
        } else if (keccak256(bytes(functionName)) == keccak256("postExecute")) {
            hookCallData =
                abi.encodeWithSignature("postExecute(address,address,bytes)", address(0), victimAccount, hex"deadbeef");
        } else if (keccak256(bytes(functionName)) == keccak256("setOutAmount")) {
            hookCallData = abi.encodeWithSignature("setOutAmount(uint256,address)", 12_345, victimAccount);
        } else if (keccak256(bytes(functionName)) == keccak256("resetExecutionState")) {
            hookCallData = abi.encodeWithSignature("resetExecutionState(address)", victimAccount);
        } else {
            revert("Unsupported poisoning function");
        }

        // Create malicious userOp with direct hook function call as callData
        // This simulates the attacker directly calling hook functions to poison them
        userOp = _createPackedUserOperation(maliciousAccount, nonce, hookCallData);

        // MockValidator doesn't require real signature validation, use simple signature
        userOp.signature = hex"1234567890"; // Dummy signature since MockValidator always returns valid
    }

    function _buildPoisoningUserOp(
        address nexusAccount,
        address targetHook,
        uint256 nonce
    )
        internal
        view
        returns (PackedUserOperation memory userOp)
    {
        // Create a single execution that calls setExecutionContext on the hook directly
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: targetHook,
            value: 0,
            callData: abi.encodeWithSignature("setExecutionContext(address,bytes)", nexusAccount, hex"deadbeef")
        });

        bytes memory callData = _prepareExecutionCalldata(executions);

        userOp = _createPackedUserOperation(nexusAccount, nonce, callData);

        (bytes memory sigData,,,) = _getSignatureData(userOp, ENTRYPOINT_ADDR);

        userOp.signature = sigData;
    }

    function _buildNormalExecutionUserOp(
        TestData memory testData,
        address nexusAccount,
        uint256 amount,
        address underlyingToken,
        address morphoVault,
        uint256 nonce
    )
        internal
        view
        returns (PackedUserOperation memory userOp)
    {
        // Create normal SuperExecutor execution with deposit and redeem hooks
        testData.hooksAddresses = new address[](4);
        testData.hooksAddresses[0] = approveHook;
        testData.hooksAddresses[1] = deposit4626Hook;
        testData.hooksAddresses[2] = redeem4626Hook;
        testData.hooksAddresses[3] = deposit4626Hook;

        testData.hooksData = new bytes[](4);
        testData.hooksData[0] = _createApproveHookData(underlyingToken, morphoVault, amount, false);
        testData.hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), morphoVault, amount, false, address(0), 0
        );
        testData.hooksData[2] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            morphoVault,
            nexusAccount,
            amount / 2, // Redeem half the expected shares
            false
        );
        testData.hooksData[3] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            morphoVault,
            amount,
            true, // Use previous hook amount
            address(0),
            0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: testData.hooksAddresses, hooksData: testData.hooksData });

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: address(superExecutorModule),
            value: 0,
            callData: abi.encodeWithSelector(ISuperExecutor.execute.selector, abi.encode(entry))
        });

        bytes memory callData = _prepareExecutionCalldata(executions);

        userOp = _createPackedUserOperation(nexusAccount, nonce, callData);

        (bytes memory sigData,,,) = _getSignatureData(userOp, ENTRYPOINT_ADDR);

        userOp.signature = sigData;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    function _assertExecutorIsInitialized(address nexusAccount) internal view {
        bool isSuperExecutorInitialized = superExecutorModule.isInitialized(nexusAccount);
        assertTrue(isSuperExecutorInitialized, "SuperExecutor should be initialized");
    }

    function _assertAccountCreation(address nexusAccount) internal view {
        string memory accountId = INexus(nexusAccount).accountId();
        assertGt(bytes(accountId).length, 0);
        assertEq(accountId, NEXUS_ACCOUNT_IMPLEMENTATION_ID);
    }

    function _installValidatorOnAccount(address account, address validator) internal {
        bytes memory initData = "";
        bytes memory callData = abi.encodeWithSelector(
            IERC7579Account.installModule.selector,
            uint256(1), // TYPE_VALIDATOR
            validator,
            initData
        );

        uint256 nonce = _prepareNonce(account);

        PackedUserOperation memory userOp = _createPackedUserOperation(account, nonce, callData);

        (bytes memory sigData,,,) = _getSignatureData(userOp, ENTRYPOINT_ADDR);
        userOp.signature = sigData;

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;
        IMinimalEntryPoint(ENTRYPOINT_ADDR).handleOps(userOps, payable(address(0x69)));
    }
}

contract MaliciousHook {
    address public owner;
    address public account;
    address public underlying;
    uint256 count;
    uint256 constant MODULE_TYPE_HOOK = 4;

    constructor(address _owner, address _underlying) {
        owner = _owner;
        underlying = _underlying;
    }

    function setAccount(address _account) external {
        account = _account;
    }

    function preCheck(
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        external
        returns (bytes memory hookData)
    {
        // do nothing in precheck
    }

    function postCheck(bytes calldata /*hookData*/ ) external {
        // This check isn't really necessary. However in our poc we batch
        // the approve, deposit and redeem calls in the same execution. Because of this, this
        // postCheck
        // is called three times, after approving, after depositing and after redeeming, so we only
        // want to call this
        // after redeeming. We limit it with a simple, unoptimized solution.
        if (count < 2) {
            count++;
            return;
        }
        // We directly transfer our balance. This will set `outAmount` to 0 in Superform's
        // postExecute call to
        // ERC4626 redeem hook, instead of the actual redeemed amount.
        IERC4626(underlying).transferFrom(account, owner, IERC4626(underlying).balanceOf(account));
    }

    function isModuleType(uint256 moduleTypeID) external pure returns (bool) {
        return moduleTypeID == MODULE_TYPE_HOOK;
    }

    function onInstall(bytes calldata data) external { }
}
