// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { IStargate } from "../../../src/vendor/bridges/stargate/IStargate.sol";
import { ILayerZeroComposer } from "../../../src/vendor/bridges/layerzero/ILayerZeroComposer.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { ISuperDestinationExecutor } from "../../../src/interfaces/ISuperDestinationExecutor.sol";
import { LayerZeroV2Helper } from "../../../lib/pigeon/src/layerzero-v2/LayerZeroV2Helper.sol";
import { StargateAdapterV2 } from "../../../src/adapters/StargateAdapterV2.sol";
import { ITokenMessaging } from "../../../src/vendor/bridges/stargate/ITokenMessaging.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { MerkleTreeHelper } from "../../utils/MerkleTreeHelper.sol";
import { Vm } from "forge-std/Vm.sol";
import "forge-std/console2.sol";

/// @title StargateAdapterV2E2EFork
/// @notice E2E fork test for StargateAdapterV2: compact 2-field compose format (initData, sigData)
/// @dev Tests the complete flow:
///      1. Deploy local StargateAdapterV2 on Base fork
///      2. Simulate lzReceive delivering tokens to adapter (via deal)
///      3. Manual lzCompose with compact 2-field format → adapter extracts from sigData
///      4. Validates sigData extraction, transfer, failed transfers, claim flow
///
///      The V2 adapter extracts account, executorCalldata, dstTokens, intentAmounts from
///      sigData.proofDst[i].info instead of top-level compose fields.
contract StargateAdapterV2E2EFork is MerkleTreeHelper {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Stargate V2 pools
    address public constant STARGATE_USDC_POOL_BASE = 0x27a16dc786820B16E5c9028b75B99F6f604b5d26;

    // Tokens
    address public constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // LayerZero V2 endpoints
    address public constant LZ_ENDPOINT_BASE = 0x1a44076050125825900e736c501f859c50fE728c;

    // Stargate V2 TokenMessaging on Base
    address public constant TOKEN_MESSAGING_BASE = 0x5634c4a5FEd09819E3c46D86A965Dd9447d86e47;

    // LayerZero V2 Endpoint IDs
    uint32 public constant EID_ETHEREUM = 30_101;
    uint32 public constant EID_BASE = 30_184;

    // Deployed Superform contracts on Base
    address public constant SUPER_DST_EXECUTOR_BASE = 0x6ac58e854798D4aae5989B18ad5a1C0fF17817EF;
    address public constant SUPER_DST_VALIDATOR_BASE = 0xADEFF5A0684392C4c273a9C638d1dB8c5dfd0098;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    uint256 public baseForkId;
    StargateAdapterV2 public adapterV2;

    address public sender;
    address public signer;
    uint256 public signerPrvKey;
    address public dstAccount;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        // Create Base fork
        baseForkId = vm.createFork(vm.envString(BASE_RPC_URL_KEY));
        vm.selectFork(baseForkId);

        // Create signer keypair
        (signer, signerPrvKey) = makeAddrAndKey("signer");

        // Create sender EOA
        sender = makeAddr("sender");

        // Deploy destination Nexus account
        _createDstAccount();

        // Deploy V2 adapter from source
        adapterV2 = new StargateAdapterV2(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);
        vm.label(address(adapterV2), "StargateAdapterV2");
    }

    /*//////////////////////////////////////////////////////////////
                        COMPACT FORMAT E2E TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice V2 compact format: lzCompose with abi.encode(initData, sigData)
    ///         Adapter extracts account from sigData → transfers tokens → calls executor
    function test_Fork_V2_CompactFormat_TransferSucceeds() public {
        uint256 amountLD = 1000e6;
        deal(USDC_BASE, address(adapterV2), amountLD);

        bytes memory composeMsg = _buildV2ComposeMsg(dstAccount, hex"deadbeef");
        bytes memory composeMsgCodec = _wrapComposeMsgCodec(amountLD, sender, composeMsg);

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(adapterV2)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), composeMsgCodec, address(0), bytes("")
        );

        // Tokens transferred to dstAccount (extracted from sigData)
        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), amountLD, "dstAccount should have received USDC");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapterV2)), 0, "Adapter should be empty");
    }

    /// @notice V2: Execution fails (invalid signature) but tokens still transferred to account
    function test_Fork_V2_ExecutionFails_TokensTransferred() public {
        uint256 amountLD = 1000e6;
        deal(USDC_BASE, address(adapterV2), amountLD);

        // Build with proper sigData but execution will fail due to bad merkle proof
        bytes memory composeMsg = _buildV2ComposeMsg(dstAccount, hex"deadbeef");
        bytes memory composeMsgCodec = _wrapComposeMsgCodec(amountLD, sender, composeMsg);

        vm.recordLogs();

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(adapterV2)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), composeMsgCodec, address(0), bytes("")
        );

        // Tokens transferred (transfer happens before execution)
        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), amountLD, "dstAccount should have USDC");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapterV2)), 0, "Adapter should be empty");

        // No failed transfer balance (transfer succeeded)
        assertEq(adapterV2.failedTransfers(dstAccount, USDC_BASE), 0, "No failed transfers");

        // ExecutionFailed emitted (executor rejects bad proof)
        _assertEventEmitted(vm.getRecordedLogs(), "ExecutionFailed(bytes32,address)");
    }

    /// @notice V2: Transfer fails → tokens stored in failedTransfers → claim recovers
    function test_Fork_V2_TransferFails_ClaimFailedTransfer() public {
        uint256 amountLD = 1000e6;
        deal(USDC_BASE, address(adapterV2), amountLD);

        // Mock USDC.transfer to dstAccount to return false
        vm.mockCall(
            USDC_BASE, abi.encodeCall(IERC20.transfer, (dstAccount, amountLD)), abi.encode(false)
        );

        bytes memory composeMsg = _buildV2ComposeMsg(dstAccount, hex"deadbeef");
        bytes memory composeMsgCodec = _wrapComposeMsgCodec(amountLD, sender, composeMsg);

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(adapterV2)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), composeMsgCodec, address(0), bytes("")
        );

        vm.clearMockedCalls();

        // Tokens in failedTransfers
        assertEq(adapterV2.failedTransfers(dstAccount, USDC_BASE), amountLD, "Should be in failedTransfers");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapterV2)), amountLD, "Tokens at adapter");

        // Claim
        vm.prank(dstAccount);
        adapterV2.claimFailedTransfer(USDC_BASE, amountLD);

        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), amountLD, "dstAccount recovered");
        assertEq(adapterV2.failedTransfers(dstAccount, USDC_BASE), 0, "failedTransfers cleared");
    }

    /// @notice V2: Zero account → failedTransfers keyed by composeFrom
    function test_Fork_V2_ZeroAccount_ClaimByComposeFrom() public {
        uint256 amountLD = 1000e6;
        deal(USDC_BASE, address(adapterV2), amountLD);

        // Build V2 composeMsg with account = address(0) in sigData
        bytes memory composeMsg = _buildV2ComposeMsg(address(0), hex"deadbeef");
        bytes memory composeMsgCodec = _wrapComposeMsgCodec(amountLD, sender, composeMsg);

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(adapterV2)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), composeMsgCodec, address(0), bytes("")
        );

        // Tokens stored under sender (composeFrom), not address(0)
        assertEq(adapterV2.failedTransfers(sender, USDC_BASE), amountLD, "Should be under composeFrom");
        assertEq(adapterV2.failedTransfers(address(0), USDC_BASE), 0, "Not under address(0)");

        // Sender claims
        vm.prank(sender);
        adapterV2.claimFailedTransfer(USDC_BASE, amountLD);

        assertEq(IERC20(USDC_BASE).balanceOf(sender), amountLD, "sender recovered");
    }

    /*//////////////////////////////////////////////////////////////
                        NO MATCHING DST PROOF TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice V2-specific: No DstProof matches current chain → emits NoDstProofForChain, returns gracefully
    function test_Fork_V2_NoDstProofForChain_EmitsAndReturns() public {
        uint256 amountLD = 1000e6;
        deal(USDC_BASE, address(adapterV2), amountLD);

        // Build composeMsg with sigData containing DstProof for chain 999 (not current chain)
        bytes memory composeMsg = _buildV2ComposeMsgWrongChain(dstAccount, hex"deadbeef", 999);
        bytes memory composeMsgCodec = _wrapComposeMsgCodec(amountLD, sender, composeMsg);

        vm.recordLogs();

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(adapterV2)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), composeMsgCodec, address(0), bytes("")
        );

        // NoDstProofForChain emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        _assertEventEmitted(logs, "NoDstProofForChain(bytes32,uint64)");
        // TransferFailed emitted for composeFrom (sender) so tokens are claimable
        _assertEventEmitted(logs, "TransferFailed(bytes32,address,address,uint256)");

        // Tokens remain in adapter (credited to composeFrom via failedTransfers)
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapterV2)), amountLD, "Tokens should remain at adapter");
        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), 0, "dstAccount should have 0");
        // failedTransfers credited to composeFrom (sender), not dstAccount
        assertEq(adapterV2.failedTransfers(dstAccount, USDC_BASE), 0, "No failedTransfers for dstAccount");
        assertEq(adapterV2.failedTransfers(sender, USDC_BASE), amountLD, "failedTransfers credited to composeFrom");
    }

    /*//////////////////////////////////////////////////////////////
                        VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice lzCompose called by non-endpoint — must revert
    function test_Fork_V2_InvalidSender_Reverts() public {
        bytes memory composeMsg = _buildV2ComposeMsg(dstAccount, hex"deadbeef");
        bytes memory composeMsgCodec = _wrapComposeMsgCodec(1000e6, sender, composeMsg);

        vm.prank(address(0xdead));
        vm.expectRevert(StargateAdapterV2.INVALID_SENDER.selector);
        ILayerZeroComposer(address(adapterV2)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), composeMsgCodec, address(0), bytes("")
        );
    }

    /// @notice Message shorter than 76-byte header — emits ComposeMsgTooShort
    function test_Fork_V2_ComposeMsgTooShort_EmitsAndReturns() public {
        bytes memory shortMsg = new bytes(75);

        vm.recordLogs();

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(adapterV2)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), shortMsg, address(0), bytes("")
        );

        _assertEventEmitted(vm.getRecordedLogs(), "ComposeMsgTooShort(bytes32,uint256)");
    }

    /// @notice Constructor rejects zero addresses
    function test_Fork_V2_Constructor_ZeroAddress_Reverts() public {
        vm.expectRevert(StargateAdapterV2.ADDRESS_NOT_VALID.selector);
        new StargateAdapterV2(address(0), TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);

        vm.expectRevert(StargateAdapterV2.ADDRESS_NOT_VALID.selector);
        new StargateAdapterV2(LZ_ENDPOINT_BASE, address(0), SUPER_DST_EXECUTOR_BASE);

        vm.expectRevert(StargateAdapterV2.ADDRESS_NOT_VALID.selector);
        new StargateAdapterV2(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, address(0));
    }

    /// @notice Claim with zero amount reverts
    function test_Fork_V2_ClaimZeroAmount_Reverts() public {
        vm.prank(dstAccount);
        vm.expectRevert(StargateAdapterV2.ZERO_AMOUNT.selector);
        adapterV2.claimFailedTransfer(USDC_BASE, 0);
    }

    /// @notice Claim by user with no balance reverts
    function test_Fork_V2_ClaimByUnauthorizedUser_Reverts() public {
        deal(USDC_BASE, address(adapterV2), 1000e6);
        vm.mockCall(USDC_BASE, abi.encodeWithSelector(IERC20.transfer.selector, dstAccount), abi.encode(false));

        bytes memory composeMsg = _buildV2ComposeMsg(dstAccount, hex"deadbeef");
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(adapterV2)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(1000e6, sender, composeMsg), address(0), bytes("")
        );
        vm.clearMockedCalls();

        address randomUser = makeAddr("random");
        vm.prank(randomUser);
        vm.expectRevert(StargateAdapterV2.INSUFFICIENT_FAILED_BALANCE.selector);
        adapterV2.claimFailedTransfer(USDC_BASE, 1000e6);
    }

    /// @notice Malformed inner payload — abi.decode panics but lzCompose doesn't revert
    function test_Fork_V2_MalformedPayload_DoesNotBlockPipeline() public {
        uint256 amount = 1000e6;
        deal(USDC_BASE, address(adapterV2), amount * 2);

        // Valid OFT header + garbage inner payload
        bytes memory garbagePayload = abi.encodePacked(
            uint64(0),
            uint32(EID_ETHEREUM),
            uint256(amount),
            bytes32(uint256(uint160(sender))),
            hex"deadbeefcafebabe0123456789"
        );

        vm.recordLogs();

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(adapterV2)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), garbagePayload, address(0), bytes("")
        );

        _assertEventEmitted(vm.getRecordedLogs(), "ComposeDecodeFailed(bytes32)");

        // Tokens untouched
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapterV2)), amount * 2, "Tokens untouched");

        // Pipeline still works — valid compose after malformed one
        address user = makeAddr("valid_user");
        bytes memory validMsg = _buildV2ComposeMsg(user, hex"deadbeef");
        bytes memory validCodec = _wrapComposeMsgCodec(amount, sender, validMsg);

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(adapterV2)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), validCodec, address(0), bytes("")
        );

        assertEq(IERC20(USDC_BASE).balanceOf(user), amount, "Valid compose after malformed succeeds");
    }

    /// @notice Unregistered pool → emits UnregisteredPool, returns gracefully
    function test_Fork_V2_UnregisteredPool_EmitsAndReturns() public {
        uint256 amount = 1000e6;
        deal(USDC_BASE, address(adapterV2), amount);

        address fakeFrom = makeAddr("fakePool");

        bytes memory composeMsg = _buildV2ComposeMsg(dstAccount, hex"deadbeef");
        bytes memory composeMsgCodec = _wrapComposeMsgCodec(amount, sender, composeMsg);

        vm.recordLogs();

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(adapterV2)).lzCompose(
            fakeFrom, bytes32(0), composeMsgCodec, address(0), bytes("")
        );

        _assertEventEmitted(vm.getRecordedLogs(), "UnregisteredPool(bytes32,address)");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapterV2)), amount, "Tokens untouched");
    }

    /*//////////////////////////////////////////////////////////////
                        MULTI-COMPOSE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Multiple failed transfers accumulate for same user
    function test_Fork_V2_MultipleFailedTransfers_Accumulate() public {
        uint256 amount1 = 500e6;
        uint256 amount2 = 700e6;
        uint256 totalAmount = amount1 + amount2;
        deal(USDC_BASE, address(adapterV2), totalAmount);

        vm.mockCall(USDC_BASE, abi.encodeWithSelector(IERC20.transfer.selector, dstAccount), abi.encode(false));

        bytes memory composeMsg = _buildV2ComposeMsg(dstAccount, hex"deadbeef");

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(adapterV2)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(amount1, sender, composeMsg), address(0), bytes("")
        );
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(adapterV2)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(amount2, sender, composeMsg), address(0), bytes("")
        );

        vm.clearMockedCalls();

        assertEq(adapterV2.failedTransfers(dstAccount, USDC_BASE), totalAmount, "Accumulated");

        vm.prank(dstAccount);
        adapterV2.claimFailedTransfer(USDC_BASE, totalAmount);

        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), totalAmount, "Claimed all");
        assertEq(adapterV2.failedTransfers(dstAccount, USDC_BASE), 0, "Cleared");
    }

    /// @notice Two different users — balances isolated
    function test_Fork_V2_DifferentUsers_Isolated() public {
        address userA = makeAddr("userA");
        address userB = makeAddr("userB");
        uint256 amountA = 800e6;
        uint256 amountB = 1200e6;
        deal(USDC_BASE, address(adapterV2), amountA + amountB);

        vm.mockCall(USDC_BASE, abi.encodeWithSelector(IERC20.transfer.selector, userA), abi.encode(false));
        vm.mockCall(USDC_BASE, abi.encodeWithSelector(IERC20.transfer.selector, userB), abi.encode(false));

        bytes memory composeMsgA = _buildV2ComposeMsg(userA, hex"deadbeef");
        bytes memory composeMsgB = _buildV2ComposeMsg(userB, hex"deadbeef");

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(adapterV2)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(amountA, sender, composeMsgA), address(0), bytes("")
        );
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(adapterV2)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(amountB, sender, composeMsgB), address(0), bytes("")
        );

        vm.clearMockedCalls();

        // Isolated
        assertEq(adapterV2.failedTransfers(userA, USDC_BASE), amountA);
        assertEq(adapterV2.failedTransfers(userB, USDC_BASE), amountB);

        // userA claims — userB unaffected
        vm.prank(userA);
        adapterV2.claimFailedTransfer(USDC_BASE, amountA);

        assertEq(IERC20(USDC_BASE).balanceOf(userA), amountA);
        assertEq(adapterV2.failedTransfers(userB, USDC_BASE), amountB);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds V2 compact 2-field compose: abi.encode(initData, sigData)
    function _buildV2ComposeMsg(address account, bytes memory executorCalldata) internal view returns (bytes memory) {
        bytes memory initData = bytes("");
        bytes memory sigData = _encodeSigDataForChain(account, executorCalldata, uint64(block.chainid));
        return abi.encode(initData, sigData);
    }

    /// @dev Builds V2 composeMsg with sigData pointing to wrong chain (for NoDstProofForChain test)
    function _buildV2ComposeMsgWrongChain(
        address account,
        bytes memory executorCalldata,
        uint64 wrongChainId
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory initData = bytes("");
        bytes memory sigData = _encodeSigDataForChain(account, executorCalldata, wrongChainId);
        return abi.encode(initData, sigData);
    }

    /// @dev Encodes SignatureData with a single DstProof for the specified chain
    function _encodeSigDataForChain(
        address account,
        bytes memory executorCalldata,
        uint64 chainId
    )
        internal
        pure
        returns (bytes memory)
    {
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] = ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: chainId,
            info: ISuperValidator.DstInfo({
                account: account,
                executor: address(0xCAFE),
                dstTokens: new address[](0),
                intentAmounts: new uint256[](0),
                validator: address(0xFACE),
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

    /// @dev Wraps inner composeMsg with OFTComposeMsgCodec header
    function _wrapComposeMsgCodec(
        uint256 amountLD,
        address composeFrom,
        bytes memory innerMsg
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint64(0), uint32(EID_ETHEREUM), amountLD, bytes32(uint256(uint160(composeFrom))), innerMsg
        );
    }

    /// @dev Creates a Nexus smart account on the current fork for dstAccount
    function _createDstAccount() internal {
        dstAccount = makeAddr("dstAccount");
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
}
