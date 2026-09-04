// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import {
    SuperVaultDeBridgeCapBridgeHook
} from "../../../src/hooks/bridges/debridge/SuperVaultDeBridgeCapBridgeHook.sol";
import { IDlnSource } from "../../../src/vendor/bridges/debridge/IDlnSource.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import {
    ICapGuardLike,
    MockCapGuard,
    MockPositionRegistry,
    MockGovernorAddressBook,
    MockPrevHook,
    CapMessageLib
} from "../../unit/hooks/bridges/CapBridgeTestUtils.sol";

contract MockDeBridgeSignatureStorage {
    function retrieveSignatureData(address) external view returns (bytes memory) {
        uint48 validUntil = uint48(block.timestamp + 3600);
        bytes32[] memory proofSrc = new bytes32[](1);
        proofSrc[0] = keccak256("src1");
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        return abi.encode(new uint64[](0), validUntil, 0, keccak256("root"), proofSrc, proofDst, hex"abcdef");
    }
}

/// @title SuperVaultDeBridgeCapBridgeHookFork
/// @notice Fork test of the B1-hardened deBridge cap hook against the REAL mainnet DLN source: the
///         cap binds to the ECONOMIC vault decoded from the external-call payload (never the
///         transport receiverDst); receiverDst and the envelope executorAddress must both be the
///         approved destination adapter; the fallback is the hub account; and the real DLN source
///         accepts the createOrder carrying that envelope. A raw order (no external call) is no
///         longer expressible. (Destination external-call execution — adapter ->
///         SuperDestinationExecutor -> vault shares — is exercised in the unit typed-action suite
///         and the Across fork fill; deBridge's DlnExternalCallAdapter execution is the
///         destination stack's own e2e.)
contract SuperVaultDeBridgeCapBridgeHookFork is Test {
    // Real deBridge DLN source (same address on every chain).
    address internal constant DLN_SOURCE = 0xeF4fB24aD0916217251F553c0596F8Edc630EB66;

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

    SuperVaultDeBridgeCapBridgeHook internal hook;
    MockCapGuard internal capGuard;
    MockPositionRegistry internal registry;
    MockGovernorAddressBook internal governor;
    MockDeBridgeSignatureStorage internal validator;

    address internal account = makeAddr("strategy");
    address internal adapter = makeAddr("debridgeAdapter"); // transport receiver + ext-call executor
    address internal destVault = makeAddr("destinationVault"); // economic destination (B1)
    address internal dstApproveHook = makeAddr("dstApproveHook");
    address internal dstDepositHook = makeAddr("dstDepositHook");

    uint256 internal nativeFee;

    function setUp() public {
        ethFork = vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"), 23_096_042);

        capGuard = new MockCapGuard();
        registry = new MockPositionRegistry();
        governor = new MockGovernorAddressBook(address(capGuard), address(registry));
        validator = new MockDeBridgeSignatureStorage();
        hook = new SuperVaultDeBridgeCapBridgeHook(DLN_SOURCE, address(validator), address(governor));
        hook.setExecutionContext(account);

        // B1 destination policy.
        capGuard.setApprovedAdapter(BASE_CHAIN_ID, adapter, true);
        capGuard.setDestinationHooks(BASE_CHAIN_ID, dstApproveHook, dstDepositHook);

        nativeFee = IDlnSource(DLN_SOURCE).globalFixedNativeFee();
        deal(USDC_ETH, account, GIVE_AMOUNT);
        vm.deal(account, nativeFee);
    }

    /// @dev R2-B1: the action amount must equal the delivery minimum for the encoded giveAmount.
    function _depositMessage(uint256 giveAmount) internal view returns (bytes memory) {
        return CapMessageLib.vaultDepositMessage(
            account, dstApproveHook, dstDepositHook, destVault, USDC_BASE, TAKE_AMOUNT * giveAmount / GIVE_AMOUNT
        );
    }

    /// @notice Cap enforced against the ECONOMIC vault; the real DLN source accepts the createOrder
    ///         carrying the external-call envelope (adapter executor, hub-account fallback).
    function test_Fork_CapEnforcedThenRealOrderCreatedWithExternalCall() public {
        bytes memory data = _encode(BASE_CHAIN_ID, GIVE_AMOUNT, nativeFee, false, _depositMessage(GIVE_AMOUNT));

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, BASE_CHAIN_ID, destVault, GIVE_AMOUNT))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);

        assertEq(registry.bridgedOut(account), GIVE_AMOUNT, "in-flight exposure not recorded");
        assertEq(registry.bridgedOutByChain(account, BASE_CHAIN_ID), GIVE_AMOUNT, "per-chain exposure not recorded");
        assertEq(registry.lastVault(), destVault, "reservation must carry the economic vault");

        Execution[] memory execs = hook.build(address(0), account, data);
        assertEq(execs[BRIDGE_EXECUTION_INDEX].target, DLN_SOURCE, "bridge target is not the DLN source");

        vm.startPrank(account);
        IERC20(USDC_ETH).approve(DLN_SOURCE, GIVE_AMOUNT);
        (bool ok,) = execs[BRIDGE_EXECUTION_INDEX].target.call{ value: execs[BRIDGE_EXECUTION_INDEX].value }(
            execs[BRIDGE_EXECUTION_INDEX].callData
        );
        vm.stopPrank();
        assertTrue(ok, "real DLN source rejected the external-call order");
        assertEq(IERC20(USDC_ETH).balanceOf(account), 0, "giveToken not pulled by DLN source");
    }

    /// @notice usePrevHookAmount path: the cap validates the prev-hook amount that actually leaves.
    function test_Fork_UsePrevHookAmount_SourceSide() public {
        uint256 prevAmount = 600e6;
        deal(USDC_ETH, account, prevAmount);
        MockPrevHook prevHook = new MockPrevHook(prevAmount);
        bytes memory data = _encode(BASE_CHAIN_ID, GIVE_AMOUNT, nativeFee, true, _depositMessage(prevAmount));

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, BASE_CHAIN_ID, destVault, prevAmount))
        );
        vm.prank(account);
        hook.preExecute(address(prevHook), account, data);
        assertEq(registry.bridgedOut(account), prevAmount, "exposure not the prev-hook amount");

        Execution[] memory execs = hook.build(address(prevHook), account, data);
        vm.startPrank(account);
        IERC20(USDC_ETH).approve(DLN_SOURCE, prevAmount);
        (bool ok,) = execs[BRIDGE_EXECUTION_INDEX].target.call{ value: execs[BRIDGE_EXECUTION_INDEX].value }(
            execs[BRIDGE_EXECUTION_INDEX].callData
        );
        vm.stopPrank();
        assertTrue(ok, "real DLN source rejected the prev-amount order");
        assertEq(IERC20(USDC_ETH).balanceOf(account), 0, "prev-amount input not fully pulled");
    }

    /// @notice A cap breach reverts in _preExecute, before any order.
    function test_Fork_CapBreachRevertsBeforeAnyOrder() public {
        bytes memory data = _encode(BASE_CHAIN_ID, GIVE_AMOUNT, nativeFee, false, _depositMessage(GIVE_AMOUNT));

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

    /// @notice B1: an order with no external call (raw transfer to receiverDst) is rejected.
    function test_Fork_RevertIf_NoExternalCall() public {
        bytes memory data = _encode(BASE_CHAIN_ID, GIVE_AMOUNT, nativeFee, false, bytes(""));
        vm.prank(account);
        vm.expectRevert(); // DESTINATION_ACTION_NOT_VALID
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), 0, "recorded despite raw-transfer order");
    }

    /// @notice B1: an unapproved receiverDst is rejected.
    function test_Fork_RevertIf_ReceiverNotApprovedAdapter() public {
        capGuard.setApprovedAdapter(BASE_CHAIN_ID, adapter, false);
        bytes memory data = _encode(BASE_CHAIN_ID, GIVE_AMOUNT, nativeFee, false, _depositMessage(GIVE_AMOUNT));
        vm.prank(account);
        vm.expectRevert(); // TRANSPORT_ADAPTER_NOT_APPROVED
        hook.preExecute(address(0), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Canonical deBridge hookData. receiverDst == envelope executorAddress == the approved
    ///      adapter; fallbackAddress == the hub account; non-empty orderAuthorityAddressDst is
    ///      required by the real DLN.
    function _encode(
        uint256 takeChainId,
        uint256 giveAmount,
        uint256 value,
        bool usePrev,
        bytes memory destinationMessage
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory part1 = abi.encodePacked(
            bytes(new bytes(52)),
            usePrev,
            value,
            USDC_ETH, // giveToken
            giveAmount,
            uint8(1), // version
            account, // fallbackAddress = hub account
            adapter // executorAddress = the approved adapter
        );
        bytes memory part2 = abi.encodePacked(
            uint256(0), // executionFee
            true, // allowDelayedExecution
            true, // requireSuccessfulExecution
            destinationMessage.length,
            destinationMessage,
            abi.encodePacked(USDC_BASE).length, // takeTokenAddress length
            abi.encodePacked(USDC_BASE),
            TAKE_AMOUNT,
            takeChainId
        );
        bytes memory orderAuthority = abi.encodePacked(adapter);
        bytes memory part3 = abi.encodePacked(
            abi.encodePacked(adapter).length, // receiverDst length (20)
            abi.encodePacked(adapter), // receiverDst = the approved adapter
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
