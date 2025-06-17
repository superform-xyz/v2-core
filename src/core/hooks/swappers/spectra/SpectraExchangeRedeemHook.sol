// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { BytesLib } from "../../../../vendor/BytesLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISpectraRouter } from "../../../../vendor/spectra/ISpectraRouter.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";
import { SpectraCommands } from "../../../../vendor/spectra/SpectraCommands.sol";

/// @title SpectraExchangeDepositHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes4 placeholder = bytes4(BytesLib.slice(data, 0, 4), 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 4);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 24);
/// @notice         uint256 value = BytesLib.toUint256(data, 25);
/// @notice         bytes txData_ = BytesLib.slice(data, 57, data.length - 57);
contract SpectraExchangeDepositHook is BaseHook, ISuperHookContextAware, ISuperHookInspector {
    using HookDataDecoder for bytes;

    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 24;
    uint256 private constant TX_DATA_POSITION = 57;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/
    ISpectraRouter public immutable router;

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_PT();
    error INVALID_IBT();
    error LENGTH_MISMATCH();
    error INVALID_COMMAND();
    error INVALID_SELECTOR();
    
    constructor(address router_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.PTYT) {
        if (router_ == address(0)) revert ADDRESS_NOT_VALID();
        router = ISpectraRouter(router_);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        address pt = data.extractYieldSource();
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
        uint256 value = abi.decode(data[25:TX_DATA_POSITION], (uint256));
        bytes memory txData_ = data[TX_DATA_POSITION:];

        bytes memory updatedTxData = _validateTxData(data[TX_DATA_POSITION:], account, usePrevHookAmount, prevHook, pt);

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(router),
            value: usePrevHookAmount ? ISuperHookResult(prevHook).outAmount() : value,
            callData: usePrevHookAmount ? updatedTxData : txData_
        });
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

}