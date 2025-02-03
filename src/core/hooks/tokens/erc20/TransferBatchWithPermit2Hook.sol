// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";

import { ISuperHook, ISuperHookResult } from "../../../interfaces/ISuperHook.sol";
import { IPermit2Batch } from "../../../interfaces/vendors/uniswap/permit2/IPermit2Batch.sol";
import { IAllowanceTransfer } from "../../../interfaces/vendors/uniswap/permit2/IAllowanceTransfer.sol";

/// @title TransferBatchWithPermit2Hook
/// @dev data has the following structure
/// @notice         bool usePrevHookAmount = _decodeBool(data, 0);
/// @notice         uint256 indexOfAmount = BytesLib.toUint256(BytesLib.slice(data, 1, 32), 0);
/// @notice         uint256 transferDetailsLength = BytesLib.toUint256(BytesLib.slice(data, 33, 32), 0);
/// @notice         IAllowanceTransfer.AllowanceTransferDetails[] transferDetails - Array of transfer details, each containing:
/// @notice             address from = BytesLib.toAddress(BytesLib.slice(data, offset, 20), 0);
/// @notice             address to = BytesLib.toAddress(BytesLib.slice(data, offset + 20, 20), 0);
/// @notice             uint160 amount = uint160(BytesLib.toUint256(BytesLib.slice(data, offset + 40, 32), 0));
/// @notice             address token = BytesLib.toAddress(BytesLib.slice(data, offset + 72, 20), 0);
/// @notice         If usePrevHookAmount is true, transferDetails[indexOfAmount].amount is set to ISuperHookResult(prevHook).outAmount().toUint160()
contract TransferBatchWithPermit2Hook is BaseHook, ISuperHook {
    using SafeCast for uint256;
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public permit2;

    constructor(address registry_, address author_, address permit2_) BaseHook(registry_, author_, HookType.NONACCOUNTING) {
        if (permit2_ == address(0)) revert ADDRESS_NOT_VALID();
        permit2 = permit2_;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
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
        bool usePrevHookAmount = _decodeBool(data, 0);
        uint256 indexOfAmount = BytesLib.toUint256(BytesLib.slice(data, 1, 32), 0);

        uint256 offset = 33;
        uint256 transferDetailsLength = BytesLib.toUint256(BytesLib.slice(data, offset, 32), 0);
        offset += 32;

        IAllowanceTransfer.AllowanceTransferDetails[] memory transferDetails = new IAllowanceTransfer.AllowanceTransferDetails[](transferDetailsLength);
        for (uint256 i = 0; i < transferDetailsLength; i++) {
            transferDetails[i].from = BytesLib.toAddress(BytesLib.slice(data, offset, 20), 0);
            offset += 20;
            
            transferDetails[i].to = BytesLib.toAddress(BytesLib.slice(data, offset, 20), 0);
            offset += 20;
            
            transferDetails[i].amount = uint160(BytesLib.toUint256(BytesLib.slice(data, offset, 32), 0));
            offset += 32;
            
            transferDetails[i].token = BytesLib.toAddress(BytesLib.slice(data, offset, 20), 0);
            offset += 20;
        }

        if (usePrevHookAmount) {
            transferDetails[indexOfAmount].amount = ISuperHookResult(prevHook).outAmount().toUint160();
        }

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(permit2),
            value: 0,
            callData: abi.encodeCall(IPermit2Batch.transferFrom, (transferDetails))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, address, bytes memory data) external {
        outAmount = _getBalance(data);
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, address, bytes memory data) external {
        outAmount = _getBalance(data) - outAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(bytes memory data) private view returns (uint256) {
        (, uint256 indexOfAmount, IAllowanceTransfer.AllowanceTransferDetails[] memory transferDetails) =
            abi.decode(data, (bool, uint256, IAllowanceTransfer.AllowanceTransferDetails[]));

        return IERC20(transferDetails[indexOfAmount].token).balanceOf(transferDetails[indexOfAmount].to);
    }
}
