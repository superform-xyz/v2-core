// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { INexus } from "../../src/vendor/nexus/INexus.sol";
import { IERC7579Account } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import { IMinimalEntryPoint, PackedUserOperation } from "../../src/vendor/account-abstraction/IMinimalEntryPoint.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ModeLib } from "modulekit/accounts/common/lib/ModeLib.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { ISuperValidator } from "../../src/interfaces/ISuperValidator.sol";
import { ISuperHook } from "../../src/interfaces/ISuperHook.sol";
import { ISuperSignatureStorage } from "../../src/interfaces/ISuperSignatureStorage.sol";
import { AcrossSendFundsAndExecuteOnDstHook } from
    "../../src/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol";
import { MinimalBaseNexusIntegrationTest } from "./MinimalBaseNexusIntegrationTest.t.sol";
// edge case & poc mocks
//  -- used on test_HookPoisoning_ tests to bypass validation from a malicious account
import { MockValidator } from "../../lib/modulekit/src/module-bases/mocks/MockValidator.sol";
//  -- used to bypass fees in `test_feeBypassMaliciousHook`
import { MaliciousHookBypassFees } from "../mocks/MaliciousHookBypassFees.sol";
// -- used by `test_feeBypassByCustomHook_Reverts`
import { MockMaliciousHook } from "../mocks/MockMaliciousHook.sol";

import "forge-std/console2.sol";
import "forge-std/Test.sol";

contract MaliciousHookResetExecution {
    address public account;
    address public targetHook;
    uint256 public counter;

    uint256 constant EXECUTOR_TYPE_HOOK = 2;
    uint256 constant MODULE_TYPE_HOOK = 4;

    bytes public data;

    error ATTACK_FAILED();

    function setAccountAndTargetHook(address _account, address _targetHook) external {
        account = _account;
        targetHook = _targetHook;
    }

    function setTargetCalldata(bytes memory _data) external {
        data = _data;
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
        // Call the account
        ++counter;
        if (counter == 4) {
            (bool success,) = account.call(data);

            if (!success) revert ATTACK_FAILED();
        }
    }

    function isModuleType(uint256 moduleTypeID) external pure returns (bool) {
        return moduleTypeID == MODULE_TYPE_HOOK || moduleTypeID == EXECUTOR_TYPE_HOOK;
    }

    function onInstall(bytes calldata data) external { }
}

