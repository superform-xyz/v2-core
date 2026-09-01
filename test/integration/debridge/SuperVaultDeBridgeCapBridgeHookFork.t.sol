// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { DebridgeDlnHelper } from "pigeon/debridge/DebridgeDlnHelper.sol";

import { SuperVaultDeBridgeCapBridgeHook } from
    "../../../src/hooks/bridges/debridge/SuperVaultDeBridgeCapBridgeHook.sol";
import { IDlnSource } from "../../../src/vendor/bridges/debridge/IDlnSource.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";

/// @dev View no-op matching the real cap guard (STATICCALL-safe). Tuple asserted via vm.expectCall.
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

/// @dev deBridge signature-storage stub deployed as the hook's validator so build()'s
///      retrieveSignatureData resolves to a well-formed blob.
contract MockDeBridgeSignatureStorage {
    function retrieveSignatureData(address) external view returns (bytes memory) {
        uint48 validUntil = uint48(block.timestamp + 3600);
        bytes32[] memory proofSrc = new bytes32[](1);
        proofSrc[0] = keccak256("src1");
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        return abi.encode(new uint64[](0), validUntil, 0, keccak256("root"), proofSrc, proofDst, hex"abcdef");
    }
}

/// @dev Minimal prev-hook returning a fixed getOutAmount for the usePrevHookAmount branch.
contract MockPrevHook {
    uint256 private immutable OUT;

    constructor(uint256 out_) {
        OUT = out_;
    }

    function getOutAmount(address) external view returns (uint256) {
        return OUT;
    }
}

