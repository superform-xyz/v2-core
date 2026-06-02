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
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, SUPER_DST_EXECUTOR_BASE);
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
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, SUPER_DST_EXECUTOR_BASE);
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
        StargateAdapter localAdapter = new StargateAdapter(LZ_ENDPOINT_BASE, SUPER_DST_EXECUTOR_BASE);
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
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

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
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 executionFailedSig = keccak256("ExecutionFailed(bytes32,address,bytes)");
        bool found = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == executionFailedSig) {
                found = true;
                break;
            }
        }
        assertTrue(found, "ExecutionFailed event should have been emitted");
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
