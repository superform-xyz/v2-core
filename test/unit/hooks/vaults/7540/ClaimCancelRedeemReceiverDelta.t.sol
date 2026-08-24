// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { MockERC20 } from "test/mocks/MockERC20.sol";
import { Mock7540Vault } from "test/mocks/Mock7540Vault.sol";
import {
    ClaimCancelRedeemRequest7540Hook
} from "../../../../../src/hooks/vaults/7540/ClaimCancelRedeemRequest7540Hook.sol";
import {
    ClaimCancelRedeemRequestWithId7540Hook
} from "../../../../../src/hooks/vaults/7540/ClaimCancelRedeemRequestWithId7540Hook.sol";

/// @title ClaimCancelRedeemReceiverDelta
/// @notice Regression tests for the cross-address snapshot bug in the ERC-7540 cancel-redeem claim
///         hooks. Before the fix, `_preExecute` snapshotted the ACCOUNT's share balance while
///         `_postExecute` measured the RECEIVER's, publishing `receiverBalance + claimed -
///         accountBalance`. A receiver != account could inflate its own pre-balance (moving
///         already-owned shares in) to over-report the claim by exactly `R - A`, which a downstream
///         usePrevHookAmount consumer (e.g. TransferERC20Hook) would then move out of the account.
///         The fix measures the receiver on both sides so the reported amount is exactly the
///         claimed shares regardless of the receiver's pre-existing balance.
contract ClaimCancelRedeemReceiverDeltaTest is Test {
    ClaimCancelRedeemRequest7540Hook internal hook;
    ClaimCancelRedeemRequestWithId7540Hook internal hookWithId;
    Mock7540Vault internal vault;
    MockERC20 internal share;

    bytes32 internal constant ORACLE_ID = keccak256("ORACLE_ID");

    // The hook's pre/post entrypoints require msg.sender == account, so the test contract is the
    // account (matching the existing 7540 hook tests); the receiver is a distinct address.
    address internal account;
    address internal receiver = makeAddr("receiver");

    function setUp() public {
        account = address(this);
        vault = new Mock7540Vault(MockERC20(address(0)), "Asset", "AST");
        share = vault.shareToken();
        hook = new ClaimCancelRedeemRequest7540Hook();
        hookWithId = new ClaimCancelRedeemRequestWithId7540Hook();
    }

    /// @dev data layout: bytes32 placeholder0 | address yieldSource | address receiver
    function _encodeData(address receiver_) internal view returns (bytes memory) {
        return abi.encodePacked(ORACLE_ID, address(vault), receiver_);
    }

    /// @dev Drives pre -> (simulated claim delivers `claimed` shares to `receiver`) -> post and
    ///      returns the amount the hook reports for `account`.
    function _runClaim(
        address hookAddr,
        address receiver_,
        uint256 accountPreBalance,
        uint256 receiverPreBalance,
        uint256 claimed
    )
        internal
        returns (uint256 reported, address reportedToken)
    {
        share.mint(account, accountPreBalance);
        share.mint(receiver_, receiverPreBalance);

        bytes memory data = _encodeData(receiver_);

        ClaimCancelRedeemRequest7540Hook h = ClaimCancelRedeemRequest7540Hook(hookAddr);
        h.preExecute(address(0), account, data);
        // Simulate the ERC-7540 claim: shares are delivered to `receiver`.
        share.mint(receiver_, claimed);
        h.postExecute(address(0), account, data);

        reported = h.getOutAmount(account);
        reportedToken = h.getOutToken(account);
    }

    /*//////////////////////////////////////////////////////////////
                    RECEIVER == ACCOUNT (was accidentally correct)
    //////////////////////////////////////////////////////////////*/

    function test_reportsClaimedAmount_whenReceiverIsAccount() public {
        // receiver == account: pass the account's balance via accountPreBalance only (avoid
        // double-minting to the same address). Reported amount is the 10e18 claim.
        (uint256 reported, address tok) = _runClaim(address(hook), account, 100e18, 0, 10e18);
        assertEq(reported, 10e18);
        assertEq(tok, address(share));
    }

    /*//////////////////////////////////////////////////////////////
        RECEIVER != ACCOUNT WITH INFLATED PRE-BALANCE (the exploit)
    //////////////////////////////////////////////////////////////*/

    function test_receiverPreBalanceCannotInflateReport() public {
        // Account holds 100, receiver holds a large pre-existing 90 + would-be-inflated stash.
        // Legitimate claim is 10. Pre-fix the hook reported R + C - A = 190 + 10 - 100 = 100.
        // After the fix it must report exactly the claimed 10.
        (uint256 reported, address tok) = _runClaim(address(hook), receiver, 100e18, 190e18, 10e18);
        assertEq(reported, 10e18, "must report only the claimed shares, not receiver pre-balance");
        assertEq(tok, address(share), "outToken must be the share token, not the unset asset");
    }

    function test_receiverPreBalanceCannotInflateReport_withId() public {
        (uint256 reported, address tok) = _runClaim(address(hookWithId), receiver, 100e18, 190e18, 10e18);
        assertEq(reported, 10e18);
        assertEq(tok, address(share));
    }

    /// @dev The pre-fix formula R + C - A was attacker-tunable to any target via R. Verify the
    ///      report is invariant to R across a fuzzed range.
    function testFuzz_reportInvariantToReceiverPreBalance(uint256 receiverPre, uint256 claimed) public {
        receiverPre = bound(receiverPre, 0, 1e30);
        claimed = bound(claimed, 1, 1e30);
        (uint256 reported,) = _runClaim(address(hook), receiver, 500e18, receiverPre, claimed);
        assertEq(reported, claimed);
    }

    /// @dev outToken must never be the zero address (the pre-fix `asset` was uninitialized).
    function test_outTokenIsShareToken_notZero() public {
        (, address tok) = _runClaim(address(hookWithId), receiver, 1e18, 5e18, 2e18);
        assertTrue(tok != address(0));
        assertEq(tok, address(share));
    }
}