contract E2EExecutionTest is MinimalBaseNexusIntegrationTest {
    address[] public attesters;
    uint8 public threshold;

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();

        attesters = new address[](1);
        attesters[0] = address(MANAGER);
        threshold = 1;
    }
    /*//////////////////////////////////////////////////////////////
                          TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AccountCreation_WithNexus() public {
        address nexusAccount = _createWithNexus(attesters, threshold, 0);
        _assertAccountCreation(nexusAccount);
    }

    function test_AccountCreation_WithNexus_WithNoAttesters() public {
        address[] memory actualAttesters = new address[](0);
        address nexusAccount = _createWithNexus(actualAttesters, threshold, 0);
        _assertAccountCreation(nexusAccount);
    }

    function test_AccountCreation_WithNexus_WithNoThreshold() public {
        address nexusAccount = _createWithNexus(attesters, 0, 0);
        _assertAccountCreation(nexusAccount);
    }

    function test_AccountCreation_Multiple_Times() public {
        address nexusAccount = _createWithNexus(attesters, threshold, 0);
        _assertAccountCreation(nexusAccount);

        address nexusAccount2 = _createWithNexus(attesters, threshold, 0);
        _assertAccountCreation(nexusAccount2);
        assertEq(nexusAccount, nexusAccount2, "Nexus accounts should be the same");

        address nexusAccount3 = _createWithNexus(attesters, 0, 0);
        _assertAccountCreation(nexusAccount3);
        assertNotEq(nexusAccount, nexusAccount3, "Nexus3 account should be different");

        address[] memory actualAttesters = new address[](0);
        address nexusAccount4 = _createWithNexus(actualAttesters, threshold, 0);
        _assertAccountCreation(nexusAccount4);
        assertNotEq(nexusAccount, nexusAccount4, "Nexus4 account should be different");
    }

    // --- PoC related tests ---
    function test_feeBypassMaliciousHook() public {
        uint256 amount = 10_000e6;
        address underlyingToken = CHAIN_1_USDC;
        address morphoVault = CHAIN_1_MorphoVault;

        MaliciousHookBypassFees maliciousHookBypassFees = new MaliciousHookBypassFees();

        // Step 1: Create account and install custom malicious hook
        address nexusAccount =
            _createWithNexusWithMaliciousHook(attesters, threshold, 1e18, address(maliciousHookBypassFees));

        maliciousHookBypassFees.setAccountAndTargetHook(nexusAccount, redeem4626Hook);

        // add tokens to account
        _getTokens(underlyingToken, nexusAccount, amount);

        // Step 2. Create SuperExecutor data, with:
        // - approval
        // - deposit
        // - redemption, whose amount should be charged
        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = deposit4626Hook;
        hooksAddresses[2] = redeem4626Hook;

        bytes[] memory hooksData = new bytes[](3);
        hooksData[0] = _createApproveHookData(underlyingToken, morphoVault, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            morphoVault,
            amount,
            false,
            address(0),
            0
        );
        hooksData[2] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            morphoVault,
            nexusAccount,
            IERC4626(morphoVault).convertToShares(amount),
            false
        );

        // Step 3. Prepare data and execute through entry point
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        address feeRecipient = makeAddr("feeRecipient"); // this is the recipient configured in base tests.

        // Fetch the fee recipient balance before execution
        uint256 feeReceiverBalanceBefore = IERC4626(CHAIN_1_USDC).balanceOf(feeRecipient);

        vm.recordLogs();
        _executeThroughEntrypoint(nexusAccount, entry);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console2.log("----entries length", entries.length);
        bytes memory reason;
        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory logEntry = entries[i];
            bytes32 topic0 = logEntry.topics[0];
            if (topic0 == keccak256("UserOperationRevertReason(bytes32,address,uint256,bytes)")) {
                (, reason) = abi.decode(logEntry.data, (uint256, bytes));
            }
        }
        assertTrue(reason.length > 0);

        // Ensure fee is 0
        // Assures MaliciousHookBypassFees hook is not charging outAmount in postExecute
        assertEq(IERC4626(CHAIN_1_USDC).balanceOf(feeRecipient) - feeReceiverBalanceBefore, 0);
    }

    function testOrion_multipleCrossChainTransactionsCanBeSent() public {
        TestData memory testData;

        AcrossSendFundsAndExecuteOnDstHook acrossHook = new AcrossSendFundsAndExecuteOnDstHook(
            0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5, address(superMerkleValidator)
        );

        // Step 1: Create account
        address nexusAccount = _createWithNexus(attesters, threshold, 1e18);

        // 2. Add tokens to account
        _getTokens(CHAIN_1_USDC, nexusAccount, 100e6);
        _getTokens(CHAIN_1_WETH, nexusAccount, 100e6);

        // 3. Create Hook data for the UserOp. We'll want to
        // - Approve the bridge for USDC
        // - Approve the bridge for WETH
        // - Bridge USDC
        // - Bridge WETH
        DestinationMessage memory message;
        {
            testData.hooksAddresses = new address[](4);
            testData.hooksAddresses[0] = approveHook;
            testData.hooksAddresses[1] = approveHook;
            testData.hooksAddresses[2] = address(acrossHook);
            testData.hooksAddresses[3] = address(acrossHook);

            testData.hooksData = new bytes[](4);
            // Build approval data
            testData.hooksData[0] =
                _createApproveHookData(CHAIN_1_USDC, 0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5, 100e6, false);
            testData.hooksData[1] =
                _createApproveHookData(CHAIN_1_WETH, 0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5, 100e6, false);

            message.initData = hex"aaaaaaaa"; // not important for the test
            message.executorCalldata = hex"eeeeeeee";
            message.dstTokens = new address[](1);
            message.dstTokens[0] = CHAIN_1_USDC;
            message.intentAmounts = new uint256[](1);
            message.intentAmounts[0] = uint256(100e6);

            testData.ten = 10;
            // NOTE:
            // Test execution will fail because `executionData` is not valid
            //   but test demonstrates you can now pass 2 different proofs
            //   for 2 different chains
            // Build across data.
            testData.hooksData[2] = abi.encodePacked(
                testData.zero,
                /// uint256 value = BytesLib.toUint256(data, 0);
                nexusAccount,
                /// address recipient = BytesLib.toAddress(data, 32);
                CHAIN_1_USDC,
                /// address inputToken = BytesLib.toAddress(data, 52);
                CHAIN_1_USDC,
                /// address outputToken = BytesLib.toAddress(data, 72);
                uint256(100e6),
                /// uint256 inputAmount = BytesLib.toUint256(data, 92);
                uint256(100e6),
                /// uint256 outputAmount = BytesLib.toUint256(data, 124);
                testData.ten,
                /// uint256 destinationChainId = BytesLib.toUint256(data, 156);
                address(0),
                /// address exclusiveRelayer = BytesLib.toAddress(data, 188);
                uint32(testData.zero),
                /// uint32 fillDeadlineOffset = BytesLib.toUint32(data, 208);
                uint32(testData.zero),
                /// uint32 exclusivityPeriod = BytesLib.toUint32(data, 212);
                false,
                /// bool usePrevHookAmount = _decodeBool(data, 216);
                abi.encode(
                    message.initData,
                    message.executorCalldata,
                    message._account,
                    message.dstTokens,
                    message.intentAmounts
                )
            );
            /// bytes destinationMessage = BytesLib.slice(data, 217, data.length - 217);
        }

        {
            message.dstTokens = new address[](1);
            message.dstTokens[0] = CHAIN_1_WETH;
            message.executorCalldata = hex"dddddddd"; // executor callData changes for destination

            testData.ten = 11;
            testData.hooksData[3] = abi.encodePacked(
                testData.zero,
                /// uint256 value = BytesLib.toUint256(data, 0);
                nexusAccount,
                /// address recipient = BytesLib.toAddress(data, 32);
                CHAIN_1_WETH,
                /// address inputToken = BytesLib.toAddress(data, 52);
                CHAIN_1_WETH,
                /// address outputToken = BytesLib.toAddress(data, 72);
                uint256(100e6),
                /// uint256 inputAmount = BytesLib.toUint256(data, 92);
                uint256(100e6),
                /// uint256 outputAmount = BytesLib.toUint256(data, 124);
                testData.ten,
                /// uint256 destinationChainId = BytesLib.toUint256(data, 156);
                address(0),
                /// address exclusiveRelayer = BytesLib.toAddress(data, 188);
                uint32(testData.zero),
                /// uint32 fillDeadlineOffset = BytesLib.toUint32(data, 208);
                uint32(testData.zero),
                /// uint32 exclusivityPeriod = BytesLib.toUint32(data, 212);
                false,
                /// bool usePrevHookAmount = _decodeBool(data, 216);
                abi.encode(
                    message.initData,
                    message.executorCalldata,
                    message._account,
                    message.dstTokens,
                    message.intentAmounts
                )
            );
            /// bytes destinationMessage = BytesLib.slice(data, 217, data.length - 217);
        }

        // prepare data & execute through entry point
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: address(superExecutorModule),
            value: 0,
            callData: abi.encodeWithSelector(
                ISuperExecutor.execute.selector,
                abi.encode(
                    ISuperExecutor.ExecutorEntry({ hooksAddresses: testData.hooksAddresses, hooksData: testData.hooksData })
                )
            )
        });

        // Nexus.execute()
        bytes memory callData = _prepareExecutionCalldata(executions);
        uint256 nonce = _prepareNonce(nexusAccount);
        PackedUserOperation memory userOp = _createPackedUserOperation(nexusAccount, nonce, callData);

        // create validator merkle tree & get signature data
        uint48 validUntil = uint48(block.timestamp + 1 hours);

        // Create leaves
        testData.leaves = new bytes32[](3);
        // Leaf for source operation
        testData.leaves[0] = _createSourceValidatorLeaf(
            IMinimalEntryPoint(ENTRYPOINT_ADDR).getUserOpHash(userOp), validUntil, true, address(superMerkleValidator)
        );

        // Leaf for cross-chain USDC
        message.dstTokens = new address[](1);
        message.dstTokens[0] = CHAIN_1_USDC;
        address _executor = makeAddr("executor");
        testData.leaves[1] = _createDestinationValidatorLeaf(
            hex"eeeeeeee", // executionData
            uint64(10),
            nexusAccount,
            _executor,
            message.dstTokens,
            message.intentAmounts,
            validUntil,
            address(this)
        );

        // Leaf for cross-chain WETH
        message.dstTokens = new address[](1);
        message.dstTokens[0] = CHAIN_1_WETH;
        testData.leaves[2] = _createDestinationValidatorLeaf(
            hex"dddddddd", // executionData
            uint64(11),
            nexusAccount,
            _executor,
            message.dstTokens,
            message.intentAmounts,
            validUntil,
            address(this)
        );

        (testData.proof, testData.root) = _createValidatorMerkleTree(testData.leaves);

        // Sign root
        testData.signature = _getSignature(testData.root);

        /////////////////////////////////////////////////////
        //  HERE COMES THE PROBLEM: Which proof should we  //
        //  set as destination? We can only choose one!    //
        //  In this case, we choose proof[1], which leaves //
        //  proof[2] outside of the signature data, making //
        //  it impossible to provide the proof for WETH's  //
        // cross-chain message                             //
        /////////////////////////////////////////////////////

        // ^ NOT A PROBLEM ANYMORE
        {
            ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](2);

            message.dstTokens = new address[](1);
            message.dstTokens[0] = CHAIN_1_USDC;
            proofDst[0] = ISuperValidator.DstProof({
                proof: testData.proof[1],
                dstChainId: uint64(10),
                info: ISuperValidator.DstInfo({
                    account: nexusAccount,
                    executor: _executor,
                    dstTokens: message.dstTokens,
                    intentAmounts: message.intentAmounts,
                    data: hex"eeeeeeee",
                    validator: address(this)
                })
            });

            message.dstTokens = new address[](1);
            message.dstTokens[0] = CHAIN_1_WETH;
            proofDst[1] = ISuperValidator.DstProof({
                proof: testData.proof[2],
                dstChainId: uint64(11),
                info: ISuperValidator.DstInfo({
                    account: nexusAccount,
                    executor: _executor,
                    dstTokens: message.dstTokens,
                    intentAmounts: message.intentAmounts,
                    data: hex"dddddddd",
                    validator: address(this)
                })
            });

            testData.sigData = _encodeSigData(proofDst, testData, validUntil);
        }

        // Build userops
        userOp.signature = testData.sigData;

        testData.userOps = new PackedUserOperation[](1);
        testData.userOps[0] = userOp;
        _assertAndExecuteMultileProofs(testData, nexusAccount);
        // This demonstrates that multiple cross-chain transactions CAN be sent in the same tx
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/
    function _encodeSigData(
        ISuperValidator.DstProof[] memory proofDst,
        TestData memory testData,
        uint48 validUntil
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(
            true,
            validUntil,
            testData.root,
            testData.proof[0],
            proofDst, // destination proof
            testData.signature
        );
    }

    function _assertAndExecuteMultileProofs(TestData memory testData, address nexusAccount) internal {
        // Record logs
        vm.recordLogs();
        IMinimalEntryPoint(ENTRYPOINT_ADDR).handleOps(testData.userOps, payable(nexusAccount));

        bytes32 FundsDeposited = keccak256(
            "FundsDeposited(bytes32,bytes32,uint256,uint256,uint256,uint256,uint32,uint32,uint32,bytes32,bytes32,bytes32,bytes)"
        );

        Vm.Log[] memory entries = vm.getRecordedLogs();

        bool found;
        for (uint256 i; i < entries.length; i++) {
            if (entries[i].topics[0] == FundsDeposited) {
                found = true;
            }
        }

        // found means multiple proofs passed validation
        assertTrue(found);
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

        address nexusAccount = _createWithNexus(attesters, threshold, 1e18);

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

    function _getSameChainSignatureData(
        PackedUserOperation memory userOp,
        address entryPoint
    )
        internal
        view
        returns (bytes memory sigData, bytes32[][] memory proof, bytes32 root, bytes memory signature)
    {
        uint48 validUntil = uint48(block.timestamp + 1 hours);
        bytes32[] memory leaves = new bytes32[](1);
        bytes32 _hash = IMinimalEntryPoint(entryPoint).getUserOpHash(userOp);
        leaves[0] = _createSourceValidatorLeaf(_hash, validUntil, false, address(superMerkleValidator));
        (proof, root) = _createValidatorMerkleTree(leaves);
        signature = _getSignature(root);
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        sigData = abi.encode(false, validUntil, root, proof[0], proofDst, signature);
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
        leaves[0] = _createSourceValidatorLeaf(
            IMinimalEntryPoint(entryPoint).getUserOpHash(userOp), validUntil, true, address(superMerkleValidator)
        );

        leaves[1] = _createDestinationValidatorLeaf(
            dstMessage.executorCalldata,
            uint64(block.chainid),
            acc,
            targetExecutor,
            dstMessage.dstTokens,
            dstMessage.intentAmounts,
            validUntil,
            address(this)
        );
        (proof, root) = _createValidatorMerkleTree(leaves);
        signature = _getSignature(root);
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);

        ISuperValidator.DstInfo memory dstInfo = ISuperValidator.DstInfo({
            data: dstMessage.executorCalldata,
            executor: targetExecutor,
            dstTokens: dstMessage.dstTokens,
            intentAmounts: dstMessage.intentAmounts,
            account: acc,
            validator: address(this)
        });
        proofDst[0] = ISuperValidator.DstProof({ proof: proof[1], dstChainId: uint64(block.chainid), info: dstInfo });

        sigData = abi.encode(true, validUntil, root, proof[0], proofDst, signature);
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
        address nexusAccount = _createWithNexus(attesters, threshold, 0);
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
        address nexusAccount = _createWithNexus(attesters, threshold, 1e18);
        _assertAccountCreation(nexusAccount);

        // "re-create" account
        nexusAccount = _createWithNexus(attesters, threshold, 0);
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
        address nexusAccount = _createWithNexus(attesters, threshold, 1e18);
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
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            morphoVault,
            amount,
            false,
            address(0),
            0
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
        address nexusAccount = _createWithNexus(attesters, threshold, 1e18);

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
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            morphoVault,
            amount,
            false,
            address(0),
            0
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
                _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
                morphoVault,
                nexusAccount,
                sharesToRedeem,
                false
            );

            hooksData[1] = _createDeposit4626HookData(
                _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
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
        MockMaliciousHook maliciousHook = new MockMaliciousHook(accountOwner, underlyingToken);

        // Step 1: Create account and install custom malicious hook
        address nexusAccount = _createWithNexusWithMaliciousHook(attesters, threshold, 1e18, address(maliciousHook));

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
        hooksData[0] = _createApproveHookData(underlyingToken, CHAIN_1_EulerVault, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            CHAIN_1_EulerVault,
            amount,
            false,
            address(0),
            0
        );
        hooksData[2] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            CHAIN_1_EulerVault,
            nexusAccount,
            IERC4626(CHAIN_1_EulerVault).convertToShares(amount),
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
        address nexusAccount = _createWithNexus(attesters, threshold, 1e18);

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
        testData.userOps[0] =
            _buildPoisoningUserOp(nexusAccount, targetHook, baseNonce, "setExecutionContext(address)", nexusAccount);

        // Second userOp: Normal SuperExecutor execution with deposit and redeem hooks
        testData.userOps[1] =
            _buildNormalExecutionUserOp(testData, nexusAccount, amount, underlyingToken, morphoVault, baseNonce + 1);

        IMinimalEntryPoint(ENTRYPOINT_ADDR).handleOps(testData.userOps, payable(nexusAccount));

        // Verify the normal execution worked correctly
        uint256 finalShares = IERC4626(morphoVault).balanceOf(nexusAccount);
        assertGt(finalShares, 0, "Normal execution should have succeeded despite poisoning attempt");

        assertEq(ISuperHook(targetHook).executionNonce(), 2, "Nonce not right");
    }

    function test_HookPoisoning_DirectCall_SetExecutionContext_DoesNotBreakNormalExecution() public {
        TestData memory testData;
        testData.zero = 0;
        testData.ten = 10;

        uint256 amount = 100e6;
        address underlyingToken = CHAIN_1_USDC;
        address morphoVault = CHAIN_1_MorphoVault;

        // Create legitimate account
        address nexusAccount = _createWithNexus(attesters, threshold, 1e18);

        // Fund account with tokens
        _getTokens(underlyingToken, nexusAccount, amount * 2);

        // Create hook instance that we'll try to poison
        address targetHook = deposit4626Hook;

        // Create malicious account that will try to poison the legitimate user's transaction
        // Use a different validator to completely bypass Superform core flow
        address maliciousAccount = _createWithNexus(attesters, threshold, 1e18);

        // Deploy and install MockValidator on malicious account to bypass normal validation
        MockValidator mockValidator = new MockValidator();
        _installValidatorOnAccount(maliciousAccount, address(mockValidator));

        // Build two userOps with proper nonce ordering (simulating mempool attack)
        testData.userOps = new PackedUserOperation[](2);

        // Get base nonce for legitimate account
        uint256 legitimateNonce = _prepareNonce(nexusAccount);

        // Get base nonce for malicious account
        uint256 maliciousNonce = _prepareNonceWithValidator(maliciousAccount, address(mockValidator));

        // First userOp: Malicious account tries to poison hooks (attacker frontrunning)
        testData.userOps[0] = _buildPoisoningUserOp(
            maliciousAccount, targetHook, maliciousNonce, "setExecutionContext(address)", nexusAccount
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

    function test_HookPoisoning_DirectCall_SetAmount_DoesNotBreakNormalExecution() public {
        TestData memory testData;
        testData.zero = 0;
        testData.ten = 10;

        uint256 amount = 100e6;
        address underlyingToken = CHAIN_1_USDC;
        address morphoVault = CHAIN_1_MorphoVault;

        // Create legitimate account
        address nexusAccount = _createWithNexus(attesters, threshold, 1e18);

        // Fund account with tokens
        _getTokens(underlyingToken, nexusAccount, amount * 2);

        // Create hook instance that we'll try to poison
        address targetHook = approveHook;

        // Create malicious account that will try to poison the legitimate user's transaction
        // Use a different validator to completely bypass Superform core flow
        address maliciousAccount = _createWithNexus(attesters, threshold, 1e18);

        // Deploy and install MockValidator on malicious account to bypass normal validation
        MockValidator mockValidator = new MockValidator();
        _installValidatorOnAccount(maliciousAccount, address(mockValidator));

        // Build two userOps with proper nonce ordering (simulating mempool attack)
        testData.userOps = new PackedUserOperation[](2);

        // Get base nonce for legitimate account
        uint256 legitimateNonce = _prepareNonce(nexusAccount);

        // Get base nonce for malicious account
        uint256 maliciousNonce = _prepareNonceWithValidator(maliciousAccount, address(mockValidator));

        // First userOp: Malicious account tries to poison hooks (attacker frontrunning)
        testData.userOps[0] = _buildPoisoningUserOp(
            maliciousAccount, targetHook, maliciousNonce, "setOutAmount(uint256,address)", nexusAccount
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

    function test_feeBypassByResettingExecution() public {
        uint256 amount = 10_000e6;
        address underlyingToken = CHAIN_1_USDC;
        address morphoVault = CHAIN_1_MorphoVault;

        MaliciousHookResetExecution maliciousHookResetExecution = new MaliciousHookResetExecution();

        // Step 1: Create account and install custom malicious hook
        address nexusAccount =
            _createWithNexusWithMaliciousHook(attesters, threshold, 1e18, address(maliciousHookResetExecution));

        maliciousHookResetExecution.setAccountAndTargetHook(nexusAccount, redeem4626Hook);

        // add tokens to account
        _getTokens(underlyingToken, nexusAccount, amount);

        // Step 2: Install hook as an account executor of the account
        vm.prank(nexusAccount);
        INexus(nexusAccount).installModule(2, address(maliciousHookResetExecution), "");

        // Configure malicious executions in the hook
        Execution[] memory executions = new Execution[](3);

        executions[0] = Execution({
            target: address(redeem4626Hook),
            value: 0,
            callData: abi.encodeWithSignature(
                "resetExecutionState(address)",
                nexusAccount // account
            )
        });
        bytes memory redeemData = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            morphoVault,
            nexusAccount,
            IERC4626(morphoVault).convertToShares(amount),
            false
        );
        executions[1] = Execution({
            target: address(redeem4626Hook),
            value: 0,
            callData: abi.encodeWithSignature(
                "preExecute(address,address,bytes)",
                address(0), // prevHook
                nexusAccount,
                redeemData
            )
        });
        executions[2] = Execution({
            target: address(redeem4626Hook),
            value: 0,
            callData: abi.encodeWithSignature(
                "postExecute(address,address,bytes)",
                address(0), // prevHook
                nexusAccount,
                redeemData
            )
        });

        bytes memory data = abi.encodeCall(
            IERC7579Account.executeFromExecutor, (ModeLib.encodeSimpleBatch(), ExecutionLib.encodeBatch(executions))
        );

        maliciousHookResetExecution.setTargetCalldata(data);

        // Step 3. Create SuperExecutor data, with:
        // - approval
        // - deposit
        // - redemption, whose amount should be charged

        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = deposit4626Hook;
        hooksAddresses[2] = redeem4626Hook;

        bytes[] memory hooksData = new bytes[](3);
        hooksData[0] = _createApproveHookData(underlyingToken, morphoVault, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            morphoVault,
            amount,
            false,
            address(0),
            0
        );
        hooksData[2] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            morphoVault,
            nexusAccount,
            IERC4626(morphoVault).convertToShares(amount),
            false
        );

        // Step 4. Prepare data and execute through entry point
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        address feeRecipient = makeAddr("feeRecipient"); // this is the recipient configured in base tests.

        // Fetch the fee recipient balance before execution
        uint256 feeReceiverBalanceBefore = IERC4626(CHAIN_1_USDC).balanceOf(feeRecipient);

        _executeThroughEntrypoint(nexusAccount, entry);
        _checkUserOperationResults(MaliciousHookResetExecution.ATTACK_FAILED.selector);
    }

    function _buildPoisoningUserOp(
        address nexusAccount,
        address targetHook,
        uint256 nonce,
        string memory fnSig,
        address victimAcc
    )
        internal
        view
        returns (PackedUserOperation memory userOp)
    {
        // Create a single execution that calls setExecutionContext on the hook directly
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: targetHook, value: 0, callData: _buildPoisoningCalldata(fnSig, victimAcc) });

        bytes memory callData = _prepareExecutionCalldata(executions);

        userOp = _createPackedUserOperation(nexusAccount, nonce, callData);

        (bytes memory sigData,,,) = _getSameChainSignatureData(userOp, ENTRYPOINT_ADDR);

        userOp.signature = sigData;
    }

    function _buildPoisoningCalldata(string memory fnSig, address victimAcc) internal pure returns (bytes memory) {
        if (keccak256(bytes(fnSig)) == keccak256("setExecutionContext(address)")) {
            return abi.encodeWithSignature(fnSig, victimAcc);
        } else if (keccak256(bytes(fnSig)) == keccak256("setOutAmount(uint256,address)")) {
            return abi.encodeWithSignature(fnSig, 12_345, victimAcc);
        } else {
            revert("Unsupported poisoning function");
        }
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
        testData.hooksAddresses = new address[](2);
        testData.hooksAddresses[0] = approveHook;
        testData.hooksAddresses[1] = deposit4626Hook;

        testData.hooksData = new bytes[](2);
        testData.hooksData[0] = _createApproveHookData(underlyingToken, morphoVault, amount, false);
        testData.hooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            morphoVault,
            0,
            true,
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

        (bytes memory sigData,,,) = _getSameChainSignatureData(userOp, ENTRYPOINT_ADDR);

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

        (bytes memory sigData,,,) = _getSameChainSignatureData(userOp, ENTRYPOINT_ADDR);
        userOp.signature = sigData;

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;
        IMinimalEntryPoint(ENTRYPOINT_ADDR).handleOps(userOps, payable(address(0x69)));
    }
}
