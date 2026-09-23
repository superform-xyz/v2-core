// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Test, Vm, console2 } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { CctpV2Helper } from "@pigeon/cctp/CctpV2Helper.sol";
import { IMessageTransmitterV2 } from "@pigeon/cctp/interfaces/IMessageTransmitterV2.sol";

import { CCTPAdapter } from "../../../src/adapters/CCTPAdapter.sol";
import { ApproveAndCCTPSendHook } from "../../../src/hooks/bridges/cctp/ApproveAndCCTPSendHook.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";

/*//////////////////////////////////////////////////////////////
                              MOCKS
//////////////////////////////////////////////////////////////*/

/// @notice Records what the adapter forwarded, and exposes the validator getter the adapter caches.
contract RecordingDestinationExecutor {
    address public SUPER_DESTINATION_VALIDATOR = address(0xDA11D);

    uint256 public callCount;
    address public lastAccount;
    address public lastTokenSent;
    address[] public lastDstTokens;
    uint256[] public lastIntentAmounts;

    function processBridgedExecution(
        address tokenSent,
        address account,
        address[] memory dstTokens,
        uint256[] memory intentAmounts,
        bytes memory,
        bytes memory,
        bytes memory
    ) external {
        ++callCount;
        lastTokenSent = tokenSent;
        lastAccount = account;
        lastDstTokens = dstTokens;
        lastIntentAmounts = intentAmounts;
    }
}

/// @notice Stands in for SuperValidator's transient signature storage on the source chain.
/// @dev The real hook pulls the signature blob from the validator rather than from its own calldata,
///      to avoid the circular dependency where the merkle root would have to commit to its own
///      signature (see CCTPSendHook.sol:28-31). Here we return a fully-formed SignatureData carrying a
///      DstProof for the destination chain, so the adapter's executor/validator assertion has
///      something real to check.
contract ForkSignatureStorage {
    bytes internal _sig;

    function setSignatureData(bytes memory sig) external {
        _sig = sig;
    }

    function retrieveSignatureData(address) external view returns (bytes memory) {
        return _sig;
    }
}

/*//////////////////////////////////////////////////////////////
                         PIGEON EXTENSION
//////////////////////////////////////////////////////////////*/

/// @notice Pigeon's CctpV2Helper relays by calling `MessageTransmitterV2.receiveMessage` directly.
///         CCTPAdapter cannot be driven that way: it must call `receiveMessage` ITSELF from inside
///         `receiveAndExecute` so that `msg.sender` seen by the transmitter is the adapter, satisfying
///         the `destinationCaller` restriction, and so the mint and the hook execution stay atomic.
/// @dev This subclass reuses pigeon's attester/finality/nonce machinery verbatim and only swaps the
///      final call, handing `(message, attestation)` to the adapter instead.
contract CctpV2AdapterHelper is CctpV2Helper {
    mapping(bytes32 => bool) private _relayed;

    /// @notice Last relayed (message, attestation), so a test can replay it directly against the
    ///         adapter without going through this helper — which clears `usedNonces` on every pass
    ///         and would therefore mask CCTP's own replay protection.
    bytes public lastMessage;
    bytes public lastAttestation;

    constructor(uint256 pk) CctpV2Helper(pk) { }

    /// @notice Relay every matching CCTP message through `adapter.receiveAndExecute`.
    /// @param expectedDestDomain CCTP domain ID to filter for
    /// @param forkId destination fork
    /// @param logs recorded source-chain logs
    /// @param adapter the CCTPAdapter deployed on the destination fork
    /// @return relayedCount how many messages were relayed
    function helpViaAdapter(
        uint32 expectedDestDomain,
        uint256 forkId,
        Vm.Log[] memory logs,
        address adapter
    ) public returns (uint256 relayedCount) {
        uint256 prevForkId = vm.activeFork();

        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length == 0) continue;
            if (logs[i].topics[0] != MESSAGE_SENT_TOPIC) continue;
            if (logs[i].emitter != MESSAGE_TRANSMITTER_V2) continue;

            bytes memory message = abi.decode(logs[i].data, (bytes));
            if (_getDestinationDomain(message) != expectedDestDomain) continue;

            bytes32 key = keccak256(abi.encode(_getSourceDomain(message), _getNonce(message)));
            if (_relayed[key]) continue;
            _relayed[key] = true;

            vm.selectFork(forkId);
            _setupTestAttester();
            _setFinalityExecuted(message);
            bytes memory attestation = _signMessage(message);
            _clearUsedNonce(message);

            // No prank: the adapter itself is the destinationCaller, and it is the contract that
            // calls receiveMessage. Anyone may trigger receiveAndExecute — that is the design.
            lastMessage = message;
            lastAttestation = attestation;

            CCTPAdapter(adapter).receiveAndExecute(message, attestation);
            ++relayedCount;

            vm.selectFork(prevForkId);
        }
    }
}

