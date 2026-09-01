// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { LayerZeroV2Helper } from "pigeon/layerzero-v2/LayerZeroV2Helper.sol";

import { SuperVaultStargateCapBridgeHook } from
    "../../../src/hooks/bridges/stargate/SuperVaultStargateCapBridgeHook.sol";
import { IStargate } from "../../../src/vendor/bridges/stargate/IStargate.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";

interface ICapGuardLike {
    function validateAllocation(address strategy, uint64 chainId, address vault, uint256 amount) external view;
}

contract MockCapGuard is ICapGuardLike {
    function validateAllocation(address, uint64, address, uint256) external view { }
}

contract MockPositionRegistry {
    mapping(address => uint256) public bridgedOut;
    mapping(address => mapping(uint64 => uint256)) public bridgedOutByChain;

    function recordBridgedOut(address strategy, uint64 chainId, uint256 amount) external {
        bridgedOut[strategy] += amount;
        bridgedOutByChain[strategy][chainId] += amount;
    }
}

contract MockGovernorAddressBook {
    bytes32 private constant CROSS_CHAIN_CAP_GUARD = keccak256("CROSS_CHAIN_CAP_GUARD");
    bytes32 private constant CROSS_CHAIN_POSITION_REGISTRY = keccak256("CROSS_CHAIN_POSITION_REGISTRY");

    address public immutable CAP_GUARD;
    address public immutable REGISTRY;

    constructor(address capGuard_, address registry_) {
        CAP_GUARD = capGuard_;
        REGISTRY = registry_;
    }

    function getAddress(bytes32 key) external view returns (address) {
        if (key == CROSS_CHAIN_CAP_GUARD) return CAP_GUARD;
        if (key == CROSS_CHAIN_POSITION_REGISTRY) return REGISTRY;
        return address(0);
    }
}

contract MockStargateSignatureStorage {
    function retrieveSignatureData(address) external view returns (bytes memory) {
        uint48 validUntil = uint48(block.timestamp + 3600);
        bytes32[] memory proofSrc = new bytes32[](1);
        proofSrc[0] = keccak256("src1");
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        return abi.encode(new uint64[](0), validUntil, 0, keccak256("root"), proofSrc, proofDst, hex"abcdef");
    }
}

contract MockPrevHook {
    uint256 private immutable OUT;

    constructor(uint256 out_) {
        OUT = out_;
    }

    function getOutAmount(address) external view returns (uint256) {
        return OUT;
    }
}

