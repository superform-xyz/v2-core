// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { ISuperHook } from "../../../interfaces/ISuperHook.sol";
import { ISomelierCellarStaking } from "../../../interfaces/vendors/somelier/ISomelierCellarStaking.sol";

/// @title SomelierUnbondHook
/// @dev data has the following structure
/// @notice         address vault = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         uint256 depositId = BytesLib.toUint256(BytesLib.slice(data, 20, 32), 0);
contract SomelierUnbondHook is BaseHook, ISuperHook {
    constructor(address registry_, address author_) BaseHook(registry_, author_) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(address, bytes memory data) external pure override returns (Execution[] memory executions) {
        address vault = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        uint256 depositId = BytesLib.toUint256(BytesLib.slice(data, 20, 32), 0);

        if (vault == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] =
            Execution({ target: vault, value: 0, callData: abi.encodeCall(ISomelierCellarStaking.unbond, (depositId)) });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, bytes memory data) external view onlyExecutor { }

    /// @inheritdoc ISuperHook
    function postExecute(address, bytes memory data) external view onlyExecutor { }
}
