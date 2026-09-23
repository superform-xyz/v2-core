// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test, Vm, console2 } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { RelayFillHelper } from "../../utils/RelayFillHelper.sol";

import { RelayAdapter } from "../../../src/adapters/RelayAdapter.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { IRelayDepository } from "../../../src/vendor/bridges/relay/IRelayDepository.sol";

/*//////////////////////////////////////////////////////////////
                              MOCKS
//////////////////////////////////////////////////////////////*/

/// @notice Records what the adapter forwarded to the destination executor.
contract RecordingDestinationExecutor {
    address public SUPER_DESTINATION_VALIDATOR = address(0xFACE);

    uint256 public callCount;
    address public lastAccount;
    address public lastTokenSent;

    function processBridgedExecution(
        address tokenSent,
        address account,
        address[] memory,
        uint256[] memory,
        bytes memory,
        bytes memory,
        bytes memory
    ) external {
        ++callCount;
        lastTokenSent = tokenSent;
        lastAccount = account;
    }
}

/// @notice A contract that cannot receive ETH and can never be `msg.sender` of claimFailedTransfer.
contract NoReceive { }

/*//////////////////////////////////////////////////////////////
                              TESTS
//////////////////////////////////////////////////////////////*/

/// @title RelayAdapterPigeonE2E
/// @author Superform Labs
/// @notice Two-fork end-to-end coverage of the Relay destination path, driven by pigeon's
///         `RelayHelper`: a real `RelayDepository` deposit on Ethereum, then a simulated solver fill
///         on Base that delivers funds to `RelayAdapter` and calls `processRelayExecution`.
/// @dev Why this suite exists. `RelayAdapterE2EFork.t.sol` has 14 tests but is SINGLE-FORK: it never
///      creates a source chain, and fabricates the solver fill with `deal(USDC_BASE, adapter, amount)`
///      before calling the adapter directly. Nothing there exercises a real Relay deposit, so nothing
///      verifies that the destination leg is actually reachable from a genuine origin deposit.
/// @dev Pigeon's `RelayHelper` models the solver's router multicall with `allowFailure = false` — the
///      fill and `processRelayExecution` execute atomically in one batch, which is the arrangement
///      RelayAdapter's NatSpec depends on for safety. This suite exercises BOTH that atomic path and
///      the non-atomic path the NatSpec flags as a documented residual risk.
contract RelayAdapterPigeonE2E is RelayFillHelper {
    /// @dev Relay's canonical depository (same address on Ethereum and Base) — script/utils/Constants.sol:103
    address internal constant RELAY_DEPOSITORY = 0x4cD00E387622C35bDDB9b4c962C136462338BC31;

    address internal constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    uint256 internal ethForkId;
    uint256 internal baseForkId;

    RelayAdapter internal adapter;
    RecordingDestinationExecutor internal executor;

    address internal depositor;
    address internal victim;
    address internal attacker;
    address internal solver;

    function setUp() public {
        // Destination first: the adapter address must be known when the fill is constructed.
        baseForkId = vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        executor = new RecordingDestinationExecutor();
        adapter = new RelayAdapter(address(executor));
        vm.label(address(adapter), "RelayAdapter");

        ethForkId = vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));

        depositor = makeAddr("depositor");
        victim = makeAddr("victim");
        attacker = makeAddr("attacker");
        solver = makeAddr("relaySolver");
    }

    /*//////////////////////////////////////////////////////////////
                               HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Real deposit into the real RelayDepository on the Ethereum fork.
    function _depositOnEth(uint256 amount, bytes32 depositId) internal returns (Vm.Log[] memory) {
        deal(USDC_ETH, depositor, amount);

        vm.recordLogs();
        vm.startPrank(depositor);
        IERC20(USDC_ETH).approve(RELAY_DEPOSITORY, amount);
        IRelayDepository(RELAY_DEPOSITORY).depositErc20(depositor, USDC_ETH, amount, depositId);
        vm.stopPrank();
        return vm.getRecordedLogs();
    }

    function _makeDstProof(address account, uint64 chainId)
        internal
        view
        returns (ISuperValidator.DstProof memory)
    {
        return ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: chainId,
            info: ISuperValidator.DstInfo({
                account: account,
                executor: address(executor),
                dstTokens: new address[](0),
                intentAmounts: new uint256[](0),
                validator: address(0xFACE),
                data: bytes("executorCalldata")
            })
        });
    }

    /// @dev The compact 2-field message RelayAdapter expects: abi.encode(initData, sigData)
    function _message(address account, uint64 chainId) internal view returns (bytes memory) {
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] = _makeDstProof(account, chainId);

        uint64[] memory chains = new uint64[](1);
        chains[0] = chainId;

        bytes memory sigData = abi.encode(
            chains,
            uint48(type(uint48).max),
            uint48(0),
            keccak256("root"),
            new bytes32[](0),
            proofDst,
            hex"abcdef"
        );
        return abi.encode(bytes(""), sigData);
    }

    /// @dev Drives a solver fill for a recorded deposit, anchored to the real source-chain event.
    function _fill(
        bytes32 depositId,
        address token,
        uint256 amount,
        bytes memory adapterCalldata,
        Vm.Log[] memory logs
    ) internal {
        Fill memory f;
        f.depository = RELAY_DEPOSITORY;
        f.depositId = depositId;
        f.solver = solver;
        f.outputToken = token;
        f.outputAmount = amount;
        f.dstForkId = baseForkId;
        fillViaAdapter(f, address(adapter), adapterCalldata, logs);
    }

    /// @dev External boundary so `vm.expectRevert` can observe reverts from `_fill` (cheatcodes
    ///      require the revert to occur at a lower call depth than the cheatcode itself).
    function fillExternal(
        bytes32 depositId,
        address token,
        uint256 amount,
        bytes memory adapterCalldata,
        Vm.Log[] memory logs
    ) external {
        _fill(depositId, token, amount, adapterCalldata, logs);
    }

    function _adapterCalldata(address account, uint256 amount) internal view returns (bytes memory) {
        return abi.encodeCall(
            RelayAdapter.processRelayExecution, (USDC_BASE, amount, _message(account, uint64(8453)))
        );
    }

    /*//////////////////////////////////////////////////////////////
                          E2E — ATOMIC FILL
    //////////////////////////////////////////////////////////////*/

    /// @notice Real Ethereum deposit → pigeon solver fill on Base → funds delivered, executor called.
    function test_E2E_Pigeon_DepositOnEth_AdapterExecutesOnBase() public {
        uint256 amount = 1000e6;
        Vm.Log[] memory logs = _depositOnEth(amount, keccak256("order-1"));

        _fill(keccak256("order-1"), USDC_BASE, amount, _adapterCalldata(victim, amount), logs);

        vm.selectFork(baseForkId);
        assertEq(IERC20(USDC_BASE).balanceOf(victim), amount, "account funded by the solver fill");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0, "adapter retains nothing");
        assertEq(executor.callCount(), 1, "destination execution fired");
        assertEq(executor.lastAccount(), victim, "executor received the intent account");
        assertEq(executor.lastTokenSent(), USDC_BASE, "tokenSent forwarded");
    }

    /// @notice The helper refuses to fill when no matching Relay deposit was emitted on the source.
    /// @dev Proves this harness is not vacuous — it is anchored to a real origin deposit event.
    function test_E2E_Pigeon_NoDepositEvent_HelperRefusesToFill() public {
        Vm.Log[] memory empty = new Vm.Log[](0);

        vm.expectRevert(bytes("RelayFillHelper: no matching deposit event"));
        this.fillExternal(keccak256("order-never-deposited"), USDC_BASE, 1000e6, _adapterCalldata(victim, 1000e6), empty);
    }

    /// @notice A deposit id that does not match the recorded deposit is rejected.
    function test_E2E_Pigeon_DepositIdMismatch_HelperRefusesToFill() public {
        Vm.Log[] memory logs = _depositOnEth(500e6, keccak256("order-A"));

        vm.expectRevert(bytes("RelayFillHelper: no matching deposit event"));
        this.fillExternal(keccak256("order-B"), USDC_BASE, 500e6, _adapterCalldata(victim, 500e6), logs); // different id
    }

    /*//////////////////////////////////////////////////////////////
              SECURITY — THE NON-ATOMIC WINDOW (documented residual)
    //////////////////////////////////////////////////////////////*/

    /// @notice **The core security property of RelayAdapter.** Inside the solver's atomic batch the
    ///         fill and `processRelayExecution` are inseparable, so no third party can interleave.
    /// @dev `RelayHelper` models the router multicall with allowFailure = false, so if the adapter call
    ///      reverts the funds-delivery leg unwinds too — the solver is never left funding a stranger.
    function test_E2E_Pigeon_AtomicBatch_RevertUnwindsTheFill() public {
        uint256 amount = 1000e6;
        Vm.Log[] memory logs = _depositOnEth(amount, keccak256("order-atomic"));

        // A message with no DstProof for THIS chain makes processRelayExecution revert.
        bytes memory badCalldata = abi.encodeCall(
            RelayAdapter.processRelayExecution, (USDC_BASE, amount, _message(victim, uint64(999_999)))
        );

        vm.expectRevert(RelayAdapter.NO_DST_PROOF_FOR_CHAIN.selector);
        this.fillExternal(keccak256("order-atomic"), USDC_BASE, amount, badCalldata, logs);

        // The whole batch unwound: nothing was delivered anywhere.
        vm.selectFork(baseForkId);
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0, "fill unwound with the revert");
        assertEq(IERC20(USDC_BASE).balanceOf(victim), 0, "victim received nothing");
    }

    /// @notice **Documents the residual risk RelayAdapter's NatSpec acknowledges.** If the fill is NOT
    ///         atomic with `processRelayExecution`, funds resting in the adapter are claimable by
    ///         anyone presenting a validly-signed message for their own account.
    /// @dev This is not a bug in the adapter — `processRelayExecution` is permissionless by design and
    ///      the executor's signature check gates only the hook execution, never the token delivery.
    ///      It is a hard requirement on the bundler/solver to keep both legs in one transaction. This
    ///      test pins the exact behaviour so a future refactor cannot silently widen the window.
    function test_E2E_Pigeon_NonAtomicWindow_RestingFundsAreSweepable() public {
        uint256 amount = 1000e6;

        // Leg 1 only: the solver delivers funds for the victim's intent but does NOT call the adapter.
        vm.selectFork(baseForkId);
        deal(USDC_BASE, address(adapter), amount);

        // An attacker presents their OWN message and sweeps the resting balance.
        vm.prank(attacker);
        adapter.processRelayExecution(USDC_BASE, amount, _message(attacker, uint64(8453)));

        assertEq(IERC20(USDC_BASE).balanceOf(attacker), amount, "resting funds swept by the attacker");
        assertEq(IERC20(USDC_BASE).balanceOf(victim), 0, "victim got nothing");

        // Recorded so the invariant is explicit: atomicity is what prevents this, not the adapter.
        console2.log("NON-ATOMIC WINDOW: swept", amount);
    }

    /// @notice **No signature is required for funds to move.** `_extractFromSigData` is a bare
    ///         `abi.decode`; the only gates before `_tryTransfer` are "a DstProof exists for this
    ///         chain", "account != 0" and a POOL-level balance check. The real signature check lives
    ///         inside `processBridgedExecution`, which runs AFTER the transfer and inside `catch {}`.
    /// @dev The contract NatSpec describes the residual as an attacker needing "a validly-signed
    ///      message for their own account". That overstates the attacker's cost: any syntactically
    ///      well-formed byte string works, with an empty signature. Pinned here as a named invariant so
    ///      a refactor in either direction is caught.
    function test_Adversarial_NoSignatureRequired_FundsStillMove() public {
        uint256 amount = 1000e6;

        vm.selectFork(baseForkId);
        deal(USDC_BASE, address(adapter), amount);

        // A message with an EMPTY signature and a fabricated proof naming the attacker.
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] = ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: uint64(block.chainid),
            info: ISuperValidator.DstInfo({
                account: attacker,
                executor: address(0),
                dstTokens: new address[](0),
                intentAmounts: new uint256[](0),
                validator: address(0),
                data: ""
            })
        });
        bytes memory sigData = abi.encode(
            new uint64[](0), uint48(0), uint48(0), bytes32(0), new bytes32[](0), proofDst, bytes("")
        );

        vm.prank(attacker);
        adapter.processRelayExecution(USDC_BASE, amount, abi.encode(bytes(""), sigData));

        assertEq(IERC20(USDC_BASE).balanceOf(attacker), amount, "unsigned message moved funds");
    }

    /// @notice The sweep is pooled, not per-intent: one attacker drains MULTIPLE victims' resting
    ///         fills in a single non-atomic window, and each victim's later leg-2 call then reverts.
    function test_Adversarial_MultiVictimSweep_InOneWindow() public {
        uint256 each = 500e6;

        vm.selectFork(baseForkId);
        // Two independent fills rest in the adapter (two users, same token).
        deal(USDC_BASE, address(adapter), each * 2);

        vm.startPrank(attacker);
        adapter.processRelayExecution(USDC_BASE, each, _message(attacker, uint64(8453)));
        adapter.processRelayExecution(USDC_BASE, each, _message(attacker, uint64(8453)));
        vm.stopPrank();

        assertEq(IERC20(USDC_BASE).balanceOf(attacker), each * 2, "both fills swept");

        // The legitimate leg-2 call for a victim now fails — the funds are gone, with no escrow.
        vm.expectRevert(RelayAdapter.INSUFFICIENT_FUNDS_RECEIVED.selector);
        adapter.processRelayExecution(USDC_BASE, each, _message(victim, uint64(8453)));
        assertEq(adapter.failedTransfers(victim, USDC_BASE), 0, "victim has no escrow to claim");
    }

    /// @notice Griefing variant: naming an unclaimable `account` destroys value instead of stealing it.
    /// @dev Native delivery to a contract with no receive/fallback fails the transfer, escrowing to an
    ///      address that can never call `claimFailedTransfer` — permanently dead funds.
    function test_Adversarial_BurnVariant_UnclaimableAccountStrandsFunds() public {
        uint256 amount = 1 ether;

        vm.selectFork(baseForkId);
        address unclaimable = address(new NoReceive());
        vm.deal(address(adapter), amount);

        vm.prank(attacker);
        adapter.processRelayExecution(address(0), amount, _message(unclaimable, uint64(8453)));

        assertEq(adapter.failedTransfers(unclaimable, address(0)), amount, "escrowed to a dead address");
        assertEq(adapter.totalEscrowed(address(0)), amount, "permanently excluded from spendable balance");
        assertEq(address(adapter).balance, amount, "ETH held but unrecoverable by anyone");
    }

    /// @notice Bounds the missing-gas-floor severity: a gas-starved executor call is recoverable,
    ///         because `processBridgedExecution` is permissionless and the merkle root is not consumed.
    /// @dev This is why RelayAdapter's lack of a MIN_EXECUTION_GAS floor is a nuisance, not fund-loss —
    ///      unlike CCTP, where the message nonce is spent and the relay is one-shot.
    function test_Adversarial_GasStarvedExecutor_IsRetriableDirectly() public {
        uint256 amount = 1000e6;

        vm.selectFork(baseForkId);
        deal(USDC_BASE, address(adapter), amount);

        // Starve the executor call; the transfer still lands and the catch swallows the failure.
        vm.prank(attacker);
        adapter.processRelayExecution{ gas: 250_000 }(USDC_BASE, amount, _message(victim, uint64(8453)));

        assertEq(IERC20(USDC_BASE).balanceOf(victim), amount, "funds delivered despite starved execution");

        // Anyone can re-drive the execution directly against the executor with adequate gas.
        uint256 before = executor.callCount();
        executor.processBridgedExecution(
            USDC_BASE, victim, new address[](0), new uint256[](0), bytes(""), bytes(""), bytes("")
        );
        assertEq(executor.callCount(), before + 1, "execution retriable by anyone");
    }

    /*//////////////////////////////////////////////////////////////
                    SECURITY — ESCROW ISOLATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Funds escrowed for a failed transfer are excluded from the spendable balance, so a
    ///         later relay cannot spend another user's escrow.
    /// @dev This is the `totalEscrowed` guard — RelayAdapter's answer to the permissionless `amount`.
    function test_E2E_Pigeon_EscrowedFunds_AreNotSpendableByANewRelay() public {
        uint256 amount = 1000e6;
        Vm.Log[] memory logs = _depositOnEth(amount, keccak256("order-escrow"));

        // Force the transfer to the victim to fail so the amount is escrowed.
        vm.selectFork(baseForkId);
        vm.mockCall(
            USDC_BASE, abi.encodeWithSelector(IERC20.transfer.selector, victim), abi.encode(false)
        );
        vm.selectFork(ethForkId);

        _fill(keccak256("order-escrow"), USDC_BASE, amount, _adapterCalldata(victim, amount), logs);

        vm.selectFork(baseForkId);
        vm.clearMockedCalls();
        assertEq(adapter.failedTransfers(victim, USDC_BASE), amount, "escrowed for the victim");
        assertEq(adapter.totalEscrowed(USDC_BASE), amount, "totalEscrowed tracks it");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), amount, "adapter holds the escrow");

        // The attacker cannot spend the escrowed balance even though the adapter physically holds it.
        vm.prank(attacker);
        vm.expectRevert(RelayAdapter.INSUFFICIENT_FUNDS_RECEIVED.selector);
        adapter.processRelayExecution(USDC_BASE, amount, _message(attacker, uint64(8453)));

        // The victim can still recover it.
        vm.prank(victim);
        adapter.claimFailedTransfer(USDC_BASE, amount);
        assertEq(IERC20(USDC_BASE).balanceOf(victim), amount, "victim recovered the escrow");
        assertEq(adapter.totalEscrowed(USDC_BASE), 0, "escrow accounting cleared");
    }

    /// @notice Escrow accounting stays consistent across a partial claim followed by a new relay.
    function test_E2E_Pigeon_PartialClaim_ThenNewRelay_AccountingHolds() public {
        uint256 amount = 1000e6;
        Vm.Log[] memory logs = _depositOnEth(amount, keccak256("order-partial"));

        vm.selectFork(baseForkId);
        vm.mockCall(
            USDC_BASE, abi.encodeWithSelector(IERC20.transfer.selector, victim), abi.encode(false)
        );
        vm.selectFork(ethForkId);

        _fill(keccak256("order-partial"), USDC_BASE, amount, _adapterCalldata(victim, amount), logs);

        vm.selectFork(baseForkId);
        vm.clearMockedCalls();

        vm.prank(victim);
        adapter.claimFailedTransfer(USDC_BASE, 400e6);
        assertEq(adapter.failedTransfers(victim, USDC_BASE), 600e6, "remaining escrow");
        assertEq(adapter.totalEscrowed(USDC_BASE), 600e6, "totalEscrowed decremented in step");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 600e6, "balance matches escrow");

        // Spendable balance is now zero: the remaining 600e6 is all escrowed.
        vm.prank(attacker);
        vm.expectRevert(RelayAdapter.INSUFFICIENT_FUNDS_RECEIVED.selector);
        adapter.processRelayExecution(USDC_BASE, 1, _message(attacker, uint64(8453)));
    }

    /*//////////////////////////////////////////////////////////////
                        E2E — NATIVE ETH PATH
    //////////////////////////////////////////////////////////////*/

    /// @notice Native fills ride as msg.value on the adapter call itself (single-tx batch).
    function test_E2E_Pigeon_NativeFill_DeliversAndExecutes() public {
        uint256 amount = 1 ether;

        deal(depositor, amount);
        vm.recordLogs();
        vm.prank(depositor);
        IRelayDepository(RELAY_DEPOSITORY).depositNative{ value: amount }(depositor, keccak256("order-native"));
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bytes memory calldata_ = abi.encodeCall(
            RelayAdapter.processRelayExecution, (address(0), amount, _message(victim, uint64(8453)))
        );

        _fill(keccak256("order-native"), address(0), amount, calldata_, logs);

        vm.selectFork(baseForkId);
        assertEq(victim.balance, amount, "native delivered to the account");
        assertEq(address(adapter).balance, 0, "adapter retains no ETH");
        assertEq(executor.callCount(), 1, "execution fired on the native path");
    }
}
