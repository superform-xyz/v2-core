// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { BytesLib } from "../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { BaseHyperCoreWriterHook } from "./BaseHyperCoreWriterHook.sol";
import { ISuperHookInspector } from "../../interfaces/ISuperHook.sol";

/// @title HyperCoreApproveBuilderFeeHook
/// @author Superform Labs
/// @notice Approves a builder to charge a fee on the executing account's HyperCore orders
/// @dev CoreWriter action 12, arguments (uint64 maxFeeRate, address builder). Field order in the
///      data layout deliberately mirrors the CoreWriter argument order so the byte-exact fixture
///      test reads without cross-referencing.
/// @dev maxFeeRate is in DECIBPS — tenths of a basis point. A value of 10 is one basis point, so
///      100 == 0.1% and 1000 == 1%. Hyperliquid caps builder fees at 0.1% on perps and 1% on spot.
///      This is NOT the API's percentage-string encoding.
/// @dev The unit is easy to misread by a factor of 10, and the failure is silent: CoreWriter never
///      reverts, so an over-cap approval is dropped on HyperCore behind a successful EVM receipt.
///      A perps deployment must pass 100, not 1000 — 1000 is the spot maximum.
/// @dev A maxFeeRate of 0 is a legitimate REVOCATION of a prior approval and is a VALID input. Do
///      not add a zero rejection.
/// @dev The cap is a constructor immutable rather than a constant because the on-wire unit carries
///      no documentation guarantee — a wrong bound here silently costs the user money on every
///      subsequent trade, and CoreWriter will not stop it.
/// @dev CoreWriter performs no validation and cannot revert. Payload correctness is entirely this
///      hook's responsibility.
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         uint64 maxFeeRate = BytesLib.toUint64(data, 52);
/// @notice         address builder = BytesLib.toAddress(data, 60);
contract HyperCoreApproveBuilderFeeHook is BaseHyperCoreWriterHook {
    uint256 private constant MAX_FEE_RATE_POSITION = 52;
    uint256 private constant BUILDER_POSITION = 60;
    uint256 private constant DATA_LENGTH = 80;

    /// @notice Upper bound on the approvable fee rate, in decibps (tenths of a basis point)
    /// @dev Set at deployment: 100 for a perps market, 1000 for spot.
    uint64 public immutable MAX_BUILDER_FEE_RATE;

    constructor(address coreWriter_, uint64 maxBuilderFeeRate_) BaseHyperCoreWriterHook(coreWriter_) {
        if (maxBuilderFeeRate_ == 0) revert AMOUNT_NOT_VALID();
        MAX_BUILDER_FEE_RATE = maxBuilderFeeRate_;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "HyperCore Approve Builder Fee";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Approves a builder fee on HyperCore orders";
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

        uint64 maxFeeRate = BytesLib.toUint64(data, MAX_FEE_RATE_POSITION);
        address builder = BytesLib.toAddress(data, BUILDER_POSITION);

        if (builder == address(0)) revert ADDRESS_NOT_VALID();
        // NOTE: maxFeeRate == 0 is deliberately permitted — it is how a prior builder approval is
        // revoked. Rejecting zero would make revocation impossible.
        if (maxFeeRate > MAX_BUILDER_FEE_RATE) revert AMOUNT_NOT_VALID();

        executions = _coreWriterExecution(ACTION_APPROVE_BUILDER_FEE, abi.encode(maxFeeRate, builder));
    }

    /// @inheritdoc ISuperHookInspector
    /// @dev PROTOCOL REQUIREMENT: inspector functions MUST only return addresses
    function inspect(bytes calldata data) external view override returns (bytes memory) {
        return abi.encodePacked(CORE_WRITER, BytesLib.toAddress(data, BUILDER_POSITION));
    }
}
