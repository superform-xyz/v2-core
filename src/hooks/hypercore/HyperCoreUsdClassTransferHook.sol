// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { BytesLib } from "../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { BaseHyperCoreWriterHook } from "./BaseHyperCoreWriterHook.sol";
import { ISuperHookInspector } from "../../interfaces/ISuperHook.sol";

/// @title HyperCoreUsdClassTransferHook
/// @author Superform Labs
/// @notice Moves USDC between the executing account's HyperCore spot and perp margin balances
/// @dev CoreWriter action 7, arguments (uint64 ntl, bool toPerp).
/// @dev `ntl` is denominated in HyperCore units of 1e6, established empirically from mainnet
///      payloads. It is NOT the same scale as an arbitrary EVM token amount: the EVM offset varies
///      per token via weiDecimals and evmExtraWeiDecimals. This hook therefore does NOT support
///      usePrevHookAmount and does not implement ISuperHookContextAware — the caller supplies an
///      already-converted value and the hook validates only its bound.
/// @dev CoreWriter performs no validation and cannot revert. Payload correctness is entirely this
///      hook's responsibility.
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         uint64 ntl = BytesLib.toUint64(data, 52);
/// @notice         bool toPerp = _decodeBool(data, 60);
contract HyperCoreUsdClassTransferHook is BaseHyperCoreWriterHook {
    uint256 private constant NTL_POSITION = 52;
    uint256 private constant TO_PERP_POSITION = 60;
    uint256 private constant DATA_LENGTH = 61;

    constructor(address coreWriter_) BaseHyperCoreWriterHook(coreWriter_) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "HyperCore USD Class Transfer";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Moves USDC between HyperCore spot and perp margin";
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

        uint64 ntl = BytesLib.toUint64(data, NTL_POSITION);
        bool toPerp = _decodeBool(data, TO_PERP_POSITION);

        // A zero class transfer is a silent CoreWriter no-op. Fail loudly rather than burn gas and
        // report success to a caller that has no other way to detect it.
        if (ntl == 0) revert AMOUNT_NOT_VALID();

        executions = _coreWriterExecution(ACTION_USD_CLASS_TRANSFER, abi.encode(ntl, toPerp));
    }

    /// @inheritdoc ISuperHookInspector
    /// @dev PROTOCOL REQUIREMENT: inspector functions MUST only return addresses.
    ///      This hook's data carries none, so the immutable target is the only meaningful value.
    function inspect(bytes calldata) external view override returns (bytes memory) {
        return abi.encodePacked(CORE_WRITER);
    }
}