/// @title SuperVaultDeBridgeCapBridgeHookFork
/// @notice Two-fork round trip: the cap-aware deBridge hook enforces the cap and produces a
///         createOrder call the REAL mainnet DLN source accepts; pigeon then relays the fill to
///         Base. Proves the validated (recipient, chainId, amount) equals what actually bridges,
///         end to end. Plus a cap-breach path that reverts before any order.
contract SuperVaultDeBridgeCapBridgeHookFork is Test {
    // Real deBridge DLN (same source address on every chain; dst is the DlnDestination).
    address internal constant DLN_SOURCE = 0xeF4fB24aD0916217251F553c0596F8Edc630EB66;
    address internal constant DLN_DST = 0xE7351Fd770A37282b91D153Ee690B63579D6dd7f;

    // Tokens
    address internal constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    uint64 internal constant BASE_CHAIN_ID = 8453; // deBridge id == EVM chainId for EVM dsts
    uint256 internal constant GIVE_AMOUNT = 1000e6;
    // ~10% give/take spread, matching a real accepted DLN order (a tight spread is rejected).
    uint256 internal constant TAKE_AMOUNT = 900e6;

    // build() layout: [0]=preExecute [1]=createOrder [2]=postExecute
    uint256 internal constant BRIDGE_EXECUTION_INDEX = 1;

    uint256 internal ethFork;
    uint256 internal baseFork;

    SuperVaultDeBridgeCapBridgeHook internal hook;
    MockCapGuard internal capGuard;
    MockPositionRegistry internal registry;
    MockGovernorAddressBook internal governor;
    MockDeBridgeSignatureStorage internal validator;
    DebridgeDlnHelper internal dlnHelper;

    address internal account = makeAddr("strategy");
    address internal recipient = makeAddr("destinationVault");

    uint256 internal nativeFee;

    function setUp() public {
        ethFork = vm.createFork(vm.envString("ETHEREUM_RPC_URL"), 23_096_042);
        baseFork = vm.createFork(vm.envString("BASE_RPC_URL"), 33_931_553);

        // Pigeon helper must exist and be persistent (it self-selects the destination fork).
        vm.selectFork(baseFork);
        dlnHelper = new DebridgeDlnHelper();
        vm.allowCheatcodes(address(dlnHelper));
        vm.makePersistent(address(dlnHelper));

        vm.selectFork(ethFork);
        capGuard = new MockCapGuard();
        registry = new MockPositionRegistry();
        governor = new MockGovernorAddressBook(address(capGuard), address(registry));
        validator = new MockDeBridgeSignatureStorage();
        hook = new SuperVaultDeBridgeCapBridgeHook(DLN_SOURCE, address(validator), address(governor));
        hook.setExecutionContext(account);

        nativeFee = IDlnSource(DLN_SOURCE).globalFixedNativeFee();
        deal(USDC_ETH, account, GIVE_AMOUNT);
        vm.deal(account, nativeFee);
    }

    /// @notice Full round trip: cap enforced on ETH, real DLN source accepts the createOrder, pigeon
    ///         fills on Base, recipient receives the takeAmount. Validated tuple == bridged tuple.
    function test_Fork_CapEnforcedThenRealBridgeAndPigeonFill() public {
        vm.selectFork(ethFork);
        bytes memory data = _encode(recipient, BASE_CHAIN_ID, GIVE_AMOUNT, USDC_ETH, TAKE_AMOUNT, nativeFee, false);

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, BASE_CHAIN_ID, recipient, GIVE_AMOUNT))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);

        assertEq(registry.bridgedOut(account), GIVE_AMOUNT, "in-flight exposure not recorded");
        assertEq(registry.bridgedOutByChain(account, BASE_CHAIN_ID), GIVE_AMOUNT, "per-chain exposure not recorded");

        uint256 recipientBefore = _baseBalanceOf(recipient);

        Execution[] memory execs = hook.build(address(0), account, data);
        assertEq(execs[BRIDGE_EXECUTION_INDEX].target, DLN_SOURCE, "bridge target is not the DLN source");

        vm.recordLogs();
        vm.startPrank(account);
        IERC20(USDC_ETH).approve(DLN_SOURCE, GIVE_AMOUNT);
        (bool ok,) = execs[BRIDGE_EXECUTION_INDEX].target.call{ value: execs[BRIDGE_EXECUTION_INDEX].value }(
            execs[BRIDGE_EXECUTION_INDEX].callData
        );
        vm.stopPrank();
        assertTrue(ok, "real DLN source rejected the createOrder");
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(IERC20(USDC_ETH).balanceOf(account), 0, "giveToken not pulled by DLN source");

        // Pigeon relays the DlnOrderCreated log to Base and fills the taker → recipient.
        dlnHelper.help(DLN_SOURCE, DLN_DST, baseFork, uint256(BASE_CHAIN_ID), logs);

        vm.selectFork(baseFork);
        assertEq(IERC20(USDC_BASE).balanceOf(recipient) - recipientBefore, TAKE_AMOUNT, "recipient not filled on Base");
    }

    /// @notice Round trip through the usePrevHookAmount path: the parent rewrites giveAmount to the
    ///         prev-hook output and rescales takeAmount by the same ratio; the cap validated the
    ///         prev-hook amount and the fill delivers the rescaled takeAmount.
    function test_Fork_RoundTrip_UsePrevHookAmount() public {
        vm.selectFork(ethFork);
        uint256 prevAmount = 600e6;
        deal(USDC_ETH, account, prevAmount);
        MockPrevHook prevHook = new MockPrevHook(prevAmount);

        bytes memory data = _encode(recipient, BASE_CHAIN_ID, GIVE_AMOUNT, USDC_ETH, TAKE_AMOUNT, nativeFee, true);

        // takeAmount rescales as takeAmount * prevAmount / giveAmount (parent's mulDiv).
        uint256 expectedTake = TAKE_AMOUNT * prevAmount / GIVE_AMOUNT;

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, BASE_CHAIN_ID, recipient, prevAmount))
        );
        vm.prank(account);
        hook.preExecute(address(prevHook), account, data);
        assertEq(registry.bridgedOut(account), prevAmount, "exposure not the prev-hook amount");

        uint256 recipientBefore = _baseBalanceOf(recipient);

        Execution[] memory execs = hook.build(address(prevHook), account, data);
        vm.recordLogs();
        vm.startPrank(account);
        IERC20(USDC_ETH).approve(DLN_SOURCE, prevAmount);
        (bool ok,) = execs[BRIDGE_EXECUTION_INDEX].target.call{ value: execs[BRIDGE_EXECUTION_INDEX].value }(
            execs[BRIDGE_EXECUTION_INDEX].callData
        );
        vm.stopPrank();
        assertTrue(ok, "real DLN source rejected the prev-amount createOrder");
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(IERC20(USDC_ETH).balanceOf(account), 0, "prev-amount giveToken not fully pulled");

        dlnHelper.help(DLN_SOURCE, DLN_DST, baseFork, uint256(BASE_CHAIN_ID), logs);

        vm.selectFork(baseFork);
        assertEq(
            IERC20(USDC_BASE).balanceOf(recipient) - recipientBefore, expectedTake, "recipient not filled rescaled"
        );
    }

    /// @notice A cap breach reverts in _preExecute, before any approval/order — no funds leave the
    ///         account and nothing reaches the DLN source.
    function test_Fork_CapBreachRevertsBeforeAnyOrder() public {
        vm.selectFork(ethFork);
        bytes memory data = _encode(recipient, BASE_CHAIN_ID, GIVE_AMOUNT, USDC_ETH, TAKE_AMOUNT, nativeFee, false);

        vm.mockCallRevert(
            address(capGuard),
            abi.encodeWithSelector(ICapGuardLike.validateAllocation.selector),
            abi.encodeWithSignature("CROSS_CHAIN_CAP_EXCEEDED()")
        );

        vm.prank(account);
        vm.expectRevert(abi.encodeWithSignature("CROSS_CHAIN_CAP_EXCEEDED()"));
        hook.preExecute(address(0), account, data);

        assertEq(registry.bridgedOut(account), 0, "no exposure should be recorded on a breach");
        assertEq(IERC20(USDC_ETH).balanceOf(account), GIVE_AMOUNT, "funds must not move on a breach");
    }

    function _baseBalanceOf(address who) internal returns (uint256 bal) {
        uint256 prev = vm.activeFork();
        vm.selectFork(baseFork);
        bal = IERC20(USDC_BASE).balanceOf(who);
        vm.selectFork(prev);
    }

    /// @dev Canonical deBridge hookData with empty destinationMessage (no external call). A
    ///      non-empty orderAuthorityAddressDst is required by the real DLN.
    function _encode(
        address receiverDst,
        uint256 takeChainId,
        uint256 giveAmount,
        address giveToken,
        uint256 takeAmount,
        uint256 value,
        bool usePrev
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory part1 = abi.encodePacked(
            bytes(new bytes(52)),
            usePrev,
            value,
            giveToken,
            giveAmount,
            uint8(0), // version
            address(0), // fallbackAddress
            address(0) // executorAddress
        );
        bytes memory part2 = abi.encodePacked(
            uint256(0), // executionFee
            false, // allowDelayedExecution
            false, // requireSuccessfulExecution
            uint256(0), // destinationMessage length (empty)
            abi.encodePacked(USDC_BASE).length, // takeTokenAddress length
            abi.encodePacked(USDC_BASE),
            takeAmount,
            takeChainId
        );
        bytes memory orderAuthority = abi.encodePacked(receiverDst);
        bytes memory part3 = abi.encodePacked(
            abi.encodePacked(receiverDst).length,
            abi.encodePacked(receiverDst),
            address(0), // givePatchAuthoritySrc
            orderAuthority.length,
            orderAuthority,
            uint256(0), // allowedTakerDst length
            uint256(0), // allowedCancelBeneficiarySrc length
            uint256(0), // affiliateFee length
            uint32(0) // referralCode
        );
        return bytes.concat(part1, part2, part3);
    }
}
