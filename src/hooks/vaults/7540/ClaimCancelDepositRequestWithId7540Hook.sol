// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC7540CancelDeposit } from "../../../vendor/standards/ERC7540/IERC7540Vault.sol";
import { IERC7540 } from "../../../vendor/vaults/7540/IERC7540.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHookAsyncCancelations, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title ClaimCancelDepositRequestWithId7540Hook
/// @author Superform Labs
/// @notice Same as ClaimCancelDepositRequest7540Hook but with requestId from calldata (non-zero support)
/// @dev data has the following structure
/// @notice         bytes32 placeholder = bytes32(BytesLib.slice(data, 0, 32));
/// @notice         address yieldSource = BytesLib.toAddress(data, 32);
/// @notice         address receiver = BytesLib.toAddress(data, 52);
/// @notice         uint256 requestId = BytesLib.toUint256(data, 72);
contract ClaimCancelDepositRequestWithId7540Hook is BaseHook, ISuperHookAsyncCancelations {
    using HookDataDecoder for bytes;

    uint256 private constant RECEIVER_POSITION = 52;
    uint256 private constant REQUEST_ID_POSITION = 72;

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.CLAIM_CANCEL_DEPOSIT_REQUEST) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Claim Cancel Deposit Request with ID ERC-7540";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Claims assets from a cancelled deposit request on an ERC-7540 vault using a request ID";
    }


    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address account,
        bytes calldata data
    )
        internal
        pure
        override
        returns (Execution[] memory executions)
    {
        address yieldSource = data.extractYieldSource();
        address receiver = BytesLib.toAddress(data, RECEIVER_POSITION);
        uint256 requestId = BytesLib.toUint256(data, REQUEST_ID_POSITION);

        if (yieldSource == address(0) || receiver == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IERC7540CancelDeposit.claimCancelDepositRequest, (requestId, receiver, account))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookAsyncCancelations
    function isAsyncCancelHook() external pure returns (CancelationType) {
        return CancelationType.INFLOW;
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(
            data.extractYieldSource(),
            BytesLib.toAddress(data, RECEIVER_POSITION) //receiver
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        address yieldSource = data.extractYieldSource();
        address receiver = BytesLib.toAddress(data, RECEIVER_POSITION);
        asset = IERC7540(yieldSource).asset();
        // store current balance
        _setOutAmount(_getBalance(receiver, data), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        address receiver = BytesLib.toAddress(data, RECEIVER_POSITION);

        _setOutAmount(_getBalance(receiver, data) - getOutAmount(account), account);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    function _getBalance(address account, bytes memory) private view returns (uint256) {
        return IERC20(asset).balanceOf(account);
    }
}
