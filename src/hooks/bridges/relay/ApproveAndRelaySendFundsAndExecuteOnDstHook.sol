// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IRelayDepository } from "../../../vendor/bridges/relay/IRelayDepository.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import {
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";

/// @title ApproveAndRelaySendFundsAndExecuteOnDstHook
/// @author Superform Labs
/// @dev ERC20-only Relay depository deposit with the approval pattern
///      (approve 0 -> approve amount -> deposit -> approve 0).
/// @dev The Relay depository pulls ERC20 deposits via transferFrom, so the approval targets the
///      immutable depository only. The trailing approval reset guarantees no residual allowance.
/// @dev For native token transfers, use RelaySendFundsAndExecuteOnDstHook instead.
/// @dev Relay's origin deposit carries only the order `id` — no destination message is appended
///      on-chain; the destination execution travels in the Relay quote's txs[] (see
///      RelaySendFundsAndExecuteOnDstHook for details).
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address token = BytesLib.toAddress(data, 52);
/// @notice         uint256 amount = BytesLib.toUint256(data, 72);
/// @notice         bytes32 depositId = BytesLib.toBytes32(data, 104);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 136);
contract ApproveAndRelaySendFundsAndExecuteOnDstHook is
    BaseHook,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
{
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    /// @notice The Relay depository this hook deposits into (per-chain, immutable)
    address public immutable RELAY_DEPOSITORY;

    uint256 private constant TOKEN_POSITION = 52;
    uint256 private constant AMOUNT_POSITION = 72;
    uint256 private constant DEPOSIT_ID_POSITION = 104;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 136;
    uint256 private constant MIN_DATA_LENGTH = 137;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when hook data is shorter than the fixed layout
    error DATA_NOT_VALID();

    /// @notice Thrown when the deposit id is zero — a zero id makes the deposit unattributable
    ///         (and unrefundable) in Relay's off-chain order matching
    error ID_NOT_VALID();

    constructor(address relayDepository_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE) {
        if (relayDepository_ == address(0)) revert ADDRESS_NOT_VALID();
        RELAY_DEPOSITORY = relayDepository_;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Approve and Relay Bridge";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Approves and bridges tokens via the Relay depository with destination execution by Relay solvers";
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
        if (data.length < MIN_DATA_LENGTH) revert DATA_NOT_VALID();

        address token = BytesLib.toAddress(data, TOKEN_POSITION);
        uint256 amount = BytesLib.toUint256(data, AMOUNT_POSITION);
        bytes32 depositId = BytesLib.toBytes32(data, DEPOSIT_ID_POSITION);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        // ERC20-only: native deposits need no approval — use RelaySendFundsAndExecuteOnDstHook
        if (token == address(0)) revert ADDRESS_NOT_VALID();

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (depositId == bytes32(0)) revert ID_NOT_VALID();

        // Always use approve pattern for ERC20 tokens: approve 0 -> approve amount -> deposit -> approve 0
        executions = new Execution[](4);

        // Execution 0: Reset approval to 0 (prevents approval race conditions)
        executions[0] = Execution({
            target: token,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (RELAY_DEPOSITORY, 0))
        });

        // Execution 1: Approve exact amount
        executions[1] = Execution({
            target: token,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (RELAY_DEPOSITORY, amount))
        });

        // Execution 2: Deposit into the Relay depository
        executions[2] = Execution({
            target: RELAY_DEPOSITORY,
            value: 0,
            callData: abi.encodeCall(IRelayDepository.depositErc20, (account, token, amount, depositId))
        });

        // Execution 3: Cleanup approval to 0
        executions[3] = Execution({
            target: token,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (RELAY_DEPOSITORY, 0))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(
            ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN
        );
    }

    /// @dev This hook implements ISuperHookInflowOutflow + ISuperHookOutflow
    function _supportsSizingInterface() internal pure override returns (bool) {
        return true;
    }

    /// @inheritdoc ISuperHookOutflow
    function replaceCalldataAmounts(
        bytes memory data,
        uint256[] memory amounts
    )
        external
        pure
        override
        returns (bytes memory)
    {
        if (amounts.length != 1) revert INVALID_AMOUNTS_LENGTH();
        return _replaceCalldataAmount(data, amounts[0], AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(
            BytesLib.toAddress(data, TOKEN_POSITION) // token
        );
    }
}
