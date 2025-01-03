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

contract TransferBatchWithPermit2Hook is BaseHook, ISuperHook {
    using SafeCast for uint256;
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public permit2;

    constructor(address registry_, address author_, address permit2_) BaseHook(registry_, author_) {
        if (permit2_ == address(0)) revert ADDRESS_NOT_VALID();
        permit2 = permit2_;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(
        address prevHook,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        //TODO: use BytesLib to decode data
        (
            bool usePrevHookAmount,
            uint256 indexOfAmount,
            IAllowanceTransfer.AllowanceTransferDetails[] memory transferDetails
        ) = abi.decode(data, (bool, uint256, IAllowanceTransfer.AllowanceTransferDetails[]));

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
    function preExecute(address, bytes memory data) external {
        outAmount = _getBalance(data);
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, bytes memory data) external {
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
