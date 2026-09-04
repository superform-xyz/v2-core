// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { DebridgeAdapter } from "../../../src/adapters/DebridgeAdapter.sol";
import {
    SuperVaultDeBridgeCapBridgeHook
} from "../../../src/hooks/bridges/debridge/SuperVaultDeBridgeCapBridgeHook.sol";

import { Mock4626Vault } from "../../mocks/Mock4626Vault.sol";
import { CrossChainSuperVaultDestinationE2EBase } from "./CrossChainSuperVaultDestinationE2EBase.sol";

/// @dev Minimal DlnDestination stand-in: the adapter only reads `externalCallAdapter` from it.
contract MockDlnDestination {
    address public externalCallAdapter;

    constructor(address externalCallAdapter_) {
        externalCallAdapter = externalCallAdapter_;
    }
}

/// @title CrossChainSuperVaultDestinationDeBridgeE2E
/// @notice The "full remote lifecycle" e2e over the DEBRIDGE transport, with the REAL destination
///         stack: deBridge's external-call adapter hands funds + payload to DebridgeAdapter
///         (`onERC20Received`), which forwards to SuperDestinationExecutor -> validated owner
///         signature -> real approve+deposit ON the hub-controlled account -> shares minted. The
///         payload is byte-identical to the typed destination action the
///         SuperVaultDeBridgeCapBridgeHook validated hub-side (receiverDst == envelope executor ==
///         this adapter; fallback == the account).
contract CrossChainSuperVaultDestinationDeBridgeE2E is CrossChainSuperVaultDestinationE2EBase {
    DebridgeAdapter internal adapter;
    SuperVaultDeBridgeCapBridgeHook internal capHook;
    MockDlnDestination internal dlnDestination;

    address internal dlnSource = makeAddr("dlnSource");
    address internal externalCallAdapter = makeAddr("dlnExternalCallAdapter");

    function setUp() public {
        _setUpDestinationStack();

        dlnDestination = new MockDlnDestination(externalCallAdapter);
        adapter = new DebridgeAdapter(address(dlnDestination), address(executor));
        capHook = new SuperVaultDeBridgeCapBridgeHook(dlnSource, address(hubValidator), address(governor));
        capHook.setExecutionContext(address(account));
        capGuard.setApprovedAdapter(chainId, address(adapter), true);
    }

    /*//////////////////////////////////////////////////////////////
                        FULL REMOTE LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    function test_E2E_DeBridge_CapValidatedDepositMintsSharesToAccount() public {
        bytes memory executorCalldata = _depositExecutorCalldata(address(vault));

        // 1. HUB SIDE: the cap hook validates the order + external-call envelope + typed action.
        vm.prank(address(account));
        capHook.preExecute(address(0), address(account), _hubData(_message5(executorCalldata)));
        assertEq(positionRegistry.lastVault(), address(vault), "cap must reserve against the economic vault");
        assertEq(positionRegistry.bridgedOut(address(account)), AMOUNT, "in-flight reservation not recorded");

        // 2. OWNER SIGNATURE over the real destination leaf.
        (bytes32 root, bytes memory sigData) = _signDestination(executorCalldata);

        // 3. DESTINATION: deBridge's external-call adapter delivers funds + payload.
        token.mint(address(adapter), AMOUNT);
        vm.prank(externalCallAdapter);
        adapter.onERC20Received(
            keccak256("orderId"), address(token), AMOUNT, address(account), _message6(executorCalldata, sigData)
        );

        // 4. The position exists as SHARES owned by the hub-controlled account.
        _assertSharesMinted(root, address(adapter));
    }

    /// @notice Mutating only the vault after signing fails destination signature validation
    ///         (deBridge adapter propagates the executor revert).
    function test_E2E_DeBridge_MutatedVaultFailsDestinationSignature() public {
        (, bytes memory sigData) = _signDestination(_depositExecutorCalldata(address(vault)));

        Mock4626Vault rogueVault = new Mock4626Vault(address(token), "Rogue", "RGV");
        bytes memory mutatedCalldata = _depositExecutorCalldata(address(rogueVault));

        token.mint(address(adapter), AMOUNT);
        vm.prank(externalCallAdapter);
        vm.expectRevert(); // INVALID_PROOF inside the executor
        adapter.onERC20Received(
            keccak256("orderId"), address(token), AMOUNT, address(account), _message6(mutatedCalldata, sigData)
        );

        assertEq(vault.balanceOf(address(account)), 0, "no shares may exist");
        assertEq(rogueVault.balanceOf(address(account)), 0, "mutated action must not execute");
    }

    /// @notice Only deBridge's external-call adapter may deliver — a rogue caller is rejected.
    function test_E2E_DeBridge_RevertIf_CallerNotExternalCallAdapter() public {
        bytes memory executorCalldata = _depositExecutorCalldata(address(vault));
        (, bytes memory sigData) = _signDestination(executorCalldata);

        token.mint(address(adapter), AMOUNT);
        vm.prank(makeAddr("rogueCaller"));
        vm.expectRevert(DebridgeAdapter.ONLY_EXTERNAL_CALL_ADAPTER.selector);
        adapter.onERC20Received(
            keccak256("orderId"), address(token), AMOUNT, address(account), _message6(executorCalldata, sigData)
        );
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Canonical deBridge hookData wrapping `message` (hub-side cap-hook input):
    ///      receiverDst == envelope executorAddress == the adapter; fallback == the account.
    function _hubData(bytes memory message) internal view returns (bytes memory) {
        bytes memory part1 = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte strategy header
            false, // usePrevHookAmount
            uint256(0), // value
            address(token), // giveToken
            AMOUNT, // giveAmount
            uint8(1), // version
            address(account), // fallbackAddress = hub account
            address(adapter) // executorAddress = the approved adapter
        );
        bytes memory part2 = abi.encodePacked(
            uint256(0), // executionFee
            false, // allowDelayedExecution (R3-RF2: pinned)
            true, // requireSuccessfulExecution
            message.length,
            message,
            uint256(20), // takeTokenAddress length
            abi.encodePacked(address(token)),
            AMOUNT, // takeAmount
            uint256(chainId) // takeChainId
        );
        bytes memory orderAuthority = abi.encodePacked(address(account)); // P1: pinned to the hub account
        bytes memory cancelBeneficiary = abi.encodePacked(address(account)); // P1: refunds only to the hub account
        bytes memory part3 = abi.encodePacked(
            uint256(20), // receiverDst length
            abi.encodePacked(address(adapter)), // receiverDst = the approved adapter
            address(0), // givePatchAuthoritySrc
            orderAuthority.length,
            orderAuthority,
            uint256(0), // allowedTakerDst length
            cancelBeneficiary.length,
            cancelBeneficiary,
            uint256(0), // affiliateFee length
            uint32(0) // referralCode
        );
        return bytes.concat(part1, part2, part3);
    }
}
