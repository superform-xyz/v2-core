// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { AcrossV3Adapter } from "../../../src/adapters/AcrossV3Adapter.sol";
import { SuperVaultAcrossCapBridgeHook } from "../../../src/hooks/bridges/across/SuperVaultAcrossCapBridgeHook.sol";
import { SuperVaultCapBridgeCommon } from "../../../src/hooks/bridges/SuperVaultCapBridgeCommon.sol";

import { Mock4626Vault } from "../../mocks/Mock4626Vault.sol";
import { CapMessageLib } from "../hooks/bridges/CapBridgeTestUtils.sol";
import { CrossChainSuperVaultDestinationE2EBase } from "./CrossChainSuperVaultDestinationE2EBase.sol";

/// @title CrossChainSuperVaultDestinationE2E (Across)
/// @notice The "full remote lifecycle" leg of the PR #336 review test matrix over the ACROSS
///         transport, with the REAL destination stack: AcrossV3Adapter ->
///         SuperDestinationExecutor -> SuperDestinationValidator -> real approve+deposit ON the
///         hub-controlled account -> ERC4626 SHARES MINTED TO THE ACCOUNT. The delivered message
///         is byte-identical to the typed destination action the SuperVaultAcrossCapBridgeHook
///         validated hub-side; a mutated action (different vault) fails BOTH hub-side and
///         destination-side.
contract CrossChainSuperVaultDestinationE2E is CrossChainSuperVaultDestinationE2EBase {
    AcrossV3Adapter internal adapter;
    SuperVaultAcrossCapBridgeHook internal capHook;
    address internal spokePool = makeAddr("spokePool");

    function setUp() public {
        _setUpDestinationStack();

        adapter = new AcrossV3Adapter(spokePool, address(executor));
        capHook = new SuperVaultAcrossCapBridgeHook(spokePool, address(hubValidator), address(governor));
        capHook.setExecutionContext(address(account));
        capGuard.setApprovedAdapter(chainId, address(adapter), true);
    }

    /*//////////////////////////////////////////////////////////////
                        FULL REMOTE LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    /// @notice RR1/RR5: bridge message -> adapter -> executor -> validated signature -> real
    ///         approve+deposit on the account -> vault SHARES owned by the hub-controlled account
    ///         — and the exact same message passed the hub-side cap hook first.
    function test_E2E_CapValidatedDepositMintsSharesToAccount() public {
        bytes memory executorCalldata = _depositExecutorCalldata(address(vault));

        // 1. HUB SIDE: the cap hook validates this exact destination action — economic vault, not
        //    the transport adapter — and mints the reservation for it.
        vm.prank(address(account));
        capHook.preExecute(address(0), address(account), _hubData(_message5(executorCalldata)));
        assertEq(positionRegistry.lastVault(), address(vault), "cap must reserve against the economic vault");
        assertEq(positionRegistry.bridgedOut(address(account)), AMOUNT, "in-flight reservation not recorded");

        // 2. OWNER SIGNATURE over the real destination leaf (single-leaf tree: root == leaf).
        (bytes32 root, bytes memory sigData) = _signDestination(executorCalldata);

        // 3. DESTINATION: Across fill delivers funds + message to the adapter (transport hop),
        //    which forwards to the executor.
        token.mint(address(adapter), AMOUNT);
        vm.prank(spokePool);
        adapter.handleV3AcrossMessage(address(token), AMOUNT, makeAddr("relayer"), _message6(executorCalldata, sigData));

        // 4. The position exists as SHARES owned by the hub-controlled account.
        _assertSharesMinted(root, address(adapter));
    }

    /// @notice B1.RR2 destination leg: mutating ONLY the vault inside the executor calldata after
    ///         signing must fail destination signature validation.
    function test_E2E_MutatedVaultFailsDestinationSignature() public {
        (, bytes memory sigData) = _signDestination(_depositExecutorCalldata(address(vault)));

        // Attacker swaps the destination action for a different vault, keeping the valid signature.
        Mock4626Vault rogueVault = new Mock4626Vault(address(token), "Rogue", "RGV");
        bytes memory mutatedCalldata = _depositExecutorCalldata(address(rogueVault));

        token.mint(address(adapter), AMOUNT);
        vm.prank(spokePool);
        vm.expectRevert(); // INVALID_PROOF: the leaf no longer opens against the signed root
        adapter.handleV3AcrossMessage(address(token), AMOUNT, makeAddr("relayer"), _message6(mutatedCalldata, sigData));

        assertEq(vault.balanceOf(address(account)), 0, "no shares may exist");
        assertEq(rogueVault.balanceOf(address(account)), 0, "mutated action must not execute");
    }

    /// @notice B1.RR2 hub leg on the same fixture: the mutated action never leaves the hub either.
    function test_E2E_MutatedVaultRejectedByCapHook() public {
        Mock4626Vault rogueVault = new Mock4626Vault(address(token), "Rogue", "RGV");
        // Approve spender still the approved vault, deposit target swapped -> spender/vault
        // mismatch is caught by the typed-action decode.
        address[] memory hooks = new address[](2);
        hooks[0] = address(approveHook);
        hooks[1] = address(depositHook);
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = CapMessageLib.approveHookData(address(token), address(vault), AMOUNT);
        hooksData[1] = CapMessageLib.depositHookData(address(rogueVault), AMOUNT);
        bytes memory message = _message5Custom(CapMessageLib.executorCalldataFor(hooks, hooksData));

        vm.prank(address(account));
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_ACTION_NOT_VALID.selector);
        capHook.preExecute(address(0), address(account), _hubData(message));
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _message5Custom(bytes memory executorCalldata) internal view returns (bytes memory) {
        return _message5(executorCalldata);
    }

    /// @dev Across ApproveAnd hookData wrapping `message` (hub-side cap-hook input).
    function _hubData(bytes memory message) internal view returns (bytes memory) {
        bytes memory header = abi.encodePacked(
            bytes(new bytes(52)),
            uint256(0), // value
            address(adapter), // recipient = transport adapter
            address(token), // inputToken
            address(token), // outputToken
            AMOUNT,
            AMOUNT
        );
        return abi.encodePacked(
            header,
            uint256(chainId), // destinationChainId
            address(0), // exclusiveRelayer
            uint32(3600),
            uint32(0),
            false, // usePrevHookAmount
            message
        );
    }
}
