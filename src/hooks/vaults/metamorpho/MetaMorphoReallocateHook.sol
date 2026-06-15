// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";
import { IMetaMorpho, MarketAllocation } from "../../../vendor/morpho/IMetaMorpho.sol";

/// @title MetaMorphoReallocateHook
/// @author Superform Labs
/// @notice NONACCOUNTING hook that calls MetaMorpho's reallocate() to redistribute funds between Morpho Blue markets
/// @dev data has the following structure
/// @notice         bytes32 placeholder = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address metaMorphoVault = BytesLib.toAddress(data, 32);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 52);
/// @notice         uint8 prevHookAmountIndex = BytesLib.toUint8(data, 53);
/// @notice         bytes allocationsData = abi.decode(BytesLib.slice(data, 54, data.length - 54), (MarketAllocation[]));
/// @dev TRUST ASSUMPTION: This hook relies entirely on MetaMorpho's onlyAllocator modifier for
///      access control. The hook itself is permissionless — it will attempt to call reallocate()
///      on any metaMorphoVault address provided in the data.
contract MetaMorphoReallocateHook is BaseHook, ISuperHookContextAware {
    using HookDataDecoder for bytes;

    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 52;
    uint256 private constant PREV_HOOK_AMOUNT_INDEX_POSITION = 53;
    uint256 private constant ALLOCATIONS_DATA_OFFSET = 54;

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.MISC) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "MetaMorpho Reallocate";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Reallocates liquidity across MetaMorpho vault markets";
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
        address metaMorphoVault = data.extractYieldSource();
        if (metaMorphoVault == address(0)) revert ADDRESS_NOT_VALID();

        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        MarketAllocation[] memory allocations =
            abi.decode(data[ALLOCATIONS_DATA_OFFSET:], (MarketAllocation[]));

        if (allocations.length == 0) revert AMOUNT_NOT_VALID();

        if (usePrevHookAmount) {
            uint8 index = BytesLib.toUint8(data, PREV_HOOK_AMOUNT_INDEX_POSITION);
            if (index >= allocations.length) revert AMOUNT_NOT_VALID();
            allocations[index].assets = ISuperHookResult(prevHook).getOutAmount(account);
        }

        executions = new Execution[](1);
        executions[0] = Execution({
            target: metaMorphoVault,
            value: 0,
            callData: abi.encodeCall(IMetaMorpho.reallocate, (allocations))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(data.extractYieldSource());
    }
}
