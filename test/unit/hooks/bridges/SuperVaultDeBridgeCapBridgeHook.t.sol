// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import {
    SuperVaultDeBridgeCapBridgeHook
} from "../../../../src/hooks/bridges/debridge/SuperVaultDeBridgeCapBridgeHook.sol";
import { SuperVaultCapBridgeCommon } from "../../../../src/hooks/bridges/SuperVaultCapBridgeCommon.sol";
import { IDlnSource } from "../../../../src/vendor/bridges/debridge/IDlnSource.sol";
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

/// @dev deBridge signature-storage stub; _createOrder reads it at build time.
contract MockDeBridgeSignatureStorage {
    function retrieveSignatureData(address) external view returns (bytes memory) {
        uint48 validUntil = uint48(block.timestamp + 3600);
        bytes32[] memory proofSrc = new bytes32[](1);
        proofSrc[0] = keccak256("src1");
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        return abi.encode(new uint64[](0), validUntil, 0, keccak256("root"), proofSrc, proofDst, hex"abcdef");
    }
}

contract SuperVaultDeBridgeCapBridgeHookTest is Test {
    SuperVaultDeBridgeCapBridgeHook internal hook;
    MockDeBridgeSignatureStorage internal validator;
    MockCapGuard internal capGuard;
    MockPositionRegistry internal registry;
    MockGovernorAddressBook internal governor;

    address internal dlnSource = makeAddr("dlnSource");
    address internal account = makeAddr("strategy");
    address internal adapter = makeAddr("debridgeAdapter"); // transport receiver + external-call executor (B1)
    address internal destVault = makeAddr("destinationVault"); // economic destination (B1)
    address internal dstApproveHook = makeAddr("dstApproveHook");
    address internal dstDepositHook = makeAddr("dstDepositHook");
    address internal giveToken = makeAddr("giveToken");
    address internal takeToken = makeAddr("takeToken");

    uint256 internal constant GIVE_AMOUNT = 1000e6;
    uint256 internal constant TAKE_AMOUNT = 995e6;
    uint64 internal constant DST_CHAIN_ID = 8453;

    // build() output layout: [0]=preExecute [1]=createOrder [2]=postExecute
    uint256 internal constant BRIDGE_EXECUTION_INDEX = 1;

    function setUp() public {
        validator = new MockDeBridgeSignatureStorage();
        capGuard = new MockCapGuard();
        registry = new MockPositionRegistry();
        governor = new MockGovernorAddressBook(address(capGuard), address(registry));
        hook = new SuperVaultDeBridgeCapBridgeHook(dlnSource, address(validator), address(governor));
        hook.setExecutionContext(account);

        capGuard.setApprovedAdapter(DST_CHAIN_ID, adapter, true);
        capGuard.setDestinationHooks(DST_CHAIN_ID, dstApproveHook, dstDepositHook);
    }

    function _depositMessage() internal view returns (bytes memory) {
        return
            CapMessageLib.vaultDepositMessage(
                account, dstApproveHook, dstDepositHook, destVault, takeToken, TAKE_AMOUNT
            );
    }

    struct EncodeParams {
        bytes receiverDst;
        uint256 takeChainId;
        uint256 giveAmount;
        address giveToken;
        bool usePrev;
        bytes destinationMessage;
        address fallbackAddress;
        address executorAddress;
    }

    function _params() internal view returns (EncodeParams memory p) {
        p.receiverDst = abi.encodePacked(adapter);
        p.takeChainId = DST_CHAIN_ID;
        p.giveAmount = GIVE_AMOUNT;
        p.giveToken = giveToken;
        p.usePrev = false;
        p.destinationMessage = _depositMessage();
        p.fallbackAddress = account;
        p.executorAddress = adapter;
    }

    /*//////////////////////////////////////////////////////////////
                B1: ECONOMIC DESTINATION, NOT TRANSPORT
    //////////////////////////////////////////////////////////////*/

    /// @notice The cap must bind to the VAULT extracted from the external-call payload — not to
    ///         the deBridge receiverDst (the adapter).
    function test_ValidatesEconomicVault_NotReceiverDst() public {
        bytes memory data = _encode(_params());

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, DST_CHAIN_ID, destVault, GIVE_AMOUNT))
        );
        vm.expectCall(
            address(registry),
            abi.encodeCall(MockPositionRegistry.recordBridgedOut, (account, DST_CHAIN_ID, destVault, GIVE_AMOUNT))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);

        assertEq(registry.bridgedOut(account), GIVE_AMOUNT, "exposure not recorded");
        assertEq(registry.lastVault(), destVault, "reservation must carry the ECONOMIC vault");
    }

    /// @notice The validated amount equals the giveAmount the parent hands to createOrder.
    function test_ValidatedAmountEqualsBridgedAmount() public {
        bytes memory data = _encode(_params());
        (address bridgedRecipient, uint256 bridgedChainId, uint256 bridgedAmount) = _decodeBridged(data);
        assertEq(bridgedRecipient, adapter, "transport receiver is the adapter");
        assertEq(bridgedChainId, DST_CHAIN_ID);
        assertEq(bridgedAmount, GIVE_AMOUNT);
    }

    /// @notice Prev-hook output overrides the encoded giveAmount for validation and recording.
    function test_PrevAmountOverridesEncodedGiveAmount() public {
        uint256 prevAmount = 333e6;
        MockPrevHook prevHook = new MockPrevHook(prevAmount);
        EncodeParams memory p = _params();
        p.usePrev = true;
        bytes memory data = _encode(p);

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, DST_CHAIN_ID, destVault, prevAmount))
        );
        vm.prank(account);
        hook.preExecute(address(prevHook), account, data);
        assertEq(registry.bridgedOut(account), prevAmount, "validated the encoded amount, not the prev amount");
    }

    /// @notice IDLE_HOLD action validates the zero-vault branch.
    function test_IdleHoldAction_ValidatesZeroVault() public {
        EncodeParams memory p = _params();
        p.destinationMessage = CapMessageLib.idleHoldMessage(account, takeToken);
        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, DST_CHAIN_ID, address(0), GIVE_AMOUNT))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, _encode(p));
        assertEq(registry.lastVault(), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                B1: TYPED DESTINATION ACTION REJECTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice An order with no external call is a raw transfer to receiverDst — rejected.
    function test_RevertIf_NoExternalCall() public {
        EncodeParams memory p = _params();
        p.destinationMessage = bytes("");
        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_ACTION_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encode(p));
    }

    /// @notice The envelope's executorAddress must be the SAME approved adapter that receives the
    ///         funds (review B1: receiverDst and executorAddress are both the adapter).
    function test_RevertIf_ExecutorAddressNotReceiver() public {
        EncodeParams memory p = _params();
        p.executorAddress = makeAddr("someOtherExecutor");
        vm.prank(account);
        vm.expectRevert(SuperVaultDeBridgeCapBridgeHook.DATA_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encode(p));
    }

    /// @notice A failed destination execution must strand funds only on the hub account.
    function test_RevertIf_FallbackNotAccount() public {
        EncodeParams memory p = _params();
        p.fallbackAddress = makeAddr("attacker");
        vm.prank(account);
        vm.expectRevert(SuperVaultDeBridgeCapBridgeHook.DATA_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encode(p));
    }

    /// @notice An unapproved transport receiver is rejected.
    function test_RevertIf_TransportAdapterNotApproved() public {
        capGuard.setApprovedAdapter(DST_CHAIN_ID, adapter, false);
        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.TRANSPORT_ADAPTER_NOT_APPROVED.selector);
        hook.preExecute(address(0), account, _encode(_params()));
    }

    /// @notice B1.RR3: an extra destination hook is rejected.
    function test_RevertIf_ExtraDestinationHook() public {
        address[] memory hooks = new address[](3);
        hooks[0] = dstApproveHook;
        hooks[1] = dstDepositHook;
        hooks[2] = makeAddr("sneakyHook");
        bytes[] memory hooksData = new bytes[](3);
        hooksData[0] = CapMessageLib.approveHookData(takeToken, destVault, TAKE_AMOUNT);
        hooksData[1] = CapMessageLib.depositHookData(destVault, TAKE_AMOUNT);
        hooksData[2] = hex"deadbeef";
        EncodeParams memory p = _params();
        p.destinationMessage =
            CapMessageLib.wrap(CapMessageLib.executorCalldataFor(hooks, hooksData), account, takeToken);

        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_ACTION_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encode(p));
    }

    /// @notice The destination account must be the hub strategy account.
    function test_RevertIf_DestinationAccountNotStrategy() public {
        EncodeParams memory p = _params();
        p.destinationMessage = CapMessageLib.vaultDepositMessage(
            makeAddr("someoneElse"), dstApproveHook, dstDepositHook, destVault, takeToken, TAKE_AMOUNT
        );
        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_ACCOUNT_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encode(p));
    }

    /*//////////////////////////////////////////////////////////////
                        B1: LEAF (inspect) PINNING
    //////////////////////////////////////////////////////////////*/

    /// @notice Mutating only the destination vault inside the external-call payload changes the
    ///         leaf (B1.RR2 at the leaf layer).
    function test_Inspect_ChangesWhenExecutorVaultChanges() public {
        EncodeParams memory pA = _params();
        EncodeParams memory pB = _params();
        pB.destinationMessage = CapMessageLib.vaultDepositMessage(
            account, dstApproveHook, dstDepositHook, makeAddr("otherVault"), takeToken, TAKE_AMOUNT
        );
        assertTrue(
            keccak256(hook.inspect(_encode(pA))) != keccak256(hook.inspect(_encode(pB))),
            "leaf must bind the economic vault"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INPUT VALIDATION
    //////////////////////////////////////////////////////////////*/

    /// @notice takeChainId above uint64 is rejected.
    function test_RevertIf_ChainIdExceedsUint64() public {
        EncodeParams memory p = _params();
        p.takeChainId = uint256(type(uint64).max) + 1;
        vm.prank(account);
        vm.expectRevert(SuperVaultDeBridgeCapBridgeHook.DATA_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encode(p));
    }

    /// @notice A non-EVM (non-20-byte) receiverDst — e.g. a 32-byte Solana pubkey — is rejected
    ///         fail-closed rather than truncated.
    function test_RevertIf_ReceiverDstNot20Bytes() public {
        EncodeParams memory p = _params();
        p.receiverDst = abi.encodePacked(bytes32(uint256(0xBEEF)));
        vm.prank(account);
        vm.expectRevert(SuperVaultDeBridgeCapBridgeHook.DATA_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encode(p));
    }

    /// @notice A zero (20-byte) receiver is rejected before adapter lookup.
    function test_RevertIf_ZeroReceiver() public {
        EncodeParams memory p = _params();
        p.receiverDst = abi.encodePacked(address(0));
        vm.prank(account);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encode(p));
    }

    /// @notice Malformed/short data reverts via the vendor lib's bounds check.
    function test_RevertIf_DataMalformed() public {
        bytes memory shortData = new bytes(120);
        vm.prank(account);
        vm.expectRevert();
        hook.preExecute(address(0), account, shortData);
    }

    /// @notice A cap-guard revert propagates and nothing is recorded.
    function test_CapGuardRevertPropagates() public {
        vm.mockCallRevert(
            address(capGuard),
            abi.encodeWithSelector(ICapGuardLike.validateAllocation.selector),
            abi.encodeWithSignature("CROSS_CHAIN_CAP_EXCEEDED()")
        );
        vm.prank(account);
        vm.expectRevert(abi.encodeWithSignature("CROSS_CHAIN_CAP_EXCEEDED()"));
        hook.preExecute(address(0), account, _encode(_params()));
        assertEq(registry.bridgedOut(account), 0, "exposure recorded despite cap revert");
    }

    /*//////////////////////////////////////////////////////////////
                        REGISTRY RESOLUTION
    //////////////////////////////////////////////////////////////*/

    function test_RecordsIntoGovernorResolvedRegistry_FollowsMigration() public {
        bytes memory data = _encode(_params());

        vm.prank(account);
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), GIVE_AMOUNT, "first registry not credited");

        MockPositionRegistry newRegistry = new MockPositionRegistry();
        governor.setRegistry(address(newRegistry));

        hook.setExecutionContext(account);
        vm.prank(account);
        hook.preExecute(address(0), account, data);

        assertEq(registry.bridgedOut(account), GIVE_AMOUNT, "old registry must not receive new writes");
        assertEq(newRegistry.bridgedOut(account), GIVE_AMOUNT, "new registry not credited after migration");
    }

    /*//////////////////////////////////////////////////////////////
                        LIFECYCLE / ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function test_RevertIf_PreExecuteNotAccount() public {
        vm.prank(makeAddr("attacker"));
        vm.expectRevert(BaseHook.UNAUTHORIZED_CALLER.selector);
        hook.preExecute(address(0), account, _encode(_params()));
    }

    function test_RevertIf_PreExecuteCalledTwiceSameContext() public {
        bytes memory data = _encode(_params());
        vm.prank(account);
        hook.preExecute(address(0), account, data);
        vm.prank(account);
        vm.expectRevert(BaseHook.PRE_EXECUTE_ALREADY_CALLED.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice The parent is TRANSFORM pipe-mode: the cap hook must not publish an output.
    function test_PreExecute_DoesNotPublishOutput() public {
        vm.prank(account);
        hook.preExecute(address(0), account, _encode(_params()));
        assertEq(hook.getOutAmount(account), 0, "cap hook must not set outAmount");
        assertEq(hook.getOutToken(account), address(0), "cap hook must not set outToken");
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_RevertIf_ZeroGovernor() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SuperVaultDeBridgeCapBridgeHook(dlnSource, address(validator), address(0));
    }

    function test_Constructor_RevertIf_ZeroDlnSource() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SuperVaultDeBridgeCapBridgeHook(address(0), address(validator), address(governor));
    }

    function test_Constructor_SetsGovernor() public view {
        assertEq(address(hook.SUPER_GOVERNOR()), address(governor));
        assertEq(hook.DLN_SOURCE(), dlnSource, "dlnSource not forwarded to parent");
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Decodes the OrderCreation the parent build() will actually send.
    function _decodeBridged(bytes memory data)
        internal
        returns (address bridgedRecipient, uint256 bridgedChainId, uint256 bridgedAmount)
    {
        Execution[] memory ex = hook.build(address(0), account, data);
        bytes memory callData = ex[BRIDGE_EXECUTION_INDEX].callData;
        bytes memory args = new bytes(callData.length - 4);
        for (uint256 i; i < args.length; ++i) {
            args[i] = callData[i + 4];
        }
        (IDlnSource.OrderCreation memory order,,,) = abi.decode(args, (IDlnSource.OrderCreation, bytes, uint32, bytes));
        bridgedRecipient = address(bytes20(order.receiverDst));
        bridgedChainId = order.takeChainId;
        bridgedAmount = order.giveAmount;
    }

    /// @dev Canonical deBridge hookData with a non-empty destination message (external call).
    function _encode(EncodeParams memory p) internal pure returns (bytes memory) {
        bytes memory part1 = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte strategy header
            p.usePrev,
            uint256(0), // value
            p.giveToken,
            p.giveAmount,
            uint8(1), // version
            p.fallbackAddress,
            p.executorAddress
        );
        bytes memory part2 = abi.encodePacked(
            uint256(0), // executionFee
            false, // allowDelayedExecution
            true, // requireSuccessfulExecution
            p.destinationMessage.length,
            p.destinationMessage,
            uint256(20), // takeTokenAddress length
            abi.encodePacked(address(0xBEEF)), // takeToken (dst-chain address)
            uint256(995e6), // takeAmount
            p.takeChainId
        );
        bytes memory part3 = abi.encodePacked(
            p.receiverDst.length,
            p.receiverDst,
            address(0), // givePatchAuthoritySrc
            uint256(0), // orderAuthorityAddressDst length
            uint256(0), // allowedTakerDst length
            uint256(0), // allowedCancelBeneficiarySrc length
            uint256(0), // affiliateFee length
            uint32(0) // referralCode
        );
        return bytes.concat(part1, part2, part3);
    }
}
