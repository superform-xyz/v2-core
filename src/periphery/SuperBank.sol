// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// External
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";

// Superform
import {ISuperBank} from "./interfaces/ISuperBank.sol";
import {ISuperGovernor, FeeType} from "./interfaces/ISuperGovernor.sol";
import {ISuperHook, Execution} from "../core/interfaces/ISuperHook.sol";
import {Bank} from "./Bank.sol";

/// @title SuperBank
/// @notice Compounds protocol revenue into UP and distributes it to sUP and treasury.
contract SuperBank is ISuperBank, Bank {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 private constant BPS_MAX = 10_000;
    ISuperGovernor public immutable SUPER_GOVERNOR;

    constructor(address superGovernor_) {
        if (superGovernor_ == address(0)) revert INVALID_ADDRESS();
        SUPER_GOVERNOR = ISuperGovernor(superGovernor_);
    }

    modifier onlyBankManager() {
        if (!IAccessControl(address(SUPER_GOVERNOR)).hasRole(SUPER_GOVERNOR.BANK_MANAGER_ROLE(), msg.sender)) {
            revert INVALID_BANK_MANAGER();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Receive function to accept direct ETH transfers if needed for hooks/executions
    receive() external payable {}

    /// @inheritdoc ISuperBank
    function distribute(uint256 upAmount_) external onlyBankManager {
        if (upAmount_ == 0) revert ZERO_LENGTH_ARRAY();

        // Get UP token address from SuperGovernor
        address upToken = SUPER_GOVERNOR.getAddress(SUPER_GOVERNOR.UP());
        address supToken = SUPER_GOVERNOR.getAddress(SUPER_GOVERNOR.SUP());
        address treasury = SUPER_GOVERNOR.getAddress(SUPER_GOVERNOR.TREASURY());

        // Get revenue share percentage from SuperGovernor
        uint256 revenueShare = SUPER_GOVERNOR.getFee(FeeType.REVENUE_SHARE);

        // Calculate amounts for sUP and Treasury
        uint256 supAmount = upAmount_.mulDiv(BPS_MAX, revenueShare);

        uint256 treasuryAmount = upAmount_ - supAmount;

        // Get the UP token instance
        IERC20 up = IERC20(upToken);

        // Ensure we have the tokens
        if (up.balanceOf(address(this)) < upAmount_) revert INVALID_UP_AMOUNT_TO_DISTRIBUTE();

        // Transfer tokens to sUP and Treasury
        if (supAmount > 0) {
            up.safeTransfer(supToken, supAmount);
        }

        if (treasuryAmount > 0) {
            up.safeTransfer(treasury, treasuryAmount);
        }

        emit RevenueDistributed(upToken, supToken, treasury, supAmount, treasuryAmount);
    }

    /// @inheritdoc ISuperBank
    function executeHooks(ISuperBank.HookExecutionData calldata executionData) external onlyBankManager {
        _executeHooks(executionData);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _getMerkleRootForHook(address hookAddress) internal view override returns (bytes32) {
        return SUPER_GOVERNOR.getSuperBankHookMerkleRoot(hookAddress);
    }
}
