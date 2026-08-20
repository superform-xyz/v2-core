// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { BytesLib } from "../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { BaseHyperCoreWriterHook } from "./BaseHyperCoreWriterHook.sol";
import { ISuperHookInspector } from "../../interfaces/ISuperHook.sol";

/// @title HyperCoreSendAssetHook
/// @author Superform Labs
/// @notice Sends a HyperCore spot balance to another account, or back to HyperEVM
/// @dev CoreWriter action 13, arguments
///      (address destination, address subAccount, uint32 sourceDex, uint32 destinationDex,
///       uint64 token, uint64 wei).
/// @dev Three of those six arguments are fixed by this hook rather than exposed as parameters.
///      subAccount is address(0): Superform does not use HyperCore sub-accounts, and every one of
///      1,945 sampled mainnet payloads carries zero. sourceDex and destinationDex are both
///      type(uint32).max, the "no perp dex" sentinel: all 84 sampled sends to a token system
///      address — the withdraw-to-HyperEVM case this hook exists for — use that pair unanimously.
///      Fixing them narrows the reachable action surface to what v1 needs.
/// @dev To withdraw to HyperEVM, set destination to the token's system address (0x20… ‖ index).
/// @dev `wei` is in HyperCore units for the token, which differ from EVM units per token via
///      weiDecimals and evmExtraWeiDecimals. This hook therefore does NOT support usePrevHookAmount
///      and does not implement ISuperHookContextAware — the caller supplies a converted value.
/// @dev CoreWriter performs no validation and cannot revert. Payload correctness is entirely this
///      hook's responsibility.
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address destination = BytesLib.toAddress(data, 52);
/// @notice         uint64 token = BytesLib.toUint64(data, 72);
/// @notice         uint64 amountWei = BytesLib.toUint64(data, 80);
contract HyperCoreSendAssetHook is BaseHyperCoreWriterHook {
    uint256 private constant DESTINATION_POSITION = 52;
    uint256 private constant TOKEN_POSITION = 72;
    uint256 private constant AMOUNT_WEI_POSITION = 80;
    uint256 private constant DATA_LENGTH = 88;

    /// @notice HyperCore sub-account. Superform does not use sub-accounts.
    address private constant SUB_ACCOUNT = address(0);

    /// @notice The "no perp dex" sentinel, used for spot sends including withdrawals to HyperEVM
    uint32 private constant NO_DEX = type(uint32).max;

    constructor(address coreWriter_) BaseHyperCoreWriterHook(coreWriter_) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "HyperCore Send Asset";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Sends a HyperCore spot balance to another account";
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        if (data.length != DATA_LENGTH) revert DATA_NOT_VALID();

        address destination = BytesLib.toAddress(data, DESTINATION_POSITION);
        uint64 token = BytesLib.toUint64(data, TOKEN_POSITION);
        uint64 amountWei = BytesLib.toUint64(data, AMOUNT_WEI_POSITION);

        if (destination == address(0)) revert ADDRESS_NOT_VALID();
        // A zero send is a silent CoreWriter no-op. Fail loudly instead.
        if (amountWei == 0) revert AMOUNT_NOT_VALID();

        executions = _coreWriterExecution(
            ACTION_SEND_ASSET, abi.encode(destination, SUB_ACCOUNT, NO_DEX, NO_DEX, token, amountWei)
        );
    }

    /// @inheritdoc ISuperHookInspector
    /// @dev PROTOCOL REQUIREMENT: inspector functions MUST only return addresses.
    ///      The destination is the withdrawal address a user most needs surfaced before signing.
    function inspect(bytes calldata data) external view override returns (bytes memory) {
        return abi.encodePacked(CORE_WRITER, BytesLib.toAddress(data, DESTINATION_POSITION));
    }
}
