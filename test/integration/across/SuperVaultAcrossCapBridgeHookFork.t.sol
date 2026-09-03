// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { AcrossV3Helper } from "pigeon/across/AcrossV3Helper.sol";

import { SuperVaultAcrossCapBridgeHook } from "../../../src/hooks/bridges/across/SuperVaultAcrossCapBridgeHook.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import {
    ICapGuardLike,
    MockCapGuard,
    MockPositionRegistry,
    MockGovernorAddressBook,
    CapMessageLib
} from "../../unit/hooks/bridges/CapBridgeTestUtils.sol";

contract MockAcrossSignatureStorage {
    function retrieveSignatureData(address) external view returns (bytes memory) {
        uint48 validUntil = uint48(block.timestamp + 3600);
        bytes32[] memory proofSrc = new bytes32[](1);
        proofSrc[0] = keccak256("src1");
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        return abi.encode(new uint64[](0), validUntil, 0, keccak256("root"), proofSrc, proofDst, hex"abcdef");
    }
}

/// @dev Minimal destination adapter deployed on the Base fork: receives the Across fill (funds +
///      message) exactly like AcrossV3Adapter and forwards the funds to the ACCOUNT decoded from
///      the message — the adapter -> hub-controlled-account hop of the real flow. (The full
///      adapter -> SuperDestinationExecutor -> vault-shares execution is the destination stack's
///      own e2e.)
contract MiniAcrossReceiver {
    address public lastAccount;
    bytes32 public lastExecutorCalldataHash;

    function handleV3AcrossMessage(address tokenSent, uint256 amount, address, bytes memory message) external {
        (, bytes memory executorCalldata, address account,,,) =
            abi.decode(message, (bytes, bytes, address, address[], uint256[], bytes));
        IERC20(tokenSent).transfer(account, amount);
        lastAccount = account;
        lastExecutorCalldataHash = keccak256(executorCalldata);
    }
}

