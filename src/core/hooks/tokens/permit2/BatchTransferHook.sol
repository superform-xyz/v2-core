// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IPermit2Batch } from "../../../../vendor/uniswap/permit2/IPermit2Batch.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IAllowanceTransfer } from "../../../../vendor/uniswap/permit2/IAllowanceTransfer.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookResult, ISuperHookContextAware } from "../../../interfaces/ISuperHook.sol";

/// @title BatchTransferHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address to = BytesLib.toAddress(data, 20);
/// @notice         uint256 amount = BytesLib.toUint256(data, 40);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 72);
contract BatchTransferHook is BaseHook, ISuperHookContextAware {
    using SafeCast for uint256;

    error INSUFFICIENT_APPROVAL();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public permit2;

    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 72;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address permit2_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.TOKEN) {
        if (permit2_ == address(0)) revert ADDRESS_NOT_VALID();
        permit2 = permit2_;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function build(
        address prevHook,
        address,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        address token = BytesLib.toAddress(data, 0);
        address to = BytesLib.toAddress(data, 20);
        uint256 amount = BytesLib.toUint256(data, 40);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).outAmount();
        }

        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (token == address(0)) revert ADDRESS_NOT_VALID();

        // @dev no-revert-on-failure tokens are not supported
        executions = new Execution[](1);
        executions[0] = Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.transfer, (to, amount)) });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address, bytes calldata data) internal override {
        outAmount = _getBalance(data);
    }

    function _postExecute(address, address, bytes calldata data) internal override {
        outAmount = _getBalance(data) - outAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(bytes memory data) private view returns (uint256) {
        address token = BytesLib.toAddress(data, 0);
        address to = BytesLib.toAddress(data, 20);
        return IERC20(token).balanceOf(to);
    }
}