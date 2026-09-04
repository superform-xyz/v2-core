// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { SuperVaultAcrossCapBridgeHook } from "../../../../src/hooks/bridges/across/SuperVaultAcrossCapBridgeHook.sol";
import {
    ApproveAndAcrossSendFundsAndExecuteOnDstHook
} from "../../../../src/hooks/bridges/across/ApproveAndAcrossSendFundsAndExecuteOnDstHook.sol";
import { SuperVaultCapBridgeCommon } from "../../../../src/hooks/bridges/SuperVaultCapBridgeCommon.sol";
import { IAcrossSpokePoolV3 } from "../../../../src/vendor/bridges/across/IAcrossSpokePoolV3.sol";
import { ISuperValidator } from "../../../../src/interfaces/ISuperValidator.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import {
    ICapGuardLike,
    MockCapGuard,
    MockPositionRegistry,
    MockGovernorAddressBook,
    MockPrevHook,
    CapMessageLib
} from "./CapBridgeTestUtils.sol";

/// @dev Signature storage stub returning a well-formed blob (appended to the dst message at build).
contract MockAcrossSignatureStorage {
    function retrieveSignatureData(address) external view returns (bytes memory) {
        uint48 validUntil = uint48(block.timestamp + 3600);
        bytes32[] memory proofSrc = new bytes32[](1);
        proofSrc[0] = keccak256("src1");
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        return abi.encode(new uint64[](0), validUntil, 0, keccak256("root"), proofSrc, proofDst, hex"abcdef");
    }
}

