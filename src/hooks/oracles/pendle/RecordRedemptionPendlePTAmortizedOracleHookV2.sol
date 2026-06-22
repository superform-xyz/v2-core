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
import { IPendlePTAmortizedOracle } from "../../../vendor/pendle/IPendlePTAmortizedOracle.sol";

/// @title RecordRedemptionPendlePTAmortizedOracleHookV2
/// @author Superform Labs
/// @notice V2 Hook to record PT redemptions in the PendlePTAmortizedOracle
/// @dev Called AFTER a redeem/swap hook that sells PT
/// @dev The strategy (msg.sender during execution) will be recorded as the position holder
/// @dev data has the following structure
/// @notice         address market = BytesLib.toAddress(data, 0);
/// @notice         uint256 ptSold = BytesLib.toUint256(data, 20);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 52);
contract RecordRedemptionPendlePTAmortizedOracleHookV2 is BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Hook version
    uint256 public constant VERSION = 2;

    uint256 private constant MARKET_POSITION = 0;
    uint256 private constant PT_SOLD_POSITION = 20;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 52;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The PendlePTAmortizedOracle contract
    IPendlePTAmortizedOracle public immutable ORACLE;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error MARKET_NOT_VALID();
    error PT_SOLD_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructor
    /// @param oracle_ The PendlePTAmortizedOracle address
    constructor(address oracle_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.PTYT) {
        if (oracle_ == address(0)) revert ADDRESS_NOT_VALID();
        ORACLE = IPendlePTAmortizedOracle(oracle_);
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Record Redemption Pendle PT Oracle V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Records a Pendle PT redemption for amortized oracle pricing (V2)";
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

        // Get ptSold from previous hook if enabled (typical flow: after redeem hook)
        if (usePrevHookAmount) {
            ptSold = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (market == address(0)) revert MARKET_NOT_VALID();
        if (ptSold == 0) revert PT_SOLD_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(ORACLE),
            value: 0,
            callData: abi.encodeCall(IPendlePTAmortizedOracle.recordRedemption, (market, ptSold))
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

    /// @notice Decode the ptSold amount from hook data
    /// @param data The hook data
    /// @return The ptSold amount
    function decodePtSold(bytes memory data) external pure returns (uint256) {
        return BytesLib.toUint256(data, PT_SOLD_POSITION);
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
