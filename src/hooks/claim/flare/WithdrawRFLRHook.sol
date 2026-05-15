// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IRNat } from "../../../vendor/flare/IRNat.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";

/// @title WithdrawRFLRHook
/// @author Superform Labs
/// @notice Withdraws all rFLR from RNat and receives WFLR. WARNING: 50% penalty applies
///         to any locked (unvested) portion. Only fully-vested rFLR is penalty-free.
/// @dev Calls IRNat.withdrawAll(true) to receive WFLR (wrapped FLR) instead of native FLR.
///      The penalty is enforced by the RNat contract and cannot be bypassed.
///      data has the following structure:
///      (no user-provided data -- all parameters are immutables or hardcoded)
contract WithdrawRFLRHook is BaseHook {
    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The IRNat contract
    address public immutable RNAT;

    /// @notice The WFLR (wrapped FLR) ERC-20 token
    address public immutable WFLR;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address rNat_, address wflr_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.CLAIM) {
        if (rNat_ == address(0) || wflr_ == address(0)) revert ADDRESS_NOT_VALID();
        RNAT = rNat_;
        WFLR = wflr_;
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address,
        bytes calldata
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        executions = new Execution[](1);
        executions[0] = Execution({
            target: RNAT,
            value: 0,
            callData: abi.encodeCall(IRNat.withdrawAll, (true))
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
    /// @dev Snapshots the WFLR balance before withdrawal execution
    function _preExecute(address, address account, bytes calldata) internal override {
        asset = WFLR;
        _setOutAmount(IERC20(WFLR).balanceOf(account), account);
    }

    /// @inheritdoc BaseHook
    /// @dev outAmount is the WFLR delta (balance after withdrawal minus balance before withdrawal)
    function _postExecute(address, address account, bytes calldata) internal override {
        uint256 currentBalance = IERC20(WFLR).balanceOf(account);
        uint256 preBalance = getOutAmount(account);
        uint256 delta = currentBalance > preBalance ? currentBalance - preBalance : 0;
        _setOutAmount(delta, account);
    }
}
