// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { IStargate } from "../../../src/vendor/bridges/stargate/IStargate.sol";
import { ILayerZeroComposer } from "../../../src/vendor/bridges/layerzero/ILayerZeroComposer.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { ISuperDestinationExecutor } from "../../../src/interfaces/ISuperDestinationExecutor.sol";
import { INexusFactory } from "../../../src/vendor/nexus/INexusFactory.sol";
import { BootstrapConfig, INexusBootstrap } from "../../../src/vendor/nexus/INexusBootstrap.sol";
import { IERC7484 } from "../../../src/vendor/nexus/IERC7484.sol";
import { LayerZeroV2Helper } from "../../../lib/pigeon/src/layerzero-v2/LayerZeroV2Helper.sol";
import { StargateAdapter } from "../../../src/adapters/StargateAdapter.sol";
import { ITokenMessaging } from "../../../src/vendor/bridges/stargate/ITokenMessaging.sol";
import { ClaimFailedTransferHook } from "../../../src/hooks/claim/stargate/ClaimFailedTransferHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { MerkleTreeHelper } from "../../utils/MerkleTreeHelper.sol";
import { Vm } from "forge-std/Vm.sol";
import "forge-std/console2.sol";

/// @title StargateAdapterE2EFork
/// @notice E2E fork test: Stargate bridge ETH→Base with destination execution through real
///         SuperDestinationExecutor and SuperDestinationValidator on Base
/// @dev Tests the complete cross-chain flow:
///      1. Source (ETH): Direct Stargate sendToken with composeMsg containing sigData
///      2. Pigeon relay: lzReceive → USDC credited to StargateAdapter on Base
///      3. Manual lzCompose: StargateAdapter → SuperDestinationExecutor.processBridgedExecution
///      4. Validates merkle proof via real SuperDestinationValidator → marks root as used
///
///      Pigeon only handles lzReceive (not lzCompose), so lzCompose is triggered manually
///      via vm.prank(LZ_ENDPOINT_BASE) → adapter.lzCompose(...)
contract StargateAdapterE2EFork is MerkleTreeHelper {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Stargate V2 pools
    address public constant STARGATE_USDC_POOL_ETH = 0xc026395860Db2d07ee33e05fE50ed7bD583189C7;
    address public constant STARGATE_USDC_POOL_BASE = 0x27a16dc786820B16E5c9028b75B99F6f604b5d26;

    // Tokens
    address public constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // LayerZero V2 endpoints (same address on all EVM chains)
    address public constant LZ_ENDPOINT_BASE = 0x1a44076050125825900e736c501f859c50fE728c;

    // Stargate V2 TokenMessaging on Base (for pool registration verification)
    address public constant TOKEN_MESSAGING_BASE = 0x5634c4a5FEd09819E3c46D86A965Dd9447d86e47;

    // LayerZero V2 Endpoint IDs
    uint32 public constant EID_ETHEREUM = 30_101;
    uint32 public constant EID_BASE = 30_184;

    // Deployed Superform contracts on Base (from script/output/prod/8453/Base-latest.json)
    address public constant STARGATE_ADAPTER_BASE = 0xE89935D1A016DCA964A5E6157C3bE5773C8D7Fb1;
    address public constant SUPER_DST_EXECUTOR_BASE = 0x6ac58e854798D4aae5989B18ad5a1C0fF17817EF;
    address public constant SUPER_DST_VALIDATOR_BASE = 0xADEFF5A0684392C4c273a9C638d1dB8c5dfd0098;

    // LZ compose extraOptions: type=3 (COMPOSE), index=0, gas=100000
    bytes public constant COMPOSE_EXTRA_OPTIONS = hex"000301001101000000000000000000000000000186a0";

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    LayerZeroV2Helper public lzHelper;
    uint256 public ethForkId;
    uint256 public baseForkId;

    address public sender;
    address public signer;
    uint256 public signerPrvKey;
    address public dstAccount;

    // Shared between helper functions to avoid stack-too-deep
    bytes32 internal _merkleRoot;
    bytes internal _composeMsg;

    // Overridable adapter target — defaults to deployed, tests can override to local
    address internal _adapterTarget;

    // Overridable signing key — tests can set this to a wrong key to simulate invalid signatures
    uint256 internal _signingKey;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        // 1. Create ETH fork at pinned block
        ethForkId = vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), ETH_BLOCK);

        // 2. Create signer keypair (owner of dstAccount on Base)
        (signer, signerPrvKey) = makeAddrAndKey("signer");

        // 3. Create sender EOA on ETH (calls Stargate sendToken directly)
        sender = makeAddr("sender");
        vm.deal(sender, 100 ether);

        // 4. Create pigeon helper
        lzHelper = new LayerZeroV2Helper();

        // 5. Create Base fork and deploy destination Nexus account
        baseForkId = vm.createFork(vm.envString(BASE_RPC_URL_KEY));
        vm.selectFork(baseForkId);
        _createDstAccount();

        // 6. Defaults
        _signingKey = signerPrvKey;
        _adapterTarget = STARGATE_ADAPTER_BASE;

        // 7. Switch back to ETH fork for the test
        vm.selectFork(ethForkId);
    }

    /*//////////////////////////////////////////////////////////////
                                 E2E TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Full E2E: Stargate bridge ETH→Base with destination execution via SuperDestinationExecutor
    /// @dev Flow: sendToken (ETH) → pigeon lzReceive (Base) → manual lzCompose → processBridgedExecution
    function test_Fork_E2E_StargateWithDestinationExecution_ETHToBase() public {
        uint256 amountLD = 1000e6; // 1000 USDC
        uint256 minAmountLD = 995e6; // 0.5% slippage

        // Fund sender with USDC on ETH
        deal(USDC_ETH, sender, amountLD);

        // Build merkle tree, sigData, and composeMsg (stored to _merkleRoot and _composeMsg)
        _buildComposeMsg();

        // Send via Stargate on ETH and relay via pigeon
        _sendAndRelay(amountLD, minAmountLD);

        // Switch to Base and execute lzCompose + assertions
        _executeDstComposeAndAssert(minAmountLD);
    }

    /// @notice E2E: Execution fails (invalid signature) but tokens are transferred to dstAccount.
    ///         Tests the updated StargateAdapter (from source) with try/catch around processBridgedExecution.
    /// @dev Uses a locally deployed StargateAdapter from current source code (has try/catch + claimFailedTransfer).
    ///      Flow:
    ///        1. Bridge ETH→Base via Stargate + pigeon relay → tokens at local adapter
    ///        2. lzCompose on local adapter → _tryTransfer succeeds (tokens to dstAccount)
    ///        3. processBridgedExecution reverts (wrong signature) → caught by try/catch → ExecutionFailed emitted
    ///        4. Result: tokens at dstAccount, merkle root NOT consumed, user has their tokens
    function test_Fork_E2E_StargateExecutionFails_TokensTransferred_ETHToBase() public {
        // Deploy the updated StargateAdapter from source on Base fork (has try/catch)
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);
        _adapterTarget = address(localAdapter);
        vm.label(_adapterTarget, "LocalStargateAdapter");
        console2.log("Deployed local StargateAdapter on Base:", _adapterTarget);
        vm.selectFork(ethForkId);

        uint256 amountLD = 1000e6;
        uint256 minAmountLD = 995e6;
        deal(USDC_ETH, sender, amountLD);

        // Sign with WRONG key → execution will fail with INVALID_SIGNATURE
        (, uint256 wrongKey) = makeAddrAndKey("wrong_signer");
        _signingKey = wrongKey;

        _buildComposeMsg();
        _sendAndRelay(amountLD, minAmountLD);

        // Execute lzCompose on the local adapter and assert execution-failed-but-tokens-safe state
        vm.selectFork(baseForkId);

        uint256 amountReceived = IERC20(USDC_BASE).balanceOf(_adapterTarget);
        console2.log("USDC received at local adapter on Base:", amountReceived);
        assertGt(amountReceived, 0, "Local adapter should have received USDC via lzReceive");
        assertGe(amountReceived, minAmountLD, "Should receive at least minAmountLD");

        // Build OFTComposeMsgCodec and trigger lzCompose
        bytes memory composeMsgCodec = abi.encodePacked(
            uint64(0), uint32(EID_ETHEREUM), uint256(amountReceived), bytes32(uint256(uint160(sender))), _composeMsg
        );

        vm.recordLogs();

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(_adapterTarget).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), composeMsgCodec, address(0), bytes("")
        );

        // 1. Tokens WERE transferred to dstAccount (try/catch doesn't roll back the transfer)
        assertEq(
            IERC20(USDC_BASE).balanceOf(dstAccount), amountReceived, "dstAccount should have received all USDC"
        );
        assertEq(IERC20(USDC_BASE).balanceOf(_adapterTarget), 0, "Local adapter should be empty");

        // 2. Merkle root NOT consumed (execution failed before marking)
        assertFalse(
            ISuperDestinationExecutor(SUPER_DST_EXECUTOR_BASE).isMerkleRootUsed(dstAccount, _merkleRoot),
            "Merkle root should NOT be marked as used"
        );

        // 3. No failed transfer balance (transfer succeeded, only execution failed)
        assertEq(
            localAdapter.failedTransfers(dstAccount, USDC_BASE),
            0,
            "failedTransfers should be 0 (transfer succeeded)"
        );

        // 4. Verify ExecutionFailed event was emitted
        _assertExecutionFailedEmitted();

        console2.log("Confirmed: tokens safe at dstAccount, execution failed, root NOT consumed");
    }

    /// @notice E2E: Transfer fails (USDC transfer returns false) → tokens stored in failedTransfers
    ///         → user recovers via claimFailedTransfer
    /// @dev Uses vm.mockCall to make USDC.transfer return false for the dstAccount, simulating
    ///      a blocklisted recipient. This triggers the failedTransfers storage path in the adapter.
    ///      Then claimFailedTransfer is called to recover the tokens.
    function test_Fork_E2E_StargateTransferFails_ClaimFailedTransfer_ETHToBase() public {
        // Deploy the updated StargateAdapter from source on Base fork
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);
        _adapterTarget = address(localAdapter);
        vm.label(_adapterTarget, "LocalStargateAdapter");
        vm.selectFork(ethForkId);

        uint256 amountLD = 1000e6;
        uint256 minAmountLD = 995e6;
        deal(USDC_ETH, sender, amountLD);

        _signingKey = signerPrvKey;
        _buildComposeMsg();
        _sendAndRelay(amountLD, minAmountLD);

        vm.selectFork(baseForkId);

        uint256 amountReceived = IERC20(USDC_BASE).balanceOf(_adapterTarget);
        console2.log("USDC received at local adapter on Base:", amountReceived);
        assertGt(amountReceived, 0, "Local adapter should have received USDC");

        // Mock USDC.transfer(dstAccount, amountReceived) to return false
        // Simulates a blocklisted recipient — _tryTransfer returns false
        vm.mockCall(
            USDC_BASE,
            abi.encodeCall(IERC20.transfer, (dstAccount, amountReceived)),
            abi.encode(false)
        );

        // Build OFTComposeMsgCodec and trigger lzCompose
        bytes memory composeMsgCodec = abi.encodePacked(
            uint64(0), uint32(EID_ETHEREUM), uint256(amountReceived), bytes32(uint256(uint160(sender))), _composeMsg
        );

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(_adapterTarget).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), composeMsgCodec, address(0), bytes("")
        );

        // Clear mock so subsequent transfers work normally
        vm.clearMockedCalls();

        // 1. Transfer failed → tokens stored in failedTransfers (still at adapter)
        assertEq(
            localAdapter.failedTransfers(dstAccount, USDC_BASE),
            amountReceived,
            "failedTransfers should hold the full amount"
        );
        assertEq(IERC20(USDC_BASE).balanceOf(_adapterTarget), amountReceived, "Tokens should remain at adapter");
        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), 0, "dstAccount should have 0 USDC");

        console2.log("Transfer failed: tokens in failedTransfers, amount:", amountReceived);

        // 2. dstAccount calls claimFailedTransfer to recover tokens
        vm.prank(dstAccount);
        localAdapter.claimFailedTransfer(USDC_BASE, amountReceived);

        // 3. Tokens recovered by dstAccount
        assertEq(
            IERC20(USDC_BASE).balanceOf(dstAccount), amountReceived, "dstAccount should have recovered all USDC"
        );
        assertEq(localAdapter.failedTransfers(dstAccount, USDC_BASE), 0, "failedTransfers should be cleared");
        assertEq(IERC20(USDC_BASE).balanceOf(_adapterTarget), 0, "Adapter should be empty after claim");

        console2.log("Recovery success: dstAccount claimed", amountReceived, "USDC via claimFailedTransfer");
    }

    /// @notice E2E: account == address(0) in composeMsg → tokens stored in failedTransfers keyed by
    ///         composeFrom (source sender) → source sender claims on destination chain
    /// @dev Tests the composeFrom fallback: when the inner message has account=address(0),
    ///      the adapter stores tokens under failedTransfers[composeFrom] so the bridge initiator
    ///      can recover them via claimFailedTransfer.
    function test_Fork_E2E_StargateZeroAccount_ClaimByComposeFrom_ETHToBase() public {
        // Deploy the updated StargateAdapter from source on Base fork
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);
        _adapterTarget = address(localAdapter);
        vm.label(_adapterTarget, "LocalStargateAdapter");
        vm.selectFork(ethForkId);

        uint256 amountLD = 1000e6;
        uint256 minAmountLD = 995e6;
        deal(USDC_ETH, sender, amountLD);

        _signingKey = signerPrvKey;

        // Build composeMsg with account = address(0) instead of dstAccount
        _buildComposeMsgWithZeroAccount();

        _sendAndRelay(amountLD, minAmountLD);

        vm.selectFork(baseForkId);

        uint256 amountReceived = IERC20(USDC_BASE).balanceOf(_adapterTarget);
        console2.log("USDC received at local adapter on Base:", amountReceived);
        assertGt(amountReceived, 0, "Local adapter should have received USDC");

        // Build OFTComposeMsgCodec — composeFrom = sender (the source chain bridge initiator)
        bytes memory composeMsgCodec = abi.encodePacked(
            uint64(0), uint32(EID_ETHEREUM), uint256(amountReceived), bytes32(uint256(uint160(sender))), _composeMsg
        );

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(_adapterTarget).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), composeMsgCodec, address(0), bytes("")
        );

        // 1. Tokens stored in failedTransfers keyed by sender (composeFrom), NOT address(0)
        assertEq(
            localAdapter.failedTransfers(sender, USDC_BASE),
            amountReceived,
            "failedTransfers[sender] should hold the full amount"
        );
        assertEq(localAdapter.failedTransfers(address(0), USDC_BASE), 0, "failedTransfers[address(0)] should be 0");
        assertEq(IERC20(USDC_BASE).balanceOf(_adapterTarget), amountReceived, "Tokens should remain at adapter");

        console2.log("Zero account: tokens in failedTransfers[sender], amount:", amountReceived);

        // 2. sender (composeFrom) claims on destination chain
        vm.prank(sender);
        localAdapter.claimFailedTransfer(USDC_BASE, amountReceived);

        // 3. Tokens recovered by sender
        assertEq(IERC20(USDC_BASE).balanceOf(sender), amountReceived, "sender should have recovered all USDC");
        assertEq(localAdapter.failedTransfers(sender, USDC_BASE), 0, "failedTransfers should be cleared");
        assertEq(IERC20(USDC_BASE).balanceOf(_adapterTarget), 0, "Adapter should be empty after claim");

        console2.log("Recovery success: sender claimed", amountReceived, "USDC via claimFailedTransfer");
    }

    /*//////////////////////////////////////////////////////////////
                        MULTI-COMPOSE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Multiple failed transfers for the same user accumulate in failedTransfers.
    ///         User claims the full accumulated balance in a single call.
    function test_Fork_E2E_StargateMultipleFailedTransfers_SameUser_Accumulate() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);

        // Simulate 3 lzReceive deliveries totalling 2000 USDC sitting at the adapter
        uint256 amount1 = 500e6;
        uint256 amount2 = 700e6;
        uint256 amount3 = 800e6;
        uint256 totalAmount = amount1 + amount2 + amount3;
        deal(USDC_BASE, address(localAdapter), totalAmount);

        // Mock USDC.transfer to dstAccount to return false (simulates blocklisted recipient)
        vm.mockCall(USDC_BASE, abi.encodeWithSelector(IERC20.transfer.selector, dstAccount), abi.encode(false));

        // 3 separate lzCompose calls — same user, different amounts
        bytes memory innerMsg = _buildInnerComposeMsg(dstAccount);

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(amount1, sender, innerMsg), address(0), bytes("")
        );
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(amount2, sender, innerMsg), address(0), bytes("")
        );
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(amount3, sender, innerMsg), address(0), bytes("")
        );

        vm.clearMockedCalls();

        // All 3 failures accumulated under dstAccount
        assertEq(localAdapter.failedTransfers(dstAccount, USDC_BASE), totalAmount, "Should accumulate all 3 amounts");
        assertEq(IERC20(USDC_BASE).balanceOf(address(localAdapter)), totalAmount, "Adapter holds all tokens");

        // Single claim for the full amount
        vm.prank(dstAccount);
        localAdapter.claimFailedTransfer(USDC_BASE, totalAmount);

        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), totalAmount, "dstAccount should have all tokens");
        assertEq(localAdapter.failedTransfers(dstAccount, USDC_BASE), 0, "failedTransfers should be cleared");
        assertEq(IERC20(USDC_BASE).balanceOf(address(localAdapter)), 0, "Adapter should be empty");
    }

    /// @notice Two different users each have failed transfers — balances are isolated.
    ///         Each user claims independently without affecting the other.
    function test_Fork_E2E_StargateMultipleFailedTransfers_DifferentUsers_Isolated() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);

        address userA = makeAddr("userA");
        address userB = makeAddr("userB");
        uint256 amountA = 800e6;
        uint256 amountB = 1200e6;
        deal(USDC_BASE, address(localAdapter), amountA + amountB);

        // Mock transfers to both users to fail
        vm.mockCall(USDC_BASE, abi.encodeWithSelector(IERC20.transfer.selector, userA), abi.encode(false));
        vm.mockCall(USDC_BASE, abi.encodeWithSelector(IERC20.transfer.selector, userB), abi.encode(false));

        bytes memory innerMsgA = _buildInnerComposeMsg(userA);
        bytes memory innerMsgB = _buildInnerComposeMsg(userB);

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(amountA, sender, innerMsgA), address(0), bytes("")
        );
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(amountB, sender, innerMsgB), address(0), bytes("")
        );

        vm.clearMockedCalls();

        // Balances isolated per user
        assertEq(localAdapter.failedTransfers(userA, USDC_BASE), amountA, "userA should have amountA");
        assertEq(localAdapter.failedTransfers(userB, USDC_BASE), amountB, "userB should have amountB");

        // userA claims — doesn't affect userB
        vm.prank(userA);
        localAdapter.claimFailedTransfer(USDC_BASE, amountA);

        assertEq(IERC20(USDC_BASE).balanceOf(userA), amountA, "userA should have claimed");
        assertEq(localAdapter.failedTransfers(userA, USDC_BASE), 0, "userA failedTransfers cleared");
        assertEq(localAdapter.failedTransfers(userB, USDC_BASE), amountB, "userB unaffected by userA claim");

        // userB claims
        vm.prank(userB);
        localAdapter.claimFailedTransfer(USDC_BASE, amountB);

        assertEq(IERC20(USDC_BASE).balanceOf(userB), amountB, "userB should have claimed");
        assertEq(localAdapter.failedTransfers(userB, USDC_BASE), 0, "userB failedTransfers cleared");
        assertEq(IERC20(USDC_BASE).balanceOf(address(localAdapter)), 0, "Adapter empty");
    }

    /// @notice Same user: first compose succeeds, second fails.
    ///         Only the failed amount goes to failedTransfers. User claims and ends up with the full total.
    function test_Fork_E2E_StargateMultipleComposes_MixedOutcomes_SameUser() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);

        uint256 amount1 = 1000e6; // will succeed
        uint256 amount2 = 1000e6; // will fail
        deal(USDC_BASE, address(localAdapter), amount1 + amount2);

        bytes memory innerMsg = _buildInnerComposeMsg(dstAccount);

        // First compose — transfer succeeds (no mock)
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(amount1, sender, innerMsg), address(0), bytes("")
        );

        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), amount1, "First transfer should succeed");
        assertEq(localAdapter.failedTransfers(dstAccount, USDC_BASE), 0, "No failed transfers yet");

        // Mock transfer to fail for second compose
        vm.mockCall(
            USDC_BASE, abi.encodeCall(IERC20.transfer, (dstAccount, amount2)), abi.encode(false)
        );

        // Second compose — transfer fails
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(amount2, sender, innerMsg), address(0), bytes("")
        );

        vm.clearMockedCalls();

        // dstAccount has amount1 from successful transfer, amount2 in failedTransfers
        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), amount1, "dstAccount has first transfer");
        assertEq(localAdapter.failedTransfers(dstAccount, USDC_BASE), amount2, "Second transfer in failedTransfers");

        // Claim the failed amount
        vm.prank(dstAccount);
        localAdapter.claimFailedTransfer(USDC_BASE, amount2);

        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), amount1 + amount2, "dstAccount has full total");
        assertEq(localAdapter.failedTransfers(dstAccount, USDC_BASE), 0, "failedTransfers cleared");
    }

    /// @notice Multiple failures then partial claims — user drains balance incrementally.
    function test_Fork_E2E_StargatePartialClaim_AfterMultipleFailures() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);

        uint256 totalAmount = 1500e6;
        deal(USDC_BASE, address(localAdapter), totalAmount);

        vm.mockCall(USDC_BASE, abi.encodeWithSelector(IERC20.transfer.selector, dstAccount), abi.encode(false));

        bytes memory innerMsg = _buildInnerComposeMsg(dstAccount);

        // Two failed composes
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(900e6, sender, innerMsg), address(0), bytes("")
        );
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(600e6, sender, innerMsg), address(0), bytes("")
        );

        vm.clearMockedCalls();

        assertEq(localAdapter.failedTransfers(dstAccount, USDC_BASE), totalAmount, "Full amount accumulated");

        // Partial claim: 500
        vm.prank(dstAccount);
        localAdapter.claimFailedTransfer(USDC_BASE, 500e6);

        assertEq(localAdapter.failedTransfers(dstAccount, USDC_BASE), 1000e6, "1000 remaining");
        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), 500e6, "dstAccount has 500");

        // Partial claim: 1000
        vm.prank(dstAccount);
        localAdapter.claimFailedTransfer(USDC_BASE, 1000e6);

        assertEq(localAdapter.failedTransfers(dstAccount, USDC_BASE), 0, "Fully drained");
        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), totalAmount, "dstAccount has full amount");
        assertEq(IERC20(USDC_BASE).balanceOf(address(localAdapter)), 0, "Adapter empty");

        // Overclaim should revert
        vm.prank(dstAccount);
        vm.expectRevert(StargateAdapter.INSUFFICIENT_FAILED_BALANCE.selector);
        localAdapter.claimFailedTransfer(USDC_BASE, 1);
    }

    /*//////////////////////////////////////////////////////////////
                        VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice lzCompose called by non-endpoint address — must revert with INVALID_SENDER.
    function test_Fork_E2E_StargateInvalidSender_Reverts() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);

        bytes memory innerMsg = _buildInnerComposeMsg(dstAccount);
        bytes memory composeMsgCodec = _wrapComposeMsgCodec(1000e6, sender, innerMsg);

        vm.prank(address(0xdead));
        vm.expectRevert(StargateAdapter.INVALID_SENDER.selector);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), composeMsgCodec, address(0), bytes("")
        );
    }

    /// @notice Message shorter than the 76-byte OFTComposeMsgCodec header — emits ComposeMsgTooShort, does not revert.
    function test_Fork_E2E_StargateComposeMsgTooShort_EmitsAndReturns() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);

        bytes memory shortMsg = new bytes(75); // one byte short of COMPOSE_MSG_OFFSET (76)

        vm.recordLogs();

        // Should NOT revert — emits event and returns to avoid blocking pipeline
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), shortMsg, address(0), bytes("")
        );

        _assertEventEmitted(vm.getRecordedLogs(), "ComposeMsgTooShort(bytes32,uint256)");
    }

    /// @notice Constructor rejects zero addresses for lzEndpoint, tokenMessaging, and superDestinationExecutor.
    function test_Fork_E2E_StargateConstructor_ZeroAddress_Reverts() public {
        vm.selectFork(baseForkId);

        vm.expectRevert(StargateAdapter.ADDRESS_NOT_VALID.selector);
        new StargateAdapter(address(0), TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);

        vm.expectRevert(StargateAdapter.ADDRESS_NOT_VALID.selector);
        new StargateAdapter(LZ_ENDPOINT_BASE, address(0), SUPER_DST_EXECUTOR_BASE);

        vm.expectRevert(StargateAdapter.ADDRESS_NOT_VALID.selector);
        new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, address(0));
    }

    /// @notice Claim with zero amount reverts with ZERO_AMOUNT.
    function test_Fork_E2E_StargateClaimZeroAmount_Reverts() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);

        vm.prank(dstAccount);
        vm.expectRevert(StargateAdapter.ZERO_AMOUNT.selector);
        localAdapter.claimFailedTransfer(USDC_BASE, 0);
    }

    /// @notice Claim by a user with no failed transfer balance reverts with INSUFFICIENT_FAILED_BALANCE.
    function test_Fork_E2E_StargateClaimByUnauthorizedUser_Reverts() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);

        // Give adapter some tokens and create a failed transfer for dstAccount
        deal(USDC_BASE, address(localAdapter), 1000e6);
        vm.mockCall(USDC_BASE, abi.encodeWithSelector(IERC20.transfer.selector, dstAccount), abi.encode(false));

        bytes memory innerMsg = _buildInnerComposeMsg(dstAccount);
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(1000e6, sender, innerMsg), address(0), bytes("")
        );
        vm.clearMockedCalls();

        assertEq(localAdapter.failedTransfers(dstAccount, USDC_BASE), 1000e6);

        // Random user tries to claim dstAccount's balance — reverts
        address randomUser = makeAddr("random");
        vm.prank(randomUser);
        vm.expectRevert(StargateAdapter.INSUFFICIENT_FAILED_BALANCE.selector);
        localAdapter.claimFailedTransfer(USDC_BASE, 1000e6);

        // dstAccount balance unchanged
        assertEq(localAdapter.failedTransfers(dstAccount, USDC_BASE), 1000e6);
    }

    /// @notice Malformed inner payload (garbage after OFT header) — abi.decode panics but
    ///         lzCompose does NOT revert. Emits ComposeDecodeFailed, pipeline continues.
    ///         Verifies the M-1 DoS fix: one malformed bridge tx cannot block the compose queue.
    function test_Fork_E2E_StargateMalformedPayload_DoesNotBlockPipeline() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);

        uint256 amount = 1000e6;
        deal(USDC_BASE, address(localAdapter), amount * 2);

        // Build a valid OFT header followed by garbage (not valid abi.encode)
        bytes memory garbagePayload = abi.encodePacked(
            uint64(0), // nonce
            uint32(EID_ETHEREUM), // srcEid
            uint256(amount), // amountLD
            bytes32(uint256(uint160(sender))), // composeFrom
            hex"deadbeefcafebabe0123456789" // garbage inner payload — abi.decode will panic
        );

        vm.recordLogs();

        // This MUST NOT revert — previously it would panic on abi.decode and block the pipeline
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), garbagePayload, address(0), bytes("")
        );

        // Verify ComposeDecodeFailed event was emitted
        _assertEventEmitted(vm.getRecordedLogs(), "ComposeDecodeFailed(bytes32)");

        // Tokens remain at adapter (no transfer attempted since decode failed)
        assertEq(IERC20(USDC_BASE).balanceOf(address(localAdapter)), amount * 2, "Tokens untouched");

        // Pipeline still works — a valid compose after the malformed one succeeds
        address user = makeAddr("valid_user");
        bytes memory validMsg = _buildInnerComposeMsg(user);
        bytes memory validCodec = _wrapComposeMsgCodec(amount, sender, validMsg);

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), validCodec, address(0), bytes("")
        );

        assertEq(IERC20(USDC_BASE).balanceOf(user), amount, "Valid compose after malformed one succeeds");
    }

    /*//////////////////////////////////////////////////////////////
                        TOKEN RESOLUTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Unregistered _from is rejected at TokenMessaging validation.
    ///         Adapter emits UnregisteredPool and returns — tokens remain in adapter.
    ///         NOTE: TokenResolutionFailed can no longer be triggered because pool validation
    ///         (step 3) rejects unregistered addresses before token() is called (step 6).
    function test_Fork_E2E_StargateUnregisteredPool_TokensStuck() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);

        uint256 amount = 1000e6;
        deal(USDC_BASE, address(localAdapter), amount);

        // Deploy a contract that isn't registered in TokenMessaging
        address fakeFrom = address(new ETHRejecter());

        bytes memory innerMsg = _buildInnerComposeMsg(dstAccount);
        bytes memory composeMsgCodec = _wrapComposeMsgCodec(amount, sender, innerMsg);

        vm.recordLogs();

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            fakeFrom, bytes32(0), composeMsgCodec, address(0), bytes("")
        );

        // Tokens remain at adapter — unregistered pool rejected before any transfer
        assertEq(IERC20(USDC_BASE).balanceOf(address(localAdapter)), amount, "Tokens remain at adapter");
        assertEq(localAdapter.failedTransfers(dstAccount, USDC_BASE), 0, "No failedTransfers for account");
        assertEq(localAdapter.failedTransfers(sender, USDC_BASE), 0, "No failedTransfers for sender");

        // Verify UnregisteredPool event (replaces TokenResolutionFailed in new validation)
        _assertEventEmitted(vm.getRecordedLogs(), "UnregisteredPool(bytes32,address)");
    }

    /*//////////////////////////////////////////////////////////////
                        NATIVE ETH PATH TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Native ETH compose — happy path: ETH transferred to recipient via _tryTransfer.
    function test_Fork_E2E_StargateNativeETH_TransferSucceeds() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);

        uint256 amount = 1 ether;
        vm.deal(address(localAdapter), amount);

        address recipient = makeAddr("eth_recipient");

        // Mock _from as a registered StargatePoolNative: token() → address(0), assetIds → 13
        address fakeNativePool = makeAddr("native_pool");
        vm.mockCall(fakeNativePool, abi.encodeWithSelector(IStargate.token.selector), abi.encode(address(0)));
        vm.mockCall(
            TOKEN_MESSAGING_BASE,
            abi.encodeWithSelector(ITokenMessaging.assetIds.selector, fakeNativePool),
            abi.encode(uint16(13))
        );

        bytes memory innerMsg = _buildInnerComposeMsg(recipient);
        bytes memory composeMsgCodec = _wrapComposeMsgCodec(amount, sender, innerMsg);

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            fakeNativePool, bytes32(0), composeMsgCodec, address(0), bytes("")
        );

        vm.clearMockedCalls();

        assertEq(recipient.balance, amount, "Recipient should have received ETH");
        assertEq(address(localAdapter).balance, 0, "Adapter should be empty");
        assertEq(localAdapter.failedTransfers(recipient, address(0)), 0, "No failed transfers");
    }

    /// @notice Native ETH compose — transfer fails (contract rejects ETH).
    ///         Tokens stored in failedTransfers. Claim also fails because recipient rejects ETH.
    ///         Demonstrates the limitation: if the account is a contract that cannot accept ETH,
    ///         funds are unrecoverable via claimFailedTransfer.
    function test_Fork_E2E_StargateNativeETH_RejectingRecipient_FundsStuck() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);

        uint256 amount = 1 ether;
        vm.deal(address(localAdapter), amount);

        // Deploy a contract that rejects ETH
        address rejecter = address(new ETHRejecter());

        // Mock _from as a registered StargatePoolNative
        address fakeNativePool = makeAddr("native_pool");
        vm.mockCall(fakeNativePool, abi.encodeWithSelector(IStargate.token.selector), abi.encode(address(0)));
        vm.mockCall(
            TOKEN_MESSAGING_BASE,
            abi.encodeWithSelector(ITokenMessaging.assetIds.selector, fakeNativePool),
            abi.encode(uint16(13))
        );

        bytes memory innerMsg = _buildInnerComposeMsg(rejecter);
        bytes memory composeMsgCodec = _wrapComposeMsgCodec(amount, sender, innerMsg);

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            fakeNativePool, bytes32(0), composeMsgCodec, address(0), bytes("")
        );

        vm.clearMockedCalls();

        // Transfer failed → ETH in failedTransfers
        assertEq(localAdapter.failedTransfers(rejecter, address(0)), amount, "ETH in failedTransfers");
        assertEq(address(localAdapter).balance, amount, "ETH still at adapter");

        // Claim also fails — rejecter contract cannot accept ETH
        vm.prank(rejecter);
        vm.expectRevert(StargateAdapter.ETH_TRANSFER_FAILED.selector);
        localAdapter.claimFailedTransfer(address(0), amount);

        // Funds remain stuck
        assertEq(localAdapter.failedTransfers(rejecter, address(0)), amount, "Still stuck");
    }

    /// @notice Native ETH compose — zero account. ETH stored under composeFrom (sender EOA).
    ///         Sender claims native ETH successfully.
    function test_Fork_E2E_StargateNativeETH_ZeroAccount_ClaimByComposeFrom() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);

        uint256 amount = 2 ether;
        vm.deal(address(localAdapter), amount);

        // Mock _from as a registered StargatePoolNative
        address fakeNativePool = makeAddr("native_pool");
        vm.mockCall(fakeNativePool, abi.encodeWithSelector(IStargate.token.selector), abi.encode(address(0)));
        vm.mockCall(
            TOKEN_MESSAGING_BASE,
            abi.encodeWithSelector(ITokenMessaging.assetIds.selector, fakeNativePool),
            abi.encode(uint16(13))
        );

        bytes memory innerMsg = _buildInnerComposeMsg(address(0));
        bytes memory composeMsgCodec = _wrapComposeMsgCodec(amount, sender, innerMsg);

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            fakeNativePool, bytes32(0), composeMsgCodec, address(0), bytes("")
        );

        vm.clearMockedCalls();

        // ETH stored under sender (composeFrom), not address(0)
        assertEq(localAdapter.failedTransfers(sender, address(0)), amount, "ETH stored under sender");
        assertEq(localAdapter.failedTransfers(address(0), address(0)), 0, "Nothing at address(0)");

        uint256 senderBalBefore = sender.balance;

        // Sender (EOA) claims native ETH
        vm.prank(sender);
        localAdapter.claimFailedTransfer(address(0), amount);

        assertEq(sender.balance, senderBalBefore + amount, "Sender received ETH");
        assertEq(localAdapter.failedTransfers(sender, address(0)), 0, "Cleared");
        assertEq(address(localAdapter).balance, 0, "Adapter empty");
    }

    /*//////////////////////////////////////////////////////////////
                    MULTI-USER SUCCESS TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Multiple users all receive tokens successfully — no failures, no failedTransfers.
    function test_Fork_E2E_StargateMultipleUsers_AllTransfersSucceed() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);

        address userA = makeAddr("userA_success");
        address userB = makeAddr("userB_success");
        address userC = makeAddr("userC_success");
        uint256 amountA = 500e6;
        uint256 amountB = 750e6;
        uint256 amountC = 1250e6;
        deal(USDC_BASE, address(localAdapter), amountA + amountB + amountC);

        bytes memory innerA = _buildInnerComposeMsg(userA);
        bytes memory innerB = _buildInnerComposeMsg(userB);
        bytes memory innerC = _buildInnerComposeMsg(userC);

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(amountA, sender, innerA), address(0), bytes("")
        );
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(amountB, sender, innerB), address(0), bytes("")
        );
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(amountC, sender, innerC), address(0), bytes("")
        );

        // All tokens transferred — adapter empty, no failed transfers
        assertEq(IERC20(USDC_BASE).balanceOf(userA), amountA, "userA received");
        assertEq(IERC20(USDC_BASE).balanceOf(userB), amountB, "userB received");
        assertEq(IERC20(USDC_BASE).balanceOf(userC), amountC, "userC received");
        assertEq(IERC20(USDC_BASE).balanceOf(address(localAdapter)), 0, "Adapter empty");
        assertEq(localAdapter.failedTransfers(userA, USDC_BASE), 0, "No failed transfers userA");
        assertEq(localAdapter.failedTransfers(userB, USDC_BASE), 0, "No failed transfers userB");
        assertEq(localAdapter.failedTransfers(userC, USDC_BASE), 0, "No failed transfers userC");
    }

    /// @notice Three users: A succeeds, B fails, C succeeds. Only B's amount in failedTransfers.
    ///         Verifies failure isolation — one user's blocklist doesn't affect others.
    function test_Fork_E2E_StargateMultipleUsers_OneFailsOthersSucceed() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);

        address userA = makeAddr("userA_ok");
        address userB = makeAddr("userB_blocked");
        address userC = makeAddr("userC_ok");
        uint256 amountA = 400e6;
        uint256 amountB = 600e6;
        uint256 amountC = 500e6;
        deal(USDC_BASE, address(localAdapter), amountA + amountB + amountC);

        // Only mock failure for userB
        vm.mockCall(USDC_BASE, abi.encodeCall(IERC20.transfer, (userB, amountB)), abi.encode(false));

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE,
            bytes32(0),
            _wrapComposeMsgCodec(amountA, sender, _buildInnerComposeMsg(userA)),
            address(0),
            bytes("")
        );
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE,
            bytes32(0),
            _wrapComposeMsgCodec(amountB, sender, _buildInnerComposeMsg(userB)),
            address(0),
            bytes("")
        );
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE,
            bytes32(0),
            _wrapComposeMsgCodec(amountC, sender, _buildInnerComposeMsg(userC)),
            address(0),
            bytes("")
        );

        vm.clearMockedCalls();

        // A and C succeeded, B failed
        assertEq(IERC20(USDC_BASE).balanceOf(userA), amountA, "userA received");
        assertEq(IERC20(USDC_BASE).balanceOf(userB), 0, "userB got nothing");
        assertEq(IERC20(USDC_BASE).balanceOf(userC), amountC, "userC received");
        assertEq(localAdapter.failedTransfers(userB, USDC_BASE), amountB, "userB in failedTransfers");
        assertEq(localAdapter.failedTransfers(userA, USDC_BASE), 0, "userA clean");
        assertEq(localAdapter.failedTransfers(userC, USDC_BASE), 0, "userC clean");

        // B recovers
        vm.prank(userB);
        localAdapter.claimFailedTransfer(USDC_BASE, amountB);
        assertEq(IERC20(USDC_BASE).balanceOf(userB), amountB, "userB recovered");
    }

    /// @notice Multiple zero-account composes from different senders.
    ///         Each sender's tokens are tracked independently under their composeFrom address.
    function test_Fork_E2E_StargateMultipleZeroAccounts_DifferentSenders() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);

        address sender1 = makeAddr("sender1");
        address sender2 = makeAddr("sender2");
        uint256 amount1 = 300e6;
        uint256 amount2 = 700e6;
        deal(USDC_BASE, address(localAdapter), amount1 + amount2);

        bytes memory innerMsg = _buildInnerComposeMsg(address(0));

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE,
            bytes32(0),
            _wrapComposeMsgCodec(amount1, sender1, innerMsg),
            address(0),
            bytes("")
        );
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE,
            bytes32(0),
            _wrapComposeMsgCodec(amount2, sender2, innerMsg),
            address(0),
            bytes("")
        );

        // Each sender has their own balance
        assertEq(localAdapter.failedTransfers(sender1, USDC_BASE), amount1, "sender1 balance");
        assertEq(localAdapter.failedTransfers(sender2, USDC_BASE), amount2, "sender2 balance");
        assertEq(localAdapter.failedTransfers(address(0), USDC_BASE), 0, "nothing at address(0)");

        // Each claims independently
        vm.prank(sender1);
        localAdapter.claimFailedTransfer(USDC_BASE, amount1);
        vm.prank(sender2);
        localAdapter.claimFailedTransfer(USDC_BASE, amount2);

        assertEq(IERC20(USDC_BASE).balanceOf(sender1), amount1, "sender1 claimed");
        assertEq(IERC20(USDC_BASE).balanceOf(sender2), amount2, "sender2 claimed");
        assertEq(IERC20(USDC_BASE).balanceOf(address(localAdapter)), 0, "Adapter empty");
    }

    /*//////////////////////////////////////////////////////////////
                        EVENT VERIFICATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify correct events emitted for success, failure, and claim in sequence.
    function test_Fork_E2E_StargateEventEmission_SuccessFailureClaim() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);

        uint256 amount = 500e6;
        deal(USDC_BASE, address(localAdapter), amount * 2);

        address user = makeAddr("event_user");
        bytes memory innerMsg = _buildInnerComposeMsg(user);

        // Successful transfer — should emit TransferSucceeded + ExecutionFailed (dummy sigData)
        vm.recordLogs();
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(amount, sender, innerMsg), address(0), bytes("")
        );
        _assertEventEmitted(vm.getRecordedLogs(), "TransferSucceeded(bytes32,address,address,uint256)");

        // Failed transfer — should emit TransferFailed + ExecutionFailed
        vm.mockCall(USDC_BASE, abi.encodeCall(IERC20.transfer, (user, amount)), abi.encode(false));
        vm.recordLogs();
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(amount, sender, innerMsg), address(0), bytes("")
        );
        _assertEventEmitted(vm.getRecordedLogs(), "TransferFailed(bytes32,address,address,uint256)");
        vm.clearMockedCalls();

        // Claim — should emit FailedTransferClaimed
        vm.recordLogs();
        vm.prank(user);
        localAdapter.claimFailedTransfer(USDC_BASE, amount);
        _assertEventEmitted(vm.getRecordedLogs(), "FailedTransferClaimed(address,address,uint256)");
    }

    /*//////////////////////////////////////////////////////////////
                    CLAIM FAILED TRANSFER HOOK TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Full E2E with Pigeon: Stargate bridge ETH→Base, transfer fails on dst, recover via hook.
    ///         Flow: sendToken (ETH) → Pigeon lzReceive (Base) → lzCompose (transfer mocked to fail)
    ///         → failedTransfers stored → ClaimFailedTransferHook claim → tokens recovered
    function test_Fork_E2E_ClaimFailedTransferHook_FullBridgeFlow_ETHToBase() public {
        // Deploy local adapter and hook on Base
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);
        ClaimFailedTransferHook hook = new ClaimFailedTransferHook();
        _adapterTarget = address(localAdapter);
        vm.label(_adapterTarget, "LocalStargateAdapter");
        vm.selectFork(ethForkId);

        uint256 amountLD = 1000e6;
        uint256 minAmountLD = 995e6;
        deal(USDC_ETH, sender, amountLD);

        _signingKey = signerPrvKey;
        _buildComposeMsg();
        _sendAndRelay(amountLD, minAmountLD);

        // Switch to Base — tokens arrived at adapter via Pigeon lzReceive
        vm.selectFork(baseForkId);

        uint256 amountReceived = IERC20(USDC_BASE).balanceOf(_adapterTarget);
        assertGt(amountReceived, 0, "Adapter should have received USDC via real Pigeon relay");
        assertGe(amountReceived, minAmountLD);

        // Mock USDC.transfer(dstAccount) to fail — simulates blocklisted recipient
        vm.mockCall(USDC_BASE, abi.encodeCall(IERC20.transfer, (dstAccount, amountReceived)), abi.encode(false));

        // Trigger lzCompose — transfer fails, tokens go to failedTransfers
        bytes memory composeMsgCodec = abi.encodePacked(
            uint64(0), uint32(EID_ETHEREUM), uint256(amountReceived), bytes32(uint256(uint160(sender))), _composeMsg
        );
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(_adapterTarget).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), composeMsgCodec, address(0), bytes("")
        );
        vm.clearMockedCalls();

        // Verify: tokens stuck in failedTransfers, dstAccount has nothing
        assertEq(localAdapter.failedTransfers(dstAccount, USDC_BASE), amountReceived, "Should have failed balance");
        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), 0, "dstAccount should have 0");

        // Recover via ClaimFailedTransferHook
        _executeHookClaim(hook, address(localAdapter), USDC_BASE, amountReceived, dstAccount);

        // Verify full recovery
        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), amountReceived, "dstAccount recovered all USDC");
        assertEq(localAdapter.failedTransfers(dstAccount, USDC_BASE), 0, "failedTransfers cleared");
        assertEq(IERC20(USDC_BASE).balanceOf(_adapterTarget), 0, "Adapter empty");
        assertEq(hook.getOutAmount(dstAccount), amountReceived, "outAmount matches");

        console2.log("Full E2E: Stargate bridge -> transfer fail -> hook claim recovery:", amountReceived, "USDC");
    }

    /// @notice E2E (local): Transfer fails → tokens in failedTransfers → recover via ClaimFailedTransferHook.
    function test_Fork_E2E_ClaimFailedTransferHook_ERC20() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);
        ClaimFailedTransferHook hook = new ClaimFailedTransferHook();

        uint256 amount = 500e6;
        address user = makeAddr("hook_claim_user");
        deal(USDC_BASE, address(localAdapter), amount);

        // 1. Create failed transfer: mock USDC.transfer(user) returning false
        vm.mockCall(USDC_BASE, abi.encodeCall(IERC20.transfer, (user, amount)), abi.encode(false));

        bytes memory innerMsg = _buildInnerComposeMsg(user);
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(amount, sender, innerMsg), address(0), bytes("")
        );
        vm.clearMockedCalls();

        // Verify tokens stuck in failedTransfers
        assertEq(localAdapter.failedTransfers(user, USDC_BASE), amount, "Should have failed balance");
        assertEq(IERC20(USDC_BASE).balanceOf(user), 0, "User should have 0 USDC");

        // 2. Execute claim via hook
        _executeHookClaim(hook, address(localAdapter), USDC_BASE, amount, user);

        // 3. Verify recovery
        assertEq(IERC20(USDC_BASE).balanceOf(user), amount, "User should have recovered USDC");
        assertEq(localAdapter.failedTransfers(user, USDC_BASE), 0, "failedTransfers should be cleared");
        assertEq(IERC20(USDC_BASE).balanceOf(address(localAdapter)), 0, "Adapter should be empty");

        // 5. Verify outAmount tracking
        assertEq(hook.getOutAmount(user), amount, "outAmount should match claimed amount");
    }

    /// @notice E2E: Native ETH transfer fails → recover via ClaimFailedTransferHook.
    ///         Uses ETHRejecter to cause initial failure, then a normal EOA user to claim via
    ///         the zero-account/composeFrom path (since ETHRejecter can't call claim itself).
    function test_Fork_E2E_ClaimFailedTransferHook_NativeETH() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);
        ClaimFailedTransferHook hook = new ClaimFailedTransferHook();

        uint256 amount = 2 ether;
        address ethUser = makeAddr("eth_claim_user");
        vm.deal(address(localAdapter), amount);

        // Use account=address(0) so tokens are stored under composeFrom=ethUser
        // This way ethUser can claim native ETH via the hook
        address mockNativePool = makeAddr("mockNativePool");
        vm.mockCall(mockNativePool, abi.encodeWithSignature("token()"), abi.encode(address(0)));
        vm.mockCall(
            TOKEN_MESSAGING_BASE,
            abi.encodeWithSelector(ITokenMessaging.assetIds.selector, mockNativePool),
            abi.encode(uint16(13))
        );

        bytes memory innerMsg = _buildInnerComposeMsg(address(0));
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            mockNativePool,
            bytes32(0),
            _wrapComposeMsgCodec(amount, ethUser, innerMsg),
            address(0),
            bytes("")
        );
        vm.clearMockedCalls();

        assertEq(localAdapter.failedTransfers(ethUser, address(0)), amount, "Should have failed ETH balance");

        // Claim native ETH via hook
        _executeHookClaim(hook, address(localAdapter), address(0), amount, ethUser);

        // Verify native ETH recovery
        assertEq(ethUser.balance, amount, "User should have recovered ETH");
        assertEq(localAdapter.failedTransfers(ethUser, address(0)), 0, "failedTransfers should be cleared");
        assertEq(hook.getOutAmount(ethUser), amount, "outAmount should match claimed ETH");
    }

    /// @notice E2E: Zero-account compose → composeFrom claims via hook.
    function test_Fork_E2E_ClaimFailedTransferHook_ZeroAccount_ComposeFromClaims() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);
        ClaimFailedTransferHook hook = new ClaimFailedTransferHook();

        uint256 amount = 750e6;
        address originator = makeAddr("originator");
        deal(USDC_BASE, address(localAdapter), amount);

        // Trigger compose with account=address(0) → tokens stored under composeFrom (originator)
        bytes memory innerMsg = _buildInnerComposeMsg(address(0));
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE,
            bytes32(0),
            _wrapComposeMsgCodec(amount, originator, innerMsg),
            address(0),
            bytes("")
        );

        assertEq(localAdapter.failedTransfers(originator, USDC_BASE), amount, "originator should have failed balance");

        // Originator claims via hook
        _executeHookClaim(hook, address(localAdapter), USDC_BASE, amount, originator);

        assertEq(IERC20(USDC_BASE).balanceOf(originator), amount, "Originator should have recovered USDC");
        assertEq(localAdapter.failedTransfers(originator, USDC_BASE), 0, "failedTransfers should be cleared");
        assertEq(hook.getOutAmount(originator), amount, "outAmount should match claimed amount");
    }

    /// @notice E2E: decodeAmount + replaceCalldataAmount roundtrip — simulates bundler adjusting the claim amount.
    ///         Flow: build hook data with 800 USDC → decodeAmount reads 800 → replaceCalldataAmount sets 500 → claim 500.
    function test_Fork_E2E_ClaimFailedTransferHook_DecodeAndReplaceAmount() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);
        ClaimFailedTransferHook hook = new ClaimFailedTransferHook();

        uint256 originalAmount = 800e6;
        uint256 adjustedAmount = 500e6;
        address user = makeAddr("decode_replace_user");
        deal(USDC_BASE, address(localAdapter), originalAmount);

        // Create failed transfer
        vm.mockCall(USDC_BASE, abi.encodeCall(IERC20.transfer, (user, originalAmount)), abi.encode(false));
        bytes memory innerMsg = _buildInnerComposeMsg(user);
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(originalAmount, sender, innerMsg), address(0), bytes("")
        );
        vm.clearMockedCalls();
        assertEq(localAdapter.failedTransfers(user, USDC_BASE), originalAmount);

        // Bundler flow: build original hook data, decode amount, replace with adjusted amount
        bytes memory hookData = abi.encodePacked(address(localAdapter), USDC_BASE, originalAmount);
        uint256 decoded = hook.decodeAmounts(hookData)[0];
        assertEq(decoded, originalAmount, "decodeAmount should read original amount");

        bytes memory adjustedData = hook.replaceCalldataAmounts(hookData, _singleAmount(adjustedAmount));
        uint256 decodedAdjusted = hook.decodeAmounts(adjustedData)[0];
        assertEq(decodedAdjusted, adjustedAmount, "decodeAmount after replace should read adjusted amount");

        // Execute claim with adjusted amount (500 out of 800)
        _executeHookClaim(hook, address(localAdapter), USDC_BASE, adjustedAmount, user);

        assertEq(IERC20(USDC_BASE).balanceOf(user), adjustedAmount, "User should have adjusted amount");
        assertEq(localAdapter.failedTransfers(user, USDC_BASE), originalAmount - adjustedAmount, "Remaining should be left");
        assertEq(hook.getOutAmount(user), adjustedAmount, "outAmount should match adjusted claim");
    }

    /// @notice E2E: Same user has failed transfers in both USDC and native ETH — claims both via separate hook calls.
    function test_Fork_E2E_ClaimFailedTransferHook_MultipleTokens() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);
        ClaimFailedTransferHook hook = new ClaimFailedTransferHook();

        uint256 usdcAmount = 600e6;
        uint256 ethAmount = 3 ether;
        address user = makeAddr("multi_token_user");

        // --- Create failed USDC transfer ---
        deal(USDC_BASE, address(localAdapter), usdcAmount);
        vm.mockCall(USDC_BASE, abi.encodeCall(IERC20.transfer, (user, usdcAmount)), abi.encode(false));
        bytes memory innerMsg = _buildInnerComposeMsg(user);
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(usdcAmount, sender, innerMsg), address(0), bytes("")
        );
        vm.clearMockedCalls();

        // --- Create failed native ETH transfer (via zero-account path) ---
        vm.deal(address(localAdapter), ethAmount);
        address mockNativePool = makeAddr("mockNativePoolMulti");
        vm.mockCall(mockNativePool, abi.encodeWithSignature("token()"), abi.encode(address(0)));
        vm.mockCall(
            TOKEN_MESSAGING_BASE,
            abi.encodeWithSelector(ITokenMessaging.assetIds.selector, mockNativePool),
            abi.encode(uint16(13))
        );
        bytes memory ethInnerMsg = _buildInnerComposeMsg(address(0));
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            mockNativePool, bytes32(0), _wrapComposeMsgCodec(ethAmount, user, ethInnerMsg), address(0), bytes("")
        );
        vm.clearMockedCalls();

        // Verify both failed balances
        assertEq(localAdapter.failedTransfers(user, USDC_BASE), usdcAmount, "USDC failed balance");
        assertEq(localAdapter.failedTransfers(user, address(0)), ethAmount, "ETH failed balance");

        // Claim USDC first
        _executeHookClaim(hook, address(localAdapter), USDC_BASE, usdcAmount, user);
        assertEq(IERC20(USDC_BASE).balanceOf(user), usdcAmount, "User should have USDC");
        assertEq(localAdapter.failedTransfers(user, USDC_BASE), 0, "USDC failed cleared");

        // Claim native ETH second
        _executeHookClaim(hook, address(localAdapter), address(0), ethAmount, user);
        assertEq(user.balance, ethAmount, "User should have ETH");
        assertEq(localAdapter.failedTransfers(user, address(0)), 0, "ETH failed cleared");
    }

    /// @notice E2E: Verify inspect() returns correct adapter+token after a real compose failure on fork.
    function test_Fork_E2E_ClaimFailedTransferHook_Inspect() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);
        ClaimFailedTransferHook hook = new ClaimFailedTransferHook();

        uint256 amount = 250e6;
        address user = makeAddr("inspect_user");
        deal(USDC_BASE, address(localAdapter), amount);

        // Create failed transfer
        vm.mockCall(USDC_BASE, abi.encodeCall(IERC20.transfer, (user, amount)), abi.encode(false));
        bytes memory innerMsg = _buildInnerComposeMsg(user);
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(amount, sender, innerMsg), address(0), bytes("")
        );
        vm.clearMockedCalls();
        assertEq(localAdapter.failedTransfers(user, USDC_BASE), amount);

        // Verify inspect returns correct adapter + token
        bytes memory hookData = abi.encodePacked(address(localAdapter), USDC_BASE, amount);
        bytes memory inspected = hook.inspect(hookData);

        assertEq(inspected.length, 40, "Inspect output should be 40 bytes");
        assertEq(BytesLib.toAddress(inspected, 0), address(localAdapter), "Inspect adapter mismatch");
        assertEq(BytesLib.toAddress(inspected, 20), USDC_BASE, "Inspect token mismatch");

        // Also verify decodeAmount on the same data
        assertEq(hook.decodeAmounts(hookData)[0], amount, "decodeAmount mismatch");

        // Execute claim to confirm the inspected data is actionable
        _executeHookClaim(hook, address(localAdapter), USDC_BASE, amount, user);
        assertEq(IERC20(USDC_BASE).balanceOf(user), amount, "User should have recovered USDC");
    }

    /// @notice E2E: Revert when hook data is too short in fork context.
    function test_Fork_E2E_ClaimFailedTransferHook_RevertIf_DataTooShort() public {
        vm.selectFork(baseForkId);
        ClaimFailedTransferHook hook = new ClaimFailedTransferHook();

        address user = makeAddr("short_data_user");
        bytes memory shortData = abi.encodePacked(address(0x1234), address(0x5678)); // 40 bytes, missing amount
        vm.expectRevert(ClaimFailedTransferHook.DATA_NOT_VALID.selector);
        hook.build(address(0), user, shortData);
    }

    /// @notice E2E: Multiple failed transfers → partial claim via hook, then remaining claim.
    function test_Fork_E2E_ClaimFailedTransferHook_PartialClaim() public {
        vm.selectFork(baseForkId);
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, TOKEN_MESSAGING_BASE, SUPER_DST_EXECUTOR_BASE);
        ClaimFailedTransferHook hook = new ClaimFailedTransferHook();

        address user = makeAddr("partial_claim_user");
        deal(USDC_BASE, address(localAdapter), 800e6);

        // Create two failed transfers for the same user (300 + 500 = 800)
        bytes memory innerMsg = _buildInnerComposeMsg(user);

        vm.mockCall(USDC_BASE, abi.encodeCall(IERC20.transfer, (user, 300e6)), abi.encode(false));
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(300e6, sender, innerMsg), address(0), bytes("")
        );

        vm.mockCall(USDC_BASE, abi.encodeCall(IERC20.transfer, (user, 500e6)), abi.encode(false));
        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(address(localAdapter)).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), _wrapComposeMsgCodec(500e6, sender, innerMsg), address(0), bytes("")
        );
        vm.clearMockedCalls();

        assertEq(localAdapter.failedTransfers(user, USDC_BASE), 800e6, "Should have accumulated balance");

        // Claim first 300 via hook
        _executeHookClaim(hook, address(localAdapter), USDC_BASE, 300e6, user);

        assertEq(IERC20(USDC_BASE).balanceOf(user), 300e6, "Should have partial claim");
        assertEq(localAdapter.failedTransfers(user, USDC_BASE), 500e6, "Remaining should be left");

        // Claim remaining 500 via hook
        _executeHookClaim(hook, address(localAdapter), USDC_BASE, 500e6, user);

        assertEq(IERC20(USDC_BASE).balanceOf(user), 800e6, "Should have full claim");
        assertEq(localAdapter.failedTransfers(user, USDC_BASE), 0, "All claimed");
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds a minimal inner composeMsg for a given account (dummy sigData — execution will fail but that's fine)
    function _buildInnerComposeMsg(address account) internal pure returns (bytes memory) {
        return abi.encode(
            bytes(""), // initData
            hex"deadbeef", // executorCalldata
            account, // account
            new address[](0), // dstTokens
            new uint256[](0), // intentAmounts
            bytes("") // sigData (dummy — execution will revert, caught by try/catch)
        );
    }

    /// @dev Wraps an inner composeMsg with the OFTComposeMsgCodec header (nonce + srcEid + amountLD + composeFrom)
    function _wrapComposeMsgCodec(
        uint256 amountLD,
        address composeFrom,
        bytes memory innerMsg
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(uint64(0), uint32(EID_ETHEREUM), amountLD, bytes32(uint256(uint160(composeFrom))), innerMsg);
    }

    /// @dev Builds merkle tree, sigData, and 6-field composeMsg. Stores to _merkleRoot and _composeMsg.
    function _buildComposeMsg() internal {
        uint48 validUntil = type(uint48).max;

        bytes32 sourceLeaf = keccak256(bytes.concat(keccak256(abi.encode(bytes32("e2e_source")))));

        bytes32 dstLeaf = _createDestinationValidatorLeaf(
            hex"deadbeef",
            uint64(BASE),
            dstAccount,
            SUPER_DST_EXECUTOR_BASE,
            new address[](0),
            new uint256[](0),
            validUntil,
            SUPER_DST_VALIDATOR_BASE
        );

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = sourceLeaf;
        leaves[1] = dstLeaf;
        (bytes32[][] memory proof, bytes32 root) = _createValidatorMerkleTree(leaves);
        _merkleRoot = root;

        bytes memory signature = _signRoot(root);
        bytes memory sigData = _encodeSigData(proof, root, signature, validUntil);

        _composeMsg = abi.encode(bytes(""), hex"deadbeef", dstAccount, new address[](0), new uint256[](0), sigData);
    }

    /// @dev Builds composeMsg with account = address(0). sigData is garbage (execution won't be reached).
    function _buildComposeMsgWithZeroAccount() internal {
        _merkleRoot = bytes32(0);
        _composeMsg = abi.encode(
            bytes(""),
            hex"deadbeef",
            address(0), // account = address(0) triggers the composeFrom fallback
            new address[](0),
            new uint256[](0),
            bytes("") // sigData irrelevant — adapter returns early before execution
        );
    }

    /// @dev Encodes sigData with DstProof for chain 8453
    function _encodeSigData(
        bytes32[][] memory proof,
        bytes32 root,
        bytes memory signature,
        uint48 validUntil
    )
        internal
        view
        returns (bytes memory)
    {
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] = ISuperValidator.DstProof({
            proof: proof[1],
            dstChainId: uint64(BASE),
            info: ISuperValidator.DstInfo({
                data: hex"deadbeef",
                executor: SUPER_DST_EXECUTOR_BASE,
                dstTokens: new address[](0),
                intentAmounts: new uint256[](0),
                account: dstAccount,
                validator: SUPER_DST_VALIDATOR_BASE
            })
        });

        uint64[] memory chainsWithDestExecution = new uint64[](1);
        chainsWithDestExecution[0] = uint64(BASE);

        return abi.encode(chainsWithDestExecution, validUntil, uint48(0), root, proof[0], proofDst, signature);
    }

    /// @dev Sends USDC via Stargate on ETH fork, records logs, relays via pigeon to Base
    function _sendAndRelay(uint256 amountLD, uint256 minAmountLD) internal {
        IStargate.SendParam memory sendParam = IStargate.SendParam({
            dstEid: EID_BASE,
            to: bytes32(uint256(uint160(_adapterTarget))),
            amountLD: amountLD,
            minAmountLD: minAmountLD,
            extraOptions: COMPOSE_EXTRA_OPTIONS,
            composeMsg: _composeMsg,
            oftCmd: bytes("")
        });

        IStargate.MessagingFee memory fee = IStargate(STARGATE_USDC_POOL_ETH).quoteSend(sendParam, false);
        console2.log("LZ fee for E2E compose bridge:", fee.nativeFee);

        vm.prank(sender);
        IERC20(USDC_ETH).approve(STARGATE_USDC_POOL_ETH, amountLD);

        vm.recordLogs();

        vm.prank(sender);
        IStargate(STARGATE_USDC_POOL_ETH).sendToken{ value: fee.nativeFee }(sendParam, fee, sender);

        assertEq(IERC20(USDC_ETH).balanceOf(sender), 0, "All USDC should be bridged from sender");
        console2.log("Source: sendToken with composeMsg succeeded");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        lzHelper.help(LZ_ENDPOINT_BASE, baseForkId, logs);
    }

    /// @dev Switches to Base fork, triggers lzCompose on deployed adapter, asserts happy path
    function _executeDstComposeAndAssert(uint256 minAmountLD) internal {
        vm.selectFork(baseForkId);

        uint256 amountReceived = IERC20(USDC_BASE).balanceOf(_adapterTarget);
        console2.log("USDC received at adapter on Base:", amountReceived);
        assertGt(amountReceived, 0, "Adapter should have received USDC via lzReceive");
        assertGe(amountReceived, minAmountLD, "Should receive at least minAmountLD");

        bytes memory composeMsgCodec = abi.encodePacked(
            uint64(0), uint32(EID_ETHEREUM), uint256(amountReceived), bytes32(uint256(uint160(sender))), _composeMsg
        );

        vm.prank(LZ_ENDPOINT_BASE);
        ILayerZeroComposer(_adapterTarget).lzCompose(
            STARGATE_USDC_POOL_BASE, bytes32(0), composeMsgCodec, address(0), bytes("")
        );

        assertEq(
            IERC20(USDC_BASE).balanceOf(dstAccount), amountReceived, "dstAccount should receive all bridged USDC"
        );
        assertEq(IERC20(USDC_BASE).balanceOf(_adapterTarget), 0, "Adapter should be empty after compose");

        assertTrue(
            ISuperDestinationExecutor(SUPER_DST_EXECUTOR_BASE).isMerkleRootUsed(dstAccount, _merkleRoot),
            "Merkle root should be marked as used on real SuperDestinationExecutor"
        );

        console2.log("E2E success: USDC bridged via Stargate, destination execution validated, root marked");
    }

    /// @dev Asserts that an ExecutionFailed event was emitted in recorded logs
    function _assertExecutionFailedEmitted() internal {
        _assertEventEmitted(vm.getRecordedLogs(), "ExecutionFailed(bytes32,address)");
    }

    /// @dev Generic helper: asserts an event with the given signature was emitted in the logs
    function _assertEventEmitted(Vm.Log[] memory logs, string memory eventSig) internal pure {
        bytes32 sig = keccak256(bytes(eventSig));
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == sig) return;
        }
        revert(string.concat("Expected event not emitted: ", eventSig));
    }

    /// @dev Executes a ClaimFailedTransferHook claim: setContext + preExecute + claim + postExecute
    function _executeHookClaim(
        ClaimFailedTransferHook hook,
        address adapter,
        address token,
        uint256 amount,
        address user
    )
        internal
    {
        bytes memory hookData = abi.encodePacked(adapter, token, amount);
        Execution[] memory execs = hook.build(address(0), user, hookData);
        hook.setExecutionContext(user);
        for (uint256 i = 0; i < execs.length; i++) {
            vm.prank(user);
            (bool ok,) = execs[i].target.call(execs[i].callData);
            assertTrue(ok, "Hook execution step failed");
        }
    }

    /// @dev Creates a Nexus smart account on Base fork with deployed SUPER_DST_VALIDATOR + SUPER_DST_EXECUTOR
    function _createDstAccount() internal {
        INexusFactory factory = INexusFactory(CHAIN_8453_NEXUS_FACTORY);
        INexusBootstrap bootstrap = INexusBootstrap(CHAIN_8453_NEXUS_BOOTSTRAP);

        BootstrapConfig[] memory validators = new BootstrapConfig[](1);
        validators[0] = BootstrapConfig({ module: SUPER_DST_VALIDATOR_BASE, data: abi.encode(signer) });

        BootstrapConfig[] memory executors = new BootstrapConfig[](1);
        executors[0] = BootstrapConfig({ module: SUPER_DST_EXECUTOR_BASE, data: "" });

        BootstrapConfig memory hook = BootstrapConfig({ module: address(0), data: "" });
        BootstrapConfig[] memory fallbacks = new BootstrapConfig[](0);

        bytes memory initData = bootstrap.getInitNexusCalldata(
            validators, executors, hook, fallbacks, IERC7484(address(0)), new address[](0), 0
        );

        bytes32 salt = keccak256("e2e_dst_account");
        dstAccount = factory.computeAccountAddress(initData, salt);
        factory.createAccount(initData, salt);

        assertTrue(dstAccount.code.length > 0, "dstAccount should have code on Base");
        vm.label(dstAccount, "DstAccount");
        console2.log("Created dstAccount on Base:", dstAccount);
    }

    /// @dev Signs a merkle root using the "SuperValidator" namespace
    function _signRoot(bytes32 root) internal view returns (bytes memory) {
        bytes32 messageHash = keccak256(abi.encode("SuperValidator", root));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signingKey, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }
}

/// @dev Helper contract that rejects all incoming ETH transfers (no receive/fallback)
contract ETHRejecter {
    // Intentionally has no receive() or fallback() — ETH transfers revert
}
