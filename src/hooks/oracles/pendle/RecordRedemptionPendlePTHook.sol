// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";
import { IPendlePTHookResult } from "../../../interfaces/IPendlePTHookResult.sol";
import { IPendleMarket } from "../../../vendor/pendle/IPendleMarket.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";

/// @title RecordRedemptionPendlePTHook
/// @author Superform Labs
/// @notice Records a Pendle PT sale/redemption in the PendlePTAmortizedOracleV2, sourcing the PT SOLD
///         from the preceding PendlePTHook's actual balance-delta TradeResult.
/// @dev Runs immediately after an approved PendlePTHook in the same executor sequence. On a PT sale or
///      matured redemption, PendlePTHook's INPUT is PT, so `ptSold` = TradeResult.inputAmount. The
///      output (asset received) must NEVER be recorded as ptSold — this hook therefore does NOT use
///      the generic getOutAmount.
/// @dev Amount semantics:
///      - usePrevHookAmount == false: use the encoded `amount` (manual mode, standalone).
///      - usePrevHookAmount == true:  ignore encoded `amount`; require the prev hook is the approved
///        PendlePTHook, its operation is SELL_PT or REDEEM_PT, its market matches, and its input token
///        is the PT of `market.readTokens()`; use TradeResult.inputAmount.
///      Resolved amount of zero ALWAYS reverts (validated after resolution).
/// @dev data layout (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0      = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1      = BytesLib.toAddress(data, 32);
/// @notice         address market            = BytesLib.toAddress(data, 52);
/// @notice         uint256 amount            = BytesLib.toUint256(data, 72);
/// @notice         bool    usePrevHookAmount = _decodeBool(data, 104);
contract RecordRedemptionPendlePTHook is BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant MARKET_POSITION = 52;
    uint256 private constant PT_SOLD_POSITION = 72;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 104;

    /*//////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    /// @notice The PendlePTAmortizedOracleV2 contract
    address public immutable ORACLE;

    /// @notice The only PendlePTHook this recorder accepts as the preceding hook (automatic mode)
    address public immutable APPROVED_PENDLE_PT_HOOK;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error MARKET_NOT_VALID();
    error PREV_HOOK_NOT_VALID();
    error OPERATION_NOT_VALID();
    error PT_TOKEN_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @param oracle_ The PendlePTAmortizedOracleV2 address
    /// @param approvedPendlePTHook_ The approved PendlePTHook address (automatic mode source)
    constructor(address oracle_, address approvedPendlePTHook_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.PTYT) {
        if (oracle_ == address(0) || approvedPendlePTHook_ == address(0)) revert ADDRESS_NOT_VALID();
        ORACLE = oracle_;
        APPROVED_PENDLE_PT_HOOK = approvedPendlePTHook_;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Record Redemption Pendle PT";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Records a Pendle PT sale/redemption (actual PT spent) for amortized oracle pricing";
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
        address market = BytesLib.toAddress(data, MARKET_POSITION);
        uint256 ptSold = BytesLib.toUint256(data, PT_SOLD_POSITION);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (market == address(0)) revert MARKET_NOT_VALID();

        if (usePrevHookAmount) {
            // G-8: pin BEFORE any external call into prevHook
            if (prevHook != APPROVED_PENDLE_PT_HOOK) revert PREV_HOOK_NOT_VALID();

            IPendlePTHookResult.TradeResult memory result =
                IPendlePTHookResult(prevHook).getPendleTradeResult(account);

            if (
                result.operation != IPendlePTHookResult.Operation.SELL_PT
                    && result.operation != IPendlePTHookResult.Operation.REDEEM_PT
            ) revert OPERATION_NOT_VALID();
            if (result.market != market) revert MARKET_NOT_VALID();

            // Re-read PT identity from the committed (and matched) market — index 1 is PT.
            (, address pt,) = IPendleMarket(market).readTokens();
            if (result.inputToken != pt) revert PT_TOKEN_NOT_VALID();

            ptSold = result.inputAmount; // actual PT spent (NOT the output asset)
        }

        // Validate AFTER resolution: zero always reverts (both modes).
        if (ptSold == 0) revert AMOUNT_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: ORACLE,
            value: 0,
            callData: abi.encodeWithSignature("recordRedemption(address,uint256)", market, ptSold)
        });
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @notice Decode the market address from hook data
    function decodeMarket(bytes memory data) external pure returns (address) {
        return BytesLib.toAddress(data, MARKET_POSITION);
    }

    /// @notice Decode the ptSold amount from hook data
    function decodePtSold(bytes memory data) external pure returns (uint256) {
        return BytesLib.toUint256(data, PT_SOLD_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(BytesLib.toAddress(data, MARKET_POSITION));
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](0);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory) external pure override returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](0);
    }

    /// @inheritdoc IERC165
    /// @dev S2: implements ISuperHookInflowOutflow (decode-only) but NOT ISuperHookOutflow
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        if (interfaceId == type(ISuperHookInflowOutflow).interfaceId) return true;
        if (interfaceId == type(ISuperHookOutflow).interfaceId) return false;
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(ISuperHook).interfaceId
            || interfaceId == type(ISuperHookResult).interfaceId
            || interfaceId == type(ISuperHookInspector).interfaceId;
    }

    /// @dev Side-effect only hook — forwards previous hook's outAmount + outToken
    function _pipeMode() internal pure override returns (PipeMode) {
        return PipeMode.PASSTHROUGH;
    }
}