/// @title SuperVaultStargateCapBridgeHookFork
/// @notice Two-fork round trip: the cap-aware Stargate hook enforces the cap and produces a
///         sendToken the REAL mainnet Stargate USDC pool accepts; pigeon's LayerZeroV2Helper relays
///         the message to Base and the recipient receives USDC. Proves validated == bridged end to
///         end. Plus a cap-breach path that reverts before any send.
contract SuperVaultStargateCapBridgeHookFork is Test {
    address internal constant STARGATE_USDC_POOL_ETH = 0xc026395860Db2d07ee33e05fE50ed7bD583189C7;
    address internal constant LZ_ENDPOINT_BASE = 0x1a44076050125825900e736c501f859c50fE728c;
    address internal constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    uint32 internal constant EID_BASE = 30_184;
    uint256 internal constant AMOUNT_LD = 1000e6;
    uint256 internal constant MIN_AMOUNT_LD = 990e6;

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
    address internal recipient = makeAddr("destinationVault");

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

        deal(USDC_ETH, account, AMOUNT_LD);
    }

    /// @notice Full round trip: cap enforced on ETH, real Stargate pool accepts sendToken, pigeon
    ///         relays to Base, recipient receives USDC. Validated tuple == bridged tuple.
    function test_Fork_CapEnforcedThenRealBridgeAndPigeonFill() public {
        uint256 fee = _quoteFee();
        vm.deal(account, fee);
        bytes memory data = _encode(EID_BASE, _toBytes32(recipient), AMOUNT_LD, MIN_AMOUNT_LD, fee, false, 0);

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, uint64(EID_BASE), recipient, AMOUNT_LD))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);

        assertEq(registry.bridgedOut(account), AMOUNT_LD, "in-flight exposure not recorded");
        assertEq(registry.bridgedOutByChain(account, uint64(EID_BASE)), AMOUNT_LD, "per-eid exposure not recorded");

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

        // Pigeon relays the LayerZero message to Base and delivers to the recipient.
        lzHelper.help(LZ_ENDPOINT_BASE, baseForkId, logs);

        vm.selectFork(baseForkId);
        assertGe(IERC20(USDC_BASE).balanceOf(recipient), MIN_AMOUNT_LD, "recipient not filled on Base");
    }

    /// @notice A cap breach reverts in _preExecute, before any approval/send — no funds leave and
    ///         nothing reaches the pool.
    function test_Fork_CapBreachRevertsBeforeAnySend() public {
        uint256 fee = _quoteFee();
        vm.deal(account, fee);
        bytes memory data = _encode(EID_BASE, _toBytes32(recipient), AMOUNT_LD, MIN_AMOUNT_LD, fee, false, 0);

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

    /// @notice Round trip through the usePrevHookAmount path: the parent rewrites amountLD to the
    ///         prev-hook output (and scales minAmountLD); the cap validated the prev amount and the
    ///         real pool bridges it, with pigeon delivering on Base.
    function test_Fork_RoundTrip_UsePrevHookAmount() public {
        uint256 prevAmount = 600e6;
        deal(USDC_ETH, account, prevAmount);
        MockPrevHook prevHook = new MockPrevHook(prevAmount);

        uint256 fee = _quoteFeeFor(prevAmount, hex"", hex"");
        vm.deal(account, fee);
        bytes memory data = _encode(EID_BASE, _toBytes32(recipient), AMOUNT_LD, MIN_AMOUNT_LD, fee, true, 0);

        // Parent scales minAmountLD proportionally: min * prev / amount.
        uint256 scaledMin = MIN_AMOUNT_LD * prevAmount / AMOUNT_LD;

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, uint64(EID_BASE), recipient, prevAmount))
        );
        vm.prank(account);
        hook.preExecute(address(prevHook), account, data);
        assertEq(registry.bridgedOut(account), prevAmount, "exposure not the prev-hook amount");

        Execution[] memory execs = hook.build(address(prevHook), account, data);
        vm.recordLogs();
        vm.startPrank(account);
        for (uint256 i = 1; i <= 4; i++) {
            (bool ok,) = execs[i].target.call{ value: execs[i].value }(execs[i].callData);
            assertTrue(ok, "source execution failed");
        }
        vm.stopPrank();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(IERC20(USDC_ETH).balanceOf(account), 0, "prev-amount input not fully pulled");

        lzHelper.help(LZ_ENDPOINT_BASE, baseForkId, logs);
        vm.selectFork(baseForkId);
        assertGe(IERC20(USDC_BASE).balanceOf(recipient), scaledMin, "recipient not filled rescaled");
    }

    /// @notice On the real pool, the SendParam the parent actually builds equals the tuple the cap
    ///         validated — the on-fork drift guard against the private parent offsets.
    function test_Fork_ValidatedTupleEqualsRealSendParam() public {
        uint256 fee = _quoteFee();
        vm.deal(account, fee);
        bytes memory data = _encode(EID_BASE, _toBytes32(recipient), AMOUNT_LD, MIN_AMOUNT_LD, fee, false, 0);

        Execution[] memory execs = hook.build(address(0), account, data);
        (uint32 eid, address to, uint256 amt) = _decodeSendToken(execs[BRIDGE_EXECUTION_INDEX].callData);
        assertEq(eid, EID_BASE, "real SendParam dstEid mismatch");
        assertEq(to, recipient, "real SendParam recipient mismatch");
        assertEq(amt, AMOUNT_LD, "real SendParam amount mismatch");

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, uint64(eid), to, amt))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);
    }

    /// @notice Bus mode (1) is accepted by the real pool and the cap enforced; delivery is deferred
    ///         (batched) so no synchronous dst fill is asserted — this is a source-side check.
    function test_Fork_Mode1Bus_AcceptedAtSource() public {
        uint256 fee = _quoteFeeFor(AMOUNT_LD, hex"", hex"");
        vm.deal(account, fee);
        bytes memory data = _encode(EID_BASE, _toBytes32(recipient), AMOUNT_LD, MIN_AMOUNT_LD, fee, false, 1);

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, uint64(EID_BASE), recipient, AMOUNT_LD))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);

        Execution[] memory execs = hook.build(address(0), account, data);
        vm.startPrank(account);
        for (uint256 i = 1; i <= 4; i++) {
            (bool ok,) = execs[i].target.call{ value: execs[i].value }(execs[i].callData);
            assertTrue(ok, "bus-mode source execution failed");
        }
        vm.stopPrank();
        assertEq(IERC20(USDC_ETH).balanceOf(account), 0, "bus-mode input not pulled");
    }

    /// @notice The pool pulls exactly amountLD; any excess wallet balance is untouched, so the cap
    ///         (which records amountLD) matches what actually leaves.
    function test_Fork_PullsExactAmount_WhenWalletHasMore() public {
        deal(USDC_ETH, account, AMOUNT_LD + 500e6); // extra sitting in the wallet
        uint256 fee = _quoteFee();
        vm.deal(account, fee);
        bytes memory data = _encode(EID_BASE, _toBytes32(recipient), AMOUNT_LD, MIN_AMOUNT_LD, fee, false, 0);

        vm.prank(account);
        hook.preExecute(address(0), account, data);

        Execution[] memory execs = hook.build(address(0), account, data);
        vm.startPrank(account);
        for (uint256 i = 1; i <= 4; i++) {
            (bool ok,) = execs[i].target.call{ value: execs[i].value }(execs[i].callData);
            assertTrue(ok, "source execution failed");
        }
        vm.stopPrank();

        assertEq(IERC20(USDC_ETH).balanceOf(account), 500e6, "only amountLD should be pulled");
        assertEq(registry.bridgedOut(account), AMOUNT_LD, "cap recorded != amount pulled");
    }

    /// @notice A compose message (destination-execution payload) — the SuperVault cross-chain-deposit
    ///         shape — is decoded through the parent with the real pool: the cap validates the same
    ///         (dstEid, recipient, amount) the built sendToken carries, and the built SendParam
    ///         carries the compose payload (signature appended). Build + cap only: executing the
    ///         real compose send needs a fee/gas quote for the signature-enlarged message, which is
    ///         parent compose-fee behaviour, not cap logic (mirrors StargateHooksFork's build-only
    ///         compose test).
    function test_Fork_WithComposeMsg_CapEnforcedAndBuilt() public {
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = USDC_BASE;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = AMOUNT_LD;
        bytes memory composeMsg = abi.encode(bytes(""), bytes(""), account, dstTokens, intentAmounts);
        bytes memory extraOptions = hex"000301001101000000000000000000000000000186a0"; // lzCompose gas

        uint256 fee = _quoteFeeFor(AMOUNT_LD, extraOptions, composeMsg);
        vm.deal(account, fee);
        bytes memory data =
            _encodeWithTail(EID_BASE, _toBytes32(recipient), AMOUNT_LD, MIN_AMOUNT_LD, fee, 0, extraOptions, composeMsg);

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, uint64(EID_BASE), recipient, AMOUNT_LD))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), AMOUNT_LD, "compose path exposure not recorded");

        // The built sendToken (against the real pool) carries the same cap tuple + the compose payload.
        Execution[] memory execs = hook.build(address(0), account, data);
        (uint32 eid, address to, uint256 amt, bytes memory builtCompose) =
            _decodeSendTokenWithCompose(execs[BRIDGE_EXECUTION_INDEX].callData);
        assertEq(eid, EID_BASE, "compose SendParam dstEid mismatch");
        assertEq(to, recipient, "compose SendParam recipient mismatch");
        assertEq(amt, AMOUNT_LD, "compose SendParam amount mismatch");
        assertGt(builtCompose.length, composeMsg.length, "signature not appended to composeMsg");
    }

    /// @notice Mode 3 (lzMulticall) is rejected on-fork before any send (cap can't bind to it).
    function test_Fork_RevertIf_Mode3() public {
        bytes memory data = _encode(EID_BASE, _toBytes32(recipient), AMOUNT_LD, MIN_AMOUNT_LD, 0, false, 3);
        vm.prank(account);
        vm.expectRevert(); // parent DATA_NOT_VALID
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), 0, "recorded despite mode-3 reject");
    }

    /// @notice A non-EVM recipient is rejected on-fork before any send.
    function test_Fork_RevertIf_NonEvmRecipient() public {
        bytes32 nonEvm = bytes32(uint256(1) << 200);
        bytes memory data = _encode(EID_BASE, nonEvm, AMOUNT_LD, MIN_AMOUNT_LD, 0, false, 0);
        vm.prank(account);
        vm.expectRevert(); // DATA_NOT_VALID
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), 0, "recorded despite non-EVM recipient");
    }

    function _quoteFee() internal view returns (uint256) {
        return _quoteFeeFor(AMOUNT_LD, hex"", hex"");
    }

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
            to: _toBytes32(recipient),
            amountLD: amountLD,
            minAmountLD: MIN_AMOUNT_LD * amountLD / AMOUNT_LD,
            extraOptions: extraOptions,
            composeMsg: composeMsg,
            oftCmd: bytes("")
        });
        return IStargate(STARGATE_USDC_POOL_ETH).quoteSend(q, false).nativeFee;
    }

    function _decodeSendToken(bytes memory callData) internal pure returns (uint32 eid, address to, uint256 amt) {
        bytes memory args = new bytes(callData.length - 4);
        for (uint256 i; i < args.length; ++i) {
            args[i] = callData[i + 4];
        }
        (IStargate.SendParam memory sendParam,,) =
            abi.decode(args, (IStargate.SendParam, IStargate.MessagingFee, address));
        eid = sendParam.dstEid;
        to = address(uint160(uint256(sendParam.to)));
        amt = sendParam.amountLD;
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
        uint8 mode
    )
        internal
        view
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
        return abi.encodePacked(fixedPart, usePrev, mode, uint256(0), uint256(0));
    }

    function _encodeWithTail(
        uint32 dstEid,
        bytes32 to,
        uint256 amountLD,
        uint256 minAmountLD,
        uint256 lzNativeFee,
        uint8 mode,
        bytes memory extraOptions,
        bytes memory composeMsg
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory fixedPart = abi.encodePacked(
            bytes32(0),
            address(0),
            lzNativeFee,
            STARGATE_USDC_POOL_ETH,
            USDC_ETH,
            dstEid,
            to,
            amountLD,
            minAmountLD
        );
        return abi.encodePacked(
            fixedPart, false, mode, uint256(extraOptions.length), extraOptions, uint256(composeMsg.length), composeMsg
        );
    }
}
