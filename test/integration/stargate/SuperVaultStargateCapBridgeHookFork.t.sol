// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { LayerZeroV2Helper } from "pigeon/layerzero-v2/LayerZeroV2Helper.sol";

import {
    SuperVaultStargateCapBridgeHook
} from "../../../src/hooks/bridges/stargate/SuperVaultStargateCapBridgeHook.sol";
import { IStargate } from "../../../src/vendor/bridges/stargate/IStargate.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import {
    ICapGuardLike,
    MockCapGuard,
    MockPositionRegistry,
    MockGovernorAddressBook,
    MockPrevHook,
    CapMessageLib
} from "../../unit/hooks/bridges/CapBridgeTestUtils.sol";

contract MockStargateSignatureStorage {
    function retrieveSignatureData(address) external view returns (bytes memory) {
        uint48 validUntil = uint48(block.timestamp + 3600);
        bytes32[] memory proofSrc = new bytes32[](1);
        proofSrc[0] = keccak256("src1");
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        return abi.encode(new uint64[](0), validUntil, 0, keccak256("root"), proofSrc, proofDst, hex"abcdef");
    }
}

/// @title SuperVaultStargateCapBridgeHookFork
/// @notice Two-fork test of the B1/B4-hardened Stargate cap hook against the REAL mainnet Stargate
///         USDC pool: the cap binds to the ECONOMIC vault decoded from the compose message and is
///         keyed under the CANONICAL EVM chain id (8453), never the LayerZero EID (30184); the
///         transport receiver must be the approved destination adapter. Pigeon relays the LZ
///         packet to Base, proving tokens land on the ADAPTER (the transport hop), not on a bare
///         vault address. (Destination compose execution — adapter -> SuperDestinationExecutor ->
///         vault shares — is the destination stack's own e2e, not simulatable by the LZ helper.)
contract SuperVaultStargateCapBridgeHookFork is Test {
    address internal constant STARGATE_USDC_POOL_ETH = 0xc026395860Db2d07ee33e05fE50ed7bD583189C7;
    address internal constant LZ_ENDPOINT_BASE = 0x1a44076050125825900e736c501f859c50fE728c;
    address internal constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    uint32 internal constant EID_BASE = 30_184; // LayerZero endpoint id (routing namespace)
    uint64 internal constant BASE_CHAIN_ID = 8453; // canonical EVM chain id (cap namespace, B4)
    uint256 internal constant AMOUNT_LD = 1000e6;
    uint256 internal constant MIN_AMOUNT_LD = 990e6;

    /// @dev lzCompose gas option so the quote covers compose delivery.
    bytes internal constant EXTRA_OPTIONS = hex"000301001101000000000000000000000000000186a0";

    // build() layout: [0]=pre [1]=approve(0) [2]=approve(amt) [3]=sendToken [4]=approve(0) [5]=post
    uint256 internal constant BRIDGE_EXECUTION_INDEX = 3;

    uint256 internal ethForkId;
    uint256 internal baseForkId;

    SuperVaultStargateCapBridgeHook internal hook;
    MockCapGuard internal capGuard;
    MockPositionRegistry internal registry;
    MockGovernorAddressBook internal governor;
    MockStargateSignatureStorage internal validator;
    LayerZeroV2Helper internal lzHelper;

    address internal account = makeAddr("strategy");
    address internal adapter = makeAddr("stargateAdapter"); // transport receiver (B1)
    address internal destVault = makeAddr("destinationVault"); // economic destination (B1)
    address internal dstApproveHook = makeAddr("dstApproveHook");
    address internal dstDepositHook = makeAddr("dstDepositHook");

    function setUp() public {
        ethForkId = vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));
        baseForkId = vm.createFork(vm.envString("BASE_RPC_URL"));

        capGuard = new MockCapGuard();
        registry = new MockPositionRegistry();
        governor = new MockGovernorAddressBook(address(capGuard), address(registry));
        validator = new MockStargateSignatureStorage();
        hook = new SuperVaultStargateCapBridgeHook(address(validator), address(governor));
        hook.setExecutionContext(account);
        lzHelper = new LayerZeroV2Helper();

        // B1/B4 destination policy.
        capGuard.setEidChainId(EID_BASE, BASE_CHAIN_ID);
        capGuard.setApprovedAdapter(BASE_CHAIN_ID, adapter, true);
        capGuard.setDestinationHooks(BASE_CHAIN_ID, dstApproveHook, dstDepositHook);
        capGuard.setDestinationVaultAsset(BASE_CHAIN_ID, destVault, USDC_BASE); // R3-RF3
        capGuard.setStargateRoute(STARGATE_USDC_POOL_ETH, BASE_CHAIN_ID, USDC_BASE); // R3-RF1
        capGuard.setStargateMinDeliveryBps(9900); // R3-RF1 (MIN/AMOUNT = 99%)

        deal(USDC_ETH, account, AMOUNT_LD);
    }

    /// @dev R2-B1: the action amount must equal the delivery minimum for the encoded amountLD.
    function _depositMessage(uint256 amountLD) internal view returns (bytes memory) {
        return CapMessageLib.vaultDepositMessage(
            account, dstApproveHook, dstDepositHook, destVault, USDC_BASE, MIN_AMOUNT_LD * amountLD / AMOUNT_LD
        );
    }

    /// @dev Two-phase encode: build once with a placeholder fee to learn the FINAL compose message
    ///      (signature appended), quote the real pool for that message, then re-encode with the
    ///      quoted fee.
    function _encodeWithQuotedFee(
        uint256 amountLD,
        bool usePrev,
        uint8 mode,
        bytes memory composeMsg
    )
        internal
        returns (bytes memory data, uint256 fee)
    {
        data = _encode(
            EID_BASE, _toBytes32(adapter), amountLD, MIN_AMOUNT_LD * amountLD / AMOUNT_LD, 1, usePrev, mode, composeMsg
        );
        Execution[] memory execs = hook.build(usePrev ? address(new MockPrevHook(amountLD)) : address(0), account, data);
        (,,, bytes memory builtCompose) = _decodeSendTokenWithCompose(execs[BRIDGE_EXECUTION_INDEX].callData);
        fee = _quoteFeeFor(amountLD, EXTRA_OPTIONS, builtCompose);
        data = _encode(
            EID_BASE,
            _toBytes32(adapter),
            amountLD,
            MIN_AMOUNT_LD * amountLD / AMOUNT_LD,
            fee,
            usePrev,
            mode,
            composeMsg
        );
    }

    /// @notice Full transport round trip: cap enforced on ETH against the ECONOMIC vault, real
    ///         Stargate pool accepts the compose sendToken, pigeon relays to Base and the tokens
    ///         land on the APPROVED ADAPTER (transport hop) — under the canonical chain key.
    function test_Fork_CapEnforcedThenRealBridgeAndPigeonFill() public {
        (bytes memory data, uint256 fee) = _encodeWithQuotedFee(AMOUNT_LD, false, 0, _depositMessage(AMOUNT_LD));
        vm.deal(account, fee);

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, BASE_CHAIN_ID, destVault, AMOUNT_LD))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);

        // B4: exposure recorded under the canonical EVM chain id, never the EID.
        assertEq(registry.bridgedOut(account), AMOUNT_LD, "in-flight exposure not recorded");
        assertEq(registry.bridgedOutByChain(account, BASE_CHAIN_ID), AMOUNT_LD, "not keyed by canonical chain id");
        assertEq(registry.bridgedOutByChain(account, uint64(EID_BASE)), 0, "must not key by LayerZero EID");

        Execution[] memory execs = hook.build(address(0), account, data);
        assertEq(execs[BRIDGE_EXECUTION_INDEX].target, STARGATE_USDC_POOL_ETH, "bridge target is not the pool");

        vm.recordLogs();
        vm.startPrank(account);
        for (uint256 i = 1; i <= 4; i++) {
            (bool ok,) = execs[i].target.call{ value: execs[i].value }(execs[i].callData);
            assertTrue(ok, "source execution failed");
        }
        vm.stopPrank();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(IERC20(USDC_ETH).balanceOf(account), 0, "input not pulled by the pool");

        // Pigeon relays the LayerZero message to Base: tokens are delivered to the transport
        // receiver — the approved adapter, NOT any vault address.
        lzHelper.help(LZ_ENDPOINT_BASE, baseForkId, logs);

        vm.selectFork(baseForkId);
        assertGe(IERC20(USDC_BASE).balanceOf(adapter), MIN_AMOUNT_LD, "adapter not filled on Base");
        assertEq(IERC20(USDC_BASE).balanceOf(destVault), 0, "no raw transfer may reach the vault address");
    }

    /// @notice A cap breach reverts in _preExecute, before any approval/send.
    function test_Fork_CapBreachRevertsBeforeAnySend() public {
        (bytes memory data,) = _encodeWithQuotedFee(AMOUNT_LD, false, 0, _depositMessage(AMOUNT_LD));

        vm.mockCallRevert(
            address(capGuard),
            abi.encodeWithSelector(ICapGuardLike.validateAllocation.selector),
            abi.encodeWithSignature("CROSS_CHAIN_CAP_EXCEEDED()")
        );

        vm.prank(account);
        vm.expectRevert(abi.encodeWithSignature("CROSS_CHAIN_CAP_EXCEEDED()"));
        hook.preExecute(address(0), account, data);

        assertEq(registry.bridgedOut(account), 0, "no exposure should be recorded on a breach");
        assertEq(IERC20(USDC_ETH).balanceOf(account), AMOUNT_LD, "funds must not move on a breach");
    }

    /// @notice usePrevHookAmount path: the cap validates the prev-hook amount that actually leaves,
    ///         still bound to the economic vault and the canonical chain id.
    function test_Fork_UsePrevHookAmount_SourceSide() public {
        uint256 prevAmount = 600e6;
        deal(USDC_ETH, account, prevAmount);
        MockPrevHook prevHook = new MockPrevHook(prevAmount);

        (bytes memory data, uint256 fee) = _encodeWithQuotedFee(prevAmount, true, 0, _depositMessage(prevAmount));
        vm.deal(account, fee);

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, BASE_CHAIN_ID, destVault, prevAmount))
        );
        vm.prank(account);
        hook.preExecute(address(prevHook), account, data);
        assertEq(registry.bridgedOut(account), prevAmount, "exposure not the prev-hook amount");

        Execution[] memory execs = hook.build(address(prevHook), account, data);
        vm.startPrank(account);
        for (uint256 i = 1; i <= 4; i++) {
            (bool ok,) = execs[i].target.call{ value: execs[i].value }(execs[i].callData);
            assertTrue(ok, "source execution failed");
        }
        vm.stopPrank();
        assertEq(IERC20(USDC_ETH).balanceOf(account), 0, "prev-amount input not fully pulled");
    }

    /// @notice On the real pool, the SendParam the parent actually builds targets the adapter with
    ///         the validated amount — while the cap validated the VAULT extracted from the compose
    ///         message (the B1 separation, on-fork).
    function test_Fork_ValidatedVaultSeparateFromRealSendParamReceiver() public {
        (bytes memory data,) = _encodeWithQuotedFee(AMOUNT_LD, false, 0, _depositMessage(AMOUNT_LD));

        Execution[] memory execs = hook.build(address(0), account, data);
        (uint32 eid, address to, uint256 amt) = _decodeSendToken(execs[BRIDGE_EXECUTION_INDEX].callData);
        assertEq(eid, EID_BASE, "real SendParam dstEid mismatch");
        assertEq(to, adapter, "real SendParam receiver must be the transport adapter");
        assertEq(amt, AMOUNT_LD, "real SendParam amount mismatch");

        // The cap tuple carries the vault, not the transport receiver.
        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, BASE_CHAIN_ID, destVault, AMOUNT_LD))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);
    }

    /// @notice An EID with no canonical mapping fails closed on-fork (B4).
    function test_Fork_RevertIf_EidNotMapped() public {
        uint32 unmappedEid = 30_101; // Ethereum EID, not configured
        bytes memory data = _encode(
            unmappedEid, _toBytes32(adapter), AMOUNT_LD, MIN_AMOUNT_LD, 1, false, 0, _depositMessage(AMOUNT_LD)
        );
        vm.prank(account);
        vm.expectRevert(SuperVaultStargateCapBridgeHook.EID_NOT_MAPPED.selector);
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), 0, "recorded despite unmapped EID");
    }

    /// @notice A raw send (empty compose message) is no longer expressible through the cap hook.
    function test_Fork_RevertIf_EmptyComposeMsg() public {
        bytes memory data = _encode(EID_BASE, _toBytes32(adapter), AMOUNT_LD, MIN_AMOUNT_LD, 1, false, 0, bytes(""));
        vm.prank(account);
        vm.expectRevert(); // DESTINATION_ACTION_NOT_VALID
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), 0, "recorded despite raw-transfer send");
    }

    /// @notice Mode 3 (lzMulticall) is rejected on-fork before any send (cap can't bind to it).
    function test_Fork_RevertIf_Mode3() public {
        bytes memory data =
            _encode(EID_BASE, _toBytes32(adapter), AMOUNT_LD, MIN_AMOUNT_LD, 0, false, 3, _depositMessage(AMOUNT_LD));
        vm.prank(account);
        vm.expectRevert(); // MODE_NOT_CAPPABLE (taxi-only)
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), 0, "recorded despite mode-3 reject");
    }

    /// @notice A non-EVM recipient is rejected on-fork before any send.
    function test_Fork_RevertIf_NonEvmRecipient() public {
        bytes32 nonEvm = bytes32(uint256(1) << 200);
        bytes memory data = _encode(EID_BASE, nonEvm, AMOUNT_LD, MIN_AMOUNT_LD, 0, false, 0, _depositMessage(AMOUNT_LD));
        vm.prank(account);
        vm.expectRevert(); // DATA_NOT_VALID
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), 0, "recorded despite non-EVM recipient");
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _quoteFeeFor(
        uint256 amountLD,
        bytes memory extraOptions,
        bytes memory composeMsg
    )
        internal
        view
        returns (uint256)
    {
        IStargate.SendParam memory q = IStargate.SendParam({
            dstEid: EID_BASE,
            to: _toBytes32(adapter),
            amountLD: amountLD,
            minAmountLD: MIN_AMOUNT_LD * amountLD / AMOUNT_LD,
            extraOptions: extraOptions,
            composeMsg: composeMsg,
            oftCmd: bytes("")
        });
        return IStargate(STARGATE_USDC_POOL_ETH).quoteSend(q, false).nativeFee;
    }

    function _decodeSendToken(bytes memory callData) internal pure returns (uint32 eid, address to, uint256 amt) {
        (eid, to, amt,) = _decodeSendTokenWithCompose(callData);
    }

    function _decodeSendTokenWithCompose(bytes memory callData)
        internal
        pure
        returns (uint32 eid, address to, uint256 amt, bytes memory composeMsg)
    {
        bytes memory args = new bytes(callData.length - 4);
        for (uint256 i; i < args.length; ++i) {
            args[i] = callData[i + 4];
        }
        (IStargate.SendParam memory sendParam,,) =
            abi.decode(args, (IStargate.SendParam, IStargate.MessagingFee, address));
        eid = sendParam.dstEid;
        to = address(uint160(uint256(sendParam.to)));
        amt = sendParam.amountLD;
        composeMsg = sendParam.composeMsg;
    }

    function _toBytes32(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }

    function _encode(
        uint32 dstEid,
        bytes32 to,
        uint256 amountLD,
        uint256 minAmountLD,
        uint256 lzNativeFee,
        bool usePrev,
        uint8 mode,
        bytes memory composeMsg
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory fixedPart = abi.encodePacked(
            bytes32(0),
            address(0), // 52-byte strategy header
            lzNativeFee,
            STARGATE_USDC_POOL_ETH,
            USDC_ETH,
            dstEid,
            to,
            amountLD,
            minAmountLD
        );
        return abi.encodePacked(
            fixedPart, usePrev, mode, uint256(EXTRA_OPTIONS.length), EXTRA_OPTIONS, composeMsg.length, composeMsg
        );
    }
}
