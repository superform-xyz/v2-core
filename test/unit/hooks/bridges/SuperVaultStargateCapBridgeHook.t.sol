// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import {
    SuperVaultStargateCapBridgeHook
} from "../../../../src/hooks/bridges/stargate/SuperVaultStargateCapBridgeHook.sol";
import { ApproveAndStargateSendHook } from "../../../../src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol";
import { SuperVaultCapBridgeCommon } from "../../../../src/hooks/bridges/SuperVaultCapBridgeCommon.sol";
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

/// @dev Stargate signature-storage stub (composeMsg gets the signature appended at build).
contract MockStargateSignatureStorage {
    function retrieveSignatureData(address) external view returns (bytes memory) {
        uint48 validUntil = uint48(block.timestamp + 3600);
        bytes32[] memory proofSrc = new bytes32[](1);
        proofSrc[0] = keccak256("src1");
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        return abi.encode(new uint64[](0), validUntil, 0, keccak256("root"), proofSrc, proofDst, hex"abcdef");
    }
}

contract SuperVaultStargateCapBridgeHookTest is Test {
    SuperVaultStargateCapBridgeHook internal hook;
    MockStargateSignatureStorage internal validator;
    MockCapGuard internal capGuard;
    MockPositionRegistry internal registry;
    MockGovernorAddressBook internal governor;

    address internal pool = makeAddr("stargatePool");
    address internal account = makeAddr("strategy");
    address internal adapter = makeAddr("stargateAdapter"); // transport receiver (B1)
    address internal destVault = makeAddr("destinationVault"); // economic destination (B1)
    address internal dstApproveHook = makeAddr("dstApproveHook");
    address internal dstDepositHook = makeAddr("dstDepositHook");
    address internal inputToken = makeAddr("inputToken");

    uint256 internal constant AMOUNT_LD = 1000e6;
    uint256 internal constant MIN_AMOUNT_LD = 995e6;
    uint256 internal constant NATIVE_FEE = 0.01 ether;

    // B4: LayerZero EID vs canonical EVM chain id are DIFFERENT namespaces.
    uint32 internal constant DST_EID = 30_184; // Base LZ endpoint id
    uint64 internal constant DST_CHAIN_ID = 8453; // Base EVM chain id

    function setUp() public {
        validator = new MockStargateSignatureStorage();
        capGuard = new MockCapGuard();
        registry = new MockPositionRegistry();
        governor = new MockGovernorAddressBook(address(capGuard), address(registry));
        hook = new SuperVaultStargateCapBridgeHook(address(validator), address(governor));
        hook.setExecutionContext(account);

        capGuard.setEidChainId(DST_EID, DST_CHAIN_ID); // B4 canonical mapping
        capGuard.setApprovedAdapter(DST_CHAIN_ID, adapter, true);
        capGuard.setDestinationHooks(DST_CHAIN_ID, dstApproveHook, dstDepositHook);
        capGuard.setDestinationVaultAsset(DST_CHAIN_ID, destVault, inputToken); // R3-RF3
        capGuard.setStargateRoute(address(pool), DST_CHAIN_ID, inputToken); // R3-RF1
        capGuard.setStargateMinDeliveryBps(9900); // R3-RF1 (MIN_AMOUNT_LD/AMOUNT_LD = 99.5%)
    }

    function _depositMessage() internal view returns (bytes memory) {
        // R2-B1: the action amount must equal the delivery minimum (minAmountLD).
        return _depositMessageWithAmount(MIN_AMOUNT_LD);
    }

    function _depositMessageWithAmount(uint256 amount) internal view returns (bytes memory) {
        return CapMessageLib.vaultDepositMessage(account, dstApproveHook, dstDepositHook, destVault, inputToken, amount);
    }

    /*//////////////////////////////////////////////////////////////
                    B4: CANONICAL CHAIN NORMALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice The cap must validate and record under the CANONICAL EVM chain id (8453), never the
    ///         LayerZero EID (30184) — one Base cap for Across, deBridge AND Stargate.
    function test_ValidatesAndRecordsUnderCanonicalChainId_NotEid() public {
        bytes memory data = _encode(DST_EID, _toBytes32(adapter), AMOUNT_LD, false, 0, _depositMessage());

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, DST_CHAIN_ID, destVault, AMOUNT_LD))
        );
        vm.expectCall(
            address(registry),
            abi.encodeCall(MockPositionRegistry.recordBridgedOut, (account, DST_CHAIN_ID, destVault, AMOUNT_LD))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);

        assertEq(registry.bridgedOutByChain(account, DST_CHAIN_ID), AMOUNT_LD, "must record under canonical chain id");
        assertEq(registry.bridgedOutByChain(account, uint64(DST_EID)), 0, "must NOT record under the EID namespace");
    }

    /// @notice An unmapped EID fails closed — no fresh, empty cap namespace for a new route.
    function test_RevertIf_EidNotMapped() public {
        uint32 unmappedEid = 30_101; // Ethereum EID, not configured in setUp
        bytes memory data = _encode(unmappedEid, _toBytes32(adapter), AMOUNT_LD, false, 0, _depositMessage());
        vm.prank(account);
        vm.expectRevert(SuperVaultStargateCapBridgeHook.EID_NOT_MAPPED.selector);
        hook.preExecute(address(0), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                B1: ECONOMIC DESTINATION, NOT TRANSPORT
    //////////////////////////////////////////////////////////////*/

    /// @notice Prev-hook output overrides the encoded amountLD for validation and recording.
    function test_PrevAmountOverridesEncodedAmount() public {
        uint256 prevAmount = 750e6;
        MockPrevHook prevHook = new MockPrevHook(prevAmount);
        // R2-B1: under usePrev the parent rescales minAmountLD by prev/amountLD; the action
        // amount must match that scaled minimum.
        bytes memory data = _encode(
            DST_EID,
            _toBytes32(adapter),
            AMOUNT_LD,
            true,
            0,
            _depositMessageWithAmount(MIN_AMOUNT_LD * prevAmount / AMOUNT_LD)
        );

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, DST_CHAIN_ID, destVault, prevAmount))
        );
        vm.prank(account);
        hook.preExecute(address(prevHook), account, data);
        assertEq(registry.bridgedOut(account), prevAmount);
    }

    /// @notice Bus mode (1) silently drops composeMsg on the Stargate side (`_rideBus` never
    ///         reads it), stranding the bridged amount on the admin-less adapter — taxi only.
    function test_RevertIf_Mode1Bus() public {
        bytes memory data = _encode(DST_EID, _toBytes32(adapter), AMOUNT_LD, false, 1, _depositMessage());
        vm.prank(account);
        vm.expectRevert(SuperVaultStargateCapBridgeHook.MODE_NOT_CAPPABLE.selector);
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), 0, "no reservation for a bus-mode send");
    }

    /// @notice Generic OFT mode (2) is unregistered in the destination TokenMessaging — the
    ///         adapter credits the tokens then returns without a compose execution: taxi only.
    function test_RevertIf_Mode2Oft() public {
        bytes memory data = _encode(DST_EID, _toBytes32(adapter), AMOUNT_LD, false, 2, _depositMessage());
        vm.prank(account);
        vm.expectRevert(SuperVaultStargateCapBridgeHook.MODE_NOT_CAPPABLE.selector);
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), 0, "no reservation for a generic-OFT send");
    }

    /// @notice The encoded amountLD must be nonzero even under usePrevHookAmount — a zero encoded
    ///         amount skips the minAmountLD rescale and degenerates the governance min-delivery
    ///         ratio check to `x < 0`, silently lowering the floor to the hardcoded 9000 bps.
    function test_RevertIf_UsePrevWithZeroEncodedAmount() public {
        MockPrevHook prevHook = new MockPrevHook(750e6);
        bytes memory data = _encode(DST_EID, _toBytes32(adapter), 0, true, 0, _depositMessage());
        vm.prank(account);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.preExecute(address(prevHook), account, data);
        assertEq(registry.bridgedOut(account), 0, "no reservation for a zero encoded amountLD");
    }

    /// @notice IDLE_HOLD action validates the zero-vault branch.
    function test_IdleHoldAction_ValidatesZeroVault() public {
        bytes memory data = _encode(
            DST_EID,
            _toBytes32(adapter),
            AMOUNT_LD,
            false,
            0,
            CapMessageLib.idleHoldMessage(account, inputToken, MIN_AMOUNT_LD)
        );
        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, DST_CHAIN_ID, address(0), AMOUNT_LD))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);
        assertEq(registry.lastVault(), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                B1: TYPED DESTINATION ACTION REJECTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice An empty compose message is a raw token send to `to` — rejected.
    function test_RevertIf_EmptyComposeMessage() public {
        bytes memory data = _encode(DST_EID, _toBytes32(adapter), AMOUNT_LD, false, 0, bytes(""));
        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_ACTION_NOT_VALID.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice An unapproved transport receiver is rejected — `to` must be the registered adapter.
    function test_RevertIf_TransportAdapterNotApproved() public {
        bytes memory data = _encode(DST_EID, _toBytes32(makeAddr("randomTo")), AMOUNT_LD, false, 0, _depositMessage());
        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.TRANSPORT_ADAPTER_NOT_APPROVED.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice B1.RR3: an extra destination hook is rejected.
    function test_RevertIf_ExtraDestinationHook() public {
        address[] memory hooks = new address[](3);
        hooks[0] = dstApproveHook;
        hooks[1] = dstDepositHook;
        hooks[2] = makeAddr("sneakyHook");
        bytes[] memory hooksData = new bytes[](3);
        hooksData[0] = CapMessageLib.approveHookData(inputToken, destVault, AMOUNT_LD);
        hooksData[1] = CapMessageLib.depositHookData(destVault, AMOUNT_LD);
        hooksData[2] = hex"deadbeef";
        bytes memory message =
            CapMessageLib.wrap(CapMessageLib.executorCalldataFor(hooks, hooksData), account, inputToken, MIN_AMOUNT_LD);

        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_ACTION_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encode(DST_EID, _toBytes32(adapter), AMOUNT_LD, false, 0, message));
    }

    /// @notice The destination account must be the hub strategy account.
    function test_RevertIf_DestinationAccountNotStrategy() public {
        bytes memory message = CapMessageLib.vaultDepositMessage(
            makeAddr("someoneElse"), dstApproveHook, dstDepositHook, destVault, inputToken, AMOUNT_LD
        );
        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_ACCOUNT_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encode(DST_EID, _toBytes32(adapter), AMOUNT_LD, false, 0, message));
    }

    /// @notice Mode 3 (lzMulticall) ignores `to`/`amountLD` — the cap cannot bind; reject.
    function test_RevertIf_Mode3() public {
        bytes memory data = _encode(DST_EID, _toBytes32(adapter), AMOUNT_LD, false, 3, _depositMessage());
        vm.prank(account);
        vm.expectRevert(SuperVaultStargateCapBridgeHook.MODE_NOT_CAPPABLE.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice A non-EVM recipient (top 12 bytes set) is rejected fail-closed.
    function test_RevertIf_NonEvmRecipient() public {
        bytes32 nonEvm = bytes32(uint256(1) << 200) | _toBytes32(adapter);
        bytes memory data = _encode(DST_EID, nonEvm, AMOUNT_LD, false, 0, _depositMessage());
        vm.prank(account);
        vm.expectRevert(ApproveAndStargateSendHook.DATA_NOT_VALID.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice A zero recipient is rejected.
    function test_RevertIf_ZeroRecipient() public {
        bytes memory data = _encode(DST_EID, bytes32(0), AMOUNT_LD, false, 0, _depositMessage());
        vm.prank(account);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice Short data fails with the typed error before any fixed-offset read.
    function test_RevertIf_DataTooShort() public {
        bytes memory shortData = new bytes(289); // one short of the 290 minimum
        vm.prank(account);
        vm.expectRevert(ApproveAndStargateSendHook.DATA_NOT_VALID.selector);
        hook.preExecute(address(0), account, shortData);
    }

    /*//////////////////////////////////////////////////////////////
                R3-RF1: DELIVERY BINDING (review round 3)
    //////////////////////////////////////////////////////////////*/

    /// @notice The caller-chosen slippage margin is bounded in code: minAmountLD below the
    ///         governance ratio of amountLD reverts, so the maximum untracked delivery surplus
    ///         (actual credit - action amount) is a governance-bounded sliver.
    function test_RevertIf_DeliveryMarginTooWide() public {
        // minAmountLD = 90% of amountLD, below the 99% floor set in setUp.
        bytes memory data = _encodeWithMin(DST_EID, _toBytes32(adapter), AMOUNT_LD, AMOUNT_LD * 9000 / 10_000);
        vm.prank(account);
        vm.expectRevert(SuperVaultStargateCapBridgeHook.DELIVERY_MARGIN_TOO_WIDE.selector);
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), 0, "no reservation on an unbounded margin");
    }

    /// @notice An unset ratio fails closed.
    function test_RevertIf_MinDeliveryBpsUnset() public {
        capGuard.setStargateMinDeliveryBps(0);
        bytes memory data = _encode(DST_EID, _toBytes32(adapter), AMOUNT_LD, false, 0, _depositMessage());
        vm.prank(account);
        vm.expectRevert(SuperVaultStargateCapBridgeHook.DELIVERY_MARGIN_TOO_WIDE.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice A route with no governance-pinned destination token fails closed.
    function test_RevertIf_StargateRouteNotSet() public {
        capGuard.setStargateRoute(address(pool), DST_CHAIN_ID, address(0));
        bytes memory data = _encode(DST_EID, _toBytes32(adapter), AMOUNT_LD, false, 0, _depositMessage());
        vm.prank(account);
        vm.expectRevert(SuperVaultStargateCapBridgeHook.STARGATE_ROUTE_NOT_SET.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice The action token must be the route's pinned destination token — a signed action
    ///         attesting a different token can no longer reach the destination (R3-RF1 token leg).
    function test_RevertIf_ActionTokenNotRouteToken() public {
        address wrongToken = makeAddr("wrongDstToken");
        capGuard.setDestinationVaultAsset(DST_CHAIN_ID, destVault, wrongToken);
        bytes memory message = CapMessageLib.vaultDepositMessage(
            account, dstApproveHook, dstDepositHook, destVault, wrongToken, MIN_AMOUNT_LD
        );
        vm.prank(account);
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_TOKEN_NOT_BOUND.selector);
        hook.preExecute(address(0), account, _encode(DST_EID, _toBytes32(adapter), AMOUNT_LD, false, 0, message));
    }

    /*//////////////////////////////////////////////////////////////
                EXTRA OPTIONS: STRUCTURAL WHITELIST
    //////////////////////////////////////////////////////////////*/

    /// @notice A gas-only executor lzCompose option (worker 1, type 3, index + gas, no value) is
    ///         the canonical legitimate option for a compose send — it must pass.
    function test_ExtraOptions_LzComposeGasOnly_Passes() public {
        bytes memory options = abi.encodePacked(uint16(3), _lzComposeGasOption());
        vm.prank(account);
        hook.preExecute(address(0), account, _encodeWithOptions(options));
        assertEq(registry.bridgedOutByChain(account, DST_CHAIN_ID), AMOUNT_LD);
    }

    /// @notice A gas-only executor lzReceive option (worker 1, type 1, gas, no value) passes,
    ///         including alongside a gas-only lzCompose entry.
    function test_ExtraOptions_LzReceiveGasOnly_Passes() public {
        bytes memory options =
            abi.encodePacked(uint16(3), uint8(1), uint16(17), uint8(1), uint128(200_000), _lzComposeGasOption());
        vm.prank(account);
        hook.preExecute(address(0), account, _encodeWithOptions(options));
        assertEq(registry.bridgedOutByChain(account, DST_CHAIN_ID), AMOUNT_LD);
    }

    /// @notice A native-drop option (type 2) appended after a valid entry would pay the account's
    ///         native fee float to an arbitrary receiver — rejected.
    function test_RevertIf_ExtraOptions_NativeDrop() public {
        bytes memory nativeDrop = abi.encodePacked(
            uint8(1), uint16(49), uint8(2), uint128(1 ether), bytes32(uint256(uint160(makeAddr("dropReceiver"))))
        );
        bytes memory options = abi.encodePacked(uint16(3), _lzComposeGasOption(), nativeDrop);
        vm.prank(account);
        vm.expectRevert(SuperVaultStargateCapBridgeHook.EXTRA_OPTIONS_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encodeWithOptions(options));
    }

    /// @notice The value-carrying lzReceive variant (gas + uint128 value, size 33) is rejected.
    function test_RevertIf_ExtraOptions_LzReceiveWithValue() public {
        bytes memory options =
            abi.encodePacked(uint16(3), uint8(1), uint16(33), uint8(1), uint128(200_000), uint128(1 ether));
        vm.prank(account);
        vm.expectRevert(SuperVaultStargateCapBridgeHook.EXTRA_OPTIONS_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encodeWithOptions(options));
    }

    /// @notice A non-executor worker id is rejected.
    function test_RevertIf_ExtraOptions_UnknownWorker() public {
        bytes memory options = abi.encodePacked(uint16(3), uint8(2), uint16(19), uint8(3), uint16(0), uint128(200_000));
        vm.prank(account);
        vm.expectRevert(SuperVaultStargateCapBridgeHook.EXTRA_OPTIONS_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encodeWithOptions(options));
    }

    /// @notice A non-TYPE_3 header is rejected.
    function test_RevertIf_ExtraOptions_WrongHeader() public {
        bytes memory options = abi.encodePacked(uint16(1), uint8(1), uint16(17), uint8(1), uint128(200_000));
        vm.prank(account);
        vm.expectRevert(SuperVaultStargateCapBridgeHook.EXTRA_OPTIONS_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encodeWithOptions(options));
    }

    /// @notice Truncated / garbage option bytes are rejected.
    function test_RevertIf_ExtraOptions_Truncated() public {
        // TYPE_3 header followed by a dangling worker byte (no size/type).
        bytes memory options = abi.encodePacked(uint16(3), uint8(1));
        vm.prank(account);
        vm.expectRevert(SuperVaultStargateCapBridgeHook.EXTRA_OPTIONS_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encodeWithOptions(options));

        // Valid entry whose declared size overruns the buffer.
        bytes memory overrun = abi.encodePacked(uint16(3), uint8(1), uint16(19), uint8(3), uint16(0)); // 16 gas bytes
        // missing
        vm.prank(account);
        vm.expectRevert(SuperVaultStargateCapBridgeHook.EXTRA_OPTIONS_NOT_VALID.selector);
        hook.preExecute(address(0), account, _encodeWithOptions(overrun));
    }

    /*//////////////////////////////////////////////////////////////
                        B1: LEAF (inspect) PINNING
    //////////////////////////////////////////////////////////////*/

    /// @notice Mutating only the destination vault inside the compose message changes the leaf.
    function test_Inspect_ChangesWhenExecutorVaultChanges() public {
        bytes memory dataA = _encode(DST_EID, _toBytes32(adapter), AMOUNT_LD, false, 0, _depositMessage());
        address otherVault = makeAddr("otherVault");
        capGuard.setDestinationVaultAsset(DST_CHAIN_ID, otherVault, inputToken); // R3-RF3
        bytes memory msgB = CapMessageLib.vaultDepositMessage(
            account, dstApproveHook, dstDepositHook, otherVault, inputToken, AMOUNT_LD
        );
        bytes memory dataB = _encode(DST_EID, _toBytes32(adapter), AMOUNT_LD, false, 0, msgB);
        assertTrue(keccak256(hook.inspect(dataA)) != keccak256(hook.inspect(dataB)));
    }

    /// @notice The leaf carries the CANONICAL chain id: remapping the EID changes the leaf.
    function test_Inspect_PinsCanonicalChainId() public {
        bytes memory data = _encode(DST_EID, _toBytes32(adapter), AMOUNT_LD, false, 0, _depositMessage());
        bytes memory leafBase = hook.inspect(data);

        capGuard.setEidChainId(DST_EID, 42_161); // governance remaps the EID
        capGuard.setApprovedAdapter(42_161, adapter, true);
        capGuard.setDestinationHooks(42_161, dstApproveHook, dstDepositHook);
        capGuard.setDestinationVaultAsset(42_161, destVault, inputToken); // R3-RF3
        capGuard.setStargateRoute(address(pool), 42_161, inputToken); // R3-RF1
        assertTrue(keccak256(leafBase) != keccak256(hook.inspect(data)), "leaf must track the canonical chain id");
    }

    /*//////////////////////////////////////////////////////////////
                        REGISTRY RESOLUTION
    //////////////////////////////////////////////////////////////*/

    function test_RecordsIntoGovernorResolvedRegistry_FollowsMigration() public {
        bytes memory data = _encode(DST_EID, _toBytes32(adapter), AMOUNT_LD, false, 0, _depositMessage());

        vm.prank(account);
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), AMOUNT_LD, "first registry not credited");

        MockPositionRegistry newRegistry = new MockPositionRegistry();
        governor.setRegistry(address(newRegistry));

        hook.setExecutionContext(account);
        vm.prank(account);
        hook.preExecute(address(0), account, data);

        assertEq(registry.bridgedOut(account), AMOUNT_LD, "old registry must not receive new writes");
        assertEq(newRegistry.bridgedOut(account), AMOUNT_LD, "new registry not credited after migration");
    }

    /*//////////////////////////////////////////////////////////////
                        LIFECYCLE / ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function test_RevertIf_PreExecuteNotAccount() public {
        bytes memory data = _encode(DST_EID, _toBytes32(adapter), AMOUNT_LD, false, 0, _depositMessage());
        vm.prank(makeAddr("attacker"));
        vm.expectRevert(BaseHook.UNAUTHORIZED_CALLER.selector);
        hook.preExecute(address(0), account, data);
    }

    function test_RevertIf_PreExecuteCalledTwiceSameContext() public {
        bytes memory data = _encode(DST_EID, _toBytes32(adapter), AMOUNT_LD, false, 0, _depositMessage());
        vm.prank(account);
        hook.preExecute(address(0), account, data);
        vm.prank(account);
        vm.expectRevert(BaseHook.PRE_EXECUTE_ALREADY_CALLED.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice A cap-guard revert propagates and nothing is recorded.
    function test_CapGuardRevertPropagates() public {
        bytes memory data = _encode(DST_EID, _toBytes32(adapter), AMOUNT_LD, false, 0, _depositMessage());
        vm.mockCallRevert(
            address(capGuard),
            abi.encodeWithSelector(ICapGuardLike.validateAllocation.selector),
            abi.encodeWithSignature("PER_CHAIN_CAP_EXCEEDED()")
        );
        vm.prank(account);
        vm.expectRevert(abi.encodeWithSignature("PER_CHAIN_CAP_EXCEEDED()"));
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_RevertIf_ZeroGovernor() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SuperVaultStargateCapBridgeHook(address(validator), address(0));
    }

    function test_Constructor_SetsGovernor() public view {
        assertEq(address(hook.SUPER_GOVERNOR()), address(governor));
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _toBytes32(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }

    /// @dev A gas-only executor lzCompose option entry: [worker 1][size 19][type 3][index][gas].
    function _lzComposeGasOption() internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(1), uint16(19), uint8(3), uint16(0), uint128(200_000));
    }

    /// @dev Encodes taxi-mode hookData carrying the given extraOptions bytes.
    function _encodeWithOptions(bytes memory extraOptions) internal view returns (bytes memory) {
        bytes memory fixedPart = abi.encodePacked(
            bytes32(0),
            address(0), // 52-byte strategy header
            NATIVE_FEE,
            address(pool),
            inputToken,
            DST_EID,
            _toBytes32(adapter),
            AMOUNT_LD,
            MIN_AMOUNT_LD
        );
        bytes memory composeMsg = _depositMessage();
        return abi.encodePacked(
            fixedPart, false, uint8(0), extraOptions.length, extraOptions, composeMsg.length, composeMsg
        );
    }

    function _encodeWithMin(
        uint32 dstEid,
        bytes32 to,
        uint256 amountLD,
        uint256 minAmountLD
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory fixedPart = abi.encodePacked(
            bytes32(0),
            address(0), // 52-byte strategy header
            NATIVE_FEE,
            address(pool),
            inputToken,
            dstEid,
            to,
            amountLD,
            minAmountLD
        );
        bytes memory composeMsg = _depositMessageWithAmount(minAmountLD);
        return abi.encodePacked(fixedPart, false, uint8(0), uint256(0), composeMsg.length, composeMsg);
    }

    function _encode(
        uint32 dstEid,
        bytes32 to,
        uint256 amountLD,
        bool usePrev,
        uint8 mode,
        bytes memory composeMsg
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory fixedPart = abi.encodePacked(
            bytes32(0),
            address(0), // 52-byte strategy header
            NATIVE_FEE,
            address(pool),
            inputToken,
            dstEid,
            to,
            amountLD,
            MIN_AMOUNT_LD
        );
        return
            abi.encodePacked(
                fixedPart,
                usePrev,
                mode,
                uint256(0), // extraOptions length
                composeMsg.length,
                composeMsg
            );
    }
}
