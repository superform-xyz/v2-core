// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

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
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";

/// @title RecordPurchasePendlePTAmortizedOracleHookV2
/// @author Superform Labs
/// @notice V2 Hook to record PT purchases in the PendlePTAmortizedOracleV2
/// @dev Key differences from V1:
///      - No sySpent parameter - oracle calculates it from on-chain PT rate
///      - Includes twapDuration parameter for per-call TWAP configuration
/// @dev Called AFTER a deposit/swap hook that outputs PT amount
/// @dev The strategy (msg.sender during execution) will be recorded as the position holder
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         uint256 placeholder0 = BytesLib.toUint256(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address market = BytesLib.toAddress(data, 52);
/// @notice         uint256 ptAmount = BytesLib.toUint256(data, 72);
/// @notice         uint32 twapDuration = BytesLib.toUint32(data, 104);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 108);
contract RecordPurchasePendlePTAmortizedOracleHookV2 is BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 private constant MARKET_POSITION = 52;
    uint256 private constant PT_AMOUNT_POSITION = 72;
    uint256 private constant TWAP_DURATION_POSITION = 104;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 108;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The PendlePTAmortizedOracleV2 contract
    address public immutable ORACLE;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error MARKET_NOT_VALID();
    error PT_AMOUNT_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructor
    /// @param oracle_ The PendlePTAmortizedOracleV2 address
    constructor(address oracle_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.PTYT) {
        if (oracle_ == address(0)) revert ADDRESS_NOT_VALID();
        ORACLE = oracle_;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Record Purchase Pendle PT Oracle V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Records a Pendle PT purchase for amortized oracle pricing (V2)";
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
        uint256 ptAmount = BytesLib.toUint256(data, PT_AMOUNT_POSITION);
        uint32 twapDuration = BytesLib.toUint32(data, TWAP_DURATION_POSITION);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        // Get ptAmount from previous hook if enabled (typical flow: after swap hook)
        if (usePrevHookAmount) {
            ptAmount = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (market == address(0)) revert MARKET_NOT_VALID();
        if (ptAmount == 0) revert PT_AMOUNT_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: ORACLE,
            value: 0,
            // V2: Pass market, ptAmount, and twapDuration (no sySpent - oracle calculates from PT rate)
            callData: abi.encodeWithSignature("recordPurchase(address,uint256,uint32)", market, ptAmount, twapDuration)
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
    /// @param data The hook data
    /// @return The market address
    function decodeMarket(bytes memory data) external pure returns (address) {
        return BytesLib.toAddress(data, MARKET_POSITION);
    }

    /// @notice Decode the ptAmount from hook data
    /// @param data The hook data
    /// @return The ptAmount
    function decodePtAmount(bytes memory data) external pure returns (uint256) {
        return BytesLib.toUint256(data, PT_AMOUNT_POSITION);
    }

    /// @notice Decode the twapDuration from hook data
    /// @param data The hook data
    /// @return The twapDuration in seconds (0 = spot price, 900 = 15min TWAP)
    function decodeTwapDuration(bytes memory data) external pure returns (uint32) {
        return BytesLib.toUint32(data, TWAP_DURATION_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(
            BytesLib.toAddress(data, MARKET_POSITION) // market
        );
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