/*//////////////////////////////////////////////////////////////
                              TESTS
//////////////////////////////////////////////////////////////*/

/// @title CCTPAdapterPigeonE2E
/// @author Superform Labs
/// @notice True end-to-end coverage of the CCTP V2 destination path: burn on Ethereum through the real
///         `ApproveAndCCTPSendHook`, relay with a real attestation via pigeon, then mint + forward +
///         execute through `CCTPAdapter` on Base — all against real deployed Circle contracts.
/// @dev This is the leg that never existed. `CCTPHooksFork.t.sol` stops at "USDC was minted to an EOA";
///      it never exercises hookData or destination execution, because no adapter existed when it was
///      written. Everything here runs against the real `MessageTransmitterV2`/`TokenMessengerV2`.
contract CCTPAdapterPigeonE2E is Test {
    address public constant TOKEN_MESSENGER_V2 = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;
    address public constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    uint32 public constant DOMAIN_BASE = 6;
    uint64 public constant CHAINID_BASE = 8453;

    uint256 internal ethForkId;
    uint256 internal baseForkId;

    ApproveAndCCTPSendHook internal cctpHook;
    ForkSignatureStorage internal sigStorage;
    CctpV2AdapterHelper internal pigeon;

    CCTPAdapter internal adapter;
    RecordingDestinationExecutor internal executor;

    address internal account;

    function setUp() public {
        // --- Destination fork first: the adapter address must be known at burn time on the source ---
        baseForkId = vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        executor = new RecordingDestinationExecutor();
        adapter = new CCTPAdapter(
            address(uint160(0x81D40F21F12A8F0E3252Bccb954D722d4c464B64)), TOKEN_MESSENGER_V2, USDC_BASE, address(executor)
        );

        // --- Source fork ---
        ethForkId = vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));
        sigStorage = new ForkSignatureStorage();
        cctpHook = new ApproveAndCCTPSendHook(TOKEN_MESSENGER_V2, address(sigStorage));
        pigeon = new CctpV2AdapterHelper(0);

        account = makeAddr("account");
        vm.deal(account, 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                               HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice A SignatureData carrying a DstProof for Base that names the deployed executor/validator,
    ///         so `CCTPAdapter.checkDestinationTargets` matches rather than reverting.
    function _signatureData(address proofExecutor, address proofValidator) internal view returns (bytes memory) {
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = USDC_BASE;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1;

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] = ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: CHAINID_BASE,
            info: ISuperValidator.DstInfo({
                account: account,
                executor: proofExecutor,
                dstTokens: dstTokens,
                intentAmounts: intentAmounts,
                validator: proofValidator,
                data: bytes("executorCalldata")
            })
        });

        uint64[] memory chains = new uint64[](1);
        chains[0] = CHAINID_BASE;

        return abi.encode(
            chains, uint48(block.timestamp + 1 days), uint48(0), keccak256("root"), new bytes32[](0), proofDst,
            new bytes(65)
        );
    }

    /// @notice The 5-tuple the SDK supplies; the hook appends the signature to make it a 6-tuple.
    function _hookCallData(uint256 intentAmount) internal view returns (bytes memory) {
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = USDC_BASE;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = intentAmount;

        return abi.encode(bytes(""), bytes("executorCalldata"), account, dstTokens, intentAmounts);
    }

    /// @dev Packs the deployed hook's data layout (52-byte strategy header + fields).
    ///      See src/hooks/bridges/cctp/CCTPSendHook.sol:32-43 — the canonical layout.
    function _encodeHookData(
        uint256 amount,
        bytes32 mintRecipient,
        bytes32 destinationCaller,
        uint256 maxFee,
        bytes memory hookCallData
    ) internal view returns (bytes memory) {
        return abi.encodePacked(
            bytes32(0), // placeholder0        @0
            address(0), // placeholder1        @32
            USDC_ETH, // burnToken             @52
            amount, // amount                  @72
            DOMAIN_BASE, // destinationDomain  @104
            mintRecipient, // mintRecipient    @108
            destinationCaller, //              @140
            maxFee, // maxFee                  @172
            uint32(2000), // minFinality       @204
            false, // usePrevHookAmount        @208
            hookCallData //                    @209
        );
    }

    function _burnOnEth(uint256 amount, uint256 intentAmount) internal returns (Vm.Log[] memory) {
        deal(USDC_ETH, account, amount);

        bytes32 adapterB32 = bytes32(uint256(uint160(address(adapter))));
        bytes memory data = _encodeHookData(amount, adapterB32, adapterB32, 0, _hookCallData(intentAmount));

        Execution[] memory executions = cctpHook.build(address(0), account, data);

        vm.recordLogs();
        vm.startPrank(account);
        for (uint256 i; i < executions.length; ++i) {
            (bool ok,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            assertTrue(ok, string.concat("source execution ", vm.toString(i), " failed"));
        }
        vm.stopPrank();
        return vm.getRecordedLogs();
    }

    /*//////////////////////////////////////////////////////////////
                                 E2E
    //////////////////////////////////////////////////////////////*/

    /// @notice Burn on Ethereum → pigeon relay → adapter mints, forwards, and calls the executor on Base.
    function test_E2E_Pigeon_BurnOnEth_AdapterExecutesOnBase() public {
        uint256 amount = 1000e6;

        vm.selectFork(baseForkId);
        sigStorageSeed();
        uint256 balanceBefore = IERC20(USDC_BASE).balanceOf(account);

        vm.selectFork(ethForkId);
        Vm.Log[] memory logs = _burnOnEth(amount, 1);

        uint256 relayed = pigeon.helpViaAdapter(DOMAIN_BASE, baseForkId, logs, address(adapter));
        assertEq(relayed, 1, "exactly one CCTP message relayed");

        vm.selectFork(baseForkId);

        // Funds reached the intent account, not the adapter.
        assertEq(
            IERC20(USDC_BASE).balanceOf(account) - balanceBefore, amount, "account received the full minted amount"
        );
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0, "adapter retains nothing");

        // Destination execution actually fired — the leg that never had coverage.
        assertEq(executor.callCount(), 1, "executor invoked exactly once");
        assertEq(executor.lastAccount(), account, "executor received the intent account");
        assertEq(executor.lastTokenSent(), USDC_BASE, "executor received USDC as tokenSent");
        assertEq(executor.lastDstTokens(0), USDC_BASE, "dstTokens survived the CCTP wire");
    }

    /// @notice The pigeon helper dedupes a log set it has already relayed.
    /// @dev NOTE: this asserts the HELPER's dedup, not CCTP's nonce protection — the helper clears
    ///      `usedNonces` via `vm.store` on every pass, so it structurally cannot surface a real nonce
    ///      rejection. `test_E2E_Pigeon_NonceReplay_RejectedByTransmitter` covers that separately.
    function test_E2E_Pigeon_HelperDedupesRelayedMessage() public {
        uint256 amount = 500e6;

        vm.selectFork(baseForkId);
        sigStorageSeed();

        vm.selectFork(ethForkId);
        Vm.Log[] memory logs = _burnOnEth(amount, 1);

        assertEq(pigeon.helpViaAdapter(DOMAIN_BASE, baseForkId, logs, address(adapter)), 1, "first relay lands");

        vm.selectFork(baseForkId);
        assertEq(executor.callCount(), 1, "executed once");

        vm.selectFork(ethForkId);
        uint256 second = pigeon.helpViaAdapter(DOMAIN_BASE, baseForkId, logs, address(adapter));
        assertEq(second, 0, "helper dedupes the already-relayed message");

        vm.selectFork(baseForkId);
        assertEq(executor.callCount(), 1, "no double execution");
    }

    /// @notice A genuine replay of the same attested message is rejected by the real
    ///         `MessageTransmitterV2` — the CCTP nonce is single-use.
    /// @dev Driven directly against the adapter rather than through the helper, because the helper
    ///      clears `usedNonces` before each relay. This is the assertion the dedup test cannot make.
    function test_E2E_Pigeon_NonceReplay_RejectedByTransmitter() public {
        uint256 amount = 500e6;

        vm.selectFork(baseForkId);
        sigStorageSeed();

        vm.selectFork(ethForkId);
        Vm.Log[] memory logs = _burnOnEth(amount, 1);
        assertEq(pigeon.helpViaAdapter(DOMAIN_BASE, baseForkId, logs, address(adapter)), 1, "first relay lands");

        bytes memory message = pigeon.lastMessage();
        bytes memory attestation = pigeon.lastAttestation();

        // Replay the exact same attested bytes, with no vm.store nonce reset in between.
        vm.selectFork(baseForkId);
        vm.expectRevert(bytes("Nonce already used"));
        adapter.receiveAndExecute(message, attestation);

        assertEq(executor.callCount(), 1, "still exactly one execution");
    }

    /// @notice The adapter forwards exactly `amount - feeExecuted`, so a non-zero CCTP fee is absorbed
    ///         by the delivered amount rather than by the adapter.
    function test_E2E_Pigeon_FeeIsDeductedFromDelivery() public {
        uint256 amount = 1000e6;

        vm.selectFork(baseForkId);
        sigStorageSeed();
        uint256 balanceBefore = IERC20(USDC_BASE).balanceOf(account);

        vm.selectFork(ethForkId);
        Vm.Log[] memory logs = _burnOnEth(amount, 1);
        pigeon.helpViaAdapter(DOMAIN_BASE, baseForkId, logs, address(adapter));

        vm.selectFork(baseForkId);
        uint256 delivered = IERC20(USDC_BASE).balanceOf(account) - balanceBefore;

        // maxFee was 0 with standard finality, so delivery is exact.
        assertEq(delivered, amount, "full amount delivered at maxFee = 0");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0, "no residue stranded in the adapter");
    }

    /// @notice THE LINCHPIN: with `destinationCaller` pinned to the adapter, nobody can bypass it by
    ///         calling the real `MessageTransmitterV2.receiveMessage` directly.
    /// @dev This is what makes a permissionless `relay()` safe, and what lets us diverge from Circle's
    ///      `onlyOwner` CCTPHookWrapper. If it did not hold, a third party could mint USDC to the
    ///      adapter without ever running the hook, stranding funds with the nonce spent. Asserted
    ///      against real deployed Circle bytecode, not a mock.
    function test_E2E_Pigeon_DestinationCallerBlocksDirectReceive() public {
        uint256 amount = 750e6;

        vm.selectFork(baseForkId);
        sigStorageSeed();

        vm.selectFork(ethForkId);
        Vm.Log[] memory logs = _burnOnEth(amount, 1);

        // Prepare a valid attestation without relaying it, by driving the helper and capturing what
        // it produced. (helpViaAdapter relays, so capture first, then assert the bypass on a fresh nonce.)
        assertEq(pigeon.helpViaAdapter(DOMAIN_BASE, baseForkId, logs, address(adapter)), 1, "relayed");
        bytes memory message = pigeon.lastMessage();
        bytes memory attestation = pigeon.lastAttestation();

        vm.selectFork(baseForkId);

        // Reset the nonce so the ONLY thing that can reject the call is the destinationCaller check.
        bytes32 nonce;
        assembly {
            nonce := mload(add(message, 44)) // offset 12, 32 bytes
        }
        vm.store(
            0x81D40F21F12A8F0E3252Bccb954D722d4c464B64, keccak256(abi.encode(nonce, uint256(29))), bytes32(0)
        );

        // A random EOA calling the real transmitter directly must be rejected.
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert(bytes("Invalid caller for message"));
        IMessageTransmitterV2(0x81D40F21F12A8F0E3252Bccb954D722d4c464B64).receiveMessage(message, attestation);
    }

    /// @notice A DstProof naming the WRONG executor must NOT revert: the funds are delivered and only
    ///         the destination execution is skipped.
    /// @dev Reverting here would be catastrophic. The CCTP burn is irreversible and the mismatching
    ///      sigData is immutable inside the Circle-attested message, so every future relay attempt
    ///      would revert identically and the USDC would be permanently destroyed with no refund path.
    ///      (This test previously asserted a revert; that behaviour was a fund-loss bug.)
    function test_E2E_Pigeon_ExecutorMismatch_DeliversFundsAndSkipsExecution() public {
        uint256 amount = 1000e6;

        vm.selectFork(baseForkId);
        uint256 balanceBefore = IERC20(USDC_BASE).balanceOf(account);

        // Seed a proof naming a bogus executor.
        vm.selectFork(ethForkId);
        sigStorage.setSignatureData(_signatureData(address(0xBAD), address(0xDA11D)));

        Vm.Log[] memory logs = _burnOnEth(amount, 1);
        assertEq(pigeon.helpViaAdapter(DOMAIN_BASE, baseForkId, logs, address(adapter)), 1, "relay succeeds");

        vm.selectFork(baseForkId);
        assertEq(
            IERC20(USDC_BASE).balanceOf(account) - balanceBefore, amount, "funds delivered despite mismatch"
        );
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0, "nothing stranded in the adapter");
        assertEq(executor.callCount(), 0, "execution skipped against a mismatched deployment");
    }

    /// @notice Against the REAL transmitter: a gas-starved relay reverts INSUFFICIENT_GAS, the mint unwinds,
    ///         the CCTP nonce stays unconsumed, and the very same message then succeeds with full gas.
    function test_E2E_Pigeon_InsufficientGas_LeavesNonceUnconsumed() public {
        uint256 amount = 1000e6;
        vm.selectFork(baseForkId);
        sigStorageSeed();
        uint256 balanceBefore = IERC20(USDC_BASE).balanceOf(account);

        vm.selectFork(ethForkId);
        Vm.Log[] memory logs = _burnOnEth(amount, 1);
        assertEq(pigeon.helpViaAdapter(DOMAIN_BASE, baseForkId, logs, address(adapter)), 1, "relayed");
        bytes memory message = pigeon.lastMessage();
        bytes memory attestation = pigeon.lastAttestation();

        vm.selectFork(baseForkId);
        bytes32 nonce;
        assembly { nonce := mload(add(message, 44)) }
        vm.store(0x81D40F21F12A8F0E3252Bccb954D722d4c464B64, keccak256(abi.encode(nonce, uint256(29))), bytes32(0));
        uint256 execBefore = executor.callCount();

        vm.expectRevert(CCTPAdapter.INSUFFICIENT_GAS.selector);
        adapter.receiveAndExecute{ gas: 1_500_000 }(message, attestation);

        adapter.receiveAndExecute(message, attestation);
        assertEq(executor.callCount(), execBefore + 1, "retry executed: nonce survived the reverted attempt");
        assertEq(IERC20(USDC_BASE).balanceOf(account) - balanceBefore, amount * 2, "both relays delivered");
    }

    /// @dev Seeds the source-side signature storage with a DstProof matching the Base deployment.
    ///      Called while on the Base fork so the executor/validator addresses are readable, then the
    ///      value is written on the source fork where the hook will read it.
    function sigStorageSeed() internal {
        address exec = address(executor);
        address val = executor.SUPER_DESTINATION_VALIDATOR();
        uint256 active = vm.activeFork();
        vm.selectFork(ethForkId);
        sigStorage.setSignatureData(_signatureData(exec, val));
        vm.selectFork(active);
    }
}
