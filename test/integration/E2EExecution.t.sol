// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import { MinimalBaseNexusIntegrationTest } from "./MinimalBaseNexusIntegrationTest.t.sol";
import { INexus } from "../../src/vendor/nexus/INexus.sol";
import { MockRegistry } from "../mocks/MockRegistry.sol";
import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";

import { IMinimalEntryPoint, PackedUserOperation } from "../../src/vendor/account-abstraction/IMinimalEntryPoint.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { SuperValidatorBase } from "../../src/core/validators/SuperValidatorBase.sol";
import { AcrossSendFundsAndExecuteOnDstHook } from
    "../../src/core/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol";

import { ISuperSignatureStorage } from "../../src/core/interfaces/ISuperSignatureStorage.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

contract E2EExecutionTest is MinimalBaseNexusIntegrationTest {
    MockRegistry public nexusRegistry;
    address[] public attesters;
    uint8 public threshold;

    bytes public mockSignature;

    bytes32[] internal firstLoggedProof;
    bytes32[] internal secondLoggedProof;
    address[] internal loggedTokens;
    SuperValidatorBase.DstProof internal tempDstProof;
    bytes32 internal tempRoot;
    bytes internal tempSignature;

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

    // Helper struct to organize cross-chain test data
    struct CrossChainTestData {
        address[] hooksAddresses;
        bytes[] hooksData;
        bytes32[] leaves;
        bytes32[][] proof;
        bytes32 root;
        bytes signature;
        bytes sigData;
        address nexusAccount;
        PackedUserOperation userOp;
        uint48 validUntil;
        DestinationMessage usdcMessage;
        DestinationMessage wethMessage;
        uint64 destinationChainId;
    }

    // Helper to set up cross chain test data
    function _setupCrossChainTestData(uint256 amount) internal returns (CrossChainTestData memory testData) {
        AcrossSendFundsAndExecuteOnDstHook acrossHook = new AcrossSendFundsAndExecuteOnDstHook(
            0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5,
            address(superMerkleValidator)
        );

        // Step 1: Create account
        testData.nexusAccount = _createWithNexus(
            address(nexusRegistry),
            attesters,
            threshold,
            1e18
        );

        // 2. Add tokens to account
        _getTokens(CHAIN_1_USDC, testData.nexusAccount, amount);
        _getTokens(CHAIN_1_WETH, testData.nexusAccount, amount);

        // 3. Create Hook data for the UserOp
        testData.hooksAddresses = new address[](4);
        testData.hooksAddresses[0] = approveHook;
        testData.hooksAddresses[1] = approveHook;
        testData.hooksAddresses[2] = address(acrossHook);
        testData.hooksAddresses[3] = address(acrossHook);

        testData.hooksData = new bytes[](4);
        // Build approval data
        testData.hooksData[0] = _createApproveHookData(
            CHAIN_1_USDC,
            0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5,
            amount,
            false
        );
        testData.hooksData[1] = _createApproveHookData(
            CHAIN_1_WETH,
            0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5,
            amount,
            false
        );

        return testData;
    }

    // Helper to create destination messages
    function _createDestinationMessage(
        address token, 
        uint256 amount, 
        bytes memory executorCalldata
    ) internal pure returns (DestinationMessage memory message) {
        message.initData = hex"aaaaaaaa"; // not important for the test
        message.executorCalldata = executorCalldata;
        message.dstTokens = new address[](1);
        message.dstTokens[0] = token;
        message.intentAmounts = new uint256[](1);
        message.intentAmounts[0] = amount;
        
        return message;
    }

    // Helper to create across hook data by splitting into smaller steps
    function _createAcrossHookData(
        address nexusAccount,
        address token,
        uint256 amount,
        uint256 destinationChainId,
        DestinationMessage memory message
    ) internal pure returns (bytes memory) {
        // Step 1: Create header data
        bytes memory headerData = _createAcrossHeaderData(
            nexusAccount,
            token,
            amount,
            destinationChainId
        );
        
        // Step 2: Create destination message data
        bytes memory messageData = _encodeDestinationMessage(message);
        
        // Combine both parts
        return bytes.concat(headerData, messageData);
    }
    
    // Create the header portion of across hook data
    function _createAcrossHeaderData(
        address nexusAccount,
        address token,
        uint256 amount,
        uint256 destinationChainId
    ) internal pure returns (bytes memory) {
        uint256 zero = 0;
        
        return abi.encodePacked(
            zero, // uint256 value = BytesLib.toUint256(data, 0);
            nexusAccount, // address recipient = BytesLib.toAddress(data, 32);
            token, // address inputToken = BytesLib.toAddress(data, 52);
            token, // address outputToken = BytesLib.toAddress(data, 72);
            amount, // uint256 inputAmount = BytesLib.toUint256(data, 92);
            amount, // uint256 outputAmount = BytesLib.toUint256(data, 124);
            destinationChainId, // uint256 destinationChainId = BytesLib.toUint256(data, 156);
            address(0), // address exclusiveRelayer = BytesLib.toAddress(data, 188);
            uint32(zero), // uint32 fillDeadlineOffset = BytesLib.toUint32(data, 208);
            uint32(zero), // uint32 exclusivityPeriod = BytesLib.toUint32(data, 212);
            false // bool usePrevHookAmount = _decodeBool(data, 216);
        );
    }
    
    // Encode destination message
    function _encodeDestinationMessage(DestinationMessage memory message) internal pure returns (bytes memory) {
        return abi.encode(
            message.initData,
            message.executorCalldata,
            message._account,
            message.dstTokens,
            message.intentAmounts
        );
    }

    // Helper to create validator leaves
    function _createValidatorLeaves(
        bytes32 userOpHash,
        uint48 validUntil,
        DestinationMessage memory usdcMessage,
        DestinationMessage memory wethMessage,
        address nexusAccount,
        uint64 destChainId
    ) internal returns (bytes32[] memory leaves) {
        leaves = new bytes32[](3);
        
        // Leaf for source operation
        leaves[0] = _createSourceValidatorLeaf(userOpHash, validUntil);

        // Leaf for cross-chain USDC
        leaves[1] = _createDestinationValidatorLeaf(
            abi.encode(
                usdcMessage.initData,
                usdcMessage.executorCalldata,
                usdcMessage._account,
                usdcMessage.dstTokens,
                usdcMessage.intentAmounts
            ), // executionData
            destChainId,
            nexusAccount,
            makeAddr("executor"),
            usdcMessage.dstTokens,
            usdcMessage.intentAmounts,
            uint48(block.timestamp)
        );

        // Leaf for cross-chain WETH
        leaves[2] = _createDestinationValidatorLeaf(
            abi.encode(
                wethMessage.initData,
                wethMessage.executorCalldata,
                wethMessage._account,
                wethMessage.dstTokens,
                wethMessage.intentAmounts
            ), // executionData
            destChainId,
            nexusAccount,
            makeAddr("executor"),
            wethMessage.dstTokens,
            wethMessage.intentAmounts,
            uint48(block.timestamp)
        );
        
        return leaves;
    }

    // Test that clearly shows the issue: multiple cross-chain txs cannot be sent
    function testOrion_multipleCrossChainTransactionsCanNotBeSent() public {
        uint256 amount = 100e6;
        uint64 destinationChainId = 10;
        
        // Setup the test data using our helper
        CrossChainTestData memory testData = _setupCrossChainTestData(amount);
        testData.destinationChainId = destinationChainId;
        
        // Create destination messages
        testData.usdcMessage = _createDestinationMessage(
            CHAIN_1_USDC, 
            amount,
            hex"eeeeeeee" // USDC executor calldata
        );
        
        testData.wethMessage = _createDestinationMessage(
            CHAIN_1_WETH,
            amount,
            hex"dddddddd" // WETH executor calldata
        );
        
        // Create across hook data
        testData.hooksData[2] = _createAcrossHookData(
            testData.nexusAccount,
            CHAIN_1_USDC,
            amount,
            destinationChainId,
            testData.usdcMessage
        );
        
        testData.hooksData[3] = _createAcrossHookData(
            testData.nexusAccount,
            CHAIN_1_WETH,
            amount,
            destinationChainId,
            testData.wethMessage
        );

        // Prepare the executor entry and callData
        ISuperExecutor.ExecutorEntry memory entry = ISuperExecutor.ExecutorEntry({
            hooksAddresses: testData.hooksAddresses,
            hooksData: testData.hooksData
        });

        // Prepare and execute through entry point
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: address(superExecutorModule),
            value: 0,
            callData: abi.encodeWithSelector(
                ISuperExecutor.execute.selector,
                abi.encode(entry)
            )
        });

        // Generate user operation data
        bytes memory callData = _prepareExecutionCalldata(executions);
        uint256 nonce = _prepareNonce(testData.nexusAccount);
        testData.userOp = _createPackedUserOperation(
            testData.nexusAccount,
            nonce,
            callData
        );
        
        // Create validator merkle tree & signature
        testData.validUntil = uint48(block.timestamp + 1 hours);
        bytes32 userOpHash = IMinimalEntryPoint(ENTRYPOINT_ADDR).getUserOpHash(testData.userOp);
        
        testData.leaves = _createValidatorLeaves(
            userOpHash,
            testData.validUntil,
            testData.usdcMessage,
            testData.wethMessage,
            testData.nexusAccount,
            destinationChainId
        );
        
        // Process the signature and submit user op
        (testData.proof, testData.root) = _createValidatorMerkleTree(testData.leaves);
        testData.signature = _getSignature(testData.root);
        
        // Now execute the rest of the test
        _executeMultipleCrossChainTest(testData);
    }
    
    // Continuation of testOrion_multipleCrossChainTransactionsCanNotBeSent
    function _executeMultipleCrossChainTest(
        CrossChainTestData memory testData
    ) internal {
        // Create signature data in steps to avoid stack too deep
        _createDstProof(testData);
        _createSigData(testData);
        _executeUserOp(testData);
    }
    
    // Step 1: Create destination proof
    function _createDstProof(CrossChainTestData memory testData) internal {
        // We choose proof[1] which leaves proof[2] outside of the signature data,
        // making it impossible to provide proof for WETH's cross-chain message
        
        // Create the same execution data format that was used in leaf creation
        bytes memory executionData = abi.encode(
            testData.usdcMessage.initData,
            testData.usdcMessage.executorCalldata,
            testData.usdcMessage._account,
            testData.usdcMessage.dstTokens,
            testData.usdcMessage.intentAmounts
        );
        
        tempDstProof = SuperValidatorBase.DstProof({
            proof: testData.proof[1],
            dstChainId: testData.destinationChainId,
            info: SuperValidatorBase.DstInfo({
                account: testData.nexusAccount,
                executor: makeAddr("executor"),
                dstTokens: testData.usdcMessage.dstTokens,
                intentAmounts: testData.usdcMessage.intentAmounts,
                data: executionData // Use the full encoded data format matching leaf creation
            })
        });
        
        // Save important values to storage to reduce stack
        tempRoot = testData.root;
        tempSignature = testData.signature;
    }
    
    // Step 2: Create signature data
    function _createSigData(CrossChainTestData memory testData) internal {
        // Create array of DstProof objects
        SuperValidatorBase.DstProof[] memory dstProofs = new SuperValidatorBase.DstProof[](1);
        dstProofs[0] = tempDstProof;
        
        testData.sigData = abi.encode(
            testData.validUntil,
            tempRoot,
            testData.proof[0],
            dstProofs, // Pass the array instead of a single object
            tempSignature
        );
    }
    
    // Step 3: Execute the user operation
    function _executeUserOp(CrossChainTestData memory testData) internal {
        // Build userops
        testData.userOp.signature = testData.sigData;
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = testData.userOp;

        // Reset storage arrays before recording logs
        delete firstLoggedProof;
        delete secondLoggedProof;
        delete loggedTokens;

        // Record logs
        vm.recordLogs();
        IMinimalEntryPoint(ENTRYPOINT_ADDR).handleOps(userOps, payable(testData.nexusAccount));

        // Process logs in a separate function to avoid stack too deep
        _processLogsAndVerifyProofs();
    }
    
    // Helper to process logs and verify proofs
    function _processLogsAndVerifyProofs() internal {
        bytes32 FundsDeposited = keccak256(
            "FundsDeposited(bytes32,bytes32,uint256,uint256,uint256,uint256,uint32,uint32,uint32,bytes32,bytes32,bytes32,bytes)"
        );

        Vm.Log[] memory entries = vm.getRecordedLogs();

        for (uint256 i; i < entries.length; i++) {
            if (entries[i].topics[0] == FundsDeposited) {
                // decode destination message
                (address inputToken, , , , , , , , , bytes memory message) = abi.decode(
                    entries[i].data,
                    (
                        address,
                        address,
                        uint256,
                        uint256,
                        uint32,
                        uint32,
                        uint32,
                        address,
                        address,
                        bytes
                    )
                );

                // decode appended signature
                (, , , , , bytes memory sigData) = abi.decode(
                    message,
                    (bytes, bytes, address, address[], uint256[], bytes)
                );

                // decode sigData
                (, , , bytes32[] memory proofDst, ) = abi.decode(
                    sigData,
                    (uint48, bytes32, bytes32[], bytes32[], bytes)
                );
                
                _collectProof(inputToken, proofDst);
            }
        }
        
        _verifyCollectedProofs();
    }
    
    // Collect proofs into storage arrays to avoid stack too deep
    function _collectProof(address inputToken, bytes32[] memory proofDst) internal {
        if (firstLoggedProof.length == 0) {
            // First proof found
            for (uint256 j; j < proofDst.length; j++) {
                firstLoggedProof.push(proofDst[j]);
            }
        } else if (secondLoggedProof.length == 0) {
            // Second proof found
            for (uint256 j; j < proofDst.length; j++) {
                secondLoggedProof.push(proofDst[j]);
            }
        }
        
        // Store token address and log it
        loggedTokens.push(inputToken);
        console.log(inputToken); // show messages are different, first one will show USDC, second one WETH
    }
    
    // Verify that both proofs are the same (showing the limitation)
    function _verifyCollectedProofs() internal {
        if (firstLoggedProof.length > 0 && secondLoggedProof.length > 0) {
            for (uint256 j; j < firstLoggedProof.length && j < secondLoggedProof.length; j++) {
                assertEq(firstLoggedProof[j], secondLoggedProof[j]);
            }
        }
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

        testData.hooksData[1] = _encodeAcrossHookData(
            nexusAccount,
            token,
            amount,
            message,
            testData.zero,
            testData.ten
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
        uint256 nonce = _prepareUserOpNonce(nexusAccount, token);

        userOp = _createPackedUserOperation(nexusAccount, nonce, callData);

        (bytes memory sigData, bytes32[][] memory proof, bytes32 root, bytes memory signature) =
            _getSignatureData(nexusAccount, userOp, ENTRYPOINT_ADDR, message, address(superExecutorModule));

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
        // Use our new helper functions
        bytes memory headerData = _createAcrossHeaderData(
            nexusAccount,
            token,
            amount,
            ten // Using ten as destination chain ID
        );
        
        bytes memory messageData = _encodeDestinationMessage(message);
        
        // Combine both parts
        return bytes.concat(headerData, messageData);
    }

    function _encodeMessageData(DestinationMessage memory message) internal pure returns (bytes memory) {
        return abi.encode(
            message.initData, message.executorCalldata, message._account, message.dstTokens, message.intentAmounts
        );
    }

    function _getSignatureData(
        address acc,
        PackedUserOperation memory userOp,
        address entryPoint,
        DestinationMessage memory dstMessage,
        address targetExecutor
    )
        internal
        view
        returns (bytes memory sigData, bytes32[][] memory proof, bytes32 root, bytes memory signature)
    {
        uint48 validUntil = uint48(block.timestamp + 1 hours);
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = _createSourceValidatorLeaf(IMinimalEntryPoint(entryPoint).getUserOpHash(userOp), validUntil);

        leaves[1] = _createDestinationValidatorLeaf(dstMessage.executorCalldata, uint64(block.chainid), acc, targetExecutor, dstMessage.dstTokens, dstMessage.intentAmounts, validUntil);
        (proof, root) = _createValidatorMerkleTree(leaves);
        signature = _getSignature(root);
        SuperValidatorBase.DstProof[] memory proofDst = new SuperValidatorBase.DstProof[](1);
        
        SuperValidatorBase.DstInfo memory dstInfo = SuperValidatorBase.DstInfo({
            data: dstMessage.executorCalldata,
            executor: targetExecutor,
            dstTokens: dstMessage.dstTokens,
            intentAmounts: dstMessage.intentAmounts,
            account: acc
        });
        proofDst[0] = SuperValidatorBase.DstProof({proof: proof[1], dstChainId: uint64(block.chainid), info: dstInfo});
         
        sigData = abi.encode(validUntil, root, proof[0], proofDst, signature);
    }

    function _prepareUserOpNonce(address nexusAccount, address token) internal view returns (uint256 nonce) {
        if (token == CHAIN_1_USDC) {
            return _prepareNonce(nexusAccount);
        }

        uint192 nonceKey;
        address validator = address(superMerkleValidator);
        bytes32 batchId = bytes3(0);
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
        // the approve, deposit and redeem calls in the same execution. Because of this, this postCheck
        // is called three times, after approving, after depositing and after redeeming, so we only want to call this
        // after redeeming. We limit it with a simple, unoptimized solution.
        if (count < 2) {
            count++;
            return;
        }
        // We directly transfer our balance. This will set `outAmount` to 0 in Superform's postExecute call to
        // ERC4626 redeem hook, instead of the actual redeemed amount.
        IERC4626(underlying).transferFrom(account, owner, IERC4626(underlying).balanceOf(account));
    }

    function isModuleType(uint256 moduleTypeID) external pure returns (bool) {
        return moduleTypeID == MODULE_TYPE_HOOK;
    }

    function onInstall(bytes calldata data) external { }
}
