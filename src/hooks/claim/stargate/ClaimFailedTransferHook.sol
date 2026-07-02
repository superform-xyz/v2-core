// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import {
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookInspector
} from "../../../interfaces/ISuperHook.sol";

/// @title IStargateAdapterClaim
/// @notice Minimal interface for StargateAdapter.claimFailedTransfer
interface IStargateAdapterClaim {
    function claimFailedTransfer(address token, uint256 amount) external;
}

/// @title ClaimFailedTransferHook
/// @author Superform Labs
/// @notice Hook to claim failed transfers from the StargateAdapter
/// @dev Calls claimFailedTransfer(address token, uint256 amount) on the StargateAdapter
/// @dev The StargateAdapter stores failed transfers when lzCompose token delivery fails.
///      This hook allows smart accounts to recover those tokens.
/// @dev Supports both ERC20 tokens and native ETH (token = address(0))
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes placeholder = BytesLib.slice(data, 0, 52);
/// @dev         address adapter = BytesLib.toAddress(data, 0);
/// @dev         address token = BytesLib.toAddress(data, 20);
/// @dev         uint256 amount = BytesLib.toUint256(data, 40);
contract ClaimFailedTransferHook is BaseHook, ISuperHookInflowOutflow, ISuperHookOutflow {

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Minimum data length: adapter(20) + token(20) + amount(32) = 72 bytes
    uint256 private constant MIN_DATA_LENGTH = 72;

    /// @dev Byte offset of the uint256 amount field in hook data
    uint256 private constant AMOUNT_POSITION = 40;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the claim amount is zero
    error CLAIM_AMOUNT_ZERO();

    /// @notice Thrown when hook data is too short
    error DATA_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.CLAIM) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Claim Failed Transfer";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Claims tokens from a failed Stargate transfer";
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
        pure
        override
        returns (Execution[] memory executions)
    {
        if (data.length < MIN_DATA_LENGTH) revert DATA_NOT_VALID();

        address adapter = BytesLib.toAddress(data, 0);
        address token = BytesLib.toAddress(data, 20);
        uint256 amount = BytesLib.toUint256(data, AMOUNT_POSITION);

        if (adapter == address(0)) revert ADDRESS_NOT_VALID();
        if (amount == 0) revert CLAIM_AMOUNT_ZERO();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: adapter,
            value: 0,
            callData: abi.encodeCall(IStargateAdapterClaim.claimFailedTransfer, (token, amount))
        });
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory) external pure override returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
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
    /// @dev Returns the packed (adapter, token) pair for off-chain inspection and indexing
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(
            BytesLib.toAddress(data, 0), // adapter
            BytesLib.toAddress(data, 20) // token
        );
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    /// @dev Snapshots the token balance before claim execution
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(data, account), account);
    }

    /// @inheritdoc BaseHook
    /// @dev Computes the delta (post - pre) as the net tokens claimed
    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(data, account) - getOutAmount(account), account);
        _setOutToken(asset, account);
    }

    /*//////////////////////////////////////////////////////////////
                           PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the balance of the token for a given account
    /// @dev For native ETH (token = address(0)), returns the ETH balance
    /// @dev For ERC20 tokens, returns the ERC20 balance
    /// @param data The hook data containing the token address at offset 20
    /// @param account The account to check the balance for
    /// @return The token balance of the account
    function _getBalance(bytes calldata data, address account) private view returns (uint256) {
        address token = BytesLib.toAddress(data, 20);
        if (token == address(0)) {
            return account.balance;
        } else {
            return IERC20(token).balanceOf(account);
        }
    }
}