/// @title SuperVaultAcrossCapBridgeHookFork
/// @notice Fork test of the B1-hardened Across cap hook: the cap binds to the ECONOMIC vault
///         decoded from the destination message (never the transport recipient); the recipient
///         must be the approved destination adapter; the real mainnet SpokePool accepts the
///         deposit WITH the destination message, and pigeon's fill on Base delivers funds+message
///         to the adapter, which forwards them to the hub-controlled account — not to a bare
///         test/vault address.
contract SuperVaultAcrossCapBridgeHookFork is Test {
    // Real Across SpokePools
    address internal constant SPOKE_POOL_ETH = 0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5;
    address internal constant SPOKE_POOL_BASE = 0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64;

    // Tokens
    address internal constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    uint64 internal constant BASE_CHAIN_ID = 8453;
    uint256 internal constant INPUT_AMOUNT = 1000e6;
    uint256 internal constant OUTPUT_AMOUNT = 999e6;

    // build() layout: [0]=pre [1]=approve(0) [2]=approve(amt) [3]=depositV3Now [4]=approve(0) [5]=post
    uint256 internal constant BRIDGE_EXECUTION_INDEX = 3;

    uint256 internal ethFork;
    uint256 internal baseFork;

    SuperVaultAcrossCapBridgeHook internal hook;
    MockAcrossSignatureStorage internal validator;
    MockCapGuard internal capGuard;
    MockPositionRegistry internal registry;
    MockGovernorAddressBook internal governor;
    AcrossV3Helper internal acrossHelper;
    MiniAcrossReceiver internal adapter; // deployed on the BASE fork (destination side)

    address internal account = makeAddr("strategy");
    address internal destVault = makeAddr("destinationVault"); // economic destination (B1)
    address internal dstApproveHook = makeAddr("dstApproveHook");
    address internal dstDepositHook = makeAddr("dstDepositHook");
    address internal relayer = makeAddr("relayer");

    function setUp() public {
        ethFork = vm.createFork(vm.envString("ETHEREUM_RPC_URL"), 23_096_042);
        baseFork = vm.createFork(vm.envString("BASE_RPC_URL"), 33_931_553);

        // Pigeon helper + destination adapter must exist on the Base fork.
        vm.selectFork(baseFork);
        acrossHelper = new AcrossV3Helper();
        vm.allowCheatcodes(address(acrossHelper));
        vm.makePersistent(address(acrossHelper));
        adapter = new MiniAcrossReceiver();

        vm.selectFork(ethFork);
        validator = new MockAcrossSignatureStorage();
        capGuard = new MockCapGuard();
        registry = new MockPositionRegistry();
        governor = new MockGovernorAddressBook(address(capGuard), address(registry));
        hook = new SuperVaultAcrossCapBridgeHook(SPOKE_POOL_ETH, address(validator), address(governor));
        hook.setExecutionContext(account);

        // B1 destination policy: the adapter address and the destination hook pair.
        capGuard.setApprovedAdapter(BASE_CHAIN_ID, address(adapter), true);
        capGuard.setDestinationHooks(BASE_CHAIN_ID, dstApproveHook, dstDepositHook);

        deal(USDC_ETH, account, INPUT_AMOUNT);
    }

    function _depositMessage() internal view returns (bytes memory) {
        return CapMessageLib.vaultDepositMessage(
            account, dstApproveHook, dstDepositHook, destVault, USDC_BASE, OUTPUT_AMOUNT
        );
    }

    /// @notice Full round trip: cap enforced on ETH against the ECONOMIC vault; the real SpokePool
    ///         accepts the deposit with the destination message; pigeon fills on Base; the adapter
    ///         receives funds+message and forwards them to the hub-controlled account.
    function test_Fork_CapEnforcedThenRealBridgeAndPigeonFill() public {
        vm.selectFork(ethFork);
        bytes memory data = _encode(BASE_CHAIN_ID, INPUT_AMOUNT, false, _depositMessage());

        // B1: the validated destination is the vault decoded from the message, not the recipient.
        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, BASE_CHAIN_ID, destVault, INPUT_AMOUNT))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);

        assertEq(registry.bridgedOut(account), INPUT_AMOUNT, "in-flight exposure not recorded");
        assertEq(registry.bridgedOutByChain(account, BASE_CHAIN_ID), INPUT_AMOUNT, "per-chain exposure not recorded");
        assertEq(registry.lastVault(), destVault, "reservation must carry the economic vault");

        // Execute the real bridge executions as the account.
        Execution[] memory execs = hook.build(address(0), account, data);
        assertEq(execs[BRIDGE_EXECUTION_INDEX].target, SPOKE_POOL_ETH, "bridge target is not the SpokePool");

        vm.recordLogs();
        vm.startPrank(account);
        for (uint256 i = 1; i <= 4; i++) {
            (bool ok,) = execs[i].target.call{ value: execs[i].value }(execs[i].callData);
            assertTrue(ok, "source execution failed");
        }
        vm.stopPrank();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(IERC20(USDC_ETH).balanceOf(account), 0, "input not pulled by SpokePool");

        // Pigeon fills on Base: the real destination SpokePool calls handleV3AcrossMessage on the
        // adapter, which forwards the funds to the account decoded from the message.
        uint256 accountBefore = _baseBalanceOf(account);
        acrossHelper.help(
            SPOKE_POOL_ETH,
            SPOKE_POOL_BASE,
            relayer,
            block.timestamp + 1 hours,
            baseFork,
            uint256(BASE_CHAIN_ID),
            uint256(1), // refund chain id (origin)
            logs
        );

        vm.selectFork(baseFork);
        assertEq(
            IERC20(USDC_BASE).balanceOf(account) - accountBefore,
            OUTPUT_AMOUNT,
            "funds must reach the hub-controlled account via the adapter"
        );
        assertEq(adapter.lastAccount(), account, "adapter decoded a different account");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0, "adapter must not retain funds");
        assertEq(IERC20(USDC_BASE).balanceOf(destVault), 0, "no raw transfer may reach the vault address");
    }

    /// @notice A cap breach reverts in _preExecute, before any approval/deposit.
    function test_Fork_CapBreachRevertsBeforeAnyBridge() public {
        vm.selectFork(ethFork);
        bytes memory data = _encode(BASE_CHAIN_ID, INPUT_AMOUNT, false, _depositMessage());

        vm.mockCallRevert(
            address(capGuard),
            abi.encodeWithSelector(ICapGuardLike.validateAllocation.selector),
            abi.encodeWithSignature("CROSS_CHAIN_CAP_EXCEEDED()")
        );

        vm.prank(account);
        vm.expectRevert(abi.encodeWithSignature("CROSS_CHAIN_CAP_EXCEEDED()"));
        hook.preExecute(address(0), account, data);

        assertEq(registry.bridgedOut(account), 0, "no exposure should be recorded on a breach");
        assertEq(IERC20(USDC_ETH).balanceOf(account), INPUT_AMOUNT, "funds must not move on a breach");
    }

    /// @notice B1: a raw transfer (empty destination message) can no longer leave through the hook.
    function test_Fork_RevertIf_EmptyDestinationMessage() public {
        vm.selectFork(ethFork);
        bytes memory data = _encode(BASE_CHAIN_ID, INPUT_AMOUNT, false, bytes(""));
        vm.prank(account);
        vm.expectRevert(); // DESTINATION_ACTION_NOT_VALID
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), 0, "recorded despite raw-transfer send");
    }

    /// @notice B1: an unapproved recipient (e.g. the vault itself as transport target) is rejected.
    function test_Fork_RevertIf_RecipientNotApprovedAdapter() public {
        vm.selectFork(ethFork);
        capGuard.setApprovedAdapter(BASE_CHAIN_ID, address(adapter), false);
        bytes memory data = _encode(BASE_CHAIN_ID, INPUT_AMOUNT, false, _depositMessage());
        vm.prank(account);
        vm.expectRevert(); // TRANSPORT_ADAPTER_NOT_APPROVED
        hook.preExecute(address(0), account, data);
    }

    function _baseBalanceOf(address who) internal returns (uint256 bal) {
        uint256 prev = vm.activeFork();
        vm.selectFork(baseFork);
        bal = IERC20(USDC_BASE).balanceOf(who);
        vm.selectFork(prev);
    }

    function _encode(
        uint256 chainId,
        uint256 inputAmount,
        bool usePrevHookAmount,
        bytes memory destinationMessage
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory header = abi.encodePacked(
            bytes(new bytes(52)), // strategy header
            uint256(0), // value
            address(adapter), // recipient = TRANSPORT adapter (B1)
            USDC_ETH, // inputToken
            USDC_BASE, // outputToken
            inputAmount,
            OUTPUT_AMOUNT
        );
        return abi.encodePacked(
            header,
            chainId, // destinationChainId @208
            address(0), // exclusiveRelayer @240
            uint32(3600), // fillDeadlineOffset @260
            uint32(0), // exclusivityPeriod @264
            usePrevHookAmount, // @268
            destinationMessage // @269+
        );
    }
}
