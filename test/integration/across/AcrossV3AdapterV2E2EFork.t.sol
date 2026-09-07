// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { ISuperDestinationExecutor } from "../../../src/interfaces/ISuperDestinationExecutor.sol";
import { IAcrossSpokePoolV3 } from "../../../src/vendor/bridges/across/IAcrossSpokePoolV3.sol";
import { IAcrossV3Receiver } from "../../../src/vendor/bridges/across/IAcrossV3Receiver.sol";
import { AcrossV3AdapterV2, IDestinationValidatorSource } from "../../../src/adapters/AcrossV3AdapterV2.sol";
import { MerkleTreeHelper } from "../../utils/MerkleTreeHelper.sol";
import { Vm } from "forge-std/Vm.sol";

/// @title AcrossV3AdapterV2E2EFork
/// @notice E2E fork test for AcrossV3AdapterV2: compact 2-field message format (initData, sigData)
/// @dev Tests the complete flow:
///      1. Deploy local AcrossV3AdapterV2 on Base fork
///      2. Simulate Across delivering tokens to adapter
///      3. handleV3AcrossMessage with compact 2-field format → adapter extracts from sigData
///      4. Validates sigData extraction, atomic transfer failures, and execution failure handling
contract AcrossV3AdapterV2E2EFork is MerkleTreeHelper {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Across SpokePool on Base
    address public constant ACROSS_SPOKE_POOL_BASE = 0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64;

    // Tokens
    address public constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // Deployed Superform contracts on Base
    address public constant SUPER_DST_EXECUTOR_BASE = 0x6ac58e854798D4aae5989B18ad5a1C0fF17817EF;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    uint256 public baseForkId;
    AcrossV3AdapterV2 public adapterV2;

    address public relayer;
    address public dstAccount;
    address public dstValidator;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        // Create Base fork
        baseForkId = vm.createFork(vm.envString(BASE_RPC_URL_KEY));
        vm.selectFork(baseForkId);

        // Create actors
        relayer = makeAddr("relayer");
        dstAccount = makeAddr("dstAccount");

        // Deploy V2 adapter
        adapterV2 = new AcrossV3AdapterV2(ACROSS_SPOKE_POOL_BASE, SUPER_DST_EXECUTOR_BASE);
        vm.label(address(adapterV2), "AcrossV3AdapterV2");

        // The validator the deployed executor is wired to — signed intents must name it
        dstValidator = IDestinationValidatorSource(SUPER_DST_EXECUTOR_BASE).SUPER_DESTINATION_VALIDATOR();
    }

    /*//////////////////////////////////////////////////////////////
                        COMPACT FORMAT E2E TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice V2 compact format: handleV3AcrossMessage with abi.encode(initData, sigData)
    ///         Adapter extracts account from sigData → transfers tokens → calls executor
    function test_Fork_V2_CompactFormat_TransferSucceeds() public {
        uint256 amount = 1000e6;
        deal(USDC_BASE, address(adapterV2), amount);

        bytes memory message = _buildV2Message(dstAccount, hex"deadbeef");

        vm.prank(ACROSS_SPOKE_POOL_BASE);
        IAcrossV3Receiver(address(adapterV2)).handleV3AcrossMessage(USDC_BASE, amount, relayer, message);

        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), amount, "dstAccount should have received USDC");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapterV2)), 0, "Adapter should be empty");
    }

    /// @notice V2: Execution fails (invalid signature) but tokens still transferred to account
    function test_Fork_V2_ExecutionFails_TokensTransferred() public {
        uint256 amount = 1000e6;
        deal(USDC_BASE, address(adapterV2), amount);

        bytes memory message = _buildV2Message(dstAccount, hex"deadbeef");

        vm.recordLogs();

        vm.prank(ACROSS_SPOKE_POOL_BASE);
        IAcrossV3Receiver(address(adapterV2)).handleV3AcrossMessage(USDC_BASE, amount, relayer, message);

        // Tokens transferred (transfer happens before execution)
        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), amount, "dstAccount should have USDC");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapterV2)), 0, "Adapter should be empty");

        // ExecutionFailed emitted (executor rejects bad proof)
        _assertEventEmitted(vm.getRecordedLogs(), "ExecutionFailed(address,bytes4)");
    }

    /// @notice V2: Transfer failure reverts so an actual SpokePool fill rolls back atomically
    function test_Fork_V2_TransferFails_Reverts() public {
        uint256 amount = 1000e6;
        deal(USDC_BASE, address(adapterV2), amount);

        // Mock USDC.transfer to dstAccount to return false
        vm.mockCall(USDC_BASE, abi.encodeCall(IERC20.transfer, (dstAccount, amount)), abi.encode(false));

        bytes memory message = _buildV2Message(dstAccount, hex"deadbeef");

        vm.prank(ACROSS_SPOKE_POOL_BASE);
        vm.expectRevert(AcrossV3AdapterV2.TRANSFER_FAILED.selector);
        IAcrossV3Receiver(address(adapterV2)).handleV3AcrossMessage(USDC_BASE, amount, relayer, message);

        vm.clearMockedCalls();
    }

    /// @notice V2: Zero account → reverts before token transfer
    function test_Fork_V2_ZeroAccount_Reverts() public {
        uint256 amount = 1000e6;
        deal(USDC_BASE, address(adapterV2), amount);

        bytes memory message = _buildV2Message(address(0), hex"deadbeef");

        vm.prank(ACROSS_SPOKE_POOL_BASE);
        vm.expectRevert(AcrossV3AdapterV2.ACCOUNT_NOT_VALID.selector);
        IAcrossV3Receiver(address(adapterV2)).handleV3AcrossMessage(USDC_BASE, amount, relayer, message);
    }

    /*//////////////////////////////////////////////////////////////
                        REAL SPOKEPOOL FILL TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice A genuine relayer fill through the real SpokePool delivers tokens and surfaces the
    ///         executor's revert selector in ExecutionFailed (empty initData + code-less account
    ///         → the real executor fails account creation with ACCOUNT_NOT_CREATED)
    function test_Fork_V2_RealSpokePoolFill_DeliversAndEmitsSelector() public {
        uint256 amount = 1000e6;
        IAcrossSpokePoolV3.V3RelayData memory relayData = _relayData(amount);
        _fundRelayer(amount);

        vm.recordLogs();
        vm.prank(relayer);
        IAcrossSpokePoolV3(ACROSS_SPOKE_POOL_BASE).fillV3Relay(relayData, 8453);

        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), amount, "Real fill should deliver USDC to dstAccount");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapterV2)), 0, "Adapter should be empty after real fill");
        assertEq(
            _findExecutionFailedSelector(vm.getRecordedLogs()),
            ISuperDestinationExecutor.ACCOUNT_NOT_CREATED.selector,
            "ExecutionFailed should carry the real executor's revert selector"
        );
    }

    /// @notice An adapter revert rolls back the entire real SpokePool fill, which stays fillable:
    ///         the literal on-chain meaning of atomic-and-retryable destination delivery
    function test_Fork_V2_RealSpokePoolFill_AtomicRevertAndRetry() public {
        uint256 amount = 1000e6;
        IAcrossSpokePoolV3.V3RelayData memory relayData = _relayData(amount);
        _fundRelayer(amount);

        // Force the adapter→account leg to fail: the whole fill must revert atomically
        vm.mockCall(USDC_BASE, abi.encodeCall(IERC20.transfer, (dstAccount, amount)), abi.encode(false));
        vm.prank(relayer);
        vm.expectRevert(AcrossV3AdapterV2.TRANSFER_FAILED.selector);
        IAcrossSpokePoolV3(ACROSS_SPOKE_POOL_BASE).fillV3Relay(relayData, 8453);
        vm.clearMockedCalls();

        assertEq(IERC20(USDC_BASE).balanceOf(relayer), amount, "Relayer keeps funds after reverted fill");
        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), 0, "No delivery after reverted fill");

        // The identical relay stays fillable — fillStatuses rolled back with the revert
        vm.prank(relayer);
        IAcrossSpokePoolV3(ACROSS_SPOKE_POOL_BASE).fillV3Relay(relayData, 8453);

        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), amount, "Retry of the same relay should deliver");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapterV2)), 0, "Adapter should be empty after retry");
    }

    /*//////////////////////////////////////////////////////////////
                        NO MATCHING DST PROOF TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice V2-specific: No DstProof matches current chain → reverts (safe for Across, prevents token loss)
    function test_Fork_V2_NoDstProofForChain_Reverts() public {
        uint256 amount = 1000e6;
        deal(USDC_BASE, address(adapterV2), amount);

        // Build message with sigData containing DstProof for chain 999 (not current chain)
        bytes memory message = _buildV2MessageWrongChain(dstAccount, hex"deadbeef", 999);

        vm.prank(ACROSS_SPOKE_POOL_BASE);
        vm.expectRevert(AcrossV3AdapterV2.NO_DST_PROOF_FOR_CHAIN.selector);
        IAcrossV3Receiver(address(adapterV2)).handleV3AcrossMessage(USDC_BASE, amount, relayer, message);
    }

    /*//////////////////////////////////////////////////////////////
                        VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice handleV3AcrossMessage called by non-SpokePool — must revert
    function test_Fork_V2_InvalidSender_Reverts() public {
        bytes memory message = _buildV2Message(dstAccount, hex"deadbeef");

        vm.prank(address(0xdead));
        vm.expectRevert(IAcrossV3Receiver.INVALID_SENDER.selector);
        IAcrossV3Receiver(address(adapterV2)).handleV3AcrossMessage(USDC_BASE, 1000e6, relayer, message);
    }

    /// @notice Constructor rejects zero addresses
    function test_Fork_V2_Constructor_ZeroAddress_Reverts() public {
        vm.expectRevert(AcrossV3AdapterV2.ADDRESS_NOT_VALID.selector);
        new AcrossV3AdapterV2(address(0), SUPER_DST_EXECUTOR_BASE);

        vm.expectRevert(AcrossV3AdapterV2.ADDRESS_NOT_VALID.selector);
        new AcrossV3AdapterV2(ACROSS_SPOKE_POOL_BASE, address(0));
    }

    /// @notice A DstProof naming a different executor rolls the fill back atomically
    function test_Fork_V2_SignedExecutorMismatch_Reverts() public {
        uint256 amount = 1000e6;
        deal(USDC_BASE, address(adapterV2), amount);

        bytes memory message =
            abi.encode(bytes(""), _encodeSigDataWithExecutor(dstAccount, hex"deadbeef", makeAddr("wrongExecutor")));

        vm.prank(ACROSS_SPOKE_POOL_BASE);
        vm.expectRevert(AcrossV3AdapterV2.EXECUTOR_NOT_VALID.selector);
        IAcrossV3Receiver(address(adapterV2)).handleV3AcrossMessage(USDC_BASE, amount, relayer, message);

        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), 0, "No tokens delivered on executor mismatch");
    }

    /// @notice A DstProof naming a different validator rolls the fill back atomically
    function test_Fork_V2_SignedValidatorMismatch_Reverts() public {
        uint256 amount = 1000e6;
        deal(USDC_BASE, address(adapterV2), amount);

        bytes memory message =
            abi.encode(bytes(""), _encodeSigDataWithValidator(dstAccount, hex"deadbeef", makeAddr("wrongValidator")));

        vm.prank(ACROSS_SPOKE_POOL_BASE);
        vm.expectRevert(AcrossV3AdapterV2.VALIDATOR_NOT_VALID.selector);
        IAcrossV3Receiver(address(adapterV2)).handleV3AcrossMessage(USDC_BASE, amount, relayer, message);

        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), 0, "No tokens delivered on validator mismatch");
    }

    /*//////////////////////////////////////////////////////////////
                    SIGDATA EXTRACTION EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Multiple DstProofs — adapter takes first matching chain
    function test_Fork_V2_MultipleDstProofs_TakesFirstMatch() public {
        uint256 amount = 1000e6;
        deal(USDC_BASE, address(adapterV2), amount);

        address firstAccount = makeAddr("first");
        address secondAccount = makeAddr("second");

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](3);
        proofDst[0] = _makeDstProof(makeAddr("ethAccount"), hex"aa", 1);
        proofDst[1] = _makeDstProof(firstAccount, hex"bb", uint64(block.chainid));
        proofDst[2] = _makeDstProof(secondAccount, hex"cc", uint64(block.chainid));

        bytes memory sigData = _encodeSigDataWithProofs(proofDst);
        bytes memory message = abi.encode(bytes(""), sigData);

        vm.prank(ACROSS_SPOKE_POOL_BASE);
        IAcrossV3Receiver(address(adapterV2)).handleV3AcrossMessage(USDC_BASE, amount, relayer, message);

        assertEq(IERC20(USDC_BASE).balanceOf(firstAccount), amount, "First match should receive tokens");
        assertEq(IERC20(USDC_BASE).balanceOf(secondAccount), 0, "Second match should get nothing");
    }

    /// @notice Empty proofDst array → reverts with NO_DST_PROOF_FOR_CHAIN
    function test_Fork_V2_EmptyProofDstArray_Reverts() public {
        uint256 amount = 500e6;
        deal(USDC_BASE, address(adapterV2), amount);

        ISuperValidator.DstProof[] memory emptyProofs = new ISuperValidator.DstProof[](0);
        bytes memory sigData = _encodeSigDataWithProofs(emptyProofs);
        bytes memory message = abi.encode(bytes(""), sigData);

        vm.prank(ACROSS_SPOKE_POOL_BASE);
        vm.expectRevert(AcrossV3AdapterV2.NO_DST_PROOF_FOR_CHAIN.selector);
        IAcrossV3Receiver(address(adapterV2)).handleV3AcrossMessage(USDC_BASE, amount, relayer, message);
    }

    /// @notice Large sigData with multiple proofs for different chains — only correct chain used
    function test_Fork_V2_LargeSigData_CorrectChainExtracted() public {
        uint256 amount = 100e6;
        deal(USDC_BASE, address(adapterV2), amount);

        address correctAccount = makeAddr("correct");

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](5);
        proofDst[0] = _makeDstProof(makeAddr("eth"), hex"aa", 1);
        proofDst[1] = _makeDstProof(makeAddr("arb"), hex"bb", 42_161);
        proofDst[2] = _makeDstProof(correctAccount, hex"cc", uint64(block.chainid));
        proofDst[3] = _makeDstProof(makeAddr("op"), hex"dd", 10);
        proofDst[4] = _makeDstProof(makeAddr("bsc"), hex"ee", 56);

        bytes memory sigData = _encodeSigDataWithProofs(proofDst);
        bytes memory message = abi.encode(bytes(""), sigData);

        vm.prank(ACROSS_SPOKE_POOL_BASE);
        IAcrossV3Receiver(address(adapterV2)).handleV3AcrossMessage(USDC_BASE, amount, relayer, message);

        assertEq(IERC20(USDC_BASE).balanceOf(correctAccount), amount, "Correct chain account receives tokens");
    }

    /*//////////////////////////////////////////////////////////////
                        EVENT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice TransferSucceeded event is emitted with correct params
    function test_Fork_V2_TransferSucceeded_EventParams() public {
        uint256 amount = 1000e6;
        deal(USDC_BASE, address(adapterV2), amount);

        bytes memory message = _buildV2Message(dstAccount, hex"deadbeef");

        vm.recordLogs();

        vm.prank(ACROSS_SPOKE_POOL_BASE);
        IAcrossV3Receiver(address(adapterV2)).handleV3AcrossMessage(USDC_BASE, amount, relayer, message);

        _assertEventEmitted(vm.getRecordedLogs(), "TransferSucceeded(address,address,uint256)");
    }

    /// @notice Immutable getters return correct values
    function test_Fork_V2_ImmutableGetters() public view {
        assertEq(adapterV2.ACROSS_SPOKE_POOL(), ACROSS_SPOKE_POOL_BASE);
        assertEq(address(adapterV2.SUPER_DESTINATION_EXECUTOR()), SUPER_DST_EXECUTOR_BASE);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds V2 compact 2-field message: abi.encode(initData, sigData)
    function _buildV2Message(address account, bytes memory executorCalldata) internal view returns (bytes memory) {
        bytes memory initData = bytes("");
        bytes memory sigData = _encodeSigDataForChain(account, executorCalldata, uint64(block.chainid));
        return abi.encode(initData, sigData);
    }

    /// @dev Builds V2 message with sigData pointing to wrong chain (for NoDstProofForChain test)
    function _buildV2MessageWrongChain(
        address account,
        bytes memory executorCalldata,
        uint64 wrongChainId
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory initData = bytes("");
        bytes memory sigData = _encodeSigDataForChain(account, executorCalldata, wrongChainId);
        return abi.encode(initData, sigData);
    }

    /// @dev Encodes SignatureData with a single DstProof for the current chain and a custom executor
    function _encodeSigDataWithExecutor(
        address account,
        bytes memory executorCalldata,
        address executor
    )
        internal
        view
        returns (bytes memory)
    {
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] = ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: uint64(block.chainid),
            info: ISuperValidator.DstInfo({
                account: account,
                executor: executor,
                dstTokens: new address[](0),
                intentAmounts: new uint256[](0),
                validator: dstValidator,
                data: executorCalldata
            })
        });
        return _encodeSigDataWithProofs(proofDst);
    }

    /// @dev Encodes SignatureData with a single DstProof for the current chain and a custom validator
    function _encodeSigDataWithValidator(
        address account,
        bytes memory executorCalldata,
        address validator
    )
        internal
        view
        returns (bytes memory)
    {
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] = ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: uint64(block.chainid),
            info: ISuperValidator.DstInfo({
                account: account,
                executor: SUPER_DST_EXECUTOR_BASE,
                dstTokens: new address[](0),
                intentAmounts: new uint256[](0),
                validator: validator,
                data: executorCalldata
            })
        });
        return _encodeSigDataWithProofs(proofDst);
    }

    /// @dev Encodes SignatureData with a single DstProof for the specified chain
    function _encodeSigDataForChain(
        address account,
        bytes memory executorCalldata,
        uint64 chainId
    )
        internal
        view
        returns (bytes memory)
    {
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] = ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: chainId,
            info: ISuperValidator.DstInfo({
                account: account,
                executor: SUPER_DST_EXECUTOR_BASE,
                dstTokens: new address[](0),
                intentAmounts: new uint256[](0),
                validator: dstValidator,
                data: executorCalldata
            })
        });

        uint64[] memory chainsWithDstExecution = new uint64[](1);
        chainsWithDstExecution[0] = chainId;

        return abi.encode(
            chainsWithDstExecution,
            uint48(type(uint48).max), // validUntil
            uint48(0), // validAfter
            keccak256("test_root"), // merkleRoot
            new bytes32[](0), // proofSrc
            proofDst,
            hex"abcdef" // signature (dummy)
        );
    }

    /// @dev Builds relay data for a real SpokePool fill delivering USDC + the V2 message to the adapter
    function _relayData(uint256 amount) internal view returns (IAcrossSpokePoolV3.V3RelayData memory) {
        return IAcrossSpokePoolV3.V3RelayData({
            depositor: dstAccount,
            recipient: address(adapterV2),
            exclusiveRelayer: address(0),
            inputToken: USDC_BASE,
            outputToken: USDC_BASE,
            inputAmount: amount,
            outputAmount: amount,
            originChainId: 1,
            depositId: 777_001,
            fillDeadline: uint32(block.timestamp + 4 hours),
            exclusivityDeadline: 0,
            message: _buildV2Message(dstAccount, hex"deadbeef")
        });
    }

    /// @dev Funds the relayer with USDC and approves the SpokePool to pull it during the fill
    function _fundRelayer(uint256 amount) internal {
        deal(USDC_BASE, relayer, amount);
        vm.prank(relayer);
        IERC20(USDC_BASE).approve(ACROSS_SPOKE_POOL_BASE, amount);
    }

    /// @dev Returns the selector carried by the adapter's ExecutionFailed event in the recorded logs
    function _findExecutionFailedSelector(Vm.Log[] memory logs) internal view returns (bytes4) {
        bytes32 topic = keccak256("ExecutionFailed(address,bytes4)");
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == address(adapterV2) && logs[i].topics.length > 0 && logs[i].topics[0] == topic) {
                return abi.decode(logs[i].data, (bytes4));
            }
        }
        revert("ExecutionFailed not emitted by adapter");
    }

    /// @dev Asserts that an event with the given signature was emitted in the recorded logs
    function _assertEventEmitted(Vm.Log[] memory logs, string memory eventSig) internal pure {
        bytes32 topic = keccak256(bytes(eventSig));
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == topic) {
                return;
            }
        }
        revert(string.concat("Event not emitted: ", eventSig));
    }

    /// @dev Creates a single DstProof for the given account, executorCalldata, and chain
    function _makeDstProof(
        address account,
        bytes memory executorCalldata,
        uint64 chainId
    )
        internal
        view
        returns (ISuperValidator.DstProof memory)
    {
        return ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: chainId,
            info: ISuperValidator.DstInfo({
                account: account,
                executor: SUPER_DST_EXECUTOR_BASE,
                dstTokens: new address[](0),
                intentAmounts: new uint256[](0),
                validator: dstValidator,
                data: executorCalldata
            })
        });
    }

    /// @dev Encodes a full SignatureData struct with custom DstProof array
    function _encodeSigDataWithProofs(ISuperValidator.DstProof[] memory proofDst) internal pure returns (bytes memory) {
        uint64[] memory chainsWithDstExecution = new uint64[](proofDst.length);
        for (uint256 i = 0; i < proofDst.length; i++) {
            chainsWithDstExecution[i] = proofDst[i].dstChainId;
        }

        return abi.encode(
            chainsWithDstExecution,
            uint48(type(uint48).max), // validUntil
            uint48(0), // validAfter
            keccak256("test_root"), // merkleRoot
            new bytes32[](0), // proofSrc
            proofDst,
            hex"abcdef" // signature (dummy)
        );
    }
}
