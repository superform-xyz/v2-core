// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title SetSlippageHook
/// @author Superform Labs
/// @notice Hook for setting slippage configuration on ERC-7540 vaults
/// @dev Allows users to configure slippage tolerance for redeem operations
/// @dev The following hook does not need a _postExecute or a _preExecute definition
/// @dev data has the following structure
/// @notice         bytes32 placeholder = bytes32(BytesLib.slice(data, 0, 32));
/// @notice         address vault = BytesLib.toAddress(data, 32);
/// @notice         uint16 slippageBps = BytesLib.toUint16(data, 52);
contract SetSlippageHook is BaseHook {
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant SLIPPAGE_BPS_POSITION = 52;
    uint16 private constant MAX_SLIPPAGE_BPS = 10_000;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.ERC7540) { }

    /*//////////////////////////////////////////////////////////////
                                VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc BaseHook
    /// @dev Creates a single execution calling vault.setRedeemSlippage(slippageBps)
    function _buildHookExecutions(
        address, // prevHook
        address, // account
        bytes calldata data
    )
        internal
        pure
        override
        returns (Execution[] memory executions)
    {
        address vault = data.extractYieldSource();
        uint16 slippageBps = BytesLib.toUint16(data, SLIPPAGE_BPS_POSITION);

        if (vault == address(0)) revert ADDRESS_NOT_VALID();
        if (slippageBps > MAX_SLIPPAGE_BPS) revert AMOUNT_NOT_VALID();

        // Build single execution
        executions = new Execution[](1);
        executions[0] = Execution({
            target: vault,
            value: 0,
            callData: abi.encodeWithSignature("setRedeemSlippage(uint16)", slippageBps)
        });
    }

    /*//////////////////////////////////////////////////////////////
                                EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookInspector
    /// @dev Returns the vault address being configured
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(data.extractYieldSource());
    }
}