contract SuperVaultAcrossCapBridgeHookTest is Test {
    SuperVaultAcrossCapBridgeHook internal hook;
    MockAcrossSignatureStorage internal validator;
    MockCapGuard internal capGuard;
    MockPositionRegistry internal registry;
    MockGovernorAddressBook internal governor;

    address internal spokePool = makeAddr("spokePool");
    address internal account = makeAddr("strategy");
    address internal adapter = makeAddr("acrossAdapter"); // transport receiver (B1)
    address internal destVault = makeAddr("destinationVault"); // economic destination (B1)
    address internal dstApproveHook = makeAddr("dstApproveHook");
    address internal dstDepositHook = makeAddr("dstDepositHook");
    address internal inputToken = makeAddr("inputToken");
    address internal outputToken = makeAddr("outputToken");

    uint256 internal constant INPUT_AMOUNT = 1000e6;
    uint256 internal constant OUTPUT_AMOUNT = 995e6;
    uint64 internal constant DST_CHAIN_ID = 8453;

    // build() output layout for the ApproveAnd variant:
    // [0]=preExecute [1]=approve(0) [2]=approve(amount) [3]=depositV3Now [4]=approve(0) [5]=postExecute
    uint256 internal constant BRIDGE_EXECUTION_INDEX = 3;

    function setUp() public {
        validator = new MockAcrossSignatureStorage();
        capGuard = new MockCapGuard();
        registry = new MockPositionRegistry();
        governor = new MockGovernorAddressBook(address(capGuard), address(registry));
        hook = new SuperVaultAcrossCapBridgeHook(spokePool, address(validator), address(governor));
        hook.setExecutionContext(account);

        // B1 destination policy: the adapter and the destination hook pair for the chain.
        capGuard.setApprovedAdapter(DST_CHAIN_ID, adapter, true);
        capGuard.setDestinationHooks(DST_CHAIN_ID, dstApproveHook, dstDepositHook);
        capGuard.setDestinationVaultAsset(DST_CHAIN_ID, destVault, outputToken); // R3-RF3
    }

    function _depositMessage() internal view returns (bytes memory) {
        // R2-B1: the action amount must equal the delivery minimum (outputAmount).
        return _depositMessageWithAmount(OUTPUT_AMOUNT);
    }

    function _depositMessageWithAmount(uint256 amount) internal view returns (bytes memory) {
        return
            CapMessageLib.vaultDepositMessage(account, dstApproveHook, dstDepositHook, destVault, outputToken, amount);
    }

    /*//////////////////////////////////////////////////////////////
                B1: ECONOMIC DESTINATION, NOT TRANSPORT
    //////////////////////////////////////////////////////////////*/

    /// @notice The cap must bind to the VAULT extracted from the typed destination action — not to
    ///         the Across transport recipient (the adapter).
    function test_ValidatesEconomicVault_NotTransportRecipient() public {
        bytes memory data = _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, _depositMessage());

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, DST_CHAIN_ID, destVault, INPUT_AMOUNT))
        );
        vm.expectCall(
            address(registry),
            abi.encodeCall(MockPositionRegistry.recordBridgedOut, (account, DST_CHAIN_ID, destVault, INPUT_AMOUNT))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);

        assertEq(registry.bridgedOut(account), INPUT_AMOUNT, "exposure not recorded");
        assertEq(registry.lastVault(), destVault, "reservation must carry the ECONOMIC vault");
    }

    /// @notice The validated amount equals the amount the parent hands to depositV3Now
    ///         (offset-equivalence, static branch).
    function test_ValidatedAmountEqualsBridgedAmount_StaticAmount() public {
        bytes memory data = _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, _depositMessage());
        (address bridgedRecipient, uint256 bridgedAmount, uint256 bridgedOutputAmount, uint256 bridgedChainId) =
            _decodeBridged(data, address(0));
        assertEq(bridgedRecipient, adapter, "transport recipient is the adapter");
        assertEq(bridgedAmount, INPUT_AMOUNT, "static amount not the encoded input");
        assertEq(bridgedOutputAmount, OUTPUT_AMOUNT, "SpokePool outputAmount not the minDelivered the cap validated");
        assertEq(bridgedChainId, DST_CHAIN_ID);

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, DST_CHAIN_ID, destVault, bridgedAmount))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);
    }

    /// @notice Same equivalence when the amount comes from the previous hook's output.
    function test_ValidatedAmountEqualsBridgedAmount_PrevHookAmount() public {
        uint256 prevAmount = 750e6;
        MockPrevHook prevHook = new MockPrevHook(prevAmount);
        // R2-B1: under usePrev the parent rescales outputAmount by prev/input; the action amount
        // must match that scaled minimum.
        uint256 scaledMinDelivered = OUTPUT_AMOUNT * prevAmount / INPUT_AMOUNT;
        bytes memory data = _encode(DST_CHAIN_ID, INPUT_AMOUNT, true, _depositMessageWithAmount(scaledMinDelivered));

        (, uint256 bridgedAmount, uint256 bridgedOutputAmount,) = _decodeBridged(data, address(prevHook));
        assertEq(bridgedAmount, prevAmount, "bridge did not use prev-hook amount");
        assertEq(
            bridgedOutputAmount, scaledMinDelivered, "SpokePool outputAmount not the rescaled minDelivered validated"
        );

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, DST_CHAIN_ID, destVault, prevAmount))
        );
        vm.prank(account);
        hook.preExecute(address(prevHook), account, data);
        assertEq(registry.bridgedOut(account), prevAmount, "exposure not the prev-hook amount");
    }

    /// @notice IDLE_HOLD: a zero-hook executor entry is the only other permitted action; the cap
    ///         validates the idle-hold branch (vault == 0) on the hub-controlled account.
    function test_IdleHoldAction_ValidatesZeroVault() public {
        bytes memory data = _encode(
            DST_CHAIN_ID, INPUT_AMOUNT, false, CapMessageLib.idleHoldMessage(account, outputToken, OUTPUT_AMOUNT)
        );

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, DST_CHAIN_ID, address(0), INPUT_AMOUNT))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);
        assertEq(registry.lastVault(), address(0), "idle-hold reservation must carry vault 0");
    }

    /*//////////////////////////////////////////////////////////////
                B1: TYPED DESTINATION ACTION REJECTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice An unapproved transport receiver (e.g. a raw EOA or a vault address) is rejected —
    ///         the recipient must be the registered destination adapter.
    function test_RevertIf_TransportAdapterNotApproved() public {
        bytes memory data = _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, _depositMessage());
        capGuard.setApprovedAdapter(DST_CHAIN_ID, adapter, false);

        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.TRANSPORT_ADAPTER_NOT_APPROVED.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice An empty destination message is a raw token transfer — no deposit, no controlled
    ///         shares — and must revert (review B1: the empty-message flow proved nothing).
    function test_RevertIf_EmptyDestinationMessage() public {
        bytes memory data = _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, bytes(""));
        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_ACTION_NOT_VALID.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice The destination account must be the hub strategy account.
    function test_RevertIf_DestinationAccountNotStrategy() public {
        bytes memory msgWrongAccount = CapMessageLib.vaultDepositMessage(
            makeAddr("someoneElse"), dstApproveHook, dstDepositHook, destVault, outputToken, OUTPUT_AMOUNT
        );
        bytes memory data = _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, msgWrongAccount);
        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_ACCOUNT_NOT_VALID.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice B1.RR3: appending any extra hook to the destination action must revert.
    function test_RevertIf_ExtraDestinationHook() public {
        address[] memory hooks = new address[](3);
        hooks[0] = dstApproveHook;
        hooks[1] = dstDepositHook;
        hooks[2] = makeAddr("sneakyTransferHook");
        bytes[] memory hooksData = new bytes[](3);
        hooksData[0] = CapMessageLib.approveHookData(outputToken, destVault, OUTPUT_AMOUNT);
        hooksData[1] = CapMessageLib.depositHookData(destVault, OUTPUT_AMOUNT);
        hooksData[2] = hex"deadbeef";
        bytes memory message = CapMessageLib.wrap(
            CapMessageLib.executorCalldataFor(hooks, hooksData), account, outputToken, OUTPUT_AMOUNT
        );

        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_ACTION_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, message));
    }

    /// @notice Destination hooks other than the governance-pinned pair must revert.
    function test_RevertIf_UnknownDestinationHooks() public {
        bytes memory message = CapMessageLib.vaultDepositMessage(
            account, makeAddr("rogueApprove"), makeAddr("rogueDeposit"), destVault, outputToken, OUTPUT_AMOUNT
        );
        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_ACTION_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, message));
    }

    /// @notice The approve spender must equal the deposit vault — no allowance to third parties.
    function test_RevertIf_ApproveSpenderNotVault() public {
        address[] memory hooks = new address[](2);
        hooks[0] = dstApproveHook;
        hooks[1] = dstDepositHook;
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = CapMessageLib.approveHookData(outputToken, makeAddr("attacker"), OUTPUT_AMOUNT);
        hooksData[1] = CapMessageLib.depositHookData(destVault, OUTPUT_AMOUNT);
        bytes memory message = CapMessageLib.wrap(
            CapMessageLib.executorCalldataFor(hooks, hooksData), account, outputToken, OUTPUT_AMOUNT
        );

        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_ACTION_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, message));
    }

    /// @notice A destination-hooks pair left unset for the chain fails closed for vault deposits.
    function test_RevertIf_DestinationHooksUnsetForChain() public {
        capGuard.setDestinationHooks(DST_CHAIN_ID, address(0), address(0));
        bytes memory data = _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, _depositMessage());
        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_ACTION_NOT_VALID.selector);
        hook.preExecute(address(0), account, data);
    }

    /*//////////////////////////////////////////////////////////////
            R2-B1: TOKEN + AMOUNT BINDING (review round 2)
    //////////////////////////////////////////////////////////////*/

    /// @notice R2-B1 core trace: bridge 100, destination deposit 1 — must revert BEFORE the bridge.
    ///         A smaller independently-encoded action can no longer leave a bridged remainder idle.
    function test_RevertIf_DepositSmallerThanBridgedAmount() public {
        bytes memory data = _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, _depositMessageWithAmount(1e6));
        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_AMOUNT_NOT_BOUND.selector);
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), 0, "no reservation on an unbound amount");
    }

    /// @notice R3-PF1: the guaranteed delivery must nearly cover the reservation — a route that
    ///         reserves 100 but only guarantees 85 can never leave the hub (it could not clear the
    ///         periphery's confirmation floor).
    function test_RevertIf_DeliveryBelowReservationFloor() public {
        // outputAmount 85% of inputAmount — below MIN_SOURCE_DELIVERY_BPS (90%).
        bytes memory message = _depositMessageWithAmount(850e6);
        bytes memory header = abi.encodePacked(
            bytes(new bytes(52)), uint256(0), adapter, inputToken, outputToken, INPUT_AMOUNT, uint256(850e6)
        );
        bytes memory data =
            abi.encodePacked(header, uint256(DST_CHAIN_ID), address(0), uint32(3600), uint32(0), false, message);
        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DELIVERY_BELOW_RESERVATION_FLOOR.selector);
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), 0, "no reservation below the delivery floor");
    }

    /// @notice The action token must be the bridge's output token — even when the (wrong) token
    ///         IS the vault's pinned asset, the bridge-output binding still rejects it.
    function test_RevertIf_ActionTokenNotBridgeOutputToken() public {
        address wrongToken = makeAddr("wrongToken");
        capGuard.setDestinationVaultAsset(DST_CHAIN_ID, destVault, wrongToken);
        bytes memory message = CapMessageLib.vaultDepositMessage(
            account, dstApproveHook, dstDepositHook, destVault, wrongToken, OUTPUT_AMOUNT
        );
        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_TOKEN_NOT_BOUND.selector);
        hook.preExecute(address(0), account, _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, message));
    }

    /// @notice The approve token must equal the attested destination token.
    function test_RevertIf_ApproveTokenNotDstToken() public {
        address[] memory hooks = new address[](2);
        hooks[0] = dstApproveHook;
        hooks[1] = dstDepositHook;
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = CapMessageLib.approveHookData(makeAddr("otherToken"), destVault, OUTPUT_AMOUNT);
        hooksData[1] = CapMessageLib.depositHookData(destVault, OUTPUT_AMOUNT);
        bytes memory message = CapMessageLib.wrap(
            CapMessageLib.executorCalldataFor(hooks, hooksData), account, outputToken, OUTPUT_AMOUNT
        );
        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_ACTION_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, message));
    }

    /// @notice The approve amount must equal the attested intent amount — one action amount only.
    function test_RevertIf_ApproveAmountNotIntentAmount() public {
        address[] memory hooks = new address[](2);
        hooks[0] = dstApproveHook;
        hooks[1] = dstDepositHook;
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = CapMessageLib.approveHookData(outputToken, destVault, 1e6); // != intent
        hooksData[1] = CapMessageLib.depositHookData(destVault, OUTPUT_AMOUNT);
        bytes memory message = CapMessageLib.wrap(
            CapMessageLib.executorCalldataFor(hooks, hooksData), account, outputToken, OUTPUT_AMOUNT
        );
        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_ACTION_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, message));
    }

    /// @notice The deposit must consume the approve amount (usePrevHookAmount = true) — a second,
    ///         independently encoded deposit amount is rejected.
    function test_RevertIf_DepositNotUsingPrevHookAmount() public {
        address[] memory hooks = new address[](2);
        hooks[0] = dstApproveHook;
        hooks[1] = dstDepositHook;
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = CapMessageLib.approveHookData(outputToken, destVault, OUTPUT_AMOUNT);
        hooksData[1] = abi.encodePacked(bytes32(0), destVault, OUTPUT_AMOUNT, false); // usePrev off
        bytes memory message = CapMessageLib.wrap(
            CapMessageLib.executorCalldataFor(hooks, hooksData), account, outputToken, OUTPUT_AMOUNT
        );
        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_ACTION_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, message));
    }

    /// @notice R3-RF3: the FIRST destination hook's usePrevHookAmount must be false — its
    ///         prevHook is address(0), so true would revert at destination execution and strand
    ///         delivered funds on best-effort adapters.
    function test_RevertIf_ApproveUsesPrevHookAmount() public {
        address[] memory hooks = new address[](2);
        hooks[0] = dstApproveHook;
        hooks[1] = dstDepositHook;
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = abi.encodePacked(new bytes(52), outputToken, destVault, OUTPUT_AMOUNT, true); // usePrev on
        hooksData[1] = CapMessageLib.depositHookData(destVault, OUTPUT_AMOUNT);
        bytes memory message = CapMessageLib.wrap(
            CapMessageLib.executorCalldataFor(hooks, hooksData), account, outputToken, OUTPUT_AMOUNT
        );
        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_ACTION_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, message));
    }

    /// @notice R3-RF3: a vault with no governance-pinned asset fails closed — the hub cannot call
    ///         the destination vault, so an unpinned asset means an unverifiable deposit.
    function test_RevertIf_VaultAssetUnpinned() public {
        capGuard.setDestinationVaultAsset(DST_CHAIN_ID, destVault, address(0));
        bytes memory data = _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, _depositMessage());
        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_VAULT_ASSET_NOT_BOUND.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice F3 boundary: destination hook payloads must be at least the full canonical length
    ///         the destination hooks actually read (approve 125, deposit 85) — one byte short is
    ///         rejected, exact length passes the length gate.
    function test_DestinationHookDataLengthBoundaries() public {
        // approve data 124 bytes (one short of the usePrev flag) -> reject.
        _expectActionRevert(_pad(124), CapMessageLib.depositHookData(destVault, OUTPUT_AMOUNT));
        // deposit data 84 bytes (one short of the usePrev flag) -> reject.
        _expectActionRevert(CapMessageLib.approveHookData(outputToken, destVault, OUTPUT_AMOUNT), _pad(84));
        // Exact canonical lengths pass the length gate (and the full valid action succeeds).
        assertEq(CapMessageLib.approveHookData(outputToken, destVault, OUTPUT_AMOUNT).length, 125);
        assertEq(CapMessageLib.depositHookData(destVault, OUTPUT_AMOUNT).length, 85);
        vm.prank(account);
        capHookPreExecuteOk();
    }

    function capHookPreExecuteOk() internal {
        hook.preExecute(address(0), account, _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, _depositMessage()));
        assertEq(registry.bridgedOut(account), INPUT_AMOUNT, "canonical action must pass");
    }

    function _pad(uint256 len) internal pure returns (bytes memory) {
        return new bytes(len);
    }

    function _expectActionRevert(bytes memory approveData, bytes memory depositData) internal {
        address[] memory hooks = new address[](2);
        hooks[0] = dstApproveHook;
        hooks[1] = dstDepositHook;
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = approveData;
        hooksData[1] = depositData;
        bytes memory message = CapMessageLib.wrap(
            CapMessageLib.executorCalldataFor(hooks, hooksData), account, outputToken, OUTPUT_AMOUNT
        );
        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_ACTION_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, message));
        hook.setExecutionContext(account); // fresh mutex for the next call in this test
    }

    /// @notice R3: the cap-aware hook is unmistakably distinct from its uncapped parent.
    function test_NameDistinctFromParent() public view {
        assertEq(hook.name(), "SuperVault Capped Approve and Across Bridge");
    }

    /// @notice Exactly one (dstToken, intentAmount) pair — the executor's arrival attestation must
    ///         be unambiguous.
    function test_RevertIf_MultipleDstTokens() public {
        address[] memory dstTokens = new address[](2);
        dstTokens[0] = outputToken;
        dstTokens[1] = makeAddr("secondToken");
        uint256[] memory intentAmounts = new uint256[](2);
        intentAmounts[0] = OUTPUT_AMOUNT;
        intentAmounts[1] = 1;
        bytes memory message =
            abi.encode(bytes(""), _executorCalldataForDeposit(OUTPUT_AMOUNT), account, dstTokens, intentAmounts);
        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_ACTION_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, message));
    }

    function _executorCalldataForDeposit(uint256 amount) internal view returns (bytes memory) {
        address[] memory hooks = new address[](2);
        hooks[0] = dstApproveHook;
        hooks[1] = dstDepositHook;
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = CapMessageLib.approveHookData(outputToken, destVault, amount);
        hooksData[1] = CapMessageLib.depositHookData(destVault, amount);
        return CapMessageLib.executorCalldataFor(hooks, hooksData);
    }

    /// @notice Executor calldata with a foreign selector is not a typed action.
    function test_RevertIf_ForeignExecutorSelector() public {
        bytes memory message =
            CapMessageLib.wrap(abi.encodeWithSignature("steal(address)", account), account, outputToken, OUTPUT_AMOUNT);
        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_ACTION_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, message));
    }

    /*//////////////////////////////////////////////////////////////
                        B1: LEAF (inspect) PINNING
    //////////////////////////////////////////////////////////////*/

    /// @notice B1.RR2/RR4 at the leaf layer: mutating ONLY the destination vault inside the
    ///         executor calldata changes the leaf, so a root approved for vault A can never
    ///         authorize the same adapter tunneling to vault B.
    function test_Inspect_ChangesWhenExecutorVaultChanges() public {
        bytes memory dataA = _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, _depositMessage());
        address otherVault = makeAddr("otherVault");
        capGuard.setDestinationVaultAsset(DST_CHAIN_ID, otherVault, outputToken); // R3-RF3
        bytes memory msgB = CapMessageLib.vaultDepositMessage(
            account, dstApproveHook, dstDepositHook, otherVault, outputToken, OUTPUT_AMOUNT
        );
        bytes memory dataB = _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, msgB);

        assertTrue(
            keccak256(hook.inspect(dataA)) != keccak256(hook.inspect(dataB)),
            "leaf must bind the economic vault, not just the transport"
        );
    }

    /// @notice The leaf pins parent transport fields plus (capGuard, chainId, vault, actionType,
    ///         amount mode): 4*20 + 20 + 8 + 20 + 1 + 1 = 130 bytes.
    function test_Inspect_LeafLayout() public view {
        bytes memory payload = hook.inspect(_encode(DST_CHAIN_ID, INPUT_AMOUNT, false, _depositMessage()));
        assertEq(payload.length, 130, "unexpected leaf payload length");
    }

    /// @notice The amount-source mode is pinned: same data except usePrevHookAmount differs ->
    ///         different leaf.
    function test_Inspect_PinsAmountSourceMode() public view {
        bytes memory dataStatic = _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, _depositMessage());
        bytes memory dataPrev = _encode(DST_CHAIN_ID, INPUT_AMOUNT, true, _depositMessage());
        assertTrue(keccak256(hook.inspect(dataStatic)) != keccak256(hook.inspect(dataPrev)));
    }

    /*//////////////////////////////////////////////////////////////
                        REGISTRY RESOLUTION (P1-1)
    //////////////////////////////////////////////////////////////*/

    /// @notice The hook must record into the SAME registry the cap reads from, following a
    ///         governance registry migration.
    function test_RecordsIntoGovernorResolvedRegistry_FollowsMigration() public {
        bytes memory data = _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, _depositMessage());

        vm.prank(account);
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), INPUT_AMOUNT, "first registry not credited");

        MockPositionRegistry newRegistry = new MockPositionRegistry();
        governor.setRegistry(address(newRegistry));

        hook.setExecutionContext(account);
        vm.prank(account);
        hook.preExecute(address(0), account, data);

        assertEq(registry.bridgedOut(account), INPUT_AMOUNT, "old registry must not receive new writes");
        assertEq(newRegistry.bridgedOut(account), INPUT_AMOUNT, "new registry not credited after migration");
    }

    /*//////////////////////////////////////////////////////////////
                        INPUT VALIDATION
    //////////////////////////////////////////////////////////////*/

    /// @notice A destinationChainId above uint64 would truncate to a different cap key than the
    ///         full value the parent forwards to the SpokePool — reject it.
    function test_RevertIf_ChainIdExceedsUint64() public {
        uint256 tooBig = uint256(type(uint64).max) + 1;
        bytes memory data = _encodeRawChainId(tooBig, INPUT_AMOUNT, false, _depositMessage());

        vm.prank(account);
        vm.expectRevert(ApproveAndAcrossSendFundsAndExecuteOnDstHook.DATA_NOT_VALID.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice Short data must fail with the typed error, not the vendor lib's untyped OOB revert.
    function test_RevertIf_DataTooShort() public {
        bytes memory shortData = abi.encodePacked(bytes(new bytes(268))); // one byte short of 269
        vm.prank(account);
        vm.expectRevert(ApproveAndAcrossSendFundsAndExecuteOnDstHook.DATA_NOT_VALID.selector);
        hook.preExecute(address(0), account, shortData);
    }

    /// @notice P3: outputToken == address(0) is the modern SpokePool's "destination equivalent of
    ///         the inputToken" sentinel — the hub cannot bind the delivered token, so it must be
    ///         rejected (the shared base would otherwise SKIP the destination-token binding).
    function test_RevertIf_OutputTokenZero() public {
        bytes memory header = abi.encodePacked(
            bytes(new bytes(52)), uint256(0), adapter, inputToken, address(0), INPUT_AMOUNT, OUTPUT_AMOUNT
        );
        bytes memory data = abi.encodePacked(
            header, uint256(DST_CHAIN_ID), address(0), uint32(3600), uint32(0), false, _depositMessage()
        );
        vm.prank(account);
        vm.expectRevert(SuperVaultAcrossCapBridgeHook.OUTPUT_TOKEN_NOT_VALID.selector);
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), 0, "no reservation on a zero output token");
    }

    /// @notice A cap-guard revert propagates and nothing is recorded.
    function test_CapGuardRevertPropagates() public {
        bytes memory data = _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, _depositMessage());
        vm.mockCallRevert(
            address(capGuard),
            abi.encodeWithSelector(ICapGuardLike.validateAllocation.selector),
            abi.encodeWithSignature("CROSS_CHAIN_CAP_EXCEEDED()")
        );
        vm.prank(account);
        vm.expectRevert(abi.encodeWithSignature("CROSS_CHAIN_CAP_EXCEEDED()"));
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), 0, "exposure recorded despite cap revert");
    }

    /*//////////////////////////////////////////////////////////////
                        LIFECYCLE / ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function test_RevertIf_PreExecuteNotAccount() public {
        bytes memory data = _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, _depositMessage());
        vm.prank(makeAddr("attacker"));
        vm.expectRevert(BaseHook.UNAUTHORIZED_CALLER.selector);
        hook.preExecute(address(0), account, data);
    }

    function test_RevertIf_PreExecuteCalledTwiceSameContext() public {
        bytes memory data = _encode(DST_CHAIN_ID, INPUT_AMOUNT, false, _depositMessage());
        vm.prank(account);
        hook.preExecute(address(0), account, data);
        vm.prank(account);
        vm.expectRevert(BaseHook.PRE_EXECUTE_ALREADY_CALLED.selector);
        hook.preExecute(address(0), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_RevertIf_ZeroGovernor() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SuperVaultAcrossCapBridgeHook(spokePool, address(validator), address(0));
    }

    function test_Constructor_SetsGovernor() public view {
        assertEq(address(hook.SUPER_GOVERNOR()), address(governor));
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _encode(
        uint64 chainId,
        uint256 inputAmount,
        bool usePrevHookAmount,
        bytes memory destinationMessage
    )
        internal
        view
        returns (bytes memory)
    {
        return _encodeRawChainId(uint256(chainId), inputAmount, usePrevHookAmount, destinationMessage);
    }

    function _encodeRawChainId(
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
            adapter, // recipient = TRANSPORT adapter (B1)
            inputToken,
            outputToken,
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

    /// @dev Runs build() and decodes the depositV3Now execution the parent produced.
    function _decodeBridged(
        bytes memory data,
        address prevHook
    )
        internal
        view
        returns (address bridgedRecipient, uint256 bridgedAmount, uint256 bridgedOutputAmount, uint256 bridgedChainId)
    {
        Execution[] memory execs = hook.build(prevHook, account, data);
        bytes memory cd = execs[BRIDGE_EXECUTION_INDEX].callData;
        assertEq(bytes4(cd), IAcrossSpokePoolV3.depositV3Now.selector, "not a depositV3Now call");

        bytes memory args = new bytes(cd.length - 4);
        for (uint256 i; i < args.length; ++i) {
            args[i] = cd[i + 4];
        }
        (, address rcpt,,, uint256 inAmt, uint256 outAmt, uint256 dstChain,,,,) = abi.decode(
            args, (address, address, address, address, uint256, uint256, uint256, address, uint32, uint32, bytes)
        );
        return (rcpt, inAmt, outAmt, dstChain);
    }
}
