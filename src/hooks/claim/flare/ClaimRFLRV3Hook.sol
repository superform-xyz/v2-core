// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IRNat } from "../../../vendor/flare/IRNat.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";

/// @title ClaimRFLRV3Hook
/// @author Superform Labs
/// @notice Claims rFLR rewards from Flare's RNat contract using fully on-chain enumeration.
///         No offchain data packing needed -- the hook discovers claimable projects automatically.
/// @dev rFLR tokens are non-transferable, so fee collection is not supported at the claim stage.
///      Fees should be collected at the WFLR withdrawal stage via WithdrawRFLRHook.
/// @dev data has the following structure:
/// @notice         (empty -- this hook is parameterless and ignores calldata)
contract ClaimRFLRV3Hook is BaseHook {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error NO_CLAIMABLE_REWARDS();
    error TOO_MANY_PROJECTS();

    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The IRNat contract (also the rFLR ERC-20 token)
    address public immutable RNAT;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 private constant MAX_PROJECT_IDS = 200;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address rNat_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.CLAIM) {
        if (rNat_ == address(0)) revert ADDRESS_NOT_VALID();
        RNAT = rNat_;
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Claim RFLR V3";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Claims rFLR rewards from Flare's RNat contract with safe balance snapshot";
    }

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address account,
        bytes calldata
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        IRNat rNat = IRNat(RNAT);

        // 1. Get total project count and validate bounds
        uint256 projectCount = rNat.getProjectsCount();
        if (projectCount > MAX_PROJECT_IDS) revert TOO_MANY_PROJECTS();

        // 2. First pass: count claimable projects
        uint256 claimableCount;
        for (uint256 i; i < projectCount; ++i) {
            if (rNat.getClaimableRewards(i, account) > 0) {
                ++claimableCount;
            }
        }

        if (claimableCount == 0) revert NO_CLAIMABLE_REWARDS();

        // 3. Second pass: build projectIds array
        uint256[] memory projectIds = new uint256[](claimableCount);
        uint256 idx;
        for (uint256 i; i < projectCount; ++i) {
            if (rNat.getClaimableRewards(i, account) > 0) {
                projectIds[idx++] = i;
            }
        }

        // 4. Get current month for claiming (after validation to avoid unnecessary call)
        uint256 month = rNat.getCurrentMonth();

        // 5. Build single claim execution (no fee -- rFLR is non-transferable)
        executions = new Execution[](1);
        executions[0] = Execution({
            target: RNAT,
            value: 0,
            callData: abi.encodeCall(IRNat.claimRewards, (projectIds, month))
        });
    }

    /// @inheritdoc BaseHook
    function inspect(bytes calldata) external view override returns (bytes memory) {
        return abi.encodePacked(RNAT);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    /// @dev Reads the pre-claim rFLR balance for EXISTING accounts only.
    ///      When balanceOf succeeds (ok = true), we snapshot the balance so _postExecute
    ///      can compute the claimed delta.
    ///      When balanceOf reverts (ok = false = new account, no RNatAccount yet), we skip
    ///      _setOutAmount: transient storage defaults to 0, which is the correct pre-balance
    ///      for a brand-new account. _postExecute sets the full claimed amount after
    ///      claimRewards lazily creates the RNatAccount.
    function _preExecute(address, address account, bytes calldata) internal override {
        asset = RNAT;
        (bool ok, uint256 balance) = _snapshotRNatBalance(account);
        if (ok) {
            // Existing account: snapshot actual pre-balance for delta computation in _postExecute
            _setOutAmount(balance, account);
        }
        // New account (!ok): RNatAccount doesn't exist yet — leave outAmount at default 0
    }

    /// @inheritdoc BaseHook
    /// @dev outAmount is the rFLR delta (balance after claim minus balance before claim).
    ///      Safe staticcall used to handle any edge-case where the account still doesn't
    ///      exist post-execution (delta would be 0 — no revert noise).
    function _postExecute(address, address account, bytes calldata) internal override {
        (, uint256 currentBalance) = _snapshotRNatBalance(account);
        uint256 preBalance = getOutAmount(account);
        uint256 delta = currentBalance > preBalance ? currentBalance - preBalance : 0;
        _setOutAmount(delta, account);
    }

    /// @notice Safely reads the rFLR (RNat) balance of an account without reverting.
    /// @dev RNat.balanceOf reverts when no RNatAccount clone exists (created lazily on first
    ///      claimRewards call). Returning (false, 0) lets callers distinguish "no account yet"
    ///      from "account exists with 0 balance", which matters for _preExecute semantics.
    /// @param account The account whose balance to read
    /// @return ok      True if the account has an RNatAccount and the balance was readable
    /// @return balance The rFLR balance; 0 when ok is false
    function _snapshotRNatBalance(address account) internal view returns (bool ok, uint256 balance) {
        bytes memory data;
        (ok, data) = RNAT.staticcall(abi.encodeWithSelector(IERC20.balanceOf.selector, account));
        if (ok && data.length >= 32) {
            balance = abi.decode(data, (uint256));
        } else {
            ok = false;
        }
    }
}
