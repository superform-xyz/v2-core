// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { HookSubTypes } from "../../libraries/HookSubTypes.sol";
import { ICoreWriter } from "../../vendor/hyperliquid/ICoreWriter.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../interfaces/ISuperHook.sol";

/// @title BaseHyperCoreWriterHook
/// @author Superform Labs
/// @notice Shared envelope encoder for every hook that drives Hyperliquid's CoreWriter
/// @dev The executing smart account is the HyperCore master account, because CoreWriter's HyperCore
///      actor is msg.sender of sendRawAction and Superform hooks execute as the account.
/// @dev CoreWriter cannot fail. It never reverts, never validates the action id, and never reports
///      an outcome. Payload correctness is entirely the responsibility of these hooks, which is why
///      every leaf pins its data length exactly and why the fixtures assert bytes rather than shape.
abstract contract BaseHyperCoreWriterHook is BaseHook, ISuperHookInflowOutflow {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice CoreWriter system contract
    /// @dev Immutable rather than hardcoded: repo convention, testnet 998 reuse, and the unit tests
    ///      inject a mock that records payloads.
    address public immutable CORE_WRITER;

    /// @notice Envelope version byte. Every action observed in production use is under 0x01.
    bytes1 internal constant ENCODING_VERSION = 0x01;

    /// @notice The complete set of HyperCore actions reachable through this hook family.
    /// @dev Listed in one place so the reachable surface is auditable at a glance. A typed leaf per
    ///      action is deliberate — a generic (actionId, bytes) encoder would let any signed intent
    ///      perform any HyperCore action.
    uint24 internal constant ACTION_USD_CLASS_TRANSFER = 7;
    uint24 internal constant ACTION_ADD_API_WALLET = 9;
    uint24 internal constant ACTION_APPROVE_BUILDER_FEE = 12;
    uint24 internal constant ACTION_SEND_ASSET = 13;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when hook data length does not exactly match the declared layout
    /// @dev Length is pinned with strict equality rather than a lower bound. CoreWriter accepts and
    ///      ignores trailing bytes, so an exact match is the only way to reject a padded payload.
    error DATA_NOT_VALID();

    constructor(address coreWriter_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.HYPERCORE) {
        if (coreWriter_ == address(0)) revert ADDRESS_NOT_VALID();
        CORE_WRITER = coreWriter_;
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Builds the versioned CoreWriter envelope
    /// @dev version byte ‖ uint24 big-endian action id ‖ abi.encode(args)
    function _encodeAction(uint24 actionId, bytes memory args) internal pure returns (bytes memory) {
        return abi.encodePacked(ENCODING_VERSION, bytes3(actionId), args);
    }

    /// @notice Wraps an encoded action into the single Execution every leaf emits
    function _coreWriterExecution(
        uint24 actionId,
        bytes memory args
    )
        internal
        view
        returns (Execution[] memory executions)
    {
        executions = new Execution[](1);
        executions[0] = Execution({
            target: CORE_WRITER,
            value: 0,
            callData: abi.encodeCall(ICoreWriter.sendRawAction, (_encodeAction(actionId, args)))
        });
    }

    /// @dev Side-effect only hooks — auto-forward the previous hook's outAmount and outToken.
    ///      A CoreWriter action produces nothing EVM-observable, so there is no delta to measure.
    ///      Not virtual: no leaf may regress to TRANSFORM.
    function _pipeMode() internal pure override returns (PipeMode) {
        return PipeMode.PASSTHROUGH;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev Authoritatively sizeless. These hooks carry no resizable amount.
    function decodeAmounts(bytes memory) external pure virtual override returns (uint256[] memory amounts) {
        amounts = new uint256[](0);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory)
        external
        pure
        virtual
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](0);
    }

    /// @inheritdoc IERC165
    /// @dev S2: implements ISuperHookInflowOutflow (decode-only) but explicitly NOT
    ///      ISuperHookOutflow. replaceCalldataAmounts lives on ISuperHookOutflow, so by not
    ///      inheriting it the rewrite function does not exist on these contracts at all — the
    ///      bundler's amount-resizing cannot touch a fee rate, an ntl, or a token index.
    function supportsInterface(bytes4 interfaceId) external pure virtual override returns (bool) {
        if (interfaceId == type(ISuperHookInflowOutflow).interfaceId) return true;
        if (interfaceId == type(ISuperHookOutflow).interfaceId) return false;
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(ISuperHook).interfaceId
            || interfaceId == type(ISuperHookResult).interfaceId
            || interfaceId == type(ISuperHookInspector).interfaceId;
    }
}
